-- Offline contract tests against an actual installed/pinned vanilla Vehicles.lua.
-- Usage: lua test_native_cargo_3811.lua PROJECT_ROOT VANILLA_VEHICLES_LUA
-- Real PZ/Kahlua, Java cache timing and multiplayer are separate live checks.
unpack = unpack or table.unpack
local root = assert(arg and arg[1], "project root required")
local vanilla = assert(arg[2], "actual vanilla Vehicles.lua required")
local checks, cases, models, beds = 0, 0, 0, 0
local function eq(a,b,why)
    checks=checks+1
    assert(a==b, (why or "mismatch").." expected="..tostring(b).." got="..tostring(a))
end
local function event() return {Add=function() end,Remove=function() end} end
Events=setmetatable({}, {__index=function(t,k) local e=event();rawset(t,k,e);return e end})
LuaEventManager={AddEvent=function() end}
dofile(vanilla)
local original=Vehicles.ContainerAccess.TruckBedOpenInside
local exterior=Vehicles.ContainerAccess.TruckBed
local open=Vehicles.ContainerAccess.TruckBedOpen
local loaded={['Vehicles/Vehicles']=true}
require=function(name) if loaded[name] then return loaded[name] end loaded[name]={};return loaded[name] end
getModInfoByID=function() return {getDir=function() return 'offline-fixture' end} end
local runtime=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/'
dofile(runtime..'shared/VLS_Config.lua')
local hook=Vehicles.ContainerAccess.TruckBedOpenInside
local C=VLS.CargoR6
local itemTypes={"Base.Mov_Cot","Base.Mattress"}
for name in pairs(VLS.sleepingBagTypes) do itemTypes[#itemTypes+1]=name end
table.sort(itemTypes)
local function fixture(name,physical,profile,policy)
    local ids,assignments={},(profile and profile.spacePassengers or {})
    for i,a in ipairs(assignments) do ids[a.passenger]=physical+i-1 end
    local raw=physical+#assignments
    local v={raw=raw,parts={},inArea=true,open=false,doorItem=true,areas={},engineReject=false}
    for s=0,physical-1 do v.areas[s]=s>=2 and 'SeatRear'..s or 'SeatFront'..s end
    for s=physical,raw-1 do v.areas[s]='TruckBed' end
    local script={getPassengerCount=function() return v.scriptCount or raw end,
        getPassengerIndex=function(_,id) return ids[id] or -1 end,
        getFullName=function() return name end}
    function v:getScript() return script end
    function v:getScriptName() return name end
    function v:getMaxPassengers() return self.raw end
    function v:getSeat(c) assert(c.real==true,'view leaked into Java getSeat');return c.seat end
    function v:getPassengerArea(s)
        if not self.areas[s] then return nil end
        local area=self.areas[s]
        return {contains=function(_,needle) return area:find(needle,1,true)~=nil end}
    end
    function v:isInArea(_,c) assert(c.real==true,'view leaked into Java area');return self.inArea end
    function v:getPartById(id) return self.parts[id] end
    function v:canAccessContainer(_,c)
        if self.engineReject then return false end
        return Vehicles.ContainerAccess[policy or 'TruckBedOpenInside'](self,self.parts.TruckBed,c)
    end
    local function part(id,index)
        local p={item=nil};v.parts[id]=p
        function p:getId() return id end
        function p:getVehicle() return v end
        function p:getIndex() return index end
        function p:getArea() return 'TruckBed' end
        function p:getInventoryItem() return self.item end
        function p:getItemContainer() return {} end
        return p
    end
    local trunk=part('TruckBed',0)
    for i,a in ipairs(assignments) do part(a.part,i) end
    v.parts.TrunkDoor={getInventoryItem=function() return v.doorItem and {} or nil end,
        getDoor=function() return {isOpen=function() return v.open end} end}
    local ch={real=true,vehicle=v,seat=0}
    function ch:getVehicle() return self.vehicle end
    return v,ch,trunk
end
local function setBed(v,a,kind)
    v.parts[a.part].item=kind and {getFullType=function() return kind end} or nil
end
for name,profile in pairs(VLS.vehicleProfiles) do
    models=models+1
    local phys=profile.kind=='smallVan' and 4 or 2
    for _,policy in ipairs({'TruckBedOpenInside','TruckBed','TruckBedOpen'}) do
        local v,ch,part=fixture(name,phys,profile,policy)
        local native=policy=='TruckBedOpenInside' and original or Vehicles.ContainerAccess[policy]
        for seat=0,phys-1 do
            ch.seat=seat
            local actual=v:canAccessContainer(0,ch)
            v.raw=phys;local expected=native(v,part,ch);v.raw=phys+#profile.spacePassengers
            eq(actual,expected,name..' '..policy..' original seat '..seat)
            cases=cases+1
        end
        for i,a in ipairs(profile.spacePassengers) do
            ch.seat=phys+i-1
            for _,kind in ipairs(itemTypes) do
                setBed(v,a,kind)
                local any=false
                for seat=0,phys-1 do
                    local saved=ch.seat;ch.seat=seat;v.raw=phys
                    any=native(v,part,ch) or any
                    v.raw=phys+#profile.spacePassengers;ch.seat=saved
                end
                eq(v:canAccessContainer(0,ch),any,name..' '..policy..' '..a.passenger..' '..kind)
                cases=cases+1;beds=beds+1
                ch.seat=0
                v.raw=phys;local front=native(v,part,ch);v.raw=phys+#profile.spacePassengers
                eq(v:canAccessContainer(0,ch),front,'front survives bed visit')
                ch.seat=phys+i-1
            end
            for _,kind in ipairs({'EMPTY','Base.Mov_SmallPineCabinet','Base.Mov_Microwave','Base.Mov_FridgeMini'}) do
                setBed(v,a,kind~='EMPTY' and kind or nil)
                eq(v:canAccessContainer(0,ch),native(v,part,ch),'non-bed does not gain permission')
                cases=cases+1
            end
            setBed(v,a,nil)
        end
        for _,near in ipairs({false,true}) do for _,door in ipairs({false,true}) do
            for _,installed in ipairs({false,true}) do
                ch.vehicle=nil;v.inArea=near;v.open=door;v.doorItem=installed
                eq(v:canAccessContainer(0,ch),native(v,part,ch),'outside semantics unchanged')
                cases=cases+1
            end
        end end
        eq(v.raw,phys+#profile.spacePassengers,'real count never modified by adapter')
    end
end
local prof=VLS.vehicleProfiles['Base.Van']
VLS.vehicleProfiles['Base.UnseenCommercialPaintVariant']=prof
local v,ch,part=fixture('Base.UnseenCommercialPaintVariant',2,prof)
eq(v:canAccessContainer(0,ch),true,'newly registered profile does not need another cargo whitelist')
local s=C.probe(v,ch)
eq(s.reached,true,'engine reaches actual original callback wrapper');eq(s.value,true)
v.engineReject=true;s=C.probe(v,ch);eq(s.reached,false);eq(s.value,false,'engine rejection preserved');v.engineReject=false
v.scriptCount=99;eq(v:canAccessContainer(0,ch),original(v,part,ch),'mismatched graph uses native');v.scriptCount=nil
local other,oc,op=fixture('Other.Unsupported',2,prof)
eq(hook(other,op,oc),original(other,op,oc),'unsupported vehicle uses original objects and policy')
local denyCalls=0
local function deny(a,b,c) denyCalls=denyCalls+1;return false end
setBed(v,prof.spacePassengers[1],'Base.Mov_Cot');ch.seat=2
eq(C.nativeInside(deny,v,part,ch),false,'native denial never turned into unconditional success')
assert(denyCalls>0)
local current=Vehicles.ContainerAccess.TruckBedOpenInside
for i=1,20 do C.installNativeHook() end
eq(current,Vehicles.ContainerAccess.TruckBedOpenInside,'idempotent installation')
eq(Vehicles.ContainerAccess.TruckBed,exterior,'outside-only callback untouched')
eq(Vehicles.ContainerAccess.TruckBedOpen,open,'open-bed callback untouched')
local later=function(...) return current(...) end
Vehicles.ContainerAccess.TruckBedOpenInside=later;C.installNativeHook()
eq(Vehicles.ContainerAccess.TruckBedOpenInside,later,'later mod wrapper is not overwritten')
eq(v:canAccessContainer(0,ch),true,'later delegation still works')
local read=assert(io.open(runtime..'shared/VLS_Config.lua')):read('*a')
local block=read:match('%-%- BEGIN VLS_NATIVE_CARGO_3811(.-)%-%- END VLS_NATIVE_CARGO_3811')
assert(block and not block:find(':Load(',1,true) and not block:find('CargoR6.targets',1,true))
print('RESULT models='..models..' policy_seat_cases='..cases..' installed_bed_policy_cases='..beds..' assertions='..checks)
print('PASS: native callback contract, all VLS profiles, all approved bed types, original seats, exterior rules, idempotence and no script rebinding.')
print('Offline Lua with actual vanilla callback and engine test doubles; not a live PZ/Kahlua or multiplayer test.')
