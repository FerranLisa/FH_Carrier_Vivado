from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'software/BringupTest_v21.c').read_text()
s=s.replace('\nint main(void)', '\n'+(r/'software/gmax3412_ring.inc').read_text()+'\nint main(void)',1)
s=s.replace('    xil_printf(" Q   -','    xil_printf(" S   - GMAX3412 pipelined DDR buffer ring test\\r\\n");\n    xil_printf(" Q   -',1)
pos=s.rindex("        case 'q':")
s=s[:pos]+"        case 's':\n        case 'S':\n            test_gmax3412_ring();\n            break;\n\n"+s[pos:]
s=s.replace('diagnostics v21','diagnostics v22').replace('qualification (v21;', 'DDR ring (v22;')
s=s.replace(' * Version history:\n',' * Version history:\n *   v22 (25 October 2026): S adds four-slot pipelined DDR acquisition,\n *     sequence/ownership checks, trigger backpressure and overrun recovery.\n *\n',1)
for name in ['software/BringupTest_v22.c','exports/gmax3412_ring/software/BringupTest_v22.c']:
    p=r/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
print('Generated v22')
