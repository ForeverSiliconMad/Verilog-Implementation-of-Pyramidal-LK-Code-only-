`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//address generator for patch extraction from full image
//consider all addresses and indices to start from 1 and not zero (except bit indices)
//cuz if zero based indexing is used (for pixel addresses), i need to reset the counters to -1 (which can lead to complications if all ones is a valid address (for eg. 31 for 5 bits)
//also, it's easier to give inputs and parameters
//just, insert a 0 before the image values start in the file containing it when ur reading it later - in the testbench
//assume that address 0 can't be accessed (or is 0 when accessed irl)

//if the original patch to store is 33x33, then using the double pixel stuff, I'm storing 36x36 --> this is necessary to do any bilinear interpolation if necessary

//valid addresses are generated only when patch had odd number of rows and cols, and extracted patch would have 1 more row and 1 more col
//it'll be useful for bilinear interpolation (of intensity values)

module address_gen
#(parameter 
pr = 16, //patchsize = 33x33, so 16 = floor(33/2)
pc = 16, 
patch_size = 33*33,
rows = 33,
cols = 33,
imsize = rows*cols,
rowbits = $clog2(rows), //log2(rows) where rows = number of rows in image
colbits = $clog2(cols), //log2(cols) where cols = number of cols in iamge
imbits = $clog2(imsize) //log2(imsize)
) //works
/*#(parameter 
pr = 70, //patchsize = 33x33, so 16 = floor(33/2)
pc = 70, 
patch_size = pr*pc,
rows = 100,
cols = 120,
imsize = rows*cols,
rowbits = $clog2(rows), //log2(rows) where rows = number of rows in image
colbits = $clog2(cols), //log2(cols) where cols = number of cols in iamge
imbits = $clog2(imsize) //log2(imsize)
)*/
(
input clk, reset, addr_en,
input [imbits-1:0] start_address, //calculated outside this module
//input row_count_en, 
input col_count_en,  
output row_done, patch_done, 
output reg invalid_addr,
output [imbits-1:0] addr
//, output [imbits-1:0] addr_next_row //use if trying to generate two addresses
);

reg [2*pr:0] row_count;
reg [2*pc:0] col_count; 

//row_counter
always@(posedge clk, posedge reset)
begin
    if(reset | patch_done) //row_count_rst = patch_done
        row_count <= 0;
    else
    begin
        if(row_done) //row_done = row_count_en
            row_count <= row_count + 1; //for a single pixel transferred at a time
            //row_count <= row_count + 2; //for two column pixels transferred at a time
        else
            row_count <= row_count;
    end
end

//col counter
always@(posedge clk, posedge reset)
begin
    if(reset | row_done | patch_done) 
        col_count <= 0;
    else
    begin
        if(col_count_en & ~row_done)
            col_count <= col_count + 1'b1;
        else
            col_count <= col_count; 
    end
end

assign row_done = (col_count == (2*pc)); //0 to 2*pc

assign patch_done = (row_count == (2*pr)) && (col_count == (2*pc)); //cuz the rows go from 0 to 2*pr, and 2*pr is included, so 1 after that, patch is considered done
//assign patch_done = (row_count == (2*pr+2)); //use this if ur trying to generate 2 addresses 

wire [imbits-1:0] a; 
reg [imbits-1:0] curr_addr; 

assign a = row_done ? (cols-2*pc) : 'b1; 
//assign a = row_done ? (2*cols-2*pc) : 'b1; //use this if ur trying to generate 2 addresses

//start_address = (r-pr)*cols + (c-pc) 

//address is considered invalid when it there's an overflow between curr_addr and a, but I have no logic to indicate that
//if that's included, it needs to be OR'ed with reset of all counters and accumulator

//accumulator
always@(posedge clk, posedge reset)
begin
    if(reset | patch_done | invalid_addr) 
        {invalid_addr, curr_addr} <= 0; 
    else
    begin
        if(addr_en)
            {invalid_addr, curr_addr} <= curr_addr + a; //if the addition overflows, the addr generated is invalid
        else
            {invalid_addr, curr_addr} <= {1'b0, start_address};
    end
end


assign addr = curr_addr; 
//assign addr_next_row = invalid_addr ? 0 : addr + cols; 

endmodule
