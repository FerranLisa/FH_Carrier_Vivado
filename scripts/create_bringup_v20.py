from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'software/BringupTest_v19.c').read_text()
start=s.index('static void test_gmax3412_ddr(void)')
end=s.index('\nint main(void)',start)
f=s[start:end]
f=f.replace('static void test_gmax3412_ddr(void)','static int capture_run(u32 Count, u32 Blank, u32 Exposure, int Timing)')
f=f.replace('int Complete,Passed=0,HaveSettings=0;', 'int Complete,Passed=0,HaveSettings=0;\n    u64 Started=0, Elapsed, ExpectedUs;')
f=f.replace('return;','return 0;')
f=f.replace('    xil_printf("\\r\\nGMAX3412 DDR', '    CaptureOverflowOnly=0;\n    xil_printf("\\r\\nGMAX3412 DDR',1)
f=f.replace('            xil_printf("  FAIL: DMA/capture completion:', '            CaptureOverflowOnly=((CapStatus&8U)!=0U && (DmaStatus&0x770U)==0U && (CapStatus&0x20U)==0U);\n            xil_printf("  FAIL: DMA/capture completion:')
f=f.replace('if(cap_dma_reset()!=XST_SUCCESS) Passed=0;', 'if(cap_dma_reset()!=XST_SUCCESS) {Passed=0;CaptureOverflowOnly=0;}')
f=f.replace('if(gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"DDR cleanup")!=XST_SUCCESS) Passed=0;', 'if(gmax_emu_wait(GMAX_EMU_STATUS,6U,0U,"DDR cleanup")!=XST_SUCCESS) {Passed=0;CaptureOverflowOnly=0;}')
f=f.replace('Frame<3U','Frame<Count')
f=f.replace('Blanks[Frame]', '(Blank ? Blank : Blanks[Frame%3U])')
f=f.replace('Seeds[Frame]', '((Seeds[Frame%3U]+(Blank ? Frame*17U : 0U))&1023U)')
f=f.replace('120000U*(Frame+1U)', '(Exposure ? Exposure : 120000U*(Frame%3U+1U))')
f=f.replace('three full frames','full-frame verification')
f=f.replace('        gmax_emu_write(GMAX_EMU_COMMAND,8U);','        Started=capture_us();\n        gmax_emu_write(GMAX_EMU_COMMAND,8U);')
needle='        Xil_DCacheInvalidateRange'
insert='''        Elapsed=capture_us()-Started;
        ExpectedUs=((u64)(Exposure ? Exposure : 120000U*(Frame%3U+1U))+
                    3072ULL*256ULL+3071ULL*(Blank ? Blank : Blanks[Frame%3U]))/120ULL;
        xil_printf("  Timing: observed=%lu us model=%lu us (includes polling/DMA tail)\\r\\n",
                   (unsigned long)Elapsed,(unsigned long)ExpectedUs);
        if(Timing && (Elapsed+100U<ExpectedUs || Elapsed>ExpectedUs+20000U)) {
            xil_printf("  FAIL: coarse frame timing outside tolerance.\\r\\n");goto cleanup;
        }
'''
f=f.replace(needle,insert+needle)
f=f.rstrip()[:-1]+'    return Passed;\n}\n'
extra=(root/'software/gmax3412_regression.inc').read_text()
s=s[:start]+extra.split('/* RUNNER */')[0]+f+extra.split('/* RUNNER */')[1]+s[end:]
s=s.replace('    xil_printf(" D   -', '    xil_printf(" T   - GMAX3412 timing, stress and recovery regression\\r\\n");\n    xil_printf(" D   -',1)
pos=s.rindex("        case 'd':")
s=s[:pos]+"        case 't':\n        case 'T':\n            test_gmax3412_regression();\n            break;\n\n"+s[pos:]
s=s.replace('test_gmax3412_ddr();','(void)capture_run(3U,0U,0U,0);')
s=s.replace('diagnostics v19','diagnostics v20')
s=s.replace('GMAX3412 DDR capture verification (v19;', 'GMAX3412 timing and recovery regression (v20;')
for name in ['software/BringupTest_v20.c','exports/gmax3412_capture/software/BringupTest_v20.c']:
    (root/name).write_text(s)
print('Generated v20')
