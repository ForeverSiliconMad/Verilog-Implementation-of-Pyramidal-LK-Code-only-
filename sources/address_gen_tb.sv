/*`timescale 1ns/1ps

module address_gen_tb;

// Parameters
localparam pr = 2;
localparam pc = 2;
localparam rows = 12;
localparam cols = 10;
localparam imbits = 7;

// DUT inputs
reg clk, reset;
reg addr_en;
reg row_count_en, col_count_en, row_count_rst;
reg [imbits-1:0] start_address;

// DUT outputs
wire rowdone;
wire patch_done;
wire invalid_addr;
wire [imbits-1:0] addr, addr_next_row; //use this to get 2 blocks of data out at a time

//memory to store the image


// Instantiate DUT
address_gen #(
    .pr(pr),
    .pc(pc),
    .rows(rows),
    .cols(cols),
    .imbits(imbits)
) dut (
    .clk(clk),
    .reset(reset),
    .addr_en(addr_en),
    .start_address(start_address),
    .row_count_en(row_count_en),
    .col_count_en(col_count_en),
    .row_done(rowdone),
    .patch_done(patch_done),
    .invalid_addr(invalid_addr),
    .addr(addr),
    .addr_next_row(addr_next_row)
);

// Clock generation
always #5 clk = ~clk;   // 100 MHz clock

initial begin
    // Initial values
    clk = 0;
    reset = 1;
    addr_en = 0;
    row_count_en = 0;
    col_count_en = 0;
    start_address = 2;  // example: starting center pixel  

    // Release reset
    @(posedge clk);
    reset = 0;
    @(posedge clk);
    // Enable address generation
    addr_en = 1;

    // Start col counter
    col_count_en = 1;
    
    

    @(posedge patch_done);
    @(negedge clk);
    
    $finish;
end 

endmodule
*/

//testing address gen + fifo

`timescale 1ns/1ps

//extraction is happening successfully
//to extract a patch of 33x33 into a fifo (one at a time), it takes 10.89 us
//even if I extract 2 column pixels and 2 row pixels at a time, (basically a 2x2 window) --> it's still gonna take so long cuz I need to iterate thru all 33x33 pixels to get bilinear interp for each pixel

module address_gen_tb;

// Parameters
localparam pr = 16;
localparam pc = 16;
localparam rows = 436;
localparam cols = 1024;
localparam imbits = 19;
localparam IMAGE_SIZE = rows * cols;

// DUT inputs
reg clk, reset;
reg addr_en;
reg col_count_en, row_count_rst;
reg [imbits-1:0] start_address;

// DUT outputs
wire rowdone;
wire patch_done;
wire invalid_addr;
wire [imbits-1:0] addr, addr_next_row;

// -----------------------------
// IMAGE MEMORY
// -----------------------------
reg [7:0] im1 [0:IMAGE_SIZE-1];   // 8-bit image

// -----------------------------
// FIFO INSTANCE
// -----------------------------
wire fifo_full, fifo_empty;
reg  w_en, r_en;
wire [7:0] fifo_data_out;

sync_fifo #(
    .DEPTH(2048),
    .DATA_WIDTH(8)
) fifo_inst (
    .clk(clk),
    .rst(reset),
    .w_en(w_en),
    .r_en(r_en),
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
    .addr_en(addr_en),
    .start_address(start_address),
    .col_count_en(col_count_en),
    .row_done(rowdone),
    .patch_done(patch_done),
    .invalid_addr(invalid_addr),
    .addr(addr)
    //, .addr_next_row(addr_next_row)
);

// -----------------------------
// Clock generation
// -----------------------------
always #5 clk = ~clk; // 100 MHz
integer dumpfile; 


task dump_fifo_contents;
begin
    dumpfile = $fopen("C:\\Users\\peace\\project\\project.srcs\\sources_1\\new\\patch.txt", "w");

    // sequentially read FIFO
    r_en = 1;
    while (!fifo_empty) begin
        @(posedge clk);
        $fwrite(dumpfile, "%0d\n", fifo_data_out);
    end
    r_en = 0;

    $fclose(dumpfile);
    $display("FIFO dump saved to fifo_dump.txt");
end
endtask

integer read_pointer_max; 
integer r, c; 

// -----------------------------
// TEST SEQUENCE
// -----------------------------
initial begin
    clk = 0;
    reset = 1;
    addr_en = 0;
    col_count_en = 0;
    r = 117;
    c = 195; 
    start_address = (r-pr)*cols + (c-pc);
    dumpfile = $fopen("C:\\Users\\peace\\project\\project.srcs\\sources_1\\new\\patch.txt", "w");

    w_en = 0;
    r_en = 0;

    // Load image into memory
    $readmemh("img1.mem", im1);
    $display("Image loaded.");

    @(posedge clk);
    reset = 0;

    @(posedge clk);
    addr_en = 1;
    col_count_en = 1;

    // Write pixels into FIFO whenever new addr is valid
//    forever begin
//        @(posedge clk);
//        if (addr_en && !invalid_addr && !fifo_full)
//           w_en = 1; 
//        else
//           w_en = 0;
//    end

    w_en = 1'b1; 
    
    @(posedge patch_done);
    w_en = 1'b0; 
    $display("Patch extraction complete. Dumping FIFO...");
    dump_fifo_contents();
    $finish;
       
end
//when data is written into file from fifo, for the first clk cycle, dataout = 0 (cuz r_en is sync)
//so in the file, please remove the first element 0 before analysing --> this is an output problem only, internally in fifo it's stored correctly


endmodule
