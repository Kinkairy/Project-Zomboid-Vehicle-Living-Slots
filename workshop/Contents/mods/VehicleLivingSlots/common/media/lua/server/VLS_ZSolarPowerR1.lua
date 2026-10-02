-- Native car-battery-charger rules adapted to the existing auxiliary circuit.
-- This is NOT an IsoCarBatteryCharger world object or a new electricity grid.
if isClient() then return end
local S = require "VLS_ZSolarVisualR1"
local VLS = require "VLS_Config"
local old = VLS.SolarPowerR1
if old and old.tickHandler then Events.OnTick.Remove(old.tickHandler) end
local P = {states = setmetatable({}, {__mode = "k"}),
    warnings = setmetatable({}, {__mode = "k"})}
VLS.SolarPowerR1 = P
local FLOAT_MAX = 3.4028234663852886e38
local function finite(n)
    return type(n) == "number" and n == n and n >= 0 and n < math.huge
end
local function warn(key, text)
    if P.warnings[key] ~= text then
        P.warnings[key] = text
        print("[VLS SolarPower] " .. text)
    end
end
-- A unique float-only public native overload reproduces Java f32 conversion.
local function f32(value)
    return PZMath.clampFloat(value, 0, FLOAT_MAX)
end
local function rate()
    if P.rateAttempted then return P.rate end
    local cell = getCell()
    if not cell then return nil end
    P.rateAttempted = true
    local ok, value = pcall(function()
        local reference = IsoCarBatteryCharger.new(cell)
        -- No item/battery/square, activation, update, registration or persistence.
        assert(reference:getSquare() == nil and reference:getBattery() == nil
            and reference:getItem() == nil and not reference:isActivated()
            and reference:getObjectIndex() == -1, "charger reference is not detached")
        return reference:getChargeRate()
    end)
    if ok and finite(value) and value > 0 then
        P.rate = value
        print("[VLS SolarPower] native charger rate=" .. tostring(value) .. " per game hour")
    else
        warn("rate", "native charger default unavailable; solar charging disabled")
    end
    return P.rate
end
local function environment()
    local game = getGameTime()
    local climate = getClimateManager()
    local day = climate and climate:getCurrentDay()
    local season = day and day:getSeason()
    if not game or not season then return nil end
    local hours, clock = game:getWorldAgeHours(), getTimestampMs()
    local tod = game:getTimeOfDay()
    local dawn, dusk = season:getDawn(), season:getDusk()
    local clouds, precipitation = climate:getCloudIntensity(), climate:getPrecipitationIntensity()
    if not finite(hours) or not finite(clock) or not finite(tod) or tod >= 24
            or not finite(dawn) or not finite(dusk) or dawn >= dusk or dusk > 24
            or not finite(clouds) or clouds > 1 or not finite(precipitation)
            or precipitation > 1 then return nil end
    -- Native AEBS: cloud mean<=0.4 is Clear skies; here the same category
    -- threshold is applied to CURRENT cloud intensity, not forecast mean.
    return {hours=f32(hours), rawHours=hours, tod=tod, ms=clock,
        clear=tod >= dawn and tod < dusk and clouds <= 0.4 and precipitation == 0}
end
local function observe(part, env)
    local vehicle = part:getVehicle()
    if not vehicle or not vehicle:getSquare() or S.part(vehicle) ~= part then
        P.states[part] = nil; return nil
    end
    local rack = part:getInventoryItem()
    local batteryPart = VLS.getAuxBatteryPart(vehicle)
    local battery = batteryPart and batteryPart:getInventoryItem()
    if not battery or not instanceof(battery, "DrainableComboItem") then
        P.states[part] = nil; return nil
    end
    local epoch = S.powerTargetRevision and S.powerTargetRevision[part] or 0
    local state = P.states[part]
    if not state or state.rack ~= rack or state.rackId ~= rack:getID()
            or state.batteryPart ~= batteryPart or state.battery ~= battery
            or state.batteryId ~= battery:getID() then
        state = {vehicle=vehicle, rack=rack, rackId=rack:getID(),
            batteryPart=batteryPart, battery=battery, batteryId=battery:getID()}
        P.states[part] = state
    end
    local expanded = S.expanded(part)
    local clockBack = state.ms and env.ms < state.ms
    local hoursBack = state.rawHours and env.rawHours < state.rawHours
    -- Eligible daylight endpoints that wrap the clock, or span a whole day,
    -- include an unobserved night. Never credit that skipped interval.
    local crossedNight = state.rawHours and
        (env.rawHours-state.rawHours >= 24 or env.tod < state.tod)
    if state.optionRevision ~= S.optionRevision or state.epoch ~= epoch or state.expanded ~= expanded or clockBack then
        state.readyAt = expanded and env.ms + S.DURATION_MS or nil
        state.lastUpdate = nil
    end
    state.optionRevision = S.optionRevision
    state.epoch, state.expanded = epoch, expanded
    state.ms, state.hours = env.ms, env.hours
    state.rawHours, state.tod = env.rawHours, env.tod
    local current = battery:getCurrentUsesFloat()
    if not finite(current) or current > 1 then
        state.lastUpdate = nil; return nil
    end
    local eligible = S.enabled() and expanded and state.readyAt and env.ms >= state.readyAt
        and S.isStopped(vehicle) and env.clear and current < 1
    if not eligible then state.lastUpdate = nil; return nil end
    if hoursBack or crossedNight then state.lastUpdate = nil end
    -- Native checkHours: first activation starts now; backward time never earns.
    if state.lastUpdate == nil then state.lastUpdate = env.hours end
    return state
end
local function charge(part, state, env, nativeRate)
    local item = state.battery
    -- Re-read immediately before mutation: appliances may consume concurrently
    -- in the same game update. Never restore a previously captured charge.
    if VLS.getAuxBatteryPart(state.vehicle) ~= state.batteryPart
            or state.batteryPart:getInventoryItem() ~= item
            or part:getInventoryItem() ~= state.rack then
        P.states[part] = nil; return
    end
    local current, maximum = item:getCurrentUsesFloat(), item:getMaxUses()
    if not finite(current) or current >= 1 or not finite(maximum)
            or maximum < 1 or maximum ~= math.floor(maximum) then
        state.lastUpdate = nil; return
    end
    local previous = math.min(state.lastUpdate, env.hours)
    local elapsed = f32(env.hours - previous)
    if elapsed <= 0 then return end
    -- Exact native update arithmetic: fmul, fadd, min(1), fmul, then f2i.
    local gain = f32(nativeRate * elapsed)
    local target = math.min(1, f32(current + gain))
    local uses = math.floor(f32(f32(maximum) * target))
    local previousUses = item:getCurrentUses()
    item:setCurrentUses(uses)
    state.lastUpdate = env.hours -- even when native integer truncation earns zero
    if uses ~= previousUses then state.vehicle:transmitPartUsedDelta(state.batteryPart) end
end
function P.tick()
    if isClient() then return end
    if not S.enabled() then
        P.states = setmetatable({}, {__mode = "k"})
        return
    end
    local ok, env = pcall(environment)
    if not ok or not env then
        P.states = setmetatable({}, {__mode = "k"})
        warn("environment", "time/climate API unavailable; solar charging paused")
        return
    end
    P.warnings.environment = nil
    for part in pairs(P.states) do
        if not S.tracked[part] then P.states[part] = nil end
    end
    local nativeRate
    for part in pairs(S.tracked) do
        local success, err = pcall(function()
            local state = observe(part, env)
            if state then
                nativeRate = nativeRate or rate()
                if nativeRate then charge(part, state, env, nativeRate)
                else state.lastUpdate = nil end
            end
        end)
        if not success then
            P.states[part] = nil
            warn(part, "one rack paused: " .. tostring(err))
        else P.warnings[part] = nil end
    end
end
P.tickHandler = P.tick
Events.OnTick.Add(P.tickHandler)
print("[VLS SolarPower] native charger rules adapter READY; auxiliary battery only")
return P
