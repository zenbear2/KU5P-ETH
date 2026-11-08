# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  set AXIS_DATA_WIDTH [ipgui::add_param $IPINST -name "AXIS_DATA_WIDTH" -parent ${Page_0}]
  set_property tooltip {AXI4-Stream data width in bits (power of 2, >= 8)} ${AXIS_DATA_WIDTH}
  set FPGA_FAMILY [ipgui::add_param $IPINST -name "FPGA_FAMILY" -parent ${Page_0}]
  set_property tooltip {Target FPGA family primitive mapping (defaults to kintexuplus for KU5P)} ${FPGA_FAMILY}
  set RX_FIFO_DEPTH [ipgui::add_param $IPINST -name "RX_FIFO_DEPTH" -parent ${Page_0}]
  set_property tooltip {Receive Frame FIFO depth in bytes (power of 2)} ${RX_FIFO_DEPTH}
  set SIM [ipgui::add_param $IPINST -name "SIM" -parent ${Page_0}]
  set_property tooltip {Simulation mode flag (1 to avoid hardware primitives in testbench)} ${SIM}
  set TX_FIFO_DEPTH [ipgui::add_param $IPINST -name "TX_FIFO_DEPTH" -parent ${Page_0}]
  set_property tooltip {Transmit Frame FIFO depth in bytes (power of 2)} ${TX_FIFO_DEPTH}


}

proc update_PARAM_VALUE.AXIS_DATA_WIDTH { PARAM_VALUE.AXIS_DATA_WIDTH } {
	# Procedure called to update AXIS_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXIS_DATA_WIDTH { PARAM_VALUE.AXIS_DATA_WIDTH } {
	# Procedure called to validate AXIS_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.FPGA_FAMILY { PARAM_VALUE.FPGA_FAMILY } {
	# Procedure called to update FPGA_FAMILY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FPGA_FAMILY { PARAM_VALUE.FPGA_FAMILY } {
	# Procedure called to validate FPGA_FAMILY
	return true
}

proc update_PARAM_VALUE.RX_FIFO_DEPTH { PARAM_VALUE.RX_FIFO_DEPTH } {
	# Procedure called to update RX_FIFO_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RX_FIFO_DEPTH { PARAM_VALUE.RX_FIFO_DEPTH } {
	# Procedure called to validate RX_FIFO_DEPTH
	return true
}

proc update_PARAM_VALUE.SIM { PARAM_VALUE.SIM } {
	# Procedure called to update SIM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SIM { PARAM_VALUE.SIM } {
	# Procedure called to validate SIM
	return true
}

proc update_PARAM_VALUE.TX_FIFO_DEPTH { PARAM_VALUE.TX_FIFO_DEPTH } {
	# Procedure called to update TX_FIFO_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TX_FIFO_DEPTH { PARAM_VALUE.TX_FIFO_DEPTH } {
	# Procedure called to validate TX_FIFO_DEPTH
	return true
}


proc update_MODELPARAM_VALUE.SIM { MODELPARAM_VALUE.SIM PARAM_VALUE.SIM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SIM}] ${MODELPARAM_VALUE.SIM}
}

proc update_MODELPARAM_VALUE.FPGA_FAMILY { MODELPARAM_VALUE.FPGA_FAMILY PARAM_VALUE.FPGA_FAMILY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FPGA_FAMILY}] ${MODELPARAM_VALUE.FPGA_FAMILY}
}

proc update_MODELPARAM_VALUE.AXIS_DATA_WIDTH { MODELPARAM_VALUE.AXIS_DATA_WIDTH PARAM_VALUE.AXIS_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXIS_DATA_WIDTH}] ${MODELPARAM_VALUE.AXIS_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.TX_FIFO_DEPTH { MODELPARAM_VALUE.TX_FIFO_DEPTH PARAM_VALUE.TX_FIFO_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TX_FIFO_DEPTH}] ${MODELPARAM_VALUE.TX_FIFO_DEPTH}
}

proc update_MODELPARAM_VALUE.RX_FIFO_DEPTH { MODELPARAM_VALUE.RX_FIFO_DEPTH PARAM_VALUE.RX_FIFO_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RX_FIFO_DEPTH}] ${MODELPARAM_VALUE.RX_FIFO_DEPTH}
}

