from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'software/BringupTest_v20.c').read_text()
s=s.replace('static int CaptureOverflowOnly;', 'static int CaptureOverflowOnly;\nstatic int CaptureQuiet;')
s=s.replace('u64 Started=0, Elapsed, ExpectedUs;', 'u64 Started=0, Elapsed, ExpectedUs;\n    u32 TimingSequence=0;')
needle='    gmax_emu_write(GMAX_EMU_COMMAND,4U);\n    if (gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"stop before DDR")'
s=s.replace(needle,'''    if(Timing==2 && gmax_emu_read(0x40U)!=0x544D0001U) {
        xil_printf("  FAIL: hardware timing monitor absent; load the Timing bitstream.\\r\\n");return 0;
    }
'''+needle,1)
s=s.replace('        Started=capture_us();', '        if(Timing==2) TimingSequence=gmax_emu_read(0x44U);\n        Started=capture_us();',1)
marker='        Elapsed=capture_us()-Started;'
check='''        if(Timing==2) {
            u32 E=Exposure ? Exposure : 120000U*(Frame%3U+1U);
            u32 B=Blank ? Blank : Blanks[Frame%3U];
            u32 Seq=gmax_emu_read(0x44U),Exp=gmax_emu_read(0x48U);
            u32 Lmin=gmax_emu_read(0x4CU),Lmax=gmax_emu_read(0x50U);
            u32 Bmin=gmax_emu_read(0x54U),Bmax=gmax_emu_read(0x58U);
            u32 Fc=gmax_emu_read(0x5CU),Lc=gmax_emu_read(0x60U);
            if(Seq!=TimingSequence+1U || gmax_emu_read(0x44U)!=Seq || Exp!=E ||
               Lmin!=256U || Lmax!=256U || Bmin!=B || Bmax!=B ||
               Fc!=3072U*256U+3071U*B || Lc!=3072U) {
                xil_printf("  FAIL: hardware timing seq=%lu exp=%lu line=%lu/%lu blank=%lu/%lu frame=%lu lines=%lu\\r\\n",
                    (unsigned long)Seq,(unsigned long)Exp,(unsigned long)Lmin,(unsigned long)Lmax,
                    (unsigned long)Bmin,(unsigned long)Bmax,(unsigned long)Fc,(unsigned long)Lc);goto cleanup;
            }
            if(!CaptureQuiet || (Frame+1U)%10U==0U || Frame+1U==Count)
                xil_printf("  HW timing PASS: exposure=%lu line=%lu blank=%lu frame=%lu cycles; seq=%lu\\r\\n",
                    (unsigned long)Exp,(unsigned long)Lmin,(unsigned long)Bmin,(unsigned long)Fc,(unsigned long)Seq);
        }
'''
s=s.replace(marker,marker+'\n'+check,1)
s=s.replace('        xil_printf("  Timing: observed=', '        if(!CaptureQuiet) xil_printf("  Timing: observed=',1)
s=s.replace('        xil_printf("  Frame %lu PASS:', '        if(!CaptureQuiet || (Frame+1U)%10U==0U || Frame+1U==Count) xil_printf("  Frame %lu PASS:',1)
qualification='''
static void test_gmax3412_qualification(void)
{
    int Pass=0;
    xil_printf("\\r\\nGMAX3412 QUALIFICATION v21: repeated full frames + hardware timing\\r\\n");
    xil_printf("  Each frame is verified before the next trigger; this is not gapless streaming.\\r\\n");
    CaptureQuiet=1;
    if(!capture_run(1U,512U,1U,2)) goto done;
    if(!capture_run(1U,512U,12000000U,2)) goto done;
    if(!capture_run(32U,512U,120000U,2)) goto done;
    if(!capture_run(100U,320U,120000U,2)) goto done;
    if(!capture_run(100U,288U,120000U,2)) goto done;
    if(!capture_run(100U,256U,120000U,2)) goto done;
    if(!capture_overflow_test()) goto done;
    if(!capture_run(3U,512U,120000U,2)) goto done;
    Pass=1;
done:
    CaptureQuiet=0;
    xil_printf("  %s: v21 repeated-capture qualification and hardware timing.\\r\\n",Pass?"PASS":"FAIL");
    xil_printf("  Pin electrical timing and gapless DDR streaming are outside this test.\\r\\n");
}
'''
s=s.replace('\nint main(void)',qualification+'\nint main(void)',1)
s=s.replace('    xil_printf(" T   -','    xil_printf(" Q   - GMAX3412 repeated-capture qualification / hardware timing\\r\\n");\n    xil_printf(" T   -',1)
pos=s.rindex("        case 't':")
s=s[:pos]+"        case 'q':\n        case 'Q':\n            test_gmax3412_qualification();\n            break;\n\n"+s[pos:]
s=s.replace('diagnostics v20','diagnostics v21').replace('regression (v20;', 'qualification (v21;')
s=s.replace(' * Version history:\n',' * Version history:\n *   v21 (24 October 2026): Q adds 337 verified repeated captures and exact\n *     hardware exposure/line/blank/frame timing checks; requires Timing BIT.\n *   v20 (24 October 2026): T adds stress, timing, overflow and recovery tests.\n *\n',1)
for name in ['software/BringupTest_v21.c','exports/gmax3412_timing/software/BringupTest_v21.c']:
    p=r/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
print('Generated v21')
