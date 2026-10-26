# Vivado derives polarity during BD propagation. Keep the default active-low
# auxiliary reset and explicitly tie it HIGH (inactive), not to gmax_emu_zero.
set_property CONFIG.C_AUX_RESET_HIGH 0 [get_bd_cells pl_ddr_reset]
if {![llength [get_bd_cells -quiet pl_ddr_reset_inactive]]} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 pl_ddr_reset_inactive
}
set_property -dict [list CONFIG.CONST_WIDTH 1 CONFIG.CONST_VAL 1] [get_bd_cells pl_ddr_reset_inactive]
set aux [get_bd_pins pl_ddr_reset/aux_reset_in]
set oldnet [get_bd_nets -quiet -of_objects $aux]
if {[llength $oldnet]} {disconnect_bd_net $oldnet $aux}
connect_bd_net [get_bd_pins pl_ddr_reset_inactive/dout] $aux
puts "PL_DDR_RESET_FIX: active-low auxiliary input connected to constant one"
