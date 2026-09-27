# Run this once from Vivado Tcl Console after opening FH_Carrier_Bringup.xpr.
# It installs the implementation hook for the raw I2C ILA and forces clean runs.

set proj [current_project]
if {$proj eq ""} { error "Open FH_Carrier_Bringup.xpr first" }
set proj_dir [get_property DIRECTORY $proj]
set hook [file join $proj_dir FH_Carrier_Bringup.srcs utils_1 i2c_debug insert_i2c_raw_ila.tcl]
set wrapper [file join $proj_dir FH_Carrier_Bringup.srcs sources_1 new design_1_wrapper.v]

if {![file exists $hook]} { error "Missing hook: $hook" }
if {![file exists $wrapper]} { error "Missing debug wrapper: $wrapper" }

# Regenerate the parent BD, including SmartConnect/System ILA child designs.
# Do this before resetting synthesis runs. Never regenerate the maintained wrapper.
set bd [get_files -quiet */bd/design_1/design_1.bd]
if {[llength $bd] != 1} {
    error "Expected exactly one design_1.bd; found [llength $bd]: $bd"
}
puts "Regenerating design_1 Block Design output products..."
reset_target all $bd
generate_target all $bd -force
# Do not use -quiet: export/generation errors must stop the build.
export_ip_user_files -of_objects $bd -no_script -sync -force

# Ensure the maintained wrapper is in the source set and the stale generated wrapper is not.
set gen_wrapper [get_files -quiet */bd/design_1/hdl/design_1_wrapper.v]
if {[llength $gen_wrapper] > 0} {
    remove_files $gen_wrapper
}
if {[llength [get_files -quiet $wrapper]] == 0} {
    add_files -norecurse -fileset sources_1 $wrapper
}
set_property top design_1_wrapper [get_filesets sources_1]
set_property top_auto_set 0 [get_filesets sources_1]
set_property top design_1_wrapper [get_filesets sim_1]
set_property top_auto_set 0 [get_filesets sim_1]

# Keep the hook visible in Utils and attach it after init_design, before opt_design.
if {[llength [get_files -quiet $hook]] == 0} {
    add_files -norecurse -fileset utils_1 $hook
}
set_property STEPS.INIT_DESIGN.TCL.POST $hook [get_runs impl_1]

# Do not reuse the old wrapper synthesis checkpoint.
catch {set_property AUTO_INCREMENTAL_CHECKPOINT false [get_runs synth_1]}
catch {set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Clean runs are mandatory because the top wrapper and debug netlist have changed.
reset_run impl_1
foreach ip_run [get_runs -quiet design_1_*_synth_1] {
    reset_run $ip_run
}
reset_run synth_1

puts ""
puts "FH_Carrier I2C logic analyzer setup complete."
puts "Implementation hook: $hook"
puts "Top: [get_property TOP [get_filesets sources_1]]"
puts "Next: Generate Bitstream normally, or source BUILD_I2C_LOGIC_ANALYZER.tcl"

