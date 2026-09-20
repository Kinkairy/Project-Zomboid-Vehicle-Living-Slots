local VLS = require "VLS_Config"
require "Vehicles/ISUI/ISVehicleSeatUI"

-- A render-only adapter: native render still owns selection, characters,
-- outlines and joypad controls. Never fabricate seat inventory/occupancy.
VLS.seatDisplay = VLS.seatDisplay or {}
local hook = VLS.seatDisplay
local PREFIX = "media/ui/vehicles/seatui/"

local function equipmentRects(panel)
    local vehicle=panel.vehicle
    local result={}
    if not vehicle or not VLS.isSupportedVehicle(vehicle) then return result end
    local script=vehicle:getScript()
    local scale=panel.height*0.7/script:getExtents():z()
    local name=vehicle:getScriptName()
    for seat=0,vehicle:getMaxPassengers()-1 do
        local part=VLS.getInstalledUniversalPartForSeat(vehicle,seat)
        if part and not VLS.getInstalledBedPartForSeat(vehicle,seat) and not vehicle:getCharacter(seat) then
            local passenger=script:getPassenger(seat)
            local position=passenger and passenger:getPositionById("inside")
            local offset=position and position:getOffset()
            if offset then
                result[#result+1]={
                    x=panel:getWidth()/2-offset:get(0)*scale-41/2+(SeatOffsetX[name] or 0),
                    y=panel:getHeight()/2-offset:get(2)*scale-59/2+(SeatOffsetY[name] or 0),
                }
            end
        end
    end
    return result
end
local function atRect(rects,x,y)
    for _,rect in ipairs(rects) do
        if math.abs(x-rect.x)<0.01 and math.abs(y-rect.y)<0.01 then return true end
    end
    return false
end
local function install()
    if hook.class==ISVehicleSeatUI then return end
    hook.class=ISVehicleSeatUI
    local native=ISVehicleSeatUI.render
    hook.wrapper=function(panel,...)
        -- KI5's enclosing render has already applied its temporary UI offsets.
        local rects=equipmentRects(panel)
        if #rects==0 then return native(panel,...) end
        local rawDraw=rawget(panel,"drawTextureScaledUniform")
        local draw=panel.drawTextureScaledUniform
        local empty=getTexture(PREFIX.."icon_vehicle_empty.png")
        local removed=getTexture(PREFIX.."icon_vehicle_uninstalled.png")
        local stuff=getTexture(PREFIX.."icon_vehicle_stuff.png")
        local rawText=rawget(panel,"drawTextCentre")
        local text=panel.drawTextCentre
        local whiteRects={}
        panel.drawTextureScaledUniform=function(self,texture,x,y,...)
            if stuff and (texture==empty or texture==removed)
                    and atRect(rects,x,y) then
                texture=stuff
                whiteRects[#whiteRects+1]={x=x,y=y}
            end
            return draw(self,texture,x,y,...)
        end
        panel.drawTextCentre=function(self,label,x,y,r,g,b,a,font)
            if font==UIFont.Large and tonumber(label) then
                for _,rect in ipairs(whiteRects) do
                    if math.abs(x-(rect.x+41/2))<0.01 and y>=rect.y and y<=rect.y+59 then
                        r,g,b=0,0,0;break
                    end
                end
            end
            return text(self,label,x,y,r,g,b,a,font)
        end
        local ok,result=pcall(native,panel,...)
        panel.drawTextureScaledUniform=rawDraw
        panel.drawTextCentre=rawText
        if not ok then error(result) end
        return result
    end
    ISVehicleSeatUI.render=hook.wrapper
end
-- Install once after all required client modules. No periodic wrapper stacking.
install()
