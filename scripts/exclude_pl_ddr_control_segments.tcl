# Run with design_1 open. These AXI-Lite masters control the DMA; they never
# access DDR or unrelated board peripherals. Exclude otherwise unmapped paths.
foreach {master slaves} {
 gmax_scheduler {pl_ddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK gmax_pl_ring_ctrl/S_AXI/Reg}
 gmax_pl_ring {axi_iic_gmax_a/S_AXI/Reg axi_gpio_clkmon/S_AXI/Reg axi_gpio_gmax_a_ctrl/S_AXI/Reg gmax_scheduler_ctrl/S_AXI/Reg pl_ddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK gmax_pl_ring_ctrl/S_AXI/Reg}
} {
 foreach slave $slaves {
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces $master/m_axi] [get_bd_addr_segs $slave]
 }
}
