from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'software/BringupTest_v22.c').read_text()
s=s.replace('\nint main(void)', '\n'+(r/'software/gmax3412_burst.inc').read_text()+'\nint main(void)',1)
s=s.replace('    xil_printf(" S   -','    xil_printf(" B   - GMAX3412 autonomous burst (4..119 stored frames)\\r\\n");\n    xil_printf(" S   -',1)
pos=s.rindex("        case 's':")
s=s[:pos]+"        case 'b':\n        case 'B':\n            test_gmax3412_burst();\n            break;\n\n"+s[pos:]
# Widened DMA: legacy tests must explicitly clear the destination high word.
s=s.replace('cap_write(CAP_DMA+0x48U,','cap_write(CAP_DMA+0x4CU,0U);cap_write(CAP_DMA+0x48U,')
s=s.replace('diagnostics v22','diagnostics v23')
s=s.replace(' * Version history:\n',' * Version history:\n *   v23: autonomous retained burst, configurable 4..119 guarded frames.\n *\n',1)
for name in ['software/BringupTest_v23.c','exports/gmax3412_scheduler/software/BringupTest_v23.c']:
    p=r/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
print('Generated v23')
