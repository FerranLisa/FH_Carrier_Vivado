# v23 validation — 25 October 2026

Implementation and export completed successfully with Vivado 2025.2.

| Check | Result |
|---|---|
| Scheduler control regression | PASS: minimum/maximum capacity, invalid bounds, 119 frame addresses, high-DDR transition, split AXI handshakes, DMA/capture/bus errors, timeout, graceful stop and recovery |
| Live capture RTL regression | PASS: four complete 4096 × 3072 frames; every streamed pixel checked with AXIS backpressure; real pattern/checker/capture FIFO RTL |
| A53 application build | PASS: `-Wall -Wextra -Werror`, existing compatible standalone BSP |
| ELF placement/MMU check | PASS: all application load segments below 256 MiB; both required high-DDR blocks identity-mapped and cacheable |
| Capacity arithmetic | PASS: 4–119 guarded frames; maximum 2,994,748,288 bytes |
| Synthesis, optimization, placement | PASS: zero errors and zero critical warnings |
| Routed setup / hold / pulse-width slack | +0.267 / +0.011 / +0.067 ns; zero failing endpoints |
| Routing errors / bus-skew violations | Zero / zero |
| Methodology | 34 existing findings; no critical methodology warnings |
| Receiver CDC | Existing 48 critical findings unchanged; receiver/pin timing remains outside emulator sign-off |
| XSA/BIT integrity | PASS: embedded BIT SHA-256 equals delivered BIT |
| Hardware handoff | PASS: scheduler at A0060000; emulator/capture/DMA addresses preserved; 64-bit DMA and high-DDR mapping present; XSCT HSI validation passed |
| PS/FSBL consistency | PASS: new handoff PS initialization matches current platform; local FSBL initialization matches generated source |
| Vitis preparation preflight | PASS: `prepare_vitis_v23.ps1 -ValidateOnly` |
| Source baseline | PASS: installed Vitis C source exactly matches the v22 source used to generate v23 |

The existing Vitis workspace was not modified: it is outside this session's
writable directories. The prepared update script backs up and updates that
workspace, regenerates its platform/BSP from the new XSA, installs the reserved
linker script, rebuilds the application and checks the resulting ELF.

Board testing is pending. Run menu 9, then B with capacities 4, 75 and 119,
then D to check low-address capture after high-DDR use. This is autonomous
finite-burst capture with hardware rearm gaps, not gapless circular streaming.

Evidence: `results/scheduler_test.log`, `results/scheduler_live_test.log`,
`results/scheduler_build_export.log`, the routed reports in this directory,
`BUILD_COMPLETE.txt`, `SHA256.json`, and `software/SHA256.json`.
