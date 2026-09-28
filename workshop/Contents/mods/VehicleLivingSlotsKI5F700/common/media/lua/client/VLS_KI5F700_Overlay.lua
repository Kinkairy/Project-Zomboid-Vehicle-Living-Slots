local A=require "VLS_KI5F700_Config"
require "VLS_VehicleMechanicsOverlay"
require "Vehicles/ISUI/ISCarMechanicsOverlay"
require "Vehicles/ISUI/ISVehicleMechanics"
if A.overlayApplied then return end
A.overlayApplied=true

local imagePath="media/ui/vehicles/mechanic overlay/"
local vans={["87fordF700bank_"]=434,["87fordF700swat_"]=424}
local busPrefix="87fordB700_"
-- Rectangles are panel coordinates, matching native isMouseOverPart.
-- Crops contain the icon/frame only, never the old baked connector.
local vanParts={
    VLSLargeVanWaterTank={img="vls_water_tank",x=8,y=268,w=52,h=80,crop={208,264,52,80},line={{60,308},{91,308}}},
    VLSF700WaterTank2={img="vls_water_right",x=223,y=268,w=52,h=80,crop={208,264,52,80},line={{223,308},{196,308}}},
    VLSAuxBatterySlot={img="vls_aux_battery",x=120,y=527,w=46,h=34,crop={6,281,46,34}},
}
local busParts={
    VLSLargeVanWaterTank={x=13,y=482,w=42,h=30,line={{55,497},{73,497},{92,480}}},
    VLSF700WaterTank2={x=228,y=482,w=42,h=30,line={{228,497},{210,497},{194,480}}},
    VLSF700WaterTank3={x=13,y=567,w=42,h=30,line={{55,582},{65,582},{65,520},{103,498}}},
    VLSF700WaterTank4={x=228,y=567,w=42,h=30,line={{228,582},{194,582},{194,520},{181,498}}},
    VLSAuxBatterySlot={x=228,y=103,w=42,h=31,battery=true,line={{228,118},{194,118}}},
    VLSF700Battery3={x=78,y=527,w=42,h=31,battery=true,line={{99,527},{99,513},{123,499}}},
}
local busNative={
    GasTank={img="gastank",x=13,y=527,w=42,h=30,crop={3,526,58,39},line={{55,542},{65,542},{65,520},{103,498}}},
    DAMNWindshieldRearArmor={img="windshield_rear_armor",x=144,y=526,w=43,h=38,crop={109,525,44,40},line={{165,526},{165,512},{160,499}}},
}
local function rectangle(s)
    return {x=s.x,y=s.y,x2=s.x+s.w,y2=s.y+s.h}
end
local function register()
    local parts,guides={},{}
    for id,s in pairs(vanParts) do
        local vehicles={}
        for prefix,r in pairs((VLS.mechanicsOverlayParts[id] or {}).vehicles or {}) do vehicles[prefix]=r end
        for prefix in pairs(vans) do vehicles[prefix]=rectangle(s) end
        parts[id]={img=s.img,vehicles=vehicles};guides[id]=s.img.."_guide"
    end
    VLS.registerMechanicsOverlay(parts,guides)
    -- Bus icons reuse native KI5 artwork at draw time. No copied KI5 assets
    -- and no Bus-specific paths are added to the shared static-guide registry.
    for id,s in pairs(busParts) do
        local part=ISCarMechanicsOverlay.PartList[id] or {}
        ISCarMechanicsOverlay.PartList[id]=part
        part.vehicles=part.vehicles or {};part.vehicles[busPrefix]=rectangle(s)
    end
    for id,s in pairs(busNative) do
        local part=ISCarMechanicsOverlay.PartList[id]
        if part then part.vehicles=part.vehicles or {};part.vehicles[busPrefix]=rectangle(s) end
    end
end
register()
Events.OnGameStart.Add(register)

local function line(panel,points)
    for i=2,#points do
        local p,q=points[i-1],points[i]
        panel:drawLine(nil,p[1],p[2],q[1],q[2],1,1,0.65,0.65,0.65)
    end
end
local function crop(panel,texture,source,target,a,r,g,b)
    if not texture then return end
    panel:drawSubTexture(texture,source[1],source[2],source[3],source[4],
        target.x,target.y,target.w,target.h,a,r,g,b)
end
local function busBase(panel,texture,props,scale,a,r,g,b)
    -- The body and untouched components stay at the native origin. Omit only
    -- the old fuel/armor cells; repaint those cells at their reviewed positions.
    panel:drawSubTexture(texture,0,0,263,520,props.x,props.y,263*scale,520*scale,a,r,g,b)
    panel:drawSubTexture(texture,189,520,74,80,props.x+189*scale,props.y+520*scale,74*scale,80*scale,a,r,g,b)
    for id,s in pairs(busNative) do
        crop(panel,texture,s.crop,s,1,1,1,1)
        line(panel,s.line)
        if id=="GasTank" then panel:drawRectBorder(s.x,s.y,s.w,s.h,1,1,1,1) end
    end
    for id,s in pairs(busParts) do
        local part=panel.vehicle:getPartById(id)
        if part then
            local source=s.battery and {3,103,42,31} or {3,526,58,39}
            crop(panel,texture,source,s,1,1,1,1)
            panel:drawRectBorder(s.x,s.y,s.w,s.h,1,1,1,1)
            line(panel,s.line)
            local missing=not part:getInventoryItem() and part:getTable("install")
            local color=panel:getConditionRGB(missing and 0 or part:getCondition())
            local alpha=(missing or part:getCondition()<10) and ISVehicleMechanics.alphaOverlay or 0.9
            local mask=getTexture(imagePath..busPrefix..(s.battery and "battery" or "gastank")..".png")
            crop(panel,mask,source,s,alpha,color.r,color.g,color.b)
        end
    end
end

local native=ISVehicleMechanics.renderCarOverlay
function ISVehicleMechanics:renderCarOverlay()
    local script=self.vehicle and self.vehicle:getScript()
    local props=script and ISCarMechanicsOverlay.CarList[script:getCarMechanicsOverlay() or self.vehicle:getScriptName()]
    local prefix=props and props.imgPrefix
    if not vans[prefix] and prefix~=busPrefix then return native(self) end
    local masks={}
    if prefix==busPrefix then
        -- Native still owns every part's tooltip, mouse hit and selection.
        -- Empty image lists prevent nonexistent per-Bus VLS texture requests.
        props.PartList=props.PartList or {}
        for id in pairs(busParts) do props.PartList[id]={multipleImg=true,img={}} end
        for _,s in pairs(busNative) do
            local texture=getTexture(imagePath..prefix..s.img..".png")
            if texture then masks[texture]={spec=s} end
        end
    else
        for _,s in pairs(vanParts) do
            for _,suffix in ipairs({"","_guide"}) do
                local texture=getTexture(imagePath..prefix..s.img..suffix..".png")
                if texture then masks[texture]={spec=s,guide=suffix~=""} end
            end
        end
    end
    local baseTexture=prefix==busPrefix and getTexture(imagePath..prefix.."base.png") or nil
    local raw=rawget(self,"drawTextureScaledUniform")
    local draw=self.drawTextureScaledUniform
    self.drawTextureScaledUniform=function(panel,texture,x,y,scale,a,r,g,b)
        if baseTexture and texture==baseTexture then return busBase(panel,texture,props,scale,a,r,g,b) end
        local entry=texture and masks[texture]
        if not entry then return draw(panel,texture,x,y,scale,a,r,g,b) end
        local s=entry.spec
        crop(panel,texture,s.crop,s,a,r,g,b)
        if entry.guide then
            line(panel,s.line or {{143,527},{143,vans[prefix]}})
        end
    end
    local ok,result=pcall(native,self)
    self.drawTextureScaledUniform=raw
    if not ok then error(result) end
    return result
end
