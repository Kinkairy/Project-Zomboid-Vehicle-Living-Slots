if isClient() then return end

require "VLS_Config"

print("[VehicleLivingSlots] Server version " .. VLS.VERSION)

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

-- Current command contract only. Invalid requests never mutate equipment.
local function isFiniteCommandNumber(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function isCommandId(value)
    return isFiniteCommandNumber(value) and value == math.floor(value)
end

local function rejectCommand(command, reason)
    print("[VLS 6ceb908-fix1] rejected " .. command .. ": " .. reason)
    return false
end

local function getMicrowavePart(player, args, command)
    if type(args) ~= "table" or not isCommandId(args.vehicle)
            or type(args.part) ~= "string" or args.part == ""
            or not isCommandId(args.item) then
        rejectCommand(command, "required_vehicle_part_item")
        return nil, nil
    end
    if command ~= "stopMicrowave" and
            (not isFiniteCommandNumber(args.timer)
            or not isFiniteCommandNumber(args.temperature)) then
        rejectCommand(command, "required_timer_temperature")
        return nil, nil
    end
    if command == "toggleMicrowave" and type(args.active) ~= "boolean" then
        rejectCommand(command, "required_active_boolean")
        return nil, nil
    end
    local vehicle = getPlayerVehicle(player, args)
    if not vehicle then
        rejectCommand(command, "not_in_supported_vehicle")
        return nil, nil
    end
    local part = VLS.getInstalledPart(vehicle, args.part)
    local item = part and part:getInventoryItem()
    if not item or VLS.getEquipmentCapability(item) ~= "cooking"
            or item:getID() ~= args.item then
        rejectCommand(command, "equipment_missing_or_replaced")
        return nil, nil
    end
    return vehicle, part
end

local function finiteNumber(value, fallback)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge
            or number == -math.huge then return fallback end
    return number
end

local function settleMicrowave(vehicle, part, currentHours)
    local data = part:getModData()
    local item = part:getInventoryItem()
    if not data.vlsMicrowaveActive or not item then return false end
    local previous = data.vlsMicrowaveLastHours
    if not previous or data.vlsMicrowaveClockItemId ~= item:getID()
            or previous > currentHours then
        -- Old saves have no clock. Establish a baseline, never charge a guessed minute.
        data.vlsMicrowaveLastHours = currentHours
        data.vlsMicrowaveClockItemId = item:getID()
        return true
    end
    local remaining = math.max(0, data.vlsMicrowaveRemaining or 0)
    local elapsedSeconds = math.min(remaining, math.max(0, currentHours - previous) * 3600)
    data.vlsMicrowaveLastHours = currentHours
    local drainPerMinute = VLS.getMicrowaveDrainPerMinute()
    local charge = VLS.getAuxBatteryCharge(vehicle)
    local poweredSeconds = elapsedSeconds
    if drainPerMinute > 0 then
        poweredSeconds = math.min(poweredSeconds, math.max(0, charge) / drainPerMinute * 60)
    end
    if poweredSeconds > 0 and drainPerMinute > 0 then
        VLS.consumeAuxBattery(vehicle, math.min(charge, poweredSeconds / 60 * drainPerMinute))
    end
    data.vlsMicrowaveRemaining = math.max(0, remaining - poweredSeconds)
    if data.vlsMicrowaveRemaining <= 0.000001
            or poweredSeconds + 0.000001 < elapsedSeconds then
        data.vlsMicrowaveActive = false
        data.vlsMicrowaveRemaining = 0
        data.vlsMicrowaveLastHours = nil
    end
    return elapsedSeconds > 0 or remaining == 0
end

local function clampMicrowaveSettings(args)
    local timer = math.max(0, math.min(3600, finiteNumber(args.timer, 0)))
    local temperature = math.max(50, math.min(130,
        finiteNumber(args.temperature, 90)))
    return timer, temperature
end

function VLS.Server.setMicrowaveParams(player, args)
    local vehicle, part = getMicrowavePart(player, args, "setMicrowaveParams")
    if not part then return false end

    local timer, temperature = clampMicrowaveSettings(args)
    settleMicrowave(vehicle, part, getGameTime():getWorldAgeHours())
    local data = part:getModData()
    data.vlsMicrowaveTimer = timer
    data.vlsMicrowaveTemperature = temperature
    if data.vlsMicrowaveActive then
        data.vlsMicrowaveRemaining = math.min(data.vlsMicrowaveRemaining or timer, timer)
        if data.vlsMicrowaveRemaining <= 0 then
            data.vlsMicrowaveActive = false
            data.vlsMicrowaveLastHours = nil
        end
    end
    VLS.refreshApplianceEnvironment(vehicle, part)
    VLS.Server.trackVehicle(vehicle)
    vehicle:transmitPartModData(part)
    return true
end

function VLS.Server.toggleMicrowave(player, args)
    local vehicle, part = getMicrowavePart(player, args, "toggleMicrowave")
    if not part then return false end
    local timer, temperature = clampMicrowaveSettings(args)
    settleMicrowave(vehicle, part, getGameTime():getWorldAgeHours())
    local data = part:getModData()
    -- The previous run may have expired during settlement. Honour the explicit
    -- requested state using the settled state, not a stale pre-settlement flag.
    local wasActive = data.vlsMicrowaveActive == true
    data.vlsMicrowaveTimer = timer
    data.vlsMicrowaveTemperature = temperature

    local desiredActive = args.active
    if not desiredActive then
        data.vlsMicrowaveActive = false
        data.vlsMicrowaveRemaining = 0
        data.vlsMicrowaveLastHours = nil
    elseif not wasActive and timer > 0
            and VLS.hasAuxBatteryPower(vehicle, VLS.getMicrowaveDrainPerMinute()) then
        data.vlsMicrowaveActive = true
        data.vlsMicrowaveRemaining = timer
        data.vlsMicrowaveLastHours = getGameTime():getWorldAgeHours()
        data.vlsMicrowaveClockItemId = part:getInventoryItem():getID()
        if vehicle.setNeedPartsUpdate then vehicle:setNeedPartsUpdate(true) end
    end

    VLS.refreshApplianceEnvironment(vehicle)
    VLS.Server.trackVehicle(vehicle)
    vehicle:transmitPartModData(part)
    return true
end

function VLS.Server.stopMicrowave(player, args)
    local vehicle, part = getMicrowavePart(player, args, "stopMicrowave")
    if not part then return false end
    local data = part:getModData()
    local changed = settleMicrowave(vehicle, part, getGameTime():getWorldAgeHours())
    if changed or data.vlsMicrowaveActive or (data.vlsMicrowaveRemaining or 0) ~= 0 then
        data.vlsMicrowaveActive = false
        data.vlsMicrowaveRemaining = 0
        data.vlsMicrowaveLastHours = nil
        VLS.refreshApplianceEnvironment(vehicle, part)
        vehicle:transmitPartModData(part)
    end
    VLS.Server.trackVehicle(vehicle)
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

-- Use snapshots only for failed commits; successful transfers remain native.
-- IsoObject reserve water is stored in these two native modData fields.
local function waterTransaction(vehicle, target, sourceFluid, sourceObject, operation)
    local copies, objects, temporaries = {}, {}, {}
    local batteryPart = VLS.getAuxBatteryPart(vehicle)
    local battery = batteryPart and batteryPart:getInventoryItem()
    local charge = battery and battery:getCurrentUsesFloat()
    local function keep(container)
        temporaries[#temporaries + 1] = container
        return container
    end
    local function snapshot(fluid)
        if not fluid then return end
        for _, entry in ipairs(copies) do if entry.fluid == fluid then return end end
        local entry = { fluid = fluid, before = keep(fluid:copy()), amounts = {} }
        local sample = fluid:createFluidSample()
        for index = 0, sample:size() - 1 do
            local kind = sample:getFluid(index)
            entry.amounts[#entry.amounts + 1] = { kind = kind,
                amount = fluid:getSpecificFluidAmount(kind) }
        end
        sample:release()
        -- An input-locked source can legally be drained. Temporarily unlock
        -- only to check/restore existing contents, preserving its actual flag.
        local locked = fluid:isInputLocked()
        fluid:setInputLocked(false)
        local restorable, err = pcall(function()
            for _, value in ipairs(entry.amounts) do
                assert(fluid:canAddFluid(value.kind), "source_contents_not_restorable")
            end
        end)
        fluid:setInputLocked(locked)
        if not restorable then error(err) end
        copies[#copies + 1] = entry
    end
    local function snapshotObject(object)
        if not object then return end
        for _, entry in ipairs(objects) do if entry.object == object then return end end
        local data = object:getModData()
        objects[#objects + 1] = { object = object,
            waterAmount = data.waterAmount, waterMaxAmount = data.waterMaxAmount }
        snapshot(object:getFluidContainer())
        if object:getUsesExternalWaterSource() then
            -- Both are public native APIs. Refresh and identify the same source
            -- before transferFluidTo can drain an external rain collector.
            object:doFindExternalWaterSource()
            snapshotObject(object:FindExternalWaterSource())
        end
    end
    local prepared, prepareError = pcall(function()
        snapshot(target)
        snapshot(sourceFluid)
        snapshotObject(sourceObject)
    end)
    local ok, moved, reason
    if prepared then ok, moved, reason = pcall(operation, keep)
    else ok, moved = false, prepareError end
    if not ok and prepared then
        local failures = {}
        local function restore(label, fn)
            local restored, err = pcall(fn)
            if not restored then failures[#failures + 1] = label .. ":" .. tostring(err) end
        end
        for _, entry in ipairs(copies) do
            restore("fluid", function()
                local locked = entry.fluid:isInputLocked()
                entry.fluid:setInputLocked(false)
                local restored, err = pcall(function()
                    entry.fluid:copyFluidsFrom(entry.before)
                    assert(math.abs(entry.fluid:getAmount() - entry.before:getAmount()) < 0.0001,
                        "restored_volume_mismatch")
                    for _, value in ipairs(entry.amounts) do
                        assert(math.abs(entry.fluid:getSpecificFluidAmount(value.kind) - value.amount) < 0.0001,
                            "restored_composition_mismatch")
                    end
                end)
                entry.fluid:setInputLocked(locked)
                if not restored then error(err) end
            end)
        end
        for _, entry in ipairs(objects) do
            restore("reserve", function()
                local data = entry.object:getModData()
                data.waterAmount, data.waterMaxAmount = entry.waterAmount, entry.waterMaxAmount
            end)
        end
        if battery then restore("battery", function() battery:setUsedDelta(charge) end) end
        print("[VLS 3.8.1] water transaction failed: " .. tostring(moved))
        if #failures > 0 then
            print("[VLS 3.8.1] WATER ROLLBACK FAILED: " .. table.concat(failures, ";"))
        end
        moved, reason = 0, #failures == 0 and "transaction_rolled_back" or "rollback_failed_see_server_log"
    end
    if not prepared then
        print("[VLS 3.8.1] water snapshot rejected: " .. tostring(prepareError))
        moved, reason = 0, "snapshot_failed_before_transfer"
    end
    -- Native object transfer may already have sent an intermediate update.
    -- Publish restored/final state after the transaction. A transport failure
    -- must not turn an already committed transfer into a rejected operation.
    for _, entry in ipairs(objects) do
        local synced, err = pcall(function()
            entry.object:sync()
            entry.object:transmitModData()
        end)
        if not synced then print("[VLS 3.8.1] water source sync failed: " .. tostring(err)) end
    end
    if batteryPart then
        local synced, err = pcall(function() vehicle:transmitPartUsedDelta(batteryPart) end)
        if not synced then print("[VLS 3.8.1] water battery sync failed: " .. tostring(err)) end
    end
    for _, container in ipairs(temporaries) do FluidContainer.DisposeContainer(container) end
    return moved, reason
end

local function reservePurificationPower(vehicle, amount)
    local cost = VLS.getWaterPurificationCost(amount)
    if cost <= 0 then return {} end
    local part = VLS.getAuxBatteryPart(vehicle)
    local item = part and part:getInventoryItem()
    if not item then return nil end
    local charge = item:getCurrentUsesFloat()
    if charge < cost then return nil end
    item:setUsedDelta(math.max(0, charge - cost))
    return { part = part, item = item, cost = cost }
end

local function finishPurificationPower(vehicle, reservation, accepted)
    if not reservation.item then return end
    local used = VLS.getWaterPurificationCost(accepted)
    local unused = math.max(0, reservation.cost - used)
    if unused > 0 then
        reservation.item:setUsedDelta(math.min(1,
            reservation.item:getCurrentUsesFloat() + unused))
    end
end

local function transferNormalizedWater(vehicle, source, target, requestedAmount)
    if not VLS.isPureWaterFluid(source) then return 0, "source_not_pure_water" end
    if target:getCapacity() <= target:getAmount() then return 0, "target_full" end
    local allowance = VLS.getWaterPurificationCapacity(vehicle)
    if allowance <= 0 then return 0, "no_aux_power" end
    local amount = math.max(0, math.min(finiteNumber(requestedAmount, 0),
        source:getAmount(), target:getCapacity() - target:getAmount(), allowance))
    if amount <= 0 then return 0, "zero_amount" end
    if not canAcceptNormalizedWater(target, amount) then
        return 0, "target_refuses_clean_water"
    end
    return waterTransaction(vehicle, target, source, nil, function(keep)
        local power = reservePurificationPower(vehicle, amount)
        if not power then return 0, "no_aux_power" end
        local normalized = keep(makeNormalizedWater(amount))
        local before = target:getAmount()
        FluidContainer.Transfer(normalized, target, amount)
        local added = math.max(0, target:getAmount() - before)
        if added > 0 then source:removeFluid(added) end
        finishPurificationPower(vehicle, power, added)
        if added <= 0 then return 0, "native_target_did_not_accept_water" end
        return added
    end)
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
    local ok, err = pcall(function()
    if not item then return end
    item:syncItemFields()
    if not part then return end
    if VLS.isWaterTankPart(part) then
        VLS.syncVehicleWaterTank(vehicle, part)
        vehicle:transmitPartModData(part)
    end
    vehicle:transmitPartItem(part)
    end)
    if not ok then print("[VLS 3.8.1] water endpoint sync failed: " .. tostring(err)) end
end

function VLS.Server.transferWaterStep(player, args)
    local vehicle = getPlayerVehicle(player, args)
    if not vehicle then return 0, "not_in_supported_vehicle" end

    local sourceItem, source, sourcePart = resolveFluidTransferEndpoint(
        player, vehicle, args.source)
    local targetItem, target, targetPart = resolveFluidTransferEndpoint(
        player, vehicle, args.target)
    if not sourceItem or not targetItem or not source or not target then
        return 0, "endpoint_missing_or_item_replaced"
    end
    if sourceItem == targetItem then return 0, "same_endpoint" end
    if not source:canPlayerEmpty() then return 0, "source_cannot_empty" end

    local amount = math.max(0, finiteNumber(args.amount, 0))
    if amount <= 0 then return 0, "zero_amount" end
    local moved, reason
    if VLS.isWaterTankPart(targetPart) then
        moved, reason = transferNormalizedWater(vehicle, source, target, amount)
        if moved <= 0 then return 0, reason or "no_volume_transferred" end
    else
        if not FluidContainer.CanTransfer(source, target) then return 0, "native_transfer_rejected" end
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
local completedFluidRequests = setmetatable({}, { __mode = "k" })

local function replyFluidTransfer(player, result)
    if isServer() then
        sendServerCommand(player, VLS.MOD_ID, "fluidTransferResult", result)
    elseif VLS.onFluidTransferResult then
        VLS.onFluidTransferResult(result)
    end
end

function VLS.Server.transferWater(player, args)
    if not player or type(args) ~= "table" then
        return rejectCommand("transferWater", "required_player_and_args")
    end
    local requestId = args.requestId
    if type(requestId) ~= "string" or #requestId == 0 or #requestId > 128 then
        return rejectCommand("transferWater", "required_requestId")
    end
    local function validEndpoint(endpoint)
        if type(endpoint) ~= "table" or not isCommandId(endpoint.item) then return false end
        if endpoint.kind == "inventory" then return true end
        return endpoint.kind == "vehicle" and type(endpoint.part) == "string"
            and endpoint.part ~= ""
    end
    local reason
    if not isCommandId(args.vehicle) then
        reason = "required_vehicle"
    elseif not validEndpoint(args.source) or not validEndpoint(args.target) then
        reason = "required_endpoint_kind_part_item"
    elseif args.source.kind ~= "vehicle" and args.target.kind ~= "vehicle" then
        reason = "vehicle_endpoint_required"
    elseif not isFiniteCommandNumber(args.amount) or args.amount <= 0 then
        reason = "required_positive_amount"
    end
    if reason then
        rejectCommand("transferWater", reason)
        replyFluidTransfer(player, { requestId = requestId, vehicle = args.vehicle,
            moved = 0, status = "rejected", reason = reason })
        return false
    end
    local now = getTimestampMs()
    local history = completedFluidRequests[player] or {}
    completedFluidRequests[player] = history
    for index = #history, 1, -1 do
        if now < history[index].time or now - history[index].time > 60000 then
            table.remove(history, index)
        end
    end
    for _, record in ipairs(history) do
        if record.result.requestId == requestId then
            replyFluidTransfer(player, record.result)
            return record.result.status == "ok"
        end
    end
    local ok, moved, reason = pcall(VLS.Server.transferWaterStep, player, args)
    if not ok then
        print("[VLS 6ceb908-fix1] water error: " .. tostring(moved))
        moved, reason = 0, "lua_error_see_server_log"
    end
    if (moved or 0) <= 0 then
        print("[VLS 6ceb908-fix1] water rejected: " .. tostring(reason or "no_volume_transferred"))
    end
    local result = { requestId = requestId, vehicle = args.vehicle,
        moved = moved or 0, status = ok and (moved or 0) > 0 and "ok" or "rejected",
        reason = reason }
    history[#history + 1] = { result = result, time = now }
    if #history > 32 then table.remove(history, 1) end
    replyFluidTransfer(player, result)
    return result.status == "ok"
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

    local moved = waterTransaction(vehicle, target, nil, source, function(keep)
        if not canAcceptNormalizedWater(target, amount) then return 0 end
        local staged = keep(target:copy())
        local normalized = keep(makeNormalizedWater(amount))
        local before = staged:getAmount()
        FluidContainer.Transfer(normalized, staged, amount)
        local planned = math.max(0, staged:getAmount() - before)
        if planned <= 0 then return 0 end
        local power = reservePurificationPower(vehicle, planned)
        if not power then return 0 end
        local captured = keep(FluidContainer.CreateContainer())
        captured:setCapacity(planned)
        source:transferFluidTo(captured, planned)
        local accepted = math.min(planned, math.max(0, captured:getAmount()))
        if accepted < planned then
            staged:copyFluidsFrom(target)
            local partial = keep(makeNormalizedWater(accepted))
            FluidContainer.Transfer(partial, staged, accepted)
        end
        if accepted > 0 then
            target:copyFluidsFrom(staged)
            assert(math.abs(target:getAmount() - staged:getAmount()) < 0.0001,
                "native_target_commit_mismatch")
        end
        finishPurificationPower(vehicle, power, accepted)
        return accepted
    end)
    if moved <= 0 then return 0 end

    syncFluidTransferEndpoint(vehicle, tank, part)
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

local coolingSnapshotEpoch = getTimestampMs()
local coolingSnapshotSequence = 0
local coolingSnapshotRequests = setmetatable({}, { __mode = "k" })

local function publishCoolingSnapshot(vehicle, part, recipient)
    if not isServer() or not part or not part:getItemContainer() then return end
    local recipients = {}
    if recipient then
        recipients[1] = recipient
    else
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player:getVehicle() == vehicle then recipients[#recipients + 1] = player end
        end
    end
    if #recipients == 0 then return end
    local entries = {}
    VLS.walkApplianceContainer(part:getItemContainer(), function(item)
        if instanceof(item, "Food") then
            entries[#entries + 1] = { id = item:getID(), age = item:getAge(),
                freezing = item:getFreezingTime(), heat = item:getHeat() }
        end
    end)
    coolingSnapshotSequence = coolingSnapshotSequence + 1
    local hours = getGameTime():getWorldAgeHours()
    -- Each command stays small; all chunks share one revision.
    for first = 1, math.max(1, #entries), 48 do
        local chunk = {}
        for i = first, math.min(first + 47, #entries) do chunk[#chunk + 1] = entries[i] end
        local args = { vehicle = vehicle:getId(), part = part:getId(),
            epoch = coolingSnapshotEpoch, sequence = coolingSnapshotSequence,
            hours = hours, entries = chunk }
        for _, player in ipairs(recipients) do
            sendServerCommand(player, VLS.MOD_ID, "coolingSnapshot", args)
        end
    end
end

function VLS.Server.requestCoolingSnapshot(player, args)
    local vehicle = getPlayerVehicle(player, args)
    if not vehicle or not args.part then return false end
    local part = vehicle:getPartById(args.part)
    local universal = part
    if part and VLS.isFreezerPart(part) then
        universal = vehicle:getPartById(VLS.UNIVERSAL_PART_BY_FREEZER[part:getId()])
    end
    if not universal or not VLS.isUniversalPart(universal)
            or VLS.getEquipmentCapability(universal:getInventoryItem()) ~= "cooling"
            or not VLS.hasAuxBatteryPower(vehicle, VLS.getFridgeDrainPerMinute()) then return false end
    local now = getTimestampMs()
    local requests = coolingSnapshotRequests[player] or {}
    coolingSnapshotRequests[player] = requests
    local last = requests[args.part]
    if last and now >= last and now - last < 1000 then return false end
    requests[args.part] = now
    publishCoolingSnapshot(vehicle, part, player)
    return true
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
            changed = settleMicrowave(vehicle, part, currentHours)
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
                publishCoolingSnapshot(vehicle, part)
                if freezerPart then publishCoolingSnapshot(vehicle, freezerPart) end
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

    VLS.refreshApplianceEnvironment(vehicle)
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

function VLS.Server.updateAppliance(vehicle, part, elapsedMinutes, forceRefresh, slotsSynced)
    if not VLS.isUniversalPart(part) then return end
    if VLS.getEquipmentCapability(part:getInventoryItem()) == "cooking"
            and settleMicrowave(vehicle, part, getGameTime():getWorldAgeHours()) then
        vehicle:transmitPartModData(part)
    end
    VLS.Server.trackVehicle(vehicle)
    VLS.refreshApplianceEnvironment(vehicle, part, forceRefresh, slotsSynced)
end

local commands = {
    setMicrowaveParams = VLS.Server.setMicrowaveParams,
    toggleMicrowave = VLS.Server.toggleMicrowave,
    stopMicrowave = VLS.Server.stopMicrowave,
    transferWater = VLS.Server.transferWater,
    fillWaterTank = VLS.Server.fillWaterTank,
    requestCoolingSnapshot = VLS.Server.requestCoolingSnapshot,
}

local function onClientCommand(module, command, player, args)
    if module ~= VLS.MOD_ID then return end
    local handler = commands[command]
    if handler and (args == nil or type(args) == "table") then handler(player, args or {}) end
end

if not VLS.serverHooksApplied then
    VLS.serverHooksApplied = true
    Events.OnClientCommand.Add(onClientCommand)
    Events.EveryOneMinute.Add(onEveryOneMinute)
end

print("[VLS 6ceb908-fix1] server loaded; current commands only")
