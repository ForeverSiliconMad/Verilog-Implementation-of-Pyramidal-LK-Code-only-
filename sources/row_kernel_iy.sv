`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//remember row_kernel is used to find Iy 

//central diff row kernel = [-1 0 1]/2

module row_kernel_iy(
input clk, reset,
input [11:0] pixel_in,
output signed [15:0] pixel_Iy);
    


wire signed [11:0] temp1, temp2, temp3;
reg signed [15:0] out0, out1, out2;


//find magnitude first and then negate it 

assign temp1 =  (pixel_in>>1); //divide by 2 is right shift by 1
assign {cout, temp2} = -temp1; 

always@(posedge clk, posedge reset)
begin
    if(reset)
        out0 <= 16'd0; 
    else
        out0 <= {{4{temp2[11]}}, temp2};   //same as just skipping the use of temp3 really - no diff in synthesis
end


//out1 = ()*0+out0 --> this is basically a dff 
always@(posedge clk, posedge reset)
begin
    if(reset)
        out1 <= 16'd0;
    else
        out1 <= out0; 
end 



assign temp3 = (pixel_in>>1) + out1; //divide by 2 is right shift by 1

//assign temp4 = (cout) ? {8'd255, 4'd0} : temp3; //this isn't required cuz we're doing signed addition now, so cout doesn't indicate overflow (for more details - cod)

always@(posedge clk, posedge reset)
begin
    if(reset)
        out2 <= 16'd0; 
    else
        out2 <= {{4{temp3[11]}}, temp3};   //same as just skipping the use of temp3 really - no diff in synthesis
end

assign pixel_Iy = out2;



endmodule
