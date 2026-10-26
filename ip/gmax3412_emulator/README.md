# gmax3412_emulator — first milestone

Synthesizable GMAX3412 **parallel driver-output** development source with an
independent on-chip checker. VLNV: `fh.local:user:gmax3412_emulator:1.0`.
Default/fixed packaged geometry: 4096 x 3072, sixteen 12-bit slots per beat,
10 useful bits per slot. This is not an electrical Sub-LVDS, training, sensor
register-map, optical-black, HDR, or cycle-accurate sensor-sequencer model.
No DMA or external sensor pins are driven by this IP.

## Interface contract

- `s_axi_aclk`: 120 MHz; all state, native commands, AXI and checker use this clock.
- `s_axi_aresetn`: active-low synchronous reset; aborts acquisition, clears
  status/counters and restores configuration defaults.
- `clk_rxg` is the same clock; `rst_rxg` is the inverted reset.
- `dataout[12*i +: 12] = {2'b00, pixel[9:0]}`, lane `i=0..15`.
  Pixel `(x,y)` = `(x + y + seed) modulo 1024`.
  Lane i contains column `16*k+i` on valid cycle k, 256 beats/line.
- `fvalout` spans the frame including inter-line blanking. `lvalout` is high
  for exactly 256 consecutive clocks per line. First FVAL and LVAL rise together;
  both fall on the clock following the final valid beat. Data outside LVAL is
  unspecified/held. There is no backpressure or ready input.
- INIT, START, STOP and TRIGGER are one-shot commands. Native inputs are
  rising-edge detected and must be synchronous to 120 MHz. AXI commands are
  write-one pulses. Both sources are ORed; simultaneous identical commands
  become one command. Integrated native inputs are tied low (AXI ownership).
- INIT at idle disarms and asserts initialized after 32 clocks. INIT during
  a busy frame is ignored. It does not clear statistics. START arms only if
  initialized; STOP disarms immediately but finishes an accepted frame.
- TRIGGER is accepted only when initialized, already armed, idle, with nonzero
  exposure and blanking, and without simultaneous INIT or STOP. Otherwise the
  rejected counter increments. START+TRIGGER does not arm-and-trigger in one
  operation: issue separate commands. No trigger queue or automatic retrigger.
- At acceptance, seed and blanking are latched and the exposure counter loads.
  `cmos_texp1` stays high for exactly EXPOSURE clocks. The first valid image beat
  follows its falling edge by one clock. `cmos_texp2` is held low.
  This is the emulator's defined timing contract, not a claim about the sensor's
  exact exposure-to-readout delay or overlapping-exposure modes.
- Configuration writes during acquisition apply only to the next accepted frame.
  BLANKING is the exact number of low-LVAL cycles **between** lines, minimum 1.
  EXPOSURE is in 120 MHz cycles (120000 = 1 ms), minimum 1.
- Poll completed checker frames, rather than busy alone, for finished results:
  checker results publish one clock after the generator releases busy.
  Counters wrap modulo 2^32. LAST_PASS describes the last checked frame.

## AXI4-Lite map

Integration base: **0xA0030000**. 32-bit aligned accesses; independent AW/W
channels, WSTRB byte enables, and response backpressure are supported.
Unknown/unaligned offsets and writes to read-only registers return SLVERR.
AWPROT/ARPROT are ignored. Only the low eight address bits are decoded; the
register window aliases within its reserved 64 KiB address segment.

| Offset | Access | Name | Meaning/default |
|---|---|---|---|
| 0x00 | RO | ID_VERSION | 0x34120001 |
| 0x04 | WO | COMMAND | bit 0 INIT, bit 1 START, bit 2 STOP, bit 3 TRIGGER; reads zero |
| 0x08 | RO | STATUS | bit 0 initialized, 1 armed, 2 busy, 3 exposing, 4 last checker pass |
| 0x0C | RW | EXPOSURE | 120000 clocks |
| 0x10 | RW | BLANKING | 16 clocks |
| 0x14 | RW | SEED | 0; only low 10 bits affect pixels |
| 0x18 | RO | WIDTH | 4096 |
| 0x1C | RO | HEIGHT | 3072 |
| 0x20 | RO | ACCEPTED | Accepted triggers since reset |
| 0x24 | RO | REJECTED | Rejected triggers since reset |
| 0x28 | RO | CHECKED_FRAMES | Completed frames checked |
| 0x2C | RO | CHECK_ERRORS | Cumulative pixel/geometry/protocol errors |
| 0x30 | RO | LAST_PIXELS | 12582912 for a correct frame |
| 0x34 | RO | LAST_LINES | 3072 for a correct frame |
| 0x38 | RO | LAST_CHECKSUM | Sum of all 12-bit slots modulo 2^32 |
| 0x3C | RO | CLOCK_HZ | 120000000 |

For every full-size ramp frame, irrespective of seed, LAST_CHECKSUM is
**0x7FA00000**. Each row includes four complete 0..1023 ramps. The checker
compares every pixel and padding bits using its own raster counters; it also
checks row length, total lines and total pixels. It does not certify programmed
blanking/exposure timing; the simulation scoreboard verifies those timings.
The checker consumes the actual output bus and the latched seed. It is included
inside the packaged IP so its results stay observable even without a consumer.

## Board smoke test

After building/programming the updated FPGA design and making this address
accessible from your PS software:

1. Check ID_VERSION = 0x34120001. Record CHECKED_FRAMES and CHECK_ERRORS.
2. Write COMMAND = 1; poll STATUS bit 0 with a timeout.
3. Write EXPOSURE = 120000, BLANKING = 16, SEED = 7.
4. Write COMMAND = 2, then COMMAND = 8.
5. Poll CHECKED_FRAMES for one increment (e.g. 1 s timeout).
6. Require STATUS bit 4, unchanged CHECK_ERRORS, LAST_PIXELS = 12582912,
   LAST_LINES = 3072 and LAST_CHECKSUM = 0x7FA00000.
7. Write COMMAND = 4 to disarm.

Use ordered/device MMIO accessors in software. Do not treat a successful bus
write as acceptance of a trigger: check ACCEPTED/REJECTED. This milestone does
not add a Linux kernel driver or capture buffers.

Alternatively, after programming the new bitstream and selecting a PS target
in XSDB, source `scripts/check_gmax3412_emulator_xsdb.tcl`. It executes the test
above with timeouts. It does not select/program/reset a target. This script has
not been exercised on physical hardware.

## Reproduce

Run from the repository root with Vivado 2025.2 (`vivado -mode batch -source ...`):

1. `scripts/test_gmax3412_emulator.tcl` — full-resolution XSim scoreboard and
   corruption test; check the explicit PASS line, not merely Vivado's exit code.
2. `scripts/package_gmax3412_emulator.tcl` — regenerate component.xml and XGUI.
3. `scripts/synth_gmax3412_emulator.tcl` — standalone synthesis, placement,
   routing and 120 MHz timing report under results/.
4. `scripts/integrate_gmax3412_emulator.tcl` — run only on a project that does
   not already contain this IP; refuses duplicates/address overlap. Adds the IP,
   100-to-120 MHz clock wizard and reset synchronizer, extends SmartConnect
   with a second clock for automatic AXI clock crossing, and generates BD
   output products. Existing external
   ports and maintained top-level wrapper do not change.

The checked-in project already contains the integration once this script has
successfully run. Subsequent RTL edits require repackaging, refreshing/upgrading
the BD IP, regeneration and a normal fresh project build. Existing bitstreams
and XSA files do not gain the new peripheral until rebuilt/exported.

`vivado_local_bootstrap.tcl` extends Tcl package search paths within the current
process and its debug-core subprocesses for this installation's Tcl Store issue;
it changes no installed files.

`scripts/build_gmax3412_emulator_export.tcl` builds the complete project in-process,
preserves the receiver ILA insertion hook, checks routed timing and methodology,
and writes BIT/LTX/XSA plus reports into `exports/gmax3412_emulator/`.
The build invokes `scripts/finalize_gmax3412_xsa.ps1` to bind the exported archive
to the new BIT explicitly: Vivado's project-mode export otherwise can embed the
older `impl_1` bitstream. The finalizer preserves all generated metadata and
checks the embedded BIT against the delivered BIT using SHA-256.
Run `scripts/verify_gmax3412_export.ps1` independently to repeat this check and
verify the emulator at `0xA0030000`. Run `scripts/validate_gmax3412_xsa.tcl` with
Vitis XSCT to check the handoff and A53 address map using AMD's HSI reader.
This flow does not populate the normal GUI implementation run; use its exported
artifacts for the smoke test.

The emulator clock wizard uses `PRIM_SOURCE=No_buffer` because its input is the
PS-generated PL clock. This removes the redundant primary-clock declaration
that caused TIMING-4 and TIMING-27 in the previous implementation.

For subsequent package refreshes, `scripts/refresh_gmax3412_emulator.tcl` updates
the installed instance, checks protocol/reset polarity and regenerates the BD.
It resets synthesis runs; use it while no build is running.
`scripts/validate_gmax3412_project.tcl` performs full-project synthesis in-process
(avoiding the Windows Script Host launcher), writes a checkpoint under results/,
and restores the original hierarchical checkpoint mode. It does not populate
the normal synth_1 run or build a bitstream.

## Verified 23 October 2026, Vivado 2025.2

| Check | Result |
|---|---|
| XSim | PASS: two full-resolution frames; changed seed/blanking; every pixel, line/frame geometry and checksum verified |
| Controls/AXI | PASS: exposure, graceful stop, reset abort, busy/uninitialized rejection, held native trigger, AW/W ordering, response stalls, byte writes and invalid addresses |
| Checker fault injection | PASS: single corrupted pixel detected by an independent checker instance |
| IP packaging | Integrity check passed |
| Block design | Validated; existing addresses preserved; new segment at 0xA0030000 |
| Standalone routed IP | 120 MHz internal timing: setup slack +3.555 ns, hold slack +0.030 ns; zero DRC findings |
| Standalone resources | 1119 LUTs, 836 registers, zero BRAM; excludes integration clock/SmartConnect overhead |
| Full project synthesis | Completed: zero synthesis errors/critical warnings; default post-synthesis DRC has zero findings |
| Full project route | PASS: setup +0.272 ns, hold +0.010 ns, pulse width +0.067 ns; zero failing timing endpoints and routing errors |
| Methodology / DRC | No critical methodology violations; no DRC errors or critical warnings; other receiver/debug warnings remain |
| Bus skew / receiver constraints | PASS: no bus-skew violations; receiver first-stage, IDELAY and Gray-pointer endpoints verified |
| BIT / XSA | Bitstream generated; finalized XSA embeds the exact delivered BIT (SHA-256 checked) |
| Vitis HSI | PASS: finalized XSA opens; one emulator found; A53 memory map includes 0xA0030000 |

Standalone port input/output delays are unconstrained: that result verifies
internal paths, not end-to-end timing of the full carrier design. Full-project
implementation and the new BIT/LTX/XSA are available in `exports/gmax3412_emulator/`.
Physical-board execution has **not** been performed. Existing physical receiver/ILA
logic remains in the project. The detailed CDC report still lists 48 critical
receiver findings (CDC-1/10/11/13); this smoke-test build is not a full CDC sign-off.

Evidence: `results/gmax_test.log`, `results/gmax_package.log`,
`results/gmax_refresh.log`, `results/gmax_emulator_timing.rpt`,
`results/gmax_emulator_utilization.rpt`, `results/gmax_emulator_drc.rpt`,
`results/gmax_project_synth_direct.log`, `results/gmax_project_drc.rpt`.
Full build evidence: `results/gmax_build_export_fixed.log`,
`exports/gmax3412_emulator/{timing,methodology,drc,bus_skew,cdc,route_status}.rpt`,
`exports/gmax3412_emulator/SHA256.json`.

## Timing-monitor revision (24 October 2026)

The current RTL adds a passive `gmax3412_timing` monitor and read-only registers
0x40 through 0x60. The original register map and command behavior are preserved.
Capability ID 0x544D0001 identifies the new register block. Measurements include
exposure pulse width, minimum/maximum line high and inter-line low duration,
frame-valid duration, line count and a completed-snapshot sequence number.
Snapshots update atomically at frame end and are read in source-clock cycles.
See `exports/gmax3412_timing/README.md` for the register map and v21 Q test.

Since the original milestone report above, user-supplied hardware logs have
confirmed option 9, v19 DDR capture, and v20 stress/recovery tests passing.
The v20 sweep passed at blanking 256 and overflowed at 192 cycles, then recovered.
Those results do not yet validate the new timing-monitor bitstream or Q test.
