`timescale 1ns/1ps
module tb_gmax3412_emulator;
    reg clk=0; always #4.166667 clk=~clk;
    reg resetn=0;
    reg [7:0] awaddr=0,araddr=0;
    reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;
    reg [31:0] wdata=0;
    reg [3:0] wstrb=15;
    wire awready,wready,bvalid,arready,rvalid;
    wire [1:0] bresp,rresp;
    wire [31:0] rdata;
    reg init_in=0,start_in=0,stop_in=0,trigger_in=0;
    wire fval,lval,busy,initialized,armed,texp;
    wire [191:0] data;
    gmax3412_emulator dut (
        .s_axi_aclk(clk),.s_axi_aresetn(resetn),
        .s_axi_awaddr(awaddr),.s_axi_awprot(3'b0),.s_axi_awvalid(awvalid),.s_axi_awready(awready),
        .s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),
        .s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
        .s_axi_araddr(araddr),.s_axi_arprot(3'b0),.s_axi_arvalid(arvalid),.s_axi_arready(arready),
        .s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),
        .init_in(init_in),.acquisition_start(start_in),.acquisition_stop(stop_in),.trigger_in(trigger_in),
        .fvalout(fval),.lvalout(lval),.dataout(data),.busy(busy),.initialized(initialized),
        .armed(armed),.cmos_texp1(texp));
    task tick(input integer n); repeat(n) @(negedge clk); endtask
    // Deliberately separate AW/W in either order and stall the response.
    task wr(input [7:0] a,input [31:0] d,input bit data_first,input [3:0] strb,input [1:0] resp);
        begin
            if(data_first) begin
                @(negedge clk); wdata=d; wstrb=strb; wvalid=1;
                do @(posedge clk); while(!wready);
                @(negedge clk); wvalid=0; tick(3);
                awaddr=a; awvalid=1;
                do @(posedge clk); while(!awready);
                @(negedge clk); awvalid=0;
            end else begin
                @(negedge clk); awaddr=a; awvalid=1;
                do @(posedge clk); while(!awready);
                @(negedge clk); awvalid=0; tick(2);
                wdata=d; wstrb=strb; wvalid=1;
                do @(posedge clk); while(!wready);
                @(negedge clk); wvalid=0;
            end
            wait(bvalid); tick(3);
            if(!bvalid || bresp!==resp) $fatal(1,"Write response %h",a);
            bready=1; tick(1); bready=0;
        end
    endtask
    task rd(input [7:0] a,input [31:0] expected,input [1:0] resp);
        reg [31:0] held;
        begin
            @(negedge clk); araddr=a; arvalid=1;
            do @(posedge clk); while(!arready);
            @(negedge clk); arvalid=0;
            wait(rvalid); held=rdata; tick(3);
            if(!rvalid || rdata!==held || rresp!==resp || rdata!==expected)
                $fatal(1,"Read %h got %h expected %h response %h",a,rdata,expected,rresp);
            rready=1; tick(1); rready=0;
        end
    endtask
    integer px=0, rows=0, x=0, y=0, gap=0, exposure_count=0, completed=0;
    integer seed_expected=7, blank_expected=3;
    reg pf=0,pl=0,pt=0;
    reg [31:0] total=0;
    reg monitor_enable=1;
    integer k;
    // Independent testbench scoreboard: no generator counters are referenced.
    always @(negedge clk) begin
        if(!resetn || !monitor_enable) begin
            pf=0; pl=0; pt=0; px=0; rows=0; x=0; y=0; gap=0; total=0; exposure_count=0;
        end else begin
            if(texp && !pt) exposure_count=0;
            if(texp) exposure_count=exposure_count+1;
            if(pt && !texp && exposure_count!=13) $fatal(1,"Exposure length %0d",exposure_count);
            if(fval && !pf) begin px=0; rows=0; x=0; y=0; total=0; end
            if(lval) begin
                if(!fval) $fatal(1,"LVAL outside FVAL");
                if(!pl && y!=0 && gap!=blank_expected) $fatal(1,"Blanking %0d",gap);
                gap=0;
                for(k=0;k<16;k=k+1) begin
                    if(data[k*12 +: 12] !== ((x+k+y+seed_expected)&1023))
                        $fatal(1,"Pixel mismatch at %0d,%0d lane %0d",x,y,k);
                    total=total+data[k*12 +: 12];
                end
                x=x+16; px=px+16;
            end else if(fval) gap=gap+1;
            if(pl && !lval) begin
                if(x!=4096) $fatal(1,"Line length %0d",x);
                rows=rows+1; y=y+1; x=0;
            end
            if(pf && !fval) begin
                if(px!=12582912 || rows!=3072 || total!=32'h7fa00000)
                    $fatal(1,"Frame geometry/checksum %0d %0d %h",px,rows,total);
                completed=completed+1;
            end
            pf=fval; pl=lval; pt=texp;
        end
    end
    // Second checker receives a deliberately corrupted pixel to prove detection.
    reg inject=0;
    wire [31:0] fault_frames,fault_errors;
    wire fault_pass;
    gmax3412_checker faulty_checker(.clk(clk),.resetn(resetn),.fval(fval),.lval(lval),
        .data(data ^ (inject ? 192'b1 : 192'b0)),.seed(10'd7),
        .frames(fault_frames),.errors(fault_errors),.last_pass(fault_pass));
    initial begin
        tick(5); resetn=1; tick(2);
        rd('h00,32'h34120001,0);
        wr('h04,8,0,15,0); rd('h24,1,0); // uninitialized trigger rejected
        wr('h0c,13,1,15,0); wr('h10,3,0,15,0);
        wr('h14,32'h12340000,1,15,0); wr('h14,7,0,1,0);
        rd('h14,32'h12340007,0); // WSTRB retained upper bytes
        wr('h18,1,0,15,2); rd('hfc,0,2); rd('h19,0,2);
        wr('h04,1,0,15,0); wait(initialized); wr('h04,2,1,15,0);
        wr('h04,8,0,15,0); wait(fval);
        // One-cycle corruption is applied only to the extra checker.
        @(negedge clk); inject=1; @(negedge clk); inject=0;
        wr('h04,8,1,15,0); // busy trigger rejected
        wr('h10,9,1,15,0); wr('h14,12,0,15,0); // active settings remain latched
        wr('h04,4,0,15,0); // stop finishes the frame and disarms
        wait(completed==1); tick(4);
        rd('h20,1,0); rd('h24,2,0); rd('h28,1,0); rd('h2c,0,0);
        rd('h30,12582912,0); rd('h34,3072,0); rd('h38,32'h7fa00000,0);
        rd('h08,17,0);
        rd('h40,32'h544d0001,0); rd('h44,1,0); rd('h48,13,0);
        rd('h4c,256,0); rd('h50,256,0); rd('h54,3,0); rd('h58,3,0);
        rd('h5c,3072*256+3071*3,0); rd('h60,3072,0);
        if(fault_frames!=1 || fault_errors!=1 || fault_pass) $fatal(1,"Fault not detected");
        // A second full frame proves the pending configuration takes effect.
        seed_expected=12; blank_expected=9;
        wr('h04,2,0,15,0); wr('h04,8,1,15,0);
        wait(completed==2); tick(4);
        rd('h28,2,0); rd('h2c,0,0); rd('h38,32'h7fa00000,0);
        rd('h44,2,0); rd('h48,13,0); rd('h54,9,0); rd('h58,9,0);
        rd('h5c,3072*256+3071*9,0);
        // Native held-high trigger produces exactly one request. Reset aborts frame.
        monitor_enable=0;
        @(negedge clk); start_in=1; tick(2); start_in=0;
        trigger_in=1; tick(30); trigger_in=0;
        rd('h20,3,0); rd('h24,2,0);
        resetn=0; tick(3); resetn=1; tick(3);
        rd('h28,0,0); rd('h08,0,0);
        rd('h44,0,0); rd('h48,0,0); rd('h5c,0,0);
        // Invalid timing is rejected, with no output.
        wr('h04,1,0,15,0); wait(initialized); wr('h04,2,0,15,0);
        wr('h0c,0,0,15,0); wr('h04,8,0,15,0); rd('h24,1,0);
        if(busy || fval || lval) $fatal(1,"Invalid timing started frame");
        $display("PASS: full 4096x3072 frame, independent pixel/timing/checksum checks, fault injection, AXI stalls/order/strobes/errors, stop/reset/native trigger.");
        $finish;
    end
    initial begin #20000000; $fatal(1,"Simulation timeout"); end
endmodule
