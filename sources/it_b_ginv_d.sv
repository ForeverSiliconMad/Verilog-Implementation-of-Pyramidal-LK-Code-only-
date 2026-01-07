`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////



module it_b_ginv_d
#(parameter 
rows = 436,
cols = 1024,
imsize = rows*cols,
rowbits = $clog2(rows), //log2(rows) where rows = number of rows in image
colbits = $clog2(cols) //log2(cols) where cols = number of cols in iamge
)
(
    input  clk,
    input  reset,
    input  start,
    input  [rowbits-1:0] r_fp,
    input  [colbits-1:0] c_fp,
    output patch_done,
    output invalid_addr, 
    output busy
);

    
    
       // ============================================================
    // PARAMETERS
    // ============================================================
    localparam pr     = 16;
    localparam pc     = 16;
//    localparam rows   = 436;
//    localparam cols   = 1024;
    localparam imbits = $clog2(rows*cols);
//    localparam rowbits = $clog2(rows);
//    localparam colbits = $clog2(cols);
    localparam IMAGE_SIZE = rows * cols;
    
//    localparam rows   = 33;
//    localparam cols   = 33;

    // fractional widths
    localparam FRAC1_BITS = 2;      // small frac bits used elsewhere
    localparam FRAC2_BITS = 10;    // used for frac3, frac4 (as requested)

    // iteration/accumulator widths (matching your iteration module)
    localparam MAX_D = 32;
    localparam MAX_SUMD = MAX_D+4;
    localparam SUMD_FRAC = 26;
    localparam SUMD_INT = 6;
    localparam MAX_SUMD_FRAC = 10;

    localparam FRAC_BITS = 2; // interpolation fractional bits (kept for compatibility)

    // ============================================================
    // DUT INPUTS / TB SIGNALS
    // ============================================================
/*    reg clk, reset;
    reg start;
    reg [rowbits-1:0] r_fp;
    reg [colbits-1:0] c_fp;*/

    wire addr_en; 
    wire ginv_en;
    wire valid_det; 
    wire drdc_en; 
    wire fifo0_irv, fifo0_icv;
    wire fifo1_irv, fifo1_icv;
    wire fifo2_irv, fifo2_icv;
    
    
    wire shift_d; 
    wire col_count_en;
    wire [imbits-1:0] start_address;
    //wire busy;

    // DUT OUTPUTS
    wire rowdone;
//    wire patch_done;
//    wire invalid_addr;
    wire [imbits-1:0] addr;

    // IMAGE MEMORY
    reg [7:0] im1 [0:IMAGE_SIZE-1];
    reg [7:0] im2 [0:IMAGE_SIZE-1];

    // PYRAMID GEN OUTPUTS
    wire [7:0] pixout0;
    wire w_en0, w_en1, w_en2;

    // read enable from wrapper
    wire r_en;
    wire b_reset, b_en; 
    wire fifo0_r_en, fifo1_r_en, fifo2_r_en; 
    wire imgrad_en0, imgrad_en1, imgrad_en2;
    wire imgrad_rst0, imgrad_rst1, imgrad_rst2;
    //wire load_addr;
    wire load_addr0, load_addr1, load_addr2;
    
    // FIFO window done signals
    wire wn_done0, wn_done1, wn_done2;

    // ============================================================
    // FIFO INSTANCES (same ports as your TB)
    // ============================================================
    // FIFO0
    wire fifo0_full, fifo0_empty;
    wire [15:0] fifo0_dout0, fifo0_dout1, fifo0_dout2, fifo0_dout3;

//    multi_ptr_fifo_interp #(
//        .DEPTH(2048),
//        .DATA_WIDTH(8),
//        .cols(33),
//        .rows(33),
//        .pr(16),
//        .pc(16),
//        .wnr(3),
//        .wnc(3)
//    ) fifo0 (
//        .clk(clk),
//        .rst(reset),
//        .w_en(w_en0),
//        .r_en(fifo0_r_en),
//        .load_addr(load_addr0),
//        .data_in(im1[addr]),
//        .sum_dr(0),
//        .sum_dc(0),
//        .data_out0(fifo0_dout0),
//        .data_out1(fifo0_dout1),
//        .data_out2(fifo0_dout2),
//        .data_out3(fifo0_dout3),
//        .full(fifo0_full),
//        .empty(fifo0_empty),
//        .window_done(wn_done0)
//    );

    // FIFO1
    wire fifo1_full, fifo1_empty;
    wire [15:0] fifo1_dout0, fifo1_dout1, fifo1_dout2, fifo1_dout3;

//    multi_ptr_fifo_interp #(
//        .DEPTH(2048),
//        .DATA_WIDTH(8),
//        .cols(17),
//        .rows(17),
//        .pr(8),
//        .pc(8),
//        .wnr(3),
//        .wnc(3)
//    ) fifo1 (
//        .clk(clk),
//        .rst(reset),
//        .w_en(w_en1),
//        .r_en(fifo1_r_en),
//        .load_addr(load_addr1),
//        .data_in(pixout0),
//        .sum_dr(0),
//        .sum_dc(0),
//        .data_out0(fifo1_dout0),
//        .data_out1(fifo1_dout1),
//        .data_out2(fifo1_dout2),
//        .data_out3(fifo1_dout3),
//        .full(fifo1_full),
//        .empty(fifo1_empty),
//        .window_done(wn_done1)
//    );

    // FIFO2 (connects to iteration.sumdr_int / sumdc_int)
    wire fifo2_full, fifo2_empty;
    wire [15:0] fifo2_dout0, fifo2_dout1, fifo2_dout2, fifo2_dout3;

    // wires for iteration outputs to connect to fifos
    wire signed [SUMD_INT-1:0] sumdr_int, sumdc_int;
    wire signed [MAX_SUMD_FRAC-1:0] rounded_sumdr_frac, rounded_sumdc_frac;
    

//    multi_ptr_fifo_interp #(
//        .DEPTH(2048),
//        .DATA_WIDTH(8),
//        .cols(9),
//        .rows(9),
//        .pr(4),
//        .pc(4),
//        .wnr(3),
//        .wnc(3)
//    ) fifo2 (
//        .clk(clk),
//        .rst(reset),
//        .w_en(w_en2),
//        .r_en(fifo2_r_en),
//        .load_addr(load_addr2),
//        .data_in(pixout0),
//        .sum_dr(0),      // connected to iteration.sumdr_int
//        .sum_dc(0),      // connected to iteration.sumdc_int
//        .data_out0(fifo2_dout0),
//        .data_out1(fifo2_dout1),
//        .data_out2(fifo2_dout2),
//        .data_out3(fifo2_dout3),
//        .full(fifo2_full),
//        .empty(fifo2_empty),
//        .window_done(wn_done2)
//    );

    // ============================================================
    // Wrapper/address/pyramid (instantiate as in your TB)
    // ============================================================
    // frac1/2 small fractional outputs (2 bits)
    wire [FRAC_BITS-1:0] frac1_r, frac1_c;
    wire [FRAC_BITS-1:0] frac2_r, frac2_c;
    // frac3/4 (10 bits) as requested
    wire [FRAC2_BITS-1:0] frac3_r, frac3_c;
    wire [FRAC2_BITS-1:0] frac4_r, frac4_c;
    
    reg [1:0] layer; 
    
    wire signed [MAX_D-1:0] dr, dc; // outputs of it_b_ginv (d_limit_bits default 32)

    // wrapper instantiation will be after iteration instantiation to show connections clearly

    wrapper #(
        .pr(pr),
        .pc(pc),
        .rows(rows),
        .cols(cols),
        .imbits(imbits),
        .frac2_bits(FRAC2_BITS) // if wrapper uses this param internally
    ) u_wrap (
        .clk(clk),
        .reset(reset),

        .start(start),
        .r(r_fp),
        .c(c_fp),

        .patch_done(patch_done),
        .invalid_addr(invalid_addr),

        .wn_done0(wn_done0),
        .wn_done1(wn_done1),
        .wn_done2(wn_done2),
        
        // sum fractional inputs from iteration
        .sumdr_frac(rounded_sumdr_frac),
        .sumdc_frac(rounded_sumdc_frac),

        .valid_det(valid_det), // from it_b_ginv (wired later)
        .b_reset(b_reset),

        // dr, dc are required by wrapper for decision making; connect to it_b_ginv outputs
        .dr(dr),
        .dc(dc),

        .r_frac1(frac1_r),
        .c_frac1(frac1_c),
        .r_frac2(frac2_r),
        .c_frac2(frac2_c),
        
        .r_frac3(frac3_r),
        .c_frac3(frac3_c),
        .r_frac4(frac4_r),
        .c_frac4(frac4_c),
        
        .col_count_en(col_count_en),
        .addr_en(addr_en),
        .ginv_en(ginv_en),
        .shift_d(shift_d),
        .start_address(start_address),
        .busy(busy),

        //.load_addr(load_addr),
        .load_addr0(load_addr0),
        .load_addr1(load_addr1),
        .load_addr2(load_addr2),
        
        .read_en(r_en),
        .imgrad_en0(imgrad_en0),
        .imgrad_en1(imgrad_en1),
        .imgrad_en2(imgrad_en2),
        
        .imgrad_rst0(imgrad_rst0),
        .imgrad_rst1(imgrad_rst1),
        .imgrad_rst2(imgrad_rst2),
        
        .fifo0_r_en(fifo0_r_en),
        .fifo1_r_en(fifo1_r_en),
        .fifo2_r_en(fifo2_r_en),
        
        .layer(layer),
        .drdc_en(drdc_en),
        //.b_en(b_en),

        .eta_thresh_pass_dr(), .eta_thresh_pass_dc()
    );

    address_gen #(
        .pr(pr),
        .pc(pc),
        .rows(rows),
        .cols(cols)
//        .imbits(imbits)
    ) u_addr (
        .clk(clk),
        .reset(reset),
        .addr_en(addr_en),
        .start_address(start_address),
        .col_count_en(col_count_en),
        .row_done(rowdone),
        .patch_done(patch_done),
        .invalid_addr(invalid_addr),
        .addr(addr)
    );

    pyramid_gen u_pyr (
        .clk(clk),
        .reset(reset),
        .addr_en(addr_en),
        .row_done(rowdone),
        .pixel_in(im1[addr]),
        .pixout0(pixout0),
        .w_en0(w_en0),
        .w_en1(w_en1),
        .w_en2(w_en2)
    );

    // ============================================================
    // Interpolation blocks for IMAGE1
    // Use frac3 for interp11/12/13 (per your request) -> FRAC2_BITS
    // Use frac4 for interp21/22/23 (per your request) -> FRAC2_BITS
    // ============================================================
    wire [11:0] interp11_Q84;
    wire [11:0] interp12_Q84;
    wire [11:0] interp13_Q84;

    wire [11:0] interp21_Q84;
    wire [11:0] interp22_Q84;
    wire [11:0] interp23_Q84;


    img1_bi_interp #(.frac_bits(FRAC1_BITS)) interp1 (
        .row0_ele(fifo1_dout0),
        .row1_ele(fifo1_dout1),
        .frac_r(frac1_r),       
        .frac_c(frac1_c),
        .interp_I(interp11_Q84)
    );

    img1_bi_interp #(.frac_bits(FRAC1_BITS)) interp2 (
        .row0_ele(fifo1_dout1),
        .row1_ele(fifo1_dout2),
        .frac_r(frac1_r),
        .frac_c(frac1_c),
        .interp_I(interp12_Q84)
    );

    img1_bi_interp #(.frac_bits(FRAC1_BITS)) interp3 (
        .row0_ele(fifo1_dout2),
        .row1_ele(fifo1_dout3),
        .frac_r(frac1_r),
        .frac_c(frac1_c),
        .interp_I(interp13_Q84)
    );

    // interp21-23 use frac4 (10 bits)
    img1_bi_interp #(.frac_bits(FRAC1_BITS)) interp4 (
        .row0_ele(fifo2_dout0),
        .row1_ele(fifo2_dout1),
        .frac_r(frac2_r),
        .frac_c(frac2_c),
        .interp_I(interp21_Q84)
    );

    img1_bi_interp #(.frac_bits(FRAC1_BITS)) interp5 (
        .row0_ele(fifo2_dout1),
        .row1_ele(fifo2_dout2),
        .frac_r(frac2_r),
        .frac_c(frac2_c),
        .interp_I(interp22_Q84)
    );

    img1_bi_interp #(.frac_bits(FRAC1_BITS)) interp6 (
        .row0_ele(fifo2_dout2),
        .row1_ele(fifo2_dout3),
        .frac_r(frac2_r),
        .frac_c(frac2_c),
        .interp_I(interp23_Q84)
    );

    // ============================================================
    // Replace old kernels by imgrad instances (updated signature)
    // Convert 8-bit FIFO outputs to 12-bit Q8.4 by appending 4 LSB zeros
    // ============================================================
    wire [11:0] fifo0_p0 = {fifo0_dout0, 4'b0000};
    wire [11:0] fifo0_p1 = {fifo0_dout1, 4'b0000};
    wire [11:0] fifo0_p2 = {fifo0_dout2, 4'b0000};

    // FIFO0 imgrad outputs & valids (updated widths)
    wire signed [15:0] fifo0_Ir, fifo0_Ic, fifo0_delayed_Ic;

    wire signed [31:0] fifo0_ir2, fifo0_ic2, fifo0_iric;

    imgrad imgrad_fifo0 (
        .clk(clk),
        .reset(reset),
        .enable(imgrad_en0), 
        .imgrad_rst(imgrad_rst0),
        .in0(fifo0_p0),
        .in1(fifo0_p1),
        .in2(fifo0_p2),
        .Ir(fifo0_Ir),
        .Ic(fifo0_Ic),
        .delayed_Ic(fifo0_delayed_Ic),
        .ir_valid(fifo0_irv),
        .ic_valid(fifo0_icv),
        .ir2(fifo0_ir2),
        .ic2(fifo0_ic2),
        .iric(fifo0_iric)
    );

    // FIFO1 imgrad: inputs are interpolated Q8.4 (12-bit)
    wire signed [15:0] fifo1_Ir, fifo1_Ic, fifo1_delayed_Ic;

    wire signed [31:0] fifo1_ir2, fifo1_ic2, fifo1_iric;

    imgrad imgrad_fifo1 (
        .clk(clk),
        .reset(reset),
        .enable(imgrad_en1),
        .imgrad_rst(imgrad_rst1),
        .in0(interp11_Q84),
        .in1(interp12_Q84),
        .in2(interp13_Q84),
        .Ir(fifo1_Ir),
        .Ic(fifo1_Ic),
        .delayed_Ic(fifo1_delayed_Ic),
        .ir_valid(fifo1_irv),
        .ic_valid(fifo1_icv),
        .ir2(fifo1_ir2),
        .ic2(fifo1_ic2),
        .iric(fifo1_iric)
    );

    // FIFO2 imgrad: inputs are interpolated Q8.4 (12-bit)
    wire signed [15:0] fifo2_Ir, fifo2_Ic, fifo2_delayed_Ic;

    wire signed [31:0] fifo2_ir2, fifo2_ic2, fifo2_iric;

    imgrad imgrad_fifo2 (
        .clk(clk),
        .reset(reset),
        .enable(imgrad_en2),
        .imgrad_rst(imgrad_rst2),
        .in0(interp21_Q84),
        .in1(interp22_Q84),
        .in2(interp23_Q84),
        .Ir(fifo2_Ir),
        .Ic(fifo2_Ic),
        .delayed_Ic(fifo2_delayed_Ic),
        .ir_valid(fifo2_irv),
        .ic_valid(fifo2_icv),
        .ir2(fifo2_ir2),
        .ic2(fifo2_ic2),
        .iric(fifo2_iric)
    );

    // ============================================================
    // IMAGE 2 
    // ============================================================
    // FIFO window done signals
    wire wn_done4, wn_done5, wn_done6;

    // PYRAMID GEN OUTPUTS
    wire [7:0] pixout02;
    wire w_en4, w_en5, w_en6;

    // ============================================================
    // FIFO INSTANCES (same ports as your TB)
    // ============================================================
    // FIFO4
    wire fifo4_full, fifo4_empty;
    wire [15:0] fifo4_dout0, fifo4_dout1, fifo4_dout2, fifo4_dout3;

//    multi_ptr_fifo_interp #(
//        .DEPTH(2048),
//        .DATA_WIDTH(8),
//        .cols(33),
//        .rows(33),
//        .pr(16),
//        .pc(16),
//        .wnr(3),
//        .wnc(3)
//    ) fifo4 (
//        .clk(clk),
//        .rst(reset),
//        .w_en(w_en4),
//        .r_en(fifo0_r_en),
//        .load_addr(load_addr0),
//        .data_in(pixout02),
//        .sum_dr(sumdr_int),
//        .sum_dc(sumdc_int),
//        .data_out0(fifo4_dout0),
//        .data_out1(fifo4_dout1),
//        .data_out2(fifo4_dout2),
//        .data_out3(fifo4_dout3),
//        .full(fifo4_full),
//        .empty(fifo4_empty),
//        .window_done(wn_done4)
//    );

//    // FIFO5
    wire fifo5_full, fifo5_empty;
    wire [15:0] fifo5_dout0, fifo5_dout1, fifo5_dout2, fifo5_dout3;

 /*   multi_ptr_fifo_interp #(
        .DEPTH(2048),
        .DATA_WIDTH(8),
        .cols(17),
        .rows(17),
        .pr(8),
        .pc(8),
        .wnr(3),
        .wnc(3)
    ) fifo5 (
        .clk(clk),
        .rst(reset),
        .w_en(w_en5),
        .r_en(fifo1_r_en),
        .load_addr(load_addr1),
        .data_in(pixout02),
        .sum_dr(sumdr_int),
        .sum_dc(sumdc_int),
        .data_out0(fifo5_dout0),
        .data_out1(fifo5_dout1),
        .data_out2(fifo5_dout2),
        .data_out3(fifo5_dout3),
        .full(fifo5_full),
        .empty(fifo5_empty),
        .window_done(wn_done5)
    );
*/
    // FIFO6 (connect to iteration outputs as well)
    wire fifo6_full, fifo6_empty;
    wire [15:0] fifo6_dout0, fifo6_dout1, fifo6_dout2, fifo6_dout3;

/*    multi_ptr_fifo_interp #(
        .DEPTH(2048),
        .DATA_WIDTH(8),
        .cols(9),
        .rows(9),
        .pr(4),
        .pc(4),
        .wnr(3),
        .wnc(3)
    ) fifo6 (
        .clk(clk),
        .rst(reset),
        .w_en(w_en6),
        .r_en(fifo2_r_en),
        .load_addr(load_addr2),
        .data_in(pixout02),
        .sum_dr(sumdr_int),   // connected to iteration.sumdr_int
        .sum_dc(sumdc_int),   // connected to iteration.sumdc_int (fixed)
        .data_out0(fifo6_dout0),
        .data_out1(fifo6_dout1),
        .data_out2(fifo6_dout2),
        .data_out3(fifo6_dout3),
        .full(fifo6_full),
        .empty(fifo6_empty),
        .window_done(wn_done6)
    );
*/
    // ============================================================
    // Wrapper/address/pyramid for IMAGE2
    // ============================================================
    pyramid_gen u_pyr2 (
        .clk(clk),
        .reset(reset),
        .addr_en(addr_en),
        .row_done(rowdone),
        .pixel_in(im2[addr]),
        .pixout0(pixout02),
        .w_en0(w_en4),
        .w_en1(w_en5),
        .w_en2(w_en6)
    );

    // ============================================================
    // Interpolation blocks for IMAGE2
    // Use frac3 for interp2_11..13, and frac4 for interp2_21..23
    // ============================================================
    wire [11:0] interp2_01_Q84;
    wire [11:0] interp2_02_Q84;
    wire [11:0] interp2_03_Q84;
    
    wire [11:0] interp2_11_Q84;
    wire [11:0] interp2_12_Q84;
    wire [11:0] interp2_13_Q84;

    wire [11:0] interp2_21_Q84;
    wire [11:0] interp2_22_Q84;
    wire [11:0] interp2_23_Q84;
    
    
    // interp2_11..13 use frac3 (10 bits)
    img1_bi_interp #(.frac_bits(FRAC2_BITS)) interp2_01 (
        .row0_ele(fifo4_dout0),
        .row1_ele(fifo4_dout1),
        .frac_r(frac3_r),
        .frac_c(frac3_c),
        .interp_I(interp2_01_Q84)
    );

    img1_bi_interp #(.frac_bits(FRAC2_BITS)) interp2_02 (
        .row0_ele(fifo4_dout1),
        .row1_ele(fifo4_dout2),
        .frac_r(frac3_r),
        .frac_c(frac3_c),
        .interp_I(interp2_02_Q84)
    );

    img1_bi_interp #(.frac_bits(FRAC2_BITS)) interp2_03 (
        .row0_ele(fifo4_dout2),
        .row1_ele(fifo4_dout3),
        .frac_r(frac3_r),
        .frac_c(frac3_c),
        .interp_I(interp2_03_Q84)
    );

    // interp2_11..13 use frac3 (10 bits)
    img1_bi_interp #(.frac_bits(FRAC2_BITS)) interp2_1 (
        .row0_ele(fifo5_dout0),
        .row1_ele(fifo5_dout1),
        .frac_r(frac3_r),
        .frac_c(frac3_c),
        .interp_I(interp2_11_Q84)
    );

    img1_bi_interp #(.frac_bits(FRAC2_BITS)) interp2_2 (
        .row0_ele(fifo5_dout1),
        .row1_ele(fifo5_dout2),
        .frac_r(frac3_r),
        .frac_c(frac3_c),
        .interp_I(interp2_12_Q84)
    );

    img1_bi_interp #(.frac_bits(FRAC2_BITS)) interp2_3 (
        .row0_ele(fifo5_dout2),
        .row1_ele(fifo5_dout3),
        .frac_r(frac3_r),
        .frac_c(frac3_c),
        .interp_I(interp2_13_Q84)
    );

    // interp2_21..23 use frac4 (10 bits)
    img1_bi_interp #(.frac_bits(FRAC2_BITS)) interp2_4 (
        .row0_ele(fifo6_dout0),
        .row1_ele(fifo6_dout1),
        .frac_r(frac4_r),
        .frac_c(frac4_c),
        .interp_I(interp2_21_Q84)
    );

    img1_bi_interp #(.frac_bits(FRAC2_BITS)) interp2_5 (
        .row0_ele(fifo6_dout1),
        .row1_ele(fifo6_dout2),
        .frac_r(frac4_r),
        .frac_c(frac4_c),
        .interp_I(interp2_22_Q84)
    );

    img1_bi_interp #(.frac_bits(FRAC2_BITS)) interp2_6 (
        .row0_ele(fifo6_dout2),
        .row1_ele(fifo6_dout3),
        .frac_r(frac4_r),
        .frac_c(frac4_c),
        .interp_I(interp2_23_Q84)
    );

    // ============================================================
    // Instantiate it_b_ginv and hook to fifo2 imgrad outputs
    // ============================================================

//b_enable signal, g_11, g_22, g_12, im1 and im2 pixel, ir and delayed Ic all require routing through a mux
//mux to select inputs to it_b_ginv module

wire b_enable;
wire signed [31:0] g_11, g_12, g_22;
wire [11:0] im1_pixel, im2_pixel; //Q8.4
wire signed [15:0] ir, delayed_ic;

assign b_enable = layer[1] ? fifo2_irv : (layer[0] ? fifo1_irv : fifo0_irv); 
assign g_11 = layer[1] ? fifo2_ir2 : (layer[0] ? fifo1_ir2 : fifo0_ir2);
assign g_12 = layer[1] ? fifo2_iric : (layer[0] ? fifo1_iric : fifo0_iric);
assign g_22 = layer[1] ? fifo2_ic2 : (layer[0] ? fifo1_ic2 : fifo0_ic2);
assign im1_pixel = layer[1] ? interp22_Q84 : (layer[0] ? interp12_Q84 : {fifo0_dout1, 4'd0});
assign im2_pixel = layer[1] ? interp2_22_Q84 : (layer[0] ? interp2_12_Q84 : interp2_02_Q84);
assign ir = layer[1] ? fifo2_Ir : (layer[0] ? fifo1_Ir : fifo0_Ir);
assign delayed_ic = layer[1] ? fifo2_delayed_Ic : (layer[0] ? fifo1_delayed_Ic : fifo0_delayed_Ic);


    it_b_ginv itb_inst (
        .clk(clk),
        .reset(reset),
        .b_enable(b_enable),           // from wrapper function
        .b_reset(b_reset),
        .ginv_enable(ginv_en),         // fifo2 window_done
        .g_11(g_11),               // g11 from fifo2 imgrad outputs (signed [31:0])
        .g_12(g_12),              // g12
        .g_22(g_22),               // g22
        .im1_pixel(im1_pixel),       // im1 pixel (from img1 pipeline)
        .im2_pixel(im2_pixel),     // im2 pixel (from img2 pipeline)
        .ir(ir),                  // Ir from fifo2 imgrad (signed [15:0])
        .delayed_ic(delayed_ic),  // delayed Ic from fifo2 imgrad (signed [15:0])
        .dr(dr),
        .dc(dc),
        .valid_det(valid_det)
    );

    // ============================================================
    // Instantiate iteration and connect as requested
    // enable = valid_det
    // dr, dc from it_b_ginv
    // iteration.sumdr_int/sumdc_int -> fifo2 & fifo6 .sum_dr/.sum_dc
    // iteration.rounded_sum*_frac -> wrapper.sumdr_frac/sumdc_frac
    // ============================================================
    
    wire [SUMD_INT-1:0] dr_int, dc_int; 
    
    iteration #(
        .max_d(MAX_D),
        .max_sumd(MAX_SUMD),
        .sumd_frac(SUMD_FRAC),
        .sumd_int(SUMD_INT),
        .max_sumd_frac(MAX_SUMD_FRAC)
    ) iteration_inst (
        .clk(clk),
        .reset(reset),
        .enable(valid_det),
        .shift_d(shift_d),
        .dr(dr),
        .dc(dc),
        .sumdr_int(dr_int),
        .sumdc_int(dc_int),
//        .sumdr_int(sumdr_int),
//        .sumdc_int(sumdc_int),
        .rounded_sumdr_frac(rounded_sumdr_frac),
        .rounded_sumdc_frac(rounded_sumdc_frac)
    );

    assign sumdr_int = drdc_en ? dr_int : {SUMD_INT{1'b0}};
    assign sumdc_int = drdc_en ? dc_int : {SUMD_INT{1'b0}};


endmodule
