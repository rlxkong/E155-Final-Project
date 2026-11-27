// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/16/2026
// Summary: Draws an 8x8 sprite (dot that represents the player) given the player location

module vga_player(
    input  logic [9:0] x, y,
    input  logic [9:0] player_x, player_y,  // top left corner of the player sprite
    output logic 	   player_on			// draw player pixel
);

	logic [9:0] rel_x, rel_y;		// relative position of pixel inside the sprite coordinates
	logic [7:0] row;				// draws each row of the sprite
	
	always_comb begin
		rel_x = x - player_x;		// x pixel position relative to player location
		rel_y = y - player_y;		// y pixel position relative to player location
		
		case(rel_y[2:0]) 
			3'd0: row = 8'b00111100;    // the 1s are the dot's shape
            3'd1: row = 8'b01111110;
            3'd2: row = 8'b11111111;
            3'd3: row = 8'b11111111;
            3'd4: row = 8'b11111111;
            3'd5: row = 8'b11111111;
            3'd6: row = 8'b01111110;
            3'd7: row = 8'b00111100;
        endcase 
		// Checks that pixel is within the 8 cols and rows and pixel is on within the sprite frame
		// When rel_x and rel_y are negative, since these are unsigned it wraps around and still 
		// fulfills the boolean
		
		player_on = (rel_x < 10'd8)  &&  (rel_y < 10'd8)  &&  row[7 - rel_x[2:0]];	
	end
endmodule