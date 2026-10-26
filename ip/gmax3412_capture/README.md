# GMAX3412 DDR capture milestone

`gmax3412_capture` accepts either of two 192-bit, 16-slot image sources,
crosses each source into the 120 MHz capture clock using an XPM asynchronous
FIFO, and emits one AXI Stream packet per requested frame. Each 12-bit slot is
zero-extended to a little-endian 16-bit pixel; the 10-bit emulator therefore
produces values 0..1023. The lowest source slot is the first pixel in memory.
The stream is 128 bits wide: lower eight pixels followed by upper eight.
TLAST marks the final eight pixels of a complete 4096 x 3072 frame.

## Integrated path

Emulator / receiver -> selectable capture bridge -> AXI DMA S2MM ->
SmartConnect -> PS S_AXI_HP0_FPD -> DDR. The DMA is simple mode, 128-bit,
32-bit addresses, with a 26-bit buffer-length register. A frame is 25,165,824
bytes (24 MiB). HP0 is non-coherent; software performs cache maintenance.
The existing receiver ILAs and emulator checker remain present.

The physical receiver's `frame_valid` and `line_valid` are currently tied low
in `gmax3412_rx_adapter`. Its source port is connected but physical image
capture is **not available** until receiver frame synchronization is implemented.
The bridge's two input paths are exercised with synthetic framed data in simulation.

## Bandwidth and buffering

Each source FIFO holds 1024 groups of 16 pixels (32 KiB image payload).
The 128-bit/120 MHz sink has a theoretical ceiling of 1.92 GB/s before DDR
stalls. The source bursts at 16 pixels/clock (3.84 GB/s in the stored format).
Line blanking must lower average traffic and the FIFO absorbs burst differences.
The DDR test uses 1024, 2048 and 512 blank clocks; it is **not a maximum-rate
or sustained-throughput certification**. The original 16-clock blanking does
not fit this capture bandwidth. Overflow is sticky and invalidates a capture;
software must reset the bridge and DMA before retrying. DDR contention can
still cause overflow. The on-chip checker test (option 9) remains independent.

## Address map and protocol

| Base | Peripheral |
|---|---|
| 0xA0030000 | Existing emulator AXI registers |
| 0xA0040000 | Dual AXI GPIO capture control/status |
| 0xA0050000 | AXI DMA; S2MM control/status at +0x30/+0x34 |

GPIO channel 1 DATA (+0) is control. Channel 2 DATA (+8) is read-only status.
Fixed GPIO directions are configured in hardware.

| Control bits | Meaning |
|---|---|
| 0 | Enable one capture; hold high until complete |
| 1 | Source: 0 emulator, 1 physical receiver; latched when enabled |
| 2 | Abort/flush; clear enable and hold this bit for at least 100 us |
| 7:4 | Diagnostic bank selector, independent of source selection |

Changing the source while enabled does not switch a live stream. Clear enable
and wait at least 100 us between captures so the source-domain request and FIFO
reset settle. After enabling, poll READY before triggering the source. Arming
mid-frame waits for the next frame boundary. Only the first frame is captured.
After aborting a stalled stream, reset DMA too; abort is not packet completion.
An inactive physical source clock does not block emulator capture.

| Bank | Status value |
|---|---|
| 0 | bit 0 READY, 1 enabled, 2 packet accepted by DMA stream, 3 overflow, 4 geometry error, 5 extra frame observed, 6 source frame ended, 7 selected source |
| 1 | ID 0x3412CA01 |
| 2 | Bytes accepted by stream sink this capture |
| 3 | Cumulative packets accepted by stream sink |
| 4 | Cumulative captures reporting overflow |
| 5 | Cumulative captures reporting geometry error |
| 6 | Cumulative capture sessions observing extra dropped frames (one count per session, not per extra frame) |
| 7 | Frame bytes: 25165824 |
| 8 | Available source mask: bit 0 emulator; physical bit 1 currently zero |

Counters wrap modulo 2^32 and reset with the peripheral reset. Per-capture
flags clear when the source request resets. Stream completion alone does not
prove DDR writes are complete: require DMA IOC and IDLE, source-ended, no
capture/DMA errors, and the expected byte count before inspecting memory.

## Bring-up software

Use `exports/gmax3412_capture/software/BringupTest_v19.c` as the application's
`BringupTest.c`. Rebuild the Vitis platform/BSP from the **capture** XSA and use
its PS initialization/FSBL, since HP0 is newly enabled. Program the matching
capture BIT and use option **D**. Option 9 retains the original checker test.

D allocates an aligned static 24 MiB DDR buffer plus guard regions, resets
DMA, arms capture before each trigger, and captures three frames with varied
seed, exposure and blanking. It checks every 16-bit pixel, zero padding, guard
regions, checksum, byte counts, source trigger counters and source checker.
It leaves DMA reset and acquisition disarmed and restores emulator settings.
The linker must place this buffer in low DDR (below 2 GiB for this HP0 map),
with enough space for the application/stack/heap; no hard-coded DDR buffer
address is used. This is a standalone test, not a Linux DMA driver.

## Reproduce

1. Vivado batch: `scripts/package_gmax3412_capture.tcl`.
2. One-time integration: `scripts/integrate_gmax3412_capture.tcl`.
3. Simulation: `scripts/test_gmax3412_capture.tcl` (require CAPTURE_TEST_PASS).
4. Full build: `scripts/build_gmax3412_capture_export.tcl`.
5. PowerShell: `scripts/verify_gmax3412_capture_export.ps1`.
6. Vitis XSCT: `scripts/validate_gmax3412_capture_xsa.tcl`.

Exports use `exports/gmax3412_capture/`, preserving the first milestone.
The export finalizer explicitly binds the new BIT into the XSA and verifies
SHA-256, avoiding Vivado's stale normal-run bitstream selection.
Board DDR capture is not claimed until option D is run on hardware.

## Verified 24 October 2026

- XSim: three full 4096 x 3072 captures across both source inputs; every pixel,
  16-bit packing and TLAST checked under backpressure. Overflow, recovery,
  active-source selection locking and short-frame geometry checks passed.
- BringupTest_v19: compiled with the installed A53 standalone BSP using
  `-Wall -Wextra -Werror`; no compiler diagnostics.
- Full-project synthesis: zero errors or critical warnings.
- Routed timing: setup +0.266 ns, hold +0.010 ns, pulse width +0.067 ns.
- Legacy PS/receiver clock-group exception narrowed to preserve the capture
  FIFO's XPM max-delay constraints. TIMING-24 warnings removed; no critical
  methodology violations and no bus-skew violations. Receiver endpoint checks pass.
- Existing receiver CDC findings remain; this is a diagnostic build, not a
  complete physical-receiver CDC sign-off.
- Final XSA: embedded BIT SHA-256 matches the delivered BIT. Vitis HSI opens
  the handoff, finds the capture IP and DMA, and verifies A53 addresses
  0xA0030000, 0xA0040000 and 0xA0050000 (XSA_HSI_VALIDATION_PASS).

Evidence: `results/capture_test_final.log`,
`results/capture_build_export.log`,
`results/capture_constraints_export_verified.log`, and reports in
`exports/gmax3412_capture/`.
