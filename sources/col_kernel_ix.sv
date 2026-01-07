`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//remember col_kernel is used to find Ix 

//central diff col kernel = ([-1 0 1]/2)^T (transpose)

module col_kernel_ix(
input clk, reset,
input [11:0] row0_pixel,
input [11:0] row2_pixel,
output signed [15:0] pixel_Ix);
    

wire [11:0] temp1, temp2, temp3;
reg [15:0] out0, out2;

//find magnitude first and then negate it 

assign temp1 = row0_pixel>>1; //divide by 2 is right shift by 1
assign {cout, temp2} = -temp1; 

always@(posedge clk, posedge reset)
begin
    if(reset)
        out0 <= 0; 
    else
        out0 <= {{4{temp2[11]}}, temp2};   //same as just skipping the use of temp3 really - no diff in synthesis
end


//bottom cell 
assign temp3 = row2_pixel>>1; //divide by 2 is right shift by 1

//assign temp4 = (cout) ? {8'd255, 4'd0} : temp3; //this isn't required cuz we're doing signed addition now, so cout doesn't indicate overflow (for more details - cod)

always@(posedge clk, posedge reset)
begin
    if(reset)
        out2 <= 0; 
    else
        out2 <= {{4{temp3[11]}}, temp3};   //same as just skipping the use of temp3 really - no diff in synthesis
end

assign pixel_Ix = out0 + out2;



endmodule
