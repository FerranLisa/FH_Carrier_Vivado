FH_Carrier_Bringup V16.3 — corrected constraint/rebuild package

Start with VALIDATION_RESULTS.txt, CHANGELOG_V16_3.txt and REBUILD_STEPS.txt.
AUDIT_REPORT.txt contains the root-cause evidence and CDC limitations.

Open FH_Carrier_Bringup.xpr with Vivado 2025.2 after extracting to a short path.
The active receiver RTL, firmware, BD and IP sources are preserved.
Use REBUILD_V16_3.tcl for a clean top-level synthesis/implementation rebuild.

Fresh results are under results/20261003_202301/. This directory's name marks
the start of the rebuild; the reports contain their actual generation times.
The final routed DCP and timing.rpx belong to the same completed implementation.

audit/ contains the original source/checkpoint analysis and hash manifests.
audit/baseline/ contains the original checkpoints and stale reports.
audit/baseline/legacy_root_files/ contains historical helpers and hardware
exports for reference only. They are not current rebuild results; some helper
scripts assume old paths or old constraints. Do not run them on this revision.

No bitstream was programmed and no fresh XSA is supplied as hardware-validated.
Follow the explicit BIT/LTX/XSA steps after reviewing the reports and repeat
the established hardware bring-up regression before replacing a known-good image.
