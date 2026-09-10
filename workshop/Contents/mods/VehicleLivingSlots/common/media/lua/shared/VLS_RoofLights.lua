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
function L.Init(vehicle,part)
    if not part:getLight() then
        local script=vehicle:getScript()
        local offset=part:getScriptPart():getModel(0):getOffset()
        local body=script:getModelOffset()
        local scale=script:getModelScale()
        local extents=script:getExtents()
        -- TorchInfo.set multiplies offsets by half the vehicle extents.
        -- Supply normalized coordinates so the beam starts at the actual lamp.
        part:createSpotLight((offset:x()+body:x())*scale*2/extents:x(),
            (offset:z()+body:z())*scale*2/extents:z(),36,0.75,0.75,0)
    end
    part:setLightActive(vehicle:getHeadlightsOn() and part:getInventoryItem()~=nil
        and vehicle:getBatteryCharge()>0)
    L.TrackVisual(part)
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
