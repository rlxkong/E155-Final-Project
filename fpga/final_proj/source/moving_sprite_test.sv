// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/16/2026
// Summary: Hardcoded stand-in for the MCU while the STM32 isn't connected.
//          1) Bounces the sprite around the screen and counts the timer down in M:SS BCD.
//          2) Acts as a fake SPI master (Mode 0) and sends a maze to fpga_spi_top exactly
//             the way the MCU will: CS low, command 0x01, 150 maze bytes, CS high.
//             It alternates between two test mazes every RELOAD_SECS seconds, so you can
//             see that repeated loads (level reset) work too.
//          Everything updates once per frame, at the start of vertical blanking,
//          so the picture never changes in the middle of a frame. A full maze load
//          (151 bytes) takes 151*8*2*SCK_HALF = 19,328 clocks with SCK_HALF = 8, which
//          fits inside the 36,000-clock vertical blanking interval.
//
//          Test maze A: border + pillar every 4 tiles + a 6-tile wall stub sticking out
//                       of the LEFT border on rows 2-3 (top-left). If the stub is on the
//                       right, or detached from the border, the bit order is flipped.
//          Test maze B: border + horizontal walls every 4 rows with a 2-tile doorway that
//                       alternates right/left (a serpentine path).

module moving_sprite_test #(
    parameter logic [9:0]  STEP           = 10'd2,     // pixels moved per frame (2 = 120 px/s)
    parameter logic [9:0]  MAX_X          = 10'd632,   // 640 - 8: rightmost top-left corner
    parameter logic [9:0]  MAX_Y          = 10'd472,   // 480 - 8: lowest top-left corner
    parameter logic [11:0] START_TIME     = 12'h200,   // 2:00
    parameter int          FRAMES_PER_SEC = 60,        // set to 1 in simulation to speed it up
    parameter int          SCK_HALF       = 8,         // clk cycles per SCK half period (8 -> 1.57 MHz), keep <= 14
    parameter int          RELOAD_SECS    = 3          // swap test mazes every N seconds (0 = load once)
)(
    input  logic        clk,            // pixel clock
    input  logic        reset_n,
    input  logic [9:0]  x, y,           // from vga_window_timing
    output logic [9:0]  spr_x, spr_y,
    output logic [11:0] time_bcd,
    // Fake MCU SPI master -> fpga_spi_top
    output logic        spi_sck,
    output logic        spi_sdi,        // MOSI
    output logic        spi_cs          // active low
);

    logic       frame_tick;             // high for one clock per frame
    logic       sec_tick;               // high for one clock per second
    logic       right, down;            // current direction of travel
    logic [5:0] frame_cnt;              // counts frames up to one second

    // First pixel of the first blanking line: once per frame, while nothing is drawn
    assign frame_tick = (x == 10'd0) && (y == 10'd480);
    assign sec_tick   = frame_tick && (frame_cnt == FRAMES_PER_SEC - 1);

    // Sprite: move STEP pixels per frame, reverse direction at each edge
    always_ff @(posedge clk) begin
        if (~reset_n) begin
            spr_x <= 10'd100;
            spr_y <= 10'd100;
            right <= 1'b1;
            down  <= 1'b1;
        end
        else if (frame_tick) begin
            if (right) begin
                if (spr_x + STEP > MAX_X) right <= 1'b0;    // would pass the right edge: turn
                else                      spr_x <= spr_x + STEP;
            end
            else begin
                if (spr_x < STEP)         right <= 1'b1;    // would pass the left edge: turn
                else                      spr_x <= spr_x - STEP;
            end

            if (down) begin
                if (spr_y + STEP > MAX_Y) down <= 1'b0;
                else                      spr_y <= spr_y + STEP;
            end
            else begin
                if (spr_y < STEP)         down <= 1'b1;
                else                      spr_y <= spr_y - STEP;
            end
        end
    end

    // Timer: every FRAMES_PER_SEC frames, subtract one second in BCD
    always_ff @(posedge clk) begin
        if (~reset_n) begin
            frame_cnt <= 6'd0;
            time_bcd  <= START_TIME;
        end
        else if (frame_tick) begin
            if (frame_cnt == FRAMES_PER_SEC - 1) begin
                frame_cnt <= 6'd0;

                if (time_bcd == 12'h000)                    // 0:00 -> start over
                    time_bcd <= START_TIME;
                else if (time_bcd[3:0] != 4'd0)             // x:x5 -> x:x4
                    time_bcd[3:0] <= time_bcd[3:0] - 4'd1;
                else begin                                  // ones digit is 0
                    time_bcd[3:0] <= 4'd9;
                    if (time_bcd[7:4] != 4'd0)              // 1:40 -> 1:39
                        time_bcd[7:4] <= time_bcd[7:4] - 4'd1;
                    else begin                              // 1:00 -> 0:59
                        time_bcd[7:4]  <= 4'd5;
                        time_bcd[11:8] <= time_bcd[11:8] - 4'd1;
                    end
                end
            end
            else
                frame_cnt <= frame_cnt + 6'd1;
        end
    end

    // ------------------------------------------------------------------
    // Test maze generator
    // Tile (tx, ty): tx = 0..39 (left to right), ty = 0..29 (top to bottom)
    // Byte n holds tiles 8n..8n+7 in row-major order, MSB = leftmost tile,
    // which is the format vga_maze expects (is_wall = byte[7 - bit_idx]).
    // ------------------------------------------------------------------
    function automatic logic wall_tile(input logic [5:0] tx, input logic [4:0] ty, input logic pat);
        logic border;
        border = (tx == 6'd0) || (tx == 6'd39) || (ty == 5'd0) || (ty == 5'd29);
        if (!pat)   // Maze A: pillars + top-left orientation stub
            wall_tile = border
                      || ((tx[1:0] == 2'd2) && (ty[1:0] == 2'd2))
                      || ((ty >= 5'd2) && (ty <= 5'd3) && (tx <= 6'd5));
        else        // Maze B: serpentine, doorway on the right (ty%8==2) or left (ty%8==6)
            wall_tile = border
                      || ((ty[1:0] == 2'd2) &&
                          !(ty[2] ? ((tx >= 6'd2)  && (tx <= 6'd3))
                                  : ((tx >= 6'd36) && (tx <= 6'd37))));
    endfunction

    function automatic logic [7:0] maze_byte(input logic [4:0] row, input logic [2:0] grp, input logic pat);
        for (int k = 0; k < 8; k++)
            maze_byte[7 - k] = wall_tile({grp, 3'(k)}, row, pat);
    endfunction

    // ------------------------------------------------------------------
    // Fake MCU: SPI Mode 0 master (CPOL = 0, CPHA = 0)
    // SDI changes while SCK is low, fpga_spi samples on the rising edge.
    // Packet: CS low | 0x01 | 150 maze bytes | CS high
    // ------------------------------------------------------------------
    localparam logic [7:0] CMD_MAZE  = 8'h01;
    localparam int         CS_HOLD   = 32;   // clks CS stays low after the last bit, so
                                             // fpga_spi_top grabs the last byte before CS
                                             // rising clears fpga_spi's latched_byte

    typedef enum logic [1:0] {IDLE, XFER, HOLD} spi_state_t;
    spi_state_t spi_state;

    logic [5:0] div_cnt;      // counts clks within an SCK half period (also used for CS_HOLD)
    logic [2:0] bit_cnt;      // bit within current byte
    logic [7:0] byte_cnt;     // 0 = command byte, 1..150 = maze bytes
    logic [7:0] shreg;        // byte being shifted out, MSB first
    logic [4:0] row;          // maze row of the NEXT maze byte to load
    logic [2:0] grp;          // byte within that row (0..4)
    logic       pat;          // which test maze is being sent
    logic       load_req;     // send a maze at the next frame_tick
    logic [7:0] reload_cnt;   // seconds since last reload

    logic [7:0] next_byte;
    assign next_byte = maze_byte(row, grp, pat);

    always_ff @(posedge clk) begin
        if (~reset_n) begin
            spi_state  <= IDLE;
            spi_cs     <= 1'b1;
            spi_sck    <= 1'b0;
            spi_sdi    <= 1'b0;
            div_cnt    <= '0;
            bit_cnt    <= '0;
            byte_cnt   <= '0;
            shreg      <= '0;
            row        <= '0;
            grp        <= '0;
            pat        <= 1'b0;
            load_req   <= 1'b1;               // send maze A as soon as the PLL locks
            reload_cnt <= '0;
        end
        else begin
            // Periodically request a reload with the other maze
            if (RELOAD_SECS != 0 && sec_tick) begin
                if (reload_cnt == RELOAD_SECS - 1) begin
                    reload_cnt <= '0;
                    load_req   <= 1'b1;
                end
                else
                    reload_cnt <= reload_cnt + 8'd1;
            end

            case (spi_state)
                IDLE: begin
                    spi_cs  <= 1'b1;
                    spi_sck <= 1'b0;
                    if (frame_tick && load_req) begin   // start at the beginning of vblank
                        load_req  <= 1'b0;
                        spi_cs    <= 1'b0;
                        shreg     <= CMD_MAZE;
                        spi_sdi   <= CMD_MAZE[7];       // first bit valid before first rising edge
                        div_cnt   <= '0;
                        bit_cnt   <= '0;
                        byte_cnt  <= '0;
                        row       <= '0;
                        grp       <= '0;
                        spi_state <= XFER;
                    end
                end

                XFER: begin
                    if (div_cnt == SCK_HALF - 1) begin
                        div_cnt <= '0;
                        if (!spi_sck) begin
                            spi_sck <= 1'b1;                    // rising edge: FPGA samples SDI
                        end
                        else begin
                            spi_sck <= 1'b0;                    // falling edge: put out next bit
                            if (bit_cnt == 3'd7) begin
                                bit_cnt <= 3'd0;
                                if (byte_cnt == 8'd150) begin   // last maze byte done
                                    spi_sdi   <= 1'b0;
                                    spi_state <= HOLD;
                                end
                                else begin
                                    byte_cnt <= byte_cnt + 8'd1;
                                    shreg    <= next_byte;
                                    spi_sdi  <= next_byte[7];
                                    if (grp == 3'd4) begin      // 5 bytes per row
                                        grp <= 3'd0;
                                        row <= row + 5'd1;
                                    end
                                    else
                                        grp <= grp + 3'd1;
                                end
                            end
                            else begin
                                bit_cnt <= bit_cnt + 3'd1;
                                shreg   <= {shreg[6:0], 1'b0};
                                spi_sdi <= shreg[6];
                            end
                        end
                    end
                    else
                        div_cnt <= div_cnt + 6'd1;
                end

                HOLD: begin
                    if (div_cnt == CS_HOLD - 1) begin
                        div_cnt   <= '0;
                        spi_cs    <= 1'b1;
                        pat       <= ~pat;                      // next load sends the other maze
                        spi_state <= IDLE;
                    end
                    else
                        div_cnt <= div_cnt + 6'd1;
                end

                default: spi_state <= IDLE;
            endcase
        end
    end

endmodule