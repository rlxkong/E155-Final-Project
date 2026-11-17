// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/16/2026
// Summary: Reusable single 7-segment digit renderer (25px wide x 45px tall)

module vga_digit_display #(
    parameter logic [9:0] X0 = 10'd0,
    parameter logic [9:0] Y0 = 10'd0
)(
    input  logic [9:0] x,
    input  logic [9:0] y,
    input  logic [3:0] digit,
    output logic       pixel_on
);

    localparam logic [9:0] W = 10'd25; // Digit width
    localparam logic [9:0] H = 10'd45; // Digit height
    localparam logic [9:0] T = 10'd5;  // Stroke thickness

    logic [6:0] seg;
    logic seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g;

    always_comb begin
        case (digit)
            4'd0:    seg = 7'b1111110;
            4'd1:    seg = 7'b0110000;
            4'd2:    seg = 7'b1101101;
            4'd3:    seg = 7'b1111001;
            4'd4:    seg = 7'b0110011;
            4'd5:    seg = 7'b1011011;
            4'd6:    seg = 7'b1011111;
            4'd7:    seg = 7'b1110000;
            4'd8:    seg = 7'b1111111;
            4'd9:    seg = 7'b1111011;
            default: seg = 7'b0000000;
        endcase
    end

    assign seg_a = (x >= X0)         && (x < X0 + W)     && (y >= Y0)          && (y < Y0 + T);      // Top
    assign seg_b = (x >= X0 + W - T) && (x < X0 + W)     && (y >= Y0)          && (y < Y0 + 10'd25); // Top-right
    assign seg_c = (x >= X0 + W - T) && (x < X0 + W)     && (y >= Y0 + 10'd20) && (y < Y0 + H);      // Bottom-right
    assign seg_d = (x >= X0)         && (x < X0 + W)     && (y >= Y0 + H - T)  && (y < Y0 + H);      // Bottom
    assign seg_e = (x >= X0)         && (x < X0 + T)     && (y >= Y0 + 10'd20) && (y < Y0 + H);      // Bottom-left
    assign seg_f = (x >= X0)         && (x < X0 + T)     && (y >= Y0)          && (y < Y0 + 10'd25); // Top-left
    assign seg_g = (x >= X0)         && (x < X0 + W)     && (y >= Y0 + 10'd20) && (y < Y0 + 10'd25); // Middle

    assign pixel_on = (seg[6] & seg_a) | (seg[5] & seg_b) | (seg[4] & seg_c) |
                      (seg[3] & seg_d) | (seg[2] & seg_e) | (seg[1] & seg_f) |
                      (seg[0] & seg_g);

endmodule