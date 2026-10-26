# FH_Carrier / FH_Sen4K GMAX3412 V16 receiver-diagnostic update
# Vivado 2025.2
#
# The source archive already contains the edited BD/XCI metadata, but run this
# script after opening FH_Carrier_Bringup.xpr to force the AXI GPIO widths,
# validate the block design and regenerate its output products/wrapper.

set proj [current_project]
if {$proj eq ""} {
    error "Open FH_Carrier_Bringup.xpr before sourcing this script."
}

set bd_file [get_files -quiet */design_1.bd]
if {[llength $bd_file] == 0} {
    error "design_1.bd not found in the current project."
}

open_bd_design $bd_file

set gpio_cell [get_bd_cells -quiet axi_gpio_gmax_a_ctrl]
if {[llength $gpio_cell] == 0} {
    error "axi_gpio_gmax_a_ctrl not found in design_1."
}

puts "Applying V16 AXI GPIO widths: CH1=15 outputs, CH2=32 inputs"
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH  {15} \
    CONFIG.C_GPIO2_WIDTH {32} \
    CONFIG.C_IS_DUAL     {1}  \
    CONFIG.C_ALL_OUTPUTS {1}  \
    CONFIG.C_ALL_INPUTS_2 {1} \
] $gpio_cell

validate_bd_design
save_bd_design

generate_target all $bd_file
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "V16 block-design update complete."
puts "Next: run synthesis/implementation, generate bitstream, then Export Hardware (include bitstream) to create a NEW V16 XSA."
puts "Do not reuse the XSA that came from the pre-V16 archive."
