# v24 PL DDR4 AXI reset correction

Hardware feedback: source smoke test passes, DDR calibration reports complete,
four MMU updates return, first CPU store at 0x1000000000 stalls. Vitis cannot
pause the CPU.

Confirmed generated-design defect: pl_ddr_reset has C_EXT_RESET_HIGH=1 and
C_AUX_RESET_HIGH=0, but aux_reset_in was connected to gmax_emu_zero/dout.
Consequently its peripheral_aresetn output holds the MIG AXI interface in reset.
PHY calibration is independent of that AXI reset.

Correction: keep the generated active-low auxiliary polarity and connect the
input to a dedicated one-bit constant one, pl_ddr_reset_inactive. Preserve
active-high ui_clk_sync_rst and calibration-driven dcm_locked.

The build applies fix_pl_ddr_reset_polarity.tcl before BD validation, then
checks propagated polarity. Layout and export validation reject the old
configuration. The proc_sys_reset IP regression compares original tied-low
and corrected tied-high inputs, including calibration loss and UI reset.

Old BIT/XSA and generated reset HDL are archived in pre_aux_reset_fix and are
not suitable for PL DDR tests. Corrected full synthesis/implementation/export
was started with run_pl_ddr_build.ps1. Check results/pl_ddr_build_exit.txt and
the final BUILD_AND_EXPORT_PASS before installing; hardware confirmation is
still required. Source checkpoint changes remain compatible.

Recovery on October 25: full corrected implementation and bitgen passed with
WNS +0.228 ns / WHS +0.010 ns. The batch exit 1 was solely a project-mode XSA
export lookup failure. The exact new BIT is now staged in impl_1 for native
Vivado export; finish_gmax3412_pl_ddr_export.tcl completes the handoff without
rerouting. Export checks verify the actual auxiliary connection, not merely
the presence of a constant. CONST_VAL is serialized as 0x1 and checked
numerically. Vitis preflight and checkpoint-enabled ELF verification pass.
Use results/pl_ddr_finish_export.log and exports/gmax3412_pl_ddr/SHA256.json
for the recovered export result. Corrected hardware qualification is pending.
