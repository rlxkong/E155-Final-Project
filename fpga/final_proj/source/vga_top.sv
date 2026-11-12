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
	logic [2:0] color_input;

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
        .reset_n(timing_reset),
        .x(x),
        .y(y),
        .hsync(hs),
        .vsync(vs),
        .video_on(video_on)
    );
	
	// hardcoding colors to test on vga
	assign color_input[2] = (x < 320) ? 1'b1 : 1'b0; // red
    assign color_input[1] = (y < 160) ? 1'b1 : 1'b0; // green
	assign color_input[0] = (y >= 320) ? 1'b1 : 1'b0; // blue
	
	// instantiate color logic module
	vga_color_logic colorlogic(
		  //.clk(clk_pixel), 
		  //.reset_n(reset_n),
		  .video_on(video_on),
		  .color_input(color_input),
		  .r(r),
		  .g(g),
		  .b(b)
	);
	
endmodule