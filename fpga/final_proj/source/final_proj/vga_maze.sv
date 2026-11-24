// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/23/2026
// Summary: Renders the 40x30 maze on VGA.
//          Swap the commented 'active_byte' line below to switch between
//          the hard-coded FPGA test maze and the MCU SPI maze.

module vga_maze (
    input  logic        clk,           // 25.125 MHz pixel clock
    input  logic [9:0]  x,            // Current pixel X 
    input  logic [9:0]  y,            // Current pixel Y 
    input  logic        video_on,      // on in visible area frame
    // Interface to fpga_spi_top / fpga_maze_ram
	// this stuff from spi logic so like idk how it work for now but yea
    output logic [7:0]  vga_raddr,     // Byte address (0..149)
    input  logic [7:0]  vga_rdata,     // 8 maze tiles from SPI Block RAM (1-cycle latency)
    input  logic [47:0] game_state,    // {dot_x[15:0], dot_y[15:0], timer[7:0], flags[7:0]}
	//
	
    output logic [2:0]  rgb            // color
);

    // Built-in 150-byte (40x30) hard-coded test maze
    localparam logic [7:0] hardcoded_maze [0:149] = '{
        8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,  // Row  0
        8'h80, 8'h00, 8'h18, 8'h00, 8'h01,  // Row  1
        8'hBF, 8'h7F, 8'hDB, 8'hFE, 8'hDD,  // Row  2
        8'hA1, 8'h00, 8'h42, 8'h00, 8'h91,  // Row  3
        8'hAD, 8'hFF, 8'h6E, 8'hFF, 8'hB5,  // Row  4
        8'h8C, 8'h00, 8'h62, 8'h00, 8'h35,  // Row  5
        8'hEF, 8'hFF, 8'hFB, 8'hFF, 8'hF5,  // Row  6
        8'h88, 8'h00, 8'h08, 8'h00, 8'h05,  // Row  7
        8'hBB, 8'hFF, 8'hEF, 8'hFF, 8'hF5,  // Row  8
        8'hA2, 8'h00, 8'h28, 8'h00, 8'h11,  // Row  9
        8'hAE, 8'hFF, 8'hAB, 8'hFF, 8'hDD,  // Row 10
        8'hA0, 8'h80, 8'hA2, 8'h00, 8'h41,  // Row 11
        8'hBF, 8'hBE, 8'hBE, 8'hFF, 8'h7D,  // Row 12
        8'h80, 8'h22, 8'h20, 8'h81, 8'h05,  // Row 13
        8'hFF, 8'hEB, 8'hEF, 8'hBD, 8'hF5,  // Row 14
        8'h80, 8'h08, 8'h08, 8'h24, 8'h11,  // Row 15
        8'hBF, 8'hFF, 8'hFB, 8'hEF, 8'hDD,  // Row 16
        8'hA0, 8'h00, 8'h08, 8'h20, 8'h41,  // Row 17
        8'hAF, 8'hFF, 8'hEF, 8'hBF, 8'h7D,  // Row 18
        8'h88, 8'h00, 8'h20, 8'h81, 8'h05,  // Row 19
        8'hEB, 8'hFF, 8'hBE, 8'hFD, 8'hF5,  // Row 20
        8'h8A, 8'h00, 8'h82, 8'h04, 8'h11,  // Row 21
        8'hBA, 8'hFE, 8'hFB, 8'hF7, 8'hDD,  // Row 22
        8'h82, 8'h82, 8'h08, 8'h10, 8'h41,  // Row 23
        8'hBE, 8'hBB, 8'hEF, 8'hDF, 8'h7D,  // Row 24
        8'hA0, 8'hA8, 8'h20, 8'h41, 8'h05,  // Row 25
        8'hAF, 8'hAF, 8'hBF, 8'h7D, 8'hF5,  // Row 26
        8'h88, 8'h20, 8'h81, 8'h04, 8'h11,  // Row 27
        8'hEB, 8'hFE, 8'hBD, 8'hF7, 8'hD7,  // Row 28
        8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hF3   // Row 29 (bottom exit gap)
    };

    // Prefetch 1 pixel ahead to compensate for Block RAM's 1-cycle read latency
    logic [9:0]  x_next, y_next;
    logic [5:0]  tile_x;
    logic [4:0]  tile_y;
    logic [10:0] tile_idx;

    assign x_next  = (x == 10'd799) ? 10'd0 : (x + 10'd1);
    assign y_next  = (x == 10'd799) ? ((y == 10'd524) ? 10'd0 : (y + 10'd1)) : y;
    assign tile_x   = x_next[9:4];                     // 0..39 during active display
    assign tile_y   = y_next[8:4];                     // 0..29 during active display
    assign tile_idx = (tile_y * 11'd40) + {5'd0, tile_x};

    // Clamp address during vertical blanking (py >= 480) to stay within 0..149
    assign vga_raddr = (tile_y < 5'd30) ? tile_idx[10:3] : 8'd0;

    //  Synchronous read of hard-coded maze + 1-cycle delay of bit offset
    logic [7:0] hardcoded_rdata;
    logic [2:0] bit_idx_d;

    always_ff @(posedge clk) begin
        hardcoded_rdata <= hardcoded_maze[vga_raddr];
        bit_idx_d       <= tile_idx[2:0];
    end

    // 3. SELECT MAZE SOURCE (Comment/Uncomment one line below)
    logic [7:0] active_byte;
    logic       is_wall;

    assign active_byte = hardcoded_rdata;   // Hard-coded FPGA test maze
    // assign active_byte = vga_rdata;      // Live maze loaded over SPI from MCU

    assign is_wall = active_byte[7 - bit_idx_d];

    // 4. Unpack player dot coordinates from 48-bit SPI game_state (8x8 px square)
    /*logic [9:0] dot_x, dot_y;
    logic       is_dot;

    assign dot_x  = game_state[47:32];
    assign dot_y  = game_state[31:16];
    assign is_dot = (px >= dot_x) && (px < dot_x + 10'd8) &&
                    (py >= dot_y) && (py < dot_y + 10'd8); */

    // Drive RGB output
    always_comb begin
        if (!video_on)
            rgb = 3'b000;     // Black during horizontal/vertical blanking
        //else if (is_dot)
           // rgb = 3'b100;     // Bright Red player dot
        else if (is_wall)
            rgb = 3'b111;     // Dark Blue maze walls
        else
            rgb = 3'b000;     // open corridor
    end

endmodule