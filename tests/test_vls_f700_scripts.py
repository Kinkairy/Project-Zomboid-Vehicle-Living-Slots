#!/usr/bin/env python3
"""Independent source boundaries and native-passenger preservation checks."""
import argparse,hashlib,json,re,runpy
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--ki5-scripts',type=Path);p.add_argument('--repo',type=Path);p.add_argument('--base-manifest',type=Path,help='Explicit approved core/Campers manifest for a later source lineage');p.add_argument('--candidate',default='candidate-3.10.1.json');a=p.parse_args()
here=Path(__file__).resolve()
root=a.repo or (here.parents[1] if (here.parents[1]/'workshop').is_dir() else here.parents[2]/'mods/vehicle-living-slots')
mods=root/'workshop/Contents/mods'
verified,_=runpy.run_path(str(root/'tools/check_runtime_manifest.py'))['validate'](root,a.candidate)
base=json.loads(a.base_manifest.read_text())['files'] if a.base_manifest else verified['files']
assert base==verified['files'],'Explicit core manifest does not match the verified candidate'
for name,want in base.items():
    assert hashlib.sha256((mods/name).read_bytes()).hexdigest()==want,'Approved core/Campers file changed: '+name
extra={str(f.relative_to(mods)) for f in mods.rglob('*') if f.is_file()}-set(base)
assert extra and all(n.startswith('VehicleLivingSlotsKI5F700/') for n in extra),extra
module=mods/'VehicleLivingSlotsKI5F700'
for ver in ['','42.20/']:
    info=(module/(ver+'mod.info')).read_text()
    assert 'name=Mobile Living: KI5 F700\n' in info
    assert 'require=\\VehicleLivingSlots,\\87fordB700,\\damnlib\n' in info
    assert 'KI5campers' not in info
    assert (module/(ver+'icon.png')).read_bytes()[:8]==b'\x89PNG\r\n\x1a\n'
src=(module/'common/media/scripts/VLS_KI5F700Patch.txt').read_text()
block=runpy.run_path(str(root/'tools/build_f700_adapter.py'))['block']
assert set(re.findall(r'(?m)^\s*vehicle\s+(\w+)\s*\{',src))=={'87fordF700bank','87fordF700swat','87fordB700school','87fordB700prison','87fordB700military'}
assert 'template = VLSLargeVanLivingSystem,' not in src
assert 'VLSImprovedChassis' not in src and 'VLS.Chassis.' not in src
system=block(src,'template vehicle','VLSKI5F700LivingSystem')
for i,id in enumerate(['VLSPantryCoffee','VLSOverhead1','VLSOverhead2','VLSOverhead3'],1):
    frame=block(system,'part','VLSTopFrame'+str(i));slot=block(system,'part',id)
    assert 'create = VLS.F700Frames.create' in frame
    assert 'requireInstalled = VLSTopFrame'+str(i)+',' in slot
    assert 'VLS.PartComplete.UniversalSlot' in slot
seats=['Bed','SpaceCenter','SpaceRight','VLSLargeVanSpace4','VLSLargeVanSpace5','VLSF700Space6','VLSF700Space7']
for model,nativeCount in [('87fordF700bank',2)]:
    vehicle=block(src,'vehicle',model)
    assert 'seats = '+str(nativeCount+7)+',' in vehicle
    passengerIds=re.findall(r'(?m)^\s*passenger\s+(\w+)\s*\{',vehicle)
    assert len(passengerIds)==len(set(passengerIds))==nativeCount+7
    for id in seats:
        passenger=block(vehicle,'passenger',id)
        assert 'door = TrunkDoor,' in passenger
        assert set(re.findall(r'switchSeat\s+(\w+)\s*\{',passenger))==set(passengerIds)-{id}
    if a.ki5_scripts:
        original=(a.ki5_scripts/(model+'.txt')).read_text()
        for id in set(passengerIds)-set(seats):
            before=block(original,'passenger',id)
            after=block(vehicle,'passenger',id)
            for new in seats:
                added=block(after,'switchSeat',new);after=after.replace(added,'')
            assert re.sub(r'\s+','',before)==re.sub(r'\s+','',after),(model,id,'original passenger changed')
print('F700_SOURCE_BOUNDARY_PASS base_files='+str(len(base))+' optional_files='+str(len(extra))+' native_seats='+str(bool(a.ki5_scripts)))

swat=block(src,'vehicle','87fordF700swat')
assert 'seats = 8,' in swat and not re.search(r'passenger\s+',swat)
assert 'VLSF700Slot7' not in swat and 'VLSF700Freezer7' not in swat
for i,id in enumerate(['SeatBed','VLSLargeVanSlot2','VLSLargeVanSlot3','VLSLargeVanSlot4','VLSLargeVanSlot5','VLSF700Slot6'],2):
    seat=block(swat,'part','SeatP'+str(i));living=block(swat,'part',id)
    assert 'category = VLSLiving,' in seat
    assert 'itemType = USMIL.Seat0,' in seat and 'specificItem = false,' in seat
    assert 'create = Vehicles.Create.Default' in seat
    assert 'create = VLS.Create.UniversalSlot' in living
    assert 'requireUninstalled = '+id+',' in seat
    assert 'requireUninstalled = SeatP'+str(i)+',' in living
    assert 'seat = P'+str(i)+',' in living
    for part in (seat,living):
        for action in ('install','uninstall'): assert 'VLS.F700Seats.' in block(part,'table',action)
print('SWAT_SIX_PAIRS_SCRIPT_PASS original passengers inherited intact; six paired native seats and living parts; driver-seat item restricted to SWAT')

for model in ('87fordB700school','87fordB700prison','87fordB700military'):
    bus=block(src,'vehicle',model)
    assert 'seats = 15,' in bus and not re.search(r'passenger\s+',bus)
    assert '/part/VLSF700Battery3,' in bus
    for i,id in enumerate(['SeatBed','VLSLargeVanSlot2','VLSLargeVanSlot3','VLSLargeVanSlot4','VLSLargeVanSlot5']+['VLSF700Slot'+str(j) for j in range(6,15)],1):
        seat=block(bus,'part','SeatP'+str(i));living=block(bus,'part',id)
        assert 'itemType = Base.87fordB700Seat2,' in seat and 'specificItem = false,' in seat
        assert 'requireUninstalled = '+id+',' in seat
        assert 'requireUninstalled = SeatP'+str(i)+',' in living and 'seat = P'+str(i)+',' in living
        assert 'create = Vehicles.Create.Default' in seat
        for part in (seat,living):
            for action in ('install','uninstall'):assert 'VLS.F700Seats.' in block(part,'table',action)
    for id in ['VLSLargeVanWaterTank','VLSF700WaterTank2','VLSF700WaterTank3','VLSF700WaterTank4']:
        assert '/part/'+id+',' in bus
    assert 'test = VLS.F700Roof.uninstallTest' in bus
    assert 'DAMNGasCanOne' not in bus and 'DAMNGasCanTwo' not in bus # inherit native roof models, recipes and items
    print('BUS_SCRIPT_PASS '+model+' 15 native passengers 14 pairs 4 tanks native roof inherited')

battery=block(system,'part','VLSF700Battery3')
assert 'test = VLS.F700Power.uninstallTest' in battery
assert 'itemType = Base.CarBattery1;Base.CarBattery2;Base.CarBattery3,' in battery
for model in ('87fordF700bank','87fordF700swat'):
    assert 'VLSF700Battery3' not in block(src,'vehicle',model)
print('BUS_NATIVE_EXITS_UNCHANGED_AND_BATTERY3_PASS')

for locale,labels in {'EN':('Water Tank #3','Water Tank #4','Battery #3'),'CN':('水箱#3','水箱#4','电瓶#3'),'CH':('水箱#3','水箱#4','電瓶#3')}.items():
    words=json.loads((module/('common/media/lua/shared/Translate/'+locale+'/IG_UI.json')).read_text())
    for key,want in zip(('VLSF700WaterTank3','VLSF700WaterTank4','VLSF700Battery3'),labels):
        assert words['IGUI_VehiclePart'+key]==want
print('BUS_WATER_BATTERY_THREE_LANGUAGES_PASS')
