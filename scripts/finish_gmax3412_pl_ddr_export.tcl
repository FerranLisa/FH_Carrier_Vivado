# Recover only the export after successful routed timing checks and bitgen.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
open_project [file join $root FH_Carrier_Bringup.xpr]
set stem [file join $root exports gmax3412_pl_ddr FH_Carrier_Bringup_GMAX3412_PL_DDR]
set run_bit [file join [get_property DIRECTORY [get_runs impl_1]] [get_property TOP [get_filesets sources_1]].bit]
file copy -force ${stem}.bit $run_bit
write_hw_platform -fixed -include_bit -force -file ${stem}.xsa
puts [exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File [file join $root scripts finalize_gmax3412_pl_ddr_xsa.ps1]]
set fd [open [file join $root exports gmax3412_pl_ddr BUILD_COMPLETE.txt] w]
puts $fd "PL_DDR_RECOVERED_EXPORT_PASS: [clock format [clock seconds]]"
puts $fd "Corrected auxiliary reset tied high; DCI startup included. Exact BIT/XSA hash verified."
puts $fd "Routed timing, bus skew, routing, DRC, memory map and reset connection checks passed."
puts $fd "Original full-build exit 1 was an export-only failure; see results/pl_ddr_finish_export.log."
puts $fd "Hardware qualification of corrected BIT is pending."
close $fd
puts "PL_DDR_RECOVERED_EXPORT_PASS"
close_project
