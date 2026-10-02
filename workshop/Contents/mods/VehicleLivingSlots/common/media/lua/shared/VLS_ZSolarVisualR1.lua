-- B42.20 visual pilot. No battery, climate, vehicle physics or inventory writes.
require "VLS_RoofCargo"
VLS.SolarVisualR1 = VLS.SolarVisualR1 or {}
local S = VLS.SolarVisualR1
local R = VLSRoofCargo
local Motion = require "VLS_ZSolarMotion"
function S.enabled()
    local settings = SandboxVars and SandboxVars.VehicleLivingSlots
    local enabled = not settings or settings.EnableSolarPanel ~= false
    if S.lastEnabled ~= enabled then
        S.optionRevision = (S.optionRevision or 0) + 1
        S.lastEnabled = enabled
    end
    return enabled
end
S.BUILD = "solar-visual-r1"
S.REVISION = "persistent-r3-rigid"
S.STEPS = 24
S.DURATION_MS = 1200
S.BEHAVIOR = "parked-1200ms-r4"
-- Keep tracked part keys across reload; S.track rebuilds old transient states.
-- Saved boolean/item ID protocol stays R1.
S.tracked = S.tracked or setmetatable({}, {__mode = "k"})
local function nowMs()
    if type(getTimestampMs) == "function" then
        local ok, value = pcall(getTimestampMs)
        if ok and type(value) == "number" and value == value
                and value ~= math.huge and value ~= -math.huge then return value end
    end
    if not S.clockWarning then
        S.clockWarning = true
        print("[VLS SolarVisual] persistent-r3 clock unavailable; endpoint-only rendering")
    end
    return nil
end

-- At menu/init boundaries, record the actual rack state once per changed
-- state. Diagnostics never alter inventory, scripts, visibility or menu policy.
S.diagnostics = S.diagnostics or setmetatable({}, {__mode = "k"})
function S.diagnose(vehicle, source)
    if not vehicle then return end
    local ok, value = pcall(function()
        local script = vehicle:getScript()
        local name = script and script:getFullName() or "unknown"
        if not R.vehicleScripts or not R.vehicleScripts[name] then return nil end
        local part = vehicle:getPartById(R.fixedId)
        if not part then return "vehicle=" .. name .. " rack=missing" end
        local item = part:getInventoryItem()
        local types = part:getItemType()
        return "vehicle=" .. name
            .. " rack=" .. (item and item:getFullType() or "EMPTY")
            .. " area=" .. tostring(part:getArea())
            .. " itemTypeOK=" .. tostring(types ~= nil and types:contains(R.fixedType))
            .. " init=" .. tostring(part:getLuaFunction("init"))
            .. " update=" .. tostring(part:getLuaFunction("update"))
    end)
    if not ok then value = "audit-unavailable=" .. tostring(value) end
    if value and S.diagnostics[vehicle] ~= value then
        S.diagnostics[vehicle] = value
        print("[VLS SolarVisual rackfix1] " .. tostring(source) .. " " .. value)
    end
end

function S.part(vehicle)
    local part = vehicle and vehicle:getPartById(R.fixedId)
    if not part or not R.isPart(part) or not R.fixed(vehicle) then return nil end
    local solar = vehicle:getPartById("VLSSolarPanel")
    local kit = solar and solar:getInventoryItem()
    if not kit or kit:getFullType() ~= "Base.VLSSolarPanelKit" then return nil end
    local name = vehicle:getScript():getFullName()
    if name == "Base.SUV" or name:find("^Base%.PickUpVan")
            or name:find("^Base%.Van") or name:find("^Base%.StepVan") then
        return part
    end
    return nil
end

function S.expanded(part)
    local item = part and part:getInventoryItem()
    local data = part and part:getModData()
    return item ~= nil and data.vlsSolarVisualR1Expanded == true
        and data.vlsSolarVisualR1RackItem == item:getID()
end

-- Native isStopped includes a 0.8km/h threshold and gas-pedal state.
-- Our explicit 0.1km/h tolerance rejects coasting that the native helper allows.
function S.isStopped(vehicle)
    if not vehicle then return false end
    local ok, stopped, speed = pcall(function()
        return vehicle:isStopped(), vehicle:getCurrentAbsoluteSpeedKmHour()
    end)
    if ok and type(stopped) == "boolean" and type(speed) == "number"
            and speed == speed and speed >= 0 and speed < math.huge then
        -- 0.1f widened to double, matching the native float getter exactly.
        return stopped and speed <= 0.10000000149011612
    end
    if not S.motionWarning then
        S.motionWarning = true
        print("[VLS SolarVisual] stopped state unavailable; deployment disabled")
    end
    return false
end

-- Display eligibility is independent from the stopped-only operation gate.
function S.canShowControl(character, vehicle)
    local part = S.part(vehicle)
    if not S.enabled() or not character or character:isDead() or not part
            or vehicle:isRemovedFromWorld() then return false end
    local current = character:getVehicle()
    if current then return current == vehicle end
    return character:DistToProper(vehicle) < 4
        and math.floor(character:getZ()) == math.floor(vehicle:getZ())
end

function S.canControl(character, vehicle, desired)
    if not S.canShowControl(character, vehicle) then return false end
    local part = S.part(vehicle)
    if not S.enabled() then return false end
    -- Retain the authority gate and compatibility of explicit retraction.
    if (desired == true or (desired == nil and not S.expanded(part)))
            and not S.isStopped(vehicle) then return false end
    return true
end

-- Host-only, transient target epochs let the power gate see rapid toggles.
-- No new vehicle modData or network fields are introduced.
S.powerTargetRevision = S.powerTargetRevision or setmetatable({}, {__mode = "k"})
local function writeExpanded(part, desired)
    local item = part and part:getInventoryItem()
    if not item then return false end
    local rackItemId = item:getID()
    local data = part:getModData()
    if data.vlsSolarVisualR1Expanded == desired
            and data.vlsSolarVisualR1RackItem == rackItemId then return true end
    S.powerTargetRevision[part] = (S.powerTargetRevision[part] or 0) + 1
    data.vlsSolarVisualR1Expanded = desired
    data.vlsSolarVisualR1RackItem = rackItemId
    part:getVehicle():transmitPartModData(part)
    return true
end

local function retractForMotionUnsafe(vehicle, part)
    if not S.enabled() or isClient() or S.part(vehicle) ~= part or not S.expanded(part) then
        Motion.clear(part)
        return
    end
    if Motion.confirm(vehicle, part, nowMs()) then writeExpanded(part, false) end
end

local motionErrors = setmetatable({}, {__mode = "k"})
local function retractForMotion(vehicle, part)
    local ok, err = pcall(retractForMotionUnsafe, vehicle, part)
    if not ok then
        local text = tostring(err)
        if motionErrors[part] ~= text then
            motionErrors[part] = text
            print("[VLS SolarVisual] motion check failed: " .. text)
        end
    else
        motionErrors[part] = nil
    end
end

-- Existing request module and data fields are unchanged. Check movement before
-- the idempotent desired=true shortcut, including stale repeated packets.
function S.setExpanded(character, vehicle, rackItemId, desired)
    if isClient() or type(desired) ~= "boolean" or not S.canControl(character, vehicle, desired) then
        return false
    end
    local part = S.part(vehicle)
    if part:getInventoryItem():getID() ~= rackItemId then return false end
    local result = writeExpanded(part, desired)
    S.track(part)
    return result
end

-- Native fixed clips drive five bones; four static children retain the atlas.
-- The case and fixed inner rails remain a static model on the original rack.
S.VISUAL_IDS = {"VLSSolarR3Driver", "VLSSolarR3Left", "VLSSolarR3Right",
    "VLSSolarR3MiddleLeft", "VLSSolarR3MiddleRight"}
S.HOLD_RETRY_MS = 1000
local function visualParts(vehicle)
    local result = {}
    for index, id in ipairs(S.VISUAL_IDS) do result[index] = vehicle:getPartById(id) or false end
    return result
end
local function sameParts(a, b)
    if not a then return false end
    for index = 1, #S.VISUAL_IDS do if a[index] ~= b[index] then return false end end
    return true
end
local function hideVisual(parts)
    if not parts then return end
    -- Native attachment transforms dereference their parent without a null guard.
    for index = #S.VISUAL_IDS, 1, -1 do
        if parts[index] then parts[index]:setModelVisible(S.VISUAL_IDS[index], false) end
    end
end
local function preflight(parts)
    local models = {}
    for index, id in ipairs(S.VISUAL_IDS) do
        local part = parts[index]
        if not part then return nil, "missing visual part " .. id .. "; cold load required" end
        local script = part:getScriptPart()
        local model = script and script:getModelById(id)
        if not model or script:getModelCount() ~= 1 then return nil, "invalid model binding " .. id end
        if index > 1 and part:getParent() ~= parts[1] then return nil, "invalid parent " .. id end
        models[index] = model
    end
    for pose = 0, S.STEPS do
        if not parts[1]:getAnimById("Pose" .. pose) then return nil, "missing anim definition " .. pose end
    end
    return models
end
local function warn(state, message)
    if state.warning ~= message then
        state.warning = message
        print("[VLS SolarVisual persistent-r3] " .. tostring(message))
    end
end
local function playPose(vehicle, state, now)
    if isServer() or state.failed or not state.installed or not state.enabled then return end
    local ok, err = pcall(function() vehicle:playPartAnim(state.visualParts[1], "Pose" .. state.pose) end)
    if not ok then
        state.failed = true
        warn(state, "native animation call failed: " .. tostring(err))
        return
    end
    -- A void return is NOT a readiness acknowledgement. A bounded-rate paused
    -- clip retry recovers a delayed importer / released animation player.
    -- It never changes visibility or uses private Java reflection.
    state.displayPose, state.lastClipMs = state.pose, now
    state.retryFrames = 0
end
local function reconcile(part, state, parts)
    local vehicle = part:getVehicle()
    if not sameParts(state.visualParts, parts) then hideVisual(state.visualParts) end
    state.visualParts = parts
    state.failed, state.warning = nil, nil
    part:setModelVisible("VLSSolarR1Case", state.installed and state.enabled)
    if not state.installed or not state.enabled then hideVisual(parts); state.displayPose = nil; return end
    local models, errorText = preflight(parts)
    if not models then
        hideVisual(parts); state.failed = true; warn(state, errorText); return
    end
    -- Driver part has exactly one model. It must be inserted before any child;
    -- the engine walks its model list in insertion order, without topology sort.
    local driverInfo = vehicle:setModelVisible(parts[1], models[1], true)
    if not driverInfo then
        hideVisual(parts); state.failed = true; warn(state, "driver ModelInfo unavailable"); return
    end
    for index = 2, #parts do
        if not vehicle:setModelVisible(parts[index], models[index], true) then
            hideVisual(parts); state.failed = true; warn(state, "child ModelInfo unavailable"); return
        end
    end
    state.driverInfo = driverInfo -- opaque identity only; no unexposed field access
    playPose(vehicle, state, state.lastMs)
end

local function trackInternal(part, forceReconcile)
    if not part then return end
    local vehicle = part:getVehicle()
    if not vehicle or vehicle:getPartById(R.fixedId) ~= part then return end
    local installed = S.part(vehicle) == part
    if installed then retractForMotion(vehicle, part) end
    local item = installed and part:getInventoryItem() or nil
    local itemId = item and item:getID() or false
    local state = S.tracked[part]
    local parts = visualParts(vehicle)
    if not state or state.itemId ~= itemId or state.revision ~= S.REVISION then
        if state then hideVisual(state.visualParts) end
        local target = S.expanded(part) and S.STEPS or 0
        state = {revision = S.REVISION, itemId = itemId, itemRef = item,
            target = target, pose = target, position = target, lastMs = nowMs(), installed = installed}
        S.tracked[part] = state
        forceReconcile = true
    elseif state.itemRef ~= item or state.installed ~= installed then
        state.itemRef, state.installed = item, installed
        forceReconcile = true
    end
    local enabled = S.enabled()
    if state.enabled ~= enabled then
        state.enabled = enabled
        -- Visibility is transient; never overwrite installation or saved pose.
        local target = S.expanded(part) and S.STEPS or 0
        state.target, state.pose, state.position = target, target, target
        state.lastMs, state.displayPose = nowMs(), nil
        forceReconcile = true
    end
    if not sameParts(state.visualParts, parts) then forceReconcile = true end
    if forceReconcile then
        local ok, err = pcall(reconcile, part, state, parts)
        if not ok then
            state.failed = true
            warn(state, "visual initialization failed: " .. tostring(err))
        end
    end
end

-- A visual failure must not change the success/return path of an existing
-- rack installation or initialization callback after its original work completed.
S.trackErrors = S.trackErrors or setmetatable({}, {__mode = "k"})
function S.track(part, forceReconcile)
    if not part then return end
    local ok, err = pcall(trackInternal, part, forceReconcile)
    if not ok then
        local state = S.tracked[part]
        if state then state.failed = true end
        local text = tostring(err)
        if S.trackErrors[part] ~= text then
            S.trackErrors[part] = text
            print("[VLS SolarVisual persistent-r3] tracking failed: " .. text)
        end
    else
        S.trackErrors[part] = nil
    end
end

function S.refresh()
    if isServer() then return end
    local now = nowMs()
    local pendingParts
    for part, state in pairs(S.tracked) do
        local vehicle = part:getVehicle()
        if not vehicle or not vehicle:getSquare() then
            S.tracked[part] = nil
        elseif vehicle:getPartById(R.fixedId) ~= part then
            hideVisual(state.visualParts)
            S.tracked[part] = nil
            local current = vehicle:getPartById(R.fixedId)
            if current then pendingParts = pendingParts or {}; pendingParts[current] = true end
        else
            S.track(part)
            state = S.tracked[part]
            local target = S.expanded(part) and S.STEPS or 0
            if not now then
                state.position, state.lastMs = target, nil
            else
                local elapsed = state.lastMs and math.max(0, now - state.lastMs) or 0
                state.lastMs = now
                local distance = elapsed * S.STEPS / S.DURATION_MS
                if state.position < state.target then state.position = math.min(state.target, state.position + distance)
                elseif state.position > state.target then state.position = math.max(state.target, state.position - distance) end
            end
            if math.abs(state.position - state.target) < 1e-9 then state.position = state.target end
            state.target = target
            state.pose = math.floor(state.position + 0.5)
            if state.position > 0 and state.position < S.STEPS then
                state.pose = math.max(1, math.min(S.STEPS - 1, state.pose))
            end
            state.retryFrames = (state.retryFrames or 0) + 1
            local retry = now and (not state.lastClipMs or now < state.lastClipMs
                or now - state.lastClipMs >= S.HOLD_RETRY_MS)
            if state.displayPose ~= state.pose or retry or (not now and state.retryFrames >= 60) then
                playPose(vehicle, state, now)
            end
        end
    end
    if pendingParts then for part in pairs(pendingParts) do S.track(part, true) end end
end

function S.InitVisual(vehicle, part)
    if not vehicle then return end
    local rack = vehicle:getPartById(R.fixedId)
    if rack then S.track(rack, true) end
end

-- Dedicated servers must own the same logical model list as clients. Native
-- flags=64 packets remove every client model absent from that authoritative list.
-- Only already-initialized racks are checked; there is no world vehicle scan.
-- Headless setModelVisible updates native lists/flags, not an animation player.
function S.refreshAuthority()
    if isClient() then return end
    local now = nowMs()
    S.authorityFrames = (S.authorityFrames or 0) + 1
    local lifecycleDue = not now and S.authorityFrames >= 6
        or now and (not S.authorityLastMs or now < S.authorityLastMs
            or now - S.authorityLastMs >= 100)
    if lifecycleDue then S.authorityLastMs, S.authorityFrames = now, 0 end
    local pendingParts
    for part, state in pairs(S.tracked) do
        local vehicle = part:getVehicle()
        if not vehicle or not vehicle:getSquare() then
            S.tracked[part] = nil
        elseif vehicle:getPartById(R.fixedId) ~= part then
            hideVisual(state.visualParts)
            S.tracked[part] = nil
            local current = vehicle:getPartById(R.fixedId)
            if current then pendingParts = pendingParts or {}; pendingParts[current] = true end
        else
            -- Observe motion every authority tick, even between the existing
            -- 100ms installation checks. Never scan untracked world vehicles.
            retractForMotion(vehicle, part)
            if lifecycleDue then S.track(part) end
        end
    end
    if pendingParts then for part in pairs(pendingParts) do S.track(part, true) end end
end

-- Preserve all existing rack callbacks. Tracking is driven by native part init /
-- update / installation, never a world-wide vehicle scan. Only our model names
-- are touched; luggage/rack lights/cargo remain under their existing owners.
if not S.hooks then
    S.hooks = true
    local init = R.InitFixedRack
    R.InitFixedRack = function(vehicle, part, ...)
        local result = init(vehicle, part, ...)
        S.diagnose(vehicle, "rack-init")
        S.track(part, true)
        return result
    end
    local update = R.UpdateFixedRack
    R.UpdateFixedRack = function(vehicle, part, ...)
        local result = update(vehicle, part, ...)
        S.track(part)
        return result
    end
    local install = R.installFixed
    R.installFixed = function(character, part, ...)
        local result = install(character, part, ...)
        if result then S.track(part, true) end
        return result
    end
    local complete = R.InstallComplete
    R.InstallComplete = function(vehicle, part, ...)
        local result = complete(vehicle, part, ...)
        if part and part:getId() == R.fixedId then
            S.tracked[part] = nil
            S.track(part)
        end
        return result
    end
end
return S
