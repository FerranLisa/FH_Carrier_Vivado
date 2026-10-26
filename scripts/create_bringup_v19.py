from pathlib import Path
src=Path('exports/gmax3412_emulator/software/BringupTest_v18.c').read_bytes()
s=src.decode('utf-8').replace('\r\n','\n')
nl='\r\n' if b'\r\n' in src else '\n'
edits=[
 (' * Revision: GMAX3412 emulator smoke test (v18; V16.3 receiver)', ' * Revision: GMAX3412 DDR capture verification (v19; V16.3 receiver)'),
 (' * Version history:\n',' * Version history:\n *   v19 (24 October 2026):\n *     - Adds D: three emulator-to-DDR captures via AXI DMA, pixel-by-pixel\n *       verification, cache maintenance, guard regions, timeouts and cleanup.\n *     - Requires the capture BIT/XSA and its initialized PS HP0 DDR interface.\n *     - Retains all v18 tests; reserves an aligned 24 MiB DDR frame buffer.\n *\n'),
 ('#include "xil_io.h"','#include "xil_io.h"\n#include "xil_cache.h"'),
 ('    xil_printf(" R   - External reset test\\r\\n");','    xil_printf(" D   - GMAX3412 emulator DDR capture / verify 3 frames\\r\\n");\n    xil_printf(" R   - External reset test\\r\\n");'),
 ('int main(void)\n',Path('software/gmax3412_ddr_test.inc').read_text()+'\nint main(void)\n'),
 ('+ emulator diagnostics v18','+ emulator/DDR diagnostics v19'),
 ("        case 'r':", "        case 'd':\n        case 'D':\n            test_gmax3412_ddr();\n            break;\n\n        case 'r':")]
for a,b in edits:
 assert s.count(a)==1,repr(a)
 s=s.replace(a,b,1)
out=Path('exports/gmax3412_capture/software/BringupTest_v19.c');out.parent.mkdir(parents=True,exist_ok=True)
out.write_bytes(s.replace('\n',nl).encode())
for a,b in reversed(edits):s=s.replace(b,a,1)
assert s.replace('\n',nl).encode()==src
print('PASS: v19 generated, v18 preserved outside intended edits')
