set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
open_project [file join $root FH_Carrier_Bringup.xpr]
open_bd_design [get_files */bd/design_1/design_1.bd]
include_bd_addr_seg [get_bd_addr_segs -excluded gmax_capture_dma/Data_S2MM/SEG_zynq_ultra_ps_e_0_HP0_DDR_HIGH]
assign_bd_address -force -offset 0x800000000 -range 2G -target_address_space [get_bd_addr_spaces gmax_capture_dma/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH]
validate_bd_design
save_bd_design
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces gmax_capture_dma/Data_S2MM]] {puts "DMA_MAP $seg [get_property OFFSET $seg] [get_property RANGE $seg]"}
if {[llength [get_bd_addr_segs gmax_capture_dma/Data_S2MM/SEG_zynq_ultra_ps_e_0_HP0_DDR_HIGH]]!=1} {error "High DDR mapping absent"}
close_project
