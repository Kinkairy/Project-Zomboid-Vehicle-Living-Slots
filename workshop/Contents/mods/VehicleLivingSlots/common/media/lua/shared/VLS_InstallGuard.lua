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

-- The native Radio branch only copies presets and creates DeviceData. It is
-- valid for televisions too: allow the original installation transaction in
-- full instead of overriding the global instanceof predicate.
VLSTelevisionUninstallVehiclePart =
    ISUninstallVehiclePart:derive("VLSTelevisionUninstallVehiclePart")
function VLSTelevisionUninstallVehiclePart:complete()
    local item=self.part and self.part:getInventoryItem()
    if not isVLSTelevision(self.part,item)
            or not VLS.canUninstallManagedPart(self.part) then return false end
    VLS.copyTelevisionStateToItem(self.part,item)
    -- Native removal copies this slot's presets into the item. The active TV
    -- uses its companion device, so supply those same current presets through
    -- the native slot endpoint before delegating the complete transaction.
    local device = self.part:getDeviceData() or self.part:createSignalDevice()
    device:cloneDevicePresets(item:getDeviceData():getDevicePresets())
    return ISUninstallVehiclePart.complete(self)
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
