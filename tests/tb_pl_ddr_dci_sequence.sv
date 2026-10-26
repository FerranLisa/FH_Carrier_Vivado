`timescale 1ns/1ps
module tb_pl_ddr_dci_sequence;
    reg clk=0, resetn=0, locked=1;
    wire pulse, sys_rst;
    integer i, highs;
    always #4.166 clk=~clk;
    pl_ddr_dci_sequence dut(.clk(clk),.resetn(resetn),.dci_locked(locked),.dci_reset(pulse),.sys_rst(sys_rst));
    task tick; begin @(posedge clk); #1; end endtask
    initial begin
        tick(); if(!sys_rst||pulse) $fatal(1,"Reset defaults");
        @(negedge clk);resetn=1;
        highs=0;
        // An initially high LOCKED must never bypass the reset sequence.
        for(i=1;i<=127;i=i+1) begin
            tick(); if(!sys_rst) $fatal(1,"Premature DDR reset release");
            if(pulse) highs=highs+1;
            if(pulse !== (i>=32 && i<=95)) $fatal(1,"Incorrect pulse placement");
        end
        if(highs!=64) $fatal(1,"Pulse width");
        tick();if(sys_rst) $fatal(1,"Reset did not release after lock");
        @(negedge clk);locked=0;
        repeat(3) tick();if(!sys_rst) $fatal(1,"Lock loss not handled");
        @(negedge clk);resetn=0;
        #1;if(!sys_rst||pulse) $fatal(1,"External reset assertion");
        tick(); @(negedge clk);resetn=1;
        repeat(200) begin tick();if(!sys_rst) $fatal(1,"Released without lock");end
        @(negedge clk);locked=1;
        repeat(3) tick();if(sys_rst) $fatal(1,"Late lock not accepted");
        repeat(10) begin tick();if(pulse) $fatal(1,"Reset unexpectedly repeated");end
        $display("PL_DDR_DCI_SEQUENCE_PASS");$finish;
    end
endmodule
