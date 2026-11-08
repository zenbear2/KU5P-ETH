# ==============================================================================
# Script: run_synth.tcl
# Description: Vivado Synthesis Automation Script for KU5P-ETH
# Target FPGA: AMD / Xilinx Kintex UltraScale+ (xcku5p-ffvb676-2-i)
# ==============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
set XPR_FILE   "$PROJ_DIR/KU5P-ETH.xpr"
set RPT_DIR    "$PROJ_DIR/reports"
set PART_NAME  "xcku5p-ffvb676-2-i"

file mkdir $RPT_DIR

# Open or create project
if {[file exists $XPR_FILE]} {
    puts "=========================================================="
    puts "  Opening Vivado Project: $XPR_FILE"
    puts "=========================================================="
    open_project $XPR_FILE
} else {
    puts "=========================================================="
    puts "  Project not found, creating project first..."
    puts "=========================================================="
    source "$SCRIPT_DIR/create_project.tcl"
}

set_property part $PART_NAME [current_project]

puts "=========================================================="
puts "  Configuring Synthesis for Kintex UltraScale+ ($PART_NAME)"
puts "=========================================================="

set_property top taxi_eth_gmii_axi_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "=========================================================="
puts "  Launching Synthesis (synth_1)"
puts "=========================================================="
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis Status: $synth_status"

if {[string match "*Complete*" $synth_status]} {
    puts "=========================================================="
    puts "  Synthesis Succeeded! Generating Reports..."
    puts "=========================================================="
    open_run synth_1 -name synth_1
    
    # Generate Reports
    report_utilization -file "$RPT_DIR/utilization_summary.rpt"
    report_utilization -hierarchical -file "$RPT_DIR/utilization_hierarchical.rpt"
    report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -routable_nets -file "$RPT_DIR/timing_summary.rpt"
    report_clock_utilization -file "$RPT_DIR/clock_utilization.rpt"

    puts "Reports saved to: $RPT_DIR"
} else {
    puts "ERROR: Synthesis did not complete successfully!"
}

# Close Project cleanly
close_project
