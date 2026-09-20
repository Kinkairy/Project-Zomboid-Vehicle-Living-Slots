require "VLS_Config"
require "Vehicles/TimedActions/ISInstallVehiclePart"
require "Vehicles/TimedActions/ISUninstallVehiclePart"

local function isVLSTelevision(part, item)
    return VLS.isUniversalPart(part)
        and VLS.isAllowedItem(part, item)
        and VLS.getEquipmentCapability(item) == "television"
        and instanceof(item, "Radio")
        and item:getDeviceData() ~= nil
end

-- B42.20 treats every Radio item (including TVs) as a vehicle speaker.
-- Delegate the whole transaction to vanilla and skip only that one type branch
-- for this exact TV. The one-shot predicate restores itself BEFORE part callbacks
-- run, so TV companion setup and every other instanceof call stay native.
-- The outer pcall also restores it if vanilla fails before reaching the branch.
local function completeTelevision(action,item,nativeComplete)
    local original=instanceof
    local skipSpeaker
    skipSpeaker=function(object,kind)
        if object==item and kind=="Radio" then
            instanceof=original
            return false
        end
        return original(object,kind)
    end
    instanceof=skipSpeaker
    local ok,result=pcall(nativeComplete,action)
    if instanceof==skipSpeaker then instanceof=original end
    if not ok then error(result,0) end
    return result
end

VLSTelevisionInstallVehiclePart =
    ISInstallVehiclePart:derive("VLSTelevisionInstallVehiclePart")
function VLSTelevisionInstallVehiclePart:complete()
    if not isVLSTelevision(self.part,self.item)
            or not VLS.isInstallationEnabled(self.part,self.item) then return false end
    return completeTelevision(self,self.item,ISInstallVehiclePart.complete)
end

VLSTelevisionUninstallVehiclePart =
    ISUninstallVehiclePart:derive("VLSTelevisionUninstallVehiclePart")
function VLSTelevisionUninstallVehiclePart:complete()
    local item=self.part and self.part:getInventoryItem()
    if not isVLSTelevision(self.part,item)
            or not VLS.canUninstallManagedPart(self.part) then return false end
    VLS.copyTelevisionStateToItem(self.part,item)
    return completeTelevision(self,item,ISUninstallVehiclePart.complete)
end

if not VLS.installGuardApplied then
    VLS.installGuardApplied = true

    local vanillaIsValid = ISInstallVehiclePart.isValid
    function ISInstallVehiclePart:isValid()
        if not VLS.isInstallationEnabled(self.part, self.item) then return false end
        -- Only the furniture and battery slots have VLS-specific item rules.
        -- The large-van water tank deliberately uses the original gas-tank
        -- itemType/mechanic-type matcher, so the vanilla action must remain
        -- authoritative for it.
        local allowed = self.part and VLS.allowedItems[self.part:getId()]
        if allowed and not VLS.isAllowedItem(self.part, self.item) then
            return false
        end
        return vanillaIsValid(self)
    end

    -- The original completion removes the input before the part callback.
    -- Recheck here so a queued action cannot consume anything after disabling.
    local vanillaComplete = ISInstallVehiclePart.complete
    function ISInstallVehiclePart:complete()
        if not VLS.isInstallationEnabled(self.part, self.item) then return false end
        return vanillaComplete(self)
    end

    local vanillaInstallNew = ISInstallVehiclePart.new
    function ISInstallVehiclePart:new(character, part, item, maxTimeInit)
        if isVLSTelevision(part, item) then
            return vanillaInstallNew(VLSTelevisionInstallVehiclePart,
                character, part, item, maxTimeInit)
        end
        return vanillaInstallNew(self, character, part, item, maxTimeInit)
    end

    local vanillaUninstallIsValid = ISUninstallVehiclePart.isValid
    function ISUninstallVehiclePart:isValid()
        if not VLS.canUninstallManagedPart(self.part) then return false end
        return vanillaUninstallIsValid(self)
    end

    local vanillaUninstallNew = ISUninstallVehiclePart.new
    function ISUninstallVehiclePart:new(character, part, workTime)
        local item = part and part:getInventoryItem() or nil
        if isVLSTelevision(part, item) then
            return vanillaUninstallNew(VLSTelevisionUninstallVehiclePart,
                character, part, workTime)
        end
        return vanillaUninstallNew(self, character, part, workTime)
    end

end
