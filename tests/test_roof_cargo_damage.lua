-- Standalone mocked regression: texlua test_roof_cargo_damage.lua <repo-root>
-- Loads the actual roof registrations and damage code. Not an engine playtest.
local root=assert(arg[1], 'repository root required')
local luaRoot=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/'
local results={}
local function same(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name, fn)
    local ok, err=pcall(fn)
    results[#results+1]={ok=ok,name=name}
    print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(err)))
end
local client=false
isClient=function() return client end
isServer=function() return not client end
VLS={equipmentProfiles={},supportedMoveableSprites={},installationOptionProviders={}}
package.loaded.VLS_Config=VLS
local ticks={}
Events={OnTick={Add=function(fn)ticks[#ticks+1]=fn end}}
dofile(luaRoot..'shared/VLS_RoofCargo.lua')
package.loaded.VLS_RoofCargo=VLSRoofCargo
local A=dofile(luaRoot..'shared/VLS_BodyArmor.lua')
package.loaded.VLS_BodyArmor=A
local R=VLSRoofCargo
local overlyBroadManaged=false
VLS.isManagedPart=function(p)
    return p:getId()=='ManagedInteriorFixture' or (overlyBroadManaged and R.allowed[p:getId()]~=nil)
end
local D=dofile(luaRoot..'shared/VLS_ComponentDamage.lua')
local nextId=0
local function makeItem(maximum)
    nextId=nextId+1
    local item={id=nextId,max=maximum or 100,condition=maximum or 100,charge=0.75,contents={'cargo'}}
    function item:getID() return self.id end
    function item:getConditionMax() return self.max end
    function item:getCondition() return self.condition end
    return item
end
local function newVehicle(name)
    local v={name=name or 'Base.StepVan',parts={},byId={},transmissions={},god=false,stats=0}
    function v:getSquare()return {} end
    function v:transmitPartCondition()end
    function v:transmitPartWindow()end
    function v:getScript() return {getFullName=function() return self.name end} end
    function v:getPartById(id) return self.byId[id] end
    function v:getPartCount() return #self.parts end
    function v:getPartByIndex(i) return self.parts[i+1] end
    function v:getDriverRegardlessOfTow() return {isGodMod=function() return self.god end} end
    function v:transmitPartItem(p) self.transmissions[p.id]=(self.transmissions[p.id] or 0)+1 end
    function v:updatePartStats() self.stats=self.stats+1 end
    function v:updateBulletStats() end
    function v:add(id,maximum)
        local p={id=id,vehicle=self,item=makeItem(maximum),damageCalls=0,removalCalls=0,lightActive=true,data={},z=-1}
        function p:getId() return self.id end
        function p:getVehicle() return self.vehicle end
        function p:getInventoryItem() return self.item end
        function p:setCondition(value)self.item.condition=value end
        function p:setModelVisible()end
        function p:getCondition() return self.item and self.item.condition or 0 end
        function p:getModData() return self.data end
        function p:damage(n)
            self.damageCalls=self.damageCalls+1
            if self.item then self.item.condition=math.max(0,self.item.condition-n) end
        end
        function p:setInventoryItem(it) self.removalCalls=self.removalCalls+1;self.item=it end
        function p:setLightActive(active) self.lightActive=active end
        function p:getScriptPart()
            return {getModel=function() return {getOffset=function() return {z=function() return self.z end} end} end}
        end
        self.parts[#self.parts+1]=p;self.byId[id]=p
        return p
    end
    v:add('EngineDoor');v:add('TruckBed')
    return v
end
local function impact(v,front,rear)
    v.byId.EngineDoor.item.condition=v.byId.EngineDoor.item.condition-(front or 0)
    v.byId.TruckBed.item.condition=v.byId.TruckBed.item.condition-(rear or 0)
    D.Update(v)
end
local function noMutation(p,item)
    same(p.item,item);same(p.damageCalls,0);same(p.removalCalls,0)
    same(item.condition,item.max);same(item.charge,0.75);same(#item.contents,1)
    same(p.lightActive,true)
    same(p.vehicle.transmissions[p.id],nil)
end
local roofIds={}
for id in pairs(R.allowed) do roofIds[#roofIds+1]=id end
table.sort(roofIds)
for _,id in ipairs(roofIds) do
    test('mounted '..id..' ignores front/rear forwarded collision',function()
        local v=newVehicle();local p=v:add(id,100);local original=p.item
        D.Init(v);impact(v,12,8);impact(v,8,12)
        noMutation(p,original)
    end)
end
for _,name in ipairs({'Base.StepVan','Base.Van','Base.VanSeats','Base.SUV','Base.PickUpVan'}) do
    test(name..' rack takes greatest front/rear loss; contents retained',function()
        local v=newVehicle(name);local rack=v:add(R.fixedId);local original=rack.item
        D.Init(v);impact(v,12,8)
        same(rack:getCondition(),91);same(rack.damageCalls,1)
        same(rack.item,original);same(#rack.item.contents,1);same(rack.removalCalls,0)
        D.Update(v);same(rack:getCondition(),91)
    end)
end
test('zero-condition rack stays installed and retains stored contents',function()
    local v=newVehicle();local p=v:add(R.fixedId);p.item.condition=2;local original=p.item
    D.Init(v);impact(v,10,0)
    same(p:getCondition(),0);same(p.item,original);same(#p.item.contents,1);same(p.removalCalls,0)
end)
test('original Torch lamp not removed on a lethal forwarded impact',function()
    local v=newVehicle();local p=v:add('VLSRoofHeadlight1',1);local original=p.item
    D.Init(v);impact(v,100,0);noMutation(p,original)
end)
test('cargo exclusion precedes broad managed-part fallback',function()
    local v=newVehicle();local p=v:add('VLSRoofGenerator');local original=p.item
    overlyBroadManaged=true
    D.Init(v);impact(v,20,20)
    overlyBroadManaged=false
    noMutation(p,original)
end)
test('interior fixture has no forwarded collision damage',function()
    local v=newVehicle();local p=v:add('ManagedInteriorFixture')
    D.Init(v);impact(v,20,10);same(p:getCondition(),100)
end)
test('armor remains outside this cargo change',function()
    local v=newVehicle();local p=v:add('VLSBumperFront');local original=p.item
    D.Init(v);impact(v,15,15);noMutation(p,original)
end)
test('source installation replacement does not fabricate an impact',function()
    local v=newVehicle();local p=v:add(R.fixedId)
    D.Init(v);v.byId.EngineDoor.item=makeItem();v.byId.EngineDoor.item.condition=10
    D.Update(v);same(p:getCondition(),100)
end)
test('late installed rack starts after pending impact',function()
    local v=newVehicle();local p=v:add(R.fixedId);p.item=nil
    D.Init(v);p.item=makeItem();impact(v,20,0);same(p:getCondition(),100)
    impact(v,10,0);same(p:getCondition(),92)
end)
test('source rebase prevents maintenance loss being forwarded',function()
    local v=newVehicle();local p=v:add(R.fixedId);D.Init(v)
    v.byId.EngineDoor.item.condition=50;D.RebaseSource(v.byId.EngineDoor)
    D.Update(v);same(p:getCondition(),100)
end)
test('client makes no authoritative damage edits',function()
    local v=newVehicle();local p=v:add(R.fixedId)
    client=true;same(D.Init(v),nil);impact(v,10,10);client=false
    same(p:getCondition(),100);same(p.damageCalls,0)
end)
test('god-mode driver preserves previous protection',function()
    local v=newVehicle();local p=v:add(R.fixedId);v.god=true
    D.Init(v);impact(v,10,10);same(p:getCondition(),100)
end)
test('old cargo damage remainder does not reactivate collision forwarding',function()
    local v=newVehicle();local p=v:add('VLSRoofPetrol1');local original=p.item
    p.data.VLSComponentDamage={itemID=original.id,remainder=0.99}
    D.Init(v);impact(v,20,20);noMutation(p,original)
    same(p.data.VLSComponentDamage.remainder,0.99)
end)
-- Real mechanics wrapper with a bounded stand-in for a native action result:
-- a failed repair may lower condition without being a collision.
package.loaded.VLS_ComponentDamage=D
package.loaded.VLS_InstallGuard=true
package.loaded["TimedActions/ISFixVehiclePartAction"]=true
local function nativeComplete(self)
    self.nativeCalls=(self.nativeCalls or 0)+1
    local p=self.part or self.vehiclePart
    p:setCondition(self.after)
    if self.fail then error("native maintenance fault") end
    return true
end
ISInstallVehiclePart={complete=nativeComplete}
ISUninstallVehiclePart={complete=nativeComplete}
ISFixVehiclePartAction={complete=nativeComplete}
dofile(luaRoot.."shared/VLS_DamageMechanics.lua")
local function armorVehicle(sourceId,armorId)
    local v=newVehicle();local source=v.byId[sourceId] or v:add(sourceId)
    local armor=v:add(armorId);local rack=v:add(R.fixedId)
    A.Init(v,armor);D.Init(v)
    return v,source,armor,rack
end
local function advanceArmor()for _=1,6 do for _,fn in ipairs(ticks)do fn()end end end
for _,case in ipairs({{"EngineDoor","VLSBumperFront"},{"WindowFrontLeft","VLSArmorWindowFrontLeft"}})do
 test("maintenance loss must not be absorbed by armor: "..case[1],function()
    local v,source,armor,rack=armorVehicle(case[1],case[2])
    local action={vehiclePart=source,after=80}
    ISFixVehiclePartAction.complete(action);advanceArmor()
    same(source:getCondition(),80);same(armor:getCondition(),100)
    same(rack:getCondition(),100);same(action.nativeCalls,1)
 end)
end
test("one real impact is settled once across tick, rack and mechanics entries",function()
    local v,source,armor,rack=armorVehicle("EngineDoor","VLSBumperFront")
    source:setCondition(90)
    local action={vehiclePart=source,after=95}
    ISFixVehiclePartAction.complete(action);advanceArmor();D.Update(v);D.Update(v)
    same(source:getCondition(),95);same(armor:getCondition(),90)
    same(rack:getCondition(),92);same(armor.damageCalls,1);same(rack.damageCalls,1)
end)
test("native maintenance exception still rebases damage before rethrow",function()
    local v,source,armor,rack=armorVehicle("EngineDoor","VLSBumperFront")
    local action={part=source,after=80,fail=true}
    same(pcall(ISInstallVehiclePart.complete,action),false);advanceArmor();D.Update(v)
    same(source:getCondition(),80);same(armor:getCondition(),100);same(rack:getCondition(),100)
end)
test("destroyed native window is not resurrected by armor",function()
    local v,source,armor=armorVehicle("WindowFrontLeft","VLSArmorWindowFrontLeft")
    source:setCondition(0);D.Update(v);advanceArmor()
    same(source:getCondition(),0);same(armor:getCondition(),100)
end)
test("god-mode protection rebases both consumers without deferred damage",function()
    local v,source,armor,rack=armorVehicle("EngineDoor","VLSBumperFront")
    v.god=true;source:setCondition(90);D.Update(v)
    v.god=false;advanceArmor();D.Update(v)
    same(source:getCondition(),90);same(armor:getCondition(),100);same(rack:getCondition(),100)
end)
local failures=0
for _,r in ipairs(results) do if not r.ok then failures=failures+1 end end
print('RESULT tests='..#results..' failures='..failures..' runtime='.._VERSION)
if failures>0 then os.exit(1) end
