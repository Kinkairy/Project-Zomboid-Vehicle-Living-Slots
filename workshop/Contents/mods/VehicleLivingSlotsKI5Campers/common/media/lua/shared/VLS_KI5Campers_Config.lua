local VLS = require "VLS_Config"
require "VLS_Propane"

if VLS.ki5CampersAdapterApplied then return VLS end
VLS.ki5CampersAdapterApplied = true

VLS.KI5_VERSION = "3.8.9"
print("[VehicleLivingSlotsKI5Campers] Adapter version " .. VLS.KI5_VERSION)

local SLOT_IDS = {
    "VLSKI5CamperSlot1", "VLSKI5CamperSlot2", "VLSKI5CamperSlot3",
    "VLSKI5CamperSlot4",
}
local FREEZER_IDS = {
    "VLSKI5CamperFreezer1", "VLSKI5CamperFreezer2",
    "VLSKI5CamperFreezer3", "VLSKI5CamperFreezer4",
}
local WATER_TANK_IDS = {
    "VLSKI5CamperWaterTank1",
    "VLSKI5CamperWaterTank2",
}
local PROPANE_TANK_IDS = {
    "DAMNPropaneTankOne",
    "DAMNPropaneTankTwo",
}
local CONTAINER_ICON_OVERRIDES = {
    freezer = "fridge",
}

for index, slotId in ipairs(SLOT_IDS) do
    local freezerId = FREEZER_IDS[index]
    VLS.FREEZER_PART_BY_UNIVERSAL[slotId] = freezerId
    VLS.UNIVERSAL_PART_BY_FREEZER[freezerId] = slotId
    VLS.allowedItems[slotId] = {}
    for fullType, equipmentProfile in pairs(VLS.equipmentProfiles) do
        if equipmentProfile.capability ~= "weaponStorage" then
            VLS.allowedItems[slotId][fullType] = true
        end
    end
    for fullType in pairs(VLS.sleepingBagTypes) do
        VLS.allowedItems[slotId][fullType] = true
    end
end

for _, partId in ipairs(WATER_TANK_IDS) do
    VLS.WATER_TANK_PART_IDS[partId] = true
end

local function livingAssignments(positions)
    local result = {}
    for index, position in ipairs(positions) do
        result[index] = {
            part = SLOT_IDS[index],
            passenger = "VLSKI5Space" .. tostring(index),
            nameKey = "IGUI_VLSKI5Space" .. position,
        }
    end
    return result
end

local function registerProfile(scriptName, positions)
    local slotIds = {}
    for index = 1, #positions do slotIds[index] = SLOT_IDS[index] end
    VLS.vehicleProfiles["Base." .. scriptName] = {
        kind = "ki5Camper",
        universalParts = slotIds,
        spacePassengers = livingAssignments(positions),
        waterTankParts = WATER_TANK_IDS,
        propaneTankParts = PROPANE_TANK_IDS,
        containerIconOverrides = CONTAINER_ICON_OVERRIDES,
        auxBatteryPartId = "Battery",
        rearArea = "TruckBed",
    }
end

-- Follow KI5's position + part naming style. Positions describe the living
-- spaces from front to rear within each layout; part/passenger IDs stay stable.
registerProfile("Trailer87Scamp13", {"FrontLeft", "RearLeft"})
registerProfile("Trailer87Scamp16", {"Front", "Middle", "Rear"})
registerProfile("Trailer61Bambi16", {"Front", "Middle", "Rear"})
registerProfile("Trailer54FlyingCloud22", {"FrontLeft", "FrontRight", "MiddleRight", "RearLeft"})
registerProfile("Trailer61Airflyte", {"FrontLeft", "MiddleLeft", "RearLeft"})
registerProfile("Trailer61Astrodome", {"FrontLeft", "MiddleLeft", "RearLeft"})

local originalGetAuxBatteryPart = VLS.getAuxBatteryPart
function VLS.getAuxBatteryPart(vehicle)
    local profile = VLS.getVehicleProfile(vehicle)
    if not profile or profile.kind ~= "ki5Camper" then
        return originalGetAuxBatteryPart(vehicle)
    end
    local part = vehicle:getPartById(profile.auxBatteryPartId)
    local item = part and part:getInventoryItem()
    return item and instanceof(item, "DrainableComboItem") and part or nil
end

local originalGetPartDisplayName = VLS.getPartDisplayName
function VLS.getPartDisplayName(part, fallback)
    local vehicle = part and part:getVehicle()
    local profile = VLS.getVehicleProfile(vehicle)
    if profile and profile.waterTankParts then
        for _, partId in ipairs(profile.waterTankParts or {}) do
            if part:getId() == partId then
                return getText("IGUI_VehiclePart" .. partId)
            end
        end
    end
    local assignment = profile and profile.kind == "ki5Camper"
        and VLS.getSpaceAssignmentForPart(vehicle, part) or nil
    if assignment and not part:getInventoryItem() then
        return getText(assignment.nameKey)
    end
    return originalGetPartDisplayName(part, fallback)
end

function VLS.getContainerIconOverride(part, containerType)
    local profile = part and VLS.getVehicleProfile(part:getVehicle()) or nil
    local overrides = profile and profile.containerIconOverrides or nil
    return overrides and overrides[containerType] or nil
end

return VLS
