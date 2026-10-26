# Run with Vitis XSCT. Read-only validation of the finalized hardware handoff.
set root [file normalize [file join [file dirname [info script]] ..]]
set xsa [file join $root exports gmax3412_timing FH_Carrier_Bringup_GMAX3412_Timing.xsa]
hsi::open_hw_design $xsa
foreach name {gmax_capture gmax_capture_ctrl gmax_capture_dma} {
 if {[llength [hsi::get_cells -hier $name]] != 1} {error "Missing capture cell $name"}
}
set peripheral [hsi::get_cells -hier -filter {IP_NAME == gmax3412_emulator}]
if {[llength $peripheral] != 1} {error "Expected one gmax3412_emulator peripheral"}
puts "Emulator: $peripheral"
set ranges [hsi::get_mem_ranges -of_objects [hsi::get_cells psu_cortexa53_0]]
set found 0
set control_found 0
set dma_found 0
foreach range $ranges {
    set base [common::get_property BASE_VALUE $range]
    if {$base ne "" && [string is entier -strict $base]} {
        if {$base == 0xA0040000} {set control_found 1}
        if {$base == 0xA0050000} {set dma_found 1}
    }
    if {$base ne "" && [string is entier -strict $base] && $base == 0xA0030000} {
        puts "Emulator memory range: $range base=$base"
        set found 1
    }
}
if {!$found} {error "A53 memory map does not contain emulator base 0xA0030000"}
if {!$control_found || !$dma_found} {error "Capture control/DMA address missing"}
hsi::close_hw_design [hsi::current_hw_design]
puts "XSA_HSI_VALIDATION_PASS"

