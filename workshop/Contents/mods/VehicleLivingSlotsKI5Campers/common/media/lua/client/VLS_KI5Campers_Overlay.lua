local VLS = require "VLS_KI5Campers_Config"
require "VLS_VehicleMechanicsOverlay"
require "Vehicles/ISUI/ISCarMechanicsOverlay"
require "Vehicles/ISUI/ISVehicleMechanics"

local VEHICLES_LEFT = {
    Trailer87Scamp13_ = { x = 13, y = 64, x2 = 65, y2 = 144 },
    Trailer87Scamp16_ = { x = 13, y = 64, x2 = 65, y2 = 144 },
    Trailer61Bambi16_ = { x = 13, y = 64, x2 = 65, y2 = 144 },
    Trailer54FlyingCloud22_ = { x = 13, y = 64, x2 = 65, y2 = 144 },
}
local VEHICLES_RIGHT = {
    Trailer87Scamp13_ = { x = 208, y = 64, x2 = 260, y2 = 144 },
    Trailer87Scamp16_ = { x = 208, y = 64, x2 = 260, y2 = 144 },
    Trailer61Bambi16_ = { x = 208, y = 64, x2 = 260, y2 = 144 },
    Trailer54FlyingCloud22_ = { x = 208, y = 64, x2 = 260, y2 = 144 },
}

local PARTS = {
    VLSKI5CamperWaterTank1 = {
        img = "vls_water_tank_left",
        vehicles = VEHICLES_LEFT,
    },
    VLSKI5CamperWaterTank2 = {
        img = "vls_water_tank_right",
        vehicles = VEHICLES_RIGHT,
    },
}

local GUIDES = {
    VLSKI5CamperWaterTank1 = "vls_water_tank_left_guide",
    VLSKI5CamperWaterTank2 = "vls_water_tank_right_guide",
}

local function registerPart(partId, spec)
    local part = ISCarMechanicsOverlay.PartList[partId] or {}
    part.img = spec.img
    part.vehicles = part.vehicles or {}
    for prefix, coords in pairs(spec.vehicles) do
        part.vehicles[prefix] = coords
    end
    ISCarMechanicsOverlay.PartList[partId] = part
end
local function registerKI5WaterTankOverlays()
    for partId, spec in pairs(PARTS) do
        registerPart(partId, spec)
    end
end

local function getOverlayProperties(vehicle)
    local overlayName = vehicle:getScriptName()
    if vehicle:getScript():getCarMechanicsOverlay() then
        overlayName = vehicle:getScript():getCarMechanicsOverlay()
    end
    return ISCarMechanicsOverlay.CarList[overlayName]
end

local function drawKI5WaterTankGuides(panel)
    local props = panel.vehicle and getOverlayProperties(panel.vehicle)
    if not props then return end
    for partId, imageName in pairs(GUIDES) do
        if panel.vehicle:getPartById(partId) then
            local texture = getTexture(
                "media/ui/vehicles/mechanic overlay/" ..
                props.imgPrefix .. imageName .. ".png"
            )
            if texture then
                panel:drawTextureScaledUniform(
                    texture, props.x, props.y, 1, 1, 1, 1, 1
                )
            end
        end
    end
end

registerKI5WaterTankOverlays()

if not VLS.ki5CampersGuideHookApplied then
    VLS.ki5CampersGuideHookApplied = true
    local originalRenderCarOverlay = ISVehicleMechanics.renderCarOverlay
    function ISVehicleMechanics:renderCarOverlay()
        drawKI5WaterTankGuides(self)
        originalRenderCarOverlay(self)
    end
end

if not VLS.ki5CampersOverlayEventApplied then
    VLS.ki5CampersOverlayEventApplied = true
    Events.OnGameStart.Add(registerKI5WaterTankOverlays)
end
