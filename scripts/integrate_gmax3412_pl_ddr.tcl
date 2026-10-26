set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
open_project [file join $root FH_Carrier_Bringup.xpr]
set repos [get_property ip_repo_paths [current_project]]
lappend repos [file join $root ip gmax3412_pl_ring]
set_property ip_repo_paths [lsort -unique $repos] [current_project]
update_ip_catalog
open_bd_design [get_files */bd/design_1/design_1.bd]
if {[llength [get_bd_cells -quiet pl_ddr4]]} {error "PL DDR already integrated"}
create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 pl_ddr4
set_property -dict [list CONFIG.C0.DDR4_MemoryPart MT40A512M16LY-075 CONFIG.C0.DDR4_DataWidth 64 CONFIG.C0.DDR4_DataMask DM_NO_DBI CONFIG.C0.DDR4_TimePeriod 833 CONFIG.C0.DDR4_InputClockPeriod 4998 CONFIG.C0.DDR4_CasLatency 17 CONFIG.C0.DDR4_CasWriteLatency 12 CONFIG.C0.DDR4_AxiSelection true CONFIG.C0.DDR4_AxiDataWidth 512 CONFIG.C0.DDR4_AxiAddressWidth 32 CONFIG.C0.DDR4_AxiNarrowBurst true] [get_bd_cells pl_ddr4]
make_bd_intf_pins_external [get_bd_intf_pins pl_ddr4/C0_DDR4]
set p [get_bd_intf_ports C0_DDR4_0]
set_property name c0_ddr4 $p
make_bd_intf_pins_external [get_bd_intf_pins pl_ddr4/C0_SYS_CLK]
set p [get_bd_intf_ports C0_SYS_CLK_0]
set_property name c0_sys_clk $p
set_property CONFIG.FREQ_HZ 200080032 $p
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_reset] [get_bd_pins pl_ddr4/sys_rst]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 pl_ddr_reset
connect_bd_net [get_bd_pins pl_ddr4/c0_ddr4_ui_clk] [get_bd_pins pl_ddr_reset/slowest_sync_clk]
connect_bd_net [get_bd_pins pl_ddr4/c0_ddr4_ui_clk_sync_rst] [get_bd_pins pl_ddr_reset/ext_reset_in]
connect_bd_net [get_bd_pins pl_ddr4/c0_init_calib_complete] [get_bd_pins pl_ddr_reset/dcm_locked]
connect_bd_net [get_bd_pins gmax_emu_zero/dout] [get_bd_pins pl_ddr_reset/aux_reset_in] [get_bd_pins pl_ddr_reset/mb_debug_sys_rst]
connect_bd_net [get_bd_pins pl_ddr_reset/peripheral_aresetn] [get_bd_pins pl_ddr4/c0_ddr4_aresetn]
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 pl_ddr_smc
set_property -dict [list CONFIG.NUM_SI 2 CONFIG.NUM_MI 1 CONFIG.NUM_CLKS 2] [get_bd_cells pl_ddr_smc]
connect_bd_net [get_bd_pins gmax_emu_clock/clk_out1] [get_bd_pins pl_ddr_smc/aclk]
connect_bd_net [get_bd_pins pl_ddr4/c0_ddr4_ui_clk] [get_bd_pins pl_ddr_smc/aclk1]
connect_bd_net [get_bd_pins gmax_emu_reset/peripheral_aresetn] [get_bd_pins pl_ddr_smc/aresetn]
connect_bd_intf_net [get_bd_intf_pins pl_ddr_smc/M00_AXI] [get_bd_intf_pins pl_ddr4/C0_DDR4_S_AXI]
set_property CONFIG.NUM_MI 2 [get_bd_cells gmax_ddr_smc]
connect_bd_intf_net [get_bd_intf_pins gmax_ddr_smc/M01_AXI] [get_bd_intf_pins pl_ddr_smc/S00_AXI]
set_property -dict [list CONFIG.NUM_MI 9 CONFIG.NUM_SI 3] [get_bd_cells axi_smc]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M08_AXI] [get_bd_intf_pins pl_ddr_smc/S01_AXI]
create_bd_cell -type ip -vlnv fh.local:user:gmax3412_pl_ring:1.0 gmax_pl_ring
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 gmax_pl_ring_ctrl
set_property -dict [list CONFIG.C_IS_DUAL 1 CONFIG.C_GPIO_WIDTH 32 CONFIG.C_GPIO2_WIDTH 32 CONFIG.C_ALL_OUTPUTS 1 CONFIG.C_ALL_INPUTS_2 1] [get_bd_cells gmax_pl_ring_ctrl]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M07_AXI] [get_bd_intf_pins gmax_pl_ring_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/S02_AXI] [get_bd_intf_pins gmax_pl_ring/m_axi]
connect_bd_net [get_bd_pins gmax_pl_ring_ctrl/gpio_io_o] [get_bd_pins gmax_pl_ring/control]
connect_bd_net [get_bd_pins gmax_pl_ring/status] [get_bd_pins gmax_pl_ring_ctrl/gpio2_io_i]
connect_bd_net [get_bd_pins pl_ddr4/c0_init_calib_complete] [get_bd_pins gmax_pl_ring/calib_ready]
foreach pin {gmax_pl_ring/clk gmax_pl_ring_ctrl/s_axi_aclk} {connect_bd_net [get_bd_pins gmax_emu_clock/clk_out1] [get_bd_pins $pin]}
foreach pin {gmax_pl_ring/resetn gmax_pl_ring_ctrl/s_axi_aresetn} {connect_bd_net [get_bd_pins gmax_emu_reset/peripheral_aresetn] [get_bd_pins $pin]}
assign_bd_address -offset 0xA0070000 -range 64K -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs gmax_pl_ring_ctrl/S_AXI/*]
foreach {cell offset iface} {gmax3412_emulator_0 0xA0030000 s_axi gmax_capture_ctrl 0xA0040000 S_AXI gmax_capture_dma 0xA0050000 S_AXI_LITE} {
 assign_bd_address -offset $offset -range 64K -target_address_space [get_bd_addr_spaces gmax_pl_ring/m_axi] [get_bd_addr_segs $cell/$iface/*]
}
foreach space {zynq_ultra_ps_e_0/Data gmax_capture_dma/Data_S2MM} {
 assign_bd_address -offset 0x1000000000 -range 4G -target_address_space [get_bd_addr_spaces $space] [get_bd_addr_segs pl_ddr4/C0_DDR4_MEMORY_MAP/*]
}
source [file join $root scripts exclude_pl_ddr_control_segments.tcl]
source [file join $root scripts add_pl_ddr_dci_reset.tcl]
source [file join $root scripts fix_pl_ddr_reset_polarity.tcl]
validate_bd_design
save_bd_design
add_files -fileset constrs_1 [file join $root FH_Carrier_Bringup.srcs constrs_1 new pl_ddr4.xdc]
generate_target all [get_files */bd/design_1/design_1.bd]
puts "PL_DDR_INTEGRATION_PASS"
close_project
