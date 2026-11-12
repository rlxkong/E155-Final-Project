// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/10/2026
// Summary: Generates 640x480 @ 60Hz VGA timing, with the (x,y) positions of the pixel being drawn, 
//          active-low hsync and vsync, and the visible window segment status being output

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

module vga_window_timing(
    input  logic       clk,
    input  logic       reset_n,
    output logic [9:0] x,
    output logic [9:0] y,
    output logic       hsync,
    output logic       vsync,
    output logic       video_on
);

    always_ff @(posedge clk) begin
        if (~reset_n) begin
            x <= 1'b0;
            y <= 1'b0;
        end
        else begin
            // if x reaches the last pixel of the row reset
            if (x == 10'd799) begin
                x <= 1'b0;
                // if y reaches the last row then reset
                y <= (y == 10'd524) ? 1'b0 : y + 1'b1;
            end
            else begin
                x <= x + 1'b1;
            end
        end
    end

    // hsync start is after visible + fp
    // hsync end is after hsync start + hsync length
    assign hsync = ~(x >= 656 && x < 752);
    // vsync calculations are the same as hsync but with respective values
    assign vsync = ~(y >= 490 && y < 492);

    // video_on is only on during the display period
    assign video_on = (x < 10'd640) && (y < 10'd480);

endmodule