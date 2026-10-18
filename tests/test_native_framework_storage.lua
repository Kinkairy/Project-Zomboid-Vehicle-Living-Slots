-- Host contract tests: execute exact Config functions with mock engine objects.
-- Not actual tile loading, world, networking or player acceptance.
local root=assert(arg[1]);local shared=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/'
package.path=shared..'?.lua;'..package.path
local f=assert(io.open(shared..'VLS_Config.lua'));local source=f:read('*a');f:close()
local function section(a,b)local x=assert(source:find(a,1,true));local y=assert(source:find(b,x+#a,true));return source:sub(x,y-1)end
local native={};local now=0;getTimestampMs=function()return now end
instanceof=function(i,k)return i and i.moveable and k=='Moveable'end
getSprite=function(s)return native[s] end
local noop=function()end
IsoObject={new=function()return {setSprite=function(o,s)o.s=s end,getSprite=function(o)return o.s end,
 createContainersFromSpriteProperties=noop,getContainerCount=function(o)return o.s.count end,
 getContainerByIndex=function(o)return {getCapacity=function()return o.s.capacity end,getType=function()return o.s.kind end,
 getOpenSound=function()return o.s.open end,getCloseSound=function()return o.s.close end,getPutSound=function()return o.s.put end,getTakeSound=function()return o.s.take end}end,
 isGenericCraftingSurface=function(o)return o.s.surface end}end}
local D=require'VLS_NativeDefinition';local C=require'VLS_NativeContext'
VLS={UNIVERSAL_PART_ID='living',profiles={}}
VLS.getEquipmentProfile=function(i)return i and i.profile end
VLS.isUniversalPart=function(p)return p.universal end
VLS.isManagedPart=VLS.isUniversalPart
VLS.isSupportedVehicle=function(v)return v.supported end
VLS.getLaundryMode=function()error('unrelated appliance logic invoked')end
-- Space policy has its own suite; these contracts concern containers only.
VLS.NativeSpace={allows=function()return true end}
local diagnostic
local glue='local NativeDefinition,NativeContext,noteNativeDefinitionFailure=...\n'..
 section('local function applyContainerProfile(', '-- Appliance inventories')..
 section('function VLS.isStorageEquipment(', 'function VLS.isManagedPart(')..
 section('function VLS.isGenericCraftSurfaceEquipment(', 'function VLS.getInstalledGenericCraftSurfacePart(')..
 section('function VLS.ensureUniversalContainerProfile(', '-- Restore the installed equipment profile')..
 section('function VLS.ContainerAccess.UniversalSlot(', 'function VLS.ContainerAccess.WeaponLocker(')
VLS.ContainerAccess={};assert(load(glue))(D,C,function(p,r)diagnostic=r end)
local cargo={capacity=77,kind='saved',open='old',close='old',put='old',take='old',items={'kept'},id=900}
for _,pair in ipairs{{'Capacity','capacity'},{'Type','kind'},{'OpenSound','open'},{'CloseSound','close'},{'PutSound','put'},{'TakeSound','take'}}do
 local name,key=pair[1],pair[2];cargo['get'..name]=function(c)return c[key]end;cargo['set'..name]=function(c,v)c[key]=v end
end
local vehicle={supported=true};local player={getVehicle=function()return vehicle end}
local part={universal=true,data={}};local item={moveable=true,id=4}
function item:getWorldSprite()return self.sprite end;function item:getID()return self.id end
function part:getId()return 'slot'end;function part:getVehicle()return vehicle end;function part:getInventoryItem()return item end
function part:getItemContainer()return cargo end;function part:getModData()return self.data end
function vehicle:getPartById(id)if id=='slot'then return part end end;function vehicle:getId()return 1 end
function vehicle:transmitPartModData()self.transmitted=(self.transmitted or 0)+1 end
getVehicleById=function(id)if id==1 then return vehicle end end
local n=0;local function test(s,fn)fn();n=n+1;print('PASS '..s)end
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function setup(name,cap,surface,overhead)
 item.sprite=name;item.profile={capability='storage',genericCraftSurface=not overhead,overhead=overhead}
 native[name]={count=1,capacity=cap,kind=cap==10 and 'sidetable' or 'counter',surface=surface};D.clearCache()
end
for _,case in ipairs{{'green',50,true,false},{'pine',10,true,false},{'overhead',50,false,true}}do
 test(case[1]..' shares native metadata and original cargo owner',function()
  setup(table.unpack(case));local contents=cargo.items;local c=assert(C.containerAccess(player,vehicle,part))
  eq(c.container,cargo);assert(VLS.ContainerAccess.UniversalSlot(vehicle,part,player));eq(cargo.capacity,case[2]);eq(cargo.items,contents);eq(cargo.items[1],'kept');eq(cargo.id,900)
  eq(cargo.open,nil);eq(cargo.close,nil);eq(cargo.put,nil);eq(cargo.take,nil)
  eq(VLS.isGenericCraftSurfaceEquipment(item),case[3]);eq(D.singleContainer(item).genericCraftSurface,case[3])
 end)
end
test('metadata entry and compatibility cabinet use one cache',function()eq(D.singleContainer(item),D.cabinet(item))end)
test('zero and multiple containers deny access without modifying saved cargo',function()
 for _,count in ipairs{0,2}do
  setup('bad',50,false,true);native.bad.count=count;local cap,kind,contents=cargo.capacity,cargo.kind,cargo.items
  eq(VLS.ContainerAccess.UniversalSlot(vehicle,part,player),false);eq(cargo.capacity,cap);eq(cargo.kind,kind);eq(cargo.items,contents)
  eq(diagnostic,count==0 and 'native_sprite_has_no_container' or 'requires_multi_container_host')
 end
end)
test('native missing definition recovers and clears diagnostic after delay',function()
 setup('late',50,false,true);native.late=nil;eq(VLS.ContainerAccess.UniversalSlot(vehicle,part,player),false)
 native.late={count=1,capacity=31,kind='native',surface=false};now=5000
 assert(VLS.ContainerAccess.UniversalSlot(vehicle,part,player));eq(cargo.capacity,31);eq(diagnostic,nil)
end)
test('foreign player or equal-named foreign part cannot borrow access',function()
 eq(VLS.ContainerAccess.UniversalSlot(vehicle,part,{getVehicle=function()end}),false)
 local fake={getId=function()return 'slot'end};eq(VLS.ContainerAccess.UniversalSlot(vehicle,fake,player),false)
end)
test('overhead has same saved epoch and rejects old same-item token',function()
 setup('overhead',50,false,true);local c=assert(C.containerAccess(player,vehicle,part));local t=C.token(c)
 assert(C.installationChanged(vehicle,part));assert(C.installationChanged(vehicle,part));eq(C.restore(player,t),nil)
 eq(C.restore(player,C.token(C.containerAccess(player,vehicle,part))).container,cargo);eq(vehicle.transmitted,2)
end)
test('unrelated non-storage item does not enter metadata path',function()
 item.profile={capability='bed'};eq(VLS.ContainerAccess.UniversalSlot(vehicle,part,player),false)
end)
test('capacity shrink keeps overfull cargo and exact original object',function()
 setup('shrunk',10,true,false);cargo.capacity=50;local contents=cargo.items
 cargo.items[2]='oversized contents remain';assert(VLS.ContainerAccess.UniversalSlot(vehicle,part,player))
 eq(cargo.capacity,10);eq(cargo.items,contents);eq(cargo.items[2],'oversized contents remain')
end)
test('installation support and existing-only recognition remain separate policy',function()
 local policy=section('function VLS.isInstallationEnabled(', 'function VLS.isAllowedItem(')
 assert(load(policy))();local frame=false
 VLS.isOverheadPart=function()return true end;VLS.hasTopFrame=function()return frame end
 VLS.getInstallationOption=function()return 'Storage' end
 VLS.getEquipmentProfileByType=function()return item.profile end
 setup('overhead',50,false,true);eq(VLS.isInstallationEnabled(part,item),false)
 frame=true;eq(VLS.isInstallationEnabled(part,item),true)
 item.profile.overheadInstallable=false;eq(VLS.isInstallationEnabled(part,item),false)
 item.profile.overheadInstallable=true;SandboxVars={VehicleLivingSlots={Storage=false}}
 eq(VLS.isInstallationEnabled(part,item),false);SandboxVars=nil
end)
print('TOTAL '..n..' storage integration mock tests; native world acceptance pending')
