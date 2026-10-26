set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
set stage routed
if {[llength $argv]} {set stage [lindex $argv 0]}
if {$stage ni {synth routed}} {error "Expected synth or routed checkpoint"}
open_checkpoint [file join $root exports gmax3412_timing FH_Carrier_Bringup_GMAX3412_Timing_${stage}.dcp]
set registers [get_cells -hier -filter {NAME =~ *timing_monitor* && REF_NAME =~ FD*}]
if {[llength $registers] < 256} {error "Hardware timing monitor missing or unexpectedly reduced: [llength $registers] registers"}
set boxes [get_cells -hier -filter {IS_BLACKBOX == 1}]
if {$stage eq "synth"} {set boxes [lsearch -all -inline -not -exact $boxes dbg_hub]}
if {[llength $boxes]} {error "Unresolved black boxes: $boxes"}
puts "TIMING_NETLIST_PASS: [llength $registers] monitor registers, no black boxes"
close_design
