// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/8/2026
// Summary: Top level module for VGA. Generates the pixel clock, runs the timing,
//          and drives the VGA connector pins.

module vga_top(
    input logic clk_12mhz,
    input logic reset_n,
	input logic spi_sck,
	input logic spi_sdi,
	input logic spi_cs,
	input logic spi_sdo,
    output logic hsync,
    output logic vsync,
    output logic r,
    output logic g,
    output logic b
);
	
    logic        clk_pixel, locked;
    logic        timing_reset;
    logic [9:0]  x, y;
    logic        hs, vs, video_on;	
	
	logic [9:0]  player_posx, player_posy;
	logic [11:0] countdown;
	logic [7:0]  flags; 		// place holder for win, pause, game over, etc.
	
	// SPI testing signals 
	logic [7:0]  vga_raddr, vga_rdata;
	logic [39:0] game_state;	// {player_x[9:0], player_y[9:0], timer[7:0], flags[7:0]}
	
    // instantiate pixel clock (25Mhz)
    clk_divider pll(
        .clk_12mhz(clk_12mhz),
        .clk_25mhz(clk_pixel),
        .locked(locked)
    );

    assign timing_reset = reset_n & locked;
	
	// testing moving
	moving_sprite_test test(
		.clk(clk_pixel),
		.reset_n(timing_reset),
		.x(x),
		.y(y),
		.spr_x(player_posx),
		.spr_y(player_posy),
		.time_bcd(countdown),
		.spi_sck(spi_sck),
		.spi_sdi(spi_sdi),
		.spi_cs(spi_cs)
	);

	// instantiate spi reciever
	fpga_spi_top spi(
		.clk(clk_pixel),
		.sck(spi_sck),
		.sdi(spi_sdi),
		.sdo(spi_sdo),
		.cs(spi_cs),
		.vga_raddr(vga_raddr),
		.vga_rdata(vga_rdata),
		.game_state(game_state)
	);	

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
		
	// instantiate color logic module
	vga_renderer driver(
		.clk(clk_pixel),
		.x(x),
		.y(y),
		.video_on(video_on),
		.player_x(player_posx),
		.player_y(player_posy),
		.time_left(countdown),
		.vga_raddr(vga_raddr),
		.vga_rdata(vga_rdata),
		.r(r),
		.g(g),
		.b(b)
	);
	
	// assign hsync and vsync
	assign hsync = hs;
	assign vsync = vs;

	// unpack game state from MCU
	assign {player_posx, player_posy, countdown, game_flags} = game_state;

endmodule