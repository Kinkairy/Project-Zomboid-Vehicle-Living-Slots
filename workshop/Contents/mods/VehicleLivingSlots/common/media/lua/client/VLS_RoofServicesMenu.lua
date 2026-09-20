local VLS = require "VLS_Config"
local F = require "VLS_RoofFuel"
require "VLS_GeneratorMenu"
require "Vehicles/ISUI/ISVehicleMenu"
require "ISUI/ISWorldObjectContextMenu"
require "Vehicles/TimedActions/ISPathFindAction"
-- Reuse the entire native pump callback (Fill All, equip and bag return).
-- Its one world-square walk is replaced only for our captured roof endpoint.
local nativeTakeFuel = ISWorldObjectContextMenu.onTakeFuelNew
ISWorldObjectContextMenu.onTakeFuelNew = function(worldobjects, source, ...)
    if type(source) ~= "table" or not source.vlsRoofVehicle then
        return nativeTakeFuel(worldobjects, source, ...)
    end
    local vehicle, part = source.vlsRoofVehicle, source:getServicePart()
    if not part then return end
    local walk = luautils.walkAdj
    luautils.walkAdj = function(character, square, ...)
        if square ~= source:getSquare() then return walk(character, square, ...) end
        if not vehicle:isInArea(part:getArea(), character) then
            ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(character,
                vehicle, part:getArea()))
        end
        return true
    end
    local ok, result = pcall(nativeTakeFuel, worldobjects, source, ...)
    luautils.walkAdj = walk
    if not ok then error(result) end
    return result
end
local function nearby(player)
    if not player or player:getVehicle() then return nil end
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
    if vehicle and vehicle:isStopped() and player:DistToProper(vehicle) < 4
            and math.floor(player:getZ()) == math.floor(vehicle:getZ()) then return vehicle end
end
-- Both menu construction and its selection callback are the shipped pump code.
function F.addCollectMenu(playerNum, vehicle, context)
    if not F.enabled() then return end
    local source=F.capture(vehicle)
    if source:getPipedFuelAmount()>0 and source:getSquare() then
        ISWorldObjectContextMenu.doFillFuelMenu(source,playerNum,context)
    end
end
local function worldMenu(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    local vehicle = nearby(player)
    if not vehicle then return end
    F.addCollectMenu(playerNum, vehicle, context)
end
if VLS.roofFuelInventoryMenu then Events.OnFillInventoryObjectContextMenu.Remove(VLS.roofFuelInventoryMenu) end
if VLS.roofServicesWorldMenu then Events.OnFillWorldObjectContextMenu.Remove(VLS.roofServicesWorldMenu) end
VLS.roofFuelInventoryMenu, VLS.roofServicesWorldMenu = nil, worldMenu
Events.OnFillWorldObjectContextMenu.Add(worldMenu)
