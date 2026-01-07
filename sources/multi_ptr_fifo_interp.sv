`timescale 1ns / 1ps

//this code is based on the assumption that start address - that is computed is within bounds, else it just gives an random value at the value that's been computed

//the multi_ptr_fifo_interp_tb shows that this code works

//////////////////////////////////////////////////////////////////////////////////
//row pointer, for accessing 4 rows at a time --> required for bilinear interp
//read operation only
//see read_en enables reading from all 3 rows at a time
//it can read from 3 consecutive rows only

//this is a fifo with bilinear interp, with a changing read pointer (based on input sum_dr and sum_dc

module multi_ptr_fifo_interp
#(parameter 
DEPTH=4096, 
DATA_WIDTH=8,
sumd_int = 6,
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
  output reg [2*DATA_WIDTH-1:0] data_out0, data_out1, data_out2, data_out3,
  output full, empty, window_done
);
 
 integer i; 
  
  reg  signed [$clog2(DEPTH)-1:0] w_ptr, r_ptr0, r_ptr1, r_ptr2, r_ptr3; //making this signed is not communicating the sign of sum_dx to this
  reg [DATA_WIDTH-1:0] fifo[0: DEPTH-1];
  
    // Set Default values on reset.
  always@(posedge clk, posedge rst) begin
    if(rst) begin
      w_ptr <= 0;
//      for(i=0; i<DEPTH; i=i+1) begin
//        fifo[w_ptr] = {DATA_WIDTH{1'b0}}; 
//      end  //i hoped it would initialise all the elements of the fifo to 0, but it's not working so I have to use the mux logic
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
  assign sum = row_done ? (cols-2*wnc) : 1; //cuz I've accessed one more col to include interpolation
  
  wire [sumd_int-1:0] abs_sum_dr, abs_sum_dc; 
 
  assign abs_sum_dr = sum_dr[sumd_int-1] ? -(sum_dr) : sum_dr; 
  assign abs_sum_dc = sum_dc[sumd_int-1] ? -(sum_dc) : sum_dc; 
  
  wire [$clog2(DEPTH)-1:0] row0, col0; 
  
  assign row0 = sum_dr[sumd_int-1] ? (pr-wnr - abs_sum_dr ) : (pr-wnr + abs_sum_dr ); 
  assign col0 = sum_dc[sumd_int-1] ? (pc-wnc - abs_sum_dc -1) : (pc-wnc + abs_sum_dc -1); 

//  assign row0 = sum_dr[sumd_int-1] ? (pr-wnr - abs_sum_dr) : (pr-wnr + abs_sum_dr); 
//  assign col0 = sum_dc[sumd_int-1] ? (pc-wnc - abs_sum_dc) : (pc-wnc + abs_sum_dc); 
  
//  assign row1 = sum_dr[sumd_int-1] ? (pr-wnr - abs_sum_dr -1) : (pr-wnr + abs_sum_dr -1); 
  
//  assign row2 = sum_dr[sumd_int-1] ? (pr-wnr - abs_sum_dr -1) : (pr-wnr + abs_sum_dr -1); 
  
//  assign row3 = sum_dr[sumd_int-1] ? (pr-wnr - abs_sum_dr -1) : (pr-wnr + abs_sum_dr -1); 

  
//  assign row0 = sum_dr[sumd_int-1] ? (pr-wnr - abs_sum_dr ) : (pr-wnr + abs_sum_dr ); 
//  assign col0 = sum_dc[sumd_int-1] ? (pc-wnc - abs_sum_dc ) : (pc-wnc + abs_sum_dc ); 


   //to handle boundary conditions: using zero padding
  wire out_of_bound0,out_of_bound1, out_of_bound2, out_of_bound3; 
  wire out_of_bound4,out_of_bound5, out_of_bound6, out_of_bound7; 
  
    // To read data from FIFO
  always@(posedge clk, posedge rst) begin
      if(rst | window_done) begin
      r_ptr0 <= 0; //read pointer is set to 1 cuz in this project, the first and last fifo element must be ignored 
      r_ptr1 <= 0; 
      r_ptr2 <= 0; //when reset, r_ptrs point to first element of first 3 rows
      r_ptr3 <= 0;
      data_out0 <= 0; //has an inferred latch, which is intentional
      data_out1 <= 0;
      data_out2 <= 0;
      data_out3 <= 0;
    end
    else
     if(load_addr) begin
/*      r_ptr0 <= sum_dr[sumd_int-1] ? ((pr-wnr - abs_sum_dr -1)*cols + (pc-wnc - abs_sum_dc -1)) : ((pr-wnr + abs_sum_dr -1)*cols + (pc-wnc + abs_sum_dc -1)); //read pointer is set to 1 cuz in this project, the first and last fifo element must be ignored 
      r_ptr1 <= sum_dr[sumd_int-1] ? ((pr-wnr - abs_sum_dr -1)*cols + cols + (pc-wnc - abs_sum_dc -1)) : ((pr-wnr + abs_sum_dr -1)*cols + cols + (pc-wnc + abs_sum_dc -1)); 
      r_ptr2 <= sum_dr[sumd_int-1] ? ((pr-wnr - abs_sum_dr -1)*cols + 2*cols + (pc-wnc - abs_sum_dc -1)) : ((pr-wnr + abs_sum_dr -1)*cols + 2*cols + (pc-wnc + abs_sum_dc -1)); //when reset, r_ptrs point to first element of first 3 rows
      r_ptr3 <= sum_dr[sumd_int-1] ? ((pr-wnr - abs_sum_dr -1)*cols + 3*cols + (pc-wnc - abs_sum_dc -1)) : ((pr-wnr + abs_sum_dr -1)*cols + 3*cols + (pc-wnc + abs_sum_dc -1));   
      */
      r_ptr0 <= 1+row0*cols + col0; //read pointer is set to 1 cuz in this project, the first and last fifo element must be ignored 
      r_ptr1 <= 1+(row0)*cols + col0 + cols; 
      r_ptr2 <= 1+(row0)*cols + col0 + 2*cols; //when reset, r_ptrs point to first element of first 3 rows
      r_ptr3 <= 1+(row0)*cols + col0 + 3*cols; 
    end 
    else
     if(r_en) begin
      data_out0 <= out_of_bound0 ? {{DATA_WIDTH{1'b0}},{DATA_WIDTH{1'b0}}} : ( out_of_bound4 ? {fifo[r_ptr0],{DATA_WIDTH{1'b0}}} : {fifo[r_ptr0], fifo[r_ptr0+1]} ); //{row_ele0, row_ele1}
      r_ptr0 <= r_ptr0 + sum;
      
      data_out1 <= out_of_bound1 ? {{DATA_WIDTH{1'b0}},{DATA_WIDTH{1'b0}}} : ( out_of_bound5 ? {fifo[r_ptr1],{DATA_WIDTH{1'b0}}} : {fifo[r_ptr1], fifo[r_ptr1+1]} );
      r_ptr1 <= r_ptr1 + sum;
      
      data_out2 <= out_of_bound2 ? {{DATA_WIDTH{1'b0}},{DATA_WIDTH{1'b0}}} : ( out_of_bound6 ? {fifo[r_ptr2],{DATA_WIDTH{1'b0}}} : {fifo[r_ptr2], fifo[r_ptr2+1]} );
      r_ptr2 <= r_ptr2 + sum;
      
      data_out3 <= out_of_bound3 ? {{DATA_WIDTH{1'b0}},{DATA_WIDTH{1'b0}}} : ( out_of_bound7 ? {fifo[r_ptr3],{DATA_WIDTH{1'b0}}} : {fifo[r_ptr3], fifo[r_ptr3+1]} );
      r_ptr3 <= r_ptr3 + sum;
    end
     else begin
      data_out0 <= data_out0; //{row_ele0, row_ele1}
      r_ptr0 <= r_ptr0;
      
      data_out1 <= data_out1;
      r_ptr1 <= r_ptr1;
      
      data_out2 <= data_out2;
      r_ptr2 <= r_ptr2;
      
      data_out3 <= data_out3;
      r_ptr3 <= r_ptr3 ;
    end
    
  end
  

  assign row_done = col_count == 4'd6; //0 to 6, mod8 counter  --> to get 8 cols
    
//  assign window_done = (row_count == 4'd4) && (col_count == 4'd6) ; //all 8 rows displayed
//  assign window_done = (row_count == 4'd5) && (col_count == 4'd6) ; //dr is excellent but dc is giving too much error --> even after removing the delay element for Ic that was causing so much error
  assign window_done = (row_count == 4'd6) && (col_count == 4'd6) ; //gives the best result till now for both dr and dc
 //even logically, the last case makes more sense
 
 //this logic gives output zero only when r_ptr is out of bounds
 //if r_ptr + 1 is out of bound, it gives an x (to solve that, another mux needs to added for each output)
  
//  assign out_of_bound0 = (r_ptr0 < 0) || (r_ptr0 > (rows*cols));  
//  assign out_of_bound1 = (r_ptr1 < 0) || (r_ptr1 > (rows*cols));  
//  assign out_of_bound2 = (r_ptr2 < 0) || (r_ptr2 > (rows*cols));  
//  assign out_of_bound3 = (r_ptr3 < 0) || (r_ptr3 > (rows*cols));  
  
//  assign out_of_bound4 =  ((r_ptr0+1) > (rows*cols));  
//  assign out_of_bound5 =  ((r_ptr1+1) > (rows*cols));  
//  assign out_of_bound6 =  ((r_ptr2+1) > (rows*cols));  
//  assign out_of_bound7 =  ((r_ptr3+1) > (rows*cols));  

localparam LAST = rows*cols - 1;

assign out_of_bound0 = (r_ptr0 < 0) || (r_ptr0 > LAST);
assign out_of_bound1 = (r_ptr1 < 0) || (r_ptr1 > LAST);
assign out_of_bound2 = (r_ptr2 < 0) || (r_ptr2 > LAST);
assign out_of_bound3 = (r_ptr3 < 0) || (r_ptr3 > LAST);

assign out_of_bound4 = ((r_ptr0+1) > LAST);
assign out_of_bound5 = ((r_ptr1+1) > LAST);
assign out_of_bound6 = ((r_ptr2+1) > LAST);
assign out_of_bound7 = ((r_ptr3+1) > LAST);
  
  
  
// assign window_done = (row_count == 4'd5)  ; 
   
 //assume this is a linear fifo - not circular
  
/*  assign full = 
      ((w_ptr+1) == r_ptr0) ||
    ((w_ptr+1) == r_ptr1) ||
    ((w_ptr+1) == r_ptr2) ||
    ((w_ptr+1) == r_ptr3); //read and write points are next to each other
    
  assign empty =  
    (w_ptr == r_ptr0) ||
    (w_ptr == r_ptr1) ||
    (w_ptr == r_ptr2) ||
    (w_ptr == r_ptr3);*/
    
    
    //it's a linear fifo, one direction only
  assign full = (w_ptr == DEPTH-1); //read and write points are next to each other
    
  assign empty =  (w_ptr == 0); 
    
endmodule


//idea: 2 row elements at a time, 4 elements of a col at a time
//the result would be 3 interpolated intensity values
