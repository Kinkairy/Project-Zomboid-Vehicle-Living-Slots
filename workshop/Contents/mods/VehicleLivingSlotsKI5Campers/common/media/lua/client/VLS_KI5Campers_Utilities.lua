local VLS = require "VLS_KI5Campers_Config"
require "Definitions/ContainerButtonIcons"
require "ISUI/ISInventoryPaneContextMenu"
require "Vehicles/ISUI/ISVehicleMenu"
require "Vehicles/ISUI/ISVehicleMechanics"
require "Vehicles/TimedActions/ISPathFindAction"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

local ADAPTER_MOD_ID = "VehicleLivingSlotsKI5Campers"

require "VLS_VehicleMechanicsIcons"
VLS.registerMechanicsUIProvider("ki5Propane", {
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
        if not vehicle or seen[vehicle] or not VLS.isSupportedVehicle(vehicle)
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

VLSRefillBlowTorchFromVehicleAction = ISBaseTimedAction:derive(
    "VLSRefillBlowTorchFromVehicleAction")

function VLSRefillBlowTorchFromVehicleAction:isValid()
    local inventory = self.character and self.character:getInventory()
    local torch = inventory and inventory:getItemWithIDRecursiv(self.torchId)
    local source, part = VLS.getInstalledPropaneSource(self.vehicle, self.partId)
    return torch and torch:getFullType() == "Base.BlowTorch"
        and torch:getCurrentUsesFloat() < 1 and source and part
        and not self.character:getVehicle() and self.vehicle:isStopped()
        and self.character:DistToProper(self.vehicle) < 4
        and self.vehicle:isInArea(part:getArea(), self.character)
end

function VLSRefillBlowTorchFromVehicleAction:update()
    self.character:faceThisObject(self.vehicle)
    self.character:setMetabolicTarget(Metabolics.LightWork)
    local torch = self.character:getInventory():getItemWithIDRecursiv(self.torchId)
    if torch then torch:setJobDelta(self:getJobDelta()) end
end

function VLSRefillBlowTorchFromVehicleAction:start()
    self:setActionAnim("Welding")
    self:setOverrideHandModels("Base.CraftingWeldingTorch",
        "Base.CraftingWeldingPipe")
    self.sound = self.character:playSound("CraftWelding")
end

function VLSRefillBlowTorchFromVehicleAction:stop()
    local torch = self.character:getInventory():getItemWithIDRecursiv(self.torchId)
    if torch then torch:setJobDelta(0) end
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

local function submitRefill(character, vehicle, partId, torchId)
    local args = { vehicle = vehicle:getId(), part = partId, torch = torchId }
    if isClient() then
        sendClientCommand(character, ADAPTER_MOD_ID, "refillBlowTorch", args)
    elseif VLS.KI5Server and VLS.KI5Server.refillBlowTorch then
        VLS.KI5Server.refillBlowTorch(character, args)
    end
end

function VLSRefillBlowTorchFromVehicleAction:perform()
    local torch = self.character:getInventory():getItemWithIDRecursiv(self.torchId)
    if torch then torch:setJobDelta(0) end
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    submitRefill(self.character, self.vehicle, self.partId, self.torchId)
    ISBaseTimedAction.perform(self)
end

function VLSRefillBlowTorchFromVehicleAction:new(character, vehicle, part,
        torch)
    local o = ISBaseTimedAction.new(self, character)
    o.vehicle = vehicle
    o.partId = part:getId()
    o.torchId = torch:getID()
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 50
    o.jobType = getText("Recipe_RefillBlowTorch")
    return o
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
        playerObj, vehicle, part, torch))
end

local function addVehiclePropaneRefillOption(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    local torch = findSelectedBlowTorch(items)
    if not torch then return end
    local vehicle, _, part = findNearbyPropaneSource(playerObj)
    if not part then return end
    context:addOption(getText("Recipe_RefillBlowTorch"), playerObj,
        queueVehicleRefill, vehicle, part, torch)
end

if not VLS.camperPropaneRefillMenuApplied then
    VLS.camperPropaneRefillMenuApplied = true
    Events.OnFillInventoryObjectContextMenu.Add(addVehiclePropaneRefillOption)
end
