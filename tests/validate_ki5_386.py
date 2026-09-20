#!/usr/bin/env python3
"""Check additive KI5 patches against the exact installed upstream scripts."""
import argparse,re,hashlib,json
from pathlib import Path

def block(text,kind,name):
    match=re.search(r"\b"+re.escape(kind)+r"\s+"+re.escape(name)+r"\s*\{",text)
    assert match,(kind,name)
    start=match.end();depth=1
    for i in range(start,len(text)):
        if text[i]=='{':depth+=1
        elif text[i]=='}':
            depth-=1
            if not depth:return text[start:i]
    raise AssertionError('unclosed block '+name)

def inside(text,name):
    return tuple(map(float,re.search(r'offset\s*=\s*([^,]+)',block(block(text,'passenger',name),'position','inside')).group(1).split()))

def check(repo,upstream):
    mod_root=repo/'mods/vehicle-living-slots'
    if not mod_root.is_dir():mod_root=repo  # standalone public source layout
    mod=mod_root/'workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media'
    patch=(mod/'scripts/VLS_KI5CampersPatch.txt').read_text()
    evidence={}
    for name in ('Trailer61Airflyte','Trailer61Astrodome'):
        path=upstream/'media/scripts/vehicles'/(name+'.txt')
        source=path.read_text();added=block(patch,'vehicle',name)
        native=['FrontL','FrontR','RearL','RearR','BackL','BackR']+(['FrontTop'] if name.endswith('Astrodome') else [])
        slots=['VLSKI5Space'+str(i) for i in range(1,4)]
        assert 'mechanicType = 2,' in source
        assert 'template = Battery,' in source and 'template = KI5CRPropane,' in source
        block(source,'area','SeatBackRight');block(source,'area','TruckBed')
        assert 'template = VLSKI5CamperSharedParts,' in added
        assert 'template = VLSKI5CamperSlots3,' in added
        for seat in native+slots:
            body=block(added,'passenger',seat)
            for target in (slots if seat in native else native+slots):
                if target!=seat:block(body,'switchSeat',target)
            if seat in native:
                assert not re.search(r'\b(position|door|area|showPassenger)\b',body),seat
        extents=tuple(map(float,re.search(r'extents\s*=\s*([^,]+)',source).group(1).split()))
        scale=500*.7/extents[2]
        positions={key:inside(added,key) for key in slots}
        for key,(x,_,z) in positions.items():
            for other in native+slots:
                if other==key:continue
                xx,_,zz=inside(source,other) if other in native else positions[other]
                assert abs(x-xx)*scale>=41 or abs(z-zz)*scale>=59,(name,key,other,'overlap')
        prefix=name.replace('Trailer61','Trailer61shasta')+'_'
        registry=(upstream/'media/lua/client/Vehicles/ISUI/KI5campers_CarMechanicsOverlay.lua').read_text()
        assert '"Base.'+name+'"] = "'+prefix+'"' in registry
        section=registry[registry.index('["Base.'+name+'"]'):].split('}, 10, 10);')[0]
        native_rects=re.findall(r'x=(\d+),y=(\d+),x2=(\d+),y2=(\d+)',section)
        for left,right in [(13,65),(208,260)]:
            for x,y,xx,yy in native_rects:
                x,y,xx,yy=map(int,(x,y,xx,yy))
                assert right<=x or xx<=left or 464<=y or yy<=384,(name,'tank/native mechanic overlap')
        for side in ('left','right'):
            for suffix in ('','_guide'):
                assert (mod/'ui/vehicles/mechanic overlay'/(name.replace('Trailer61','Trailer61shasta')+'_vls_water_tank_'+side+suffix+'.png')).is_file()
        evidence[name]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'slots':3,'native_passengers':len(native),'layout':'no added/native rectangle overlap at native 263x500 panel'}
    print('KI5_386_OK '+json.dumps(evidence,sort_keys=True))
    return evidence
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--upstream',type=Path,required=True);a=p.parse_args()
    check(Path(__file__).resolve().parents[2],a.upstream)
