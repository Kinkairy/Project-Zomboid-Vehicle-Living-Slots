"""Build a pinned real Kahlua probe from the actual Lua sources. Not gameplay."""
import argparse, pathlib, subprocess
p=argparse.ArgumentParser();p.add_argument('--game-root',type=pathlib.Path,required=True);p.add_argument('--javac',required=True);p.add_argument('--work-dir',type=pathlib.Path,required=True);a=p.parse_args()
source=pathlib.Path(__file__).resolve().parent
# Native-service fixture is kept separately; source placeholders prevent stale copies.
a.work_dir.mkdir(parents=True,exist_ok=True)
fixture=(source/'native_service_fixture.lua').read_text()
mod_root=source.parent.parent/'mods/vehicle-living-slots'
if not mod_root.is_dir():mod_root=source.parent  # standalone public source layout
runtime=mod_root/'workshop/Contents/mods/VehicleLivingSlots/common/media/lua'
propane=(runtime/'shared/VLS_PropaneRefillAction.lua').read_text().replace('local VLS = require "VLS_Propane"','local VLS = VLS')
fuel=(runtime/'shared/VLS_RoofFuel.lua').read_text().replace('local VLS = require "VLS_Config"','local VLS = VLS').removesuffix('return F\n')
native_base=(a.game_root/'media/lua/shared/TimedActions/ISBaseTimedAction.lua').read_text()
start=native_base.index('function ISBaseTimedAction:setOverrideHandModels(')
end=native_base.index('\nend',start)+4
hands=native_base[start:end]
start=native_base.index('function ISBaseTimedAction:forceStop()')
end=native_base.index('\nend',start)+4
for marker,body in {'BASE_HANDS':hands+'\n'+native_base[start:end],'HANDCRAFT':(a.game_root/'media/lua/shared/Entity/TimedActions/ISHandcraftAction.lua').read_text(),'BAD_PROPANE':propane.replace('nil, nil, {}, nil, nil, 1, 0)','nil, nil, false, nil, nil, 1, 0)'),'FIXED_PROPANE':propane,'TAKE_FUEL':(a.game_root/'media/lua/shared/TimedActions/ISTakeFuel.lua').read_text(),'ROOF_FUEL':fuel}.items():fixture=fixture.replace('-- INSERT_'+marker,body)
(a.work_dir/'probe.lua').write_text(fixture)
stdlib=next(a.game_root.rglob('stdlib.lua'));(a.work_dir/'stdlib.lua').write_bytes(stdlib.read_bytes())
subprocess.run([a.javac,'-d',str(a.work_dir),str(source/'NativeServiceProbe.java')],check=True)
subprocess.run([str(a.game_root/'jre64/bin/java'),'-Duser.home='+str(a.work_dir),'-cp',str(a.game_root/'java/projectzomboid.jar')+':'+str(a.work_dir),'NativeServiceProbe',str(a.work_dir/'probe.lua')],cwd=a.work_dir,check=True)
