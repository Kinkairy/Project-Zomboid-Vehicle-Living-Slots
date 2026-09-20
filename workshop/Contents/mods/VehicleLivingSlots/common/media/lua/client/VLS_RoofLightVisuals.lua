require "VLS_RoofLights"
local L=VLSRoofLights
local ticks=0
function L.RefreshVisuals()
    for part in pairs(L.visualParts) do
        local vehicle=part:getVehicle()
        if vehicle and vehicle:getSquare() then
            L.EnsureLight(vehicle,part)
            L.SyncVisual(part)
        else
            L.visualParts[part]=nil
        end
    end
end
local function onTick()
    ticks=ticks+1
    if ticks<6 then return end
    ticks=0
    L.RefreshVisuals()
end
if L.visualTick and Events.OnTick.Remove then Events.OnTick.Remove(L.visualTick) end
L.visualTick = onTick
Events.OnTick.Add(L.visualTick)
