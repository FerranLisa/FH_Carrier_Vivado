set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
open_project [file join $root FH_Carrier_Bringup.xpr]
set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
update_ip_catalog
open_bd_design [get_files */bd/design_1/design_1.bd]
if {[llength [get_bd_cells -quiet gmax_capture]]} {error "Capture already integrated"}
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces zynq_ultra_ps_e_0/Data]] {
 set off [get_property OFFSET $seg];set range [get_property RANGE $seg]
 if {$off<0xA0060000 && $off+$range>0xA0040000} {error "Capture address overlap"}
}
create_bd_cell -type ip -vlnv fh.local:user:gmax3412_capture:1.0 gmax_capture
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 gmax_capture_ctrl
set_property -dict [list CONFIG.C_IS_DUAL 1 CONFIG.C_GPIO_WIDTH 32 CONFIG.C_GPIO2_WIDTH 32 CONFIG.C_ALL_OUTPUTS 1 CONFIG.C_ALL_INPUTS_2 1] [get_bd_cells gmax_capture_ctrl]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 gmax_capture_dma
set_property -dict [list CONFIG.c_include_sg 0 CONFIG.c_include_mm2s 0 CONFIG.c_include_s2mm 1 CONFIG.c_sg_length_width 26 CONFIG.c_m_axi_s2mm_data_width 128 CONFIG.c_s_axis_s2mm_tdata_width 128 CONFIG.c_s2mm_burst_size 64 CONFIG.c_addr_width 32] [get_bd_cells gmax_capture_dma]
set_property CONFIG.NUM_MI 6 [get_bd_cells axi_smc]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M04_AXI] [get_bd_intf_pins gmax_capture_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M05_AXI] [get_bd_intf_pins gmax_capture_dma/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins gmax_capture/m_axis] [get_bd_intf_pins gmax_capture_dma/S_AXIS_S2MM]
connect_bd_net [get_bd_pins gmax_capture_ctrl/gpio_io_o] [get_bd_pins gmax_capture/control]
connect_bd_net [get_bd_pins gmax_capture/status] [get_bd_pins gmax_capture_ctrl/gpio2_io_i]
foreach {src dst} {clk_rxg emu_clk fvalout emu_fval lvalout emu_lval dataout emu_data} {
 connect_bd_net [get_bd_pins gmax3412_emulator_0/$src] [get_bd_pins gmax_capture/$dst]
}
foreach {name width type} {rx_clk 1 clk rx_fval 1 data rx_lval 1 data rx_data 192 data} {
 if {$width==1} {set port [create_bd_port -dir I -type $type capture_$name]} else {set port [create_bd_port -dir I -from 191 -to 0 capture_$name]}
 if {$type eq "clk"} {set_property CONFIG.FREQ_HZ 120000000 $port}
 connect_bd_net $port [get_bd_pins gmax_capture/$name]
}
set_property -dict [list CONFIG.PSU__USE__S_AXI_GP2 1 CONFIG.PSU__SAXIGP2__DATA_WIDTH 128] [get_bd_cells zynq_ultra_ps_e_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 gmax_ddr_smc
set_property -dict [list CONFIG.NUM_SI 1 CONFIG.NUM_MI 1] [get_bd_cells gmax_ddr_smc]
connect_bd_intf_net [get_bd_intf_pins gmax_capture_dma/M_AXI_S2MM] [get_bd_intf_pins gmax_ddr_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins gmax_ddr_smc/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
foreach pin {gmax_capture/clk gmax_capture_ctrl/s_axi_aclk gmax_capture_dma/s_axi_lite_aclk gmax_capture_dma/m_axi_s2mm_aclk gmax_ddr_smc/aclk zynq_ultra_ps_e_0/saxihp0_fpd_aclk} {
 connect_bd_net [get_bd_pins gmax_emu_clock/clk_out1] [get_bd_pins $pin]
}
foreach pin {gmax_capture/resetn gmax_capture_ctrl/s_axi_aresetn gmax_capture_dma/axi_resetn gmax_ddr_smc/aresetn} {
 connect_bd_net [get_bd_pins gmax_emu_reset/peripheral_aresetn] [get_bd_pins $pin]
}
assign_bd_address -offset 0xA0040000 -range 64K -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs gmax_capture_ctrl/S_AXI/*]
assign_bd_address -offset 0xA0050000 -range 64K -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs gmax_capture_dma/S_AXI_LITE/*]
assign_bd_address
validate_bd_design
save_bd_design
generate_target all [get_files */bd/design_1/design_1.bd]
make_wrapper -files [get_files */bd/design_1/design_1.bd] -top
update_compile_order -fileset sources_1
puts "CAPTURE_INTEGRATION_PASS"
close_project
