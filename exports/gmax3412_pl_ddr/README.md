# GMAX3412 v24 — PL DDR4 rolling buffer

The PL DDR4 bank is separate from the PS DDR used by v23. Capacity is configurable in whole frames, minimum 4 and maximum 170. Existing PS-DDR tests remain available.

The final BIT/LTX/XSA export and Vitis preparation preflight passed. Routed setup/hold margins are +0.228/+0.010 ns. Hardware functional tests passed at 170 retained frames, in continuous mode with graceful stop, and for the existing PS-DDR capture path; see `VALIDATION.md` for the complete validation record.

## Memory layout

| Item | Value |
|---|---:|
| Physical PL DDR4 capacity | 4,294,967,296 bytes (4 GiB) |
| Pixel format | 4096 × 3072, 10-bit values in little-endian 16-bit words |
| Frame payload | 25,165,824 bytes |
| Guards | 64 bytes before and 64 bytes after each frame |
| Slot stride | 25,165,952 bytes |
| Maximum stored frames | 170 |
| Maximum storage including guards | 4,278,211,840 bytes |
| Remaining bank space | 16,755,456 bytes |
| PS/DMA-visible bank | 0x1000000000–0x10FFFFFFFF |
| New scheduler GPIO | 0xA0070000 |

Frame sequence `s` uses slot `s % capacity`; seed is `(7 + 37*s) & 1023`. After stopping, the retained range is `completed - min(completed, capacity)` through `completed - 1`. Oldest slots are deliberately overwritten after the ring fills. Software must stop acquisition and wait for ownership release before reading frames. Failed acquisition does not certify retained data, since the current slot may contain a partial overwrite.

The scheduler autonomously rearms the existing simple-mode AXI DMA and triggers each frame. This provides continuous rolling acquisition with small hardware rearm gaps, not gapless sensor streaming. Sequence count is 32 bits; hardware stops before it wraps. The cycle counter wraps modulo 2^32.

The pixel pattern repeats every 1024 frame sequences. The default two-wrap qualification captures at most 343 frames, within that period. In longer continuous runs, sequences 1024 apart have identical pixel patterns.

## Hardware basis

Sources supplied by the user:

- PZ-ZU7EV-KFB Board User Manual, §3.4: 200 MHz PL reference on AH12/AJ12; §3.13, pages 16–19: four 1 GB PL DDR4 devices and pinout.
- PZ-ZU7EV FPGA Development Guide, DDR example chapter, approximately pages 73–89: native controller example and pin constraints.
- `8_PZ_ZCU_DDR.zip`: `DDR_TOP.v`, `ddr.xdc`, and the configuration within `ddr4_0.xcix`. Extracted readable evidence is in `audit/pl_ddr4`.

The original example selects MT40A512M16LY-075, 64 data bits, DM without DBI, 833 ps memory period, 4998 ps reference period, CL17/CWL12. v24 retains these vendor settings and uses the controller's AXI interface (512-bit data, 32-bit local byte addresses, narrow transfers enabled). The reference is nominally 200 MHz; the vendor's 4998 ps setting is retained. The example's short 1000-count native traffic generator is not a full-capacity memory test and is not reused as the capture engine.

The vendor traffic generator also declares its address counter as 28 bits while connecting it to a 29-bit native address port. It therefore cannot exercise the complete native address range. v24 uses the full 32-bit AXI byte address range, and its software alias probe explicitly checks the highest address bit and the last word of the bank.

Capture DMA and A53 access the same PL bank through SmartConnect with clock-domain conversion to the DDR UI clock. The scheduler synchronizes calibration completion and refuses to start before calibration. Software waits for calibration before any CPU memory access, sets four 1 GiB MMU blocks to normal write-back memory, and explicitly maintains caches around noncoherent DMA.

Bank 65 uses multi-function DCI pins. The added `pl_ddr_dci_reset` startup sequencer follows [AMD AR 000038677](https://adaptivesupport.amd.com/s/article/000038677) and UG571: after reset release it waits 32 independent 120 MHz clocks, pulses DCIRESET for 64 clocks (533 ns), and waits for synchronized LOCKED before releasing the DDR controller reset. Loss of LOCKED reasserts controller reset. Each PL reset repeats the sequence. The DCIRST-1 warning is checked as a build failure, not waived.

## Prepare Vitis and test

Close Vitis before running the preparation script from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Projects\VIVADO\FH_Carrier_Bringup_Linux\scripts\prepare_vitis_v24.ps1
```

The script updates the existing platform from the v24 XSA, preserves the reserved PS linker layout used by B, installs BringupTest_v24.c as BringupTest.c, selects the v24 BIT, and rebuilds the platform/application. Backups go to the sibling `FH_Carrier_Bringup_backups` directory, outside the Vitis workspace. It does not program the board.

Start a fresh hardware launch. Run:

1. **9**: existing emulator smoke test.
2. **P**, capacity **4**, default mode **0**: capture 11 frames and verify the latest 4 after two wraps.
3. **P**, capacity **170**, default mode **0**: capture 343 frames and verify the latest 170, sequences 173–342, in chronological order.
4. **P**, capacity **4**, mode **1**: continuous acquisition; ESC requests stop at a frame boundary, followed by verification.
5. **D**: confirm ordinary PS-DDR capture still works.

P performs an address-bit probe including the bank's final 64-bit word, poisons requested slots, writes guards, then captures. Preparation and exhaustive CPU verification take much longer than acquisition. Each retained frame is checked pixel by pixel, including guards and checksum. The address-bit probe is an aliasing check, not an exhaustive DDR electrical qualification.

Calibration, full-capacity retention and physical DDR timing still require board results. See VALIDATION.md for the actual build/test status.

## Scheduler interface

GPIO channel 1 at +0 accepts a command when bit31 toggles. Bits30:28 select opcode. For opcode 1, bits15:8 carry the 8-bit capacity and bits27:16 are reserved (write zero); for opcode 4, bits27:8 carry the 20-bit total-frame target. Bits3:0 select a diagnostic bank without toggling commands. Channel2 at +8 returns diagnostics.

Opcodes: 1 sets capacity (4–170) while idle and clears configuration/error status; 2 starts; 3 requests graceful stop; 4 sets a total-frame target (zero means continuous, otherwise 20-bit count). Configuration is immutable while running. Software must serialize use of the old and new schedulers, which share the capture/DMA path.

Banks: 0 ID=0x34125224; 1 status (busy bit0, successful completion bit1, error bit2, stopped bit3, state bits15:8); 2 capacity; 3 completed frames; 4 error; 5 cycle counter; 6 last DMA status; 7 last capture status; 8 maximum170; 9 slot stride; 10/11 destination low/high; 12 synchronized calibration; 13 retained count; 14 current slot; 15 total target. Current slot describes the last destination on stop, not necessarily the next slot.

Errors: 1 capacity, 2 AXI response, 3 polling timeout, 4 DMA, 5 capture, 6 source checker, 7 invalid state, 8 calibration lost. Outstanding AXI requests are never withdrawn; an unresponsive bus can require a hardware reset. Software does not reclaim shared DMA ownership before the scheduler becomes idle.
