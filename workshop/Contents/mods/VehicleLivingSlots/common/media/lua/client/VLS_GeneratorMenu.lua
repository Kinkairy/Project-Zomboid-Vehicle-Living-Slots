local VLS = require "VLS_Config"
local G = require "VLS_GeneratorOwnership"
require "ISUI/ISWorldObjectContextMenu"
require "Vehicles/ISUI/ISVehicleMenu"
require "Vehicles/TimedActions/ISPathFindAction"
local W = ISWorldObjectContextMenu
-- Only the spatial step of these native callbacks changes. Container grouping,
-- equip/transfer, actions, duration, fuel, repair and power remain native.
if not G.servicePathInstalled then
    G.servicePathInstalled = true
    for name, generatorArg in pairs({onPlugGenerator=2, onActivateGenerator=3,
            onFixGenerator=2, doAddFuelGenerator=2}) do
        local native = W[name]
        W[name] = function(...)
            local generator = select(generatorArg, ...)
            if not generator or not generator:getModData().vlsMountedGenerator then
                return native(...)
            end
            local vehicle = G.getOwner(generator)
            local part = vehicle and G.getPart(vehicle)
            if not part then return end
            local walk = luautils.walkAdj
            luautils.walkAdj = function(character, square, ...)
                if square ~= generator:getSquare() then return walk(character, square, ...) end
                if not vehicle:isInArea(part:getArea(), character) then
                    local path = ISPathFindAction:pathToVehicleArea(character, vehicle, part:getArea())
                    ISTimedActionQueue.add(path)
                end
                return true
            end
            local ok, result = pcall(native, ...)
            luautils.walkAdj = walk
            if not ok then error(result) end
            return result
        end
    end
end
-- Object construction can arrive before its modData packet. Watch native
-- generator instances from add/load until removed, so a late tag is handled.
-- Reapply if the native moveable cursor restores rendering after a hover.
local watched = setmetatable({}, {__mode="k"})
local function hideMounted(object)
    if object:getModData().vlsMountedGenerator and object:getDoRender() then
        object:setDoRender(false)
        object:invalidateRenderChunkLevel(FBORenderChunk.DIRTY_REDRAW)
    end
end
local function objectAdded(object)
    if instanceof(object, "IsoGenerator") then
        watched[object] = true
        hideMounted(object)
    end
end
local function squareLoaded(square)
    local objects = square:getSpecialObjects()
    for i=0,objects:size()-1 do objectAdded(objects:get(i)) end
end
local function visualTick()
    for object in pairs(watched) do
        if object:getObjectIndex()==-1 then watched[object]=nil
        else hideMounted(object) end
    end
end
if VLS.generatorObjectAdded then Events.OnObjectAdded.Remove(VLS.generatorObjectAdded) end
if VLS.generatorVisualSquare then Events.LoadGridsquare.Remove(VLS.generatorVisualSquare) end
if VLS.generatorVisualTick then Events.OnTick.Remove(VLS.generatorVisualTick) end
VLS.generatorObjectAdded, VLS.generatorVisualSquare, VLS.generatorVisualTick = objectAdded, squareLoaded, visualTick
Events.OnObjectAdded.Add(objectAdded)
Events.LoadGridsquare.Add(squareLoaded)
Events.OnTick.Add(visualTick)
local function fetchMounted(playerNum)
    if not G.enabled() then return end
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
    if not vehicle or not vehicle:isStopped() or player:DistToProper(vehicle) >= 4
            or math.floor(player:getZ()) ~= math.floor(vehicle:getZ()) then return end
    local object = G.object(vehicle)
    -- Feed the public native fetch stage before its Java menu builder runs.
    -- Preserve a different generator explicitly clicked by the player.
    local fetch = W.fetchVars
    if object and (not fetch.generator or fetch.generator == object) then
        ISWorldObjectContextMenuLogic.fetch(fetch, object, playerNum, true)
    end
end
local function removePickup(_, context)
    local object = W.fetchVars.generator
    if not object or not object:getModData().vlsMountedGenerator then return end
    local option = context:getOptionFromName(getText("ContextMenu_Generator"))
    local menu = option and option.subOption and context:getSubMenu(option.subOption)
    if menu then menu:removeOptionByName(getText("ContextMenu_GeneratorTake")) end
end
if VLS.generatorPreMenu then Events.OnPreFillWorldObjectContextMenu.Remove(VLS.generatorPreMenu) end
if VLS.generatorPostMenu then Events.OnFillWorldObjectContextMenu.Remove(VLS.generatorPostMenu) end
VLS.generatorPreMenu, VLS.generatorPostMenu = fetchMounted, removePickup
Events.OnPreFillWorldObjectContextMenu.Add(fetchMounted)
Events.OnFillWorldObjectContextMenu.Add(removePickup)
