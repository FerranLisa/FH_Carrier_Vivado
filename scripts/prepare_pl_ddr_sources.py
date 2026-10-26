from pathlib import Path
import shutil
r=Path(__file__).resolve().parents[1]
b=r/'audit/pl_ddr4/pre_v24';b.mkdir(parents=True,exist_ok=True)
for n in ['FH_Carrier_Bringup.xpr','FH_Carrier_Bringup.srcs/sources_1/new/FH_Carrier_Bringup_top.v','FH_Carrier_Bringup.srcs/sources_1/bd/design_1/design_1.bd']:
    dst=b/Path(n).name
    if not dst.exists(): shutil.copy2(r/n,dst)
p=r/'FH_Carrier_Bringup.srcs/sources_1/new/FH_Carrier_Bringup_top.v';s=p.read_text()
if 'c0_ddr4_dq' not in s:
    ports={'c0_sys_clk_p':('input',''),'c0_sys_clk_n':('input','')}
    for n,w in [('act_n',''),('adr','[16:0]'),('ba','[1:0]'),('bg','[0:0]'),('cke','[0:0]'),('odt','[0:0]'),('cs_n','[0:0]'),('ck_t','[0:0]'),('ck_c','[0:0]'),('reset_n',''),('dm_dbi_n','[7:0]'),('dq','[63:0]'),('dqs_c','[7:0]'),('dqs_t','[7:0]')]:
        ports['c0_ddr4_'+n]=('inout' if n in ['dm_dbi_n','dq','dqs_c','dqs_t'] else 'output',w)
    s=s.replace('(\n    //','(\n'+''.join(f'    {d} wire {w} {n},\n' for n,(d,w) in ports.items())+'    //',1)
    s=s.replace('        .capture_rx_clk',''.join(f'        .{n}({n}),\n' for n in ports)+'        .capture_rx_clk',1)
    s=s.replace('.c0_sys_clk_p(','.c0_sys_clk_clk_p(').replace('.c0_sys_clk_n(','.c0_sys_clk_clk_n(').replace('.c0_ddr4_dm_dbi_n(','.c0_ddr4_dm_n(')
    p.write_text(s)
# Adapt the independently stalled AXI slave model to circular addresses.
s=(r/'tests/tb_gmax3412_scheduler.sv').read_text().replace('gmax3412_scheduler','gmax3412_pl_ring')
s=s.replace('reg resetn=0;', 'reg calib_ready=0;reg resetn=0;').replace('.clk(clk),.resetn(resetn),.control(control)', '.clk(clk),.resetn(resetn),.calib_ready(calib_ready),.control(control)')
s=s.replace("expected=frames<74 ? 64'h10000040+frames*64'd25165952 : 64'h800000040+(frames-74)*64'd25165952;", "expected=64'h1000000040+(frames%dut.capacity)*64'd25165952;")
s=s.replace('input [7:0] n','input [19:0] n').replace("op,12'b0,n,8'b0",'op,n,8\'b0')
s=s.replace('cmd(1,count);cmd(2,0);','cmd(1,count);cmd(4,2*count+3);cmd(2,0);')
s=s.replace('triggers!=count','triggers!=2*count+3').replace('status!=count','status!=2*count+3')
s=s.replace('stream_frames!=4 || checked!=4 || errors!=0 || accepted!=4', 'stream_frames!=11 || checked!=11 || errors!=0 || accepted!=11')
s=s.replace('repeat(8) @(negedge clk);resetn=1;', 'repeat(8) @(negedge clk);resetn=1;\n  cmd(2,0);bank(1);if(status[0]) $fatal(1,"Started before calibration");\n  calib_ready=1;repeat(4) @(negedge clk);')
s=s.replace('120','171').replace('119','170') # restore reset wait and poll limit constants below
s=s.replace('17100 : 12','12000 : 12')
s=s.replace('status[3] || status[1]', 'status[3] || !status[1]')
s=s.replace('frames=0;triggers=0;cmd(1,170);cmd(2,0);', 'frames=0;triggers=0;cmd(1,170);cmd(4,0);cmd(2,0);')
s=s.replace('tick=tick+1;', 'if(fault==5 && triggers!=0) calib_ready=0;\n  tick=tick+1;')
s=s.replace('frames=0;triggers=0;fault=inject;', 'calib_ready=1;frames=0;triggers=0;repeat(4) @(negedge clk);fault=inject;')
s=s.replace('runburst(4,4);runburst(5,0);', 'runburst(4,4);runburst(4,5);fault=0;runburst(5,0);')
s=s.replace("fault==2 ? 'h1A", "(fault==2 && triggers>0) ? 'h1A")
s=s.replace('if(status!=2*count+3) $fatal(1,"Wrong completed count");', 'if(status!=2*count+3) $fatal(1,"Wrong completed count");\n   bank(13);if(status!=count) $fatal(1,"Wrong retained count");')
s=s.replace('if(!status[2] || status[1] || enabled || armed) $fatal(1,"Error cleanup failed");', 'if(!status[2] || status[1] || enabled || armed) $fatal(1,"Error cleanup failed");\n   bank(4);if(status!=(inject==1 ? 4 : inject==2 ? 5 : inject==3 ? 3 : inject==4 ? 2 : 8)) $fatal(1,"Wrong error code inject=%d code=%d",inject,status);')
s=s.replace('500000000 :','1000000000 :')
s=s.replace('SCHEDULER_TEST_PASS','PL_RING_TEST_PASS').replace('SCHEDULER_LIVE_PASS','PL_RING_LIVE_PASS')
s=s.replace('four real 4096x3072 frames','eleven real 4096x3072 frames through a four-slot ring').replace('170 frames, high DDR transition','4/170 slots, multiple wraps')
(r/'tests/tb_gmax3412_pl_ring.sv').write_text(s)
for live in [False,True]:
    s=(r/'scripts/test_gmax3412_scheduler.tcl').read_text().replace('gmax3412_scheduler','gmax3412_pl_ring').replace('test_scheduler','test_pl_ring').replace('scheduler_sim','pl_ring_live_sim' if live else 'pl_ring_sim').replace('SCHEDULER_TEST_PASS','PL_RING_LIVE_PASS' if live else 'PL_RING_TEST_PASS')
    if live:s=s.replace('launch_simulation','set_property generic {LIVE=1} [get_filesets sim_1]\nlaunch_simulation')
    (r/('scripts/test_gmax3412_pl_ring'+('_live' if live else '')+'.tcl')).write_text(s)
