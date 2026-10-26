# Resume the routed capture checkpoint after narrowing the legacy clock group.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
cd $root
set out [file join $root exports gmax3412_capture]
set stem [file join $out FH_Carrier_Bringup_GMAX3412_Capture]
open_checkpoint ${stem}_routed.dcp
# Vivado has no reset_clock_groups command. Round-trip the complete resolved
# constraint set, removing only this one named exception before reloading it.
set original [file join $out constraints_before_fix.xdc]
set corrected [file join $out constraints_corrected.xdc]
if {![file exists $original] || [file mtime $original]<[file mtime ${stem}_routed.dcp]} {
 write_xdc -force $original
}
set fd [open $original];set text [read $fd];close $fd
set fd [open $corrected w]
set command "";set removed 0
foreach line [split $text \n] {
 append command $line \n
 if {[info complete $command]} {
  if {[string match *set_clock_groups*FH_ASYNC_PL_GMAX_FAMILIES* $command]} {
   incr removed
  } else {puts -nonewline $fd $command}
  set command ""
 }
}
puts -nonewline $fd $command
close $fd
if {$removed!=1} {error "Expected exactly one legacy clock group; found $removed"}
# write_xdc serializes this project's PCIe primary clock after the dependent
# rename-only generated-clock command. Preserve it but move it before its use.
set fd [open $corrected];set fixed [read $fd];close $fd
if {![regexp -line {^create_clock .* -name M2_PCIE_REFCLK_SOM_100M.*$} $fixed primary]} {
 error "PCIe primary clock missing from resolved constraints"
}
regsub -line {^create_clock .* -name M2_PCIE_REFCLK_SOM_100M.*$} $fixed {} fixed
set fd [open $corrected w];puts $fd $primary;puts -nonewline $fd $fixed;close $fd
reset_timing
read_xdc $corrected
set_clock_groups -name FH_ASYNC_PL_GMAX_FAMILIES -asynchronous \
 -group [get_clocks clk_pl_0] \
 -group [get_clocks -include_generated_clocks GMX_A_CLK0] \
 -group [get_clocks -include_generated_clocks GMX_A_CLK1]
if {[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]<0 ||
    [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]<0} {
 phys_opt_design -directive AggressiveExplore
 route_design -directive Explore
}
report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
report_methodology -file [file join $out methodology.rpt]
report_drc -file [file join $out drc.rpt]
report_bus_skew -file [file join $out bus_skew.rpt]
report_cdc -details -file [file join $out cdc.rpt]
report_clocks -file [file join $out clocks.rpt]
report_route_status -file [file join $out route_status.rpt]
set fd [open [file join $out methodology.rpt]];set method [read $fd];close $fd
if {[regexp {Critical Warning|TIMING-24} $method]} {error "Capture methodology not clean"}
set fd [open [file join $out bus_skew.rpt]];set skew [read $fd];close $fd
if {[regexp VIOLATED $skew]} {error "Bus skew failed"}
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
if {$wns<0 || $whs<0} {error "Timing failed WNS=$wns WHS=$whs"}
source [file join $root verify_constraints.tcl]
write_checkpoint -force ${stem}_routed.dcp
write_bitstream -force ${stem}.bit
write_debug_probes -force ${stem}.ltx
close_project
open_project [file join $root FH_Carrier_Bringup.xpr]
write_hw_platform -fixed -include_bit -force -file ${stem}.xsa
close_project
puts [exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File [file join $root scripts finalize_gmax3412_capture_xsa.ps1]]
set fd [open [file join $out BUILD_COMPLETE.txt] w]
puts $fd "Capture build completed with Vivado [version -short]. WNS=$wns WHS=$whs."
puts $fd "Legacy clock group narrowed; XPM max-delay constraints retained; no TIMING-24 or critical methodology violations."
puts $fd "BIT/LTX/XSA matched and hash verified. Physical DDR smoke test pending."
close $fd
puts "CAPTURE_CONSTRAINT_EXPORT_PASS WNS=$wns WHS=$whs"
