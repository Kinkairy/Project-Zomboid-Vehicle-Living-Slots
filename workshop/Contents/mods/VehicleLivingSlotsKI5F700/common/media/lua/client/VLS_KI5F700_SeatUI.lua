local A = require "VLS_KI5F700_Config"
require "VLS_SeatDisplay"
local S = require "VLS_KI5F700_Seats"
if A.seatUIApplied then return end
A.seatUIApplied = true
-- Native prerender labels an installed rear seat by passenger ID (SeatP2),
-- while the mechanics panel already uses the visible 3..8 numbering. Supply
-- the same localized name through the existing core title provider. Empty
-- spaces and fitted beds/equipment retain the existing display-name route.
local baseDisplayName=VLS.getSeatEquipmentDisplayName
function VLS.getSeatEquipmentDisplayName(vehicle,seat)
    if A.matches(vehicle) then
        local profile=VLS.getVehicleProfile(vehicle)
        for _,pair in ipairs(profile.seatPairs or {}) do
            if vehicle:getScript():getPassengerIndex(pair.passenger)==seat then
                local native=vehicle:getPartById(pair.seat)
                if native and native:getInventoryItem() then return getText(pair.nameKey) end
                break
            end
        end
    end
    return baseDisplayName(vehicle,seat)
end

-- Core display handles additive slots. Paired native seats need a shared rear
-- exit that remains usable when an original seat (rather than a bed) is fitted.
local function rearCandidate(panel,profile)
    local v,script=panel.vehicle,panel.vehicle:getScript()
    local current=v:getSeat(panel.character)
    if current<0 then return nil end
    local chosen,chosenNative
    local candidates={}
    if profile.driverOnly then candidates[1]={seat="SeatFrontLeft",passenger="FrontLeft"} end
    for _,pair in ipairs(profile.seatPairs or {}) do candidates[#candidates+1]=pair end
    for _,pair in ipairs(candidates) do
        local seat=script:getPassengerIndex(pair.passenger)
        local native=v:getPartById(pair.seat):getInventoryItem()~=nil
        local installed=native or VLS.getInstalledBedPartForSeat(v,seat)~=nil
        if installed and (not panel.joyfocus or panel.joypadSeat==seat+1) then
            local usable=v:canSwitchSeat(current,seat)
            if v:isSeatOccupied(seat) then
                usable=not v:getCharacter(seat) and ISVehicleMenu.moveItemsFromSeat(panel.character,v,seat,false,false)
            end
            if current==seat then usable=true end
            if usable then
                v:updateHasExtendOffsetForExit(panel.character)
                local ok,blocked=pcall(v.isExitBlocked,v,panel.character,seat)
                v:updateHasExtendOffsetForExitEnd(panel.character)
                if not ok then error(blocked) end
                if not blocked and (chosen==nil or seat==current
                        or (chosen~=current and native and not chosenNative)) then chosen,chosenNative=seat,native end
            end
        end
    end
    return chosen
end
local baseRender=ISVehicleSeatUI.render
function ISVehicleSeatUI:render()
    if not A.matches(self.vehicle) then return baseRender(self) end
    local profile=VLS.getVehicleProfile(self.vehicle)
    local paired=#(profile.seatPairs or {})>0
    local bus=profile.driverOnly==true
    if paired then S.sync(self.vehicle) end
    local indices={};for i,pair in ipairs(profile.spacePassengers) do indices[pair.passenger]=i end
    local rows=math.ceil(#profile.spacePassengers/2)
    local script=self.vehicle:getScript()
    local previousHeight=self.height
    local originalHeight=self.vlsF700OriginalHeight or self.height
    self.vlsF700OriginalHeight=originalHeight
    local scale=originalHeight*0.7/script:getExtents():z()
    local name=self.vehicle:getScriptName()
    local shiftX,shiftY=SeatOffsetX[name] or 0,SeatOffsetY[name] or 0
    local left,right,lastY=self.width*0.35,self.width*0.65,0
    local changed={}
    for i=0,script:getPassengerCount()-1 do
        local p=script:getPassenger(i)
        local position=p:getPositionById("inside")
        local o=position and position:getOffset()
        if o then
            local x,y,z=o:get(0),o:get(1),o:get(2)
            local index=indices[p:getId()]
            if index then changed[#changed+1]={o=o,x=x,y=y,z=z,index=index}
            else
                local pixelX=self.width/2+shiftX-x*scale
                lastY=math.max(lastY,originalHeight/2+shiftY-z*scale)
                if p:getId()=="FrontLeft" then left=pixelX end
                if p:getId()=="FrontRight" then right=pixelX end
            end
        end
    end
    local pitch=70
    if bus then
        local screen=getPlayerScreenHeight and getPlayerScreenHeight(self.playerNum or 0) or 720
        pitch=math.max(60,math.min(70,(screen-190)/7))
        left,right,lastY=self.width*0.35,self.width*0.65,90
        local driver=script:getPassenger(script:getPassengerIndex("FrontLeft")):getPositionById("inside"):getOffset()
        changed[#changed+1]={o=driver,x=driver:get(0),y=driver:get(1),z=driver:get(2),index=0}
    end
    local height=math.max(originalHeight,math.ceil((lastY+rows*70+35)/0.85),math.ceil(lastY+rows*70+80))
    if bus then height=lastY+rows*pitch+59/2+53 end
    if self.height~=height then self:setHeight(height) end
    if self.close then self.close:setY(height-35) end
    local ownBodyBottom=self.vlsSeatBodyBottom
    local ownHeight=rawget(self,"getHeight")
    local ownRect,ownBorder=rawget(self,"drawRect"),rawget(self,"drawRectBorder")
    local bodyHeight=originalHeight*0.7
    local extents=script:getExtents()
    local bodyWidth=extents.x and bodyHeight*extents:x()/extents:z() or 0
    local function extend(draw)
        if not draw then return nil end
        return function(panel,x,y,w,h,...)
            if math.abs(x-(self.width-bodyWidth)/2)<0.001 and math.abs(y-originalHeight*0.15)<0.001
                    and math.abs(w-bodyWidth)<0.001 and math.abs(h-bodyHeight)<0.001 then
                if bus then x=left-29;y=lastY-38;w=right-left+58;h=height-45-y
                else h=h+height-originalHeight end
            end
            return draw(panel,x,y,w,h,...)
        end
    end
    local rect,border=extend(self.drawRect),extend(self.drawRectBorder)
    local ownTexture,ownText=rawget(self,"drawTextureScaledUniform"),rawget(self,"drawTextCentre")
    local textureDraw,textDraw=self.drawTextureScaledUniform,self.drawTextCentre
    local exitTexture=paired and getTexture("media/ui/vehicles/vehicle_exit.png")
    local joyTexture=paired and Joypad.Texture.XButton
    local rearBottom=bus and height-45 or math.max(originalHeight*0.85+height-originalHeight,lastY+rows*70+59/2)
    local props=ISCarMechanicsOverlay.CarList[script:getCarMechanicsOverlay() or name]
    local bodyTexture=props and props.imgPrefix and getTexture("media/ui/vehicles/seatui/"..props.imgPrefix.."base_small.png")
    -- KI5 SWAT uses a rearward physical side door for the front passenger.
    -- Align its UI only; never change the outside offset used by obstruction
    -- checks and by the actual enter/exit action.
    local sideExit,sideHover
    if name=="Base.87fordF700swat" then
        local leftIndex,rightIndex=script:getPassengerIndex("FrontLeft"),script:getPassengerIndex("FrontRight")
        local left=leftIndex>=0 and script:getPassenger(leftIndex):getPositionById("outside")
        local right=rightIndex>=0 and script:getPassenger(rightIndex):getPositionById("outside")
        if left and right then
            local l,r=left:getOffset(),right:getOffset()
            sideExit={seat=rightIndex,x=self.width/2-r:get(0)*scale,
                y=originalHeight/2+shiftY-r:get(2)*scale,dy=(r:get(2)-l:get(2))*scale}
        end
    end
    local fontHeight=getTextManager():getFontHeight(UIFont.Large)
    local function sideMark(x,y,w,h)
        return sideExit and math.abs(x+w/2-sideExit.x)<0.01
            and math.abs(y+h/2-sideExit.y)<0.01
    end
    local candidate
    local function rearMark(x,y,w) return paired and not bus and math.abs(x+w/2-self.width/2)<8 and y>lastY+30 end
    local ok,result=pcall(function()
        self.drawTextureScaledUniform=function(panel,texture,x,y,scale,alpha,...)
            if bus and (texture==exitTexture or texture==joyTexture) then return end
            if (texture==exitTexture or texture==joyTexture)
                    and sideMark(x,y,texture:getWidthOrig(),texture:getHeightOrig()) then
                y=y+sideExit.dy
                if not self.joyfocus then
                    sideHover=self:getMouseX()>=x and self:getMouseX()<x+texture:getWidthOrig()
                        and self:getMouseY()>=y and self:getMouseY()<y+texture:getHeightOrig()
                    local shift=isKeyDown(Keyboard.KEY_LSHIFT) or isKeyDown(Keyboard.KEY_RSHIFT)
                    alpha=(sideHover or shift) and 1 or 0.2
                end
            end
            if not bus and texture==bodyTexture then
                rearBottom=math.max(y+(texture:getOffsetY()+texture:getHeight())*scale,lastY+rows*70+59/2)
            end
            if paired and (texture==exitTexture or texture==joyTexture) and rearMark(x,y,texture:getWidthOrig()) then return end
            return textureDraw(panel,texture,x,y,scale,alpha,...)
        end
        if paired then
            candidate=rearCandidate(self,profile)
            self.drawTextCentre=function(panel,label,x,y,...)
                if bus and tonumber(label) and (isKeyDown(Keyboard.KEY_LSHIFT) or isKeyDown(Keyboard.KEY_RSHIFT)) then return end
                if sideExit and tonumber(label)==sideExit.seat+1 and sideMark(x,y,0,fontHeight) then y=y+sideExit.dy end
                if tonumber(label) and rearMark(x,y,0) then return end
                return textDraw(panel,label,x,y,...)
            end
        end
        self.vlsSeatBodyBottom=originalHeight*0.85+height-originalHeight
        self.height=originalHeight;self.getHeight=function()return originalHeight end
        if rect then
            self.drawRect=function(panel,x,y,w,h,...)
                if bus and w==16 and h==fontHeight then return end
                if w==16 and h==fontHeight and sideMark(x,y,w,h) then y=y+sideExit.dy end
                if w==16 and rearMark(x,y,w) then return end
                return rect(panel,x,y,w,h,...)
            end
        end;if border then self.drawRectBorder=border end
        for _,p in ipairs(changed) do
            local x=p.index==0 and left or p.index==#profile.spacePassengers and #profile.spacePassengers%2==1 and (left+right)/2 or (p.index%2==1 and left or right)
            local y=lastY+math.ceil(p.index/2)*pitch
            p.o:set((self.width/2+shiftX-x)/scale,p.y,(originalHeight/2+shiftY-y)/scale)
        end
        local value=baseRender(self)
        if sideExit and not self.joyfocus then
            if self.mouseOverExit==sideExit.seat then self.mouseOverExit=nil end
            if sideHover then self.mouseOverExit=sideExit.seat end
        end
        if paired then
            if bus or (self.mouseOverExit and self.mouseOverExit>=2) then self.mouseOverExit=nil end
            self.vlsSeatExitBottom=nil
            local icon=self.joyfocus and joyTexture or exitTexture
            local texture=icon
            -- Match native drawing: controller icons wrap their current Texture.
            if ISUITextureGetter and ISUITextureGetter.checkGetTexture then
                texture=ISUITextureGetter.checkGetTexture(texture)
            end
            if candidate~=nil and texture then
                local w,h=texture:getWidth(),texture:getHeight()
                local x,y=self.width/2-w/2,rearBottom+4
                if bus then x,y=right+29+4,lastY-h/2 end
                local shift=isKeyDown(Keyboard.KEY_LSHIFT) or isKeyDown(Keyboard.KEY_RSHIFT)
                local hover=self:getMouseX()>=x and self:getMouseX()<x+w and self:getMouseY()>=y and self:getMouseY()<y+h
                textureDraw(self,icon,x-texture:getOffsetX(),y-texture:getOffsetY(),1,(hover or shift or self.joyfocus) and 1 or 0.2,1,1,1)
                if not self.joyfocus and hover then self.mouseOverExit=candidate end
                if not self.joyfocus and shift then
                    local fh=getTextManager():getFontHeight(UIFont.Large)
                    rect(self,x+w/2-8,y+h/2-fh/2,16,fh,1,0.1,0.1,0.1)
                    textDraw(self,tostring(candidate+1),x+w/2,y+h/2-fh/2,1,1,1,1,UIFont.Large)
                end
                self.vlsSeatExitBottom=y+h
            end
        end
        return value
    end)
    for _,p in ipairs(changed) do p.o:set(p.x,p.y,p.z) end
    if ok then height=math.max(bus and 0 or originalHeight,rearBottom+45,(self.vlsSeatExitBottom or 0)+45)
    else height=previousHeight end
    self.vlsSeatBodyBottom=ownBodyBottom
    self:setHeight(height)
    if self.close then self.close:setY(height-35) end
    self.drawTextureScaledUniform=ownTexture;self.drawTextCentre=ownText
    self.getHeight=ownHeight;self.drawRect=ownRect;self.drawRectBorder=ownBorder
    if getPlayerScreenHeight and self.playerNum and self.setY and self.getY then
        local top=getPlayerScreenTop(self.playerNum)
        self:setY(math.max(top,math.min(self:getY(),top+getPlayerScreenHeight(self.playerNum)-height)))
    end
    if not ok then error(result) end
    return result
end
