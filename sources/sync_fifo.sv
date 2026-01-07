`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//synchronous fifo (instead of RAM)
//it's circular in nature, naturally
//both pointers can move in a single direction only

//This module is inferring RAM in the synthesis schematic


module sync_fifo 
#(parameter DEPTH=2048, DATA_WIDTH=8) (
  input clk, rst, //active high reset
  input w_en, r_en, 
  input [DATA_WIDTH-1:0] data_in,
  output reg [DATA_WIDTH-1:0] data_out,
  output full, empty
);
  
  reg [$clog2(DEPTH)-1:0] w_ptr, r_ptr;
  reg [DATA_WIDTH-1:0] fifo[DEPTH];
  
  // Set Default values on reset.
  always@(posedge clk, posedge rst) begin
    if(rst) begin
      w_ptr <= 0; r_ptr <= 0; //when reset is asserted, the values in fifo are not reset to zero, only the pointers are
      data_out <= 0; //has an inferred latch, which is intentional
    end
  end
  
  // To write data to FIFO
  always@(posedge clk) begin
    if(w_en & !full)begin //if fifo is write enabled and not full, write into the fifo, else keep the prev value in
      fifo[w_ptr] <= data_in; //fifo[w_ptr] and w_ptr --> latch intentional
      w_ptr <= w_ptr + 1;
    end
  end
  
  // To read data from FIFO
  always@(posedge clk) begin
    if(r_en & !empty) begin
      data_out <= fifo[r_ptr];
      r_ptr <= r_ptr + 1;
    end
  end
  
  assign full = ((w_ptr+1'b1) == r_ptr); //read and write points are next to each other
  assign empty = (w_ptr == r_ptr);
endmodule
