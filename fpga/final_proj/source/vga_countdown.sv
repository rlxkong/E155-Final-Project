// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/16/2026
// Summary: Generates M:SS countdown in top right corner of VGA display

module vga_countdown(
    input  logic [9:0] x,
    input  logic [9:0] y,
    input  logic [3:0] min,       // Minutes digit (0-9)
    input  logic [3:0] sec_tens,  // Seconds tens digit (0-5)
    input  logic [3:0] sec_ones,  // Seconds ones digit (0-9)
    output logic       countdown  // 1 when (x, y) is part of any digit or colon
);

    localparam logic [9:0] Y0 = 10'd20; // Top margin for all characters

    logic min_on, sec_tens_on, sec_ones_on, colon_on;

    // Instantiate 3 digits side-by-side in the top-right corner (25x45 px each)
    vga_digit_display #(.X0(10'd523), .Y0(Y0)) u_min      (.x(x), .y(y), .digit(min),      .pixel_on(min_on));
    vga_digit_display #(.X0(10'd562), .Y0(Y0)) u_sec_tens (.x(x), .y(y), .digit(sec_tens), .pixel_on(sec_tens_on));
    vga_digit_display #(.X0(10'd595), .Y0(Y0)) u_sec_ones (.x(x), .y(y), .digit(sec_ones), .pixel_on(sec_ones_on));

    // Two 5x5 dots for the colon between x = 548 and x = 562
    assign colon_on = (x >= 10'd553) && (x < 10'd558) &&
                      (((y >= Y0 + 10'd12) && (y < Y0 + 10'd17)) ||
                       ((y >= Y0 + 10'd28) && (y < Y0 + 10'd33)));

    assign countdown = min_on | colon_on | sec_tens_on | sec_ones_on;

endmodule


