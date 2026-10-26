set root [file dirname [file normalize [info script]]]
cd $root
open_project FH_Carrier_Bringup.xpr
open_run synth_1
set h [open [file join $root rx_debug_inventory.txt] w]
puts $h "CORES: [get_debug_cores -quiet]"
foreach core [get_debug_cores -quiet] {puts $h "CORE $core: [list_property $core]"}
foreach name {u_gmax_a_rx/u_training u_gmax_a_rx/u_training/loopi[0].u_iserdes u_gmax_a_rx/u_training/loopi[1].u_iserdes u_gmax_a_rx/u_training/loopi[0].u_iserdes/u_fifo u_gmax_a_rx/u_training/loopi[1].u_iserdes/u_fifo} {
    set c [get_cells -quiet -hier -filter "NAME == \"$name\""]
    puts $h "CELL: $name FOUND: [llength $c]"
    foreach p [lsort [get_pins -quiet -of_objects $c]] {
        puts $h "PIN $p: [get_nets -quiet -of_objects $p]"
    }
}
puts $h "PS CLOCKS: [get_nets -quiet -hier -filter {NAME =~ *pl_clk0*}]"
foreach stem {iserdese3_dout data_shift data_12b cnt_bitslip cnt_data_val reg_bit_width_qq wr_bin rd_bin full_r raw_activity} {
    puts $h "CELLS $stem: [get_cells -quiet -hier -filter \"NAME =~ *loopi?0?.u_iserdes/*${stem}* || NAME =~ *loopi?1?.u_iserdes/*${stem}*\"]"
}
close $h
puts "WROTE $root/rx_debug_inventory.txt"
close_project
