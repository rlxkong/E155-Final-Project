// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/20/2026
// Summary:  150 x 8-bit (1,200-bit) inferred Block RAM for 40x30 maze tiles
// We need this just because we need to send 40x30 = 1,200 bits (150 bytes) when initializing or resetting a level
// 40 from 640 / 16 = 40 tiles. 480 / 16 = 30 tiles

module fpga_maze_ram (
    input  logic       clk,
    input  logic       we,
    input  logic [7:0] waddr,      // 0 to 149
    input  logic [7:0] wdata,
    input  logic [7:0] raddr,      // 0 to 149
    output logic [7:0] rdata       // Available 1 clk cycle after raddr
);
    logic [7:0] mem [0:149];

    always_ff @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
        rdata <= mem[raddr];       // Synchronous read infers iCE40 EBR
    end
endmodule