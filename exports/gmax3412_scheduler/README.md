# GMAX3412 v23: autonomous retained-frame burst

This milestone adds a hardware AXI-Lite control master that arms DMA, rearms
the capture bridge, sets the image seed and triggers each frame. The CPU starts
one burst and polls its result. It does not rearm DMA or issue per-frame triggers.
The existing emulator, capture bridge, checker, timing monitor and legacy tests
remain in use. This is a finite burst with hardware rearm gaps, not gapless
streaming or AXI DMA scatter/gather mode.

## Configurable capacity

Capacity is configured at runtime in **whole stored frames, from 4 through 119**.
3 GB is interpreted as **3,000,000,000 bytes**. Each image has 4096 × 3072
pixels stored as little-endian 16-bit values containing the 10-bit pixel.

| Item | Bytes |
|---|---:|
| Frame payload | 25,165,824 |
| Guards per frame | 128 |
| Stored frame stride | 25,165,952 |
| Minimum: 4 frames | 100,663,808 |
| Maximum: 119 frames | 2,994,748,288 |

Both software and hardware reject capacities outside this range. The firmware
does not allocate a multi-gigabyte static array or assume contiguous DDR across
the PS address hole. Slot addresses are fixed by the hardware storage contract:

- Slots 0–73: `0x10000000 + slot * 25165952`.
- Slots 74–118: `0x800000000 + (slot - 74) * 25165952`.
- DMA destination is slot base + 64, leaving one guard cache line on each side.

The matching linker script limits all application allocations to the first
256 MiB and makes high DDR unavailable to ordinary linker allocations. The
existing standalone BSP maps both high-DDR GiB blocks as normal cacheable
memory. DMA addressing is widened to 64 bits and the high-DDR aperture is
explicitly included in the DMA address map. DDR/PS initialization is unchanged.

All slots remain retained when the burst finishes. There is no wraparound or
overwrite-on-full policy. Starting a new B test deliberately replaces the
previous burst. The CPU poisons and flushes each slot before capture, then
invalidates and verifies every pixel, both guards and the checksum afterward.
Only the scheduler owns capture/DMA/emulator controls during the burst.

## Hardware test preparation

Use the new Scheduler BIT/XSA together with BringupTest_v23.c and lscript_v23.ld.
Renaming the C source alone is insufficient for this revision.

Run from PowerShell, with the Vitis workspace idle:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Projects\VIVADO\FH_Carrier_Bringup_Linux\scripts\prepare_vitis_v23.ps1
```

The script checks the export and PS/FSBL initialization, creates backups,
installs the C source and reserved-memory linker script, updates the platform
from the new XSA, rebuilds the platform and application, checks regenerated
DMA/scheduler definitions and the final ELF, and selects the new BIT in the
existing launch configuration. It does not program the board.

Start a fresh hardware debug launch. Suggested sequence:

1. `9`: existing on-chip smoke test.
2. `B`, then `4`: minimum-capacity autonomous burst and full verification.
3. `B`, then `75`: exercises the transition into high DDR.
4. `B`, then `119`: maximum permitted allocation.
5. `D`: checks legacy low-DDR capture after high-address DMA use.

`B` prompts for a decimal capacity; Enter selects 4 and ESC cancels. Invalid
capacity input is rejected before touching buffer storage. Large tests take
time to initialize and verify all pixels; progress is printed. Acquisition
itself is separate from CPU verification. B uses exposure 120000 and blanking
1024 cycles as a conservative initial hardware-test profile. The scheduler
uses the emulator's programmed exposure/blanking registers; other software can
set those before starting a burst.
Software must initialize and arm the emulator before submitting scheduler START;
the B test performs these steps. Do not run another capture owner concurrently.

On a scheduler/bus timeout the application requests graceful stop and retains
ownership until the scheduler is idle. If the bus never responds, it waits
instead of allowing another test to reuse an active DMA; reset/relaunch then.

## Scheduler control interface

AXI GPIO at `0xA0060000`: output/command at +0, input/status at +8.
Change bit 31 to submit a command; changing only the status bank does not submit
another command. Bits 30:28 select opcode, bits 15:8 carry capacity, bits 3:0
select the diagnostic bank. Configuration/start commands are ignored while busy.

| Opcode | Meaning |
|---|---|
| 1 | Configure 4–119 frames while idle; valid configuration clears prior error |
| 2 | Start a new burst from slot zero, if idle and no configuration error |
| 3 | Graceful stop after the current frame |

| Bank | Value |
|---|---|
| 0 | ID `0x34125301` |
| 1 | bit 0 busy, bit 1 complete, bit 2 error, bit 3 stopped; state in bits 15:8 |
| 2 | Configured capacity |
| 3 | Successfully completed frames |
| 4 | Error code: 1 capacity, 2 AXI response, 3 timeout, 4 DMA, 5 capture, 6 checker, 7 state |
| 5 | 32-bit wrapping scheduler cycles at 120 MHz, including rearm and cleanup |
| 6 / 7 | Last DMA / capture status |
| 8 / 9 | Maximum capacity / guarded frame stride |
| 10 / 11 | Current DMA destination low / high word |

Frame seed is `(7 + 37 * zero_based_slot) & 1023`. The scheduler waits for DMA
completion, source completion and checker success before advancing. It waits
12000 cycles with the bridge disabled between frames, matching the previously
qualified 100 us software reset interval. Normal completion and failure cleanup
disable the bridge, disarm the source and reset DMA before releasing ownership.
AXI requests are never withdrawn while stalled.
The scheduler has a two-second per-frame polling watchdog; exposure plus readout
and DMA completion must fit within that interval. B's fixed test profile uses a
15-second overall software timeout for the burst.

## Validation and limits

Control regression covers 4 and 119 frames, invalid capacity, the high-DDR
transition, independently stalled AXI channels, DMA/capture/AXI errors, timeout,
graceful stop and recovery. The live simulation uses the real pattern generator,
checker and capture bridge plus a modeled DMA sink with AXIS backpressure;
it checks every pixel in four full-size frames. It does not model PS DDR physics
or the internal implementation of the vendor DMA.

The ELF verifier checks actual load segments and high-DDR MMU descriptors.
The export verifier checks the embedded BIT hash and 64-bit DMA/scheduler
handoff. Hardware qualification of v23 is pending the board tests above.
Pin electrical timing and sustained circular/gapless streaming remain outside
this milestone. The routed reports retain the existing 48 critical receiver CDC
findings (2 CDC-1, 12 CDC-10, 16 CDC-11, 18 CDC-13), with no new critical
methodology warnings. See BUILD_COMPLETE.txt and timing.rpt for the completed build's
timing results; see the simulation logs under results for test outcomes.
