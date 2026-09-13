require "VLS_RoofCargo"
VLS = VLS or {}
VLS.BodyArmor = VLS.BodyArmor or {}
local A = VLS.BodyArmor
VLSBodyArmor = A

local states = setmetatable({}, { __mode = "k" })
local registered = setmetatable({}, { __mode = "k" })
local tick = 0

A.parts = {
    VLSArmorWindshield = "Windshield", VLSArmorWindshieldRear = "WindshieldRear",
    VLSArmorWindowFrontLeft = "WindowFrontLeft", VLSArmorWindowFrontRight = "WindowFrontRight",
    VLSArmorWindowRearLeft = "WindowRearLeft", VLSArmorWindowRearRight = "WindowRearRight",
    VLSArmorWindowMiddleLeft = "WindowMiddleLeft", VLSArmorWindowMiddleRight = "WindowMiddleRight",
    VLSBumperFront = "EngineDoor", VLSBumperRear = { "TrunkDoor", "DoorRear" },
}

local function itemId(item) return item and item.getID and item:getID() or nil end
local function condition(part) return part and part:getCondition() or 0 end
local function isHost() return not (isClient and isClient()) end
local function stateFor(vehicle)
    local state = states[vehicle]
    if not state then state = { parts = setmetatable({}, { __mode = "k" }) }; states[vehicle] = state end
    return state
end
function A.IsPart(part) return part and A.parts[part:getId()] ~= nil end
-- Native checkDamage thresholds; native model visibility owns replication (flag0x40).
function A.DamageStage(armorPart)
    if not armorPart:getInventoryItem() then return nil end
    local current=armorPart:getInventoryItem():getCondition()
    return current<40 and 2 or current<60 and 1 or 0
end
function A.SyncDamageVisual(armorPart)
    local stage=A.DamageStage(armorPart)
    armorPart:setModelVisible("Armor",stage==0)
    armorPart:setModelVisible("ArmorDamage1",stage==1)
    armorPart:setModelVisible("ArmorDamage2",stage==2)
end
local function sourceFor(vehicle, armorPart)
    local configured = A.parts[armorPart:getId()]
    if type(configured) == "table" then
        for _, sourceId in ipairs(configured) do
            local source = vehicle:getPartById(sourceId)
            if source then return source end
        end
        return nil
    end
    return configured and vehicle:getPartById(configured) or nil
end
local function hasInstalledArmor(vehicle)
    for armorId in pairs(A.parts) do
        local part = vehicle:getPartById(armorId)
        if part and part:getInventoryItem() then return true end
    end
    return false
end
local function rebase(vehicle, armorPart)
    local source = sourceFor(vehicle, armorPart)
    stateFor(vehicle).parts[armorPart] = { armor = itemId(armorPart:getInventoryItem()), source = itemId(source and source:getInventoryItem()), condition = condition(source) }
end
function A.Register(vehicle, armorPart)
    if isHost() and vehicle and armorPart and armorPart:getInventoryItem() then registered[vehicle] = true end
end
function A.Create(vehicle, armorPart)
    A.SyncDamageVisual(armorPart)
    A.Register(vehicle, armorPart)
    if isHost() and armorPart:getInventoryItem() then rebase(vehicle, armorPart) end
end
function A.Init(vehicle, armorPart)
    A.SyncDamageVisual(armorPart)
    A.Register(vehicle, armorPart)
    if isHost() and armorPart:getInventoryItem() then rebase(vehicle, armorPart) end
end
function A.Update(vehicle, armorPart, elapsedMinutes) A.Register(vehicle, armorPart); A.SyncDamageVisual(armorPart) end
function A.InstallComplete(vehicle, armorPart)
    local result = Vehicles.InstallComplete.Default(vehicle, armorPart)
    A.SyncDamageVisual(armorPart)
    A.Register(vehicle, armorPart)
    if isHost() and armorPart:getInventoryItem() then rebase(vehicle, armorPart) end
    return result
end
function A.UninstallComplete(vehicle, armorPart, item)
    local result = Vehicles.UninstallComplete.Default(vehicle, armorPart, item)
    A.SyncDamageVisual(armorPart)
    local state = states[vehicle]
    if state then state.parts[armorPart] = nil end
    if vehicle and not hasInstalledArmor(vehicle) then registered[vehicle] = nil end
    return result
end
local function settle(vehicle, armorPart)
    local source = sourceFor(vehicle, armorPart)
    local armorItem = armorPart:getInventoryItem()
    local sourceItem = source and source:getInventoryItem()
    local old = stateFor(vehicle).parts[armorPart]
    if not old or old.armor ~= itemId(armorItem) or old.source ~= itemId(sourceItem) then rebase(vehicle, armorPart); return end
    local before, current, available = old.condition or 0, condition(source), condition(armorPart)
    if armorItem and sourceItem and current > 0 and current < before and available > 0 then
        local restored = math.min(before - current, available)
        source:setCondition(current + restored)
        armorPart:damage(restored)
        if source.getWindow and source:getWindow() then vehicle:transmitPartWindow(source) end
        vehicle:transmitPartCondition(source)
        vehicle:transmitPartItem(source)
        vehicle:transmitPartCondition(armorPart)
        if vehicle.updatePartStats then vehicle:updatePartStats() end
        if vehicle.updateBulletStats then vehicle:updateBulletStats() end
        if VLS.Damage and VLS.Damage.RebaseSource then VLS.Damage.RebaseSource(source) end
    end
    rebase(vehicle, armorPart)
end
local function onTick()
    if not isHost() then return end
    tick = tick + 1
    if tick % 6 ~= 0 then return end
    for vehicle in pairs(registered) do
        if not vehicle:getSquare() or not hasInstalledArmor(vehicle) then
            registered[vehicle] = nil
        else
            if VLS.Damage and VLS.Damage.Update then VLS.Damage.Update(vehicle) end
            for armorId in pairs(A.parts) do
                local armorPart = vehicle:getPartById(armorId)
                if armorPart and armorPart:getInventoryItem() then settle(vehicle, armorPart); A.SyncDamageVisual(armorPart) end
            end
        end
    end
end
if Events and Events.OnTick and not A.tickHooked then Events.OnTick.Add(onTick); A.tickHooked = true end
-- Permanent fitted parts share the existing rack fabrication transaction/actions.
local R=VLSRoofCargo
local function supported(part)
    local vehicle=part and part:getVehicle()
    return vehicle and vehicle:getScript() and R.vehicleScripts[vehicle:getScript():getFullName()]==true
end
for id in pairs(A.parts) do
    local bumper=string.find(id,"Bumper",1,true)~=nil
    R.fabricatedParts[id]={
        accepts=supported,
        itemType=bumper and "Base.VLSBumperArmor" or "Base.VLSWindowArmor",
        materials=bumper and {["Base.MetalBar"]=6,["Base.SmallSheetMetal"]=2,["Base.Screws"]=4}
            or {["Base.MetalBar"]=2,["Base.SmallSheetMetal"]=1,["Base.Screws"]=2},
        uses={["Base.BlowTorch"]=10,["Base.WeldingRods"]=bumper and 2 or 1},
        salvage=bumper and {{"MetalBar",6,15},{"SmallSheetMetal",2,15},{"Screws",4,25}}
            or {{"MetalBar",2,15},{"SmallSheetMetal",1,15},{"Screws",2,25}},
        onInstalled=A.InstallComplete,
        onDestroyed=A.UninstallComplete,
    }
end
return A
