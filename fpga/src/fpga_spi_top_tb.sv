`timescale 1ns / 1ps

module fpga_spi_top_tb;

    // Timing constants matching proposal:
    // 25.125 MHz FPGA PLL clock (~39.8 ns) and 2.5 MHz SPI clock (400 ns)
    localparam real CLK_PERIOD = 39.8;
    localparam real SCK_PERIOD = 400.0;

    // DUT Signals
    logic        clk;
    logic        sck;
    logic        sdi;
    logic        sdo;
    logic        cs;
    logic [7:0]  vga_raddr;
    logic [7:0]  vga_rdata;
    logic [47:0] game_state;

    // Instantiate the top-level SPI + Block RAM module
    fpga_spi_top dut (
        .clk        (clk),
        .sck        (sck),
        .sdi        (sdi),
        .sdo        (sdo),
        .cs         (cs),
        .vga_raddr  (vga_raddr),
        .vga_rdata  (vga_rdata),
        .game_state (game_state)
    );

    // 25.125 MHz FPGA system clock generator
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2.0) clk = ~clk;

    // 30 rows x 40 columns maze definition ('#' = wall/1, '.' = path/0)
    string maze_rows [0:29] = '{
        "########################################",
        "#......................................#",
        "#.######.########.##########.#########.#",
        "#.#....#........#..........#.#.......#.#",
        "#.#.##.########.##########.#.#.#####.#.#",
        "#...##..........#..........#...#...#...#",
        "###.#############.##########.###.#.###.#",
        "#...#.............#..........#...#.....#",
        "#.###.#############.##########.#######.#",
        "#.#...#...........#..........#.......#.#",
        "#.#.###.#########.#.########.#######.#.#",
        "#.#.....#.......#.#.#......#.......#...#",
        "#.#######.#####.#.#.#.####.#######.###.#",
        "#.........#...#...#...#..#.......#.....#",
        "###########.#.#########.##########.###.#",
        "#...........#...........#..........#...#",
        "#.#####################.#.##########.###",
        "#.#...................#.#..........#...#",
        "#.#.#################.#.##########.###.#",
        "#...#...............#.#..........#.....#",
        "###.#.#############.#.##########.#####.#",
        "#...#.#...........#.#..........#.....#.#",
        "#.###.#.#########.#.##########.#####.#.#",
        "#.....#.#.......#...#........#.....#...#",
        "#.#####.#.#####.#####.######.#####.###.#",
        "#.#.....#.#...#.....#......#.....#.....#",
        "#.#.#####.#.#.#####.######.#####.#####.#",
        "#...#.....#.#.....#......#.....#.....#.#",
        "###.#.#####.#####.######.#####.#####.#..",
        "########################################"
    };

    // Packed 150-byte array representing what the STM32 stores in Flash
    logic [7:0] mcu_maze [0:149];

    // Task: Bit-bang 1 byte over SPI Mode 0 (CPOL=0, CPHA=0, MSB first)
    task automatic spi_send_byte(input logic [7:0] data);
        for (int i = 7; i >= 0; i--) begin
            sdi = data[i];               // Drive MOSI while SCK is low
            #(SCK_PERIOD / 2.0);
            sck = 1'b1;                  // Rising edge: FPGA samples SDI
            #(SCK_PERIOD / 2.0);
            sck = 1'b0;                  // Falling edge
        end
    endtask

    // Task: Pretend STM32 sends Command 0x01 + 150 maze bytes
    task automatic mcu_send_maze();
        cs = 1'b0;
        #(SCK_PERIOD / 2.0);
        spi_send_byte(8'h01);            // Command 0x01: Load Maze
        for (int idx = 0; idx < 150; idx++) begin
            spi_send_byte(mcu_maze[idx]);
        end
        #(SCK_PERIOD / 2.0);            // Wait for 25.125 MHz synchronizer to latch last byte
        cs = 1'b1;
        #(SCK_PERIOD);
    endtask

    // Task: Pretend STM32 sends Command 0x02 + 6 bytes (48-bit game state)
    task automatic mcu_send_game_state(input logic [47:0] packet);
        cs = 1'b0;
        #(SCK_PERIOD / 2.0);
        spi_send_byte(8'h02);            // Command 0x02: Update Game State
        for (int b = 5; b >= 0; b--) begin
            spi_send_byte(packet[b*8 +: 8]);
        end
        #(SCK_PERIOD / 2.0);
        cs = 1'b1;
        #(SCK_PERIOD);
    endtask
	
	// Task: Read maze from Block RAM and save a 640x480 image (maze_output.bmp)
    task automatic save_maze_image();
        int fd;
        logic [39:0] maze_grid [0:29];
        logic [7:0]  bmp_hdr [0:53] = '{
            8'h42, 8'h4D,                         // "BM" signature
            8'h36, 8'h10, 8'h0E, 8'h00,           // File size: 54 + 640*480*3 = 921,654 bytes
            8'h00, 8'h00, 8'h00, 8'h00,           // Reserved
            8'h36, 8'h00, 8'h00, 8'h00,           // Pixel data offset: 54 bytes
            8'h28, 8'h00, 8'h00, 8'h00,           // DIB header size: 40 bytes
            8'h80, 8'h02, 8'h00, 8'h00,           // Width: 640 px
            8'hE0, 8'h01, 8'h00, 8'h00,           // Height: 480 px
            8'h01, 8'h00,                         // Color planes: 1
            8'h18, 8'h00,                         // Bits per pixel: 24 (RGB)
            8'h00, 8'h00, 8'h00, 8'h00,           // Compression: none
            8'h00, 8'h10, 8'h0E, 8'h00,           // Image size: 921,600 bytes
            8'h00, 8'h00, 8'h00, 8'h00,           // X pixels/m
            8'h00, 8'h00, 8'h00, 8'h00,           // Y pixels/m
            8'h00, 8'h00, 8'h00, 8'h00,           // Colors in palette
            8'h00, 8'h00, 8'h00, 8'h00            // Important colors
        };

        // 1. Read all 30 rows (150 bytes) out of FPGA Block RAM
        for (int r = 0; r < 30; r++) begin
            for (int b = 0; b < 5; b++) begin
                vga_raddr = r * 5 + b;
                @(posedge clk);
                #1;
                maze_grid[r][39 - b*8 -: 8] = vga_rdata;
            end
        end

        // 2. Write 640x480 BMP image (BMP stores rows bottom-to-top)
        fd = $fopen("maze_output.bmp", "wb");
        for (int i = 0; i < 54; i++)
            $fwrite(fd, "%c", bmp_hdr[i]);

        for (int r = 29; r >= 0; r--) begin
            for (int py = 0; py < 16; py++) begin
                for (int c = 0; c < 40; c++) begin
                    for (int px = 0; px < 16; px++) begin
                        if (maze_grid[r][39 - c]) begin
                            // Wall (1): Dark Navy (B=90, G=40, R=20)
                            $fwrite(fd, "%c%c%c", 8'd90, 8'd40, 8'd20);
                        end else begin
                            // Path (0): Off-White (B=245, G=245, R=245)
                            $fwrite(fd, "%c%c%c", 8'd245, 8'd245, 8'd245);
                        end
                    end
                end
            end
        end
        $fclose(fd);
        $display("[TB] Saved 640x480 maze image to maze_output.bmp");
    endtask

    // Main test sequence
    initial begin
        int r, b, bit_i, errors;
        logic [47:0] test_state;

        // 1. Initialize idle SPI signals (Mode 0: SCK idle low, CS idle high)
        sck       = 1'b0;
        sdi       = 1'b0;
        cs        = 1'b1;
        vga_raddr = 8'd0;
        errors    = 0;

        // Pack the 30x40 ASCII maze into 150 bytes (5 bytes per row, MSB = leftmost tile)
        for (r = 0; r < 30; r++) begin
            for (b = 0; b < 5; b++) begin
                for (bit_i = 0; bit_i < 8; bit_i++) begin
                    mcu_maze[r*5 + b][7 - bit_i] = (maze_rows[r][b*8 + bit_i] == "#") ? 1'b1 : 1'b0;
                end
            end
        end

        #(CLK_PERIOD * 10);

        // 2. Transmit the 150-byte maze from the "MCU" to the FPGA
        $display("=== [TB] Sending 150-byte (40x30) Maze over SPI ===");
        mcu_send_maze();

        // 3. Read back all 150 bytes from Block RAM and print the maze
        $display("=== [TB] Reading Maze Back from FPGA Block RAM ===\n");
        for (r = 0; r < 30; r++) begin
            for (b = 0; b < 5; b++) begin
                vga_raddr = r * 5 + b;
                @(posedge clk); // Cycle 1: Block RAM samples vga_raddr
                #1;             // Small delta delay so vga_rdata settles

                // Verify Block RAM byte matches original MCU byte
                if (vga_rdata !== mcu_maze[r*5 + b]) begin
                    $error("Mismatch at byte %0d: expected 8'h%02h, got 8'h%02h",
                           r*5 + b, mcu_maze[r*5 + b], vga_rdata);
                    errors++;
                end

                // Print 8 horizontal tiles ('#' for wall, '.' for open path)
                for (bit_i = 0; bit_i < 8; bit_i++) begin
                    $write("%s", vga_rdata[7 - bit_i] ? "#" : ".");
                end
            end
            $write("\n");
        end

        // 4. Verify 48-bit game-state packet reception (Cmd 0x02)
        test_state = 48'h0140_00F0_3C00; // e.g. X=320, Y=240, Timer=60s, Flags=0
        $display("\n=== [TB] Sending 48-bit Game State Packet (0x%012h) ===", test_state);
        mcu_send_game_state(test_state);

        if (game_state !== test_state) begin
            $error("Game state mismatch: expected 48'h%012h, got 48'h%012h", test_state, game_state);
            errors++;
        end else begin
            $display("[TB] Game state latched accurately: 48'h%012h", game_state);
        end
		
		// 5. Final check
        if (errors == 0) begin
            $display("\n=== ALL TESTS PASSED (0 errors) ===");
            save_maze_image();
        end else begin
            $display("\n=== TEST FAILED (%0d errors) ===", errors);
        end

        $finish;
    end

endmodule