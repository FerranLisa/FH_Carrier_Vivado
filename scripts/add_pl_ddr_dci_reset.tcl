# Source with the project and block design open. Safe to run again.
set dci_source [file join $root FH_Carrier_Bringup.srcs sources_1 new pl_ddr_dci_reset.v]
if {![llength [get_files -quiet $dci_source]]} {add_files $dci_source}
update_compile_order -fileset sources_1
if {![llength [get_bd_cells -quiet pl_ddr_dci_reset]]} {
    create_bd_cell -type module -reference pl_ddr_dci_reset pl_ddr_dci_reset
    disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins pl_ddr4/sys_rst]] [get_bd_pins pl_ddr4/sys_rst]
    connect_bd_net [get_bd_pins gmax_emu_clock/clk_out1] [get_bd_pins pl_ddr_dci_reset/clk]
    connect_bd_net [get_bd_pins gmax_emu_reset/peripheral_aresetn] [get_bd_pins pl_ddr_dci_reset/resetn]
    connect_bd_net [get_bd_pins pl_ddr_dci_reset/sys_rst] [get_bd_pins pl_ddr4/sys_rst]
}
