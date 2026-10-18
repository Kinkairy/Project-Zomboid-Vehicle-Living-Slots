require "Entity/TimedActions/ISHandcraftAction"
local Context = require "VLS_NativeContext"

VLSNativeHandcraftAction = ISHandcraftAction:derive("VLSNativeHandcraftAction")
local nativeNew = ISHandcraftAction.new

function VLSNativeHandcraftAction:resolveContext()
    if self.craftBench ~= nil or not self.craftRecipe
            or not self.craftRecipe:isAnySurfaceCraft() then return nil end
    if not self.isoObject or not instanceof(self.isoObject, "BaseVehicle")
            or self.isoObject:getId() ~= self.vehicleId then return nil end
    local context = Context.restore(self.character, {
        vehicleId = self.vehicleId, partId = self.partId,
        installedItemId = self.installedItemId, installationEpoch = self.installationEpoch })
    if not context or context.vehicle ~= self.isoObject
            or not VLS.isGenericCraftSurfaceEquipment(context.item) then return nil end
    return context
end

function VLSNativeHandcraftAction:isValid()
    return not self.vlsRejected and self:resolveContext() ~= nil
        and ISHandcraftAction.isValid(self)
end

function VLSNativeHandcraftAction:start()
    if not self:isValid() then self.vlsRejected = true; self:forceStop(); return end
    return ISHandcraftAction.start(self)
end

function VLSNativeHandcraftAction:serverStart()
    if not self:isValid() then
        self.vlsRejected = true
        -- Server actions use NetTimedAction, not the client's animation action.
        -- forceComplete can still invoke complete(), which must remain harmless.
        self.netAction:forceComplete()
        return
    end
    return ISHandcraftAction.serverStart(self)
end

function VLSNativeHandcraftAction:complete()
    if self.vlsCompletionDone then return true end
    self.vlsCompletionDone = true
    if self.logic and self:isValid() then return ISHandcraftAction.complete(self) end
    self.vlsRejected = true
    -- Preserve vanilla progress cleanup and completion callbacks even when the
    -- server rejected before constructing logic. Disable only the abandoned
    -- recipe's eat-percentage mutation, then restore the serialized argument.
    local eatPercentage = self.eatPercentage
    self.eatPercentage = 0
    local ok, result = pcall(ISHandcraftAction.complete, self)
    self.eatPercentage = eatPercentage
    if not ok then error(result, 0) end
    return result
end

function VLSNativeHandcraftAction:performRecipe()
    if self.vlsRecipeExecuted or (isClient and isClient())
            or not self.logic or not self:isValid() then return end
    self.vlsRecipeExecuted = true
    -- Entire native executor: validation, inputs, outputs, OnCreate and effects.
    -- No copied performRecipe body and no force=true bypass.
    return ISHandcraftAction.performRecipe(self)
end

-- Keep every original parameter name/type for timed-action network rebuilding.
-- The four appended primitive arguments pin the installation across that rebuild.
function VLSNativeHandcraftAction:new(character, craftRecipe, containers, isoObject,
        craftBench, manualInputs, items, recipeItem, variableInputRatio, eatPercentage,
        vehicleId, partId, installedItemId, installationEpoch)
    local o = nativeNew(self, character, craftRecipe, containers, isoObject,
        craftBench, manualInputs, items, recipeItem, variableInputRatio, eatPercentage)
    o.vehicleId, o.partId, o.installedItemId, o.installationEpoch = vehicleId, partId, installedItemId, installationEpoch
    return o
end

function VLSNativeHandcraftAction.install()
    if ISHandcraftAction.new == VLSNativeHandcraftAction.constructorWrapper then return end
    local previous = ISHandcraftAction.new
    VLSNativeHandcraftAction.constructorWrapper = function(self, character, craftRecipe,
            containers, isoObject, craftBench, manualInputs, items, recipeItem,
            variableInputRatio, eatPercentage)
        if self == ISHandcraftAction and not craftBench and craftRecipe
                and craftRecipe:isAnySurfaceCraft() and isoObject
                and instanceof(isoObject, "BaseVehicle") then
            local context = Context.cabinet(character, isoObject)
            local token = Context.token(context)
            if token then
                return VLSNativeHandcraftAction:new(character, craftRecipe, containers,
                    isoObject, craftBench, manualInputs, items, recipeItem,
                    variableInputRatio, eatPercentage,
                    token.vehicleId, token.partId, token.installedItemId, token.installationEpoch)
            end
        end
        return previous(self, character, craftRecipe, containers, isoObject,
            craftBench, manualInputs, items, recipeItem, variableInputRatio, eatPercentage)
    end
    ISHandcraftAction.new = VLSNativeHandcraftAction.constructorWrapper
end

VLSNativeHandcraftAction.install()
return VLSNativeHandcraftAction
