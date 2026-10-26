from pathlib import Path
import json,sys
r=Path(__file__).resolve().parents[1]
d=json.loads((r/'FH_Carrier_Bringup.srcs/sources_1/bd/design_1/design_1.bd').read_text())['design']['addressing']
active=[]
for master,m in d.items():
    for space,s in m['address_spaces'].items():
        for v in s['segments'].values():
            if v.get('is_excluded')!='TRUE':
                active.append([master,space,v['address_block'],int(v['offset'],16),v['range']])
active.sort()
p=r/'audit/pl_ddr4/routed_assigned_addresses.json'
if '--snapshot' in sys.argv:
    assert not p.exists(), 'Do not overwrite the routed design address baseline'
    p.write_text(json.dumps(active,indent=2)+'\n')
else:
    assert json.loads(p.read_text())==active, 'Handoff reachable addresses differ from routed BIT baseline'
    print('PL_DDR_HANDOFF_MAP_PASS: all reachable addresses match the routed design')
