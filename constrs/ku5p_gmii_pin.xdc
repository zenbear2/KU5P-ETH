#CLK
set_property IOSTANDARD LVCMOS18 [get_ports clk_i]
set_property PACKAGE_PIN E18 [get_ports clk_i]

#UART
set_property IOSTANDARD LVCMOS18 [get_ports uart_0_rxd]
set_property IOSTANDARD LVCMOS18 [get_ports uart_0_txd]
set_property PACKAGE_PIN H16 [get_ports uart_0_rxd]
set_property PACKAGE_PIN G16 [get_ports uart_0_txd]

# DDR4
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports {c0_ddr4_ck_t[0]}]

set_property PACKAGE_PIN T24 [get_ports c0_sys_clk_p]

set_property PACKAGE_PIN AD24 [get_ports {c0_ddr4_dq[0]}]
set_property PACKAGE_PIN AF24 [get_ports {c0_ddr4_dq[1]}]
set_property PACKAGE_PIN AB26 [get_ports {c0_ddr4_dq[2]}]
set_property PACKAGE_PIN AB24 [get_ports {c0_ddr4_dq[3]}]
set_property PACKAGE_PIN AC24 [get_ports {c0_ddr4_dq[4]}]
set_property PACKAGE_PIN AB25 [get_ports {c0_ddr4_dq[5]}]
set_property PACKAGE_PIN AF25 [get_ports {c0_ddr4_dq[6]}]
set_property PACKAGE_PIN AD25 [get_ports {c0_ddr4_dq[7]}]
set_property PACKAGE_PIN AD23 [get_ports {c0_ddr4_dq[8]}]
set_property PACKAGE_PIN AE23 [get_ports {c0_ddr4_dq[9]}]
set_property PACKAGE_PIN AD21 [get_ports {c0_ddr4_dq[10]}]
set_property PACKAGE_PIN AC23 [get_ports {c0_ddr4_dq[11]}]
set_property PACKAGE_PIN AC22 [get_ports {c0_ddr4_dq[12]}]
set_property PACKAGE_PIN AE21 [get_ports {c0_ddr4_dq[13]}]
set_property PACKAGE_PIN AB21 [get_ports {c0_ddr4_dq[14]}]
set_property PACKAGE_PIN AC21 [get_ports {c0_ddr4_dq[15]}]
set_property PACKAGE_PIN AF17 [get_ports {c0_ddr4_dq[16]}]
set_property PACKAGE_PIN AE17 [get_ports {c0_ddr4_dq[17]}]
set_property PACKAGE_PIN AC19 [get_ports {c0_ddr4_dq[18]}]
set_property PACKAGE_PIN AF18 [get_ports {c0_ddr4_dq[19]}]
set_property PACKAGE_PIN AF19 [get_ports {c0_ddr4_dq[20]}]
set_property PACKAGE_PIN AD19 [get_ports {c0_ddr4_dq[21]}]
set_property PACKAGE_PIN AE16 [get_ports {c0_ddr4_dq[22]}]
set_property PACKAGE_PIN AD16 [get_ports {c0_ddr4_dq[23]}]
set_property PACKAGE_PIN AB20 [get_ports {c0_ddr4_dq[24]}]
set_property PACKAGE_PIN AB19 [get_ports {c0_ddr4_dq[25]}]
set_property PACKAGE_PIN AA19 [get_ports {c0_ddr4_dq[26]}]
set_property PACKAGE_PIN AA20 [get_ports {c0_ddr4_dq[27]}]
set_property PACKAGE_PIN Y17 [get_ports {c0_ddr4_dq[28]}]
set_property PACKAGE_PIN AA17 [get_ports {c0_ddr4_dq[29]}]
set_property PACKAGE_PIN Y18 [get_ports {c0_ddr4_dq[30]}]
set_property PACKAGE_PIN AA18 [get_ports {c0_ddr4_dq[31]}]

set_property PACKAGE_PIN P26 [get_ports {c0_ddr4_adr[0]}]
set_property PACKAGE_PIN P25 [get_ports {c0_ddr4_adr[1]}]
set_property PACKAGE_PIN R22 [get_ports {c0_ddr4_adr[2]}]
set_property PACKAGE_PIN AA24 [get_ports {c0_ddr4_adr[3]}]
set_property PACKAGE_PIN T23 [get_ports {c0_ddr4_adr[4]}]
set_property PACKAGE_PIN W20 [get_ports {c0_ddr4_adr[5]}]
set_property PACKAGE_PIN T22 [get_ports {c0_ddr4_adr[6]}]
set_property PACKAGE_PIN W19 [get_ports {c0_ddr4_adr[7]}]
set_property PACKAGE_PIN U21 [get_ports {c0_ddr4_adr[8]}]
set_property PACKAGE_PIN P21 [get_ports {c0_ddr4_adr[9]}]
set_property PACKAGE_PIN V22 [get_ports {c0_ddr4_adr[10]}]
set_property PACKAGE_PIN U19 [get_ports {c0_ddr4_adr[11]}]
set_property PACKAGE_PIN Y25 [get_ports {c0_ddr4_adr[12]}]
set_property PACKAGE_PIN P20 [get_ports {c0_ddr4_adr[13]}]
set_property PACKAGE_PIN Y23 [get_ports {c0_ddr4_adr[14]}]
#DDR4_WE_B
set_property PACKAGE_PIN U26 [get_ports {c0_ddr4_adr[15]}]
#DDR4_CAS_B
set_property PACKAGE_PIN V26 [get_ports {c0_ddr4_adr[16]}]
#DDR4_RAS_B
set_property PACKAGE_PIN AC26 [get_ports {c0_ddr4_dqs_t[0]}]
set_property PACKAGE_PIN AA22 [get_ports {c0_ddr4_dqs_t[1]}]
set_property PACKAGE_PIN AC18 [get_ports {c0_ddr4_dqs_t[2]}]
set_property PACKAGE_PIN AB17 [get_ports {c0_ddr4_dqs_t[3]}]

set_property PACKAGE_PIN U22 [get_ports {c0_ddr4_ba[0]}]
set_property PACKAGE_PIN R26 [get_ports {c0_ddr4_ba[1]}]

set_property PACKAGE_PIN AE25 [get_ports {c0_ddr4_dm_n[0]}]
set_property PACKAGE_PIN AE22 [get_ports {c0_ddr4_dm_n[1]}]
set_property PACKAGE_PIN AD20 [get_ports {c0_ddr4_dm_n[2]}]
set_property PACKAGE_PIN Y20 [get_ports {c0_ddr4_dm_n[3]}]

set_property PACKAGE_PIN V21 [get_ports {c0_ddr4_bg[0]}]

set_property PACKAGE_PIN P23 [get_ports c0_ddr4_reset_n]
set_property PACKAGE_PIN V19 [get_ports c0_ddr4_act_n]
set_property PACKAGE_PIN AA25 [get_ports {c0_ddr4_odt[0]}]


##DDR4_ODT

set_property PACKAGE_PIN W25 [get_ports {c0_ddr4_ck_t[0]}]

set_property PACKAGE_PIN Y22 [get_ports {c0_ddr4_cke[0]}]
set_property PACKAGE_PIN Y26 [get_ports {c0_ddr4_cs_n[0]}]

# ------------------------------------------------------------------------------
# 2. GMII Receive Interface (PHY -> FPGA, Bank 87, LVCMOS33)
# ------------------------------------------------------------------------------
# ETHPL_RXCLK -> IO_L8P_HDGC_87_D14 (HDGC Global Clock P-Pin)
create_clock -period 8.000 -name gmii_rx_clk [get_ports gmii_rx_clk]
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
# Note: In current block design, mii_tx_clk is tied internally to constant 0
# set_property PACKAGE_PIN C13      [get_ports mii_tx_clk]
# set_property IOSTANDARD  LVCMOS33 [get_ports mii_tx_clk]
# set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_ports mii_tx_clk]]
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
set_property PACKAGE_PIN D13      [get_ports phy_reset_n]
set_property IOSTANDARD  LVCMOS33 [get_ports phy_reset_n]
set_property SLEW        SLOW     [get_ports phy_reset_n]
