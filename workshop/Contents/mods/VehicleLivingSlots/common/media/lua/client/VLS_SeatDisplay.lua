local VLS = require "VLS_Config"
require "Vehicles/ISUI/ISVehicleSeatUI"

-- Render-only layout and equipment icons. Native controls and vehicle state stay intact.
VLS.seatDisplay = VLS.seatDisplay or {}
local hook = VLS.seatDisplay
local PREFIX = "media/ui/vehicles/seatui/"

local function layoutPositions(panel)
    local vehicle=panel.vehicle
    local profile=vehicle and VLS.getVehicleProfile and VLS.getVehicleProfile(vehicle)
    local count=profile and (profile.kind=="mediumVan" and 3 or profile.kind=="largeVan" and 5)
    if not count or #(profile.spacePassengers or {})~=count then return {} end
    local script=vehicle:getScript()
    if not script or not script.getPassengerIndex then return {} end
    local function inside(id)
        local index=script:getPassengerIndex(id)
        local passenger=index>=0 and script:getPassenger(index)
        local position=passenger and passenger:getPositionById("inside")
        return position and position:getOffset()
    end
    local left,right=inside("FrontLeft"),inside("FrontRight")
    local scale=panel.height*0.7/script:getExtents():z()
    if not left or not right or scale<=0 then return {} end
    local firstZ=math.min(left:get(2),right:get(2))
    local positions={}
    for index,assignment in ipairs(profile.spacePassengers) do
        local offset=inside(assignment.passenger)
        if not offset then return {} end
        positions[#positions+1]={offset=offset,x=offset:get(0),y=offset:get(1),z=offset:get(2),
            displayX=index==count and (left:get(0)+right:get(0))/2
                or (index%2==1 and left:get(0) or right:get(0)),
            displayZ=firstZ-math.ceil(index/2)*70/scale}
    end
    return positions
end

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
                result[#result+1]={seat=seat,
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
        if math.abs(x-rect.x)<0.01 and math.abs(y-rect.y)<0.01 then return rect end
    end
end
-- Living slots share real exits, but only installed, reachable beds are seats.
-- Keep physical outside offsets intact: native obstruction checks must use them.
local function livingExits(panel)
    local vehicle=panel.vehicle
    local profile=vehicle and VLS.getVehicleProfile and VLS.getVehicleProfile(vehicle)
    local groups,seats={},{}
    if not profile or vehicle:getSeat(panel.character)==-1 then return groups,seats end
    local script=vehicle:getScript()
    if not script.getPassengerIndex then return groups,seats end
    local scale=panel.height*0.7/script:getExtents():z()
    local shiftY=SeatOffsetY[vehicle:getScriptName()] or 0
    local current=vehicle:getSeat(panel.character)
    local function usable(seat,living)
        if living then
            if not VLS.getInstalledBedPartForSeat(vehicle,seat) then return false end
        elseif not vehicle:isSeatInstalled(seat) then return false end
        if panel.joyfocus and panel.joypadSeat~=seat+1 then return false end
        local canSwitch=vehicle:canSwitchSeat(current,seat)
        if vehicle:isSeatOccupied(seat) then
            canSwitch=not vehicle:getCharacter(seat)
                and ISVehicleMenu.moveItemsFromSeat(panel.character,vehicle,seat,false,false)
        end
        if current==seat then canSwitch=true end
        if not canSwitch then return false end
        vehicle:updateHasExtendOffsetForExit(panel.character)
        local ok,blocked=pcall(vehicle.isExitBlocked,vehicle,panel.character,seat)
        vehicle:updateHasExtendOffsetForExitEnd(panel.character)
        if not ok then error(blocked) end
        return not blocked
    end
    for _,assignment in ipairs(profile.spacePassengers or {}) do
        local seat=script:getPassengerIndex(assignment.passenger)
        local passenger=seat>=0 and script:getPassenger(seat)
        local position=passenger and passenger:getPositionById("outside")
        local offset=position and position:getOffset()
        if offset then
            local x=panel:getWidth()/2-offset:get(0)*scale
            local y=panel:getHeight()/2-offset:get(2)*scale+shiftY
            local group
            for _,g in ipairs(groups) do
                if math.abs(g.x-x)<0.01 and math.abs(g.y-y)<0.01 then group=g;break end
            end
            if not group then
                group={x=x,y=y,rear=offset:get(2)<0
                    and math.abs(offset:get(0))<=script:getExtents():x()*0.2}
                groups[#groups+1]=group
            end
            seats[seat]=group
            if usable(seat,true) and (group.seat==nil or seat==current) then group.seat=seat end
        end
    end
    -- Native rear seats can share a door with added living slots (for example SWAT).
    -- They remain valid exits without a bed and take precedence unless already on a bed.
    for seat=0,vehicle:getMaxPassengers()-1 do
        if not seats[seat] then
            local passenger=script:getPassenger(seat)
            local position=passenger and passenger:getPositionById("outside")
            local offset=position and position:getOffset()
            if offset then
                local x=panel:getWidth()/2-offset:get(0)*scale
                local y=panel:getHeight()/2-offset:get(2)*scale+shiftY
                for _,group in ipairs(groups) do
                    if math.abs(group.x-x)<0.01 and math.abs(group.y-y)<0.01 then
                        seats[seat]=group
                        if usable(seat,false) and (group.seat==nil or seat==current
                                or (group.seat~=current and not group.nativeSeat)) then
                            group.seat=seat;group.nativeSeat=true
                        end
                        break
                    end
                end
            end
        end
    end
    return groups,seats
end

local function install()
    if hook.class==ISVehicleSeatUI then return end
    hook.class=ISVehicleSeatUI
    local native=ISVehicleSeatUI.render
    hook.wrapper=function(panel,...)
        local args={n=select("#",...),...}
        local positions={}
        local profile=panel.vehicle and VLS.getVehicleProfile and VLS.getVehicleProfile(panel.vehicle)
        local ownLayout=profile and (profile.kind=="smallVan" or profile.kind=="mediumVan" or profile.kind=="largeVan")
        local initialHeight=panel.height
        local rawHeight=rawget(panel,"getHeight")
        local rawDraw=rawget(panel,"drawTextureScaledUniform")
        local rawText=rawget(panel,"drawTextCentre")
        local rawRect=rawget(panel,"drawRect")
        local draw,text,drawRect=panel.drawTextureScaledUniform,panel.drawTextCentre,panel.drawRect
        panel.vlsSeatExitBottom=nil
        local ok,result=pcall(function()
            -- Optional adapters own their layout and panel size.
            if ownLayout and panel.vlsSeatDisplayOriginalHeight then panel.height=panel.vlsSeatDisplayOriginalHeight end
            positions=layoutPositions(panel)
            if ownLayout then
                panel.vlsSeatDisplayOriginalHeight=panel.height
                panel.getHeight=function()return panel.vlsSeatDisplayOriginalHeight end
            end
            for _,p in ipairs(positions) do p.offset:set(p.displayX,p.y,p.displayZ) end
            local rects=equipmentRects(panel)
            local exits,exitSeats=livingExits(panel)
            if #rects==0 and #exits==0 then return native(panel,unpack(args,1,args.n)) end
            local empty=getTexture(PREFIX.."icon_vehicle_empty.png")
            local removed=getTexture(PREFIX.."icon_vehicle_uninstalled.png")
            local stuff=getTexture(PREFIX.."icon_vehicle_stuff.png")
            local exitTexture=getTexture("media/ui/vehicles/vehicle_exit.png")
            local joyExit=Joypad.Texture.XButton
            local fontHeight=getTextManager():getFontHeight(UIFont.Large)
            local bodyBottom=panel.vlsSeatBodyBottom or panel.height*0.85
            local script=panel.vehicle:getScript()
            local props=ISCarMechanicsOverlay.CarList[script:getCarMechanicsOverlay() or panel.vehicle:getScriptName()]
            local bodyTexture=props and props.imgPrefix and getTexture(PREFIX..props.imgPrefix.."base_small.png")
            local function oldExit(x,y,texture)
                if not texture then return nil end
                for _,g in ipairs(exits) do
                    if math.abs(x+texture:getWidthOrig()/2-g.x)<0.01
                            and math.abs(y+texture:getHeightOrig()/2-g.y)<0.01 then return g end
                end
            end
            panel.drawTextureScaledUniform=function(self,texture,x,y,scale,...)
                if (texture==exitTexture or texture==joyExit) and oldExit(x,y,texture) then return end
                -- Texture-pack canvases include transparent padding; Java draws
                -- only the cropped rectangle at offsetX/offsetY.
                if texture==bodyTexture then bodyBottom=y+(texture:getOffsetY()+texture:getHeight())*scale end
                local rect=atRect(rects,x,y)
                if stuff and (texture==empty or texture==removed) and rect then texture=stuff end
                return draw(self,texture,x,y,scale,...)
            end
            panel.drawRect=function(self,x,y,w,h,...)
                if w==16 and h==fontHeight then
                    for _,g in ipairs(exits) do
                        if math.abs(x+8-g.x)<0.01 and math.abs(y+fontHeight/2-g.y)<0.01 then return end
                    end
                end
                return drawRect(self,x,y,w,h,...)
            end
            panel.drawTextCentre=function(self,label,x,y,r,g,b,a,font)
                local number=tonumber(label)
                if font==UIFont.Large and number then
                    local exit=exitSeats[number-1]
                    if exit and math.abs(x-exit.x)<0.01 and math.abs(y+fontHeight/2-exit.y)<0.01 then return end
                    for _,rect in ipairs(rects) do
                        if math.abs(x-(rect.x+41/2))<0.01 and y>=rect.y and y<=rect.y+59 then
                            r,g,b=0,0,0;rect.numberDrawn=true;break
                        end
                    end
                end
                return text(self,label,x,y,r,g,b,a,font)
            end
            local value=native(panel,unpack(args,1,args.n))
            -- Position numbers do not grant permission to enter equipment slots.
            for _,rect in ipairs(rects) do
                if not rect.numberDrawn then
                    text(panel,tostring(rect.seat+1),rect.x+41/2,rect.y+59/2-fontHeight/2,
                        0,0,0,1,UIFont.Large)
                end
            end
            if exitSeats[panel.mouseOverExit] then panel.mouseOverExit=nil end
            local scale=panel.height*0.7/script:getExtents():z()
            local shiftY=SeatOffsetY[panel.vehicle:getScriptName()] or 0
            for seat in pairs(exitSeats) do
                local inside=script:getPassenger(seat):getPositionById("inside")
                if inside then bodyBottom=math.max(bodyBottom,panel:getHeight()/2-inside:getOffset():get(2)*scale+shiftY+59/2) end
            end
            local shift=isKeyDown(Keyboard.KEY_LSHIFT) or isKeyDown(Keyboard.KEY_RSHIFT)
            for _,g in ipairs(exits) do
                local texture=panel.joyfocus and joyExit or exitTexture
                if g.seat~=nil and texture then
                    local w,h=texture:getWidthOrig(),texture:getHeightOrig()
                    local x,y=g.x-w/2,g.y-h/2
                    local offsetX,offsetY=texture:getOffsetX(),texture:getOffsetY()
                    if g.rear then
                        w,h=texture:getWidth(),texture:getHeight()
                        x,y=panel:getWidth()/2-w/2,bodyBottom+4
                    else
                        x,y=x+offsetX,y+offsetY
                        w,h=texture:getWidth(),texture:getHeight()
                    end
                    local hover=panel:getMouseX()>=x and panel:getMouseX()<x+w
                        and panel:getMouseY()>=y and panel:getMouseY()<y+h
                    draw(panel,texture,x-offsetX,y-offsetY,1,(hover or shift or panel.joyfocus) and 1 or 0.2,1,1,1)
                    if not panel.joyfocus and hover then panel.mouseOverExit=g.seat end
                    if not panel.joyfocus and shift then
                        drawRect(panel,x+w/2-8,y+h/2-fontHeight/2,16,fontHeight,1,0.1,0.1,0.1)
                        text(panel,tostring(g.seat+1),x+w/2,y+h/2-fontHeight/2,1,1,1,1,UIFont.Large)
                    end
                    if g.rear then panel.vlsSeatExitBottom=math.max(panel.vlsSeatExitBottom or 0,y+h) end
                end
            end
            return value
        end)
        panel.drawTextureScaledUniform=rawDraw;panel.drawTextCentre=rawText;panel.drawRect=rawRect
        panel.getHeight=rawHeight
        for _,p in ipairs(positions) do p.offset:set(p.x,p.y,p.z) end
        if ownLayout then
            local height=ok and math.max(panel.vlsSeatDisplayOriginalHeight,(panel.vlsSeatExitBottom or 0)+45) or initialHeight
            panel:setHeight(height)
            if panel.close then panel.close:setY(height-35) end
        end
        if not ok then error(result) end
        return result
    end
    ISVehicleSeatUI.render=hook.wrapper
end
-- Install once after all required client modules. No periodic wrapper stacking.
install()
