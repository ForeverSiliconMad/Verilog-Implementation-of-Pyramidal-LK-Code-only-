`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//clock division module --works

module clk_divide(
input clk, reset,
output clk_by2, clk_by4);

reg q1, q2; 

//TFF 1 (TFF eqn: t^q = in) - input is the clk
always@(posedge clk, posedge reset)
begin
    if(reset)
        q1 <= 1'b0;
    else
        q1 <= ~q1; 
end

//TFF 2
always@(posedge q1, posedge reset)
begin
    if(reset)
        q2 <= 1'b0;
    else
        q2 <= ~q2; 
end

assign clk_by2 = q1; 
assign clk_by4 = q2; 

endmodule


