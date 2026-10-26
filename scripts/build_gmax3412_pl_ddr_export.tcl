# Full in-process build: avoids Windows Script Host, preserves the receiver ILA
# insertion hook, and exports only after timing/methodology checks pass.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
set_param general.maxThreads 8
cd $root
set out [file join $root exports gmax3412_pl_ddr]
file mkdir $out
open_project [file join $root FH_Carrier_Bringup.xpr]
update_ip_catalog
upgrade_ip [get_ips design_1_gmax_pl_ring_0]
set bd [get_files */bd/design_1/design_1.bd]
open_bd_design $bd
source [file join $root scripts add_pl_ddr_dci_reset.tcl]
source [file join $root scripts fix_pl_ddr_reset_polarity.tcl]
set_property CONFIG.PRIM_SOURCE No_buffer [get_bd_cells gmax_emu_clock]
source [file join $root scripts exclude_pl_ddr_control_segments.tcl]
validate_bd_design
if {[get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells pl_ddr_reset]] != 1 ||
    [get_property CONFIG.C_AUX_RESET_HIGH [get_bd_cells pl_ddr_reset]] != 0} {
    error "Unexpected propagated DDR reset polarity"
}
if {[get_property CONFIG.c_addr_width [get_bd_cells gmax_capture_dma]] != 64} {error "DMA must support high DDR"}
set high [get_bd_addr_segs gmax_capture_dma/Data_S2MM/SEG_zynq_ultra_ps_e_0_HP0_DDR_HIGH]
if {[llength $high]!=1 || [get_property OFFSET $high]!=0x800000000} {error "High DDR is not mapped for DMA"}
save_bd_design
set previous_mode [get_property SYNTH_CHECKPOINT_MODE $bd]
set stem [file join $out FH_Carrier_Bringup_GMAX3412_PL_DDR]
try {
    set_property SYNTH_CHECKPOINT_MODE None $bd
    # An interrupted generation can leave SmartConnect child modules absent
    # while the parent target is marked current. Rebuild the generated products.
    reset_target all $bd
    generate_target all $bd
    update_compile_order -fileset sources_1
    synth_design -top FH_Carrier_Bringup_top -part xczu7ev-ffvc1156-2-i
    if {[llength [get_cells -hier -filter {NAME =~ *gmax_scheduler* && REF_NAME =~ FD*}]] < 100} {error "Scheduler missing from netlist"}
    if {[llength [get_cells -hier -filter {NAME =~ *timing_monitor*}]] == 0} {error "Timing monitor missing from synthesized design"}
    if {[llength [get_cells -hier -filter {NAME =~ *gmax_pl_ring* && REF_NAME =~ FD*}]] < 100} {error "PL ring absent"}
    if {[llength [get_cells -hier -filter {REF_NAME == DCIRESET}]] != 1} {error "DDR DCI reset primitive missing"}
    set dci_sync [get_pins -hier -regexp {.*pl_ddr_dci_reset.*/lock_sync_reg\[0\]/D}]
    if {[llength $dci_sync] != 1} {error "DCI LOCKED synchronizer missing"}
    set_false_path -to $dci_sync
    set_false_path -to [get_pins -hier -regexp {.*gmax_pl_ring.*/calibrated_reg\[0\]/D}]
    write_checkpoint -force ${stem}_synth.dcp
    set hook [get_property STEPS.INIT_DESIGN.TCL.POST [get_runs impl_1]]
    if {$hook eq "" || ![file exists $hook]} {error "Existing receiver ILA hook is missing"}
    source $hook
    opt_design
    if {[file exists [file join $root audit pl_ddr4 pre_dci_routed.dcp]]} {
        read_checkpoint -incremental [file join $root audit pl_ddr4 pre_dci_routed.dcp]
    }
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
    set fd [open [file join $out drc.rpt] r]
    set drc_report [read $fd]; close $fd
    if {[regexp {DCIRST-1|Critical Warning|\| Error} $drc_report]} {error "DDR DCI/reset or critical DRC finding remains; no export produced"}
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
    # Project-mode export looks in impl_1 even for an in-process build.
    # Stage this exact BIT there before requesting Vivado's native archive.
    set run_bit [file join [get_property DIRECTORY [get_runs impl_1]] [get_property TOP [get_filesets sources_1]].bit]
    file copy -force ${stem}.bit $run_bit
    write_hw_platform -fixed -include_bit -force -file ${stem}.xsa
    # Project-mode export may pull the old normal-run BIT. Explicitly bind the
    # archive to this build's BIT and require an exact SHA-256 match.
    puts [exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File [file join $root scripts finalize_gmax3412_pl_ddr_xsa.ps1]]
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


