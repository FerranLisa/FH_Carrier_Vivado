set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
create_project -in_memory -part xczu7ev-ffvc1156-2-i
create_bd_design probe
create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 pl_ddr4
set_property -dict [list CONFIG.C0.DDR4_MemoryPart MT40A512M16LY-075 CONFIG.C0.DDR4_DataWidth 64 CONFIG.C0.DDR4_TimePeriod 833 CONFIG.C0.DDR4_InputClockPeriod 4998 CONFIG.C0.DDR4_AxiSelection true CONFIG.C0.DDR4_AxiDataWidth 512 CONFIG.C0.DDR4_AxiAddressWidth 32 CONFIG.C0.DDR4_AxiNarrowBurst true] [get_bd_cells pl_ddr4]
report_property [get_bd_cells pl_ddr4]
puts "PINS: [get_bd_pins pl_ddr4/*]"
puts "INTFS: [get_bd_intf_pins pl_ddr4/*]"
close_project
open_project [file join $root FH_Carrier_Bringup.xpr]
open_bd_design [get_files */bd/design_1/design_1.bd]
puts "PS ADDRESS: [get_property APERTURES [get_bd_addr_spaces zynq_ultra_ps_e_0/Data]]"
puts "PS MASTER: [get_bd_intf_pins -filter {MODE == Master} zynq_ultra_ps_e_0/*]"
close_project
