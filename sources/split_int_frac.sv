/*`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module split_int_frac(
input 
    );
    
    // -------------------------------------------
// Split into magnitude integer + fractional
// -------------------------------------------
wire signed [d_limit_bits-1:0] abs_dx, abs_dy;

assign abs_dx = sum_dx[d_limit_bits-1] ? -sum_dx : sum_dx;
assign abs_dy = sum_dy[d_limit_bits-1] ? -sum_dy : sum_dy;

// Integer part = upper bits
wire [int_bits-1:0] dx_int  = abs_dx[d_limit_bits-1 -: int_bits];
wire [int_bits-1:0] dy_int  = abs_dy[d_limit_bits-1 -: int_bits];

// Fractional part = lower bits
wire [frac_bits-1:0] dx_frac = abs_dx[frac_bits-1:0];
wire [frac_bits-1:0] dy_frac = abs_dy[frac_bits-1:0];


// -------------------------------------------
// Compute new (x0, y0)
// -------------------------------------------
// dx shifts Y coordinate, dy shifts X coordinate

wire signed [colbits:0] x_tmp =
    sum_dy[d_limit_bits-1] ? (x - dy_int) : (x + dy_int);

wire signed [rowbits:0] y_tmp =
    sum_dx[d_limit_bits-1] ? (y - dx_int) : (y + dx_int);


// -------------------------------------------
// Boundary check (feature lost)
// -------------------------------------------
assign feature_loss =
    (x_tmp < 0) | (x_tmp >= cols) |
    (y_tmp < 0) | (y_tmp >= rows);

assign x0 = feature_loss ? {colbits{1'b0}} : x_tmp[colbits-1:0];
assign y0 = feature_loss ? {rowbits{1'b0}} : y_tmp[rowbits-1:0];


// -------------------------------------------
// Convert fractional part to Q0.10
// -------------------------------------------
wire [10:0] dx_q10 = {1'b0, dx_frac[frac_bits-1 -: 10]};
wire [10:0] dy_q10 = {1'b0, dy_frac[frac_bits-1 -: 10]};


// -------------------------------------------
// Bilinear interpolation weights (Q2.20)
// -------------------------------------------
localparam ONE_Q10 = 1024; // 1.0000000000 in Q0.10

assign w00 = (ONE_Q10 - dx_q10) * (ONE_Q10 - dy_q10);
assign w10 = (dx_q10)         * (ONE_Q10 - dy_q10);
assign w01 = (ONE_Q10 - dx_q10) * (dy_q10);
assign w11 = (dx_q10)         * (dy_q10);

endmodule
*/