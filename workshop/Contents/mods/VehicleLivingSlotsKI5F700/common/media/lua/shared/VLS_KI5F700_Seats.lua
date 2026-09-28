-- Two real mechanics parts share one native passenger; never share inventory items.
local VLS = require "VLS_Config"
local A = require "VLS_KI5F700_Config"
require "VLS_InstallGuard"
if VLS.F700Seats then return VLS.F700Seats end
local S = {}
VLS.F700Seats = S
local registered = setmetatable({}, {__mode="k"})
local definitions = setmetatable({}, {__mode="k"})
local function pairsFor(vehicle)
    local profile = vehicle and VLS.getVehicleProfile(vehicle)
    return profile and profile.seatPairs or {}
end
function S.pair(part)
    local vehicle = part and part:getVehicle()
    if not vehicle or vehicle:getPartById(part:getId()) ~= part then return nil end
    for _, pair in ipairs(pairsFor(vehicle)) do
        if part:getId() == pair.seat or part:getId() == pair.living then return pair end
    end
end
local function empty(part)
    local container = part and part:getItemContainer()
    return not container or container:isEmpty()
end
local function occupied(vehicle, pair)
    local seat = vehicle:getScript():getPassengerIndex(pair.passenger)
    return seat < 0 or vehicle:getCharacter(seat) ~= nil
end
local function unboundDefinitions(script, pairs, blocked)
    local cached = definitions[script]
    if not cached then cached={};definitions[script]=cached end
    local key=blocked and "blocked" or "unbound"
    if cached[key] then return cached[key] end
    -- Part.makeCopy and container fields are NOT exposed to Kahlua. These
    -- public VehicleScript APIs make independent copies, verified on B42.20.
    local clone = VehicleScript.new()
    clone:setModule(script:getModule())
    local rows = {"vehicle VLSSeatBindings {"}
    for _, pair in ipairs(pairs) do
        for _, id in ipairs({pair.seat, pair.living}) do
            assert(script:getPartById(id), "missing paired seat definition: "..id)
            clone:copyPartsFrom(script, id)
            -- Native repair bypasses install tests, but skips an empty item type.
            -- Keep this on a private clone; restore the canonical allowed types
            -- as soon as the opposite part is empty. Loaded() must not append a
            -- mechanic suffix to the empty string (specificItem=false).
            rows[#rows+1] = "part "..id.." { "
                ..(blocked and "itemType = , specificItem = false, " or "")
                .."container { seat = VLS_Unbound, } }"
        end
    end
    rows[#rows+1] = "}"
    clone:Load("VLSSeatBindings", table.concat(rows, "\n"))
    clone:Loaded() -- no model, passengers or physics; every cloned seat resolves to -1
    cached[key] = clone
    return clone
end
function S.sync(vehicle)
    local pairs = pairsFor(vehicle)
    if #pairs == 0 then return end
    local script = vehicle:getScript()
    local unbound = unboundDefinitions(script, pairs)
    local blocked = unboundDefinitions(script, pairs, true)
    registered[vehicle] = true
    for _, pair in ipairs(pairs) do
        local seat, living = vehicle:getPartById(pair.seat), vehicle:getPartById(pair.living)
        if seat and living then
            -- Occupied opposites cannot be auto-filled by native addvehicle /
            -- repair, which do not call our install test. No old-save migration.
            local native = seat:getInventoryItem() ~= nil
            local equipped = living:getInventoryItem() ~= nil
            local seatDef = (native and script or equipped and blocked or unbound):getPartById(pair.seat)
            local livingDef = (native and blocked or script):getPartById(pair.living)
            if seat:getScriptPart() ~= seatDef then seat:setScriptPart(seatDef) end
            if living:getScriptPart() ~= livingDef then living:setScriptPart(livingDef) end
        end
    end
end
function S.canInstall(part, item)
    local pair = S.pair(part)
    if not pair then return true end
    local vehicle = part:getVehicle()
    local other = vehicle:getPartById(part:getId() == pair.seat and pair.living or pair.seat)
    if not other or part:getInventoryItem() or other:getInventoryItem()
            or not empty(part) or not empty(other) or occupied(vehicle,pair) then return false end
    if part:getId() == pair.living then
        if type(item) == "string" then return VLS.allowedItems[part:getId()][item] == true end
        return VLS.isAllowedItem(part,item)
    end
    local fullType = type(item) == "string" and item or item and item:getFullType()
    local types = part:getItemType()
    return fullType ~= nil and types ~= nil and types:contains(fullType)
end
local baseCanRemove = VLS.canUninstallManagedPart
function S.canRemove(part)
    local pair = S.pair(part)
    if not pair then return true end
    return part:getInventoryItem() ~= nil and empty(part)
        and not occupied(part:getVehicle(),pair) and baseCanRemove(part)
end
local baseEnabled = VLS.isInstallationEnabled
function VLS.isInstallationEnabled(part,item)
    return S.canInstall(part,item) and baseEnabled(part,item)
end
function VLS.canUninstallManagedPart(part)
    return S.canRemove(part) and baseCanRemove(part)
end
function S.installTest(vehicle,part,character)
    return S.pair(part) ~= nil and S.canInstall(part,part:getItemType():get(0))
        and Vehicles.InstallTest.Default(vehicle,part,character)
end
function S.uninstallTest(vehicle,part,character)
    return S.pair(part) ~= nil and S.canRemove(part)
        and Vehicles.UninstallTest.Default(vehicle,part,character)
end
function S.initSeat(vehicle) S.sync(vehicle) end
function S.completeSeat(vehicle) S.sync(vehicle) end
function S.initLiving(vehicle,part)
    S.sync(vehicle)
    VLS.Init.UniversalSlot(vehicle,part)
end
function S.updateLiving(vehicle,part,elapsed)
    S.sync(vehicle)
    VLS.Update.UniversalSlot(vehicle,part,elapsed)
end
function S.completeLiving(vehicle,part)
    S.sync(vehicle)
    VLS.PartComplete.UniversalSlot(vehicle,part)
end
-- VLS's install guard rechecks this module's isInstallationEnabled before
-- native completion consumes the item. Add the matching removal boundary.
local baseComplete = ISUninstallVehiclePart.complete
function ISUninstallVehiclePart:complete()
    if not S.canRemove(self.part) then return false end
    return baseComplete(self)
end
local baseAssignment = VLS.getSpaceAssignmentForSeat
function VLS.getSpaceAssignmentForSeat(vehicle,seat)
    for _,pair in ipairs(pairsFor(vehicle)) do
        if vehicle:getScript():getPassengerIndex(pair.passenger) == seat then
            S.sync(vehicle)
            local native = vehicle:getPartById(pair.seat)
            if native and native:getInventoryItem() then return nil end
            break
        end
    end
    return baseAssignment(vehicle,seat)
end
-- Rebuild bindings after streaming/replication as well as init and completion.
-- No modData or shared vehicle-script mutation is required or serialized.
Events.OnTick.Add(function()
    for vehicle in pairs(registered) do
        if vehicle:isRemovedFromWorld() then registered[vehicle]=nil else S.sync(vehicle) end
    end
end)
return S
