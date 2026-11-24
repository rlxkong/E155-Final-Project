// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/20/2026
// Summary: SPI interface.  Loads in maze from MCU

module fpga_spi (
    input  logic       clk,        // 25.125 MHz PLL pixel/system clock
    input  logic       sck,        // SPI clock from STM32 (<= 4 MHz recommended)
    input  logic       sdi,        // MOSI from STM32
    input  logic       cs,         // Active-low Chip Select from STM32
    output logic       sdo,        // MISO (tie low or echo rx_byte[7] for debug)
    output logic [7:0] rx_byte,    // Completed byte synchronized to clk
    output logic       rx_valid,   // 1-cycle pulse on clk when a byte arrives
    output logic       cs_active   // Synchronized active-high transaction flag
);

    // --- SPI Clock Domain (Mode 0: CPOL=0, CPHA=0 -> sample on posedge sck) ---
    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;
    logic [7:0] latched_byte;
    logic       byte_toggle;
	
	// this loop allows us to take 1 byte at a time in to load the maze
    always_ff @(posedge sck, posedge cs) begin
        if (cs) begin
            shift_reg    <= 8'd0;
            bit_cnt      <= 3'd0;
            latched_byte <= 8'd0;
            byte_toggle  <= 1'b0;
        end else begin
            shift_reg <= {shift_reg[6:0], sdi}; // shifting 1 bit at a time, replacing 7th one and introducing 1st one
            if (bit_cnt == 3'd7) begin // reading 7 means we caught our 8th bit
                latched_byte <= {shift_reg[6:0], sdi}; //  Copies the completed 8-bit byte into a safe holding box so shift_reg is free to start catching the next byte without overwriting this one
                byte_toggle  <= ~byte_toggle;
                bit_cnt      <= 3'd0; // Resets the counter back to 0 after 8 bits
            end else begin
                bit_cnt <= bit_cnt + 3'd1; // adds 1 if we are still counting up to 8 bits
            end
        end
    end

    assign sdo = 1'b0; // Unused during maze load

    // --- System Clock Domain (25.125 MHz CDC Synchronizer) ---
    logic [2:0] tog_sync;
    logic [1:0] cs_sync;

    always_ff @(posedge clk) begin
        tog_sync <= {tog_sync[1:0], byte_toggle};
        cs_sync  <= {cs_sync[0], cs};
    end

    assign cs_active = ~cs_sync[1];
    assign rx_valid  = (tog_sync[2] ^ tog_sync[1]) && cs_active;
    assign rx_byte   = latched_byte;

endmodule