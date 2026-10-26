# Apply explicit exclusions for paths that were already unmapped in the routed
# netlist. No reachable address, RTL, pin or clock is changed by this step.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts vivado_local_bootstrap.tcl]
open_project [file join $root FH_Carrier_Bringup.xpr]
open_bd_design [get_files */bd/design_1/design_1.bd]
source [file join $root scripts exclude_pl_ddr_control_segments.tcl]
validate_bd_design
save_bd_design
puts [exec C:/AMDDesignTools/2025.2/tps/win64/python-3.13.0/python.exe [file join $root scripts verify_pl_ddr_handoff_map.py]]
set out [file join $root exports gmax3412_pl_ddr]
set stem [file join $out FH_Carrier_Bringup_GMAX3412_PL_DDR]
generate_target all [get_files */bd/design_1/design_1.bd]
write_hw_platform -fixed -include_bit -force -file ${stem}.xsa
puts [exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File [file join $root scripts finalize_gmax3412_pl_ddr_xsa.ps1]]
puts "PL_DDR_METADATA_PASS"
close_project
