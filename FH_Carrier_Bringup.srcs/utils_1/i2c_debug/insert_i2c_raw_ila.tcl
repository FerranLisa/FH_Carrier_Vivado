# FH_Carrier raw I2C logic-analyzer insertion hook
# Run point: impl_1 STEPS.INIT_DESIGN.TCL.POST
# Vivado 2025.2

puts "INFO: FH_I2C_ILA: inserting raw PAC1944 I2C ILA"

proc fh_one_net_ending {suffix} {
    # The maintained wrapper declares these exact top-level nets. A hierarchical
    # suffix search also finds the BD-side segment, which is not an ambiguity.
    set candidates [get_nets -quiet $suffix]
    set matches {}
    foreach n $candidates {
        set nm [get_property NAME $n]
        if {$nm eq $suffix} {
            lappend matches $n
        }
    }
    if {[llength $matches] != 1} {
        puts "ERROR: FH_I2C_ILA: expected one exact wrapper net '$suffix', found [llength $matches]: $matches"
        error "FH_I2C_ILA net lookup failed for $suffix"
    }
    return [lindex $matches 0]
}

# Do not create a duplicate if the hook is sourced twice in the same design.
if {[llength [get_debug_cores -quiet i2c_raw_ila]] != 0} {
    puts "INFO: FH_I2C_ILA: i2c_raw_ila already exists; leaving existing core unchanged"
    return
}

set scl_i [fh_one_net_ending PAC1944_I2C_scl_i]
set sda_i [fh_one_net_ending PAC1944_I2C_sda_i]
set scl_o [fh_one_net_ending PAC1944_I2C_scl_o]
set scl_t [fh_one_net_ending PAC1944_I2C_scl_t]
set sda_o [fh_one_net_ending PAC1944_I2C_sda_o]
set sda_t [fh_one_net_ending PAC1944_I2C_sda_t]

# Exact functional PLCLK0 net, also used by the existing XDC.
# Never select an auto-generated dbg_hub_* net using a wildcard.
set clk_net [get_nets -quiet design_1_i/zynq_ultra_ps_e_0_pl_clk0]
if {[llength $clk_net] != 1} {
    error "FH_I2C_ILA: expected exact functional PLCLK0 net; found: $clk_net"
}
puts "INFO: FH_I2C_ILA: clock net = [get_property NAME $clk_net]"

create_debug_core i2c_raw_ila ila
set ila [get_debug_cores i2c_raw_ila]
set_property C_DATA_DEPTH 65536 $ila
set_property C_TRIGIN_EN false $ila
set_property C_TRIGOUT_EN false $ila
set_property C_ADV_TRIGGER false $ila
set_property C_INPUT_PIPE_STAGES 0 $ila
set_property C_EN_STRG_QUAL false $ila
set_property ALL_PROBE_SAME_MU true $ila
set_property ALL_PROBE_SAME_MU_CNT 1 $ila
if {[lsearch -exact [list_property $ila] C_CLK_INPUT_FREQ_HZ] >= 0} {
    set_property C_CLK_INPUT_FREQ_HZ 100000000 $ila
}

set_property port_width 1 [get_debug_ports i2c_raw_ila/clk]
connect_debug_port [get_debug_ports i2c_raw_ila/clk] $clk_net

# Mapping shown in Hardware Manager / LTX:
# probe0 = SCL_I : actual SCL level at FPGA pin after IOBUF
# probe1 = SDA_I : actual SDA level at FPGA pin after IOBUF
# probe2 = SCL_O : AXI IIC output data toward IOBUF
# probe3 = SCL_T : AXI IIC tri-state control (1 = released)
# probe4 = SDA_O : AXI IIC output data toward IOBUF
# probe5 = SDA_T : AXI IIC tri-state control (1 = released)
set probe_nets [list $scl_i $sda_i $scl_o $scl_t $sda_o $sda_t]
for {set i 0} {$i < 6} {incr i} {
    if {$i > 0} {
        create_debug_port i2c_raw_ila probe
    }
    set p [get_debug_ports i2c_raw_ila/probe$i]
    set_property port_width 1 $p
    set_property PROBE_TYPE DATA_AND_TRIGGER $p
    connect_debug_port $p [lindex $probe_nets $i]
    puts "INFO: FH_I2C_ILA: probe$i -> [get_property NAME [lindex $probe_nets $i]]"
}

puts "INFO: FH_I2C_ILA: raw I2C ILA inserted, depth=65536 @ 100 MHz"
report_debug_core
