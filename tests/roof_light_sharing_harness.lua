-- Mock host mirroring decompiled 42.21 VehiclePart/VehicleLight semantics.
-- __SUBJECT__ is replaced by the VLS_RoofLights.lua under test.
local function check(cond, msg) if not cond then error("ASSERT: "..msg, 2) end end
local function near(a, b) return math.abs(a-b) < 1e-4 end
local SERVER = false
function isServer() return SERVER end
function require() end
local battery
VehicleUtils = { chargeBattery = function(v, d) v.battery = math.max(0, v.battery + d) end }
-- Vanilla 42.21 Vehicles.Update.Headlight (server/Vehicles/Vehicles.lua:562).
Vehicles = { Update = {}, InstallComplete = {}, UninstallComplete = {} }
function Vehicles.Update.Headlight(vehicle, part, elapsedMinutes)
    local light = part:getLight()
    if not light then return end
    local active = vehicle:getHeadlightsOn()
    if active and (not part:getInventoryItem() or vehicle:getBatteryCharge() <= 0.0) then active = false end
    part:setLightActive(active)
    if active and not vehicle:isEngineRunning() then
        VehicleUtils.chargeBattery(vehicle, -0.000025 * elapsedMinutes)
    end
end
function Vehicles.InstallComplete.Default(vehicle, part) end
function Vehicles.UninstallComplete.Default(vehicle, part, item) part.item = nil end
VLSRoofCargo = { lamps = { VLSRoofHeadlight1=1, VLSRoofHeadlight2=2, VLSRoofHeadlight3=3, VLSRoofHeadlight4=4 },
    Create = function() end }

local V3 = {}; V3.__index = V3
local function v3(x, y, z) return setmetatable({ X=x, Y=y, Z=z }, V3) end
function V3:x() return self.X end
function V3:y() return self.Y end
function V3:z() return self.Z end

local Light = {}; Light.__index = Light
function Light:getActive() return self.active end
local Part = {}; Part.__index = Part
function Part:getId() return self.id end
function Part:getVehicle() return self.vehicle end
function Part:getInventoryItem() return self.item end
function Part:getCondition() return self.condition end
function Part:getLight() return self.light end
function Part:getScriptPart()
    local off = self.offset
    return { getModel = function(_, i) return { getOffset = function() return off end } end }
end
function Part:createSpotLight(x, y, dist, intensity, dot, focusing)
    self.light = self.light or setmetatable({ active = false }, Light)
    self.light.ox, self.light.oy, self.light.dist, self.light.intensity, self.light.dot = x, y, dist, intensity, dot
    self.createCount = (self.createCount or 0) + 1
end
local function lerp(a, b, t) return a + (b - a) * t end
function Part:getLightDistance()
    return self.light and lerp(self.light.dist * 0.5, self.light.dist, self.condition / 100) or 0
end
function Part:getLightIntensity()
    return self.light and lerp(self.light.intensity * 0.5, self.light.intensity, self.condition / 100) or 0
end
function Part:setLightActive(active)
    if self.light == nil or self.light.active == active then return end
    self.light.active = active
    self.transmits = (self.transmits or 0) + 1
end
function Part:setModelVisible(name, visible) self.models[name] = visible end

local Item = {}; Item.__index = Item
function Item:getCondition() return self.c end
function Item:getConditionMax() return self.m end
function Item:setActivated() end
local function torch(c) return setmetatable({ c = c or 10, m = 10 }, Item) end

local Vehicle = {}; Vehicle.__index = Vehicle
function Vehicle:getPartById(id) return self.parts[id] end
function Vehicle:getHeadlightsOn() return self.headlights end
function Vehicle:getBatteryCharge() return self.battery end
function Vehicle:isEngineRunning() return self.engine end
function Vehicle:getScript()
    return { getModelOffset = function() return v3(0, 0.1, 0.2) end,
        getModelScale = function() return 1.0 end,
        getExtents = function() return v3(2.4, 2.5, 6.0) end }
end
-- StepVan lamp model offsets from VLS_StepVanRoofRackAdjustment.txt.
local XS = { 0.2664, 0.0888, -0.0888, -0.2664 }
local function newVehicle(installed)
    local v = setmetatable({ parts = {}, headlights = true, battery = 1.0, engine = false }, Vehicle)
    for i = 1, 4 do
        local p = setmetatable({ id = "VLSRoofHeadlight"..i, vehicle = v, condition = 100,
            offset = v3(XS[i], 0.57, 0.64), models = {} }, Part)
        if installed[i] then p.item = torch() end
        v.parts[p.id] = p
    end
    return v
end
local function lamp(v, i) return v.parts["VLSRoofHeadlight"..i] end
local function activeCount(v)
    local n = 0
    for i = 1, 4 do local l = lamp(v, i).light; if l and l.active then n = n + 1 end end
    return n
end
local function updateAll(L, v, minutes) for i = 1, 4 do L.Update(v, lamp(v, i), minutes or 1) end end
local function createAll(L, v) for i = 1, 4 do L.Create(v, lamp(v, i)) end end
local function nativeX(p) return p.light.ox end

local function load(subject)
    VLSRoofLights = nil
    subject()
    return VLSRoofLights
end

return function(subjectOld, subjectNew, report)
    local v
    if subjectOld then
        -- Baseline: the pre-fix file registers four overlapping native lights.
        local O = load(subjectOld)
        v = newVehicle({ true, true, true, true })
        createAll(O, v); updateAll(O, v)
        check(activeCount(v) == 4, "baseline expected 4 active native lights, got "..activeCount(v))
        report("baseline: 4 lamps -> "..activeCount(v).." native lights, each dist "..lamp(v,1):getLightDistance())
    end

    local L = load(subjectNew)
    -- 1. Four lamps: exactly one native light, centred, full 48/1.0 output.
    v = newVehicle({ true, true, true, true })
    createAll(L, v); updateAll(L, v)
    check(activeCount(v) == 1, "expected 1 active native light, got "..activeCount(v))
    check(lamp(v,1).light.active, "lamp1 should carry the shared light")
    local ext = 2.4
    check(near(nativeX(lamp(v,1)), 0 * 2 / ext), "shared light should be centred, x="..nativeX(lamp(v,1)))
    -- Beam starts where vanilla headlights do, never on the van's own square.
    check(near(lamp(v,1).light.oy, 2.0), "origin ahead of the bumper, y="..lamp(v,1).light.oy)
    for i = 1, 4 do check(lamp(v,i).light.oy > 1.0, "lamp "..i.." origin outside the body") end
    check(near(lamp(v,1):getLightDistance(), 48) and near(lamp(v,1):getLightIntensity(), 1.0), "full output kept")
    for i = 1, 4 do
        check(lamp(v,i).models["RoofSpotlightGlow"..i] == true, "lamp "..i.." glow visible")
        check(lamp(v,i).models["RoofSpotlightLens"..i] == false, "lamp "..i.." lens hidden while lit")
        check(lamp(v,i).models["RoofSpotlightHousing"..i] == true, "lamp "..i.." housing visible")
    end
    report("new: 4 lamps -> 1 native light at centre, 4 glows visible")

    -- 2. Engine-off battery draw unchanged: still 4 lamps' worth.
    local before = v.battery
    updateAll(L, v, 10)
    check(near(before - v.battery, 4 * 0.000025 * 10), "battery draw should equal four lamps, got "..(before - v.battery))
    v.engine = true; before = v.battery; updateAll(L, v, 10)
    check(near(before, v.battery), "no draw while engine runs")
    report("new: engine-off drain = 4 lamps; none with engine running")

    -- 3. Headlights off / flat battery: nothing lit, lenses shown.
    v.headlights = false; updateAll(L, v)
    for i = 1, 4 do L.SyncVisual(lamp(v,i)) end
    check(activeCount(v) == 0, "headlights off -> no light")
    check(lamp(v,2).models.RoofSpotlightGlow2 == false and lamp(v,2).models.RoofSpotlightLens2 == true, "unlit visuals")
    v.headlights = true; v.battery = 0; updateAll(L, v)
    check(activeCount(v) == 0, "flat battery -> no light")
    report("new: headlights off / flat battery -> 0 lights, lenses shown")

    -- 4. Removing lamp1 hands the shared light to lamp2, re-centred on 2..4.
    v.battery = 1.0; updateAll(L, v)
    local item = lamp(v,1).item
    L.UninstallComplete(v, lamp(v,1), item)
    updateAll(L, v)
    check(activeCount(v) == 1 and lamp(v,2).light.active and not lamp(v,1).light.active, "handover to lamp2")
    check(near(nativeX(lamp(v,2)), ((XS[2]+XS[3]+XS[4])/3) * 2 / ext), "re-centred on remaining lamps")
    L.SyncVisual(lamp(v,1))
    check(lamp(v,1).models.RoofSpotlightHousing1 == false, "removed lamp hidden")
    report("new: uninstall lamp1 -> lamp2 carries light, re-centred")

    -- 5. Reinstall lamp1: shared light returns to lamp1, still one light.
    lamp(v,1).item = item; L.InstallComplete(v, lamp(v,1)); updateAll(L, v)
    check(activeCount(v) == 1 and lamp(v,1).light.active, "reinstall restores lamp1 as carrier")
    report("new: reinstall lamp1 -> back to 1 light on lamp1")

    -- 6. Only lamp3 installed: it carries its own light at its own position.
    v = newVehicle({ false, false, true, false })
    createAll(L, v); updateAll(L, v)
    check(activeCount(v) == 1 and lamp(v,3).light.active, "single lamp3 carries light")
    check(near(nativeX(lamp(v,3)), XS[3] * 2 / ext), "single lamp keeps own position")
    report("new: only lamp3 -> 1 light at lamp3")

    -- 7. Legacy save: all four lights saved active; first update leaves one.
    v = newVehicle({ true, true, true, true })
    createAll(L, v)
    for i = 1, 4 do lamp(v,i).light.active = true end
    updateAll(L, v)
    check(activeCount(v) == 1, "legacy active lights collapse to one, got "..activeCount(v))
    report("new: legacy save with 4 active -> 1 after first update")

    -- 8. Damaged torch keeps the original condition scaling (factor 0.5+0.5*c).
    v = newVehicle({ true, false, false, false })
    lamp(v,1).item = torch(5); lamp(v,1).condition = 60
    createAll(L, v); updateAll(L, v)
    check(near(lamp(v,1):getLightDistance(), 48 * 0.75) and near(lamp(v,1):getLightIntensity(), 0.75), "condition scaling")
    report("new: half-condition torch -> dist 36, intensity 0.75 (unchanged rule)")

    -- 9. Steady state: no re-configuration and no repeated network transmits.
    v = newVehicle({ true, true, true, true })
    createAll(L, v); updateAll(L, v)
    local creates, transmits = {}, {}
    for i = 1, 4 do creates[i] = lamp(v,i).createCount; transmits[i] = lamp(v,i).transmits or 0 end
    for _ = 1, 50 do updateAll(L, v); for i = 1, 4 do L.EnsureLight(v, lamp(v,i)); L.SyncVisual(lamp(v,i)) end end
    for i = 1, 4 do
        check(lamp(v,i).createCount == creates[i], "lamp "..i.." re-configured in steady state")
        check((lamp(v,i).transmits or 0) == transmits[i], "lamp "..i.." re-transmitted in steady state")
    end
    report("new: 50 steady updates -> 0 reconfigures, 0 extra light transmits")

    -- 10. Dedicated server path: no client visual tracking.
    SERVER = true
    v = newVehicle({ true, true, false, false })
    local before = 0; for _ in pairs(L.visualParts) do before = before + 1 end
    createAll(L, v); updateAll(L, v)
    local after = 0; for _ in pairs(L.visualParts) do after = after + 1 end
    check(after == before and activeCount(v) == 1, "server path")
    SERVER = false
    report("new: dedicated server -> 1 light, no visual tracking")
end
