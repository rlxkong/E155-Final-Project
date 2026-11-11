// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/8/2026
//
// Summary: Testbench for vga_window_timing.

`timescale 1 ns/1 ns

module vga_window_timing_tb();
    logic           clk;
    logic           reset;
    logic     [9:0] x;
    logic     [9:0] y;
    logic           hs;
    logic           vs;
    logic           vid_on;

    vga_window_timing dut (
.clk(clk),
.reset(reset),
.x(x),
.y(y),
.hsync(hs),
.vsync(vs),
.video_on(vid_on)
    );

    // generate clock
    always begin
        clk = 0; #10;
        clk = 1; #10;
    end

    // initial begin
// initialize
reset = 0;
#5
reset = 1;
#5

   
endmodule
