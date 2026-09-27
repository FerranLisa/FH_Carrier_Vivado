FH_Carrier Vivado 2025.2 - RAW I2C LOGIC ANALYZER BUILD
=======================================================

Purpose
-------
This project keeps the existing 2-slot System ILA for AXI context and adds a second,
conventional ILA named i2c_raw_ila during implementation.  The new ILA samples the
six raw AXI-IIC/IOBUF signals at PLCLK0 = 100 MHz and is intended to diagnose the
PAC1944 I2C transaction directly, without System-ILA AXI decoding.

This revision also drives the active-low PAC1944 VMON_PWRDN signal high from PL
package pin E5.  Unused PL pins are left without internal pulls so board-level
pull-ups on PWR_MON_ALERT1/2 are not loaded by Vivado's unused-pin pull-downs.

IMPORTANT: the old BIT/LTX/XSA and Hardware Manager cache were deliberately removed
(or archived under stale_pre_i2c_ila_artifacts) so an old probes file cannot be paired
with the new design.  A clean bitstream must be generated.

One-time setup in Vivado
------------------------
1. Unzip to a NEW directory.
2. Open FH_Carrier_Bringup.xpr in Vivado 2025.2.
3. In Tcl Console run:

   source [file join [get_property DIRECTORY [current_project]] SETUP_I2C_LOGIC_ANALYZER.tcl]

4. Generate Bitstream normally.

Alternative clean build from Tcl:

   source [file join [get_property DIRECTORY [current_project]] BUILD_I2C_LOGIC_ANALYZER.tcl]

After the build, open the Hardware Manager target and run this one command.  It
programs the matching BIT/LTX, restores the verified I2C START trigger and arms ILA2:

   source [file join [get_property DIRECTORY [current_project]] PROGRAM_AND_ARM_I2C_ILA.tcl]

The top module name remains design_1_wrapper, so the generated files keep the familiar names:
  FH_Carrier_Bringup.runs/impl_1/design_1_wrapper.bit
  FH_Carrier_Bringup.runs/impl_1/design_1_wrapper.ltx

What was changed
----------------
- Replaced the auto-generated top wrapper in the project source set with a maintained
  design_1_wrapper.v that is functionally identical at the board pins.
- Marked the six PAC1944 I2C tri-state nets KEEP + MARK_DEBUG.
- Added insert_i2c_raw_ila.tcl as an implementation hook (installed by the setup script).
- Added VMON_PWRDN as a constant-high PL output on E5, LVCMOS33.
- Set BITSTREAM.CONFIG.UNUSEDPIN to PULLNONE so unused ALERT inputs remain high impedance.
- Added PROGRAM_AND_ARM_I2C_ILA.tcl to program the device, restore the trigger and arm it.
- Disabled use of the old incremental synthesis checkpoint.
- Removed stale Hardware Manager probe associations.
- Existing Block Design, AXI addresses, System ILA, AXI IIC, PS configuration and XDC pin
  assignments are unchanged.

Raw I2C ILA probe map
---------------------
  probe0 = PAC1944_I2C_scl_i  : actual SCL level returned from IOBUF / PCB pin
  probe1 = PAC1944_I2C_sda_i  : actual SDA level returned from IOBUF / PCB pin
  probe2 = PAC1944_I2C_scl_o  : AXI IIC output data toward IOBUF
  probe3 = PAC1944_I2C_scl_t  : SCL tri-state control; 1 = released
  probe4 = PAC1944_I2C_sda_o  : AXI IIC output data toward IOBUF
  probe5 = PAC1944_I2C_sda_t  : SDA tri-state control; 1 = released

ILA settings
------------
- Core name: i2c_raw_ila
- Clock: same PLCLK0 domain as AXI IIC, 100 MHz
- Capture depth: 65536 samples (~655 us at 100 MHz)
- Six independent 1-bit DATA_AND_TRIGGER probes

Suggested PAC1944 capture
-------------------------
1. Open the Hardware Manager target.
2. Source PROGRAM_AND_ARM_I2C_ILA.tcl.  It programs the device and configures:
      trigger position = 1024
      trigger condition = AND
      probe0 SCL_I = 1
      probe1 SDA_I = 0
      probe3 SCL_T = 1
      probe5 SDA_T = 0
   It then arms i2c_raw_ila automatically.  The runtime name may be hw_ila_2,
   but the script selects it by the stable cell name i2c_raw_ila.
3. Start or resume Vitis and run menu option 5 in BringupTest.

ACK/NACK interpretation
-----------------------
On the 9th SCL clock after an address/data byte:
- probe5 = 1 means the master has released SDA for ACK sampling.
- probe1 = 0 means a slave is pulling SDA low -> ACK.
- probe1 = 1 means the bus remains high -> NACK.

For START/STOP/open-drain behavior, compare SDA_I/SCL_I (what is physically on the bus)
with SDA_T/SCL_T (what the AXI IIC is releasing/driving).

Consistency note for Vitis
--------------------------
The AXI address map is unchanged, so software sources/BSP do not need hardware-address changes.
However, Vitis must program the NEW design_1_wrapper.bit generated from this project.  If your
Vitis launch points directly to the Vivado .bit path, rebuilding Vivado is sufficient.  If the
platform programs a bitstream embedded in the XSA, export a fresh XSA with bitstream after this
build and update/rebuild the Vitis platform.

2026-09-19 build-flow correction
-------------------------------
SETUP now locates exactly one design_1.bd, resets and force-regenerates all its
output products (including child IP designs), exports IP user files, installs
the maintained wrapper/hook, updates both compile orders, then resets the BD
OOC synthesis runs and the top synthesis/implementation runs. BUILD calls SETUP
once, checks run status, and exports fresh debug probes from the implemented
netlist. Errors are propagated; save_project is not used.
Use BUILD directly for the complete flow; running SETUP separately first is
unnecessary. For the GUI flow, run SETUP then Generate Bitstream.
Extract to a short path, for example C:/Projects/VIVADO/FH_I2C_FIXED, because
Vivado-generated child-IP paths can exceed the Windows path-length limit.
The raw-I2C wrapper, insertion hook, BD, System ILA and XDC are unchanged.
See VALIDATION_REPORT.txt for the checks actually completed on this revision.
Reference: AMD UG835 2025.2 generate_target and export_ip_user_files:
https://docs.amd.com/r/en-US/Vivado-Design-Suite-Tcl-Command-Reference-Guide-UG835/generate_target
https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands/export_ip_user_files

