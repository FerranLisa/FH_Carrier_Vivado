set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
open_project [file join $root FH_Carrier_Bringup.xpr]
reset_run synth_1
foreach run [get_runs *_synth_1] {
    if {[regexp {Running|Queued} [get_property STATUS $run]]} {reset_run $run}
}
update_ip_catalog
open_bd_design [get_files */bd/design_1/design_1.bd]
upgrade_bd_cells [get_bd_cells gmax3412_emulator_0]
set_property CONFIG.C_AUX_RESET_HIGH 1 [get_bd_cells gmax_emu_reset]
set_property CONFIG.PRIM_SOURCE No_buffer [get_bd_cells gmax_emu_clock]
if {[llength [get_bd_cells -quiet gmax_emu_axi_cdc]]} {
    delete_bd_objs [get_bd_intf_nets -of_objects [get_bd_intf_pins gmax_emu_axi_cdc/S_AXI]]
    delete_bd_objs [get_bd_intf_nets -of_objects [get_bd_intf_pins gmax_emu_axi_cdc/M_AXI]]
    delete_bd_objs [get_bd_cells gmax_emu_axi_cdc]
    set_property CONFIG.NUM_CLKS 2 [get_bd_cells axi_smc]
    connect_bd_net [get_bd_pins gmax_emu_clock/clk_out1] [get_bd_pins axi_smc/aclk1]
    connect_bd_intf_net [get_bd_intf_pins axi_smc/M03_AXI] [get_bd_intf_pins gmax3412_emulator_0/s_axi]
}
validate_bd_design
if {[get_property CONFIG.C_AUX_RESET_HIGH [get_bd_cells gmax_emu_reset]] != 1} {error "Auxiliary reset polarity incorrect"}
if {[get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells gmax_emu_reset]] != 0} {error "External reset polarity incorrect"}
if {[get_property CONFIG.PROTOCOL [get_bd_intf_pins gmax3412_emulator_0/s_axi]] ne "AXI4LITE"} {error "Incorrect AXI protocol"}
save_bd_design
generate_target all [get_files */bd/design_1/design_1.bd]
close_project
