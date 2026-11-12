-L work
-reflib pmi_work
-reflib ovi_ice40up


"C:/Users/rkong/Documents/GitHub/E155-Final-Project/fpga/final_proj/source/clk_divider.sv" 
"C:/Users/rkong/Documents/GitHub/E155-Final-Project/fpga/final_proj/source/vga_top.sv" 
"C:/Users/rkong/Documents/GitHub/E155-Final-Project/fpga/final_proj/source/vga_window_timing.sv" 
"C:/Users/rkong/Documents/GitHub/E155-Final-Project/fpga/final_proj/source/vga_color_logic.sv" 
"C:/Users/rkong/Documents/GitHub/E155-Final-Project/fpga/final_proj/source/vga_frame_tb.sv" 
-sv
-optionset VOPTDEBUG
+noacc+pmi_work.*
+noacc+ovi_ice40up.*

-vopt.options
  -suppress vopt-7033
-end

-gui
-top vga_frame_tb
-vsim.options
  -suppress vsim-7033,vsim-8630,3009,3389
-end

-do "view wave"
-do "add wave /*"
-do "run -all"
