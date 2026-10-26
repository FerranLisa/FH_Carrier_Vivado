# FH Carrier bring-up: v24 hardware tests passed

Vivado/Vitis 2025.2 project for the Puzhi ZU7EV carrier and GMAX3412 emulator.
The separate 4 GiB PL DDR4 bank retains 4-170 full 4096 x 3072 frames in a rolling
buffer. Maximum-capacity capture, wraparound, continuous capture/stop and the
existing PS-DDR capture path passed hardware functional tests.

See `exports/gmax3412_pl_ddr/README.md` and `VALIDATION.md` for the design,
constraints, known limitations and test results. Raw board output is preserved
in `audit/pl_ddr4/v24_hardware_tests.txt`. Hardware hashes identify the tested
deliverables; generated binaries themselves are excluded from Git.

## Version-control contents

Keep the XPR, BD/XCI configurations, RTL, imported receiver RTL, XDC constraints,
custom IP metadata, testbenches, software sources and linker scripts, build and
validation scripts, documentation, vendor pinout evidence and address baseline.
Source handoffs under `exports/*/software` remain because existing preparation
and source-generation scripts reference them.

`.gitignore` excludes generated BIT/XSA/LTX/DCP/ELF outputs, object files, reports,
logs, Vivado caches/runs, old output archives and temporary review/download files.
Ignoring or removing a file from the Git index does not delete its local copy.

## Rebuilding

Open `FH_Carrier_Bringup.xpr` with Vivado 2025.2 or run
`scripts/run_pl_ddr_build.ps1` from PowerShell. The batch script generates the
block-design products, inserts debug probes, implements and validates the design,
then exports hardware into `exports/gmax3412_pl_ddr`. An optional incremental
checkpoint is local-only; a clone builds without it.

The application build uses `scripts/build_bringup_v24.ps1` and a compatible
standalone BSP in the Vitis workspace (default `C:\Projects\VITIS\FH_Carrier_Bringup`).
After generating the hardware, `scripts/prepare_vitis_v24.ps1 -ValidateOnly`
checks prerequisites; run without that switch to update the existing Vitis
workspace. These scripts require the installed AMD tools and the BSP; this is
not a standalone host-only software build.

The intended release tag is `v24-hardware-tests-passed` (Git tags cannot contain
spaces), with commit and annotated-tag message `v24 hardware tests passed`.
`scripts/commit_v24_hardware_tests.ps1` stages the curated worktree, untracks
ignored generated files without deleting them, commits and tags locally.
The Vivado remote is `FH_Carrier_Vivado`; `origin` points to a different Vitis
repository. The script commits/tags locally by default; add `-Push` to publish
the current branch and this tag atomically to `FH_Carrier_Vivado`. Use `-Preview`
to inspect the selection without changing the index or repository. A failed
push can be retried with `-Push` when the tag still points to HEAD and the
worktree is clean. Existing tags are never overwritten; no force push is used.

## Viewing the hardware-tested results in Vivado

The validated v24 build was executed in-process, outside the GUI run manager.
`scripts/sync_v24_gui_results.ps1` restores its exact synthesis/routed DCPs,
BIT and LTX into `synth_1`/`impl_1`, regenerates GUI report databases, and
registers those completed batch results. Close Vivado before running it.
The script preserves previous run files under `results/gui_run_backup_*`, checks
artifact hashes and timing, and verifies both runs with `open_run` after reopening
the project. It does not perform a new synthesis/implementation or change the
tested bitstream. Run descriptions explicitly identify restored batch results.

Open `FH_Carrier_Bringup.xpr`, then use **Open Synthesized Design** or **Open
Implemented Design**. The native report files are under the run directories.
Only the final synthesis/routed checkpoints were saved by the batch flow;
intermediate opt/place checkpoints are not available. For a new implementation,
reset and rebuild the runs rather than resuming an intermediate stage.

These generated results remain local and ignored by Git. A fresh clone must
rebuild them or obtain the matching validated export checkpoints before syncing.
