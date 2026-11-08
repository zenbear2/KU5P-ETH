# ==============================================================================
# Script: package_ip.tcl
# Description: Packages taxi_eth_gmii_axi_wrapper as a Vivado IP core
# Target FPGA: AMD / Xilinx Kintex UltraScale+ (xcku5p-ffvb676-2-i)
# ==============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
set IP_DIR     "$PROJ_DIR/ip_repo/taxi_eth_gmii_axi_wrapper"
set XPR_FILE   "$PROJ_DIR/KU5P-ETH.xpr"

file mkdir $IP_DIR

if {[file exists $XPR_FILE]} {
    open_project $XPR_FILE
} else {
    source "$SCRIPT_DIR/create_project.tcl"
}

puts "=========================================================="
puts "  Packaging IP: taxi_eth_gmii_axi_wrapper -> $IP_DIR"
puts "=========================================================="

# Infer IP definition
ipx::package_project -root_dir $IP_DIR -vendor "taxi" -library "user" -taxonomy "/Communication_Utility" -import_files -force

set core [ipx::current_core]

# Set Identification
set_property name "taxi_eth_gmii_axi_wrapper" $core
set_property display_name "KU5P GMII Ethernet MAC AXI Wrapper" $core
set_property description "1G Ethernet GMII MAC with AXI4-Lite CSR, AXI4-Stream TX/RX FIFOs and CDC, optimized for Xilinx Kintex UltraScale+ (KU5P)" $core
set_property version "1.0" $core
set_property vendor_display_name "Taxi Project" $core

# Set Supported FPGA Families
set_property supported_families { \
    kintexuplus     Production \
    virtexuplus     Production \
    zynquplus       Production \
    zynquplusRFSOC  Production \
    kintexu         Production \
    virtexu         Production \
} $core

# Associate Clocks & Resets to Bus Interfaces
ipx::infer_bus_interface axis_aclk xilinx.com:signal:clock_rtl:1.0 $core
ipx::infer_bus_interface axis_aresetn xilinx.com:signal:reset_rtl:1.0 $core
ipx::infer_bus_interface gtx_clk xilinx.com:signal:clock_rtl:1.0 $core
ipx::infer_bus_interface gtx_reset xilinx.com:signal:reset_rtl:1.0 $core
ipx::infer_bus_interface irq xilinx.com:signal:interrupt_rtl:1.0 $core

# Save and close
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core

puts "=========================================================="
puts "  IP Packaged successfully into: $IP_DIR"
puts "=========================================================="
close_project
