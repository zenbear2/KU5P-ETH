# ==============================================================================
# Script: package_ip.tcl
# Description: Fully packages taxi_eth_gmii_axi_wrapper as a Vivado IP core
# Target FPGA: AMD / Xilinx Kintex UltraScale+ (xcku5p-ffvb676-2-i)
# ==============================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set PROJ_DIR   [file normalize "$SCRIPT_DIR/.."]
set IP_DIR     "$PROJ_DIR/ip_repo/taxi_eth_gmii_axi_wrapper"
set XPR_FILE   "$PROJ_DIR/KU5P-ETH.xpr"

puts "=========================================================="
puts "  Opening Vivado Project: $XPR_FILE"
puts "=========================================================="

if {[file exists $XPR_FILE]} {
    open_project $XPR_FILE
} else {
    source "$SCRIPT_DIR/create_project.tcl"
}

set_property top taxi_eth_gmii_axi_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Clean and recreate IP directory
file delete -force $IP_DIR
file mkdir $IP_DIR

puts "=========================================================="
puts "  Packaging Project as IP -> $IP_DIR"
puts "=========================================================="

ipx::package_project -root_dir $IP_DIR -vendor "taxi" -library "user" -taxonomy "/Communication_Utility" -import_files -force

set core [ipx::current_core]

# ------------------------------------------------------------------------------
# 1. Identification Properties
# ------------------------------------------------------------------------------
set_property name "taxi_eth_gmii_axi_wrapper" $core
set_property display_name "KU5P 1G GMII Ethernet MAC AXI Wrapper" $core
set_property description "1G Ethernet GMII MAC with AXI4-Lite CSR, AXI4-Stream TX/RX Async FIFOs and CDC, optimized for Xilinx Kintex UltraScale+ (xcku5p-ffvb676-2-i)" $core
set_property version "1.0" $core
set_property vendor_display_name "Taxi Project" $core
set_property company_url "https://github.com/zenbear2/KU5P-ETH" $core

# ------------------------------------------------------------------------------
# 2. Supported FPGA Architectures
# ------------------------------------------------------------------------------
set_property supported_families { \
    kintexuplus     Production \
    virtexuplus     Production \
    zynquplus       Production \
    kintexu         Production \
    virtexu         Production \
} $core

# ------------------------------------------------------------------------------
# 3. Associate Clocks & Resets to Bus Interfaces
# ------------------------------------------------------------------------------
set aclk_bus [ipx::get_bus_interfaces axis_aclk -of_objects $core]
if {[llength $aclk_bus] != 0} {
    set p [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $aclk_bus]
    if {[llength $p] == 0} { set p [ipx::add_bus_parameter ASSOCIATED_BUSIF $aclk_bus] }
    set_property value "S_AXIS_TX:M_AXIS_RX:S_AXI_CTRL" $p

    set r [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $aclk_bus]
    if {[llength $r] == 0} { set r [ipx::add_bus_parameter ASSOCIATED_RESET $aclk_bus] }
    set_property value "axis_aresetn" $r
}

set gtx_clk_bus [ipx::get_bus_interfaces gtx_clk -of_objects $core]
if {[llength $gtx_clk_bus] != 0} {
    set p [ipx::get_bus_parameters FREQ_HZ -of_objects $gtx_clk_bus]
    if {[llength $p] == 0} { set p [ipx::add_bus_parameter FREQ_HZ $gtx_clk_bus] }
    set_property value "125000000" $p

    set r [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $gtx_clk_bus]
    if {[llength $r] == 0} { set r [ipx::add_bus_parameter ASSOCIATED_RESET $gtx_clk_bus] }
    set_property value "gtx_reset" $r
}

set gmii_tx_clk_bus [ipx::get_bus_interfaces gmii_tx_clk -of_objects $core]
if {[llength $gmii_tx_clk_bus] != 0} {
    set p [ipx::get_bus_parameters FREQ_HZ -of_objects $gmii_tx_clk_bus]
    if {[llength $p] == 0} { set p [ipx::add_bus_parameter FREQ_HZ $gmii_tx_clk_bus] }
    set_property value "125000000" $p
}

set gmii_rx_clk_bus [ipx::get_bus_interfaces gmii_rx_clk -of_objects $core]
if {[llength $gmii_rx_clk_bus] != 0} {
    set p [ipx::get_bus_parameters FREQ_HZ -of_objects $gmii_rx_clk_bus]
    if {[llength $p] == 0} { set p [ipx::add_bus_parameter FREQ_HZ $gmii_rx_clk_bus] }
    set_property value "125000000" $p
}

set mii_tx_clk_bus [ipx::get_bus_interfaces mii_tx_clk -of_objects $core]
if {[llength $mii_tx_clk_bus] != 0} {
    set p [ipx::get_bus_parameters FREQ_HZ -of_objects $mii_tx_clk_bus]
    if {[llength $p] == 0} { set p [ipx::add_bus_parameter FREQ_HZ $mii_tx_clk_bus] }
    set_property value "25000000" $p
}

# ------------------------------------------------------------------------------
# 4. Handle Constraint Files in File Groups
# ------------------------------------------------------------------------------
# Fix file types of imported TCL constraint files
foreach fg [ipx::get_file_groups -of_objects $core] {
    foreach f [ipx::get_files -of_objects $fg -filter {NAME =~ *.tcl}] {
        set_property type tclSource $f
        set_property used_in {synthesis implementation} $f
    }
    foreach f [ipx::get_files -of_objects $fg -filter {NAME =~ *timing.xdc}] {
        set_property used_in {out_of_context} $f
    }
}

# ------------------------------------------------------------------------------
# 5. User Parameter Customization in GUI
# ------------------------------------------------------------------------------
catch {
    set_property tooltip "Target FPGA family primitive mapping (defaults to kintexuplus for KU5P)" [ipgui::get_guiparamspec -name "FPGA_FAMILY" -component $core]
    set_property tooltip "Simulation mode flag (1 to avoid hardware primitives in testbench)" [ipgui::get_guiparamspec -name "SIM" -component $core]
    set_property tooltip "AXI4-Stream data width in bits (power of 2, >= 8)" [ipgui::get_guiparamspec -name "AXIS_DATA_WIDTH" -component $core]
    set_property tooltip "Transmit Frame FIFO depth in bytes (power of 2)" [ipgui::get_guiparamspec -name "TX_FIFO_DEPTH" -component $core]
    set_property tooltip "Receive Frame FIFO depth in bytes (power of 2)" [ipgui::get_guiparamspec -name "RX_FIFO_DEPTH" -component $core]
}

# ------------------------------------------------------------------------------
# 6. Generate XGUI files, Update Checksums and Save
# ------------------------------------------------------------------------------
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core

puts "=========================================================="
puts "  IP Core packaged successfully!"
puts "  Output Path: $IP_DIR"
puts "  Component XML: $IP_DIR/component.xml"
puts "=========================================================="

close_project
