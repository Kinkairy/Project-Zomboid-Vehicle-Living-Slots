-- Ownership boundary only. All generator behavior stays in the shipped actions.
local G = require "VLS_Generator"
require "TimedActions/ISAddFuel"
require "TimedActions/ISFixGenerator"
require "TimedActions/ISActivateGenerator"
require "TimedActions/ISPlugGenerator"
require "TimedActions/ISTakeGenerator"
local function mounted(object)
    return object and object:getModData().vlsMountedGenerator ~= nil
end
local function owner(object)
    if not G.enabled() then return nil end
    local vehicles = getCell():getVehicles():iterator()
    while vehicles:hasNext() do
        local vehicle = vehicles:next()
        local _, item = G.getPart(vehicle)
        local dock = item and G.state(item).dock
        if dock and G.object(vehicle) == object and not G.hasMoved(vehicle, dock) then return vehicle end
    end
end
G.getOwner = owner
local function faceService(action)
    if not mounted(action.generator) then return false end
    local vehicle = owner(action.generator)
    local part = vehicle and G.getPart(vehicle)
    local point = part and vehicle:getAreaFacingPosition(part:getArea(), Vector2.new())
    if not point then return false end
    action.character:faceLocationF(point:getX(), point:getY())
    return true
end
if not G.ownershipInstalled then
    G.ownershipInstalled = true
    for _, class in ipairs({ISAddFuel, ISFixGenerator, ISActivateGenerator, ISPlugGenerator}) do
        local valid, complete = class.isValid, class.complete
        local wait, update = class.waitToStart, class.update
        class.waitToStart = function(self)
            if faceService(self) then return self.character:shouldBeTurning() end
            return wait(self)
        end
        class.update = function(self)
            local result = update(self)
            faceService(self)
            return result
        end
        class.isValid = function(self)
            if mounted(self.generator) and not owner(self.generator) then return false end
            return valid(self)
        end
        class.complete = function(self)
            local vehicle
            if mounted(self.generator) then
                vehicle = owner(self.generator)
                if not vehicle then return false end
            end
            local result = complete(self)
            if vehicle then G.update(vehicle) end
            return result
        end
    end
    -- Picking up the world projection would duplicate the installed item.
    local valid, complete = ISTakeGenerator.isValid, ISTakeGenerator.complete
    ISTakeGenerator.isValid = function(self)
        return not mounted(self.generator) and valid(self)
    end
    ISTakeGenerator.complete = function(self)
        if mounted(self.generator) then return false end
        return complete(self)
    end
end
return G
