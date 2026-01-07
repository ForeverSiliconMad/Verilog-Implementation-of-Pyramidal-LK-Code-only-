`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//7x7 imgradient module

module imgrad(
input clk, reset, enable,  //connected to r_en from the main module --> it must read only when in the correct state
input imgrad_rst,
input [11:0] in0, in1, in2, 
output signed [15:0] Ir, Ic, delayed_Ic, 
output ir_valid, ic_valid,
output signed [31:0] ir2, ic2, iric);



reg [3:0] count; //mod8 counter
wire cnt_rst;  //reset after counting row-wise

assign cnt_rst = (count == 4'd7); 

always@(posedge clk, posedge reset)
begin
    if(reset | ~enable)
        count <= -4'd1;
    else 
    begin
        if(cnt_rst)
            count <= 4'd1; 
        else
            count <= count + 1'b1;
    end
end



assign ir_valid = ((count > 4'd2) && (count < 4'd8)); 
assign ic_valid = ((count > 4'd2) && (count < 4'd8)); //this is giving the best error for both dr and dc
//assign ic_valid = (count > 4'd1) && (count < 4'd7); //this is giving more error than above case for both dr and dc


reg signed [15:0] temp_ir, temp_ic; 

// Row kernels
row_kernel_iy dut0 (.clk(clk), .reset(reset), .pixel_in(in1), .pixel_Iy(temp_ir));


// Col kernels
col_kernel_ix dut1 (.clk(clk), .reset(reset), .row0_pixel(in0), .row2_pixel(in2), .pixel_Ix(temp_ic));


//outputs 
assign Ic = ic_valid ? temp_ic : 16'd0; 
assign Ir = ir_valid ? temp_ir : 16'd0;

/*reg signed [15:0] a; 
wire signed [15:0] b; 

always@(posedge clk, posedge reset)
begin
    if(reset)
        a <= 16'd0;
    else
        a <= Ic; 
end*/

//the data is already delayed by 1 when it's output by the fifo, so delaying it once more gives significant error in dc value --> that's the reason

wire signed [15:0] a; 
wire signed [15:0] b; 

assign a = Ic; 

assign delayed_Ic = a; //delayed Ic signal

//assign a = temp_ic; //Q8.4
assign b = Ir; 

wire signed [31:0] a2, b2, ab; 

assign a2 = a*a;  //Q24.8
assign b2 = b*b; 
assign ab = a*b; 

reg signed [31:0] sum_a2, sum_b2, sum_ab; //Qsomething.8

always@(posedge clk, posedge reset) //global async reset
begin
    if(reset | imgrad_rst)
    begin
        sum_a2 <= 32'd0;
        sum_b2 <= 32'd0;
        sum_ab <= 32'd0;
    end
    else
    begin
        sum_a2 <= sum_a2 + a2;
        sum_b2 <= sum_b2 + b2;
        sum_ab <= sum_ab + ab;
    end
end

assign ic2 = sum_a2; //Q .8
assign ir2 = sum_b2; //Q .8
assign iric = sum_ab; //Q .8

endmodule
