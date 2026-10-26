# v22: pipelined DDR buffer ring

Uses the existing hardware-qualified Timing BIT/XSA from exports/gmax3412_timing.
No RTL, FPGA rebuild, PS initialization change or platform regeneration is needed.
BringupTest_v22.c adds **S** to the main menu. Options 9, D, T and Q are preserved.

## Acquisition behavior

Four 24 MiB slots use explicit FREE -> DMA -> READY -> VERIFY -> FREE ownership.
The producer starts the next frame without waiting for the preceding image to be
verified. The CPU verifies a completed slot in 4096-pixel blocks, servicing DMA
completion between blocks. DMA and verification can therefore overlap without
interrupts, additional cores, or scatter-gather descriptors.

Each slot carries a full 32-bit software sequence and a sequence-derived 10-bit
seed. The image remains the existing 10-bit test pattern, not a new wire format.
Seed patterns repeat after 1024 sequences; full sequence numbers are metadata,
not embedded pixel headers. Source trigger/checker counters and hardware timing
snapshots are checked before publishing each DMA completion. Consumer sequence
checks detect out-of-order slot ownership, and every pixel checks its assigned seed.

This is trigger-paced pipelining, not autonomous/gapless camera streaming.
Each frame has a software completion/rearm gap, including FIFO reset. The maximum
observed completion-to-next-trigger gap is reported; it includes ring-full waits.
No maximum frame-rate claim follows from this test.

When no FREE slot exists, lossless mode pauses triggers until the consumer releases
a slot. It counts pause events. The fault test instead stops at that point and
reports one rejected acquisition demand as an overrun. No trigger is issued for
that demand and no unread slot is overwritten. This is queue-exhaustion detection,
distinct from capture FIFO overflow or DMA errors, which always fail the test.

Cache maintenance is restricted to owned buffers: all slots are initialized and
flushed before acquisition, and completed payload slices and guards are invalidated
before CPU reads. Payload, guard and metadata cache lines do not overlap. The ring
adds 96 MiB to the existing 24 MiB frame buffer, all in linker-owned low DDR.

## S test phases

1. Existing one-frame baseline and hardware timing check.
2. 64 pipelined captures with blanking 1024 cycles.
3. 64 pipelined captures with blanking 512 cycles.
4. Withhold consumption, fill four slots, and refuse the fifth demand. Then verify
   all four retained images, proving the ring-full policy protected unread data.
5. Eight captures after recovery at blanking 1024.

There are 140 verified ring frames plus the initial baseline. Software sequences
run from 0 through 139; the refused request does not consume a sequence number.
Every normal phase requires nonzero verification slices while a DMA is in flight,
zero overruns, exact issued/completed/verified counts and all slots returned FREE.
The forced phase requires exactly four captures and exactly one overrun indication.
Timing, pixel/padding, checksum, guard, byte-count and trigger/checker failures
abort the test. Cleanup disarms the source, drains it, flushes capture and resets
DMA; the caller restores exposure, blanking and seed.

CPU DDR reads now overlap DMA writes. These conditions are different from v21;
a hardware failure at blanking 512 must be investigated, not classified as an
expected sweep boundary. Backpressure pauses are expected and are not data loss.

## Prepare and run

Stop debugging and save/close the C editor. Run from your PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Projects\VIVADO\FH_Carrier_Bringup_Linux\scripts\prepare_vitis_v22.ps1
```

The script backs up source and launch settings, installs v22, checks BSP/FSBL and
the existing Timing BIT/XSA pair, selects that BIT, and rebuilds with the toolchain
PATH required by Ninja. It does not start or program the board. Launch normally
and select **S**. Send the complete phase summaries and any failure message.

The assistant session cannot write to the Vitis directory. Read-only preparation
preflight passed; actual installation remains for the command above. The supplied
ELF is built with the current standalone BSP and application linker script.

## Verification

- Production ring code executed in a native host harness with deterministic
  MMIO responses: ring wrap, full-ring pause, concurrent DMA/verification,
  protected overrun and post-error recovery passed.
- Injected pixel corruption, guard corruption, DMA error, completion timeout,
  hardware timing mismatch, sequence mismatch and rejected-trigger anomaly were
  all detected. Cleanup was checked after every failure.
- Cache mocks check ownership and range sizes; they do not emulate real CPU
  caches, AXI behavior or DMA hardware. Board testing is still required.
- A53 application compiled/linked with -Wall -Wextra -Werror. Ring buffers fit
  below 2 GiB and are 64-byte aligned in the ELF. No Q/T/D hardware artifacts
  were changed. Tests and generation scripts are under scripts/ and tests/.

No v22 hardware PASS is claimed yet. Autonomous continuous capture using a
hardware scheduler/queued DMA remains a separate subsequent milestone.
