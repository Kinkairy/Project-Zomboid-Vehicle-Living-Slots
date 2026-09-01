if isClient() then return end

local VLS = require "VLS_KI5Campers_Config"

local ADAPTER_MOD_ID = "VehicleLivingSlotsKI5Campers"
local REFILL_PROPANE_PER_TORCH_USE = 70

VLS.KI5Server = VLS.KI5Server or {}

local function roundPositive(value)
    return math.floor(value + 0.5)
end

function VLS.KI5Server.refillBlowTorch(player, args)
    if not player or not args or not args.vehicle or not args.part
            or not args.torch or player:getVehicle() then return false end
    local vehicle = getVehicleById(tonumber(args.vehicle))
    if not vehicle or not vehicle:isStopped()
            or not VLS.isSupportedVehicle(vehicle)
            or player:DistToProper(vehicle) >= 4 then return false end

    local propane, part = VLS.getInstalledPropaneSource(vehicle, args.part)
    if not propane or not part or part:getId() ~= args.part
            or not vehicle:isInArea(part:getArea(), player) then return false end

    local inventory = player:getInventory()
    local torch = inventory and inventory:getItemWithIDRecursiv(
        tonumber(args.torch)) or nil
    if not torch or torch:getFullType() ~= "Base.BlowTorch"
            or not instanceof(torch, "DrainableComboItem") then return false end

    local refillCapacity = torch:getMaxUses() * REFILL_PROPANE_PER_TORCH_USE
    local currentCapacity = torch:getCurrentUsesFloat() * refillCapacity
    local transfer = math.min(refillCapacity - currentCapacity,
        propane:getCurrentUses())
    if transfer <= 0 then return false end

    torch:setCurrentUsesFloat((currentCapacity + transfer) / refillCapacity)
    propane:setCurrentUses(roundPositive(propane:getCurrentUses() - transfer))
    torch:syncItemFields()
    propane:syncItemFields()
    vehicle:transmitPartUsedDelta(part)
    return true
end

local function onClientCommand(module, command, player, args)
    if module ~= ADAPTER_MOD_ID then return end
    if command == "refillBlowTorch" then
        VLS.KI5Server.refillBlowTorch(player, args)
    end
end

if not VLS.ki5CamperServerCommandHookApplied then
    VLS.ki5CamperServerCommandHookApplied = true
    Events.OnClientCommand.Add(onClientCommand)
end
