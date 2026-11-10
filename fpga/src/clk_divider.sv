// Emily Ing & Rebecca Kong
// eing@g.hmc.edu & rkong@g.hmc.edu
// Date of creation: 11/8/2026
// Summary: Clock divider for the crystal clock.

module clk_divider (
    input  logic clk_12mhz,   // 12 MHz input from the UPduino board
    output logic clk_25mhz,   // 25.125 MHz output for the VGA pixel clock
    output logic locked       // high once the PLL is stable
);

    // Instantiate the Phase-Locked Loop (PLL) primitive
    // 12 MHz x 67 / 2^5 = 25.125 MHz
    PLL_B #(
        .FEEDBACK_PATH("SIMPLE"),
        .DIVR("0"),             // DIVR = 0, reference clock divider
        .DIVF("66"),            // DIVF = 66, feedback divider (automatically adds 1)
        .DIVQ("5"),             // DIVQ = 5, VCO divider
        .FILTER_RANGE("1")      // 1 is the standard filter range for 10-17 MHz inputs. PFD = Input Clock / (DIVR + 1) = 12 MHz / 1 = 12. 
		// According to Lattice Semiconductor's specifications, any PFD frequency that falls between 10 MHz and 17 MHz requires the analog loop filter to be set to 1
    
	) pll_inst (
        .REFERENCECLK(clk_12mhz), 
        .PLLOUTCORE(clk_25mhz),
        .RESET_N(1'b1),      // Active low reset, tied to 1 to keep it running
        .BYPASS(1'b0),       // Set to 0 so we use the PLL output, not the bypassed input
        .LOCK(locked)
    );

endmodule