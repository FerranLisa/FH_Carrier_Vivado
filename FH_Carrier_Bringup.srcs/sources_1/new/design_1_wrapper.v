// FH_Carrier bring-up top wrapper with raw I2C debug taps.
// The I2C nets are marked KEEP/MARK_DEBUG so the implementation Tcl hook
// can attach a conventional ILA directly to the six AXI-IIC tri-state signals.
// Vivado 2025.2 / XCZU7EV
`timescale 1 ps / 1 ps

module design_1_wrapper
   (PAC1944_I2C_scl_io,
    PAC1944_I2C_sda_io,
    VMON_PWRDN);

  inout PAC1944_I2C_scl_io;
  inout PAC1944_I2C_sda_io;
  output VMON_PWRDN;

  // PAC1944 PWRDN is active low.  Drive it high explicitly so the external
  // 10 kOhm pull-up cannot form a divider with an unused-pin pull-down.
  assign VMON_PWRDN = 1'b1;

  (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) wire PAC1944_I2C_scl_i;
  (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) wire PAC1944_I2C_scl_o;
  (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) wire PAC1944_I2C_scl_t;
  (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) wire PAC1944_I2C_sda_i;
  (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) wire PAC1944_I2C_sda_o;
  (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) wire PAC1944_I2C_sda_t;

  IOBUF PAC1944_I2C_scl_iobuf
       (.I(PAC1944_I2C_scl_o),
        .IO(PAC1944_I2C_scl_io),
        .O(PAC1944_I2C_scl_i),
        .T(PAC1944_I2C_scl_t));

  IOBUF PAC1944_I2C_sda_iobuf
       (.I(PAC1944_I2C_sda_o),
        .IO(PAC1944_I2C_sda_io),
        .O(PAC1944_I2C_sda_i),
        .T(PAC1944_I2C_sda_t));

  design_1 design_1_i
       (.PAC1944_I2C_scl_i(PAC1944_I2C_scl_i),
        .PAC1944_I2C_scl_o(PAC1944_I2C_scl_o),
        .PAC1944_I2C_scl_t(PAC1944_I2C_scl_t),
        .PAC1944_I2C_sda_i(PAC1944_I2C_sda_i),
        .PAC1944_I2C_sda_o(PAC1944_I2C_sda_o),
        .PAC1944_I2C_sda_t(PAC1944_I2C_sda_t));

endmodule
