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

local function registerKI5WaterTankOverlays()
    VLS.registerMechanicsOverlay(PARTS, GUIDES)
end

registerKI5WaterTankOverlays()
