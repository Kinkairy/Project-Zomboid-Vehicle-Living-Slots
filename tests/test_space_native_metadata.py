"""Compare generated furniture entries with real game sprite metadata. Not gameplay."""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--game-root',type=Path,required=True)
p.add_argument('--probe-dir',type=Path,required=True)
p.add_argument('--work-dir',type=Path,required=True)
a=p.parse_args();root=Path(__file__).resolve().parents[1]
catalog=root/'workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/VLS_SpaceCatalog.lua'
a.work_dir.mkdir(parents=True,exist_ok=True)
(a.work_dir/'stdlib.lua').write_bytes((a.game_root/'java/stdlib.lua').read_bytes())
body=r"""
local Catalog=(function()
__CATALOG__
end)()
local Definition=(function()
__DEFINITION__
end)()
IsoObject={new=newNativeObject}
instanceof=function(_,kind)return kind=="Moveable"end
local checked,surfaces,containers=0,0,0
local rows={}
for kind,entry in pairs(Catalog.furniture) do
 if not entry.capability then
  for _,sprite in ipairs(entry.sprites) do
   local registered=assert(getSprite(sprite),kind..' missing native sprite '..sprite)
   local object=newNativeObject()
   object:setSprite(registered)
   object:createContainersFromSpriteProperties()
   assert(object:isGenericCraftingSurface()==entry.surface,kind..' native crafting surface differs')
   local count=object:getContainerCount()
   local item={getWorldSprite=function()return sprite end}
   local adapted,reason=Definition.furniture(item)
   assert(adapted,kind.." metadata adapter failed: "..tostring(reason))
   assert(adapted.genericCraftSurface==entry.surface,kind.." adapter surface differs")
   if count==0 then
    assert(adapted.capacity==0,kind.." invented storage")
    assert(Definition.singleContainer(item)==nil,kind.." gained storage capability")
   else
    assert(adapted.capacity==object:getContainerByIndex(0):getCapacity(),kind.." adapter capacity differs")
   end
   if entry.container then
    assert(count>0,kind..' missing native container')
    local box=object:getContainerByIndex(0)
    assert(box:getType()==entry.container,kind..' native container type differs')
    assert(box:getCapacity()>=0,kind..' invalid native capacity')
    containers=containers+1
   else
    assert(count==0,kind..' catalog omitted a native container')
   end
   if entry.surface then surfaces=surfaces+1 end
   checked=checked+1
   rows[#rows+1]=kind..','..sprite..','..entry.space..','..tostring(entry.surface)..','..count
  end
 end
end
assert(checked>0 and surfaces>0 and containers>0)
probeType='P3_NATIVE_PASS sprites='..checked..' surfaces='..surfaces..' containers='..containers..'\n'..table.concat(rows,'\n')
"""
script=a.work_dir/'catalog-native.lua';script.write_text(body.replace('__CATALOG__',catalog.read_text()).replace('__DEFINITION__',(catalog.parent/'VLS_NativeDefinition.lua').read_text()))
q=subprocess.run([str(a.game_root/'jre64/bin/java'),'-Duser.home='+str(a.work_dir/'user'),'-cp',str(a.game_root/'java/*')+':'+str(a.probe_dir),'NativeContainerLuaProbe',str(script),'registered',str(a.game_root/'media/newtiledefinitions.tiles')],cwd=a.work_dir,capture_output=True,text=True,timeout=120)
(a.work_dir/'stdout').write_text(q.stdout);(a.work_dir/'stderr').write_text(q.stderr)
match=re.search(r'P3_NATIVE_PASS sprites=(\d+) surfaces=(\d+) containers=(\d+)',q.stdout)
receipt={'pass':q.returncode==0 and bool(match),'exit_code':q.returncode,'counts':list(map(int,match.groups())) if match else None,'catalog_sha256':hashlib.sha256(catalog.read_bytes()).hexdigest(),'tiles_sha256':hashlib.sha256((a.game_root/'media/newtiledefinitions.tiles').read_bytes()).hexdigest()}
(a.work_dir/'receipt.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt))
if not receipt['pass']:print(q.stderr[-3000:])
raise SystemExit(0 if receipt['pass'] else 1)
