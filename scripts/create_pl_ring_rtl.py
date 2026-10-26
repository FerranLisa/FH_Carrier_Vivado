from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'ip/gmax3412_scheduler/hdl/gmax3412_scheduler.v').read_text()
s=s.replace('gmax3412_scheduler','gmax3412_pl_ring').replace('Finite autonomous burst','Rolling PL DDR4 capture').replace('input wire [31:0] control','input wire calib_ready,\n input wire [31:0] control')
s=s.replace('reg [7:0] capacity, completed, state;', 'reg [7:0] capacity, slot, state;\n reg [31:0] completed, target;\n (* ASYNC_REG="TRUE" *) reg [1:0] calibrated;\n always @(posedge clk) if(!resetn) calibrated<=0; else calibrated<={calibrated[0],calib_ready};')
s=s.replace("32'h34125301","32'h34125224").replace("3:status={24'b0,completed}","3:status=completed").replace("32'd119","32'd170")
s=s.replace('11:status=destination[63:32];default:status=0;', '11:status=destination[63:32];12:status={31\'b0,calibrated[1]};\n    13:status=completed<capacity ? completed : capacity;14:status={24\'b0,slot};15:status=target;default:status=0;')
s=s.replace('capacity<=4;completed<=0;', 'capacity<=4;slot<=0;target<=0;completed<=0;').replace('<=119','<=170')
s=s.replace('2:if(!running && error==0)', '2:if(!running && error==0 && calibrated[1])')
s=s.replace("state<=1;destination<=64'h10000040;", "state<=1;slot<=0;destination<=64'h1000000040;")
s=s.replace('3:if(running) stop_request<=1;', '3:if(running) stop_request<=1;\n     4:if(!running) target<={12\'b0,control[27:8]};')
s=s.replace('if(timer==POLL_LIMIT && state<90)', 'if(!calibrated[1] && state<90) begin error<=8;state<=90;end\n     else if(timer==POLL_LIMIT && state<90)')
s=s.replace('if(completed+1==capacity || stop_request)', "if((target!=0 && completed+1==target) || stop_request || completed==32'hFFFFFFFE)")
s=s.replace("// 74 guarded frames fit below 0x7FF00000; continue in high DDR.\n           if(completed==73) destination<=64'h800000040;\n           else destination<=destination+STRIDE;", "// Wrap only after a complete frame; configured slots stay within 4 GiB.\n           if(slot+1==capacity) begin slot<=0;destination<=64'h1000000040;end\n           else begin slot<=slot+1;destination<=destination+STRIDE;end")
s=s.replace('done<=error==0 && completed==capacity;', 'done<=error==0;')
p=r/'ip/gmax3412_pl_ring/hdl/gmax3412_pl_ring.v';p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
p=r/'scripts/package_gmax3412_pl_ring.tcl';p.write_text((r/'scripts/package_gmax3412_scheduler.tcl').read_text().replace('gmax3412_scheduler','gmax3412_pl_ring').replace('package_scheduler','package_pl_ring').replace('scheduler_package','pl_ring_package'))
# Reuse vendor physical pinout; reset comes from the existing PS reset network.
s=(r/'audit/pl_ddr4/vendor_ddr.xdc').read_text()
s='\n'.join(l for l in s.splitlines() if 'sys_rstn' not in l)
(r/'FH_Carrier_Bringup.srcs/constrs_1/new/pl_ddr4.xdc').write_text(s+'\n')
# Vendor source evidence is retained in audit/pl_ddr4 for reproducible pinout.
