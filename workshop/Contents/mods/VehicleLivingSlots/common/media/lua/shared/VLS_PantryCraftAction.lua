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
local function bindNativeLogic(action, logic)
    if not logic then return nil end
    return setmetatable({}, { __index = function(_, key)
        if key == "canPerformCurrentRecipe" then
            return function()
                return action:isValid()
                    and P.canCraft(action.character, logic, action.craftRecipe)
            end
        end
        return function(_, ...) return logic[key](logic, ...) end
    end })
end

function VLSPantryCraftAction:withNativeLogic(callback)
    -- Native start/serverStart construct their own logic. Intercept only this
    -- action's field assignment, preserving its identity and every public
    -- constructor. Other actions, including ones started by callbacks, are not
    -- affected. Restore the original metatable even when native code fails.
    local previousMeta = getmetatable(self)
    local previousIndex = previousMeta.__index
    local previousNewIndex = previousMeta.__newindex
    local logic = rawget(self, "logic")
    local scopedMeta = {}
    for key, value in pairs(previousMeta) do scopedMeta[key] = value end
    scopedMeta.__index = function(action, key)
        if key == "logic" then return logic end
        if type(previousIndex) == "function" then return previousIndex(action, key) end
        return previousIndex[key]
    end
    scopedMeta.__newindex = function(action, key, value)
        if key == "logic" then
            logic = bindNativeLogic(action, value)
        elseif type(previousNewIndex) == "function" then
            previousNewIndex(action, key, value)
        elseif previousNewIndex then
            previousNewIndex[key] = value
        else
            rawset(action, key, value)
        end
    end
    rawset(self, "logic", nil)
    setmetatable(self, scopedMeta)
    local ok, result = pcall(callback, self)
    setmetatable(self, previousMeta)
    rawset(self, "logic", logic)
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
                    VLS.consumeAuxBattery(vehicle, VLS.getSmallApplianceDrainPerUse())
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

-- Only native constructor arguments are serialized, not arbitrary action fields.
-- Preserve vehicle authority explicitly while the original action owns crafting.
local nativeNew = ISHandcraftAction.new
function VLSPantryCraftAction:new(character, vehicleId, partId, applianceId, choice,
        manualInputs, items, recipeItem)
    local craftRecipe = P.recipe(choice)
    local o
    if craftRecipe then
        o = nativeNew(self, character, craftRecipe, P.carriedContainers(character),
            nil, nil, manualInputs or {}, items, recipeItem, 1, 0)
    else
        -- An invalid remote choice must be rejected without a constructor crash.
        o = ISBaseTimedAction.new(self, character)
        o.maxTime = 0
    end
    o.vehicleId, o.partId, o.applianceId, o.choice = vehicleId, partId, applianceId, choice
    -- Java conversion requires a table; nil/false mean native automatic inputs.
    -- Preserve the converted table from nativeNew only for actual manual inputs.
    if not manualInputs or not craftRecipe then o.manualInputs = nil end
    o.items, o.recipeItem = items, recipeItem
    o.stopOnWalk, o.stopOnRun = true, true
    return o
end

return VLSPantryCraftAction
