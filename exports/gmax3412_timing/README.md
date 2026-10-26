# GMAX3412 timing monitor and repeated-capture qualification

This revision adds passive source-clock measurements inside gmax3412_emulator.
The capture bridge, DMA, DDR mapping and PS configuration are unchanged.
Previous known-good capture artifacts remain in exports/gmax3412_capture.

## Hardware timing registers

AXI base remains 0xA0030000. All values below are read-only, 32-bit.

| Offset | Meaning |
|---|---|
| 0x40 | Timing monitor capability ID: 0x544D0001 |
| 0x44 | Completed timing snapshot sequence number |
| 0x48 | Measured CMOS_TEXP1 high duration |
| 0x4C / 0x50 | Minimum / maximum LVAL high duration across the frame |
| 0x54 / 0x58 | Minimum / maximum inter-line LVAL low duration |
| 0x5C | FVAL high duration |
| 0x60 | Number of completed lines |

Durations are in 120 MHz source-clock cycles. The monitor observes source
signals, not configuration values. It commits all measurements together at the
falling edge of FVAL and holds the snapshot until the next complete frame.
Read sequence before and after a multi-register read to detect replacement.
Reset clears snapshots and sequence. Counters use modulo-2^32 arithmetic;
measured intervals must remain shorter than 2^32 source clocks. INIT does not
clear the timing monitor. This measures internal digital signals, not electrical
delays at external pins, and does not independently measure clock frequency.

For this source, expect exposure=configured exposure, LVAL high=256 cycles,
inter-line low=configured blanking, lines=3072, and
FVAL high=3072*256+3071*blanking cycles. Exposure and FVAL do not overlap.

## Software and board test

BringupTest_v21.c adds **Q** to the main menu; 9, D and T remain available.
Q requires the new Timing BIT. Do not run Q against the older capture BIT:
its AXI decoder does not implement the new register range.

Q verifies 337 complete images:

1. One-cycle and 100 ms exposure cases at blanking 512.
2. 32 frames at blanking 512.
3. 100 frames each at blanking 320, 288 and 256.
4. Forced overflow and disarmed/busy trigger rejection.
5. Three recovery frames at blanking 512.

Every successful frame must pass pixel, padding, guard, checksum, byte-count,
source-checker, trigger-count and exact hardware-timing comparisons. The monitor
sequence must advance exactly once. Progress prints every ten frames and at the
end of each phase. This can take several minutes with the unoptimized debug build.

Each image is verified before the next trigger. This qualifies repeated one-shot
capture, not uninterrupted or gapless streaming. A failure at 256 is a qualification
failure, not an expected boundary event. Use the existing T sweep for boundary
exploration. Long-run DDR buffering/continuous streaming remains a separate task.

## Prepare Vitis

Stop debugging and save/close the source editor. Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Projects\VIVADO\FH_Carrier_Bringup_Linux\scripts\prepare_vitis_v21.ps1
```

The script verifies the new BIT/XSA pairing and compares PS initialization files
against the installed platform. If identical, the existing tested platform/BSP
can be reused. It also checks the capture addresses and FSBL initialization
source. It backs up source and launch configuration, installs v21, selects the
Timing BIT, enables reset/programming, and rebuilds the application with the
toolchain PATH required by Ninja's post-link size command. It does not program
or run the board. -ValidateOnly performs preflight without modifying Vitis files.

Launch FH_Carrier_Test_app_hw_1, then choose Q. Supply the complete output.
The assistant session cannot write to the Vitis project directory; installation
must be run from your PowerShell unless workspace write access is expanded.

The Timing XSA is also supplied for platform archival or regeneration. If the
preflight detects a PS initialization mismatch, update the platform and rebuild
its FSBL from this XSA before proceeding; do not bypass the check.

## Verification

- Full-size monitor simulation: exposure 1/120000/1200000 cycles, blanking
  1/256/512, all 3072 lines, snapshot hold and reset.
- Emulator AXI regression: snapshot register values and response stalls,
  changed settings, full images, rejected triggers, reset and pixel corruption.
- v21 compiled and linked against the installed standalone BSP and linker
  script with -Wall -Wextra -Werror.
- Routed setup slack +0.267 ns, hold slack +0.010 ns, pulse-width slack
  +0.067 ns. No critical methodology findings or TIMING-24 warnings.
  Existing receiver CDC critical counts remain 2/12/16/18 (48 total), unchanged.
- FPGA implementation/export results are recorded in BUILD_COMPLETE.txt and
  the accompanying timing, methodology, CDC and bus-skew reports when complete.
- BIT generation and XSA export completed. The XSA's embedded BIT matches the
  delivered BIT by SHA-256. Final routed netlist contains 610 timing-monitor
  registers and no unresolved black boxes.
- Vitis preparation preflight passed against the installed project: its PS
  initialization C/header/Tcl files inside the XSA match the new handoff exactly,
  and its capture BSP and FSBL source checks pass. No platform regeneration is
  needed for this revision. The Vitis project itself remains unchanged until
  the preparation script is run without -ValidateOnly.

No Q hardware results are claimed yet. Physical receiver framing and existing
receiver CDC findings remain outside this milestone.
