// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/20/2026
// Summary: Routes SPI packets to Maze Block RAM (cmd 0x01) or Game State (cmd 0x02)


module fpga_spi_top (
    input  logic        clk,       // 25.125 MHz PLL clock
    input  logic        sck,
    input  logic        sdi,
    output logic        sdo,
    input  logic        cs,
    // Interface to VGA Driver
    input  logic [7:0]  vga_raddr,
    output logic [7:0]  vga_rdata,
    output logic [39:0] game_state // 48-bit packet (dot X, dot Y, timer, flags)
);
    logic [7:0] rx_byte;
    logic       rx_valid, cs_active;

    logic [7:0]  cmd;                // packet header
    logic [7:0]  byte_idx;           // counts how many bytes have arrived in a packet
    logic        ram_we;
    logic [7:0]  ram_waddr;
    logic [39:0] state_buf;         // buffer for game state being shifted in
    lgoic [39:0] state_next;        // state buffer and rx_byte shifted in

    // instantiate SPI byte receiver
    fpga_spi spi_inst (
        .clk(clk), 
        .sck(sck), 
        .sdi(sdi), 
        .cs(cs), 
        .sdo(sdo),
        .rx_byte(rx_byte), 
        .rx_valid(rx_valid), 
        .cs_active(cs_active)
    );

    assign state_next = {state_buf[39:0], rx_byte};

    // Packet parser & Block RAM write controller
    // byte 0 is the cmd and the rest is the payload
    always_ff @(posedge clk) begin
        ram_we <= 1'b0;

        if (!cs_active) begin // 0 between SPI transfers
            byte_idx <= 8'd0;
            cmd      <= 8'd0;
        end 
        // Runs only during the single clock tick when fpga_spi announces a new byte has arrived
        else if (rx_valid) begin 
            if (byte_idx == 8'd0) begin
                cmd <= rx_byte; // First byte identifies packet type (The very first byte (0) is saved into cmd as the packet header.)
            end 
            else if (cmd == 8'h01 && byte_idx <= 8'd150) begin
                // Command 0x01: Load 150-byte (1,200-bit) maze into Block RAM
                ram_we    <= 1'b1;
                ram_waddr <= byte_idx - 8'd1;
            end 
            else if (cmd == 8'h02 && byte_idx <= 8'd6) begin
                // Command 0x02: Shift in 48-bit (6-byte) runtime game state
                state_buf <= state_next;
                if (byte_idx == 8'd6)
                    game_state <= state_next;
            end
            byte_idx <= byte_idx + 8'd1;
        end
    end

    // instantiate maze RAM (written by SPI, read by VGA)
    fpga_maze_ram ram_inst (
        .clk(clk),
        .we(ram_we),
        .waddr(ram_waddr),
        .wdata(rx_byte),
        .raddr(vga_raddr),
        .rdata(vga_rdata)
    );

endmodule