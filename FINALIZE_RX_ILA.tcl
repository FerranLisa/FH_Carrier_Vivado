# Packaging/verification helper; does not change the routed netlist.
set root [file dirname [file normalize [info script]]]
cd $root
open_project FH_Carrier_Bringup.xpr
set hook [file join $root insert_receiver_ila.tcl]
if {[llength [get_files -quiet $hook]] == 0} {add_files -fileset utils_1 -norecurse $hook}
set_property STEPS.INIT_DESIGN.TCL.POST $hook [get_runs impl_1]
open_run impl_1
set h [open debug/routed_debug_identity.txt w]
foreach {name driver expected_probes} {ila_rx_d0 BUFGCE0_DIV_inst 16 ila_rx_d1 BUFGCE1_DIV_inst 16 ila_rx_words BUFGCE_RXG_DIV5_inst 17} {
    set core [get_debug_cores -quiet $name]
    if {[llength $core] != 1} {error "Missing routed debug core $name"}
    set clock [get_clocks -quiet -of_objects [get_pins $name/clk]]
    set expected [get_clocks -quiet -of_objects [get_pins u_gmax_a_rx/u_training/u_gmax3412_iob_clock/$driver/O]]
    puts $h "$name UUID=[get_property UUID $core] CLOCK=$clock DEPTH=[get_property C_DATA_DEPTH $core] INPUT_PIPE=[get_property C_INPUT_PIPE_STAGES $core]"
    if {[llength $clock] != 1 || $clock ne $expected} {error "Wrong routed ILA clock for $name: $clock"}
    if {[get_property C_DATA_DEPTH $core] != 2048 || [get_property C_INPUT_PIPE_STAGES $core] != 2} {error "Wrong ILA configuration"}
    set probes [get_debug_ports -quiet $name/probe*]
    if {[llength $probes] != $expected_probes} {error "Wrong probe count for $name"}
    foreach p $probes {puts $h "$p WIDTH=[get_property PORT_WIDTH $p]"}
}
puts $h "Debug hub clock: [get_clocks -quiet -of_objects [get_pins dbg_hub/clk]]"
close $h
# Installed-version help verifies the delivered capture helper's commands.
foreach c {run_hw_ila wait_on_hw_ila upload_hw_ila_data write_hw_ila_data display_hw_ila_data} {help $c}
close_project
