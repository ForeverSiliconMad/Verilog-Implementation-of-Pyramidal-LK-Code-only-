`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//the inputs for image1 would be max 0.25 (1/4), cuz r,c are initially integers only
//and naturally, Q.2 * Q.2 = Q.4, (after multiplication)
//assume proper fraction has been extracted externally and given as input here

module img1_bi_interp
#(parameter
frac_bits = 2)
(
input [15:0] row0_ele, row1_ele,
input [frac_bits-1:0] frac_r, frac_c, //fractional part of the optical flow vectors
output [11:0] interp_I); //this has to be Q8.4 format --> inputs are always +ve, so output is also always +ve

//row_ele is of the form: {col0, col1} 
wire [7:0] ele00, ele01, ele10, ele11; 

//wire is_equal; 

//assign is_equal = (ele00 & ele01 & ele10 & ele11) == (ele00) ; //if all intensities are equal, output is that intensity value
// perform this check outside the module


assign {ele00, ele01} = row0_ele;
assign {ele10, ele11} = row1_ele;

wire [2*frac_bits+1:0]w00, w01, w10, w11;

//calculate weights of the form Q2.20
assign w00 = ((1'b1<<frac_bits) - frac_r) * ((1'b1<<frac_bits) - frac_c); // (1-x)(1-y) (11 bits + 11 bits = 22 bits in total)
assign w10 = (frac_r) * ((1'b1<<frac_bits) - frac_c);      // x(1-y)
assign w01 = ((1'b1<<frac_bits) - frac_r) * (frac_c);      // (1-x)y
assign w11 = (frac_r) * (frac_c); 

wire [7+2*frac_bits+4:0] temp_I; //8 bits + fractional bits (after mult)

assign temp_I = ele00*w00 + ele10*w10 + ele01*w01 + ele11*w11;

assign interp_I = (2*frac_bits > 4) ? (temp_I >> (2*frac_bits - 4)) : (temp_I << (4 - 2*frac_bits)); //get it down to 4 fractional bits always

endmodule
