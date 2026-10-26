set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
open_project [file join $root FH_Carrier_Bringup.xpr]
set repos [get_property ip_repo_paths [current_project]]
lappend repos [file join $root ip gmax3412_scheduler]
set_property ip_repo_paths [lsort -unique $repos] [current_project]
update_ip_catalog
open_bd_design [get_files */bd/design_1/design_1.bd]
if {[llength [get_bd_cells -quiet gmax_scheduler]]} {error "Scheduler already integrated"}
create_bd_cell -type ip -vlnv fh.local:user:gmax3412_scheduler:1.0 gmax_scheduler
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 gmax_scheduler_ctrl
set_property -dict [list CONFIG.C_IS_DUAL 1 CONFIG.C_GPIO_WIDTH 32 CONFIG.C_GPIO2_WIDTH 32 CONFIG.C_ALL_OUTPUTS 1 CONFIG.C_ALL_INPUTS_2 1] [get_bd_cells gmax_scheduler_ctrl]
set_property -dict [list CONFIG.NUM_MI 7 CONFIG.NUM_SI 2] [get_bd_cells axi_smc]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M06_AXI] [get_bd_intf_pins gmax_scheduler_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/S01_AXI] [get_bd_intf_pins gmax_scheduler/m_axi]
connect_bd_net [get_bd_pins gmax_scheduler_ctrl/gpio_io_o] [get_bd_pins gmax_scheduler/control]
connect_bd_net [get_bd_pins gmax_scheduler/status] [get_bd_pins gmax_scheduler_ctrl/gpio2_io_i]
foreach pin {gmax_scheduler/clk gmax_scheduler_ctrl/s_axi_aclk} {
 connect_bd_net [get_bd_pins gmax_emu_clock/clk_out1] [get_bd_pins $pin]
}
foreach pin {gmax_scheduler/resetn gmax_scheduler_ctrl/s_axi_aresetn} {
 connect_bd_net [get_bd_pins gmax_emu_reset/peripheral_aresetn] [get_bd_pins $pin]
}
set_property CONFIG.c_addr_width 64 [get_bd_cells gmax_capture_dma]
assign_bd_address -offset 0xA0060000 -range 64K -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs gmax_scheduler_ctrl/S_AXI/*]
# Assign the new control master the same peripheral addresses as the PS.
foreach {cell offset iface} {gmax3412_emulator_0 0xA0030000 s_axi gmax_capture_ctrl 0xA0040000 S_AXI gmax_capture_dma 0xA0050000 S_AXI_LITE} {
 assign_bd_address -offset $offset -range 64K -target_address_space [get_bd_addr_spaces gmax_scheduler/m_axi] [get_bd_addr_segs $cell/$iface/*]
}
assign_bd_address
include_bd_addr_seg [get_bd_addr_segs -excluded gmax_capture_dma/Data_S2MM/SEG_zynq_ultra_ps_e_0_HP0_DDR_HIGH]
assign_bd_address -force -offset 0x800000000 -range 2G -target_address_space [get_bd_addr_spaces gmax_capture_dma/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH]
validate_bd_design
save_bd_design
puts "SCHEDULER_INTEGRATION_PASS"
close_project
