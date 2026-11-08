# ==============================================================================
# Script: ku5p_eth_timing.xdc
# Description: Timing and CDC constraints for taxi_eth_gmii_axi_wrapper
# Target FPGA: AMD / Xilinx Kintex UltraScale+ (xcku5p-ffvb676-2-i)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Primary Clock Definitions (Out-of-Context / Module level)
# ------------------------------------------------------------------------------
# AXI4-Stream & AXI4-Lite Clock (e.g., 100 MHz or 125 MHz system clock)
create_clock -period 8.000 -name axis_aclk [get_ports axis_aclk]

# GMII 125 MHz Reference Transmit Clock
create_clock -period 8.000 -name gtx_clk [get_ports gtx_clk]

# GMII Receive Clock from External PHY
create_clock -period 8.000 -name gmii_rx_clk [get_ports gmii_rx_clk]

# MII 10/100 Mbps Transmit Clock (optional fallback for 10/100M MII mode)
create_clock -period 40.000 -name mii_tx_clk [get_ports mii_tx_clk]

# ------------------------------------------------------------------------------
# 2. Forwarded GMII TX Clock (from internal ODDR primitive)
# ------------------------------------------------------------------------------
create_generated_clock -name gmii_tx_clk_out \
    -source [get_pins -hier -filter {NAME =~ *clk_oddr_inst/*oddr_inst/C}] \
    -divide_by 1 \
    [get_ports gmii_tx_clk]

# ------------------------------------------------------------------------------
# 3. GMII Input Delay (Source-Synchronous DDR/SDR PHY Interface)
# Typical GMII timing budget at 125 MHz (8.0 ns period):
# Setup time ~2.0 ns, Hold time ~0.0 ns from external PHY
# ------------------------------------------------------------------------------
set_input_delay -clock [get_clocks gmii_rx_clk] -max 2.000 [get_ports {gmii_rxd[*] gmii_rx_dv gmii_rx_er}]
set_input_delay -clock [get_clocks gmii_rx_clk] -min 0.000 [get_ports {gmii_rxd[*] gmii_rx_dv gmii_rx_er}]

# ------------------------------------------------------------------------------
# 4. GMII Output Delay
# Setup requirement ~2.5 ns, Hold requirement ~0.5 ns for external PHY
# ------------------------------------------------------------------------------
set_output_delay -clock [get_clocks gmii_tx_clk_out] -max 2.500 [get_ports {gmii_txd[*] gmii_tx_en gmii_tx_er}]
set_output_delay -clock [get_clocks gmii_tx_clk_out] -min -0.500 [get_ports {gmii_txd[*] gmii_tx_en gmii_tx_er}]

# ------------------------------------------------------------------------------
# 5. False Paths and Asynchronous Resets
# ------------------------------------------------------------------------------
# Asynchronous active-low reset for AXI domain
set_false_path -through [get_ports axis_aresetn]

# Asynchronous active-high reset for GTX domain
set_false_path -through [get_ports gtx_reset]

# IRQ output is level-sensitive interrupt to interrupt controller
set_false_path -to [get_ports irq]

# Unregistered status indicators in axis_aclk domain (non-critical monitoring)
set_false_path -to [get_ports {tx_error_underflow tx_fifo_overflow tx_fifo_bad_frame tx_fifo_good_frame}]
set_false_path -to [get_ports {rx_error_bad_frame rx_error_bad_fcs rx_fifo_overflow rx_fifo_bad_frame rx_fifo_good_frame link_speed[*]}]

# ------------------------------------------------------------------------------
# NOTE ON CDC CONSTRAINTS:
# CDC paths between axis_aclk, gtx_clk, and gmii_rx_clk are constrained via
# dedicated TCL constraint scripts with max-delay and bus-skew datapath checks:
#   - constrs/taxi_eth_gmii_cfg_cdc.tcl
#   - constrs/taxi_eth_mac_fifo.tcl
#   - constrs/taxi_axis_async_fifo.tcl
#   - constrs/taxi_sync_reset.tcl
#   - constrs/taxi_sync_signal.tcl
# Do NOT apply broad 'set_clock_groups -asynchronous' across these clock domains,
# as it would override the max-delay and bus-skew constraints on CDC buses.
# ------------------------------------------------------------------------------
