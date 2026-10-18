-- Shared auxiliary-power boundary for native vehicle equipment.
-- Uses the installed battery itself; owns no saved charge or device simulation.
-- bind() keeps existing VLS API/table identity for current device adapters.
local NativePower = {}

function NativePower.bind(VLS)
VLS.VehiclePower = VLS.VehiclePower or {}
local VehiclePower = VLS.VehiclePower

local function finitePower(value)
    return type(value) == "number" and value == value
        and value >= 0 and value < math.huge
end

function VehiclePower.rate(displayValue)
    if not finitePower(displayValue) then return 0 end
    return displayValue / VLS.APPLIANCE_DRAIN_DISPLAY_SCALE
end

function VLS.getAuxBatteryPart(vehicle)
    return VLS.getInstalledPart(vehicle, VLS.AUX_BATTERY_PART_ID)
end

function VehiclePower.snapshot(vehicle)
    local part = VLS.getAuxBatteryPart(vehicle)
    local item = part and part:getInventoryItem()
    if not item then return nil end
    return { vehicle = vehicle, part = part, item = item,
        charge = item:getCurrentUsesFloat() }
end

local function writePower(snapshot, charge, deferSync)
    if isClient and isClient() then return false end
    if not snapshot or not finitePower(charge)
            or VLS.getAuxBatteryPart(snapshot.vehicle) ~= snapshot.part
            or snapshot.part:getInventoryItem() ~= snapshot.item then return false end
    charge = math.min(1, charge)
    if snapshot.item:getCurrentUsesFloat() ~= charge then
        snapshot.item:setUsedDelta(charge)
        if not deferSync then VehiclePower.sync(snapshot.vehicle, snapshot.part) end
    end
    return true
end

function VehiclePower.sync(vehicle, part)
    if isClient and isClient() then return end
    part = part or VLS.getAuxBatteryPart(vehicle)
    if part then vehicle:transmitPartUsedDelta(part) end
end

function VehiclePower.restore(snapshot, deferSync)
    return snapshot == nil or writePower(snapshot, snapshot.charge, deferSync)
end

function VehiclePower.charge(vehicle)
    local state = VehiclePower.snapshot(vehicle)
    return state and state.charge or 0
end

function VehiclePower.has(vehicle, required)
    required = required == nil and 0.0001 or required
    local state = VehiclePower.snapshot(vehicle)
    return finitePower(required) and state ~= nil and state.charge >= required
end

function VehiclePower.capacity(vehicle, rate)
    if not finitePower(rate) then return 0 end
    local state = VehiclePower.snapshot(vehicle)
    if not state then return 0 end
    return rate == 0 and math.huge or math.max(0, state.charge) / rate
end

function VehiclePower.consume(vehicle, amount)
    if not finitePower(amount) then return false end
    local state = VehiclePower.snapshot(vehicle)
    if not state then return false end
    -- Preserve established continuous-device behavior: an exhausted battery
    -- reaches zero and the caller stops the device on this false result.
    local sufficient = state.charge >= amount
    if not writePower(state, math.max(0, state.charge - amount)) then return false end
    return sufficient
end

function VehiclePower.reserve(vehicle, amount)
    if not finitePower(amount) or (isClient and isClient()) then return nil end
    if amount == 0 then return { cost = 0 } end
    local state = VehiclePower.snapshot(vehicle)
    if not state or state.charge < amount then return nil end
    if not writePower(state, state.charge - amount, true) then return nil end
    state.cost = amount
    return state
end

function VehiclePower.settle(reservation, used)
    if not reservation or reservation.settled or not finitePower(used)
            or used > reservation.cost + 0.000000001 then return false end
    used = math.min(used, reservation.cost)
    if reservation.cost == 0 then reservation.settled = true; return true end
    local charge = reservation.item:getCurrentUsesFloat()
    if not writePower(reservation, charge + reservation.cost - used, true) then return false end
    reservation.settled = true
    return true
end

    return VehiclePower
end

return NativePower
