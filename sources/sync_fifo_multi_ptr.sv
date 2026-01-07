`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//row pointer, for accessing 3 rows at a time
//read operation only
//see read_en enables reading from all 3 rows at a time
//it can read from 3 consecutive rows only

module sync_fifo_multi_ptr
#(parameter 
DEPTH=4096, 
DATA_WIDTH=8,
sumd_int = 10,
cols = 33,
rows = 33,
pr = 16, 
pc = 16,
wnr = 3, //window size --> currently 7x7
wnc = 3,
colbits = $clog2(cols), //log2(cols)
rowbits = $clog2(rows)) 
(
  input clk, rst, //active high reset
  input w_en, r_en, load_addr,
  input [DATA_WIDTH-1:0] data_in,
  input signed [sumd_int-1:0] sum_dr, sum_dc,
  output reg [DATA_WIDTH-1:0] data_out0, data_out1,
  output full, empty, window_done
);
 
  
  reg [$clog2(DEPTH)-1:0] w_ptr, r_ptr0, r_ptr1; //this is necessary to make the fifo circular
  reg [DATA_WIDTH-1:0] fifo[DEPTH];
  
  // Set Default values on reset.
  always@(posedge clk, posedge rst) begin
    if(rst) begin
      w_ptr <= 0; 
    end
    else if(w_en & !full)begin //if fifo is write enabled and not full, write into the fifo, else keep the prev value in
      fifo[w_ptr] <= data_in; //fifo[w_ptr] and w_ptr --> latch intentional
      w_ptr <= w_ptr + 1;
    end
  end
  
  
//READ LOGIC
  
  //col_counter
  reg [3:0] col_count, row_count;
  
  always@(posedge clk, posedge rst)
  begin
    if(rst | ~r_en | row_done)
        col_count <= 4'd0;
    else 
        col_count <= col_count + 1; 
  end
  

  
  always@(posedge clk, posedge rst)
  begin
    if(rst | ~r_en | window_done)
        row_count <= 4'd0;
    else if(row_done)
        row_count <= row_count + 1; 
    else 
        row_count <= row_count; 
  end
  
  wire [colbits-1:0] sum;
  assign sum = row_done ? (cols-2*wnc) : 1; 
  
    // To read data from FIFO
      // load Default values.
  always@(posedge clk, posedge rst) begin
    if(rst | window_done) begin
      r_ptr0 <= 0; //read pointer is set to 1 cuz in this project, the first and last fifo element must be ignored 
      r_ptr1 <= 0; 
//      r_ptr2 <= 0; //when reset, r_ptrs point to first element of first 3 rows
      data_out0 <= 0; //has an inferred latch, which is intentional
      data_out1 <= 0;
//      data_out2 <= 0;
      end
    else
     if(load_addr) begin
    r_ptr0 <= 1+(pr-wnr)*cols + (pc-wnc); //read pointer is set to 1 cuz in this project, the first and last fifo element must be ignored 
      r_ptr1 <= 1+(pr-wnr)*cols + cols + (pc-wnc); 
//      r_ptr2 <= 1+(pr-wnr)*cols + 2*cols + (pc-wnc); //when reset, r_ptrs point to first element of first 3 rows
/*      r_ptr0 <= (pr-wnr+sum_dr)*cols + (pc-wnc+sum_dc); //read pointer is set to 1 cuz in this project, the first and last fifo element must be ignored 
      r_ptr1 <= (pr-wnr+sum_dr)*cols + cols + (pc-wnc+sum_dc); 
      r_ptr2 <= (pr-wnr+sum_dr)*cols + 2*cols + (pc-wnc+sum_dc);   */
    end
    else
     if(r_en) begin
      data_out0 <= fifo[r_ptr0]; //{row_ele0, row_ele1}
      r_ptr0 <= r_ptr0 + sum;
      
      data_out1 <= fifo[r_ptr1];
      r_ptr1 <= r_ptr1 + sum;
      
//      data_out2 <= fifo[r_ptr2];
//      r_ptr2 <= r_ptr2 + sum;
    end
    
  end
  

  assign row_done = col_count == 4'd6; //0 to 6, mod7 counter
    
  assign window_done = row_count == 4'd5; //all 7 rows displayed
  
 //assume this is a linear fifo - not circular
  
  assign full = (w_ptr == DEPTH-1); //read and write points are next to each other
    
  assign empty =  (w_ptr == 0); 
 
 
endmodule

//make the read pointers give exactly 7x7 window - 3 col pixels at a time
//fix the read_pointer start addresses, and when reset, it must go back to this
//also row and col counters are necessary

//remember, these are custom fifos that output 3 col pixels per clock cycle from a central 7x7 window
//see, if I didn't need a 7x7 window but the entire image, then I didn't have to do all this
//fifo is stored in such a way that the end of row1 naturally moves to row2
//it's made for sliding window operations, but here, I need 7x7 window, which requires row and col counter logic
