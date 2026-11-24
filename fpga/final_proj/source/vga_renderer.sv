// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/16/2026
// Summary: 


module vga_renderer(
	input  logic        clk,				// pixel clock (needed by vga_maze's synchronous read)
    input  logic [9:0]  x, y,
	input  logic 	    video_on,			// on in visible area frame
	input  logic [9:0]  player_x, player_y, 	// sprite position
	input  logic [11:0] time_left, 			// gives the time left in countdown m:ss
	// Maze Block RAM interface (fpga_spi_top)
	output logic [7:0]  vga_raddr,
	input  logic [7:0]  vga_rdata,
	input  logic [47:0] game_state,
    output logic 	    r, g, b
);

	logic		player_on, timer_on;
	logic [2:0] color;					// {r, g, b}
	logic [3:0] min, t_sec, o_sec;
	
	assign {min, t_sec, o_sec} = time_left;
	
	vga_maze maze(
		.clk(clk),
		.x(x),
		.y(y),
		.video_on(video_on),
		.vga_raddr(vga_raddr),
		.vga_rdata(vga_rdata),
		.game_state(game_state),
		.rgb(color)
	);
	
	vga_player dot(
		.x(x), 
		.y(y),
		.player_x(player_x),
		.player_y(player_y),
		.player_on(player_on)
	);
	
	vga_countdown timer(
		.x(x),
		.y(y),
		.min(min),
		.sec_tens(t_sec),
		.sec_ones(o_sec),
		.countdown(timer_on)
	);
	
	// determines priority of what is drawn
	/*always_comb begin
		if		(!video_on) 	color = 3'b000;		// blanking
		else if	(timer_on)		color = 3'b111;		// timer on top
		else if (player_on)		color = 3'b100;		// player dot
		// walls				color = 3'b111;		// walls
		else					color = 3'b000;		// background
	end */
	
	assign {r, g, b} = color;
	
endmodule