# Implementation INIT_DESIGN post-hook. Adds only passive debug loads.
# Functional RTL, block design, pinout and receiver constraints remain V16.3.
set rxila_root [file dirname [file normalize [info script]]]
file mkdir [file join $rxila_root debug]
set rxila_map [open [file join $rxila_root debug probe_map.tsv] w]
puts $rxila_map "core\tprobe\tlabel\twidth\tbit_order_LSB_first"

proc rxila_pin_net {name} {
    set p [get_pins -quiet -hier -filter "NAME == \"$name\""]
    if {[llength $p] != 1} {error "Receiver ILA: expected one pin $name, found [llength $p]"}
    set n [get_nets -quiet -of_objects $p]
    if {[llength $n] != 1} {error "Receiver ILA: pin $name has [llength $n] nets"}
    return $n
}
proc rxila_net {name} {
    set n [get_nets -quiet -hier -filter "NAME == \"$name\""]
    if {[llength $n] != 1} {error "Receiver ILA: expected one net $name, found [llength $n]"}
    return $n
}
proc rxila_qbus {prefix width} {
    set result {}
    for {set i 0} {$i < $width} {incr i} {
        lappend result [rxila_pin_net [format {%s[%d]/Q} $prefix $i]]
    }
    return $result
}
proc rxila_nbus {prefix width} {
    set result {}
    for {set i 0} {$i < $width} {incr i} {
        lappend result [rxila_net [format {%s[%d]} $prefix $i]]
    }
    return $result
}
proc rxila_create {name clock_net} {
    if {[llength [get_debug_cores -quiet $name]]} {error "Receiver ILA already exists: $name"}
    create_debug_core $name ila
    set c [get_debug_cores $name]
    set_property C_DATA_DEPTH 2048 $c
    set_property C_INPUT_PIPE_STAGES 2 $c
    set_property C_TRIGIN_EN false $c
    set_property C_TRIGOUT_EN false $c
    set_property C_ADV_TRIGGER false $c
    set_property C_EN_STRG_QUAL false $c
    set_property ALL_PROBE_SAME_MU true $c
    set_property ALL_PROBE_SAME_MU_CNT 1 $c
    connect_debug_port $name/clk $clock_net
    puts "Receiver ILA $name clock: $clock_net ([get_clocks -quiet -of_objects $clock_net])"
}
proc rxila_probe {name index label nets} {
    global rxila_map
    if {$index > 0} {create_debug_port $name probe}
    set port $name/probe$index
    set_property port_width [llength $nets] [get_debug_ports $port]
    set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports $port]
    set_property MARK_DEBUG true $nets
    connect_debug_port $port $nets
    puts $rxila_map "$name\t$index\t$label\t[llength $nets]\t[join $nets {;}]"
}
set rxila_train u_gmax_a_rx/u_training
for {set lane 0} {$lane < 2} {incr lane} {
    set p [format {%s/loopi[%d].u_iserdes} $rxila_train $lane]
    set c ila_rx_d$lane
    rxila_create $c [rxila_net $rxila_train/clk_rxio${lane}_d4]
    rxila_probe $c 0 raw8 [rxila_nbus $p/iserdese3_dout 8]
    rxila_probe $c 1 shifted8 [rxila_qbus $p/iserdese3_dout_shift_reg 8]
    rxila_probe $c 2 packed12 [rxila_qbus $p/data_12b_reg 12]
    rxila_probe $c 3 fifo_write_enable [rxila_pin_net $p/data_val_reg/Q]
    rxila_probe $c 4 lane_reset [rxila_pin_net $p/ISERDESE3_inst/RST]
    rxila_probe $c 5 soft_reset [rxila_pin_net $p/rst_iserdes_d4_soft_reg/Q]
    rxila_probe $c 6 global_reset [rxila_net $rxila_train/rst_rxio${lane}_d4]
    rxila_probe $c 7 bitslip_count [rxila_qbus $p/cnt_bitslip_reg 4]
    rxila_probe $c 8 pack_counter [rxila_qbus $p/cnt_data_val_reg 3]
    rxila_probe $c 9 bit_width_mode [rxila_qbus $p/reg_bit_width_qq_reg 2]
    rxila_probe $c 10 idelay_value [rxila_qbus $p/idelay_valuein_d4_reg 9]
    rxila_probe $c 11 idelay_load [rxila_pin_net $p/idelay_ld_d4_reg/Q]
    rxila_probe $c 12 fifo_write_pointer [rxila_qbus $p/u_fifo/wr_bin_reg 6]
    rxila_probe $c 13 fifo_full [rxila_pin_net $p/u_fifo/full_r_reg/Q]
    rxila_probe $c 14 raw_activity [rxila_pin_net $p/raw_activity_reg/Q]
    rxila_probe $c 15 bitslip_pulse [rxila_pin_net $p/bitslip_d4_reg/Q]
}
set d0 [format {%s/loopi[0].u_iserdes} $rxila_train]
set d1 [format {%s/loopi[1].u_iserdes} $rxila_train]
set c ila_rx_words
rxila_create $c [rxila_pin_net $rxila_train/u_gmax3412_iob_clock/BUFGCE_RXG_DIV5_inst/O]
rxila_probe $c 0 d0_word12 [rxila_qbus $d0/datapar_reg 12]
rxila_probe $c 1 d1_word12 [rxila_qbus $d1/datapar_reg 12]
rxila_probe $c 2 d0_fifo_out12 [rxila_qbus $d0/u_fifo/dout_reg 12]
rxila_probe $c 3 d1_fifo_out12 [rxila_qbus $d1/u_fifo/dout_reg 12]
rxila_probe $c 4 fifo_read_enable_D1_D0 [concat [rxila_pin_net $d0/fifo_ren_reg/Q] [rxila_pin_net $d1/fifo_ren_reg/Q]]
rxila_probe $c 5 fifo_empty_D1_D0 [concat [rxila_pin_net $d0/u_fifo/empty_r_reg/Q] [rxila_pin_net $d1/u_fifo/empty_r_reg/Q]]
rxila_probe $c 6 d0_fifo_read_pointer [rxila_qbus $d0/u_fifo/rd_bin_reg 6]
rxila_probe $c 7 d1_fifo_read_pointer [rxila_qbus $d1/u_fifo/rd_bin_reg 6]
rxila_probe $c 8 fifo_read_reset_D1_D0 [concat [rxila_pin_net [format {%s/u_fifo/rd_bin_reg[0]/R} $d0]] [rxila_pin_net [format {%s/u_fifo/rd_bin_reg[0]/R} $d1]]]
rxila_probe $c 9 global_reset [rxila_pin_net [format {%s/chan_sel_reg[0]/R} $rxila_train]]
rxila_probe $c 10 training_result [rxila_qbus $rxila_train/training_result_reg 16]
rxila_probe $c 11 training_done [rxila_pin_net $rxila_train/training_done_reg/Q]
rxila_probe $c 12 channel_select [rxila_qbus $rxila_train/chan_sel_reg 4]
rxila_probe $c 13 alignment_state [rxila_qbus $rxila_train/FSM_sequential_fsm_align_reg 3]
rxila_probe $c 14 alignment_steps [rxila_qbus $rxila_train/cnt_steps_reg 9]
rxila_probe $c 15 alignment_counter [rxila_qbus $rxila_train/cnt_align_reg 5]
rxila_probe $c 16 debug_freeze [rxila_pin_net {u_gmax_a_rx/u_xpm_cdc_debug_freeze/syncstages_ff_reg[1]/Q}]

# Keep debug transport running when the sensor stops its output clocks.
set hub [get_debug_cores dbg_hub]
if {[llength $hub] != 1} {error "Receiver ILA: debug hub missing"}
disconnect_debug_port dbg_hub/clk
set_property C_CLK_INPUT_FREQ_HZ 100000000 $hub
set_property C_ENABLE_CLK_DIVIDER false $hub
set_property C_USER_SCAN_CHAIN 1 $hub
connect_debug_port dbg_hub/clk [rxila_net u_design_1_wrapper/design_1_i/zynq_ultra_ps_e_0_pl_clk0]
close $rxila_map
puts "Receiver ILA insertion complete: D0/D1 at 150 MHz, words at 120 MHz; depth 2048, input pipeline 2."
