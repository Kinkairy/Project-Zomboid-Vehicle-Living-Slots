require "VLS_Config"
require "VLS_RoofCargo"

-- Shared by the main mod and optional KI5 adapter. Query profiles at call time:
-- the adapter may register its vehicles after this module has already loaded.
local ROOF_PROPANE_IDS = { "VLSRoofPropane1", "VLSRoofPropane2" }
function VLS.isRoofPropaneRefillEnabled()
    local settings = SandboxVars and SandboxVars.VehicleLivingSlots
    return not settings or settings.EnableRoofPropaneShortcut ~= false
end

local function hasRoofProfile(vehicle)
    local script = vehicle and vehicle:getScript()
    return script and VLSRoofCargo.vehicleScripts[script:getFullName()] == true
end

function VLS.getPropaneTankPartIds(vehicle)
    if not vehicle then return {} end
    local result = {}
    local profile = VLS.getVehicleProfile(vehicle)
    for _, id in ipairs(profile and profile.propaneTankParts or {}) do
        result[#result + 1] = id
    end
    if hasRoofProfile(vehicle) then
        for _, id in ipairs(ROOF_PROPANE_IDS) do result[#result + 1] = id end
    end
    return result
end

function VLS.isPropaneTankPart(part)
    if not part then return false end
    for _, id in ipairs(VLS.getPropaneTankPartIds(part:getVehicle())) do
        if part:getId() == id then return true end
    end
    return false
end

function VLS.getInstalledPropaneSource(vehicle, preferredPartId, expectedItemId)
    for _, id in ipairs(VLS.getPropaneTankPartIds(vehicle)) do
        if not preferredPartId or preferredPartId == id then
            local roof = id == "VLSRoofPropane1" or id == "VLSRoofPropane2"
            local part = vehicle:getPartById(id)
            local item = part and part:getInventoryItem()
            if (not roof or (VLS.isRoofPropaneRefillEnabled() and VLSRoofCargo.fixed(vehicle)))
                    and item and item:getFullType() == "Base.PropaneTank"
                    and instanceof(item, "DrainableComboItem")
                    and (not expectedItemId or item:getID() == expectedItemId)
                    and item:getCurrentUses() > 0 then
                return item, part
            end
        end
    end
    return nil
end

return VLS
