# ==============================================================================
# File: ku5p_gmii_pin.xdc
# Description: Physical Pin & I/O Standard Constraints for KU5P-ETH (Bank 87 GMII)
# Target Part: AMD / Xilinx Kintex UltraScale+ (xcku5p-ffvb676-2-i)
# Schematic Reference: U0G (Bank 87, VCCO_87 = +3.3V -> LVCMOS33)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. System Reference Clock & Reset
# ------------------------------------------------------------------------------
set_property PACKAGE_PIN E18      [get_ports clk_I]
set_property IOSTANDARD  LVCMOS18 [get_ports clk_I]

set_property PACKAGE_PIN P19      [get_ports rst]
set_property IOSTANDARD  LVCMOS12 [get_ports rst]
set_property PULLUP      true     [get_ports rst]

# ------------------------------------------------------------------------------
# 2. GMII Receive Interface (PHY -> FPGA, Bank 87, LVCMOS33)
# ------------------------------------------------------------------------------
# ETHPL_RXCLK -> IO_L8P_HDGC_87_D14 (HDGC Global Clock P-Pin)
set_property PACKAGE_PIN D14      [get_ports gmii_rx_clk]
set_property IOSTANDARD  LVCMOS33 [get_ports gmii_rx_clk]

# ETHPL_RXDV -> H12, ETHPL_RXER -> J12
set_property PACKAGE_PIN H12      [get_ports gmii_rx_dv]
set_property PACKAGE_PIN J12      [get_ports gmii_rx_er]
set_property IOSTANDARD  LVCMOS33 [get_ports {gmii_rx_dv gmii_rx_er}]

# ETHPL_RXD[7:0]
set_property PACKAGE_PIN F12      [get_ports {gmii_rxd[0]}]
set_property PACKAGE_PIN G14      [get_ports {gmii_rxd[1]}]
set_property PACKAGE_PIN G12      [get_ports {gmii_rxd[2]}]
set_property PACKAGE_PIN H14      [get_ports {gmii_rxd[3]}]
set_property PACKAGE_PIN J15      [get_ports {gmii_rxd[4]}]
set_property PACKAGE_PIN J14      [get_ports {gmii_rxd[5]}]
set_property PACKAGE_PIN H13      [get_ports {gmii_rxd[6]}]
set_property PACKAGE_PIN J13      [get_ports {gmii_rxd[7]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {gmii_rxd[*]}]

# ------------------------------------------------------------------------------
# 3. GMII Transmit Interface (FPGA -> PHY, Bank 87, LVCMOS33)
# ------------------------------------------------------------------------------
# ETHPL_GTX_CLK -> IO_L7P_HDGC_87_E13
set_property PACKAGE_PIN E13      [get_ports gmii_tx_clk]
set_property IOSTANDARD  LVCMOS33 [get_ports gmii_tx_clk]
set_property SLEW        FAST     [get_ports gmii_tx_clk]
set_property DRIVE       12       [get_ports gmii_tx_clk]

# ETHPL_TXCLK (10/100M MII TX Clock) -> IO_L9N_AD11N_87_C13
# Note: C13 is a non-GC pin driving BUFGMUX.I0; bypass dedicated clock route check
set_property PACKAGE_PIN C13      [get_ports mii_tx_clk]
set_property IOSTANDARD  LVCMOS33 [get_ports mii_tx_clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_ports mii_tx_clk]]

# ETHPL_TXEN -> F14, ETHPL_TXER -> A14
set_property PACKAGE_PIN F14      [get_ports gmii_tx_en]
set_property PACKAGE_PIN A14      [get_ports gmii_tx_er]
set_property IOSTANDARD  LVCMOS33 [get_ports {gmii_tx_en gmii_tx_er}]
set_property SLEW        FAST     [get_ports {gmii_tx_en gmii_tx_er}]
set_property DRIVE       12       [get_ports {gmii_tx_en gmii_tx_er}]

# ETHPL_TXD[7:0]
set_property PACKAGE_PIN E12      [get_ports {gmii_txd[0]}]
set_property PACKAGE_PIN F13      [get_ports {gmii_txd[1]}]
set_property PACKAGE_PIN C14      [get_ports {gmii_txd[2]}]
set_property PACKAGE_PIN C12      [get_ports {gmii_txd[3]}]
set_property PACKAGE_PIN B12      [get_ports {gmii_txd[4]}]
set_property PACKAGE_PIN A12      [get_ports {gmii_txd[5]}]
set_property PACKAGE_PIN A13      [get_ports {gmii_txd[6]}]
set_property PACKAGE_PIN B14      [get_ports {gmii_txd[7]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {gmii_txd[*]}]
set_property SLEW        FAST     [get_ports {gmii_txd[*]}]
set_property DRIVE       12       [get_ports {gmii_txd[*]}]

# ------------------------------------------------------------------------------
# 4. External PHY Hardware Reset (Active-Low ETHPL_RSTB -> D13)
# Uncomment if phy_reset_n port is present at top-level SoC wrapper
# ------------------------------------------------------------------------------
# set_property PACKAGE_PIN D13      [get_ports phy_reset_n]
# set_property IOSTANDARD  LVCMOS33 [get_ports phy_reset_n]
# set_property SLEW        SLOW     [get_ports phy_reset_n]
