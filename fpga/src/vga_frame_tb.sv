// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Summary: "Virtual monitor" testbench for vga_top's logic below the PLL
//          (vga_window_timing, the color pattern, and vga_color_logic). Shows
//          what one frame would look like on the monitor if the design loaded
//          on the board.
//
//   The testbench makes its own pixel clock, so no PLL, HSOSC or Lattice
//   library is involved. The clock period doesn't matter: VGA timing is all
//   counted in clocks, so the picture is identical at any speed. Frequencies
//   in the report are scaled to the real 25.125 MHz board clock.
//
//   It only looks at the pins a real monitor sees: hsync, vsync, r, g, b.
//   Like a monitor, it locks onto the sync pulses and places each pixel by
//   counting clocks from the hsync falling edge and lines from the vsync
//   falling edge, so any pipeline delay or sync bug shows up in the picture
//   the same way it would on the screen.
//
//   Outputs (written to the simulation directory):
//     frame.bmp / frame.ppm   the 640x480 visible picture
//     raster.bmp / raster.ppm the full 800x525 raster, including blanking:
//                              dark gray = hsync low, dark blue = vsync low,
//                              very dark gray = blanking, orange = X or Z on r/g/b
//   (.bmp opens in any image viewer; .ppm is a plain-text fallback.)
//
//   It also prints the measured sync timing, where the lit pixels are, and
//   warnings for color driven during blanking or X/Z outputs.
//
//   Compile: vga_window_timing.sv, vga_color_logic.sv and this file. Leave out
//   vga_top and clk_divider. Top: vga_frame_tb.

`timescale 1ns/1ps
module vga_frame_tb;

    // 640x480 @ 60 Hz, written independently of the design
    localparam int H_DISP = 640, H_FP = 16, H_SYNC = 96, H_BP = 48;
    localparam int V_DISP = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33;
    localparam int H_TOTAL = H_DISP + H_FP + H_SYNC + H_BP;   // 800
    localparam int V_TOTAL = V_DISP + V_FP + V_SYNC + V_BP;   // 525
    localparam int FRAME   = H_TOTAL * V_TOTAL;               // 420,000 clocks

    // Where the visible picture sits relative to the sync pulses, as the
    // monitor sees it: pixel 0 is H_SYNC+H_BP clocks after hsync falls, and
    // row 0 starts on the (V_SYNC+V_BP)th hsync pulse after vsync falls.
    localparam int COL0 = H_SYNC + H_BP;        // 144
    localparam int ROW0 = V_SYNC + V_BP - 1;    // 34 (raster row index)

    // Which full frame to save. 1 = first complete frame after reset.
    // Raise it if your design needs a few frames to settle (e.g. a moving sprite).
    localparam int CAPTURE_FRAME = 2;

    // Testbench clock. Any period works; 10 ns just keeps waveforms readable.
    localparam real PERIOD  = 10.0;
    localparam real PIX_MHZ = 25.125;   // real board clock, used only for the report

    // ---------------- clock and DUT ----------------
    logic pix_clk = 1'b0;
    always #(PERIOD/2) pix_clk = ~pix_clk;

    // Everything below mirrors vga_top, with pix_clk in place of the PLL's
    // clk_pixel and locked treated as always high.
    logic       reset_n;
    logic [9:0] x, y;
    logic       video_on;
    logic [2:0] color_input;
    logic       hsync, vsync, r, g, b;

    vga_window_timing timing(
        .clk(pix_clk),
        .reset_n(reset_n),
        .x(x),
        .y(y),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on)
    );

    // Copied from vga_top. If you change the colors there, change them here too.
    assign color_input[2] = (x < 320) ? 1'b1 : 1'b0;   // red
    assign color_input[1] = (y < 160) ? 1'b1 : 1'b0;   // green
    assign color_input[0] = (y >= 320) ? 1'b1 : 1'b0;  // blue

    vga_color_logic colorlogic(
        .video_on(video_on),
        .color_input(color_input),
        .r(r),
        .g(g),
        .b(b)
    );

    // ---------------- what the monitor captured ----------------
    // One byte per raster position: {xz, vs_low, hs_low, r, g, b}
    logic [5:0] scr [0:V_TOTAL-1][0:H_TOTAL-1];

    int   h, k, frames;            // clocks since hsync fell, hsync pulses since vsync fell
    bit   have_h, have_v, done;
    logic hs_d, vs_d;
    int   hs_period, hs_low, hs_run;
    int   vs_period, vs_lines, vs_low, vs_run, vs_since;
    bit   running;

    always @(posedge pix_clk) if (running) begin
        logic hs_fall, vs_fall, xz;
        int   row;

        hs_fall = (hs_d === 1'b1) && (hsync === 1'b0);
        vs_fall = (vs_d === 1'b1) && (vsync === 1'b0);

        // pulse widths
        if (hsync === 1'b0) hs_run++;
        else if (hs_run) begin hs_low = hs_run; hs_run = 0; end
        if (vsync === 1'b0) vs_run++;
        else if (vs_run) begin vs_low = vs_run; vs_run = 0; end

        h++;
        vs_since++;

        if (vs_fall) begin
            if (have_v) begin
                vs_period = vs_since;
                vs_lines  = k;
            end
            vs_since = 0;
            k        = 0;
            have_v   = 1'b1;
            frames++;
            if (frames == CAPTURE_FRAME + 1) done = 1'b1;
        end

        if (hs_fall) begin
            if (have_h) hs_period = h;
            h      = 0;
            have_h = 1'b1;
            k++;
        end

        // store this pixel at its sync-relative position
        if (frames == CAPTURE_FRAME && have_h && h < H_TOTAL && k <= V_TOTAL) begin
            row = (k == 0) ? V_TOTAL - 1 : k - 1;
            xz  = $isunknown({r, g, b});
            scr[row][h] = {xz, (vsync === 1'b0), (hsync === 1'b0),
                           (r === 1'b1), (g === 1'b1), (b === 1'b1)};
        end

        hs_d = hsync;
        vs_d = vsync;
    end

    // ---------------- image writing ----------------
    // Color for one raster position. overlay = 1 shades the blanking/sync areas.
    function automatic logic [23:0] color(logic [5:0] p, bit overlay, int row, int col);
        bit visible;
        visible = (row >= ROW0) && (row < ROW0 + V_DISP) &&
                  (col >= COL0) && (col < COL0 + H_DISP);
        if (p[5])            return 24'hFF8000;                       // X/Z
        if (p[2:0] != 3'b0)  return {{8{p[2]}}, {8{p[1]}}, {8{p[0]}}}; // r, g, b
        if (!overlay)        return 24'h000000;
        if (p[4])            return 24'h00005A;                       // vsync low
        if (p[3])            return 24'h464646;                       // hsync low
        if (!visible)        return 24'h191919;                       // blanking
        return 24'h000000;
    endfunction

    task automatic put_le(int fd, int v, int nbytes);
        for (int i = 0; i < nbytes; i++) $fwrite(fd, "%c", (v >> (8*i)) & 8'hFF);
    endtask

    task automatic write_images(string name, int row0, int col0, int W, int H, bit overlay);
        int fd, rowsize;
        logic [23:0] c;

        // BMP (24-bit, bottom-up rows)
        rowsize = ((W * 3 + 3) / 4) * 4;
        fd = $fopen({name, ".bmp"}, "wb");
        $fwrite(fd, "BM");
        put_le(fd, 54 + rowsize * H, 4);
        put_le(fd, 0, 4);
        put_le(fd, 54, 4);
        put_le(fd, 40, 4);
        put_le(fd, W, 4);
        put_le(fd, H, 4);
        put_le(fd, 1, 2);
        put_le(fd, 24, 2);
        put_le(fd, 0, 4);
        put_le(fd, rowsize * H, 4);
        put_le(fd, 2835, 4);
        put_le(fd, 2835, 4);
        put_le(fd, 0, 4);
        put_le(fd, 0, 4);
        for (int y = H - 1; y >= 0; y--) begin
            for (int x = 0; x < W; x++) begin
                c = color(scr[row0 + y][col0 + x], overlay, row0 + y, col0 + x);
                $fwrite(fd, "%c%c%c", c[7:0], c[15:8], c[23:16]);   // B, G, R
            end
            for (int p = W * 3; p < rowsize; p++) $fwrite(fd, "%c", 8'h00);
        end
        $fclose(fd);

        // PPM (plain text), in case your simulator mangles binary output
        fd = $fopen({name, ".ppm"}, "w");
        $fwrite(fd, "P3\n%0d %0d\n255\n", W, H);
        for (int y = 0; y < H; y++) begin
            for (int x = 0; x < W; x++) begin
                c = color(scr[row0 + y][col0 + x], overlay, row0 + y, col0 + x);
                $fwrite(fd, "%0d %0d %0d ", c[23:16], c[15:8], c[7:0]);
            end
            $fwrite(fd, "\n");
        end
        $fclose(fd);
    endtask

    // ---------------- reporting ----------------
    task automatic check(string what, int got, int exp);
        $display("  %s: %0d (expect %0d)%s", what, got, exp, (got == exp) ? "" : "   <-- MISMATCH");
    endtask

    task automatic report();
        int lit [3], xmin [3], xmax [3], ymin [3], ymax [3];
        int blank_lit, xz_cnt;
        string names [3] = '{"red", "green", "blue"};

        $display("");
        $display("==== sync timing (what the monitor locks onto) ====");
        check("hsync period (clocks)", hs_period, H_TOTAL);
        check("hsync low (clocks)",    hs_low,    H_SYNC);
        check("lines per frame",       vs_lines,  V_TOTAL);
        check("vsync low (clocks)",    vs_low,    V_SYNC * H_TOTAL);
        if (hs_period > 0)
            $display("  hsync = %0.2f kHz, vsync = %0.2f Hz at %0.3f MHz",
                     PIX_MHZ * 1e3 / hs_period, PIX_MHZ * 1e6 / vs_period, PIX_MHZ);
        if (hs_low > H_TOTAL / 2)
            $display("  hsync is low most of the line: polarity looks inverted (should be active-low)");
        if (vs_low > V_TOTAL * H_TOTAL / 2)
            $display("  vsync is low most of the frame: polarity looks inverted (should be active-low)");

        foreach (lit[c]) begin
            lit[c] = 0; xmin[c] = H_DISP; xmax[c] = -1; ymin[c] = V_DISP; ymax[c] = -1;
        end
        blank_lit = 0;
        xz_cnt    = 0;

        for (int y = 0; y < V_TOTAL; y++)
            for (int x = 0; x < H_TOTAL; x++) begin
                bit vis;
                vis = (y >= ROW0) && (y < ROW0 + V_DISP) && (x >= COL0) && (x < COL0 + H_DISP);
                if (scr[y][x][5]) xz_cnt++;
                if (!vis && scr[y][x][2:0] != 0) blank_lit++;
                if (vis)
                    for (int c = 0; c < 3; c++)
                        if (scr[y][x][2 - c]) begin
                            lit[c]++;
                            if (x - COL0 < xmin[c]) xmin[c] = x - COL0;
                            if (x - COL0 > xmax[c]) xmax[c] = x - COL0;
                            if (y - ROW0 < ymin[c]) ymin[c] = y - ROW0;
                            if (y - ROW0 > ymax[c]) ymax[c] = y - ROW0;
                        end
            end

        $display("");
        $display("==== visible picture (frame %0d) ====", CAPTURE_FRAME);
        for (int c = 0; c < 3; c++)
            if (lit[c] == 0) $display("  %s: off everywhere", names[c]);
            else $display("  %s: %0d pixels lit, spanning x %0d..%0d, y %0d..%0d",
                          names[c], lit[c], xmin[c], xmax[c], ymin[c], ymax[c]);
        if (lit[0] + lit[1] + lit[2] == 0)
            $display("  The screen would be completely black.");
        if (blank_lit > 0)
            $display("  WARNING: color is on for %0d clocks during blanking. Monitors expect black there;\n           this can dim or shift the picture. Gate r/g/b with video_on.", blank_lit);
        if (xz_cnt > 0)
            $display("  WARNING: r/g/b were X or Z for %0d clocks (orange in the images).", xz_cnt);

        $display("");
        $display("Wrote frame.bmp / frame.ppm (640x480) and raster.bmp / raster.ppm (800x525).");
    endtask

    // ---------------- stimulus and watchdogs ----------------
    initial begin
        foreach (scr[y, x]) scr[y][x] = '0;
        h = 0; k = 0; frames = 0;
        have_h = 0; have_v = 0; done = 0;
        hs_d = 1'b1; vs_d = 1'b1;
        hs_period = 0; hs_low = 0; hs_run = 0;
        vs_period = 0; vs_lines = 0; vs_low = 0; vs_run = 0; vs_since = 0;
        running = 0;

        reset_n = 1'b0;
        repeat (10) @(posedge pix_clk);
        reset_n = 1'b1;
        running = 1'b1;
        $display("Reset released at %0t. Watching hsync/vsync...", $time);

        // A monitor gives up quickly without sync, so do we.
        repeat (3 * H_TOTAL) @(posedge pix_clk);          // 3 lines
        if (!have_h) begin
            $display("NO HSYNC: hsync never fell in 3 lines (value now: %b).", hsync);
            $display("The monitor would show nothing / go to sleep. Check that reset is released and the counters run.");
            $finish;
        end

        fork
            wait (done);
            begin
                repeat ((CAPTURE_FRAME + 2) * FRAME) @(posedge pix_clk);
                $display("NO VSYNC / FRAME NEVER FINISHED: saw %0d vsync pulses (value now: %b).", frames, vsync);
                $display("hsync period measured: %0d clocks. The monitor would not lock vertically.", hs_period);
                $finish;
            end
        join_any
        disable fork;

        report();
        write_images("frame",  ROW0, COL0, H_DISP,  V_DISP,  1'b0);
        write_images("raster", 0,    0,    H_TOTAL, V_TOTAL, 1'b1);
        $finish;
    end

endmodule