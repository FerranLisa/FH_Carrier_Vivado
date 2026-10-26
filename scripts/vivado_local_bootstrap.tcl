# Some installations omit Tcl Store support directories from auto_path.
# Process-local search-path repair only; no installed/user files are changed.
if {[info exists ::env(XILINX_VIVADO)]} {
    foreach sub {appinit args} {
        lappend auto_path [file join $::env(XILINX_VIVADO) data XilinxTclStore support $sub]
    }
    foreach dir [glob -nocomplain -types d [file join $::env(XILINX_VIVADO) data XilinxTclStore tclapp * *]] {
        lappend auto_path $dir
    }
    # Debug-core synthesis starts a child Vivado process. TCLLIBPATH makes the
    # same process-local repair available to that child before project creation.
    set store_package_paths {}
    if {[info exists ::env(TCLLIBPATH)]} {set store_package_paths $::env(TCLLIBPATH)}
    foreach dir $auto_path {
        if {[string match *XilinxTclStore* $dir] && [lsearch -exact $store_package_paths $dir] < 0} {
            lappend store_package_paths $dir
        }
    }
    set ::env(TCLLIBPATH) $store_package_paths
}
