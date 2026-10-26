`timescale 1ns/1ps
module tb_pl_ddr_axi_reset;
  reg clk=0, ui_reset=1, calibrated=0;
  always #5 clk=~clk;
  wire fixed_resetn, old_resetn;
  reset_fixed fixed_dut(.slowest_sync_clk(clk), .ext_reset_in(ui_reset),
    .aux_reset_in(1'b1), .mb_debug_sys_rst(1'b0), .dcm_locked(calibrated),
    .peripheral_aresetn(fixed_resetn));
  reset_old old_dut(.slowest_sync_clk(clk), .ext_reset_in(ui_reset),
    .aux_reset_in(1'b0), .mb_debug_sys_rst(1'b0), .dcm_locked(calibrated),
    .peripheral_aresetn(old_resetn));
  initial begin
    repeat(200) @(negedge clk);
    if(fixed_resetn!==0 || old_resetn!==0) $fatal(1,"Reset must assert before calibration");
    ui_reset=0; calibrated=1;
    repeat(300) @(negedge clk);
    if(fixed_resetn!==1) $fatal(1,"Corrected AXI reset must release");
    if(old_resetn!==0) $fatal(1,"Original tied-low active-low auxiliary must hold reset");
    calibrated=0;
    repeat(200) @(negedge clk);
    if(fixed_resetn!==0) $fatal(1,"Calibration loss must assert reset");
    calibrated=1;
    repeat(300) @(negedge clk);
    if(fixed_resetn!==1) $fatal(1,"Reset must recover after calibration returns");
    ui_reset=1;
    repeat(200) @(negedge clk);
    if(fixed_resetn!==0) $fatal(1,"UI reset must assert AXI reset");
    ui_reset=0;
    repeat(300) @(negedge clk);
    if(fixed_resetn!==1) $fatal(1,"Reset must recover after UI reset");
    $display("PL_DDR_AXI_RESET_PASS: original fault reproduced; corrected release, calibration loss and UI reset verified");
    $finish;
  end
endmodule
