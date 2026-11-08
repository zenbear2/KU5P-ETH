# ==============================================================================
# Script: run_sim_xsim.tcl
# Description: Vivado xsim batch simulation script for KU5P-ETH testbench
# ==============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
set RTL_DIR    "$PROJ_DIR/rtl"
set TB_DIR     "$PROJ_DIR/tb"
set WORK_DIR   "$TB_DIR/xsim_run"

file mkdir $WORK_DIR
cd $WORK_DIR

puts "=========================================================="
puts "  Parsing SystemVerilog Design & Testbench Sources"
puts "=========================================================="

set f [open "$RTL_DIR/taxi_eth_gmii_axi_wrapper.f" r]
set file_data [read $f]
close $f

set sv_files [list]
foreach line [split $file_data "\n"] {
    set trimmed [string trim $line]
    if {$trimmed ne "" && ![string match "//*" $trimmed] && ![string match "#*" $trimmed]} {
        lappend sv_files "$RTL_DIR/$trimmed"
    }
}
lappend sv_files "$TB_DIR/test_taxi_eth_gmii_axi_wrapper.sv"

# Compile SystemVerilog files
exec xvlog -sv {*}$sv_files

# Elaborate
puts "=========================================================="
puts "  Elaborating Testbench"
puts "=========================================================="
exec xelab -top test_taxi_eth_gmii_axi_wrapper -snapshot sim_snapshot -timescale 1ns/1ps -debug typical

# Run simulation
puts "=========================================================="
puts "  Running Simulation"
puts "=========================================================="
exec xsim sim_snapshot -R

puts "Simulation finished successfully."

