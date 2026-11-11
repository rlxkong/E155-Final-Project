// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/8/2026
// Summary: Top level module for VGA. Generates the pixel clock, runs the timing,
//          and drives the VGA connector pins.

module vga_top(
    input logic clk_12mhz,
    input logic reset_n,
    output logic hsync,
    output logic vsync,
    output logic r,
    output logic g,
    output logic b
);

    logic       clk_pixel, locked;
    logic       timing_reset;
    logic [9:0] x, y;
    logic       hs, vs, video_on;

    // instantiate pixel clock (25Mhz)
    clk_divider pll(
        .clk_12mhz(clk_12mhz),
        .clk_25mhz(clk_pixel),
        .locked(locked)
    );

    assign timing_reset = ~reset_n | ~locked;

    // instantiate pixel coordinates of scan
    vga_window_timing timing(
        .clk(clk_pixel),
        .reset(timing_reset),
        .x(x),
        .y(y),
        .hsync(hs),
        .vsync(vs),
        .video_on(video_on)
    );