if isClient() then return end

require "VLS_Config"

-- VLS_DIRECT_ORIGINAL_FIX_20260904_V2: server
if VLS.installGenericCraftSurfaceActionHooks then
    VLS.installGenericCraftSurfaceActionHooks()
end

VLS.Server = VLS.Server or {}

local trackedVehicles = {}
local cooledFood = {}

local function hasManagedAppliance(vehicle)
    local profile = vehicle and VLS.getVehicleProfile(vehicle)
    if not profile then return false end
    for _, partId in ipairs(profile.universalParts) do
        local part = VLS.getInstalledPart(vehicle, partId)
        local capability = part
            and VLS.getEquipmentCapability(part:getInventoryItem()) or nil
        if capability == "cooling" then return true end
        if capability == "cooking"
                and part:getModData().vlsMicrowaveActive then
            return true
        end
        if capability == "television" then
            local deviceData = VLS.getTelevisionDeviceData(part)
            if deviceData and deviceData:getIsTurnedOn() then return true end
        end
    end
    return false
end

function VLS.Server.trackVehicle(vehicle)
    if vehicle and VLS.isSupportedVehicle(vehicle)
            and hasManagedAppliance(vehicle) then
        trackedVehicles[vehicle:getId()] = true
    elseif vehicle then
        trackedVehicles[vehicle:getId()] = nil
    end
end

local function getPlayerVehicle(player, args)
    if not player or not args or not args.vehicle then return nil end
    local vehicle = getVehicleById(args.vehicle)
    if not vehicle or player:getVehicle() ~= vehicle or not VLS.isSupportedVehicle(vehicle) then
        return nil
    end
    return vehicle
end

local function getMicrowavePart(player, args)
    local vehicle = getPlayerVehicle(player, args)
    if not vehicle then return nil, nil end
    local part
    if args.part then
        part = VLS.getInstalledPart(vehicle, args.part)
    else
        part = VLS.getInstalledCapabilityPart(vehicle, "cooking")
    end
    if part and VLS.getEquipmentCapability(part:getInventoryItem()) ~= "cooking" then
        part = nil
    end
    if not part then return nil, nil end
    return vehicle, part
end

local function clampMicrowaveSettings(args)
    local timer = math.max(0, math.min(3600, tonumber(args.timer) or 0))
    local temperature = math.max(50, math.min(130,
        tonumber(args.temperature) or tonumber(args.maxTemperature) or 90))
    return timer, temperature
end

function VLS.Server.setMicrowaveParams(player, args)
    local vehicle, part = getMicrowavePart(player, args)
    if not part then return false end

    local timer, temperature = clampMicrowaveSettings(args)
    local data = part:getModData()
    data.vlsMicrowaveTimer = timer
    data.vlsMicrowaveTemperature = temperature
    if data.vlsMicrowaveActive then
        data.vlsMicrowaveRemaining = math.min(data.vlsMicrowaveRemaining or timer, timer)
    end
    vehicle:transmitPartModData(part)
    return true
end

function VLS.Server.toggleMicrowave(player, args)
    local vehicle, part = getMicrowavePart(player, args)
    if not part then return false end

    local timer, temperature = clampMicrowaveSettings(args)
    local data = part:getModData()
    data.vlsMicrowaveTimer = timer
    data.vlsMicrowaveTemperature = temperature

    if data.vlsMicrowaveActive then
        data.vlsMicrowaveActive = false
        data.vlsMicrowaveRemaining = 0
    elseif timer > 0 and VLS.hasAuxBatteryPower(vehicle, VLS.getMicrowaveDrainPerMinute()) then
        data.vlsMicrowaveActive = true
        data.vlsMicrowaveRemaining = timer
        if vehicle.setNeedPartsUpdate then vehicle:setNeedPartsUpdate(true) end
    end

    VLS.refreshApplianceEnvironment(vehicle)
    VLS.Server.trackVehicle(vehicle)
    vehicle:transmitPartModData(part)
    return true
end

function VLS.Server.stopMicrowave(player, args)
    local vehicle, part = getMicrowavePart(player, args)
    if not part then return false end
    local data = part:getModData()
    if data.vlsMicrowaveActive or (data.vlsMicrowaveRemaining or 0) ~= 0 then
        data.vlsMicrowaveActive = false
        data.vlsMicrowaveRemaining = 0
        VLS.refreshApplianceEnvironment(vehicle)
        vehicle:transmitPartModData(part)
    end
    return true
end

local function getPortableFluidItem(player, itemId)
    local inventory = player and player:getInventory()
    local numericId = tonumber(itemId)
    if not inventory or not numericId then return nil end
    return inventory:getItemWithIDRecursiv(numericId)
end

local function makeNormalizedWater(amount)
    local container = FluidContainer.CreateContainer()
    container:setCapacity(amount)
    container:addFluid(Fluid.Water, amount)
    return container
end

local canAcceptNormalizedWater = VLS.canAcceptNormalizedWater

local function commitPurificationPower(vehicle, amount)
    local cost = VLS.getWaterPurificationCost(amount)
    if cost <= 0 then return true end
    local part = VLS.getAuxBatteryPart(vehicle)
    local item = part and part:getInventoryItem()
    if not item then return false end
    local charge = item:getCurrentUsesFloat()
    if charge + 0.000001 < cost then return false end
    item:setUsedDelta(math.max(0, charge - cost))
    vehicle:transmitPartUsedDelta(part)
    return true
end

local function addCapturedCleanWater(vehicle, captured, target)
    local moved = captured:getAmount()
    if moved <= 0 or not canAcceptNormalizedWater(target, moved) then return 0 end

    local normalized = makeNormalizedWater(moved)
    local before = target:getAmount()
    FluidContainer.Transfer(normalized, target, moved)
    local added = math.max(0, target:getAmount() - before)
    FluidContainer.DisposeContainer(normalized)
    if added <= 0 then return 0 end
    if not commitPurificationPower(vehicle, added) then return 0 end
    return added
end

local function transferNormalizedWater(vehicle, source, target, requestedAmount)
    if not VLS.isPureWaterFluid(source) then return 0 end
    local amount = math.max(0, math.min(tonumber(requestedAmount) or 0,
        source:getAmount(), target:getCapacity() - target:getAmount(),
        VLS.getWaterPurificationCapacity(vehicle)))
    if amount <= 0 or not canAcceptNormalizedWater(target, amount) then return 0 end

    local captured = FluidContainer.CreateContainer()
    captured:setCapacity(amount)
    if not FluidContainer.CanTransfer(source, captured) then
        FluidContainer.DisposeContainer(captured)
        return 0
    end
    FluidContainer.Transfer(source, captured, amount)
    local added = addCapturedCleanWater(vehicle, captured, target)
    FluidContainer.DisposeContainer(captured)
    return added
end

local function resolveFluidTransferEndpoint(player, vehicle, descriptor)
    if type(descriptor) ~= "table" then return nil end
    if descriptor.kind == "vehicle" then
        local item, part = VLS.getVehicleFluidItem(vehicle, descriptor.part)
        if not item or not part or item:getID() ~= tonumber(descriptor.item) then
            return nil
        end
        return item, item:getFluidContainer(), part
    end
    if descriptor.kind == "inventory" then
        local item = getPortableFluidItem(player, descriptor.item)
        return item, item and item:getFluidContainer() or nil, nil
    end
    return nil
end

local function syncFluidTransferEndpoint(vehicle, item, part)
    if not item then return end
    item:syncItemFields()
    if not part then return end
    if VLS.isWaterTankPart(part) then
        VLS.syncVehicleWaterTank(vehicle, part)
        vehicle:transmitPartModData(part)
    end
    vehicle:transmitPartItem(part)
end

function VLS.Server.transferWaterStep(player, args)
    local vehicle = getPlayerVehicle(player, args)
    if not vehicle then return 0 end

    local sourceItem, source, sourcePart = resolveFluidTransferEndpoint(
        player, vehicle, args.source)
    local targetItem, target, targetPart = resolveFluidTransferEndpoint(
        player, vehicle, args.target)
    if not sourceItem or not targetItem or sourceItem == targetItem
            or not source or not target or not source:canPlayerEmpty() then return 0 end

    local amount = math.max(0, tonumber(args.amount) or 0)
    if amount <= 0 then return 0 end
    local moved
    if VLS.isWaterTankPart(targetPart) then
        moved = transferNormalizedWater(vehicle, source, target, amount)
        if moved <= 0 then return 0 end
    else
        if not FluidContainer.CanTransfer(source, target) then return 0 end
        local before = source:getAmount()
        FluidContainer.Transfer(source, target, amount)
        moved = math.max(0, before - source:getAmount())
        if moved <= 0 then return 0 end
    end

    syncFluidTransferEndpoint(vehicle, sourceItem, sourcePart)
    syncFluidTransferEndpoint(vehicle, targetItem, targetPart)
    return moved
end

-- Installed vehicle endpoints cannot be serialized as vanilla fluid owners.
-- Keep their transfer in this one authoritative adapter; carried-container
-- transfers remain wholly owned by the vanilla timed-action path.
function VLS.Server.transferWater(player, args)
    return VLS.Server.transferWaterStep(player, args) > 0
end

local function getOutsideWaterTankVehicle(player, args)
    if not player or player:getVehicle() or not args or not args.vehicle then
        return nil
    end
    local vehicle = getVehicleById(args.vehicle)
    if not vehicle or not VLS.hasWaterTankCapability(vehicle)
            or not vehicle:isStopped() then
        return nil
    end
    local tank, part = VLS.getInstalledWaterTank(vehicle, args.part)
    if not tank or part:getId() ~= args.part
            or tank:getID() ~= tonumber(args.tank)
            or not VLS.isPlayerAtWaterTankInlet(vehicle, part, player) then
        return nil
    end
    return vehicle, tank, part
end

local function resolveWaterSource(args)
    local x, y, z = tonumber(args.sourceX), tonumber(args.sourceY),
        tonumber(args.sourceZ)
    local index = tonumber(args.sourceIndex)
    if not x or not y or not z or not index then return nil end
    local square = getCell():getGridSquare(x, y, z)
    local objects = square and square:getObjects()
    if not objects or index < 0 or index >= objects:size() then return nil end
    local source = objects:get(index)
    if not source or source:getObjectIndex() ~= index
            or VLS.getTankWaterSourceAmount(source) <= 0 then return nil end
    return source
end

local function transferWaterTankFillStep(player, vehicle, tank, part, source,
        requestedAmount)
    if not player or player:getVehicle() or not vehicle or not tank or not part
            or not source or not vehicle:isStopped()
            or not VLS.isPlayerAtWaterTankInlet(vehicle, part, player) then
        return 0
    end
    if not VLS.isWaterSourceNearTank(vehicle, part, source) then return 0 end
    local target = tank:getFluidContainer()
    local amount = math.max(0, math.min(tonumber(requestedAmount) or 0,
        VLS.getWaterTankFillAmount(vehicle, tank, source)))
    if amount <= 0 then return 0 end

    local captured = FluidContainer.CreateContainer()
    captured:setCapacity(amount)
    source:transferFluidTo(captured, amount)
    local moved = addCapturedCleanWater(vehicle, captured, target)
    FluidContainer.DisposeContainer(captured)
    if moved <= 0 then return 0 end

    if source.sync then source:sync() end
    VLS.syncVehicleWaterTank(vehicle, part)
    tank:syncItemFields()
    vehicle:transmitPartItem(part)
    vehicle:transmitPartModData(part)
    return moved
end

function VLS.Server.transferWaterTankFillStep(player, part, source, amount)
    local vehicle = part and part:getVehicle()
    if not vehicle or not VLS.hasWaterTankCapability(vehicle) then return 0 end
    local tank, resolvedPart = VLS.getInstalledWaterTank(vehicle,
        part and part:getId())
    if not tank or resolvedPart ~= part then return 0 end
    return transferWaterTankFillStep(player, vehicle, tank, part, source, amount)
end

function VLS.Server.fillWaterTank(player, args)
    local vehicle, tank, part = getOutsideWaterTankVehicle(player, args)
    if not vehicle then return false end
    local source = resolveWaterSource(args)
    if not source then return false end
    local moved = transferWaterTankFillStep(player, vehicle, tank, part,
        source, args.amount)
    if moved <= 0 then return false end
    return true
end

local function processCooledFood(item, currentHours, vehicleId, containerId,
        freezer, seen, targetHeat)
    if not instanceof(item, "Food") then return end

    local itemId = item:getID()
    seen[itemId] = true
    local state = cooledFood[itemId]
    if not state or state.vehicleId ~= vehicleId
            or state.containerId ~= containerId
            or currentHours < state.lastHours then
        state = {
            age = item:getAge(),
            freezing = item:getFreezingTime(),
            heat = item:getHeat(),
            lastHours = currentHours,
            vehicleId = vehicleId,
            containerId = containerId,
        }
        cooledFood[itemId] = state
    end

    local changed = VLS.preservePoweredFoodHeat(item, state, targetHeat)
    local elapsedHours = currentHours - state.lastHours
    if elapsedHours <= 0 then
        if changed then
            if item.syncItemFields then item:syncItemFields() end
            sendItemStats(item)
        end
        return
    end

    if freezer and item:canBeFrozen() then
        state.freezing = math.min(100,
            state.freezing + elapsedHours / 4 * 100)
    elseif state.freezing > 0 then
        -- Vanilla doubles the normal 1.5-hour thaw time in a powered fridge.
        state.freezing = math.max(0,
            state.freezing - elapsedHours / 3 * 100)
    end
    if math.abs(item:getFreezingTime() - state.freezing) > 0.000001 then
        item:setFreezingTime(state.freezing)
        changed = true
    end

    local ageFactor = state.freezing >= 100 and 0 or VLS.getFridgeAgeFactor()
    state.age = state.age + elapsedHours * VLS.getFoodRotSpeed()
        / 24 * ageFactor
    state.lastHours = currentHours
    if math.abs(item:getAge() - state.age) > 0.000001 then
        item:setAge(state.age)
        changed = true
    end
    if changed then
        item:setLastAged(currentHours)
        if item.syncItemFields then item:syncItemFields() end
        sendItemStats(item)
    end
end

local function processCooledContainer(container, currentHours, vehicleId,
        containerId, freezer, seen)
    if not container then return end
    local targetHeat = freezer and 0.1 or 0.2
    VLS.walkApplianceContainer(container, function(item)
        processCooledFood(item, currentHours, vehicleId, containerId,
            freezer, seen, targetHeat)
    end)
end

local function processTrackedVehicle(vehicle, elapsedMinutes, currentHours, seen)
    local profile = vehicle and VLS.getVehicleProfile(vehicle)
    if not profile then return end
    for _, partId in ipairs(profile.universalParts) do
        local part = vehicle:getPartById(partId)
        local capability = part
            and VLS.getEquipmentCapability(part:getInventoryItem()) or nil
        local data = part and part:getModData() or nil
        local changed = false

        if capability == "cooking" and data.vlsMicrowaveActive then
            local drain = VLS.getMicrowaveDrainPerMinute() * elapsedMinutes
            if VLS.consumeAuxBattery(vehicle, drain) then
                data.vlsMicrowaveRemaining = math.max(0,
                    (data.vlsMicrowaveRemaining or 0) - elapsedMinutes * 60)
                changed = true
                if data.vlsMicrowaveRemaining <= 0 then
                    data.vlsMicrowaveActive = false
                end
            else
                data.vlsMicrowaveActive = false
                data.vlsMicrowaveRemaining = 0
                changed = true
            end
        elseif capability == "cooling" then
            local drain = VLS.getFridgeDrainPerMinute() * elapsedMinutes
            if VLS.consumeAuxBattery(vehicle, drain) then
                processCooledContainer(part:getItemContainer(), currentHours,
                    vehicle:getId(), partId, false, seen)
                local freezerPart = VLS.getFreezerPartForUniversal(vehicle, partId)
                processCooledContainer(freezerPart
                        and freezerPart:getItemContainer(), currentHours,
                    vehicle:getId(), freezerPart and freezerPart:getId()
                        or VLS.FREEZER_PART_BY_UNIVERSAL[partId], true, seen)
            end
        elseif capability == "television" then
            local deviceData = VLS.getTelevisionDeviceData(part)
            if deviceData and deviceData:getIsTurnedOn() then
                local drain = VLS.getTelevisionDrainPerMinute() * elapsedMinutes
                if not VLS.consumeAuxBattery(vehicle, drain) then
                    deviceData:setIsTurnedOn(false)
                    vehicle:transmitPartItem(
                        VLS.getTelevisionDevicePart(part))
                end
            end
        end

        if changed then vehicle:transmitPartModData(part) end
    end

    for _, partId in ipairs(profile.universalParts) do
        local part = vehicle:getPartById(partId)
        if part then VLS.refreshApplianceEnvironment(vehicle, part, false) end
    end
end

local function onEveryOneMinute()
    local currentHours = getGameTime():getWorldAgeHours()
    local seen = {}
    for vehicleId in pairs(trackedVehicles) do
        local vehicle = getVehicleById(vehicleId)
        if vehicle and vehicle:getSquare() and hasManagedAppliance(vehicle) then
            processTrackedVehicle(vehicle, 1, currentHours, seen)
        else
            trackedVehicles[vehicleId] = nil
        end
    end
    for itemId in pairs(cooledFood) do
        if not seen[itemId] then cooledFood[itemId] = nil end
    end
end

function VLS.Server.updateAppliance(vehicle, part, elapsedMinutes, forceRefresh)
    if not VLS.isUniversalPart(part) then return end
    VLS.Server.trackVehicle(vehicle)
    VLS.refreshApplianceEnvironment(vehicle, part, forceRefresh)
end

local commands = {
    setMicrowaveParams = VLS.Server.setMicrowaveParams,
    toggleMicrowave = VLS.Server.toggleMicrowave,
    stopMicrowave = VLS.Server.stopMicrowave,
    transferWater = VLS.Server.transferWater,
    fillWaterTank = VLS.Server.fillWaterTank,
}

local function onClientCommand(module, command, player, args)
    if module ~= VLS.MOD_ID then return end
    local handler = commands[command]
    if handler then handler(player, args or {}) end
end

if not VLS.serverHooksApplied then
    VLS.serverHooksApplied = true
    Events.OnClientCommand.Add(onClientCommand)
    Events.EveryOneMinute.Add(onEveryOneMinute)
end
