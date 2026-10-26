from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'software/BringupTest_v23.c').read_text()
s=s.replace('\nint main(void)', '\n'+(r/'software/gmax3412_pl_ring.inc').read_text()+'\nint main(void)',1)
s=s.replace('    xil_printf(" B   -','    xil_printf(" P   - PL DDR4 rolling buffer (4..170 stored frames)\\r\\n");\n    xil_printf(" B   -',1)
pos=s.rindex("        case 'b':")
s=s[:pos]+"        case 'p':\n        case 'P':\n            test_gmax3412_pl_ring();\n            break;\n\n"+s[pos:]
s=s.replace('diagnostics v23','diagnostics v24')
s=s.replace(' * Version history:\n',' * Version history:\n *   v24: separate 4 GiB PL DDR4 rolling buffer, 4..170 retained frames.\n *\n',1)
for name in ['software/BringupTest_v24.c','exports/gmax3412_pl_ddr/software/BringupTest_v24.c']:
    p=r/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
print('Generated v24')
