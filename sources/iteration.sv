`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////


module iteration
#(parameter
//k_thresh = 1,
max_d = 32, //Q10.32
max_sumd = max_d+4,
sumd_frac = 26,
sumd_int = 6, 
max_sumd_frac = 10)//this is based on the interp module's fractional bits --> i've fixed it to 10 for now
(
input clk, reset, enable, //connect en to valid_det signal from it_b_ginv module
input shift_d, //connected to wrapper port of same name
input signed [max_d-1:0] dr, dc, //given as input to this module from it_b_ginv
output reg signed [max_sumd-1:0] sum_dr, sum_dc, //extra bits to include overflow if any
//comment out sum_dr and sum_dc when running layer2_d testbench
output wire signed [sumd_int-1:0] sumdr_int, sumdc_int, //needs to go to fifo module (to read diff patch of image2 --> to find different It)
output wire signed [max_sumd_frac-1:0] rounded_sumdr_frac, rounded_sumdc_frac); //this needs to go to interp module
    
//reg signed [max_sumd-1:0] sum_dr, sum_dc;


//accumulator
always@(posedge clk, posedge reset)
begin
    if(reset)
    begin
        sum_dr <= {max_sumd{1'b0}}; 
        sum_dc <= {max_sumd{1'b0}};
    end
    else if(enable)
    begin
        sum_dr <= sum_dr + {{4{dr[max_d-1]}}, dr}; 
        sum_dc <= sum_dc + {{4{dc[max_d-1]}}, dc};
//        sum_dr <= sum_dr + {dr}; 
//        sum_dc <= sum_dc + {dc};
    end
    else if(shift_d)
    begin 
        sum_dr <= (sum_dr<<1); 
        sum_dc <= (sum_dc<<1);
    end 
    else
    begin
        sum_dr <= sum_dr; 
        sum_dc <= sum_dc;
    end   
end



//get the absolute value first
wire signed [max_sumd-1:0]abs_sum_dr, abs_sum_dc; 

assign abs_sum_dc = sum_dc[max_sumd-1] ? -sum_dc : sum_dc; 
assign abs_sum_dr = sum_dr[max_sumd-1] ? -sum_dr : sum_dr;

//split the sum into int and fractional part
wire [sumd_int-1:0] abs_sumdr_int, abs_sumdc_int;
wire [sumd_frac-1:0] sumdr_frac, sumdc_frac; //(fraction is always positive --> for this project atleast)

assign {abs_sumdr_int, sumdr_frac} = abs_sum_dr; 
assign {abs_sumdc_int, sumdc_frac} = abs_sum_dc;

//propagating the sign 
//wire signed [sumd_int-1:0] sumdr_int, sumdc_int; 

assign sumdr_int = (abs_sumdr_int == 0) ? {sumd_int{1'b0}} : (sum_dr[max_sumd-1] ? -abs_sumdr_int : abs_sumdr_int); //will go to the fifo module (of image2) 
assign sumdc_int = (abs_sumdc_int == 0) ? {sumd_int{1'b0}} : (sum_dc[max_sumd-1] ? -abs_sumdc_int : abs_sumdc_int);

//assign sumdr_int =  (sum_dr[max_sumd-1] ? -abs_sumdr_int : abs_sumdr_int); //will go to the fifo module (of image2) 
//assign sumdc_int =  (sum_dc[max_sumd-1] ? -abs_sumdc_int : abs_sumdc_int);


//I don't need negative fraction for anything
//but I need to convert 26 bits into 10 bits of fraction

localparam OLD_FRAC = sumd_frac; //26
localparam NEW_FRAC = max_sumd_frac; //10
localparam DROP = OLD_FRAC - NEW_FRAC;        // 16
localparam ROUND_BIT = DROP - 1;              // 15

// Add rounding constant for "round-to-nearest"
//wire signed [sumd_frac-1:0] rounded_sumdr_frac;
//assign rounded_sumdr_frac = sumdr_frac + (sumdr_frac[ROUND_BIT] << DROP); //if 15th bit is 1, add 1 at 16th place, else nothing
//the above is too complex, just do this:

//wire signed [NEW_FRAC-1:0] rounded_sumdr_frac, rounded_sumdc_frac; 

assign rounded_sumdr_frac = sumdr_frac[(OLD_FRAC-1)-:NEW_FRAC] + sumdr_frac[ROUND_BIT];
assign rounded_sumdc_frac = sumdc_frac[(OLD_FRAC-1)-:NEW_FRAC] + sumdc_frac[ROUND_BIT];


endmodule
