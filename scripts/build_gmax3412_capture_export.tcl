# Full in-process build: avoids Windows Script Host, preserves the receiver ILA
# insertion hook, and exports only after timing/methodology checks pass.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
cd $root
set out [file join $root exports gmax3412_capture]
file mkdir $out
open_project [file join $root FH_Carrier_Bringup.xpr]
update_ip_catalog
upgrade_ip [get_ips design_1_gmax_capture_0]
set bd [get_files */bd/design_1/design_1.bd]
open_bd_design $bd
set_property CONFIG.PRIM_SOURCE No_buffer [get_bd_cells gmax_emu_clock]
validate_bd_design
save_bd_design
set previous_mode [get_property SYNTH_CHECKPOINT_MODE $bd]
set stem [file join $out FH_Carrier_Bringup_GMAX3412_Capture]
try {
    set_property SYNTH_CHECKPOINT_MODE None $bd
    generate_target all $bd
    update_compile_order -fileset sources_1
    synth_design -top FH_Carrier_Bringup_top -part xczu7ev-ffvc1156-2-i
    write_checkpoint -force ${stem}_synth.dcp
    set hook [get_property STEPS.INIT_DESIGN.TCL.POST [get_runs impl_1]]
    if {$hook eq "" || ![file exists $hook]} {error "Existing receiver ILA hook is missing"}
    source $hook
    opt_design
    place_design
    phys_opt_design
    route_design
    if {[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]] < 0 ||
        [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]] < 0} {
        phys_opt_design -directive AggressiveExplore
    }
    report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
    report_methodology -file [file join $out methodology.rpt]
    report_drc -file [file join $out drc.rpt]
    report_bus_skew -file [file join $out bus_skew.rpt]
    report_cdc -details -file [file join $out cdc.rpt]
    report_clocks -file [file join $out clocks.rpt]
    report_utilization -file [file join $out utilization.rpt]
    report_route_status -file [file join $out route_status.rpt]
    write_checkpoint -force ${stem}_routed.dcp
    set fd [open [file join $out methodology.rpt] r]
    set method_report [read $fd]
    close $fd
    if {[regexp {Critical Warning|TIMING-24} $method_report]} {error "Critical methodology or overridden capture CDC constraints remain; no export produced"}
    set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
    set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
    if {$wns < 0 || $whs < 0} {error "Timing failed: WNS=$wns WHS=$whs"}
    set fd [open [file join $out bus_skew.rpt] r]
    set skew_report [read $fd]
    close $fd
    if {[regexp {VIOLATED} $skew_report]} {error "Bus skew violation; no export produced"}
    source [file join $root verify_constraints.tcl]
    write_bitstream -force ${stem}.bit
    write_debug_probes -force ${stem}.ltx
    write_hw_platform -fixed -include_bit -force -file ${stem}.xsa
    # Project-mode export may pull the old normal-run BIT. Explicitly bind the
    # archive to this build's BIT and require an exact SHA-256 match.
    puts [exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File [file join $root scripts finalize_gmax3412_capture_xsa.ps1]]
    set fd [open [file join $out BUILD_COMPLETE.txt] w]
    puts $fd "Completed [clock format [clock seconds]] with Vivado [version -short]"
    puts $fd "Clocking Wizard PRIM_SOURCE=No_buffer; existing receiver ILA hook preserved."
    puts $fd "Routed WNS=$wns ns; WHS=$whs ns. No critical methodology violations or bus-skew violations."
    puts $fd "BIT/LTX/XSA: $stem"
    puts $fd "XSA includes the bitstream. Physical board smoke test not run; review cdc.rpt for remaining receiver findings."
    close $fd
    puts "BUILD_AND_EXPORT_PASS: $stem WNS=$wns WHS=$whs"
} finally {
    set_property SYNTH_CHECKPOINT_MODE $previous_mode $bd
    close_project
}
