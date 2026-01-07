`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//generates the pyramid and puts it to the layer fifo
//address generator interfaces the image memory and this module, it must not be instantiated here

//assume pixel_in is in Q8.4 form
//pixel_in is given after bilinear interpolation if present

//perhaps include read enable signals for the pyramid later?

module pyramid_gen
(
input clk, reset, addr_en, row_done, //the addr_en signal is same as for address_gen module
//input counter_reset, //it must be reset after the patch is done --> it must come from the fsm
//as soon as valid addresses are generated, pixels will start streaming in
input [7:0] pixel_in, //keep it 8 bit
output reg [7:0] pixout0,
//output reg [7:0] pixout1, pixout2, //pixels for each layer fifo
output w_en0, w_en1, w_en2
);



/*
wire clk1, clk2; //clk1 is for layer1 and clk2 is for layer2

//instantiate this where the layer fifos are present
//produce the clocks with different frequencies
clk_divide dut1(
.clk(clk), 
.reset(reset | ~addr_en),
.clk_by2(clk1), 
.clk_by4(clk2));

//DFF1
always@(posedge clk, posedge reset)
begin
    if(reset)
    pixout0 <= 8'd0;
    else if(addr_en)
    pixout0 <= pixel_in; 
    else 
    pixout0 <= pixout0; 
end



//DFF2
always@(posedge clk1, posedge reset)
begin
    if(reset)
    pixout1 <= 8'd0;
    else if(addr_en)
    pixout1 <= pixel_in; 
    else 
    pixout1 <= pixout1; 
end

//DFF2
always@(posedge clk2, posedge reset)
begin
    if(reset)
    pixout2 <= 8'd0;
    else if(addr_en)
    pixout2 <= pixel_in; 
    else 
    pixout2 <= pixout2; 
end*/

//I also need to generate write enable signal for each layer fifo, so I'll use a counter that starts from -1 and then 0 to 3
//when count is even, write enable fifo1, when count is 00 (multiple of 4), write enable fifo2 
//this is important cuz only if write enable is on, fifo writes into the fifo and increments the write counter automatically

reg [1:0] count;

assign pixout0 = pixel_in; 



//col_counter
always@(posedge clk, posedge reset)
begin
    if(reset)
        count <= 2'd0;
    else if(addr_en)
        count <= count + 2'd1; 
    else
        count <= count; 
end

//get a row_counter to skip rows
reg [1:0] row_count;

always@(posedge clk, posedge reset)
begin
    if(reset)
        row_count <= 2'd0;
    else if(row_done)
        row_count <= row_count + 2'd1; 
    else
        row_count <= row_count; 
end

assign w_en0 = addr_en; 
assign w_en1 = addr_en ? (~(count[0] | row_count[0])) : 0; //write if both row_counter and col_counter is even
assign w_en2 = addr_en ? (count==2'd0 & row_count==2'd0) : 0; //write if both row_counter and col_counter is 00

endmodule