-- One installed-water service. Native actions and real FluidContainers remain owners.
-- Existing purification behavior is retained explicitly; this is not a claim
-- that purification is an original game capability. No new saved water store.
local Context = require "VLS_NativeContext"
local NativeWater = {}
function NativeWater.bind(VLS)
    if isClient and isClient() then return nil end
    local Water = {}
-- Keep the installed item and vehicle-part mirrors synchronized after a
-- successful outside-source water-tank transfer.
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
    if not ok then
        print("[VLS 3.8.9] water endpoint sync failed: " .. tostring(err))
    end
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
    local powerSnapshot = VLS.VehiclePower.snapshot(vehicle)
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
        restore("battery", function()
            assert(VLS.VehiclePower.restore(powerSnapshot, true), "battery_changed")
        end)
        print("[VLS 3.8.9] water transaction failed: " .. tostring(moved))
        if #failures > 0 then
            print("[VLS 3.8.9] WATER ROLLBACK FAILED: " .. table.concat(failures, ";"))
        end
        moved, reason = 0, #failures == 0 and "transaction_rolled_back" or "rollback_failed_see_server_log"
    end
    if not prepared then
        print("[VLS 3.8.9] water snapshot rejected: " .. tostring(prepareError))
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
        if not synced then print("[VLS 3.8.9] water source sync failed: " .. tostring(err)) end
    end
    if powerSnapshot then
        local synced, err = pcall(function() VLS.VehiclePower.sync(vehicle, powerSnapshot.part) end)
        if not synced then print("[VLS 3.8.9] water battery sync failed: " .. tostring(err)) end
    end
    for _, container in ipairs(temporaries) do FluidContainer.DisposeContainer(container) end
    return moved, reason
end

local function reservePurificationPower(vehicle, amount)
    return VLS.VehiclePower.reserve(vehicle, VLS.getWaterPurificationCost(amount))
end

local function finishPurificationPower(vehicle, reservation, accepted)
    assert(VLS.VehiclePower.settle(reservation,
        VLS.getWaterPurificationCost(accepted)), "power_reservation_changed")
end

-- The original ISFluidTransferAction owns progress and transfer calculation.
-- Purification is the vehicle-specific policy: supply a temporary clean-water
-- view during that same native step, then debit only the accepted source volume.
function Water.runVehicleFluidAction(action, nativeOperation)
    local source, target, vehicle, _, targetPart = action:resolveEndpoints()
    if not source then return false end
    if not VLS.isWaterTankPart(targetPart) then
        nativeOperation(action)
        return true
    end
    local sourceFluid, targetFluid = source:getFluidContainer(), target:getFluidContainer()
    if not VLS.isPureWaterFluid(sourceFluid) then return false end
    local amount = math.max(0, math.min(action.amount, sourceFluid:getAmount(),
        targetFluid:getCapacity() - targetFluid:getAmount(),
        VLS.getWaterPurificationCapacity(vehicle)))
    if amount <= 0 or not canAcceptNormalizedWater(targetFluid, amount) then return false end
    local originalSource, originalTarget, originalStart = action.source,
        action.target, action.sourceStartAmount
    local moved, reason = waterTransaction(vehicle, targetFluid, sourceFluid, nil, function(keep)
        local power = reservePurificationPower(vehicle, amount)
        if not power then return 0, "no_aux_power" end
        local normalized = keep(makeNormalizedWater(amount))
        -- These views are local to this synchronous native invocation. Nothing
        -- is installed, serialized, moved to inventory or drawn in the world.
        action.source = { getOwner=function() return source:getOwner() end,
            getFluidContainer=function() return normalized end, sync=function() end }
        action.target = { getOwner=function() return target:getOwner() end,
            getFluidContainer=function() return targetFluid end, sync=function() end }
        action.sourceStartAmount = originalStart - sourceFluid:getAmount() + amount
        local before = targetFluid:getAmount()
        nativeOperation(action)
        local accepted = math.max(0, targetFluid:getAmount() - before)
        if accepted > 0 then sourceFluid:removeFluid(accepted) end
        finishPurificationPower(vehicle, power, accepted)
        return accepted
    end)
    action.source, action.target, action.sourceStartAmount = originalSource,
        originalTarget, originalStart
    -- Sync final committed/restored state, never a half-purified intermediate.
    for _, endpoint in ipairs({originalSource, originalTarget}) do
        local ok, err = pcall(function() endpoint:sync() end)
        if not ok then print("[VLS 3.8.9] fluid sync failed: " .. tostring(err)) end
    end
    return reason == nil
end

local function getOutsideWaterTankVehicle(player, args)
    if not VLS.isWaterTankShortcutEnabled() or not player or player:getVehicle() or not args or not args.vehicle then
        return nil
    end
    local vehicle = getVehicleById(args.vehicle)
    if not vehicle or not VLS.hasWaterTankCapability(vehicle)
            or not vehicle:isStopped() then
        return nil
    end
    if type(args.epoch) ~= "number" or args.epoch < 0
            or args.epoch ~= math.floor(args.epoch) then return nil end
    local context = Context.identity(vehicle, args.part, tonumber(args.tank), args.epoch)
    if not context then return nil end
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
    if not VLS.isWaterTankShortcutEnabled() or not player or player:getVehicle() or not vehicle or not tank or not part
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

function Water.transferWaterTankFillStep(player, part, source, amount, itemId, installationEpoch)
    local vehicle = part and part:getVehicle()
    if not vehicle or not VLS.hasWaterTankCapability(vehicle) then return 0 end
    local tank, resolvedPart = VLS.getInstalledWaterTank(vehicle,
        part and part:getId())
    if type(installationEpoch) ~= "number" or installationEpoch < 0
            or installationEpoch ~= math.floor(installationEpoch) or itemId == nil then return 0 end
    local context = Context.identity(vehicle, part:getId(), itemId, installationEpoch)
    if not context or context.item ~= tank or context.part ~= part
            or not tank or resolvedPart ~= part then return 0 end
    return transferWaterTankFillStep(player, vehicle, tank, part, source, amount)
end

function Water.fillWaterTank(player, args)
    local vehicle, tank, part = getOutsideWaterTankVehicle(player, args)
    if not vehicle then return false end
    local source = resolveWaterSource(args)
    if not source then return false end
    local moved = transferWaterTankFillStep(player, vehicle, tank, part,
        source, args.amount)
    if moved <= 0 then return false end
    return true
end

    VLS.NativeWater = Water
    VLS.Server.runVehicleFluidAction = Water.runVehicleFluidAction
    VLS.Server.transferWaterTankFillStep = Water.transferWaterTankFillStep
    VLS.Server.fillWaterTank = Water.fillWaterTank
    return Water
end
return NativeWater
