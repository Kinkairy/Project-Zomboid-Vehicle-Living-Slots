if isClient() then return end

require "VLS_Config"
local NativeContext = require "VLS_NativeContext"

print("[VehicleLivingSlots] Server version " .. VLS.VERSION)

-- VLS_DIRECT_ORIGINAL_FIX_20260904_V2: server
if VLS.installGenericCraftSurfaceActionHooks then
    VLS.installGenericCraftSurfaceActionHooks()
end

VLS.Server = VLS.Server or {}

local trackedVehicles = {}
local cooledFood = {}

local function hasManagedAppliance(vehicle)
    if not (vehicle and VLS.getVehicleProfile(vehicle)) then return false end
    for _, partId in ipairs(VLS.NativeSpace.equipmentPartIds(vehicle)) do
        local part = VLS.getInstalledPart(vehicle, partId)
        local capability = part
            and VLS.getEquipmentCapability(part:getInventoryItem()) or nil
        if capability == "cooling" and VLS.hasAuxBatteryPower(vehicle,
                VLS.getFridgeDrainPerMinute()) then return true end
        if capability == "cooking"
                and part:getModData().vlsMicrowaveActive then
            return true
        end
        if capability == "laundryCombo"
                and part:getModData().vlsLaundryActive then return true end
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

local function isInstallationEpoch(value)
    return isCommandId(value) and value >= 0 and value < 2147483647
end

local function rejectCommand(command, reason)
    print("[VLS 3.8.9] rejected " .. command .. ": " .. reason)
    return false
end

local function getMicrowavePart(player, args, command)
    if type(args) ~= "table" or not isCommandId(args.vehicle)
            or type(args.part) ~= "string" or args.part == ""
            or not isInstallationEpoch(args.epoch) or not isCommandId(args.item) then
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
    local context = NativeContext.equipment(player, vehicle, args.part, args.item, "cooking", args.epoch)
    local part = context and context.part
    if not part then
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
    local poweredSeconds = math.min(elapsedSeconds,
        VLS.VehiclePower.capacity(vehicle, drainPerMinute) * 60)
    if poweredSeconds > 0 and drainPerMinute > 0 then
        VLS.consumeAuxBattery(vehicle, math.min(VLS.getAuxBatteryCharge(vehicle),
            poweredSeconds / 60 * drainPerMinute))
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

local function clampMicrowaveSettings(part, args)
    local limits = VLS.getCookingLimits(part)
    local timer = math.max(0, math.min(limits.maxTimer, finiteNumber(args.timer, 0)))
    local temperature = math.max(limits.minTemperature, math.min(limits.maxTemperature,
        finiteNumber(args.temperature, 90)))
    return timer, temperature
end

function VLS.Server.setMicrowaveParams(player, args)
    local vehicle, part = getMicrowavePart(player, args, "setMicrowaveParams")
    if not part then return false end

    local timer, temperature = clampMicrowaveSettings(part, args)
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
    local timer, temperature = clampMicrowaveSettings(part, args)
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

require("VLS_NativeWater").bind(VLS)

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
            sendItemStats(item)
        end
        return
    end

    if freezer and item:canBeFrozen() and state.freezing<100 then
        -- Native freezing makes fertilized eggs non-viable too.
        item:setFertilized(false)
    end
    state.age,state.freezing=VLS.getPoweredFoodProgress(item,state.age,
        state.freezing,elapsedHours,freezer)
    if math.abs(item:getFreezingTime() - state.freezing) > 0.000001 then
        item:setFreezingTime(state.freezing)
        changed = true
    end

    state.lastHours = currentHours
    if math.abs(item:getAge() - state.age) > 0.000001 then
        item:setAge(state.age)
        changed = true
    end
    if changed then
        item:setLastAged(currentHours)
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
    if type(args) ~= "table" or not isCommandId(args.vehicle)
            or type(args.part) ~= "string" or args.part == "" then return false end
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

-- Native map-machine updates require grid power and a world-object identity.
-- Keep one vehicle cycle/resource adapter; use native item fields and native
-- container/item packets, never a second client-side cleaning implementation.
local function syncLaundryItem(item)
    if not isServer() then return end
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        -- B42.20 syncItemFields(player, item) targets that player's connection.
        -- A nil player does NOT broadcast. The packet retains the vehicle
        -- container identity and includes clothing visuals, patches and fields.
        syncItemFields(players:get(index), item)
    end
end

local function replaceLaundryItem(container, item, fullType)
    local replacement = instanceItem(fullType)
    if not replacement then return false end
    container:Remove(item)
    container:AddItem(replacement)
    if isServer() then
        sendRemoveItemFromContainer(container, item)
        sendAddItemToContainer(container, replacement)
    end
    return true
end

-- B42.20 ClothingWasherLogic updates clothing each paid game minute:
-- wetness 100, and -2 percentage points of blood/dirt on each visual part.
-- Its helpers are private Java methods; use the same public visual setters
-- and native total calculators here. Dryer clothing loses one wetness point.
local function updateLaundryClothing(part, mode)
    local container = part:getItemContainer()
    if not container then return end
    local items = container:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if instanceof(item, "Clothing") then
            if mode == "laundryWasher" then
                local visual = item:getVisual()
                if visual then
                    for i = 0, BloodBodyPartType.MAX:index() - 1 do
                        local bodyPart = BloodBodyPartType.FromIndex(i)
                        local blood = visual:getBlood(bodyPart)
                        local dirt = visual:getDirt(bodyPart)
                        if blood > 0 then
                            visual:setBlood(bodyPart, math.max(0, blood - 0.02))
                        end
                        if dirt > 0 then
                            visual:setDirt(bodyPart, math.max(0, dirt - 0.02))
                        end
                    end
                    BloodClothingType.calcTotalBloodLevel(item)
                    BloodClothingType.calcTotalDirtLevel(item)
                end
                item:setWetness(100)
            else
                item:setWetness(math.max(0, item:getWetness() - 1))
            end
            syncLaundryItem(item)
        end
    end
end

local function finishLaundry(vehicle, part, mode)
    local container = part:getItemContainer()
    if not container then return end
    local items = container:getItems()
    -- Backward iteration permits native container replacements (wet towels,
    -- ItemAfterCleaning) without processing a new item twice.
    for index = items:size() - 1, 0, -1 do
        local item = items:get(index)
        if instanceof(item, "Clothing") then
            if mode == "laundryWasher" then
                local visual = item:getVisual()
                if visual then
                    visual:removeBlood()
                    visual:removeDirt()
                end
                item:setBloodLevel(0)
                item:setDirtiness(0)
                item:setWetness(100)
            else
                item:setWetness(0)
            end
            syncLaundryItem(item)
        elseif mode == "laundryWasher" then
            local replacement = item:getModData().ItemAfterCleaning
            if type(replacement) == "string" then
                replaceLaundryItem(container, item, replacement)
            elseif instanceof(item, "InventoryContainer") then
                item:setBloodLevel(0)
                syncLaundryItem(item)
            end
        elseif item:isWet() and item:getItemWhenDry() then
            if replaceLaundryItem(container, item, item:getItemWhenDry()) then
                item:setWet(false)
                getCell():addToProcessItemsRemove(item)
            end
        end
    end
end

local function processLaundry(vehicle, part, capability)
    local data = part:getModData()
    local item = part:getInventoryItem()
    if not data.vlsLaundryActive then return false end
    if not item or item:getID() ~= data.vlsLaundryItemId
            or item:getCondition() <= 0 or part:getCondition() <= 0 then
        data.vlsLaundryActive = false
        data.vlsLaundryPaused = false
        return true
    end
    local remaining = tonumber(data.vlsLaundryRemaining) or 0
    if remaining <= 0 or remaining > VLS.LAUNDRY_CYCLE_MINUTES then
        data.vlsLaundryActive = false
        data.vlsLaundryPaused = false
        return true
    end
    local power = VLS.getLaundryDrainPerMinute(capability)
    local tank, tankPart, fluid, waterStep
    if capability == "laundryWasher" then
        tank, tankPart = VLS.getInstalledWaterTank(vehicle)
        fluid = tank and tank:getFluidContainer()
        local budget = tonumber(data.vlsLaundryWaterBudget)
            or VLS.getComboWaterPerCycle()
        waterStep = remaining == 1
            and math.max(0, budget - (tonumber(data.vlsLaundryWaterSpent) or 0))
            or budget / VLS.LAUNDRY_CYCLE_MINUTES
    end
    if not VLS.hasAuxBatteryPower(vehicle, power)
            or (capability == "laundryWasher" and (not fluid
                or not VLS.isPureWaterFluid(fluid)
                or fluid:getAmount() + 0.0001 < waterStep)) then
        data.vlsLaundryActive = false
        data.vlsLaundryPaused = true
        return true
    end
    if not VLS.consumeAuxBattery(vehicle, power) then
        data.vlsLaundryActive = false
        data.vlsLaundryPaused = true
        return true
    end
    if waterStep and waterStep > 0 then
        fluid:removeFluid(waterStep)
        data.vlsLaundryWaterSpent =
            (tonumber(data.vlsLaundryWaterSpent) or 0) + waterStep
        VLS.syncVehicleWaterTank(vehicle, tankPart)
        vehicle:transmitPartModData(tankPart)
        vehicle:transmitPartItem(tankPart)
    end
    remaining = remaining - 1
    data.vlsLaundryRemaining = remaining
    if remaining > 0 then
        updateLaundryClothing(part, capability)
    end
    if remaining == 0 then
        finishLaundry(vehicle, part, capability)
        data.vlsLaundryActive = false
        data.vlsLaundryPaused = false
    end
    return true
end

function VLS.Server.toggleLaundry(player, args)
    if type(args) ~= "table" or not isCommandId(args.vehicle)
            or type(args.part) ~= "string" or args.part == ""
            or not isInstallationEpoch(args.epoch) or not isCommandId(args.item) or type(args.active) ~= "boolean" then
        return rejectCommand("toggleLaundry", "required_vehicle_part_item_active")
    end
    local vehicle = getPlayerVehicle(player, args)
    if not vehicle then return rejectCommand("toggleLaundry", "not_in_supported_vehicle") end
    local context = NativeContext.equipment(player, vehicle, args.part, args.item, "laundryCombo", args.epoch)
    local part, item = context and context.part, context and context.item
    if not part then
        return rejectCommand("toggleLaundry", "equipment_missing_or_replaced")
    end
    local data = part:getModData()
    local mode = VLS.getLaundryMode(part)
    if args.active then
        if item:getCondition() <= 0 or part:getCondition() <= 0 then
            return rejectCommand("toggleLaundry", "broken_equipment")
        end
        if data.vlsLaundryActive then return true end
        local power = VLS.getLaundryDrainPerMinute(mode)
        if not VLS.hasAuxBatteryPower(vehicle, power) then
            return rejectCommand("toggleLaundry", "no_aux_power")
        end
        local resume = data.vlsLaundryPaused == true
            and data.vlsLaundryItemId == item:getID()
            and type(data.vlsLaundryRemaining) == "number"
            and data.vlsLaundryRemaining > 0
        local budget = resume and (tonumber(data.vlsLaundryWaterBudget) or 0)
            or VLS.getComboWaterPerCycle()
        local spent = resume and (tonumber(data.vlsLaundryWaterSpent) or 0) or 0
        if mode == "laundryWasher" then
            local tank = VLS.getInstalledWaterTank(vehicle)
            local fluid = tank and tank:getFluidContainer()
            if not fluid or not VLS.isPureWaterFluid(fluid)
                    or fluid:getAmount() + 0.0001 < budget - spent then
                return rejectCommand("toggleLaundry", "insufficient_clean_water")
            end
        end
        data.vlsLaundryItemId = item:getID()
        data.vlsLaundryWaterBudget = budget
        data.vlsLaundryWaterSpent = spent
        data.vlsLaundryRemaining = resume and data.vlsLaundryRemaining
            or VLS.LAUNDRY_CYCLE_MINUTES
        data.vlsLaundryActive = true
        data.vlsLaundryPaused = false
    else
        data.vlsLaundryActive = false
        data.vlsLaundryPaused = false
        data.vlsLaundryRemaining = 0
    end
    vehicle:transmitPartModData(part)
    VLS.Server.trackVehicle(vehicle)
    return true
end

function VLS.Server.setLaundryMode(player, args)
    if type(args) ~= "table" or not isCommandId(args.vehicle)
            or type(args.part) ~= "string" or args.part == ""
            or not isInstallationEpoch(args.epoch) or not isCommandId(args.item)
            or (args.mode ~= "washer" and args.mode ~= "dryer") then
        return rejectCommand("setLaundryMode", "required_vehicle_part_item_mode")
    end
    local vehicle = getPlayerVehicle(player, args)
    local context = NativeContext.equipment(player, vehicle, args.part, args.item, "laundryCombo", args.epoch)
    local part = context and context.part
    if not part then
        return rejectCommand("setLaundryMode", "equipment_missing_or_replaced")
    end
    local mode = args.mode == "dryer" and "laundryDryer" or "laundryWasher"
    if VLS.getLaundryMode(part) == mode then return true end
    local supported = false
    for _, available in ipairs(VLS.getLaundryModes(part)) do
        if available == mode then supported = true end
    end
    if not supported then return rejectCommand("setLaundryMode", "mode_not_supported") end
    local data = part:getModData()
    -- Like the native combination machine, switching mode stops the old cycle.
    data.vlsLaundryMode = mode
    data.vlsLaundryActive = false
    data.vlsLaundryPaused = false
    data.vlsLaundryRemaining = 0
    data.vlsLaundryWaterBudget = nil
    data.vlsLaundryWaterSpent = nil
    VLS.ensureUniversalContainerProfile(part)
    vehicle:transmitPartModData(part)
    VLS.Server.trackVehicle(vehicle)
    return true
end

local function processTrackedVehicle(vehicle, elapsedMinutes, currentHours, seen)
    if not (vehicle and VLS.getVehicleProfile(vehicle)) then return end
    for _, partId in ipairs(VLS.NativeSpace.equipmentPartIds(vehicle)) do
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
                local profile = VLS.getEquipmentProfile(part:getInventoryItem())
                local freezerOnly = profile ~= nil and profile.freezerOnly == true
                processCooledContainer(part:getItemContainer(), currentHours,
                    vehicle:getId(), partId, freezerOnly, seen)
                local freezerPart = VLS.getFreezerPartForUniversal(vehicle, partId)
                processCooledContainer(freezerPart
                        and freezerPart:getItemContainer(), currentHours,
                    vehicle:getId(), freezerPart and freezerPart:getId()
                        or VLS.FREEZER_PART_BY_UNIVERSAL[partId], true, seen)
                publishCoolingSnapshot(vehicle, part)
                if freezerPart then publishCoolingSnapshot(vehicle, freezerPart) end
            end
        elseif capability == "laundryCombo"
                and data.vlsLaundryActive then
            changed = processLaundry(vehicle, part, VLS.getLaundryMode(part))
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
    toggleLaundry = VLS.Server.toggleLaundry,
    setLaundryMode = VLS.Server.setLaundryMode,
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

print("[VLS 3.8.9] server loaded; current commands only")
