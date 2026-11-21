-L work
-reflib pmi_work
-reflib ovi_ice40up


"C:/Users/eing/Documents/GitHub/E155-Final-Project/fpga/final_proj/source/final_proj/fpga_spi.sv" 
"C:/Users/eing/Documents/GitHub/E155-Final-Project/fpga/final_proj/source/final_proj/fpga_spi_top.sv" 
"C:/Users/eing/Documents/GitHub/E155-Final-Project/fpga/final_proj/source/final_proj/fpga_maze_ram.sv" 
"C:/Users/eing/Documents/GitHub/E155-Final-Project/fpga/final_proj/source/final_proj/fpga_spi_top_tb.sv" 
-sv
-optionset VOPTDEBUG
+noacc+pmi_work.*
+noacc+ovi_ice40up.*

-vopt.options
  -suppress vopt-7033
-end

-gui
-top fpga_spi_top_tb
-vsim.options
  -suppress vsim-7033,vsim-8630,3009,3389
-end

-do "view wave"
-do "add wave /*"
-do "run -all"
