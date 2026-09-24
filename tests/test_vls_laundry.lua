local root = assert(arg[1])
local media = root .. "/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
package.loaded["Entity/TimedActions/ISHandcraftAction"] = true
package.loaded["TimedActions/ISDeviceBatteryAction"] = true
package.loaded["Vehicles/Vehicles"] = true
local V = dofile(media .. "shared/VLS_Config.lua")
package.loaded.VLS_Config = V
V.installGenericCraftSurfaceActionHooks = nil
local count = 0
local function test(name, fn) fn(); count = count + 1; print("PASS " .. name) end
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
function instanceof(item, kind) return item and item.kind == kind end

local combo = "Base.Mov_BlueComboWasherDryer"
for n = 0, 3 do
    test("combo facing " .. n, function()
        local item = {kind="Moveable", getFullType=function() return "Moveables.Furniture" end,
            getWorldSprite=function() return "appliances_laundry_01_" .. n end,
            getScriptItem=function() return nil end}
        eq(V.resolveEquipmentType(item), combo)
        eq(V.getEquipmentCapability(item), "laundryCombo")
        eq(V.getEquipmentProfile(item).capacity, 20)
    end)
end
test("all living-space variants accept only the combo laundry machine", function()
    for _, rel in ipairs({"VehicleLivingSlots/common/media/scripts/VLS_VanPatch.txt",
            "VehicleLivingSlots/common/media/scripts/VLS_StepVanWaterPatch.txt",
            "VehicleLivingSlotsKI5Campers/common/media/scripts/VLS_KI5CampersPatch.txt"}) do
        local f = assert(io.open(root .. "/workshop/Contents/mods/" .. rel))
        local source = f:read("*a"); f:close()
        assert(not source:find("Moveables.appliances_laundry_01_",1,true))
        local seen = 0
        for line in source:gmatch("[^\n]+") do
            if line:find("itemType",1,true) and line:find("Base.Mov_FridgeMini;",1,true) then
                assert(line:find(combo .. ";",1,true)); seen=seen+1
            end
        end
        assert(seen>0)
    end
    for _, n in ipairs({4,5,6,7,12,13,14,15}) do
        eq(V.getEquipmentProfileByType("Moveables.appliances_laundry_01_"..n),nil)
    end
end)

SandboxVars = {VehicleLivingSlots={}}
test("sandbox power and water defaults and overrides", function()
    eq(V.getComboWaterPerCycle(), 5)
    eq(V.getLaundryDrainPerMinute("laundryWasher"), 0.0004)
    eq(V.getLaundryDrainPerMinute("laundryDryer"), 0.0004)
    eq(V.getSmallApplianceDrainPerUse(), 0.0002)
    eq(V.getSmallApplianceDrainPerUse() * 10, V.getMicrowaveDrainPerMinute() * 5)
    local options = SandboxVars.VehicleLivingSlots
    options.ComboWaterPerCycle = 7
    options.ComboWashPowerConsumption = 0.8
    options.ComboDryPowerConsumption = 0.2
    options.SmallAppliancePowerConsumption = 0.6
    eq(V.getComboWaterPerCycle(), 7)
    eq(V.getLaundryDrainPerMinute("laundryWasher"), 0.0008)
    eq(V.getLaundryDrainPerMinute("laundryDryer"), 0.0008)
    eq(V.getComboDryPowerConsumption(), V.getComboWashPowerConsumption())
    eq(V.getSmallApplianceDrainPerUse(), 0.0006)
    options.ComboWaterPerCycle = nil
    options.ComboWashPowerConsumption = nil
    options.ComboDryPowerConsumption = nil
    options.SmallAppliancePowerConsumption = nil
end)

test("one combo switch prevents new installs without hiding installed equipment", function()
    local vehicle={getScriptName=function() return "Base.StepVan" end}
    local part={getVehicle=function() return vehicle end,
        getId=function() return V.UNIVERSAL_PART_ID end}
    local movable={kind="Moveable",getFullType=function() return combo end,
        getWorldSprite=function()return "appliances_laundry_01_0" end,
        getScriptItem=function()return nil end}
    SandboxVars.VehicleLivingSlots.EnableComboWasherDryers=false
    assert(not V.isInstallationEnabled(part,movable))
    eq(V.getEquipmentCapability(movable),"laundryCombo")
    SandboxVars.VehicleLivingSlots.EnableComboWasherDryers=nil
    local nativeTankLookup=V.getInstalledWaterTank
    local installedTank
    V.getInstalledWaterTank=function(v) assert(v==vehicle);return installedTank end
    assert(V.isInstallationEnabled(part,movable))
    assert(V.isInstallationEnabled(part,combo))
    assert(V.isAllowedItem(part,movable)) -- existing machine remains recognized
    installedTank={} -- tank need not already contain water to install
    assert(V.isInstallationEnabled(part,movable))
    assert(V.isInstallationEnabled(part,combo))
    installedTank=nil -- installation does not require a water supply
    assert(V.isInstallationEnabled(part,movable))
    V.getInstalledWaterTank=nativeTankLookup
end)

local events = {}
local function event(name)
    return {Add=function(fn) events[name] = fn end}
end
Events = {OnClientCommand=event("command"), EveryOneMinute=event("minute")}
isClient=function() return false end
isServer=function() return true end
getTimestampMs=function() return 1 end
getGameTime=function() return {getWorldAgeHours=function() return 10 end} end
local sent = 0
syncItemFields=function(player,item) assert(player and item);sent=sent+1 end
local lastPacket
local onlinePlayer
getOnlinePlayers=function()
    return {size=function()return onlinePlayer and 1 or 0 end,
        get=function()return onlinePlayer end}
end
sendServerCommand=function(_,module,command,args)
    lastPacket={module=module,command=command,args=args}
end
local charge, water = 1, 10
local fluid = {getAmount=function() return water end,
    removeFluid=function(_, amount) water = water - amount end}
local visual = {removeBlood=function(self) self.blood=false end,
    removeDirt=function(self) self.dirt=false end, blood=true, dirt=true}
local clothing = {kind="Clothing", id=99, blood=100, dirt=100, wet=0,
    getID=function(self)return self.id end,
    getVisual=function() return visual end,
    setBloodLevel=function(self,n) self.blood=n end,
    setDirtiness=function(self,n) self.dirt=n end,
    setWetness=function(self,n) self.wet=n end}
-- Public visual API used by the native washer; three distinct body regions.
visual.bloodParts={1,0.5,0};visual.dirtParts={1,0.25,0}
visual.getBlood=function(self,p)return self.bloodParts[p+1] end
visual.getDirt=function(self,p)return self.dirtParts[p+1] end
visual.setBlood=function(self,p,v)self.bloodParts[p+1]=v end
visual.setDirt=function(self,p,v)self.dirtParts[p+1]=v end
BloodBodyPartType={MAX={index=function()return 3 end},FromIndex=function(i)return i end}
BloodClothingType={
 calcTotalBloodLevel=function(i)i.blood=visual.bloodParts[1]*100 end,
 calcTotalDirtLevel=function(i)i.dirt=visual.dirtParts[1]*100 end}
clothing.getWetness=function(self)return self.wet end
local items = {size=function() return 1 end, get=function() return clothing end}
local container = {getItems=function() return items end}
local equipment = {kind="Moveable", full=combo, id=11, condition=100,
    getFullType=function(self) return self.full end,
    getWorldSprite=function(self) return self.full:match("%.(.*)$") end,
    getScriptItem=function() return nil end,
    getID=function(self) return self.id end,
    getCondition=function(self) return self.condition end}
local data = {}
local vehicle = {id=7, modSync=0, itemSync=0,
    getId=function(self) return self.id end,
    getScriptName=function() return "Base.StepVan" end,
    getSquare=function() return {} end,
    transmitPartModData=function(self) self.modSync=self.modSync+1 end,
    transmitPartItem=function(self) self.itemSync=self.itemSync+1 end}
local part = {getVehicle=function() return vehicle end,
    getId=function() return V.UNIVERSAL_PART_ID end,
    getInventoryItem=function() return equipment end,
    getItemContainer=function() return container end,
    getCondition=function() return 100 end,
    getModData=function() return data end}
local tankItem={getFluidContainer=function() return fluid end}
local tankPart={}
function vehicle:getPartById(id)
    if id == V.UNIVERSAL_PART_ID then return part end
end
getVehicleById=function(id) return id==7 and vehicle or nil end
local player={getVehicle=function() return vehicle end}
onlinePlayer=player
V.getInstalledPart=function(v,id) return v:getPartById(id) end
V.getInstalledWaterTank=function() return tankItem,tankPart end
V.isPureWaterFluid=function() return true end
V.syncVehicleWaterTank=function() return tankItem,fluid end
V.hasAuxBatteryPower=function(_, amount) return charge >= amount end
V.consumeAuxBattery=function(_, amount)
    if charge < amount then return false end
    charge=charge-amount;return true
end
V.refreshApplianceEnvironment=function() end
local profileMode
V.ensureUniversalContainerProfile=function(p)profileMode=V.getLaundryMode(p)end
dofile(media .. "server/VLS_ApplianceServer.lua")
local function toggle(active)
    return V.Server.toggleLaundry(player,{vehicle=7,part=V.UNIVERSAL_PART_ID,
        item=equipment.id,active=active})
end
test("washer rejects missing tank without changing clothes or draining power", function()
    local lookup=V.getInstalledWaterTank
    V.getInstalledWaterTank=function()return nil end
    local wet=clothing.wet
    assert(not toggle(true))
    eq(charge,1);eq(clothing.wet,wet);assert(not data.vlsLaundryActive)
    V.getInstalledWaterTank=lookup
end)
test("washer rejects insufficient water without draining battery", function()
    water=4.9
    assert(not toggle(true))
    eq(charge,1)
    water=10
end)
test("washer uses exactly five water and finishes wet clean clothing", function()
    assert(toggle(true))
    events.minute()
    eq(clothing.wet,100)
    assert(math.abs(clothing.blood-98)<0.00001)
    assert(math.abs(clothing.dirt-98)<0.00001)
    assert(math.abs(visual.bloodParts[2]-.48)<0.00001)
    assert(math.abs(visual.dirtParts[2]-.23)<0.00001)
    eq(visual.bloodParts[3],0);eq(visual.dirtParts[3],0)
    eq(sent,1);eq(data.vlsLaundryRemaining,89)
    for _=2,90 do events.minute() end
    assert(math.abs(water-5)<0.00001)
    assert(math.abs(charge-0.964)<0.00001)
    eq(clothing.blood,0);eq(clothing.dirt,0);eq(clothing.wet,100)
    eq(visual.blood,false);eq(visual.dirt,false)
    eq(data.vlsLaundryActive,false)
    assert(vehicle.modSync>0 and vehicle.itemSync>0 and sent>0)
    eq(lastPacket,nil) -- Native SyncItemFields replaces the custom replay packet.
    eq(sent,90)
end)
test("dryer finishes without any installed tank", function()
    local lookup=V.getInstalledWaterTank
    V.getInstalledWaterTank=function()return nil end
    assert(V.Server.setLaundryMode(player,{vehicle=7,part=V.UNIVERSAL_PART_ID,
        item=equipment.id,mode="dryer"}))
    eq(data.vlsLaundryMode,"laundryDryer")
    clothing.wet=100
    local beforeWater=water
    assert(toggle(true))
    events.minute();eq(clothing.wet,99)
    for _=2,90 do events.minute() end
    eq(water,beforeWater);eq(clothing.wet,0)
    V.getInstalledWaterTank=lookup
end)
test("lost power pauses and manual restart resumes remaining cycle", function()
    assert(V.Server.setLaundryMode(player,{vehicle=7,part=V.UNIVERSAL_PART_ID,
        item=equipment.id,mode="washer"}))
    water=10;charge=1
    assert(toggle(true))
    events.minute()
    local remaining=data.vlsLaundryRemaining
    charge=0
    local oldBlood=clothing.blood;local oldDirt=clothing.dirt;local oldWet=clothing.wet;local oldSent=sent
    events.minute()
    eq(clothing.blood,oldBlood);eq(clothing.dirt,oldDirt);eq(clothing.wet,oldWet);eq(sent,oldSent)
    eq(data.vlsLaundryActive,false);eq(data.vlsLaundryPaused,true)
    eq(data.vlsLaundryRemaining,remaining)
    charge=1
    assert(toggle(true))
    eq(data.vlsLaundryRemaining,remaining)
    for _=1,remaining do events.minute() end
    eq(data.vlsLaundryActive,false)
    assert(math.abs(water-5)<0.00001)
end)
test("repeated activation does not restart or double charge an active cycle",function()
    water=10;charge=1;assert(toggle(true));events.minute()
    local remaining=data.vlsLaundryRemaining;local before=charge
    assert(toggle(true));eq(data.vlsLaundryRemaining,remaining);eq(charge,before)
end)
test("mode change stops old cycle and repeated mode request preserves new cycle",function()
    local args={vehicle=7,part=V.UNIVERSAL_PART_ID,item=equipment.id,mode="dryer"}
    local beforeWater=water;assert(V.Server.setLaundryMode(player,args))
    eq(profileMode,"laundryDryer");eq(data.vlsLaundryActive,false)
    eq(data.vlsLaundryRemaining,0);eq(water,beforeWater)
    assert(toggle(true));events.minute();local remaining=data.vlsLaundryRemaining
    assert(V.Server.setLaundryMode(player,args));eq(data.vlsLaundryRemaining,remaining)
end)
test("bad mode and stale equipment descriptors do not mutate the machine",function()
    for _,mode in ipairs({"", "washing", {}, false}) do
        assert(not V.Server.setLaundryMode(player,{vehicle=7,part=V.UNIVERSAL_PART_ID,item=equipment.id,mode=mode}))
    end
    assert(not V.Server.setLaundryMode(player,{vehicle=7,part=V.UNIVERSAL_PART_ID,item=999,mode="washer"}))
    eq(data.vlsLaundryMode,"laundryDryer")
    local old=player.getVehicle;player.getVehicle=function()return nil end
    assert(not toggle(true));assert(not V.Server.setLaundryMode(player,{vehicle=7,part=V.UNIVERSAL_PART_ID,item=equipment.id,mode="washer"}))
    player.getVehicle=old
end)
test("broken or replaced machine stops without delivering a free cycle",function()
    equipment.condition=0;local before=charge;events.minute()
    eq(data.vlsLaundryActive,false);eq(charge,before);assert(not toggle(true))
    equipment.condition=100;assert(toggle(true));equipment.id=equipment.id+1
    events.minute();eq(data.vlsLaundryActive,false);eq(charge,before)
end)
test("water loss pauses washing and resumes only after replenishment",function()
    assert(V.Server.setLaundryMode(player,{vehicle=7,part=V.UNIVERSAL_PART_ID,item=equipment.id,mode="washer"}))
    water=10;charge=1;assert(toggle(true));events.minute();water=0
    local before=charge;local remaining=data.vlsLaundryRemaining;events.minute()
    eq(charge,before);eq(data.vlsLaundryRemaining,remaining);eq(data.vlsLaundryPaused,true)
    assert(not toggle(true));water=10;assert(toggle(true));eq(data.vlsLaundryRemaining,remaining)
end)
print("RESULT laundry tests=" .. count .. " failures=0")
