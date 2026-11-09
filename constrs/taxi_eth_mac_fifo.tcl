# SPDX-License-Identifier: CERN-OHL-S-2.0
#
# Copyright (c) 2019-2025 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# Ethernet MAC with FIFO timing constraints

foreach inst [get_cells -hier -regexp -filter {(ORIG_REF_NAME =~ "taxi_eth_mac_(10g|1g)_((gmii|rgmii|mii)_)?fifo(__\w+__\d+)?" ||
        REF_NAME =~ "taxi_eth_mac_(10g|1g)_((gmii|rgmii|mii)_)?fifo(__\w+__\d+)?")}] {
    puts "Inserting timing constraints for Ethernet MAC with FIFO instance $inst"

    set sync_ffs [get_cells -quiet -hier -regexp ".*/rx_sync_reg_\[1234\]_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]

    if {[llength $sync_ffs]} {
        set_property ASYNC_REG TRUE $sync_ffs

        set from_cells [get_cells -quiet $inst/rx_sync_reg_1_reg[*]]
        set to_cells   [get_cells -quiet $inst/rx_sync_reg_2_reg[*]]

        if {[llength $from_cells] && [llength $to_cells]} {
            set src_clk [get_clocks -quiet -of_objects [get_pins -quiet $inst/rx_sync_reg_1_reg[*]/C]]
            set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 8.0}]

            set_max_delay -from $from_cells -to $to_cells -datapath_only $src_clk_period
        }
    }

    set sync_ffs [get_cells -quiet -hier -regexp ".*/tx_sync_reg_\[1234\]_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]

    if {[llength $sync_ffs]} {
        set_property ASYNC_REG TRUE $sync_ffs

        set from_cells [get_cells -quiet $inst/tx_sync_reg_1_reg[*]]
        set to_cells   [get_cells -quiet $inst/tx_sync_reg_2_reg[*]]

        if {[llength $from_cells] && [llength $to_cells]} {
            set src_clk [get_clocks -quiet -of_objects [get_pins -quiet $inst/tx_sync_reg_1_reg[*]/C]]
            set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 8.0}]

            set_max_delay -from $from_cells -to $to_cells -datapath_only $src_clk_period
        }
    }
}
