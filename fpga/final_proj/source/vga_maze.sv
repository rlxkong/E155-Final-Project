// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/23/2026
// Summary: Looks up the maze tile under the current pixel and outputs 
//          whether it's a wall.
//          Tiles are 16x16 pixel so the screen is a 40x30 grid.

module vga_maze (
    input  logic        clk,           // 25.125 MHz pixel clock
    input  logic [9:0]  x,             // Current pixel X 
    input  logic [9:0]  y,             // Current pixel Y 
    // Interface to fpga_spi_top / fpga_maze_ram
    input  logic [7:0]  vga_rdata,     // 8 maze tiles from SPI Block RAM (1-cycle latency)
    output logic [7:0]  vga_raddr,     // Byte address (0..149)
    output logic        wall_on
	//
	
    output logic [2:0]  rgb            // color
);

    // Prefetch 1 pixel ahead to compensate for Block RAM's 1-cycle read latency
    logic [9:0]  x_next, y_next;        // pixel one clk ahead
    logic [5:0]  tile_x;                // tile col (0-39)
    logic [4:0]  tile_y;                // tile row (0-29)
    logic [10:0] tile_idx;              // tile number (0-1199)
    logic [2:0]  bit_idx;               // tile's bit in the byte

    // RAM data comes back 1 clkl late, so address it with the next pixel
    assign x_next  = (x == 10'd799) ? 10'd0 : (x + 10'd1);
    assign y_next  = (x == 10'd799) ? ((y == 10'd524) ? 10'd0 : (y + 10'd1)) : y;
    assign tile_x   = x_next[9:4];                     // 0..39 during active display
    assign tile_y   = y_next[8:4];                     // 0..29 during active display
    assign tile_idx = (tile_y * 11'd40) + {5'd0, tile_x};

    // Clamp address during vertical blanking (py >= 480) to stay within 0..149
    // Hold the address at 0
    assign vga_raddr = (tile_y < 5'd30) ? tile_idx[10:3] : 8'd0;

    //  Synchronous read of hard-coded maze + 1-cycle delay of bit offset
    logic [7:0] hardcoded_rdata;
    logic [2:0] bit_idx_d;

    always_ff @(posedge clk) begin
        bit_idx         <= tile_idx[2:0];
    end

    // assign active_byte = hardcoded_rdata;   // Hard-coded FPGA test maze
    assign active_byte = vga_rdata;      // Live maze loaded over SPI from MCU

    // MSB of each byte is the leftmost tile
    assign wall_on = vga_rdata[3'd7 - bit_idx];
endmodule