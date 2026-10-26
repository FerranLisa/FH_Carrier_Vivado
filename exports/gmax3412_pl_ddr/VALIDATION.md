# v24 validation record

## Hardware-discovered reset defect - corrected export validated

The initial v24 hardware run calibrated DDR but stalled on the first CPU access.
The generated DDR AXI reset controller had an active-low auxiliary reset tied
low, holding the AXI interface in reset. The input is now tied high. The
corrected implementation and recovered export pass. Do not use the old BIT.
See `audit/pl_ddr4/AXI_RESET_FIX.md` for evidence and
the vendor reset-IP regression. Hardware verification remains pending.

## Completed

- Reviewed uploaded Puzhi board manual, development guide and DDR project. Vendor DDR IP geometry, speed, clock and all pin assignments preserved; AXI interface enabled for this application.
- Vivado 2025.2 block-design validation and output generation: PASS (`results/pl_ddr_integrate.log`). PS and DMA share the 4 GiB PL aperture at 0x1000000000.
- Static layout checks: PASS (`scripts/verify_pl_ddr_layout.py`). Checks vendor pin map, MIG geometry, both address maps, every capacity 4–170, address bounds and wrap/retention arithmetic.
- RTL scheduler fault tests: PASS (`results/pl_ring_test.log`). Invalid capacities 3/171, start before calibration, 4-slot and 170-slot multi-wrap acquisitions, independently stalled AXI address/data channels, DMA/capture/AXI errors, timeout, calibration loss, graceful stop and recovery.
- Full image-path simulation: PASS (`results/pl_ring_live_test.log`). Actual emulator pattern/checker/capture RTL produces eleven full 4096×3072 images through a four-slot circular address schedule. Every 16-bit stream pixel, TKEEP, TLAST, source/checker counters and destination are checked, with 25% AXI-stream backpressure. The inherited PASS message says “four real frames”; executable assertions require eleven accepted/checked/streamed frames. The test description has since been corrected. This test uses a DMA sink/control model; it does not simulate the vendor DDR PHY or a physical DDR device.
- A53 application: PASS with `-Wall -Wextra -Werror`, existing compatible standalone BSP, and explicit PS memory reservation. ELF placement and v24 test presence checked. PL DDR MMU mappings are installed at runtime only after calibration.
- Preparation PowerShell syntax: PASS. Existing-platform update script prepared; Vitis workspace installation is performed by the user-run script.
- DCI startup-sequence simulation: PASS (`results/dci_test.log`). Checks a 64-clock reset pulse after startup, initially asserted LOCKED, delayed LOCKED, loss of lock, and external reset/restart. The sequence uses the independent 120 MHz clock and holds MIG in reset until DCI is ready.
- Corrected FPGA implementation: routed timing PASS, setup WNS +0.228 ns, hold WHS +0.010 ns, pulse-width slack +0.006 ns. All specified timing constraints met; zero unconstrained internal endpoints. All 169,933 routable nets routed, zero routing errors. No bus-skew violations, critical methodology findings, or DRC errors/critical findings. The 44 DCIRST-1 warnings in the first implementation are eliminated.
- CDC review: the same 48 critical receiver/debug findings remain. Of 48 detailed rows, 46 are identical to the first implementation; two report the other launch bit of the existing receiver debug-selection mux (bit 2 instead of bit 1), with the same destinations. No new critical PL-DDR or scheduler path was introduced. These existing receiver findings are not waived by this milestone.

## Export and Vitis preparation

- Corrected routed checkpoint, BIT, LTX and XSA: COMPLETE. The October 25 21:17 batch failed only at XSA export because project-mode export could not find the in-process BIT in impl_1. `finish_gmax3412_pl_ddr_export.tcl` stages the exact new BIT at that location and regenerates the native XSA; no synthesis or routing repeat is needed. See `results/pl_ddr_finish_export.log` for recovery status. The original exit-code file remains 1 as historical evidence.
- The XSA contains the exact delivered BIT; hashes are recorded in `SHA256.json`. Both PS/DMA 4 GiB apertures, MIG geometry, DCI startup, reset polarity, and actual auxiliary-reset connection to constant one are verified. The validator accepts Vivado's hexadecimal constant encoding (0x1). Timing, bus skew and route checks also pass.
- `prepare_vitis_v24.ps1 -ValidateOnly`: PASS after recovery. Current platform PS initialization (`psu_init.c`, `.h`, `.tcl`) matches the final XSA; local FSBL initialization matches its generated source. The checkpoint-enabled application ELF and both exported C filenames are verified.
- Full Vitis installation/build in `C:\Projects\VITIS\FH_Carrier_Bringup` was not run: that directory is outside this session's writable workspace. The prepared script updates the existing platform, application source, linker reservation and launch configuration, then rebuilds and checks them. The v24 application has already compiled and linked successfully against the compatible existing BSP into this export directory.

The initial build without DCIRESET is archived under `audit/pl_ddr4/pre_dci` and is not qualified for hardware use. The final export includes the correction. The debug-hub synthesis launch initially hit a Windows Script Host access error; its generated synthesis Tcl was run directly with the local bootstrap, completed successfully, and populated the cache. The corrected full build reused that cache successfully.

## Hardware functional qualification passed

The corrected BIT passes the planned board tests. The earlier first-store stall
is resolved. Test 9 and the four-slot qualification (11 captured, sequences 7-10
retained) passed in the console output supplied by the user. The subsequent
complete log is retained in `audit/pl_ddr4/v24_hardware_tests.txt`:

- 4 GiB address-bit probe passes, including the final word at 0x10FFFFFFF8.
- Maximum capacity: 343 captured, 170 retained, sequences 173-342. Every retained
  pixel, guard and checksum passes. Storage is 4,278,211,840 bytes including guards.
- Continuous acquisition and stop: 614 captured, four retained, sequences 610-613;
  all retained data passes.
- Subsequent PS-DDR test D: all three full frames pass.

This completes functional qualification of the emulator PL-DDR rolling buffer.
Gapless streaming and endurance qualification are separate milestones. The 48
pre-existing receiver critical CDC findings remain outside this milestone.
