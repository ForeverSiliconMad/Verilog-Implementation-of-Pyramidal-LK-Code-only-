`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

//ensure that when start occurs, x,y are updated

module it_ginv_iteration
/*#(parameter 
k_threshold = 1,
d_limit_bits = 40, //Q4.36
imsize = 436*1024,
col = 1024,  
row = 436,
imbits = 19, //log2(imsize) 
colbits = 11, //log2(col)+1 if required
rowbits = 9//log2(row) +1 if required 
) */
#(parameter 
k_threshold = 4,
d_limit_bits = 40,
imsize = 20*30,
col = 30,  
row = 20,
imbits = 10, //log2(imsize) 
colbits = 6, //log2(col) 
rowbits = 5//log2(row) 
) //works
(
input wire clk, reset, start,
input wire signed [31:0] g11, g12, g22,
input wire [rowbits-1:0]y, //feature point coordinates in image1
input wire [colbits-1:0]x,
output wire valid_det, valid_d, b_done, stop, feature_loss,
output wire signed [d_limit_bits-1:0] dx, dy
);


//reg it_enable, b_enable;
wire it_enable;
wire signed [63:0] ginv_11, ginv_12, ginv_22;

reg signed [31:0] bx, by;

reg [rowbits-1:0]im1_y;
reg [colbits-1:0]im1_x;
wire interp_on; 

//it_enable must be on throughout the whole process of finding It, else the dff within it won't work
//assign it_enable = start | b_done; //this won't work

assign it_enable = ~reset & (start | ~b_done); 


bilinear_interp dut(
.enable(it_enable),
.clk(clk),
.reset(reset),
.interp_on(interp_on),
.x(x),
.y(y),
.sum_dx(sum_dx),
.sum_dy(sum_dy),
.done(b_done),
.feature_loss(feature_loss),
.bx(bx),
.by(by));

ginv_2x2 dut2(
.g11(g11),
.g12(g12),
.g22(g22),
.ginv_11(ginv_11),
.ginv_12(ginv_12),
.ginv_22(ginv_22),
.valid_det(valid_det));

//wire signed [64:0] temp1, temp2, temp3; 
//added an enable signal to solve_eqn module is better than limiting the input to ginv_11/22/12 by using a mux 
//adding the enable is required cuz otherwise the module is computing dx dy for all the intermediate bx by values
//which is messy and confusing, tho it's not affecting the power cuz enable only affects the output of the module, the operation is still being done
solve_eqn dut3(
.clk(clk),
.reset(reset),
.enable(b_done),
.ginv11(ginv_11), 
.ginv12(ginv_12), 
.ginv22(ginv_22),
.bx(bx), 
.by(by), 
.dx(dx),
.dy(dy),
.valid_d(valid_d));

//just know that when b_done is high (construct_b is done), then in the same cycle dx dy is also found (cuz it's combinational logic)

reg [3:0]k;
wire k_enable, update;
wire signed [rowbits-1:0]dy_rounded; 
wire signed [colbits-1:0]dx_rounded;
wire k_reset;

assign k_reset = start;

always@(posedge clk, posedge reset)
begin
    if(reset | k_reset)
        k <= 4'd0;
    else
    begin
        if(k_enable)
            k <= k+4'd1;
        else
            k <= k;
    end
end

//delay block for update signal
reg delay_update;

always@(posedge clk, posedge reset)
begin
    if(reset)
        delay_update <= 1'b0;
    else
        delay_update <= update; 
end

//point updation and storage dff
/*always@(posedge clk, posedge reset, posedge start)
begin
    if(reset)
    begin
        im1_x <= {colbits{1'b0}};
      //  im2_x <= {colbits{1'b0}};
        im1_y <= {rowbits{1'b0}};
       // im2_y <= {rowbits{1'b0}};
    end
    else
    begin
        if(start) //when you start, both set of points must be same
        begin
            im1_x <= x;
          //  im2_x <= x;
            im1_y <= y;
          //  im2_y <= y;
        end
        else
        begin
            if(delay_update)
            begin
                im1_x <= x;
                //im2_x <= x + dy_rounded;
                im1_y <= y;
               // im2_y <= y + dx_rounded; 
           end
           else
            begin
                im1_x <= im1_x;
                //im2_x <= im2_x;
                im1_y <= im1_y;
                //im2_y <= im2_y; 
           end                 
        end
    end
    
end*/


assign update = b_done ? ((k < k_threshold) ? 1'b1 : 1'b0) : 1'b0;
assign k_enable = b_done;

reg signed [39:0] sum_dx, sum_dy; //36 + some 4 bits for extra safety
//reg signed [39:0] dx_temp, dy_temp;


//when done is high (from it_integrate module), start accumulating dx and dy
always@(posedge clk, posedge reset) //previously, I'd given always@(posedge b_done) --> that's not working and having so many async signals is bad
begin
    if(reset)
    begin
        sum_dx <= 40'd0;
        sum_dy <= 40'd0;
    end
    else
    begin
        if(b_done)
        begin
        sum_dx <= sum_dx + dx;
        sum_dy <= sum_dy + dy; 
        end
        else
        begin
        sum_dx <= sum_dx;
        sum_dy <= sum_dy; 
        end
    end
end



assign dx_rounded = sum_dx[31] ? (sum_dx[39] ? (sum_dx[39:32] - 8'd1) : (sum_dx[39:32] + 8'd1)) : sum_dx[39:32];
assign dy_rounded = sum_dy[31] ? (sum_dy[39] ? (sum_dy[39:32] - 8'd1) : (sum_dy[39:32] + 8'd1)) : sum_dy[39:32];
//the bit widths here are a bit messed up, look at it later
//sums get truncated or sign extended when required, implicitly?

assign interp_on = ~(k == 0); 

assign stop = (k == k_threshold);


endmodule

//works for k = 4

