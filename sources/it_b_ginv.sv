`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

//ensure that when start occurs, x,y are updated

module it_b_ginv
/*#(parameter 
//k_threshold = 4,
d_limit_bits = 32, //Q6.26
d_frac = 26,
d_int = 6,
imsize = 9*9,
col = 9,  
row = 9,
imbits = 7, //log2(imsize) 
colbits = 4, //log2(col)+1 if required
rowbits = 4//log2(row) +1 if required 
) */
#(parameter 
//k_threshold = 4,
d_limit_bits = 32, //Q6.26
d_frac = 26,
d_int = 6
) 
(
input wire clk, reset, b_enable, b_reset, //connected to ir_valid from imgrad  for fifo2 module
input wire ginv_enable, 
input wire signed [31:0] g_11, g_12, g_22, //from the gmatrix module
input wire [11:0] im1_pixel, im2_pixel, //Q8.4
input wire signed [15:0] ir, delayed_ic, //Q12.4 //the ic connected here is the delayed one
//output wire valid_det, valid_d, b_done, stop, feature_loss,
output wire signed [d_limit_bits-1:0] dr, dc,
output wire valid_det
);

//I need to delay the incoming pixel by 2 clock cycles to get the correct output

reg signed [11:0] delay1_im1, delay1_im2;
reg signed [11:0] delay2_im1, delay2_im2;

always@(posedge clk, posedge reset)
begin
    if(reset)
    begin
        delay1_im1 <= 12'd0;
        delay1_im2 <= 12'd0;
    end
    else
    begin
        delay1_im1 <= im1_pixel;
        delay1_im2 <= im2_pixel; 
    end    
end


always@(posedge clk, posedge reset)
begin
    if(reset)
    begin
        delay2_im1 <= 16'd0;
        delay2_im2 <= 16'd0;
    end
    else
    begin
        delay2_im1 <=  delay1_im1;
        delay2_im2 <=  delay1_im2; 
    end    
end


wire signed [63:0] ginv_11, ginv_12, ginv_22;

reg signed [31:0] br, bc;

//find It

wire signed [12:0] temp_It; 
wire signed [15:0] It; 

assign temp_It = b_enable ? (delay2_im1 - delay2_im2) : 16'd0; 
assign It = {{3{temp_It[12]}}, temp_It};



//find b

reg signed [31:0] prod1, prod2; //Q 24.12

always@(posedge clk, posedge reset)
begin
    if(reset | b_reset)
    begin
        br <= 32'd0;
        bc <= 32'd0;
//        prod1 <= 32'd0; //IxIt
//        prod2 <= 32'd0; //IyIt
    end
    else
    begin
        if(b_enable)
        begin
            br <= br + prod1; 
            bc <= bc + prod2;
//            prod1 <= ((ix_temp>>>3) * It); //IxIt (Q9.1 * Q9.7 = Q18.8 or 26 bits but for 32 bits in total it becomes Q24.8)
//            prod2 <= ((iy_temp>>>3) * It); //IyIt
        end
        else
        begin
            br <= br; 
            bc <= bc;
//            prod1 <= prod1; //IxIt
//            prod2 <= prod2; //IyIt
        end
    end
end


assign prod1 = (ir * It); //IxIt --> Q12.4 * Q12.4 = Q24.8 --> use only Q24.8 (lower 32 bits)
assign prod2 = (delayed_ic * It); //IyIt --> --> Q12.4 * Q12.4 = Q24.8


//finding ginv:

wire signed [31:0] g11, g12, g22;

assign g11 = ginv_enable ? g_11 : 32'd0;
assign g12 = ginv_enable ? g_12 : 32'd0;
assign g22 = ginv_enable ? g_22 : 32'd0;

wire signed [63:0] detG; 
wire signed [63:0] detprod1, detprod2; 

assign detprod1 = g11*g22; //Q24.8 * Q24.8 = Q48.16
assign detprod2 = g12*g12; 

assign detG = detprod1 - detprod2; 

assign valid_det = ~(detG == 64'd0);


wire signed [63:0]g11_temp, g12_temp, g22_temp;

//assign g11_temp = g11<<32; 
//assign g12_temp = g12<<32; //doing -(g12_temp<<32) and then ginv_12 = g12_temp2/detG --> this also does unsigned division which is wrong
//assign g22_temp = g22<<32; 

assign g11_temp = g11<<32; 
assign g12_temp = g12<<32; //doing -(g12_temp<<32) and then ginv_12 = g12_temp2/detG --> this also does unsigned division which is wrong
assign g22_temp = g22<<32; 

wire signed [63:0] temp; 
assign temp = g12_temp/detG; 
assign ginv_11 = valid_det ? ((g22_temp)/detG) : 64'd0; 
assign ginv_12 = valid_det ? (-temp) : 64'd0; //doing (-g12_temp2/detG) is doing unsigned division so that's wrong
assign ginv_22 = valid_det ? ((g11_temp)/detG) : 64'd0; 

//to get actual ginv values, divide by 2^32

//wire signed [127:0] dr_temp, dc_temp; //change in cols (dc) comes first

wire signed [63:0] dr_temp, dc_temp; //42 bits --> Q10.32

assign dc_temp = ginv_11*br + ginv_12*bc; //Q32.32 * Q48.16 --> Q80.48
assign dr_temp = ginv_12*br + ginv_22*bc; 

//to get actual dc and dr values, I need to divide by 2^32 --> all the math you did with other stuff is not correct --> idek how

//assign dr = {dr_temp[53:48], dr_temp[47-:d_frac]};
//assign dc = {dc_temp[53:48], dc_temp[47-:d_frac]};

assign dr = {dr_temp[37:32], dr_temp[31-:d_frac]};
assign dc = {dc_temp[37:32], dc_temp[31-:d_frac]};


//assign dc = dc_temp;
//assign dr = dr_temp;

endmodule


