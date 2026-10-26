# Fail loudly if synthesis hierarchy changes and constraints lose endpoints.
set first [get_pins -hier -regexp {u_gmax_a_rx/u_training/loopi\[[0-9]+\]\.u_iserdes/(rst_iserdes_q_reg|bitslip_sync_reg\[0\]|idelay_ld_sync_reg\[0\]|idelay_valuein_q_reg\[[0-9]+\]|reg_bit_width_q_reg\[[0-9]+\])/D}]
if {[llength $first] != 224} {error "Expected 224 receiver first-stage pins, found [llength $first]"}
for {set i 0} {$i < 16} {incr i} {
    set idsrc [get_cells -hier -regexp [format {u_gmax_a_rx/u_training/(idelay_valuein_reg\[%d\]\[[0-9]+\]|idelay_ld_reg\[%d\])} $i $i]]
    set iddst [get_cells -hier -regexp [format {u_gmax_a_rx/u_training/loopi\[%d\]\.u_iserdes/(idelay_valuein_q_reg\[[0-9]+\]|idelay_ld_sync_reg\[0\])} $i]]
    if {[llength $idsrc] != 10 || [llength $iddst] != 10} {error "IDELAY bus/load endpoints missing in lane $i"}
    foreach {ptr sync} {wr_gray u_sync_wr_gray_to_rd rd_gray u_sync_rd_gray_to_wr} {
        set prefix [format {u_gmax_a_rx/u_training/loopi\[%d\]\.u_iserdes/u_fifo/} $i]
        set bin [string map {gray bin} $ptr]
        set src [get_cells -hier -regexp [format {%s(%s_reg\[[0-4]\]|%s_reg\[5\])} $prefix $ptr $bin]]
        set dst [get_cells -hier -regexp [format {%s%s/syncstages_ff_reg\[0\]\[[0-9]+\]} $prefix $sync]]
        if {[llength $src] != 6 || [llength $dst] != 6} {error "Gray pointer endpoints missing in lane $i $ptr"}
    }
}
puts "Verified receiver first-stage pins and 32 six-bit Gray pointer crossings."
set pixel [get_clocks -of_objects [get_pins u_gmax_a_rx/u_training/u_gmax3412_iob_clock/BUFGCE_RXG_DIV5_inst/O]]
set clk0family [get_clocks -include_generated_clocks GMX_A_CLK0]
if {[llength $pixel] != 1 || [lsearch -exact $clk0family $pixel] < 0} {error "Pixel clock is missing from the CLK0 family"}
puts "Verified all 16 IDELAY bus/load crossings and the generated pixel-clock family."
