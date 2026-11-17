// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/16/2026
// Summary: Hardcoded stand-in for the MCU while SPI isn't connected. Bounces the
//          sprite around the screen and counts the timer down in M:SS BCD.
//          Everything updates once per frame, at the start of vertical blanking,
//          so the picture never changes in the middle of a frame.

module moving_sprite_test #(
    parameter logic [9:0]  STEP           = 10'd2,     // pixels moved per frame (2 = 120 px/s)
    parameter logic [9:0]  MAX_X          = 10'd632,   // 640 - 8: rightmost top-left corner
    parameter logic [9:0]  MAX_Y          = 10'd472,   // 480 - 8: lowest top-left corner
    parameter logic [11:0] START_TIME     = 12'h200,   // 2:00
    parameter int          FRAMES_PER_SEC = 60         // set to 1 in simulation to speed it up
)(
    input  logic        clk,            // pixel clock
    input  logic        reset_n,
    input  logic [9:0]  x, y,           // from vga_window_timing
    output logic [9:0]  spr_x, spr_y,
    output logic [11:0] time_bcd
);

    logic       frame_tick;             // high for one clock per frame
    logic       right, down;            // current direction of travel
    logic [5:0] frame_cnt;              // counts frames up to one second

    // First pixel of the first blanking line: once per frame, while nothing is drawn
    assign frame_tick = (x == 10'd0) && (y == 10'd480);

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

endmodule