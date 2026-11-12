// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/11/2026
// Summary: Logic to determine color of pixels using RGB

/*
    Each frame is 800x525 pixels, of which 640x480 are visible.
    The rest is blanking time, when RGB must be held at 0 (black).
    Pixel clock speed operates at 25.125MHz.
    Scan order: display > fp > sync > bp > display
    Assume the scan starts at display so that (x,y) aligns with visible window.

    Horizontal:
        display         640 pixels
        front porch     16 pixels
        hsync           96 pixels
        back porch      48 pixels

    Vertical:
        display         480 lines
        front porch     10 lines
        vsync           2 lines
        back porch      33 lines
*/

module vga_color_logic(
    //input  logic       clk,
    //input  logic       reset_n,
	input  logic       video_on, // at display area comparator
	//input  logic [9:0] x,
    //input  logic [9:0] y,
	input  logic [2:0] color_input, // r g b	
	output logic 	   r, g, b 
);

//  Write logic to determine the color of the current pixel (like drawing a checkerboard or a bouncing square). If video_active is low, force all RGB outputs to 0 so the monitor's sync signals register correctly.
	

    /*always_ff @(posedge clk) begin
        if (~reset_n) begin
            r <= 1'b0;
            g <= 1'b0;
			b <= 1'b0;
        end
     end */
	 
	 // hardcoding colors to test on vga
	//assign color_input[2] = (x < 320) ? 1'b1 : 1'b0; // red
    //assign color_input[1] = (y < 160) ? 1'b1 : 1'b0; // green
	//assign color_input[0] = (y >= 320) ? 1'b1 : 1'b0; // blue
	 
	 // black color and deciding what rgb is
	 always_comb begin
		r = (video_on) ? color_input[2] : 1'b0;
		g = (video_on) ? color_input[1] : 1'b0;
		b = (video_on) ? color_input[0] : 1'b0;
     end
	
	

endmodule