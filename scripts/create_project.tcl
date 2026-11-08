# ==============================================================================
# Script: create_project.tcl
# Description: Creates Vivado Project for KU5P-ETH targeting Xilinx KU5P
# Target FPGA: AMD / Xilinx Kintex UltraScale+ (xcku5p-ffvb676-2-i)
# ==============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
set PROJ_NAME  "KU5P-ETH"
set PART_NAME  "xcku5p-ffvb676-2-i"

puts "=========================================================="
puts "  Creating Vivado Project: $PROJ_NAME ($PART_NAME)"
puts "=========================================================="

create_project -force $PROJ_NAME $PROJ_DIR -part $PART_NAME

# Set Project properties
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]

# Add SystemVerilog Design Sources
puts "--> Adding RTL sources from $PROJ_DIR/rtl"
set rtl_files [glob -nocomplain "$PROJ_DIR/rtl/*.sv"]
add_files -norecurse -fileset sources_1 $rtl_files
set_property file_type SystemVerilog [get_files *.sv]

# Add Timing Constraints
puts "--> Adding constraints from $PROJ_DIR/constrs"
set xdc_file "$PROJ_DIR/constrs/ku5p_eth_timing.xdc"
if {[file exists $xdc_file]} {
    add_files -norecurse -fileset constrs_1 $xdc_file
}

# Add CDC / Timing TCL scripts into constraints fileset
set tcl_constrs [glob -nocomplain "$PROJ_DIR/constrs/*.tcl"]
foreach tf $tcl_constrs {
    add_files -norecurse -fileset constrs_1 $tf
    set_property USED_IN {synthesis implementation} [get_files [file tail $tf]]
}

# Set Top Module
set_property top taxi_eth_gmii_axi_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Add Simulation Testbench
puts "--> Adding testbench from $PROJ_DIR/tb"
set tb_file "$PROJ_DIR/tb/test_taxi_eth_gmii_axi_wrapper.sv"
if {[file exists $tb_file]} {
    add_files -norecurse -fileset sim_1 $tb_file
    set_property file_type SystemVerilog [get_files test_taxi_eth_gmii_axi_wrapper.sv]
    set_property top test_taxi_eth_gmii_axi_wrapper [get_filesets sim_1]
    update_compile_order -fileset sim_1
}

puts "=========================================================="
puts "  Project $PROJ_NAME created successfully!"
puts "=========================================================="

