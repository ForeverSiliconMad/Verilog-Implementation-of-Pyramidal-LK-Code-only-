/*`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////


module wrapper(
 );
 
 
 
// -----------------------------
// FIFO INSTANCE
// -----------------------------
wire fifo_full, fifo_empty;
reg  w_en, r_en;
wire [7:0] fifo_data_out;

sync_fifo #(
    .DEPTH(2048),
    .DATA_WIDTH(8)
) fifo_inst1 (
    .clk(clk),
    .rst(reset),
    .w_en(w_en),    //from fsm
    .r_en(r_en),    //from fsm
    .data_in(im1[addr]),      // store pixel from image
    .data_out(fifo_data_out),
    .full(fifo_full),
    .empty(fifo_empty)
);

// -----------------------------
// Instantiate DUT
// -----------------------------
address_gen #(
    .pr(pr),
    .pc(pc),
    .rows(rows),
    .cols(cols),
    .imbits(imbits)
) dut (
    .clk(clk),
    .reset(reset),
    .addr_en(addr_en),      //from fsm
    .start_address(start_address), //from fsm
    .row_count_en(row_count_en), //from fsm
    .col_count_en(col_count_en), //from fsm
    .row_done(rowdone),
    .patch_done(patch_done),
    .invalid_addr(invalid_addr),
    .addr(addr)
    //, .addr_next_row(addr_next_row)
);



endmodule
*/

//perhaps include read enable signals for the pyramid later?

//fsm to generate constrol signals basically

module wrapper
#(parameter 
k_thresh = 6, // and eta = 4 gives the best results //after the boundary conditions were handled using zero padding, this works and the eta logic is also working
//k_thresh = 5, //even with eta = 4, k_thresh = 5 is not giving good results (as good as k_thresh, eta = 6, 4
//but for a test image, any k>6 is giving worse results, even k=6 is the best case and sum_dr is better than sum_dc in terms of accuracy
frac1_bits = 2, //for initial r,c values
frac2_bits = 10, 
dfrac_bits = 26, 
eta_thresh = 4, //for decision making 
//these eta values keep k_thresh = 6
//eta = 0 is bad (no threshold basically)
//eta = 4 is giving excellent results
//eta = 8 is okay, less that the case before
//eta = 12 is same as the case before
//now fix eta = 4, and try reducing k_thresh
d_bits = 32,
pr = 16, //patchsize = 33x33, so 16 = floor(33/2)
pc = 16, 
patch_size = 33*33,
rows = 33,
cols = 33,
imsize = rows*cols,
rowbits = $clog2(rows), //log2(rows) where rows = number of rows in image
colbits = $clog2(cols), //log2(cols) where cols = number of cols in iamge
imbits =$clog2(imsize)//log2(imsize)
)
/*#(parameter 
k_thresh = 2,
frac1_bits = 2, //for initial r,c values
frac2_bits = 10, 
dfrac_bits = 26, 
eta_thresh = 4, //for decision making 
d_bits = 32,
pr = 70, //patchsize = 33x33, so 16 = floor(33/2)
pc = 70, 
patch_size = pr*pc,
rows = 436,
cols = 1024,
imsize = rows*cols,
rowbits = $clog2(rows), //log2(rows) where rows = number of rows in image
colbits = $clog2(cols), //log2(cols) where cols = number of cols in iamge
imbits =$clog2(imsize)//log2(imsize)
)*/
/*#(parameter 
k_thresh = 2,
frac1_bits = 2, //for initial r,c values
frac2_bits = 10, 
dfrac_bits = 26, 
eta_thresh = 4, //for decision making 
d_bits = 32,
pr = 70, //patchsize = 33x33, so 16 = floor(33/2)
pc = 70, 
patch_size = pr*pc,
rows = 376,
cols = 1241,
imsize = rows*cols,
rowbits = $clog2(rows), //log2(rows) where rows = number of rows in image
colbits = $clog2(cols), //log2(cols) where cols = number of cols in iamge
imbits =$clog2(imsize)//log2(imsize)
)*/
(
input clk, reset, start, 
input [rowbits-1:0] r, 
input [colbits-1:0] c, //these are integers only - I get it from the feature point bram (no bilinear interpolation here
input patch_done, invalid_addr,//from addr_gen module
input wn_done0, wn_done1, wn_done2,
//input fifo0_irv, fifo1_irv, fifo2_irv, //from imgrad modules --> this is not working
input [frac2_bits-1:0] sumdr_frac, sumdc_frac, //connected to rounded_sumdr/dc_frac in iteration 
input valid_det, //from it_b_ginv module
input [d_bits-1:0] dr, dc, //to make a decision --> Q6.26
//cuz this is the input to the system
//output reg row_count_en, 
//output load_addr, //for initialising the extraction of 7x7
output load_addr0, load_addr1, load_addr2, //loading address separately
output read_en, //for all 3 fifos
output imgrad_en0, imgrad_en1, imgrad_en2, 
output imgrad_rst0, imgrad_rst1, imgrad_rst2, 
output fifo0_r_en, fifo1_r_en, fifo2_r_en, //these are read enable signals for fifos storing the ix iy values
output col_count_en, addr_en,
output reg [imbits-1:0] start_address,
output [frac1_bits-1:0] r_frac1, c_frac1, r_frac2, c_frac2,
output [frac2_bits-1:0] r_frac3, c_frac3, r_frac4, c_frac4,
output ginv_en, b_reset, shift_d,
//output b_en, //logic wrong 
output eta_thresh_pass_dr, eta_thresh_pass_dc, 
output drdc_en, 
output reg [1:0] layer, //tells which layer the FSM is working on
output busy //busy signal tells the module is at work - this signals needs to be on throughout the process
);


//---------------------------------------------------------
// STATE ENCODING
//---------------------------------------------------------
reg [4:0] current, next;

localparam 
    S_START                = 5'd0,
    S_INIT1                = 5'd1,
    S_EXTRACT_PYR_GEN      = 5'd2,
    S_INIT2                = 5'd3,
    S_FINDG                = 5'd4, 
  //  S_L0_WAIT              = 5'd5, //state where the equation is solved for layer 2
    S_FIND_D_L2            = 5'd5, 
    S_INIT3                = 5'd6, 
    S_L2_ITERATE           = 5'd7,
    S_L2_CHECK             = 5'd8,
    S_INIT4_1              = 5'd9,
    S_INIT4                = 5'd10,
    S_L1_ITERATE           = 5'd11,
    S_L1_CHECK             = 5'd12,
    S_INIT5_1              = 5'd13,
    S_INIT5                = 5'd14,
    S_L0_ITERATE           = 5'd15,
    S_L0_CHECK             = 5'd16,
    S_STOP                 = 5'd17;

//---------------------------------------------------------
// STATE REGISTER
//---------------------------------------------------------
always @(posedge clk or posedge reset) begin
    if (reset)
        current <= S_START;
    else
        current <= next;
end

//k counter
reg [3:0] k;
wire k_en, k_reset;

always@(posedge clk, posedge reset)
begin
    if(reset | k_reset)
    k <= 4'd0;
    else if (k_en)
    k <= k + 4'd1; 
    else
    k <= k; 
end

always@(posedge clk, posedge reset)
begin
    if(reset)
    layer <= 2'd2;
    else if (k_reset) //when k is reset, we go does one layer, so
    layer <= layer - 2'd1; 
    else
    layer <= layer;  
end


//---------------------------------------------------------
// NEXT STATE LOGIC
//---------------------------------------------------------
always @(*) begin
    case (current)

        S_START: begin
            if (start)
                next = S_INIT1;
            else
                next = S_START;
        end

        S_INIT1: begin
            next = S_EXTRACT_PYR_GEN; //may or maynot have an if-else with start signal here
        end

        S_EXTRACT_PYR_GEN: begin
            // run patch extraction + pyramid gen
            // move to init2 when done
            // replace (done_condition) with your real signal
            
            if(invalid_addr)
                next = S_START; 
            else if (patch_done)
                next = S_INIT2;
            else
                next = S_EXTRACT_PYR_GEN;
        end

        S_INIT2: begin       
            next = S_FINDG;
        end
        
        S_FINDG: begin //when I'm finding g for the first time, I can find b too, for layer2 atleast
            //if(wn_done0 & wn_done1 & wn_done2)  //these three are never high at the same time, so, this leads to infinite loop kinda thing
            if(wn_done2) 
            //next = S_L0_WAIT;
            next = S_FIND_D_L2;
            else
            next = S_FINDG; 
                
        end    

/*        S_L0_WAIT: begin 
                
       //assuming wn_done2 and wn_done1 happens together         
            if(wn_done2) //it's the last to be done --> consider that
            next = S_FIND_D_L2;
            else
            next = S_L0_WAIT; 
            
        end*/
        
        S_FIND_D_L2: begin         
            if(valid_det)
            next = S_INIT3;
            else
            next = S_FIND_D_L2;
        end
        
        S_INIT3: begin       
            next = S_L2_ITERATE;
        end
        
       S_L2_ITERATE: begin         
            //basically read from fifo2 (of img1 and img2), findG, findIt, all that
            if(wn_done2)
            next = S_L2_CHECK;
            else
            next = S_L2_ITERATE;
            
        end
        
        
       S_L2_CHECK: begin         
            //check k value, or eta value
/*
            if((k == k_thresh) || (eta_thresh_pass_dr & eta_thresh_pass_dc))
            next = S_INIT4_1;
            else
            next = S_INIT3;*/
            if(valid_det) 
            begin
            if((k == k_thresh) || (eta_thresh_pass_dr & eta_thresh_pass_dc))
            next = S_INIT4_1;
            else
            next = S_INIT3;
            end
            else
            next = S_STOP; 
            
        end
        
        S_INIT4_1: begin       
            next = S_INIT4;
        end

        S_INIT4: begin       
            next = S_L1_ITERATE;
        end
        
       S_L1_ITERATE: begin         
            //basically read from fifo2 (of img1 and img2), findG, findIt, all that
            if(wn_done1)
            next = S_L1_CHECK;
            else
            next = S_L1_ITERATE;
            
        end
        
        
       S_L1_CHECK: begin         
            //check k value, or eta value
/*            if((k == k_thresh) || (eta_thresh_pass_dr & eta_thresh_pass_dc))
            next = S_INIT5_1;
            else
            next = S_INIT4;*/
            if(valid_det)
            begin
            if((k == k_thresh) || (eta_thresh_pass_dr & eta_thresh_pass_dc))
            next = S_INIT5_1;
            else
            next = S_INIT4;
            end
            else
            next = S_STOP; 
            
        end
        
        S_INIT5_1: begin       
            next = S_INIT5;
        end

        S_INIT5: begin       
            next = S_L0_ITERATE;
        end
        
       S_L0_ITERATE: begin         
            //basically read from fifo2 (of img1 and img2), findG, findIt, all that
            if(wn_done0)
            next = S_L0_CHECK;
            else
            next = S_L0_ITERATE;
            
        end
        
        
       S_L0_CHECK: begin         
/*            //check k value, or eta value
            if((k == k_thresh) || (eta_thresh_pass_dr & eta_thresh_pass_dc))
            next = S_STOP;
            else
            next = S_INIT5;*/
            if(valid_det)
            begin
            if((k == k_thresh) || (eta_thresh_pass_dr & eta_thresh_pass_dc))
            next = S_STOP;
            else
            next = S_INIT5;
            end
            else
            next = S_STOP; 
            
        end
        
              
             
        S_STOP: begin
            next = S_START; 
        end

        default: next = S_START;
    endcase
end

//remember it's extremely important to have different case-statements for next state logic and output logic - specially if the outputs are control signals

/*
//use this to better understand where the control signals remain
//---------------------------------------------------------
// OUTPUT LOGIC (MOORE)
//---------------------------------------------------------
always @(*) begin
    // defaults
    col_count_en = 0;
    addr_en      = 0;
    start_address = 0;
    busy = 1; 

    case (current)

        S_START: begin
            busy = 0; 
        end

        S_INIT1: begin
            // Reset counters / prepare initial address
            //start_address = (r-pr)*cols + (c-pc); 
        end

        S_EXTRACT_PYR_GEN: begin
            //enable address generation
            addr_en = 1; 
            //enable counters in addr generators
           // row_count_en = 1;
            col_count_en = 1; 
        end

        S_INIT2: begin
            //disable address generation
            addr_en = 0; 
            //enable counters in addr generators
           // row_count_en = 0;
            col_count_en = 0;  
            load_addr = 1; 
        end

        S_FINDG: begin  
            load_addr = 0; 
            read_en = 1; 
        end 

        S_L0_WAIT: begin       
            next = S_STOP;
            fifo0_r_en = 0; 
            imgrad_en0 = 0; 
        end

        S_FIND_D_L2: begin         
            if(valid_det)
            next = S_STOP;
            else
            next = S_L2_ITERATE;
        end
        
       S_L2_ITERATE: begin         
            //basically read from fifo2 (of img1 and img2)
            if(wn_done2)
            next = S_STOP;
            else
            next = S_L2_ITERATE;
            
        end
        
        S_STOP: begin
            busy = 0; 
        end
    endcase
end*/

assign busy = current != S_START; 
assign addr_en = (current == S_EXTRACT_PYR_GEN);  
assign col_count_en = (current == S_EXTRACT_PYR_GEN); 
//assign load_addr = (current == S_INIT2) || (current == S_INIT3) || (current == S_INIT4) || (current == S_INIT5); 

assign read_en = (current == S_FINDG);  //this enables the read signal for all the fifo's 
//assign imgrad_en0 = (current == S_FINDG) || (current == S_L0_ITERATE);
//assign imgrad_en1 = (current == S_FINDG) || (current == S_L0_WAIT) || (current == S_L1_ITERATE);
//assign imgrad_en2 = (current == S_FINDG) || (current == S_L0_WAIT) || (current == S_L2_ITERATE);

//assign imgrad_en0 = (current == S_FINDG) || (current == S_L0_ITERATE) || (current == S_L0_WAIT);
//assign imgrad_en1 = (current == S_FINDG) ||  (current == S_L1_ITERATE)|| (current == S_L0_WAIT);
//assign imgrad_en2 = (current == S_FINDG) || (current == S_L2_ITERATE) || (current == S_L0_WAIT);

assign imgrad_en0 = (current == S_L0_ITERATE);
assign imgrad_en1 = (current == S_L1_ITERATE);
assign imgrad_en2 = (current == S_FINDG) || (current == S_L2_ITERATE);

assign imgrad_rst0 = (current == S_INIT3) || (current == S_INIT4) || (current == S_INIT5);
assign imgrad_rst1 = (current == S_INIT3) || (current == S_INIT4) || (current == S_INIT5);
assign imgrad_rst2 = (current == S_INIT3) || (current == S_INIT4) || (current == S_INIT5);

//assign fifo0_r_en = (current == S_FINDG) || (current == S_L0_ITERATE)|| (current == S_L0_WAIT);
//assign fifo1_r_en = (current == S_FINDG) || (current == S_L0_WAIT) || (current == S_L1_ITERATE);
//assign fifo2_r_en = (current == S_FINDG) || (current == S_L0_WAIT) || (current == S_L2_ITERATE);

assign fifo0_r_en =  (current == S_L0_ITERATE);
assign fifo1_r_en =  (current == S_L1_ITERATE);
assign fifo2_r_en = (current == S_FINDG)  || (current == S_L2_ITERATE);

assign load_addr = (current == S_INIT2); //once for all fifos
assign drdc_en = current > S_FINDG; 
//assign drdc_en = 1'b1; 

//assign load_addr0 = (current == S_INIT2) || (current == S_INIT5); 
//assign load_addr1 = (current == S_INIT2) || (current == S_INIT4); 
//assign load_addr2 = (current == S_INIT2) || (current == S_INIT3); 

assign load_addr0 =  (current == S_INIT5); 
assign load_addr1 =  (current == S_INIT4); 
assign load_addr2 = (current == S_INIT2) || (current == S_INIT3); 

//assign b_en = (imgrad_en0 & fifo0_irv) | (imgrad_en1 & fifo1_irv) | (imgrad_en1 & fifo2_irv); //logic wrong

assign ginv_en = (current == S_FIND_D_L2) || (current == S_L2_CHECK) || (current == S_L1_CHECK) || (current == S_L0_CHECK);

assign b_reset = (current == S_INIT3) || (current == S_INIT4) || (current == S_INIT5);

assign k_en = valid_det; //is it good?
assign k_reset = (current == S_INIT4_1) || (current == S_INIT5_1);

assign shift_d = (current == S_INIT4_1) || (current == S_INIT5_1); //once you go down the pyramid, you gotta multiple d by 2 --> this signal enables that


//assume r,c are valid always, and thus start address is always valid

always @(posedge clk or posedge reset) begin
    if (reset)
        start_address <= 0;
    else if (current == S_START)
        //start_address <= (r-1-pr)*cols + (c-1-pc); //to account for 0 based indexing 
        start_address <= (r-pr)*cols + (c-pc); //to account for 0 based indexing 
    else
        start_address <= 0; 
end

//I could just feed r-1, c-1 directly, but that removes the 0.5 and 0.25 that an odd number/2 or /4 gives, so?

//generating fractional bits for bilinear interpolation in layer1 and layer2
//integer part not required for image1 --> taken care by sum_dx = -1 and sum_dy = -1

//assign r_frac1 = r[0] ? {r[0], 1'b0} : ({r[0], 1'b0}+2'd2); 
//assign c_frac1 = c[0] ? {c[0], 1'b0} : ({c[0], 1'b0}+2'd2);

//assign r_frac2 = r[0] ? r[1:0] : (r[1:0]+2'd1); 
//assign c_frac2 = c[0] ? c[1:0] : (c[1:0]+2'd1);  

assign r_frac1 =  ({r[0], 1'b0}); 
assign c_frac1 =  ({c[0], 1'b0});

assign r_frac2 =  (r[1:0]); 
assign c_frac2 =  (c[1:0]); 



//--------------------------------------start from this part
//eta (error) is dx, dy itself 
wire signed [d_bits-1:0] eta; 

assign eta = 1 << (dfrac_bits - eta_thresh); 

wire [d_bits-1:0] abs_dr, abs_dc; 

assign abs_dr = dr[d_bits-1] ? -dr : dr; 
assign abs_dc = dc[d_bits-1] ? -dc : dc; 

assign eta_thresh_pass_dr = (k > 0) ? (abs_dr < eta) : 1'b0; //positive and negative, both cases check
assign eta_thresh_pass_dc = (k > 0) ? (abs_dc < eta) : 1'b0;

//assign eta_thresh_pass_dr = (k > 2) ? (dr[d_bits-1] ? (dr > eta) : (dr < eta)) : 1'b0; //positive and negative, both cases check
//assign eta_thresh_pass_dc = (k > 2) ? (dc[d_bits-1] ? (dc > eta) : (dc < eta)) : 1'b0;

//fractional part for image2

assign r_frac3 = (fifo0_r_en | fifo1_r_en) ? sumdr_frac : {frac2_bits{1'b0}}; //for img2 layer0 fifo and layer1 fifo share the same frac_bits signal
assign c_frac3 = (fifo0_r_en | fifo1_r_en) ? sumdc_frac : {frac2_bits{1'b0}};


assign r_frac4 = fifo2_r_en ? sumdr_frac : {frac2_bits{1'b0}};
assign c_frac4 = fifo2_r_en ? sumdc_frac : {frac2_bits{1'b0}};

endmodule
