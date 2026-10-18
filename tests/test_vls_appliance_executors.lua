-- One heating, one cooling and one laundry executor driven by vanilla tile data
-- (owner request 2026-10-17), on the real VLS_Config with mocked engine objects.
local root=assert(arg[1])
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(media.."shared/VLS_Config.lua")
package.loaded.VLS_Config=V
function instanceof(item,kind)return item and item.kind==kind end
-- Power availability has its own suite; these cases concern the executors.
V.hasAuxBatteryPower=function()return true end
local n=0
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
local function eq(a,b,msg)assert(a==b,(msg or "")..": "..tostring(a).." != "..tostring(b))end
local function near(a,b,msg)assert(math.abs(a-b)<1e-6,(msg or "")..": "..tostring(a).." != "..tostring(b))end

local function container()
    local c={cap=0,kind="",temp=1,age=1,processed=0}
    function c:getCapacity()return self.cap end;function c:setCapacity(v)self.cap=v end
    function c:getType()return self.kind end;function c:setType(v)self.kind=v end
    for _,k in ipairs({"OpenSound","CloseSound","PutSound","TakeSound"})do
        c["get"..k]=function(s)return s[k] end;c["set"..k]=function(s,v)s[k]=v end
    end
    function c:getCustomTemperature()return self.temp end;function c:setCustomTemperature(v)self.temp=v end
    function c:getAgeFactor()return self.age end;function c:setAgeFactor(v)self.age=v end
    function c:addItemsToProcessItems()self.processed=self.processed+1 end
    return c
end
local function item(fullType,id)
    return {kind="Moveable",getFullType=function()return fullType end,getScriptItem=function()return nil end,
        getWorldSprite=function()return nil end,getID=function()return id or 7 end,getCondition=function()return 100 end}
end
local function vehicle(fullType)
    local v={parts={}}
    function v:getScriptName()return "Base.StepVan" end
    function v:getPartById(id)return self.parts[id]end
    local function part(id,it)
        local p={item=it,data={},box=container()}
        function p:getId()return id end;function p:getVehicle()return v end
        function p:getInventoryItem()return self.item end;function p:getModData()return self.data end
        function p:getItemContainer()return self.box end
        v.parts[id]=p;return p
    end
    local slot=part(V.UNIVERSAL_PART_ID,item(fullType))
    local freezer=part(V.FREEZER_PART_ID)
    return v,slot,freezer
end
local P=V.getEquipmentProfileByType

test("cooling profiles carry vanilla capacities",function()
    local fridge=P("Base.Mov_WhiteFridge")
    eq(fridge.capability,"cooling");eq(fridge.capacity,40);eq(fridge.freezerCapacity,20)
    eq(fridge.containerType,"fridge");eq(fridge.containerOpenSound,"OpenFridge")
    local chest=P("Base.Mov_ChestFreezer")
    eq(chest.capability,"cooling");eq(chest.capacity,30);eq(chest.freezerOnly,true)
    eq(chest.freezerCapacity,0);eq(chest.containerType,"freezer")
end)

test("heating profiles choose the vanilla window and its limits",function()
    local oven=P("Base.Mov_GreenOven")
    eq(oven.capability,"cooking");eq(oven.capacity,15);eq(oven.containerType,"stove");eq(oven.cookingWindow,"oven")
    local _,ovenPart=vehicle("Base.Mov_GreenOven")
    local limits,window=V.getCookingLimits(ovenPart)
    eq(window,"oven");eq(limits.maxTemperature,300);eq(limits.minTemperature,0);eq(limits.maxTimer,7200)
    local _,microPart=vehicle("Base.Mov_Microwave")
    limits,window=V.getCookingLimits(microPart)
    eq(window,"microwave");eq(limits.maxTemperature,130);eq(limits.minTemperature,50);eq(limits.maxTimer,3600)
end)

test("single-function laundry machines keep their vanilla mode",function()
    local _,dryer=vehicle("Moveables.appliances_laundry_01_12")
    dryer.data.vlsLaundryMode="laundryWasher"
    eq(V.getLaundryMode(dryer),"laundryDryer")
    local _,washer=vehicle("Moveables.appliances_laundry_01_4")
    washer.data.vlsLaundryMode="laundryDryer"
    eq(V.getLaundryMode(washer),"laundryWasher")
    local _,combo=vehicle("Base.Mov_BlueComboWasherDryer")
    combo.data.vlsLaundryMode="laundryDryer"
    eq(V.getLaundryMode(combo),"laundryDryer");eq(#V.getLaundryModes(combo),2)
end)

test("freezer drawers follow the vanilla freezer capacity",function()
    local v,_,freezer=vehicle("Base.Mov_WhiteFridge")
    V.syncFreezerSlot(v,V.UNIVERSAL_PART_ID)
    eq(freezer.box.cap,20,"regular fridge");eq(freezer.box.kind,"freezer")
    v,_,freezer=vehicle("Base.Mov_FridgeMini")
    V.syncFreezerSlot(v,V.UNIVERSAL_PART_ID)
    eq(freezer.box.cap,V.FREEZER_CAPACITY,"existing mini fridge keeps its drawer")
    v,_,freezer=vehicle("Base.Mov_ChestFreezer")
    freezer.box.cap=99
    V.syncFreezerSlot(v,V.UNIVERSAL_PART_ID)
    eq(freezer.box.cap,0,"a chest freezer has no extra drawer")
end)

test("the shared environment cools, freezes and heats by profile",function()
    local v,slot,freezer=vehicle("Base.Mov_ChestFreezer")
    V.refreshApplianceEnvironment(v,slot,true,true)
    near(slot.box.temp,0.1,"chest freezer main compartment");near(slot.box.age,0.0)
    v,slot,freezer=vehicle("Base.Mov_WhiteFridge")
    V.syncFreezerSlot(v,V.UNIVERSAL_PART_ID)
    V.refreshApplianceEnvironment(v,slot,true,true)
    near(slot.box.temp,0.2,"fridge");near(slot.box.age,V.getFridgeAgeFactor())
    near(freezer.box.temp,0.1,"fridge drawer");near(freezer.box.age,0.0)
    v,slot=vehicle("Base.Mov_GreenOven")
    slot.data.vlsMicrowaveActive=true;slot.data.vlsMicrowaveTemperature=500
    V.refreshApplianceEnvironment(v,slot,true,true)
    near(slot.box.temp,1+300/100,"oven clamps to its vanilla knob")
    v,slot=vehicle("Base.Mov_Microwave")
    slot.data.vlsMicrowaveActive=true;slot.data.vlsMicrowaveTemperature=500
    V.refreshApplianceEnvironment(v,slot,true,true)
    near(slot.box.temp,1+130/100,"microwave clamps to its vanilla knob")
end)

test("appliances install in the living space only",function()
    local v,slot=vehicle("Base.Mov_WhiteFridge")
    for _,t in ipairs({"Base.Mov_WhiteFridge","Base.Mov_ChestFreezer","Base.Mov_GreenOven",
            "Moveables.appliances_laundry_01_4","Moveables.appliances_laundry_01_12"})do
        eq(V.NativeSpace.ofType(t),"living",t)
        eq(V.isInstallationEnabled(slot,t),true,"living accepts "..t)
    end
end)

print("RESULT appliance executor tests="..n.." failures=0")
