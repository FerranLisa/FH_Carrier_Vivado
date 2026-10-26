# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "POLL_LIMIT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "RESET_WAIT" -parent ${Page_0}


}

proc update_PARAM_VALUE.POLL_LIMIT { PARAM_VALUE.POLL_LIMIT } {
	# Procedure called to update POLL_LIMIT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.POLL_LIMIT { PARAM_VALUE.POLL_LIMIT } {
	# Procedure called to validate POLL_LIMIT
	return true
}

proc update_PARAM_VALUE.RESET_WAIT { PARAM_VALUE.RESET_WAIT } {
	# Procedure called to update RESET_WAIT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RESET_WAIT { PARAM_VALUE.RESET_WAIT } {
	# Procedure called to validate RESET_WAIT
	return true
}


proc update_MODELPARAM_VALUE.RESET_WAIT { MODELPARAM_VALUE.RESET_WAIT PARAM_VALUE.RESET_WAIT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RESET_WAIT}] ${MODELPARAM_VALUE.RESET_WAIT}
}

proc update_MODELPARAM_VALUE.POLL_LIMIT { MODELPARAM_VALUE.POLL_LIMIT PARAM_VALUE.POLL_LIMIT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.POLL_LIMIT}] ${MODELPARAM_VALUE.POLL_LIMIT}
}

