from pathlib import Path
import json,re
r=Path(__file__).resolve().parents[1]
d=json.loads((r/'FH_Carrier_Bringup.srcs/sources_1/bd/design_1/design_1.bd').read_text())['design']
p=d['components']['pl_ddr4']['parameters']
reset=d['components']['pl_ddr_reset'].get('parameters',{})
# BD omits default-valued settings: proc_sys_reset 5.0 defaults EXT=1, AUX=0.
for key,default in [('C_EXT_RESET_HIGH','1'),('C_AUX_RESET_HIGH','0')]:
    assert reset.get(key,{}).get('value',default)==default, ('unsafe DDR reset polarity',key)
assert any('pl_ddr_reset/aux_reset_in' in net['ports'] and
           'pl_ddr_reset_inactive/dout' in net['ports'] for net in d['nets'].values())
assert d['components']['pl_ddr_reset_inactive']['parameters']['CONST_VAL']['value']=='1'
for a,b in [('pl_ddr_dci_reset/clk','gmax_emu_clock/clk_out1'),
            ('pl_ddr_dci_reset/resetn','gmax_emu_reset/peripheral_aresetn'),
            ('pl_ddr4/sys_rst','pl_ddr_dci_reset/sys_rst')]:
    assert any(a in net['ports'] and b in net['ports'] for net in d['nets'].values()), (a,b)
for key,value in {'C0.DDR4_MemoryPart':'MT40A512M16LY-075','C0.DDR4_DataWidth':'64','C0.DDR4_AxiAddressWidth':'32','C0.DDR4_AxiDataWidth':'512','C0.DDR4_AxiNarrowBurst':'true'}.items():
    assert p[key]['value']==value,(key,p[key])
for master,space in [('/zynq_ultra_ps_e_0','Data'),('/gmax_capture_dma','Data_S2MM')]:
    segs=d['addressing'][master]['address_spaces'][space]['segments']
    v=next(v for v in segs.values() if v['address_block'].startswith('/pl_ddr4/'))
    assert int(v['offset'],16)==0x1000000000 and v['range']=='4G' and not v.get('is_excluded')
vendor=(r/'audit/pl_ddr4/vendor_ddr.xdc').read_text()
actual=(r/'FH_Carrier_Bringup.srcs/constrs_1/new/pl_ddr4.xdc').read_text()
def pins(s):
    return dict((port.strip('{}'),pin) for pin,port in re.findall(r'set_property PACKAGE_PIN\s+(\w+)\s+\[get_ports\s+(\{[^}]+\}|\w+)\]',s))
assert pins(actual)==pins(vendor)
assert len(set(pins(actual).values()))==len(pins(actual))
stride=25165952
for capacity in range(4,171):
    assert capacity*stride<=2**32
    for total in [1,capacity-1,capacity,capacity+1,2*capacity+3,1025]:
        retained=min(total,capacity)
        slots=[s%capacity for s in range(total-retained,total)]
        assert len(set(slots))==retained
        for slot in slots: assert slot*stride+64+25165824+64 <=2**32
assert 171*stride>2**32
print('PL_DDR_LAYOUT_PASS: PS/DMA map, vendor pinout, MIG geometry, independent DCI startup/reset, every capacity 4..170 and wrap boundaries')
