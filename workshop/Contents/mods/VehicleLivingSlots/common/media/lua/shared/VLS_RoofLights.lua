require "VLS_RoofCargo"
-- Native parts hold the real Torch items. Handheld charge is never read/drained.
VLSRoofLights = VLSRoofLights or {}
local L = VLSRoofLights
-- Client-only appearance cache is populated by native part initialization.
-- The native light remains the authoritative source of power and illumination.
L.visualParts = L.visualParts or {}
function L.SyncVisual(part)
    local i=VLSRoofCargo.lamps[part:getId()]
    if not i then return end
    local vehicle=part:getVehicle()
    local installed=part:getInventoryItem()~=nil
    local light=part:getLight()
    local active=installed and light~=nil and light:getActive()
        and vehicle:getHeadlightsOn() and vehicle:getBatteryCharge()>0
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
L.configured=setmetatable({}, {__mode="k"})
local function finite(value)
    return type(value)=="number" and value==value and math.abs(value)<math.huge
end
function L.Configure(vehicle,part)
    local script=vehicle:getScript()
    local model=part:getScriptPart():getModel(0)
    local offset=model and model:getOffset()
    if not offset then return false end
    local body=script:getModelOffset()
    local scale=script:getModelScale()
    local extents=script:getExtents()
    if extents:x()<=0 or extents:z()<=0 then return false end
    local x=(offset:x()+body:x())*scale*2/extents:x()
    local z=(offset:z()+body:z())*scale*2/extents:z()
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
    L.configured[part]={light=part:getLight(),item=item,
        condition=part:getCondition(),itemCondition=item and item:getCondition(),
        maximum=item and item:getConditionMax()}
    return true
end
function L.EnsureLight(vehicle,part)
    local old=L.configured[part]
    local item=part:getInventoryItem()
    if not old or old.light~=part:getLight() or old.item~=item
            or old.condition~=part:getCondition()
            or old.itemCondition~=(item and item:getCondition())
            or old.maximum~=(item and item:getConditionMax()) then
        return L.Configure(vehicle,part)
    end
    return true
end
function L.Init(vehicle,part)
    L.Configure(vehicle,part)
    part:setLightActive(vehicle:getHeadlightsOn() and part:getInventoryItem()~=nil
        and vehicle:getBatteryCharge()>0)
    L.TrackVisual(part)
end
function L.Update(vehicle,part,elapsedMinutes)
    L.EnsureLight(vehicle,part)
    -- Keep the native switch, engine-off drain and multiplayer update path.
    Vehicles.Update.Headlight(vehicle,part,elapsedMinutes)
end
function L.Create(vehicle,part)
    VLSRoofCargo.Create(vehicle,part)
    L.Init(vehicle,part)
end
function L.InstallComplete(vehicle,part)
    -- Disconnect the portable light's own switch; retain any inserted battery/charge.
    local item=part:getInventoryItem()
    if item then item:setActivated(false) end
    L.Init(vehicle,part)
    Vehicles.InstallComplete.Default(vehicle,part)
    if not isServer() then L.SyncVisual(part) end
end
function L.UninstallComplete(vehicle,part,item)
    part:setLightActive(false)
    Vehicles.UninstallComplete.Default(vehicle,part,item)
    if not isServer() then L.SyncVisual(part) end
end
