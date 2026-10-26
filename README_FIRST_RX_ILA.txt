FH_Carrier_Bringup receiver ILA diagnostic build

Start with CAPTURE_STEPS.txt to use the completed build on the board.
Program the BIT/LTX pair in debug/ from this same build; keep that bitstream
selected in the Vitis launch when starting the existing V16 BringupTest ELF.
Run A, then S and Y; leave streaming enabled for receiver ILA captures.

To build from sources, extract to a short path and follow
REBUILD_STEPS_RX_ILA.txt. BUILD_RX_ILA.tcl performs fresh synthesis/routing
and checks before generating outputs. CHANGELOG_RX_ILA.txt describes the
debug-only additions; VALIDATION_RX_ILA.txt states the measured results
and remaining CDC findings. Full reports and a routed checkpoint are in
results/20261004_100615/.

The original corrected V16.3 project is preserved. This debug build adds
D0/D1 raw/packing/FIFO/reset visibility and word/training visibility; it
does not claim to repair the sensor's failed training or produce frames.
