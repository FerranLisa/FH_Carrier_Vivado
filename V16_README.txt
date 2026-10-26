FH_Carrier / FH_Sen4K - GMAX3412 receiver bring-up V16
========================================================
Date: 2026-10-03
Target: XCZU7EV / Vivado + Vitis 2025.2
Sensor mode: GMAX3412 Table 16, 10-bit, 16-channel Sub-LVDS, 1.20 Gb/s/lane

WHY V16
-------
V15 proved the PL training FSM is alive and repeatedly completes attempts, but
all completed attempts returned training_result=0x0000. V16 adds observability
BEFORE changing sensor timing or attempting frame capture.

V16 HARDWARE CHANGES
--------------------
1. AXI GPIO axi_gpio_gmax_a_ctrl is widened:
   - Channel 1: 9 -> 15 output bits.
   - Channel 2: 18 -> 32 input bits.

2. Existing mapping is preserved:
   CH1 bits 0..8   = existing FH_Sen4K controls.
   CH2 bit 0       = SDO_TDIG.
   CH2 bits 16:1   = training_result[15:0].
   CH2 bit 17      = training_done.

3. New CH1 V16 controls:
   bits 12:9 = candidate index 0..13
   bit 13    = lane select, 0=D0 / 1=D1
   bit 14    = snapshot/retry freeze

4. New CH2 V16 status:
   bits 27:18 = selected captured 10-bit candidate word
   bit 28     = candidate valid
   bit 29     = CLK_OUT0 activity seen
   bit 30     = CLK_OUT1 activity seen
   bit 31     = selected lane raw ISERDESE3 activity seen

5. training.v captures the exact candidate words compared by the existing
   s_WORD_ALIGN state. The existing receiver actually checks 14 candidate
   slots (0..13), so V16 reports all 14 rather than silently reducing this to
   the conceptual 10 bit phases.

6. training.v also fixes one pre-existing terminal-candidate bug found during
   the V16 source review: slot 13 was compared to the training word and then an
   independent `if (cnt_steps == 13)` overwrote loc_ok back to failure. V16
   makes the terminal failure an `else if`, so a valid match in slot 13 passes.

7. gmax3412_rx_adapter stops launching NEW retry attempts while debug_freeze=1.
   An in-flight attempt is allowed to finish. Software waits 20 ms after freeze
   before reading the stable snapshot.

8. iserdes1to10_12.v adds a sticky raw-activity flag from changes on the
   pre-word-alignment ISERDESE3 8-bit sample bus. It does not affect training.

V16 SOFTWARE CHANGES
--------------------
BringupTest.c is updated to v16.

Command D in the FH_Sen4K submenu prints:
   - sensor readback 0x2E00 / 0x3000 / 0x3010 / 0x3014 / 0x3015
   - expected training word
   - CLK_OUT0 / CLK_OUT1 activity
   - D0 and D1 raw activity
   - all 14 captured candidate words per lane
   - direct 0x165 matches
   - 0x29A matches (possible P/N inversion OR bit-order reversal)

Command S now:
   1. releases V16 debug freeze,
   2. enables STREAM_EN,
   3. reads back the sensor-side training configuration,
   4. runs the normal 16-lane training wait,
   5. automatically runs the V16 raw RX diagnostic if training times out.

IMPORTANT 0x165 / 0x29A DETAIL
------------------------------
The expected Table-16 10-bit training pattern is 0x165.
Its 10-bit complement is 0x29A. For this particular pattern, its bit-reversed
value is ALSO 0x29A. Therefore a 0x29A candidate proves a useful systematic
relationship but cannot by itself distinguish P/N inversion from bit-order
reversal. Do not automatically set DATAIN_SWAP solely from that observation.

FILES MODIFIED
--------------
FH_Carrier_Bringup.srcs/sources_1/new/FH_Carrier_Bringup_top.v
FH_Carrier_Bringup.srcs/sources_1/new/gmax3412_rx_adapter.v
FH_Carrier_Bringup.srcs/sources_1/imports/New folder/training.v
FH_Carrier_Bringup.srcs/sources_1/imports/New folder/iserdes1to10_12.v
FH_Carrier_Bringup.srcs/sources_1/bd/design_1/design_1.bd
FH_Carrier_Bringup.srcs/sources_1/bd/design_1/ip/design_1_axi_gpio_0_1/design_1_axi_gpio_0_1.xci
BringupTest.c

NO XDC PIN CHANGES ARE REQUIRED
-------------------------------
V16 adds only internal PL diagnostic signals through the existing AXI GPIO.
The existing 16 data-pair and two forwarded-clock pin assignments/TERM_100
constraints are unchanged.

BUILD / PROGRAM SEQUENCE
------------------------
1. Open FH_Carrier_Bringup.xpr in Vivado 2025.2.
2. In the Tcl console run:
      source APPLY_V16_GMAX_RX_DIAG.tcl
3. Validate the block design if Vivado asks again.
4. Run synthesis.
5. Run implementation and review timing/DRC.
6. Generate bitstream.
7. Export Hardware INCLUDING bitstream and generate a NEW V16 XSA.
8. Update/recreate the Vitis platform from that V16 XSA.
9. Replace the application source with the supplied V16 BringupTest.c.
10. Rebuild and run the application.
11. FH_Sen4K submenu: A -> S -> confirm Y.
12. If 16-lane training still fails, V16 automatically prints the raw RX
    diagnostic. Copy that complete V16 section back into ChatGPT.

XSA WARNING
-----------
The original project archive contained an XSA created before V16. It does NOT
contain the widened AXI GPIO or V16 receiver logic. Regenerate/export hardware
before rebuilding Vitis. The existing zynqmp_fsbl.zip does not need source
changes, but any FSBL/platform binary used for the test must correspond to the
newly exported hardware as appropriate for your normal flow.

VALIDATION LIMITATION
---------------------
This environment does not contain Vivado/xvlog, so the project could not be
synthesized or implemented here. Source-level consistency checks were applied,
but Vivado 2025.2 synthesis/implementation is the authoritative validation.
