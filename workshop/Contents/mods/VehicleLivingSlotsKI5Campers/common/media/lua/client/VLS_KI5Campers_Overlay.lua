local VLS = require "VLS_KI5Campers_Config"
require "VLS_VehicleMechanicsOverlay"
require "Vehicles/ISUI/ISCarMechanicsOverlay"
require "Vehicles/ISUI/ISVehicleMechanics"

local VEHICLES_LEFT, VEHICLES_RIGHT = {}, {}
for _,prefix in ipairs({"Trailer87Scamp13_", "Trailer87Scamp16_", "Trailer61Bambi16_",
        "Trailer54FlyingCloud22_", "Trailer61shastaAirflyte_", "Trailer61shastaAstrodome_"}) do
    VEHICLES_LEFT[prefix]={x=223,y=384,x2=275,y2=464}
    VEHICLES_RIGHT[prefix]={x=223,y=484,x2=275,y2=564}
end

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

-- Connect both tanks to the actual outline of each native trailer. Shorter
-- trailers use a shared clear gutter; no connector crosses the other tank.
local anchors={
    Trailer87Scamp13_={204,300}, Trailer87Scamp16_={205,350},
    Trailer61Bambi16_={205,350}, Trailer54FlyingCloud22_={205,424},
    Trailer61shastaAirflyte_={207,350}, Trailer61shastaAstrodome_={207,350},
}
if not VLS.ki5WaterTankOverlayApplied then
    VLS.ki5WaterTankOverlayApplied=true
    local native=ISVehicleMechanics.renderCarOverlay
    function ISVehicleMechanics:renderCarOverlay()
        local script=self.vehicle and self.vehicle:getScript()
        local props=script and ISCarMechanicsOverlay.CarList[script:getCarMechanicsOverlay() or self.vehicle:getScriptName()]
        local prefix=props and props.imgPrefix
        if not VEHICLES_LEFT[prefix] then return native(self) end
        local masks={}
        for _,suffix in ipairs({"left","right","left_guide","right_guide"}) do
            local texture=getTexture("media/ui/vehicles/mechanic overlay/"..
                prefix.."vls_water_tank_"..suffix..".png")
            if texture then masks[texture]={
                left=suffix:find("^left")~=nil,guide=suffix:find("_guide")~=nil,
            } end
        end
        local raw=rawget(self,"drawTextureScaledUniform")
        local draw=self.drawTextureScaledUniform
        self.drawTextureScaledUniform=function(panel,texture,x,y,scale,a,r,g,b)
            local mask=texture and masks[texture]
            if not mask then return draw(panel,texture,x,y,scale,a,r,g,b) end
            local target=mask.left and VEHICLES_LEFT[prefix] or VEHICLES_RIGHT[prefix]
            -- Exclude the old horizontal stub at the left of the source frame.
            panel:drawSubTexture(texture,mask.left and 13 or 208,64,52,80,
                target.x,target.y,52,80,a,r,g,b)
            if mask.guide then
                local anchor=anchors[prefix]
                local cy=target.y+40
                panel:drawLine(target.x,cy,215,cy,1,0.65,0.65,0.65)
                if cy~=anchor[2] then panel:drawLine(215,cy,215,anchor[2],1,0.65,0.65,0.65) end
                panel:drawLine(215,anchor[2],anchor[1],anchor[2],1,0.65,0.65,0.65)
            end
        end
        local ok,result=pcall(native,self)
        self.drawTextureScaledUniform=raw
        if not ok then error(result) end
        return result
    end
end
