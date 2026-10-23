# ============================================================
# FH_Carrier_Bringup.xdc - revision trace
# ============================================================
# 2026-10-02  REV 1.2G-6 - Split post-synthesis clock relationships into implementation-only XDC
#   - REV 1.2G-5 created synthesis-time Critical Warnings because clk_pl_0 and
#     internal PCIe monitor objects do not exist while Block Design IP is still
#     represented by synthesis black boxes.
#   - Remove explicit user-generated GMAX BUFGCE_DIV clocks; Vivado already
#     derives clk_rxio0_d4, clk_rxio1_d4 and gmax_a_pixel_clk correctly.
#   - Move all set_clock_groups constraints that reference clk_pl_0 and all
#     post-synthesis PCIe reset endpoint constraints to
#     FH_Carrier_Bringup_impl.xdc, which MUST be implementation-only.
#   - Fix the malformed REV 1.2G-5 comment and remove Tcl 'if' from XDC.
#   - No package-pin, I/O-standard, termination, electrical, or sensor-rate changes.
#
# 2026-10-02  REV 1.2G-5 - Explicit BUFGCE_DIV clock definitions + unconditional clock grouping
#   - REV 1.2G-4 still left TIMING-6/TIMING-7 because its guarded queries of
#     auto-derived clocks could evaluate before those clock objects existed and
#     silently skip the set_clock_groups commands.
#   - Define the three GMAX generated clocks explicitly at the BUFGCE_DIV output
#     pins, using each divider input pin as the generated-clock source.
#   - /4 clocks use edges {1 5 9}; the /5 clock uses edges {1 5 11}, preserving
#     the actual BUFGCE_DIV divide ratio and odd-divider duty cycle.
#   - Apply one unconditional asynchronous grouping across clk_pl_0, the complete
#     CLK_OUT0 family, and the complete CLK_OUT1 family.
#   - No electrical, package-pin, I/O-standard, data false-path, or low-speed I/O
#     changes relative to REV 1.2G-4.
#
# 2026-10-02  REV 1.2G-4 - Exact generated-clock grouping + PCIe async-reset timing cleanup
#   - Rename the auto-derived GMAX BUFGCE_DIV clocks at their source pins using
#     the rename-only create_generated_clock form. No period/divider is redefined.
#   - Replace broad clock-family discovery with exact clock groups so the
#     CLK_OUT0-derived 120 MHz pixel domain and CLK_OUT1-derived 150 MHz odd-lane
#     domain are unambiguously asynchronous. This targets the remaining
#     TIMING-6/TIMING-7 pair reported by routed methodology analysis.
#   - Add a false path only to the first PCIe 50 MHz reset-synchronizer CLR pin.
#     sys_resetn is intentionally asynchronous-assert / synchronous-deassert, so
#     recovery/removal timing from clk_pl_0 to this first async-reset stage is not
#     a valid synchronous timing relationship. This targets the PCIe TIMING-6/7.
#   - Retain synchronous timing between CLK_OUT0 /4 and /5 because they share the
#     same forwarded clock and common BUFGCE_DIV startup reset.
#
# 2026-10-02  REV 1.2G-3 - Explicit asynchronous clock-family relationships after CDC analysis
#   - Declare PS clk_pl_0, GMAX CLK_OUT0 family, and GMAX CLK_OUT1 family mutually asynchronous.
#   - This removes TIMING-6/TIMING-7/TIMING-8 methodology Critical Warnings without masking
#     synchronous crossings within each GMAX clock family.
#   - CLK_OUT0/CLK_OUT1 are each source-synchronous to their own even/odd data lanes; the
#     GMAX3412 datasheet does not specify a deterministic inter-clock phase relationship.
#   - REV 1.2G-2 generated-clock cleanup is retained.
#
# 2026-10-02  REV 1.2G-2 - Timing-model cleanup after routed analysis
#   - Keep only the two primary 600 MHz GMAX_A forwarded clocks.
#   - Remove manual create_generated_clock constraints for the /4 and /5
#     BUFGCE_DIV outputs; Vivado derives these clocks from the primitives.
#   - Remove the asynchronous clock-group declaration between the 120 MHz
#     word/training clock and 150 MHz ISERDES CLKDIV clocks. They are derived
#     from the same forwarded clock, and the blanket asynchronous declaration
#     overrode the receiver/FIFO CDC timing exceptions.
#   - No package-pin, I/O-standard, termination, or electrical changes.
#   - All 1.20 Gb/s sensor operating-point constraints are retained.
#
# Previous baseline: REV 1.2G-1, initial 1.20 Gb/s receiver timing constraints.
# ============================================================

# ============================================================
# PAC1944 Power Monitor I2C
# PS I2C1 through EMIO
# ============================================================

set_property PACKAGE_PIN D2 [get_ports PAC1944_I2C_scl_io]
set_property IOSTANDARD LVCMOS33 [get_ports PAC1944_I2C_scl_io]

set_property PACKAGE_PIN C2 [get_ports PAC1944_I2C_sda_io]
set_property IOSTANDARD LVCMOS33 [get_ports PAC1944_I2C_sda_io]


# ============================================================
# FH_Sen4K / GMAX3412 A
# ZU7EV BANK 28
# VCCO experimentally confirmed = 1.8 V
# ============================================================

# Power / clock / reset / interface selection

set_property PACKAGE_PIN A19 [get_ports GMX_A_PWR_EN]
set_property PACKAGE_PIN A18 [get_ports GMX_A_CLK_EN]
set_property PACKAGE_PIN A21 [get_ports GMX_A_SYS_RST_N]
set_property PACKAGE_PIN A20 [get_ports GMX_A_CCI_EN]

# XCE in SPI mode / SLAMODE in I2C mode

set_property PACKAGE_PIN L22 [get_ports GMX_A_XCE_SLAMODE]

# Exposure

set_property PACKAGE_PIN L23 [get_ports GMX_A_TEXP1]
set_property PACKAGE_PIN K24 [get_ports GMX_A_TEXP2]

# SPI

set_property PACKAGE_PIN C18 [get_ports GMX_A_SPI_SCK]
set_property PACKAGE_PIN C19 [get_ports GMX_A_SPI_SDI]
set_property PACKAGE_PIN L21 [get_ports GMX_A_SDO_TDIG]

# I2C

set_property PACKAGE_PIN J21 [get_ports GMX_A_I2C_SCL]
set_property PACKAGE_PIN J22 [get_ports GMX_A_I2C_SDA]

# All GMAX_A control I/O is Bank 28 / 1.8 V

set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_PWR_EN]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_CLK_EN]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_SYS_RST_N]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_CCI_EN]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_XCE_SLAMODE]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_TEXP1]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_TEXP2]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_SPI_SCK]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_SPI_SDI]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_SDO_TDIG]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_I2C_SCL]
set_property IOSTANDARD LVCMOS18 [get_ports GMX_A_I2C_SDA]

# ============================================================
# GMAX3412-A Sub-LVDS DATA - 16 lanes
# ZU7EV Bank 28, VCCO = 1.8 V
# ============================================================

set_property PACKAGE_PIN B20 [get_ports GMX_A_D0_P]
set_property PACKAGE_PIN B21 [get_ports GMX_A_D0_N]

set_property PACKAGE_PIN G21 [get_ports GMX_A_D1_P]
set_property PACKAGE_PIN F21 [get_ports GMX_A_D1_N]

set_property PACKAGE_PIN A22 [get_ports GMX_A_D2_P]
set_property PACKAGE_PIN A23 [get_ports GMX_A_D2_N]

set_property PACKAGE_PIN G20 [get_ports GMX_A_D3_P]
set_property PACKAGE_PIN F20 [get_ports GMX_A_D3_N]

set_property PACKAGE_PIN B18 [get_ports GMX_A_D4_P]
set_property PACKAGE_PIN B19 [get_ports GMX_A_D4_N]

set_property PACKAGE_PIN D20 [get_ports GMX_A_D5_P]
set_property PACKAGE_PIN D21 [get_ports GMX_A_D5_N]

set_property PACKAGE_PIN G25 [get_ports GMX_A_D6_P]
set_property PACKAGE_PIN G26 [get_ports GMX_A_D6_N]

set_property PACKAGE_PIN H21 [get_ports GMX_A_D7_P]
set_property PACKAGE_PIN H22 [get_ports GMX_A_D7_N]

set_property PACKAGE_PIN D22 [get_ports GMX_A_D8_P]
set_property PACKAGE_PIN C23 [get_ports GMX_A_D8_N]

set_property PACKAGE_PIN E19 [get_ports GMX_A_D9_P]
set_property PACKAGE_PIN D19 [get_ports GMX_A_D9_N]

set_property PACKAGE_PIN E24 [get_ports GMX_A_D10_P]
set_property PACKAGE_PIN D24 [get_ports GMX_A_D10_N]

set_property PACKAGE_PIN J24 [get_ports GMX_A_D11_P]
set_property PACKAGE_PIN H24 [get_ports GMX_A_D11_N]

set_property PACKAGE_PIN C21 [get_ports GMX_A_D12_P]
set_property PACKAGE_PIN C22 [get_ports GMX_A_D12_N]

set_property PACKAGE_PIN J25 [get_ports GMX_A_D13_P]
set_property PACKAGE_PIN H26 [get_ports GMX_A_D13_N]

set_property PACKAGE_PIN G23 [get_ports GMX_A_D14_P]
set_property PACKAGE_PIN G24 [get_ports GMX_A_D14_N]

set_property PACKAGE_PIN K22 [get_ports GMX_A_D15_P]
set_property PACKAGE_PIN K23 [get_ports GMX_A_D15_N]


# Sub-LVDS electrical standard

set_property IOSTANDARD SUB_LVDS [get_ports {
    GMX_A_D0_P  GMX_A_D0_N
    GMX_A_D1_P  GMX_A_D1_N
    GMX_A_D2_P  GMX_A_D2_N
    GMX_A_D3_P  GMX_A_D3_N
    GMX_A_D4_P  GMX_A_D4_N
    GMX_A_D5_P  GMX_A_D5_N
    GMX_A_D6_P  GMX_A_D6_N
    GMX_A_D7_P  GMX_A_D7_N
    GMX_A_D8_P  GMX_A_D8_N
    GMX_A_D9_P  GMX_A_D9_N
    GMX_A_D10_P GMX_A_D10_N
    GMX_A_D11_P GMX_A_D11_N
    GMX_A_D12_P GMX_A_D12_N
    GMX_A_D13_P GMX_A_D13_N
    GMX_A_D14_P GMX_A_D14_N
    GMX_A_D15_P GMX_A_D15_N
}]

# FPGA-side 100-ohm differential termination

set_property DIFF_TERM_ADV TERM_100 [get_ports {
    GMX_A_D0_P
    GMX_A_D1_P
    GMX_A_D2_P
    GMX_A_D3_P
    GMX_A_D4_P
    GMX_A_D5_P
    GMX_A_D6_P
    GMX_A_D7_P
    GMX_A_D8_P
    GMX_A_D9_P
    GMX_A_D10_P
    GMX_A_D11_P
    GMX_A_D12_P
    GMX_A_D13_P
    GMX_A_D14_P
    GMX_A_D15_P
}]

# ============================================================
# GMAX3412-A Sub-LVDS receive clocks
# ZU7EV Bank 28, VCCO verified = 1.8 V
# FH_Carrier schematic page 2 / J3:
#   GMX_A_CLK0_P -> F23 (IO_L13P_MRCC_28_67)
#   GMX_A_CLK0_N -> E23 (IO_L13N_MRCC_28_67)
#   GMX_A_CLK1_P -> F22 (IO_L11P_SRCC_28_67)
#   GMX_A_CLK1_N -> E22 (IO_L11N_SRCC_28_67)
# ============================================================

set_property PACKAGE_PIN F23 [get_ports GMX_A_CLK0_P]
set_property PACKAGE_PIN E23 [get_ports GMX_A_CLK0_N]
set_property PACKAGE_PIN F22 [get_ports GMX_A_CLK1_P]
set_property PACKAGE_PIN E22 [get_ports GMX_A_CLK1_N]

set_property IOSTANDARD SUB_LVDS [get_ports GMX_A_CLK0_P]
set_property IOSTANDARD SUB_LVDS [get_ports GMX_A_CLK0_N]
set_property IOSTANDARD SUB_LVDS [get_ports GMX_A_CLK1_P]
set_property IOSTANDARD SUB_LVDS [get_ports GMX_A_CLK1_N]

# UltraScale HP internal differential 100-ohm termination.
# Apply to P side of each differential input pair.
set_property DIFF_TERM_ADV TERM_100 [get_ports GMX_A_CLK0_P]
set_property DIFF_TERM_ADV TERM_100 [get_ports GMX_A_CLK1_P]

# 1.20 Gb/s DDR -> 600 MHz forwarded clock -> period 1.666667 ns.
# This operating point is used because the routed ZU7EV -2 ISERDESE3
# minimum-period check did not close at 640 MHz.

create_clock -period 1.666667 -name GMX_A_CLK0 [get_ports GMX_A_CLK0_P]
create_clock -period 1.666667 -name GMX_A_CLK1 [get_ports GMX_A_CLK1_P]

# The /4 (150 MHz) and /5 (120 MHz) receive clocks are generated by
# BUFGCE_DIV primitives in gmax3412_iob_clock.v. Vivado derives these clocks
# automatically from GMX_A_CLK0/1; do not redefine them here.

# ============================================================
# Post-synthesis clock-domain constraints
# ============================================================
# The asynchronous relationships involving PS clk_pl_0 and the post-synthesis
# PCIe monitor clock tree are intentionally NOT placed in this file.  During
# synthesis, the Block Design IP is still black-boxed and those clock objects do
# not exist yet.  They are constrained in FH_Carrier_Bringup_impl.xdc, which
# must be added to constrs_1 with USED_IN_SYNTHESIS=false,
# USED_IN_IMPLEMENTATION=true, and PROCESSING_ORDER=LATE.
#
# Vivado automatically derives the following GMAX BUFGCE_DIV clocks after the
# primitives are elaborated:
#   clk_rxio0_d4      = GMX_A_CLK0 / 4 = 150 MHz
#   clk_rxio1_d4      = GMX_A_CLK1 / 4 = 150 MHz
#   /5 clock at BUFGCE_RXG_DIV5_inst/O = GMX_A_CLK0 / 5 = 120 MHz
#   Its auto-derived net name can change (currently u_training_n_1).
# Do not redefine those clocks here.

# The 16 Sub-LVDS data lanes are dynamically centered by the receiver's
# IDELAYE3 training sweep. Consequently their static port-to-ISERDES paths are
# intentionally excluded from ordinary input-delay timing. Link margin is
# validated by the hardware training result on every lane.
set_false_path -from [get_ports {
    GMX_A_D0_P  GMX_A_D0_N  GMX_A_D1_P  GMX_A_D1_N
    GMX_A_D2_P  GMX_A_D2_N  GMX_A_D3_P  GMX_A_D3_N
    GMX_A_D4_P  GMX_A_D4_N  GMX_A_D5_P  GMX_A_D5_N
    GMX_A_D6_P  GMX_A_D6_N  GMX_A_D7_P  GMX_A_D7_N
    GMX_A_D8_P  GMX_A_D8_N  GMX_A_D9_P  GMX_A_D9_N
    GMX_A_D10_P GMX_A_D10_N GMX_A_D11_P GMX_A_D11_N
    GMX_A_D12_P GMX_A_D12_N GMX_A_D13_P GMX_A_D13_N
    GMX_A_D14_P GMX_A_D14_N GMX_A_D15_P GMX_A_D15_N
}]

# Low-speed camera/PAC interfaces are protocol-driven or software-bit-banged,
# not synchronous board-level buses relative to a PL clock. Mark their external
# I/O timing as asynchronous rather than leaving misleading missing-delay checks.
set_false_path -from [get_ports {
    GMX_A_SDO_TDIG GMX_A_I2C_SCL GMX_A_I2C_SDA
    PAC1944_I2C_scl_io PAC1944_I2C_sda_io
}]
set_false_path -to [get_ports {
    GMX_A_PWR_EN GMX_A_CLK_EN GMX_A_SYS_RST_N GMX_A_CCI_EN
    GMX_A_XCE_SLAMODE GMX_A_TEXP1 GMX_A_TEXP2 GMX_A_SPI_SCK GMX_A_SPI_SDI
    GMX_A_I2C_SCL GMX_A_I2C_SDA
    PAC1944_I2C_scl_io PAC1944_I2C_sda_io
}]

# NOTE: The obsolete u_gmax_clk_probe ILA constraints remain removed.
# The 16-lane receiver exposes training_result/training_done for debug.
