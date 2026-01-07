`timescale 1ns/1ps

module pyramid_gen_tb;

// ------------------------
// DUT signals
// ------------------------
reg clk, reset, addr_en;
reg [11:0] pixel_in;

wire [7:0] pixout0, pixout1, pixout2;
wire w_en0, w_en1, w_en2;


// ------------------------
// Instantiate DUT
// ------------------------
pyramid_gen DUT (
    .clk(clk),
    .reset(reset),
    .addr_en(addr_en),
    .pixel_in(pixel_in),
    .pixout0(pixout0),
    .pixout1(pixout1),
    .pixout2(pixout2),
    .w_en0(w_en0),
    .w_en1(w_en1),
    .w_en2(w_en2)
);

// ------------------------
// Clock generation
// ------------------------
always #5 clk = ~clk;   // 100 MHz main clock

// ------------------------
// Test variables
// ------------------------
integer i;

// ------------------------
// Stimulus
// ------------------------
initial begin

    // initial
    clk = 1;
    reset = 1;
    addr_en = 0;
    pixel_in = 12'd0;

    // release reset
    #5; //assuming reset will not be present for 1 whole clock cycle, then this works
    reset = 0;

    // start addr enable
    @(posedge clk);
    addr_en = 1;

    // feed 40 pixels
    for (i = 0; i < 40; i = i + 1) begin
        pixel_in = 10+i;

        @(posedge clk);   // new pixel every cycle

        // display activity
        $display("t=%0t  in=%0d | L0=%0d  L1=%0d  L2=%0d",
                 $time, pixel_in, pixout0, pixout1, pixout2);
    end

    addr_en = 0;

    $display("Simulation complete.");
    $finish;
end

endmodule
