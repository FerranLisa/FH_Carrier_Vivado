# v24 GUI result restoration - 2026-10-26

The successful v24 build used in-process synthesis and implementation. Its
results were restored to the project's existing `synth_1` and `impl_1` run
directories so the GUI shows the hardware-tested design. No RTL changes or
new synthesis, implementation or bitstream generation were performed.

Verified after closing and reopening `FH_Carrier_Bringup.xpr`:

| Run | Status | Progress | Needs refresh |
| --- | --- | --- | --- |
| synth_1 | synth_design Complete! | 100% | false |
| impl_1 | write_bitstream Complete! | 100% | false |

Both `open_run synth_1` and `open_run impl_1` succeed. The corrected DCIRESET
primitive is present. Native implementation summary statistics show
WNS 0.228034 ns and WHS 0.009506 ns (rounded report values +0.228/+0.010 ns).
GUI timing, utilization, route, DRC, methodology and bus-skew report databases
were regenerated from the original checkpoints.

The imported BIT SHA-256 matches the tested export exactly:
`AE2E906AB8C11808867C9EB47EB518D0AC9EFFD544B13AAD222CB26AF78B896E`.
The synthesis/routed DCP and LTX copies were also hash-checked. Previous GUI
run files were backed up under `results/gui_run_backup_*`. Failed old synthesis
messages were replaced with the successful stage logs from the original build;
the complete batch log, including the separately resolved XSA-export failure,
remains in `results/pl_ddr_build.log`.

Use `scripts/sync_v24_gui_results.ps1` to repeat the restoration with Vivado
closed. Run descriptions label the results as restored. Only final synthesis
and routed checkpoints are available; reset/rebuild for a new implementation
instead of resuming an intermediate step. Generated run data remains ignored
by Git and is not included in the source tag.

Evidence: `results/v24_gui_reports.log`, `results/v24_gui_register.log`
(`V24_GUI_RUNS_PASS`) and `results/v24_gui_final.log` (`GUI_FINAL` rows).
