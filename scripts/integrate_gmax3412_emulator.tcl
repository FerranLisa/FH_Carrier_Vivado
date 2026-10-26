set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
if {[current_project -quiet] eq ""} { open_project [file join $root FH_Carrier_Bringup.xpr] }
set repo [file join $root ip]
set_property ip_repo_paths [lsort -unique [concat [get_property ip_repo_paths [current_project]] $repo]] [current_project]
update_ip_catalog
open_bd_design [get_files */bd/design_1/design_1.bd]
if {[llength [get_bd_cells -quiet gmax3412_emulator_0]]} { error "Emulator already integrated; refusing to duplicate it" }
# Verify the proposed address is free before editing the design.
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces zynq_ultra_ps_e_0/Data]] {
    set off [get_property OFFSET $seg]
    set range [get_property RANGE $seg]
    if {$off < 0xA0040000 && ($off + $range) > 0xA0030000} { error "0xA0030000 overlaps $seg" }
}
create_bd_cell -type ip -vlnv fh.local:user:gmax3412_emulator:1.0 gmax3412_emulator_0
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 gmax_emu_clock
set_property -dict [list CONFIG.PRIM_SOURCE {No_buffer} CONFIG.PRIM_IN_FREQ {100.000} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {120.000} CONFIG.RESET_TYPE {ACTIVE_LOW}] [get_bd_cells gmax_emu_clock]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 gmax_emu_reset
# External polarity propagates from PS pl_resetn0. Auxiliary reset is tied low.
set_property CONFIG.C_AUX_RESET_HIGH 1 [get_bd_cells gmax_emu_reset]
set smc [get_bd_cells axi_smc]
set n [get_property CONFIG.NUM_MI $smc]
set_property CONFIG.NUM_MI [expr {$n+1}] $smc
# SmartConnect implements the AXI CDC itself when both clocks are supplied.
set_property CONFIG.NUM_CLKS 2 $smc
connect_bd_intf_net [get_bd_intf_pins axi_smc/M[format %02d $n]_AXI] [get_bd_intf_pins gmax3412_emulator_0/s_axi]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins gmax_emu_clock/clk_in1]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins gmax_emu_clock/resetn]
connect_bd_net [get_bd_pins gmax_emu_clock/clk_out1] [get_bd_pins gmax_emu_reset/slowest_sync_clk] [get_bd_pins axi_smc/aclk1] [get_bd_pins gmax3412_emulator_0/s_axi_aclk]
connect_bd_net [get_bd_pins gmax_emu_clock/locked] [get_bd_pins gmax_emu_reset/dcm_locked]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins gmax_emu_reset/ext_reset_in]
connect_bd_net [get_bd_pins gmax_emu_reset/peripheral_aresetn] [get_bd_pins gmax3412_emulator_0/s_axi_aresetn]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 gmax_emu_zero
set_property CONFIG.CONST_VAL 0 [get_bd_cells gmax_emu_zero]
foreach pin {init_in acquisition_start acquisition_stop trigger_in} {
    connect_bd_net [get_bd_pins gmax_emu_zero/dout] [get_bd_pins gmax3412_emulator_0/$pin]
}
connect_bd_net [get_bd_pins gmax_emu_zero/dout] [get_bd_pins gmax_emu_reset/aux_reset_in] [get_bd_pins gmax_emu_reset/mb_debug_sys_rst]
assign_bd_address -offset 0xA0030000 -range 64K -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs gmax3412_emulator_0/s_axi/*]
validate_bd_design
save_bd_design
generate_target all [get_files */bd/design_1/design_1.bd]
update_compile_order -fileset sources_1
puts "GMAX3412 emulator/checker integrated at 0xA0030000."
