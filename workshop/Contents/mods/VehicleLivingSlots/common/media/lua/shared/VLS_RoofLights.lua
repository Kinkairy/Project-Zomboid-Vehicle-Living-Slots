require "VLS_RoofCargo"
-- Native parts hold the real Torch items. Handheld charge is never read/drained.
VLSRoofLights = VLSRoofLights or {}
local L = VLSRoofLights
-- Client-only appearance cache is populated by native part initialization.
-- The native light remains the authoritative source of power and illumination.
-- Up to four lamps share ONE native light: overlapping 48-tile spotlights made
-- the native lighting flicker. Every installed lamp still shows its own glow.
L.visualParts = L.visualParts or {}
function L.installedLamps(vehicle)
    local out={}
    for i=1,4 do
        local part=vehicle:getPartById("VLSRoofHeadlight"..i)
        if part and part:getInventoryItem() then out[#out+1]=part end
    end
    return out
end
function L.primary(vehicle)
    return L.installedLamps(vehicle)[1]
end
-- True while the shared native light is switched on and powered.
function L.lit(vehicle)
    local primary=L.primary(vehicle)
    local light=primary and primary:getLight()
    return light~=nil and light:getActive()
        and vehicle:getHeadlightsOn() and vehicle:getBatteryCharge()>0
end
function L.SyncVisual(part)
    local i=VLSRoofCargo.lamps[part:getId()]
    if not i then return end
    local vehicle=part:getVehicle()
    local installed=part:getInventoryItem()~=nil
    local active=installed and L.lit(vehicle)
    part:setModelVisible("RoofSpotlightHousing"..i,installed)
    part:setModelVisible("RoofSpotlightLens"..i,installed and not active)
    part:setModelVisible("RoofSpotlightGlow"..i,active)
end
function L.TrackVisual(part)
    if isServer() then return end
    L.visualParts[part]=true
    L.SyncVisual(part)
end
-- Refresh saved light objects as well as new ones. The two public
-- effective-output getters account for native condition scaling. Calibrate
-- the lamp without changing the carried Torch's condition/max/battery.
L.DISTANCE=48
L.INTENSITY=1.0
L.DOT=0.75
-- The engine lights a vehicle model from the lights reaching its own square.
-- A beam starting on the roof keeps flipping that square in and out of the
-- cone, so the whole van blinked. Start the beam where vanilla headlights do
-- (VehicleUtils.initHeadlight yOffset 2.0, ahead of the bumper); the lamp
-- models stay on the roof.
L.ORIGIN_FORWARD=2.0
L.configured=setmetatable({}, {__mode="k"})
local function finite(value)
    return type(value)=="number" and value==value and math.abs(value)<math.huge
end
-- Native light offset of one lamp model, in the units createSpotLight expects.
local function lampOffset(script,part)
    local model=part:getScriptPart():getModel(0)
    local offset=model and model:getOffset()
    if not offset then return nil end
    local body=script:getModelOffset()
    local scale=script:getModelScale()
    local extents=script:getExtents()
    if extents:x()<=0 or extents:z()<=0 then return nil end
    return (offset:x()+body:x())*scale*2/extents:x(),
        (offset:z()+body:z())*scale*2/extents:z()
end
-- Installed lamp ids in order; a change moves or hands over the shared light.
local function layout(vehicle)
    local ids={}
    for _,lamp in ipairs(L.installedLamps(vehicle)) do ids[#ids+1]=lamp:getId() end
    return table.concat(ids,",")
end
function L.Configure(vehicle,part)
    local script=vehicle:getScript()
    local x,z=lampOffset(script,part)
    if not x then return false end
    if part==L.primary(vehicle) then
        -- Centre the shared light across all installed lamps.
        local sx,n=0,0
        for _,lamp in ipairs(L.installedLamps(vehicle)) do
            local lx=lampOffset(script,lamp)
            if lx then sx,n=sx+lx,n+1 end
        end
        if n>0 then x=sx/n end
    end
    z=L.ORIGIN_FORWARD
    local item=part:getInventoryItem()
    local percent=item and item:getConditionMax()>0
        and math.max(0,math.min(1,item:getCondition()/item:getConditionMax())) or 0
    local factor=0.5+0.5*percent
    part:createSpotLight(x,z,L.DISTANCE,L.INTENSITY,L.DOT,0)
    local distance,intensity=part:getLightDistance(),part:getLightIntensity()
    if finite(distance) and distance>0 and finite(intensity) and intensity>0 then
        -- Works whether the engine uses 0..100 part condition or normalizes
        -- the installed item's own maximum. Do not normalize the item itself.
        part:createSpotLight(x,z,L.DISTANCE*L.DISTANCE*factor/distance,
            L.INTENSITY*L.INTENSITY*factor/intensity,L.DOT,0)
    end
    L.configured[part]={light=part:getLight(),item=item,layout=layout(vehicle),
        condition=part:getCondition(),itemCondition=item and item:getCondition(),
        maximum=item and item:getConditionMax()}
    return true
end
function L.EnsureLight(vehicle,part)
    local old=L.configured[part]
    local item=part:getInventoryItem()
    if not old or old.light~=part:getLight() or old.item~=item
            or old.layout~=layout(vehicle)
            or old.condition~=part:getCondition()
            or old.itemCondition~=(item and item:getCondition())
            or old.maximum~=(item and item:getConditionMax()) then
        return L.Configure(vehicle,part)
    end
    return true
end
function L.Init(vehicle,part)
    L.Configure(vehicle,part)
    part:setLightActive(part==L.primary(vehicle) and vehicle:getHeadlightsOn()
        and vehicle:getBatteryCharge()>0)
    L.TrackVisual(part)
end
function L.Update(vehicle,part,elapsedMinutes)
    L.EnsureLight(vehicle,part)
    if part~=L.primary(vehicle) then
        part:setLightActive(false)
        return
    end
    -- Keep the native switch, engine-off drain and multiplayer update path.
    Vehicles.Update.Headlight(vehicle,part,elapsedMinutes)
    -- The other installed lamps keep their previous engine-off battery draw.
    local light=part:getLight()
    local extra=#L.installedLamps(vehicle)-1
    if extra>0 and light and light:getActive() and not vehicle:isEngineRunning() then
        VehicleUtils.chargeBattery(vehicle,-0.000025*elapsedMinutes*extra)
    end
end
function L.Create(vehicle,part)
    VLSRoofCargo.Create(vehicle,part)
    L.Init(vehicle,part)
end
-- Installing or removing a lamp can hand the shared light to another lamp.
function L.Reinit(vehicle)
    for i=1,4 do
        local lamp=vehicle:getPartById("VLSRoofHeadlight"..i)
        if lamp then L.Init(vehicle,lamp) end
    end
end
function L.InstallComplete(vehicle,part)
    -- Disconnect the portable light's own switch; retain any inserted battery/charge.
    local item=part:getInventoryItem()
    if item then item:setActivated(false) end
    L.Init(vehicle,part)
    Vehicles.InstallComplete.Default(vehicle,part)
    L.Reinit(vehicle)
    if not isServer() then L.SyncVisual(part) end
end
function L.UninstallComplete(vehicle,part,item)
    part:setLightActive(false)
    Vehicles.UninstallComplete.Default(vehicle,part,item)
    L.Reinit(vehicle)
    if not isServer() then L.SyncVisual(part) end
end
