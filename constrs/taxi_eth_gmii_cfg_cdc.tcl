# SPDX-License-Identifier: CERN-OHL-S-2.0
# Source after synthesis and clock creation. Broad asynchronous clock
# groups must not override the bundled-data maximum delay constraints.
foreach inst [get_cells -hier -filter {REF_NAME =~ taxi_eth_gmii_cfg_cdc* || ORIG_REF_NAME =~ taxi_eth_gmii_cfg_cdc*}] {
    set payload [get_cells -quiet -hier -filter "PARENT == $inst && NAME =~ */payload_reg*"]
    set request [get_cells -quiet -hier -filter "PARENT == $inst && NAME =~ */request_reg*"]
    if {![llength $payload] || ![llength $request]} {
        error "Missing configuration CDC source registers in $inst"
    }
    foreach domain {tx rx} {
        set capture [get_cells -quiet -hier -filter "PARENT == $inst && NAME =~ */${domain}_config_reg*"]
        set req_sync [get_cells -quiet -hier -filter "PARENT == $inst && NAME =~ */${domain}_req_sync_reg*"]
        set ack [get_cells -quiet -hier -filter "PARENT == $inst && NAME =~ */${domain}_ack_reg"]
        set ack_sync [get_cells -quiet -hier -filter "PARENT == $inst && NAME =~ */${domain}_ack_sync_reg*"]
        if {![llength $capture] || ![llength $req_sync] || ![llength $ack_sync]} {
            error "Missing configuration CDC registers in $inst ($domain)"
        }
        set dst_clocks [get_clocks -of_objects [get_pins -of_objects $req_sync -filter {REF_PIN_NAME == C}]]
        set src_clocks [get_clocks -of_objects [get_pins -of_objects $ack_sync -filter {REF_PIN_NAME == C}]]
        if {![llength $dst_clocks] || ![llength $src_clocks]} {
            error "Define source and destination clocks before applying configuration CDC constraints"
        }
        set dst_period [get_property -min PERIOD $dst_clocks]
        set src_period [get_property -min PERIOD $src_clocks]
        set_property ASYNC_REG TRUE $req_sync
        set_property ASYNC_REG TRUE $ack_sync
        set_max_delay -datapath_only $dst_period -from $payload -to $capture
        set_bus_skew $dst_period -from $payload -to $capture
        set_max_delay -datapath_only $dst_period -from $request -to $req_sync
        set_max_delay -datapath_only $src_period -from $ack -to $ack_sync
    }
}
