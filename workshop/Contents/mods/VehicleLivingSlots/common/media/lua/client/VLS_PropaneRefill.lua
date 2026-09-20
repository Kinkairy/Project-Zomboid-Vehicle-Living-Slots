local VLS = require "VLS_Propane"
require "Definitions/ContainerButtonIcons"
require "ISUI/ISInventoryPaneContextMenu"
require "Vehicles/ISUI/ISVehicleMenu"
require "Vehicles/ISUI/ISVehicleMechanics"
require "Vehicles/TimedActions/ISPathFindAction"
require "VLS_PropaneRefillAction"
require "TimedActions/ISTimedActionQueue"


require "VLS_VehicleMechanicsIcons"
VLS.registerMechanicsUIProvider("vehiclePropane", {
    matches=VLS.isPropaneTankPart,
    remaining=function(part) return part:getInventoryItem():getCurrentUsesFloat() end,
})

local function resolveInventoryItem(entry)
    if instanceof(entry, "InventoryItem") then return entry end
    return entry and entry.items and entry.items[1] or nil
end

local function findSelectedBlowTorch(items)
    for _, entry in ipairs(items or {}) do
        local item = resolveInventoryItem(entry)
        if item and item:getFullType() == "Base.BlowTorch"
                and instanceof(item, "DrainableComboItem")
                and item:getCurrentUsesFloat() < 1 then
            return item
        end
    end
    return nil
end

local function findNearbyPropaneSource(playerObj)
    if not playerObj or playerObj:getVehicle() then return nil end
    local seen = {}
    local function resolve(vehicle)
        -- Installed-input resolver covers roof-only vehicles as well as KI5 tanks.
        if not vehicle or seen[vehicle]
                or not vehicle:isStopped()
                or playerObj:DistToProper(vehicle) >= 4 then return nil end
        seen[vehicle] = true
        local source, part = VLS.getInstalledPropaneSource(vehicle)
        return source and vehicle or nil, source, part
    end

    local vehicle, source, part = resolve(
        ISVehicleMenu.getVehicleToInteractWith(playerObj))
    if vehicle then return vehicle, source, part end

    local cell = getCell()
    if not cell then return nil end
    local px, py, pz = math.floor(playerObj:getX()),
        math.floor(playerObj:getY()), math.floor(playerObj:getZ())
    for x = px - 2, px + 2 do
        for y = py - 2, py + 2 do
            local square = cell:getGridSquare(x, y, pz)
            vehicle, source, part = resolve(
                square and square:getVehicleContainer() or nil)
            if vehicle then return vehicle, source, part end
        end
    end
    return nil
end

local function queueVehicleRefill(playerObj, vehicle, part, torch)
    local path = ISPathFindAction:pathToVehicleArea(playerObj, vehicle,
        part:getArea())
    path:setOnFail(function(character)
        HaloTextHelper.addBadText(character,
            getText("IGUI_PlayerText_NoWayToFuelTankInlet"))
    end, playerObj)
    ISTimedActionQueue.add(path)
    ISTimedActionQueue.add(VLSRefillBlowTorchFromVehicleAction:new(
        playerObj, vehicle:getId(), part:getId(), torch:getID(),
        part:getInventoryItem():getID()))
end

local function addVehiclePropaneRefillOption(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    local torch = findSelectedBlowTorch(items)
    if not torch then return end
    local vehicle, _, part = findNearbyPropaneSource(playerObj)
    if not part then return end
    context:addOption(Translator.getRecipeName("RefillBlowTorch"), playerObj,
        queueVehicleRefill, vehicle, part, torch)
end

if not VLS.vehiclePropaneRefillMenuApplied then
    VLS.vehiclePropaneRefillMenuApplied = true
    Events.OnFillInventoryObjectContextMenu.Add(addVehiclePropaneRefillOption)
end
