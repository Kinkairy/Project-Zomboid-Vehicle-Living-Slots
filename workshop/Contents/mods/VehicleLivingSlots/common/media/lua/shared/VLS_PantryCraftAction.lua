local P = require "VLS_Pantry"
local VLS = require "VLS_Config"
require "Entity/TimedActions/ISHandcraftAction"

VLSPantryCraftAction = ISHandcraftAction:derive("VLSPantryCraftAction")

local function integer(value)
    return type(value) == "number" and value == value and value ~= math.huge
        and value ~= -math.huge and value == math.floor(value)
end

function VLSPantryCraftAction:resolve()
    local choice = P.choices[self.choice]
    if self.finished or not choice or not integer(self.vehicleId)
            or not integer(self.applianceId) then return nil end
    local vehicle = getVehicleById(self.vehicleId)
    if not P.slots[self.partId] or P.reason(self.character, vehicle, self.partId, self.applianceId) then return nil end
    local item = vehicle:getPartById(self.partId):getInventoryItem()
    if P.resolveType(item) ~= choice.itemType then return nil end
    return vehicle
end

function VLSPantryCraftAction:isValid()
    return self:resolve() ~= nil and self.craftRecipe == P.recipe(self.choice)
end

function VLSPantryCraftAction:bind()
    if not self:resolve() then return false end
    self.craftRecipe = P.recipe(self.choice)
    if not self.craftRecipe then return false end
    self.actionScript = self.craftRecipe:getTimedActionScript()
    self.containers = P.carriedContainers(self.character)
    self.isoObject, self.craftBench = nil, nil
    self.variableInputRatio, self.eatPercentage, self.force = 1, 0, false
    return true
end

-- The actual native action still owns manual item selection, duration, models,
-- animation and outputs. Only its world-workbench predicate is adapted.
function VLSPantryCraftAction:withNativeLogic(callback)
    local nativeNew = HandcraftLogic.new
    HandcraftLogic.new = function(character, bench, object)
        local logic = nativeNew(character, bench, object)
        if character ~= self.character or bench ~= nil or object ~= nil then return logic end
        return setmetatable({}, { __index = function(_, key)
            if key == "canPerformCurrentRecipe" then
                return function()
                    return self:isValid() and P.canCraft(character, logic, self.craftRecipe)
                end
            end
            return function(_, ...) return logic[key](logic, ...) end
        end })
    end
    local ok, result = pcall(callback, self)
    HandcraftLogic.new = nativeNew
    if not ok then error(result, 0) end
    return result
end

function VLSPantryCraftAction:start()
    if not self:bind() then self:forceStop(); return end
    self:withNativeLogic(ISHandcraftAction.start)
    if not P.canCraft(self.character, self.logic, self.craftRecipe) then self:forceStop(); return end
end

function VLSPantryCraftAction:serverStart()
    if self:bind() then
        self:withNativeLogic(ISHandcraftAction.serverStart)
        if P.canCraft(self.character, self.logic, self.craftRecipe) then return end
    end
    self.finished = true
    self.netAction:forceComplete()
end

function VLSPantryCraftAction:complete()
    -- Native SP perform() may already have produced output. Its finished flag
    -- must not suppress the native UI completion callback (also used by batches).
    if self.completionNotified then return true end
    self.completionNotified = true
    if not self.finished and (not self.logic or not self:isValid()) then
        self.finished = true
    end
    return ISHandcraftAction.complete(self)
end

function VLSPantryCraftAction:performRecipe()
    if isClient() or not self:isValid() or not self.logic then return end
    local vehicle = self:resolve()
    if not vehicle or not P.canCraft(self.character, self.logic, self.craftRecipe) then return end
    self.finished = true
    local realLogic = self.logic
    local spent = false
    self.logic = setmetatable({}, { __index = function(_, key)
        if key == "performCurrentRecipe" then
            return function()
                if spent then return false end
                local succeeded = realLogic:performCurrentRecipe()
                if succeeded then
                    spent = true
                    VLS.consumeAuxBattery(vehicle, P.ENERGY_PER_USE)
                end
                return succeeded
            end
        end
        return function(_, ...) return realLogic[key](realLogic, ...) end
    end })
    local ok, result = pcall(ISHandcraftAction.performRecipe, self)
    self.logic = realLogic
    if not ok then error(result, 0) end
    return result
end

return VLSPantryCraftAction
