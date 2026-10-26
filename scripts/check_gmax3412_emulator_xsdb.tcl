# XSDB smoke test. Select an appropriate PS target and program the updated
# bitstream before sourcing this file. This script does not connect, program,
# reset, halt or resume the target. It accesses only the emulator's AXI registers.
set emu_base 0xA0030000
proc emu_read {offset} {
    global emu_base
    set raw [lindex [mrd -value [expr {$emu_base+$offset}]] 0]
    if {[scan $raw %x value] != 1} {error "Invalid XSDB read result: $raw"}
    return $value
}
proc emu_write {offset value} {
    global emu_base
    mwr [expr {$emu_base+$offset}] $value
}
proc emu_wait {offset mask expected} {
    set deadline [expr {[clock milliseconds]+1000}]
    while {([emu_read $offset] & $mask) != $expected} {
        if {[clock milliseconds]>$deadline} {error "Emulator timeout at offset $offset"}
        after 1
    }
}
if {[emu_read 0] != 0x34120001} {error "Emulator ID/version mismatch"}
emu_write 4 4
emu_wait 8 4 0
# Let any preceding frame checker commit before recording baseline counters.
after 1
set emu_frames_before [emu_read 0x28]
set emu_errors_before [emu_read 0x2c]
set emu_accepted_before [emu_read 0x20]
set emu_rejected_before [emu_read 0x24]
emu_write 4 1
emu_wait 8 1 1
emu_write 0x0c 120000
emu_write 0x10 16
emu_write 0x14 7
emu_write 4 2
emu_wait 8 2 2
emu_write 4 8
emu_wait 0x28 0xffffffff [expr {($emu_frames_before+1)&0xffffffff}]
emu_write 4 4
if {[emu_read 0x20] != (($emu_accepted_before+1)&0xffffffff) ||
    [emu_read 0x24] != $emu_rejected_before ||
    [emu_read 0x2c] != $emu_errors_before ||
    [emu_read 0x30] != 12582912 || [emu_read 0x34] != 3072 ||
    [emu_read 0x38] != 0x7fa00000 || !([emu_read 8]&16)} {
    error "GMAX3412 emulator checker failed; inspect registers 0x08 and 0x20..0x38"
}
puts "PASS: GMAX3412 4096x3072 frame; pixels=12582912 lines=3072 checksum=0x7FA00000"
