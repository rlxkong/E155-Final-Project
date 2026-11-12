create_clock -name {clk} -period 83.33 [get_ports {clk}]

// replace 83.33 w/ your clock's period in nanoseconds and clk with the exact top-level input port name used in vga_top.sv.)