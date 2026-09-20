local VLS = require "VLS_KI5Campers_Config"
require "VLS_VehicleMechanicsOverlay"
require "Vehicles/ISUI/ISCarMechanicsOverlay"
require "Vehicles/ISUI/ISVehicleMechanics"

local VEHICLES_LEFT = {
    Trailer87Scamp13_ = { x = 13, y = 64, x2 = 65, y2 = 144 },
    Trailer87Scamp16_ = { x = 13, y = 64, x2 = 65, y2 = 144 },
    Trailer61Bambi16_ = { x = 13, y = 64, x2 = 65, y2 = 144 },
    Trailer54FlyingCloud22_ = { x = 13, y = 64, x2 = 65, y2 = 144 },
    Trailer61shastaAirflyte_ = { x = 13, y = 384, x2 = 65, y2 = 464 },
    Trailer61shastaAstrodome_ = { x = 13, y = 384, x2 = 65, y2 = 464 },
}
local VEHICLES_RIGHT = {
    Trailer87Scamp13_ = { x = 208, y = 64, x2 = 260, y2 = 144 },
    Trailer87Scamp16_ = { x = 208, y = 64, x2 = 260, y2 = 144 },
    Trailer61Bambi16_ = { x = 208, y = 64, x2 = 260, y2 = 144 },
    Trailer54FlyingCloud22_ = { x = 208, y = 64, x2 = 260, y2 = 144 },
    Trailer61shastaAirflyte_ = { x = 208, y = 384, x2 = 260, y2 = 464 },
    Trailer61shastaAstrodome_ = { x = 208, y = 384, x2 = 260, y2 = 464 },
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

-- Shasta's original upper-left windshield occupies the old tank position.
-- Move only the four VLS masks below the original parts, without editing KI5
-- assets/registries. Native rendering and hit testing use matching coordinates.
if not VLS.ki5ShastaOverlayApplied then
    VLS.ki5ShastaOverlayApplied=true
    local native=ISVehicleMechanics.renderCarOverlay
    function ISVehicleMechanics:renderCarOverlay()
        local name=self.vehicle and self.vehicle:getScriptName()
        local prefix=name=="Base.Trailer61Airflyte" and "Trailer61shastaAirflyte_"
            or name=="Base.Trailer61Astrodome" and "Trailer61shastaAstrodome_"
        if not prefix then return native(self) end
        local masks={}
        for _,suffix in ipairs({"left","right","left_guide","right_guide"}) do
            local texture=getTexture("media/ui/vehicles/mechanic overlay/"..
                prefix.."vls_water_tank_"..suffix..".png")
            if texture then masks[texture]=true end
        end
        local raw=rawget(self,"drawTextureScaledUniform")
        local draw=self.drawTextureScaledUniform
        self.drawTextureScaledUniform=function(panel,texture,x,y,...)
            return draw(panel,texture,x,y+(masks[texture] and 320 or 0),...)
        end
        local ok,result=pcall(native,self)
        self.drawTextureScaledUniform=raw
        if not ok then error(result) end
        return result
    end
end
