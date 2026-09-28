-- Actual native seat render/input and VLS UI hooks; PZ engine objects are mocked.
local root,native,ki5=assert(arg[1]),assert(arg[2]),assert(arg[3],"KI5 F700 vehicle-script folder required")
local mods=root.."/workshop/Contents/mods/"
local media=mods.."VehicleLivingSlots/common/media/"
local function read(p)local f=assert(io.open(p));local s=f:read('*a');f:close();return s end
local checks=0
local function check(v,m)assert(v,m);checks=checks+1 end
local function near(a,b,m)check(math.abs(a-b)<0.000001,m or tostring(a)..' vs '..tostring(b))end
local noop=function()end
package.loaded.VLS_InstallGuard=true
package.loaded['Entity/TimedActions/ISHandcraftAction']=true
package.loaded['TimedActions/ISDeviceBatteryAction']=true
package.loaded['Vehicles/Vehicles']=true
local V=dofile(media..'lua/shared/VLS_Config.lua');package.loaded.VLS_Config=V
instanceof=function(o,k)return o and o.kind==k end
getText=function(k)return k end;getTextOrNull=function()return nil end
UIFont={Medium=1,Large=2};getTextManager=function()return {getFontHeight=function()return 16 end}end
ISPanelJoypad={render=noop,prerender=function(p)p.backgrounds=(p.backgrounds or 0)+1 end}
function ISPanelJoypad:derive()return setmetatable({},{__index=self})end
package.loaded['ISUI/ISPanelJoypad']=true
ISCarMechanicsOverlay={CarList={}};Keyboard={KEY_LSHIFT=1,KEY_RSHIFT=2};local shiftDown=false;isKeyDown=function()return shiftDown end
local textures={};getTexture=function(n)
 if not textures[n]then textures[n]={name=n,getOffsetX=function()return 0 end,getOffsetY=function()return 0 end,getWidth=function()return 24 end,getHeight=function()return 24 end,getWidthOrig=function()return 24 end,getHeightOrig=function()return 24 end}end
 return textures[n]
end
Joypad={Texture={AButton=getTexture('A'),XButton=getTexture('X')}}
local enters=0;ISVehicleMenu={moveItemsFromSeat=function()return false end,onEnter=function()enters=enters+1 end}
dofile(native..'/client/Vehicles/ISUI/ISVehicleSeatUI.lua');package.loaded['Vehicles/ISUI/ISVehicleSeatUI']=true
local originalRender=ISVehicleSeatUI.render
local source=read(media..'scripts/VLS_StepVanWaterPatch.txt')
local medium=assert(source:match('template vehicle VLSMediumVanLivingSystem(.-)template vehicle VLSLargeVanLivingSystem'))
local large=assert(source:match('template vehicle VLSLargeVanLivingSystem(.*)'))
local function vector(x,y,z)
 local p={x,y,z};function p:get(i)return self[i+1]end;function p:set(a,b,c)self[1],self[2],self[3]=a,b,c end;return p
end
local function panel(name,templateOverride,extentsOverride)
 local profile=assert(V.vehicleProfiles[name]);local names={'FrontLeft','FrontRight'}
 local template=templateOverride or (profile.kind=='mediumVan' and medium or large)
 if templateOverride then
  local living={};for _,a in ipairs(profile.spacePassengers)do living[a.passenger]=true end
  names={};for id in template:gmatch('passenger%s+(%w+)%s*{')do if not living[id]then names[#names+1]=id end end
 end
 local nativeCount=#names
 for _,a in ipairs(profile.spacePassengers)do names[#names+1]=a.passenger end
 local passengers,index,parts,snap={},{},{},{}
 for i,id in ipairs(names)do
  local block=assert(template:match('passenger '..id..'%s*{(.-)switchSeat'))
  local x,y,z=block:match('position inside%s*{%s*offset%s*=%s*([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)')
  local o=vector(tonumber(x),tonumber(y),tonumber(z));snap[i]={o[1],o[2],o[3]}
  local ox,oy,oz=block:match('position outside%s*{%s*offset%s*=%s*([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)')
  local outside=vector(tonumber(ox),tonumber(oy),tonumber(oz));snap[i].outside={outside[1],outside[2],outside[3]}
  passengers[i]={getId=function()return id end,getPositionById=function(_,pos)return {getOffset=function()return pos=='inside' and o or outside end}end,offset=o,outside=outside}
  index[id]=i-1
 end
 local script={getPassengerIndex=function(_,id)return index[id] or -1 end,getPassenger=function(_,i)return passengers[i+1]end,
 getPassengerCount=function()return #passengers end,getFullName=function()return name end,
 getExtents=function()return {x=function()return extentsOverride and extentsOverride[1] or 1.3 end,z=function()return extentsOverride and extentsOverride[2] or 2.1 end}end,getCarMechanicsOverlay=noop}
 local vehicle={parts=parts,occupied={},characters={},getScript=function()return script end,getScriptName=function()return name end,
 getMaxPassengers=function()return #passengers end,getSeat=function()return -1 end,getPartById=function(_,id)return parts[id]end,
 canSwitchSeat=function()return true end,updateHasExtendOffsetForExit=noop,updateHasExtendOffsetForExitEnd=noop,isExitBlocked=function()return true end}
 for i,id in ipairs(names)do
  local partId=i<=nativeCount and 'Seat'..id or profile.spacePassengers[i-nativeCount].part
  local part={id=partId,getId=function()return partId end,getVehicle=function()return vehicle end}
  function part:getInventoryItem()return self.item end
  if i<=nativeCount then part.item={}end
  parts[partId]=part
 end
 function vehicle:getPartForSeatContainer(seat)return parts[seat<nativeCount and 'Seat'..names[seat+1] or profile.spacePassengers[seat-nativeCount+1].part]end
 function vehicle:isSeatOccupied(seat)return self.occupied[seat] or self.characters[seat]~=nil end
 function vehicle:getCharacter(seat)return self.characters[seat]end
 function vehicle:isSeatInstalled(seat)return self:getPartForSeatContainer(seat):getInventoryItem()~=nil end
 local p=setmetatable({vehicle=vehicle,width=263,height=500,mouseX=-1,mouseY=-1,character={getVehicle=function()return nil end},backgroundColor={r=0,g=0,b=0},images={},labels={},warnings={},playerNum=0},{__index=ISVehicleSeatUI})
 function p:getWidth()return self.width end;function p:getHeight()return self.height end;function p:setHeight(h)self.height=h end
 function p:getMouseX()return self.mouseX end;function p:getMouseY()return self.mouseY end
 function p:drawTextureScaledUniform(tex,x,y,scale,alpha)self.images[#self.images+1]={name=tex.name,x=x,y=y,alpha=alpha}end
 function p:drawTextCentre(label,x,y,r,g,b,a,font)self.labels[#self.labels+1]={label=label,x=x,y=y,r=r,font=font}end
 p.drawRect=noop;p.borders={};p.drawRectBorder=function(self,x,y,w,h)self.borders[#self.borders+1]={x=x,y=y,w=w,h=h}end;p.closeSelf=function(self)self.closed=true end
 local rt={setText=function(self,s)self.text=s end,render=function(self)p.warnings[#p.warnings+1]=self.text end}
 p.richText=rt
 function p:restored()
  for i,passenger in ipairs(passengers)do for axis=1,3 do near(passenger.offset[axis],snap[i][axis],'inside restored')end
   for axis=1,3 do near(passenger.outside[axis],snap[i].outside[axis],"actual outside unchanged")end
  end
 end
 function p:restoredOutside()
  for i,passenger in ipairs(passengers)do for axis=1,3 do near(passenger.outside[axis],snap[i].outside[axis],'obstruction uses physical exit offset')end end
 end
 function p:put(seat,ft)
  local it={kind='Moveable',getFullType=function()return ft end,getWorldSprite=function()return nil end,getDisplayName=function()return ft end}
  vehicle:getPartForSeatContainer(seat).item=it;return it
 end
 return p
end
dofile(media..'lua/client/VLS_SeatDisplay.lua')
local client=read(media..'lua/client/VLS_Client.lua')
local first=assert(client:find('if not VLS.bedSeatUIHookApplied then',1,true))
local last=assert(client:find('-- Reload-sensitive adapters',first,true))
assert(loadstring(client:sub(first,last-1),'@VLS_Client.seatUI'))()
local models=0
for name,profile in pairs(V.vehicleProfiles)do
 if profile.kind=='mediumVan' or profile.kind=='largeVan' then
  local p=panel(name);p:render();p:restored();models=models+1
  local images=p.images;check(#images==#profile.spacePassengers+2,'all seats drawn')
  near(images[3].x,images[1].x);near(images[4].x,images[2].x)
  near(images[#images].x,(images[1].x+images[2].x)/2)
  near(images[3].y,images[4].y)
  if #images==7 then near(images[5].x,images[1].x);near(images[6].x,images[2].x);near(images[5].y,images[6].y)end
  for i=3,#images do
   near(images[i].y,images[1].y+math.ceil((i-2)/2)*70)
   check(images[i].y+59<p.height-35,'clear of cancel button')
   p.mouseX=images[i].x+20;p.mouseY=images[i].y+29;p.images={};p:render()
   check(p.mouseOverSeat==i-1,'native hover matches displayed rectangle')
   local selected;p.useSeat=function(_,seat)selected=seat end;p:onMouseDown(0,0);check(selected==i-1,'native click uses same seat')
   p:restored()
  end
 end
end
local p=panel('Base.StepVan');p:put(3,'Base.Mov_FridgeMini');p.vehicle.occupied[3]=true;p.mouseOverSeat=3
local richRender=p.richText.render;p:prerender();check(#p.warnings==0,'equipment has no red status');check(p.backgrounds==1,'native background kept');check(p.richText.render==richRender,'rich method restored');check(p.vlsDisplayInstalledSeat==nil,'temporary installed display flag restored')
check(p.labels[#p.labels].label=='Base.Mov_FridgeMini','equipment title preserved')
p.labels={};p:render();local n=0
for _,label in ipairs(p.labels)do if label.label=='4' then n=n+1;check(label.r==0,'number black on white')end end
check(n==1,'blocked equipment still has one position number');p:restored()
p:useSeat(3);check(not p.closed and enters==0,'equipment cannot be entered')
-- Beds and real seats retain native status messages.
for _,row in ipairs({{2,'Base.Mov_Cot'},{0,false}})do
 local b=panel('Base.StepVan');if row[2]then b:put(row[1],row[2])end
 b.vehicle.occupied[row[1]]=true;b.mouseOverSeat=row[1];b:prerender();check(#b.warnings==1,'bed/native occupancy warning retained')
end
local b=panel('Base.StepVan');b.mouseOverSeat=2;b:prerender();check(#b.warnings==1,'empty living slot status retained')
p.mouseOverExit=0;p.labels={};p:prerender();check(p.labels[1].label=='IGUI_ExitVehicle','exit hover preserved');p.mouseOverExit=nil
p.richText.setText=function()error('tooltip fault')end;p.seatText=nil;p.mouseOverSeat=3
check(not pcall(p.prerender,p),'tooltip error propagated');check(p.richText.render==richRender,'rich render restored after error');check(p.vlsDisplayInstalledSeat==nil,'flag restored after error')
local broken=panel('Base.Van');local oldDraw=broken.drawTextureScaledUniform;broken.drawTextureScaledUniform=function()error('draw fault')end
local failingDraw=broken.drawTextureScaledUniform;check(not pcall(broken.render,broken),'render error propagated');check(broken.drawTextureScaledUniform==failingDraw,'draw method restored after error');broken:restored()
-- UI layout selection must leave optional adapters to their own code.
local optional=panel('Base.StepVan');local profile=V.vehicleProfiles['Base.StepVan'];local kind=profile.kind;profile.kind='ki5Camper'
optional:render();near(optional.images[3].x,263/2-0.3*(500*0.7/2.1)-41/2);profile.kind=kind;optional:restored()
local installedRender=ISVehicleSeatUI.render;dofile(media..'lua/client/VLS_SeatDisplay.lua');check(ISVehicleSeatUI.render==installedRender,'idempotent reload')

local van=panel('Base.Van')
for i,key in ipairs({'IGUI_VLSLargeVanFrontLeftSpace','IGUI_VLSLargeVanFrontRightSpace','IGUI_VLSLargeVanRearSpace'})do
 check(V.getPartDisplayName(van.vehicle:getPartForSeatContainer(i+1))==key,'Van names follow the new visual positions')
end
ISUninstallVehiclePart=ISUninstallVehiclePart or {complete=function()end}
Events=Events or {};Events.OnTick=Events.OnTick or {Add=function()end}
local A=require 'VLS_KI5F700_Config'
dofile(mods..'VehicleLivingSlotsKI5F700/common/media/lua/client/VLS_KI5F700_SeatUI.lua')
local f700Script=read(mods..'VehicleLivingSlotsKI5F700/common/media/scripts/VLS_KI5F700Patch.txt')
local template=assert(f700Script:match('vehicle 87fordF700bank%s*{(.*)'))
local f=panel('Base.87fordF700bank',template);f:put(7,'Base.Mov_FridgeMini');f.vehicle.occupied[7]=true
f:render();f:restored();check(#f.images==9,'F700 still draws all nine positions')
near(f.images[8].x,f.images[2].x,'F700 own right column preserved')
near(f.images[9].x,(f.images[1].x+f.images[2].x)/2,'F700 own last center preserved')
local count=0;for _,l in ipairs(f.labels)do if l.label=='8' then count=count+1;check(l.r==0,'F700 blocked equipment number is readable')end end
check(count==1,'F700 equipment position retains one number')
f.mouseX=f.images[8].x+20;f.mouseY=f.images[8].y+29;f.images={};f:render();check(f.mouseOverSeat==7,'F700 moved position hit test')
f:prerender();check(#f.warnings==0,'F700 equipment red status suppressed');f:useSeat(7);check(not f.closed,'F700 equipment cannot be entered');f:restored()
-- Rear exit visibility and placement use actual native draw/click methods.
local exitPath="media/ui/vehicles/vehicle_exit.png"
local function exitImages(p)
 local result={};for _,im in ipairs(p.images)do if im.name==exitPath or im.name=='X' then result[#result+1]=im end end;return result
end
local function seated(name,template,extents)
 local p=panel(name,template,extents)
 p.vehicle.getSeat=function()return 0 end;p.character.getVehicle=function()return p.vehicle end
 p.vehicle.characters[0]=p.character;p.vehicle.isExitBlocked=function()p:restoredOutside();return false end
 return p
end
for _,row in ipairs({{'Base.Van'}, {'Base.StepVan'}, {'Base.87fordF700bank',template}})do
 local q=seated(row[1],row[2]);q:render();q:restored()
 check(#exitImages(q)==2,'empty living slots have no rear exit, native front exits remain')
 q:put(2,'Base.Mov_FridgeMini');q.images={};q:render();check(#exitImages(q)==2,'equipment is not an exit seat')
 q:put(2,'Base.Mov_Cot');q.images={};q:render();q:restored()
 local icons=exitImages(q);check(#icons==3,'installed reachable bed creates one shared rear exit')
 local rear=icons[3];near(rear.x+12,q.width/2,'rear exit centered')
 local tail=0;for _,b in ipairs(q.borders)do if b.w>100 and b.h>100 then tail=math.max(tail,b.y+b.h)end end
 local seats={};for _,im in ipairs(q.images)do if im.name:find('/seatui/')then seats[#seats+1]=im end end
 for _,im in ipairs(seats)do check(rear.y>im.y+59,'rear exit after all seats');tail=math.max(tail,im.y+59)end
 near(rear.y,tail+4,'rear exit hugs tail with a four pixel gap')
 check(rear.y+24<=q.height-45,'rear exit clear of cancel button')
 local oldOutside=q.vehicle:getScript():getPassenger(2).outside
 local nativeScale=500*0.7/2.1
 q.mouseX=q.width/2-oldOutside:get(0)*nativeScale;q.mouseY=500/2-oldOutside:get(2)*nativeScale;q.images={};q:render()
 check(q.mouseOverExit==nil,'old rear exit hit area removed')
 q.mouseX=rear.x+12;q.mouseY=rear.y+12;q.images={};q:render()
 check(q.mouseOverExit==2 and q.mouseOverSeat==nil,'rear hover matches valid bed seat')
 local switched,exited
 ISVehicleMenu.onSwitchSeat=function(_,seat)switched=seat end
 ISVehicleMenu.onExit=function(_,seat)exited=seat or true end
 q:onMouseDown(0,0);check(switched==2 and exited==2,'native click exits through installed bed')
 -- A second installed bed sharing the same door still produces one icon.
 q:put(3,'Base.Mov_Cot');q.images={};q:render();check(#exitImages(q)==3,'shared rear door is deduplicated')
 q.vehicle.occupied[2]=true;q.images={};q:render();check(q.mouseOverExit==3,'occupied blocked bed falls back to usable bed')
 q.vehicle.occupied[3]=true;q.images={};q:render();check(#exitImages(q)==2 and q.mouseOverExit==nil,'occupied blocked beds hide rear exit')
 q.vehicle.occupied={};q.vehicle.isExitBlocked=function(_,_,seat)return seat>=2 end
 q.images={};q:render();check(#exitImages(q)==2,'blocked rear door hidden')
 q.vehicle.isExitBlocked=function()return false end;shiftDown=true;q.labels={};q.images={};q:render()
 local number=0;for _,label in ipairs(q.labels)do if label.label=='3' then number=number+1;near(label.x,rear.x+12);near(label.y,rear.y+12-8)end end
 check(number==1,'shift exit number follows rear icon once');shiftDown=false
 q.joyfocus=true;q.joypadSeat=3;q.images={};q:render();check(#exitImages(q)==1,'controller gets one valid exit')
 q:put(2,'Base.Mov_FridgeMini');q.images={};q:render();check(#exitImages(q)==0,'controller equipment exit hidden')
 q.joyfocus=nil;q.mouseX=1;q.mouseY=1;q:put(2,'Base.Mov_Cot')
 local oldDraw=q.drawTextureScaledUniform;q.drawTextureScaledUniform=function(_,tex,...)if tex.name==exitPath then error('exit draw fault')end;return oldDraw(q,tex,...)end
 local failing=q.drawTextureScaledUniform;check(not pcall(q.render,q),'exit drawing failure propagates');check(q.drawTextureScaledUniform==failing,'draw method restored after exit error');q:restored()
 check(q.vlsSeatBodyBottom==nil,'addon temporary body boundary restored')
end
-- Texture-backed body bounds and small vans use the same rear-edge spacing.
local smallName;for name,profile in pairs(V.vehicleProfiles)do if profile.kind=='smallVan' then smallName=name;break end end
check(smallName~=nil,'small van fixture exists')
local small=seated(smallName,medium)
small.vehicle:getScript().getCarMechanicsOverlay=function()return 'FixtureBody' end
ISCarMechanicsOverlay.CarList.FixtureBody={imgPrefix='fixture_'}
local body=getTexture('media/ui/vehicles/seatui/fixture_base_small.png')
body.getHeightOrig=function()return 450 end;body.getWidthOrig=function()return 200 end
body.getHeight=body.getHeightOrig;body.getWidth=body.getWidthOrig
small:put(2,'Base.Mov_Cot');small:render();local rear=exitImages(small)[3]
near(rear.y,(500+450)/2+4,'rear exit hugs rendered vehicle image')
check(rear.y+24<=small.height-45,'small van cancel clearance')
local first=small.images[2];small.images={};small:render()
near(exitImages(small)[3].y,rear.y,'no panel growth across frames');near(small.images[2].y,first.y,'front doors stay aligned')
small:restored()
local paired=0
small.vehicle.updateHasExtendOffsetForExitEnd=function()paired=paired+1 end
small.vehicle.isExitBlocked=function()small:restoredOutside();error('blocked query fault')end
local savedDraw=small.drawTextureScaledUniform
check(not pcall(small.render,small),'exit obstruction query failure propagated')
check(paired==1,'temporary exit extension ended on query error');check(small.drawTextureScaledUniform==savedDraw,'draw methods preserved on query error');small:restored()
check(#V.vehicleProfiles['Base.87fordF700swat'].seatPairs==6,'SWAT registers six original seat pairs')
check(A.matches({getScriptName=function()return 'Base.87fordF700swat'end}),'SWAT independent adapter enabled')
-- Paired SWAT seats: render/input runs the real native UI and both addon layers.
-- Script-part association is tested separately against actual Java/Kahlua.
local S=V.F700Seats;local realSync=S.sync;S.sync=function()end
-- Use the actual SWAT passenger template. Bank-derived fixtures hide KI5's
-- asymmetric FrontRight outside point and cannot catch the misplaced icon.
local swatTemplate=read(ki5..'/template_F700_passengers.txt')
local swatScript=read(ki5..'/87fordF700swat.txt')
local sx,sy,sz=swatScript:match('extents%s*=%s*([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)')
local q=seated('Base.87fordF700swat',swatTemplate,{assert(tonumber(sx)),assert(tonumber(sz))})
check(q.vehicle:getScript():getPassenger(0).outside:get(2)>q.vehicle:getScript():getPassenger(1).outside:get(2)+1,
 'real SWAT side door is rearward of driver exit')
local profile=V.getVehicleProfile(q.vehicle)
local basePart=q.vehicle.getPartForSeatContainer
for _,pair in ipairs(profile.seatPairs)do
 local id=pair.seat
 q.vehicle.parts[id]={item={},getId=function()return id end,getVehicle=function()return q.vehicle end,getInventoryItem=function(self)return self.item end}
end
q.vehicle.getPartForSeatContainer=function(v,seat)
 local pair=profile.seatPairs[seat-1]
 if pair and v.parts[pair.seat].item then return v.parts[pair.seat]end
 return basePart(v,seat)
end
q:render();q:restored();check(#exitImages(q)==3,'native rear seats yield one rear door without a bed')
local rear=exitImages(q)[3]
local seats={};for _,im in ipairs(q.images)do if im.name:find('/seatui/')then seats[#seats+1]=im end end
check(#seats==8,'SWAT keeps eight positions')
for i=3,8 do near(seats[i].x,seats[i%2==1 and 1 or 2].x,'SWAT rear columns align')end
local tail=0;for _,border in ipairs(q.borders)do if border.w>100 and border.h>100 then tail=math.max(tail,border.y+border.h)end end
for _,im in ipairs(seats)do tail=math.max(tail,im.y+59)end
near(rear.y,tail+4,'SWAT door hugs tail')
q.mouseX=rear.x+12;q.mouseY=rear.y+12;q.images={};q:render();check(q.mouseOverExit==2,'native rear door click selects original rear passenger')
local height=q.height;q.images={};q:render();near(q.height,height,'SWAT panel height stable')
for _,pair in ipairs(profile.seatPairs)do q.vehicle.parts[pair.seat].item=nil end
q.images={};q:render();check(#exitImages(q)==2,'all empty paired positions hide rear door')
q:put(2,'Base.Mov_FridgeMini');q.images={};q:render();check(#exitImages(q)==2,'paired furniture does not open rear route')
q:put(3,'Base.Mov_Cot');q.images={};q:render();check(#exitImages(q)==3 and q.mouseOverExit==3,'paired bed becomes shared rear route')
q.vehicle.parts.SeatP4.item={};q.images={};q:render();check(q.mouseOverExit==4,'native seat takes route priority over another bed')
q.vehicle.characters[4]={};q.images={};q:render();check(q.mouseOverExit==3,'occupied native seat falls back to bed')
q.vehicle.isExitBlocked=function()q:restoredOutside();return true end;q.images={};q:render();check(#exitImages(q)==0,'native obstruction suppresses blocked rear and front exits')
q.vehicle.isExitBlocked=function()q:restoredOutside();return false end
q.joyfocus=true;q.joypadSeat=4;q.images={};q:render();check(#exitImages(q)==1,'controller paired bed exit deduplicated')
q.joypadSeat=3;q.images={};q:render();check(#exitImages(q)==0,'controller furniture route suppressed')
q.joyfocus=nil;shiftDown=true;q.labels={};q.images={};q:render();local count=0
for _,label in ipairs(q.labels)do if label.label=='4' and math.abs(label.x-q.width/2)<1 then count=count+1 end end
check(count==1,'SWAT shared exit shift label appears once');shiftDown=false
local draw=q.drawTextureScaledUniform
q.drawTextureScaledUniform=function(_,tex,...)if tex.name==exitPath then error('paired exit draw fault')end;return draw(q,tex,...)end
local failing=q.drawTextureScaledUniform;check(not pcall(q.render,q),'paired exit render fault propagated');check(q.drawTextureScaledUniform==failing,'paired draw restored');q:restored()
S.sync=realSync
-- Real B42.20 UI2.pack metadata (cropped rectangle + original canvas).
-- UIElement.DrawTextureScaledUniform applies offsets and draws getWidth/Height.
body.getHeightOrig=function()return 600 end;body.getWidthOrig=function()return 263 end
body.getHeight=function()return 335 end;body.getWidth=function()return 165 end
body.getOffsetY=function()return 132 end;body.getOffsetX=function()return 60 end
ImageScale.fixture_=1.1
local door=getTexture(exitPath)
door.getHeightOrig=function()return 64 end;door.getWidthOrig=function()return 64 end
door.getHeight=function()return 40 end;door.getWidth=function()return 54 end
door.getOffsetY=function()return 10 end;door.getOffsetX=function()return 5 end
q.drawTextureScaledUniform=draw
S.sync=function()end
local fixtures={seated('Base.Van'),seated('Base.StepVan'),seated(smallName,medium),
 seated('Base.87fordF700bank',template),q}
for _,actual in ipairs(fixtures)do
 for _,textured in ipairs({true,false})do
  actual.images={};actual.labels={};actual.borders={};actual.mouseX=-1;actual.mouseY=-1
  actual.vehicle:getScript().getCarMechanicsOverlay=function()return textured and 'FixtureBody' or nil end
  if actual~=q then actual:put(2,'Base.Mov_Cot')end
  actual:render();actual:restored()
  local rear=exitImages(actual)[3];check(rear~=nil,'real texture rear exit exists')
  local tail=textured and ((500-600*1.1)/2+(132+335)*1.1) or 0
  for _,border in ipairs(actual.borders)do if border.w>100 and border.h>100 then tail=math.max(tail,border.y+border.h)end end
  for _,im in ipairs(actual.images)do
   if im.name:find('/seatui/icon_')then tail=math.max(tail,im.y+59)end
  end
  local x,y=rear.x+5,rear.y+10
  near(y,tail+4,'visible rear icon is four pixels after visible body/seats')
  near(x+54/2,actual.width/2,'visible rear icon centered')
  near(actual.height,math.max(500,y+40+45),'panel fits visible icon, excluding transparent padding')
  local height=actual.height
  for _,point in ipairs({{x+1,y+1},{x+53,y+39}})do
   actual.mouseX,actual.mouseY=point[1],point[2];actual.images={};actual:render()
   check(actual.mouseOverExit~=nil and actual.mouseOverExit>=2,'visible edge is clickable')
   check(actual.mouseOverSeat==nil,'rear hit box does not overlap a seat')
   local chosen=actual.mouseOverExit;local used
   ISVehicleMenu.onExit=function(_,seat)used=seat end;actual:onMouseDown(0,0)
   check(used==chosen,'native click targets chosen real seat')
  end
  for _,point in ipairs({{x-1,y+20},{x+54,y+20},{x+27,y-1},{x+27,y+40}})do
   actual.mouseX,actual.mouseY=point[1],point[2];actual.images={};actual:render()
   check(actual.mouseOverExit==nil,'transparent/outside pixels do not trigger rear exit')
  end
  actual.mouseX=actual.width/2;actual.mouseY=620;actual.images={};actual:render()
  check(actual.mouseOverExit==nil,'old distant exit area is inactive')
  for frame=1,3 do actual.images={};actual:render();near(actual.height,height,'real texture panel does not grow')end
  print('REAL_TEXTURE_REAR '..actual.vehicle:getScriptName()..' textured='..tostring(textured)..' gap='..(y-tail)..' height='..height)
 end
end
-- SWAT side icon moves only in the UI: real native input, texture cropping,
-- controller and Shift hint, across panel sizes and seat-overlay offsets.
local savedWidth,savedHeight,savedOriginal=q.width,q.height,q.vlsF700OriginalHeight
local savedShift=SeatOffsetY['Base.87fordF700swat']
local savedRects=q.drawRect;local rects={}
q.drawRect=function(self,x,y,w,h,...)rects[#rects+1]={x=x,y=y,w=w,h=h};return savedRects(self,x,y,w,h,...)end
q.vehicle:getScript().getCarMechanicsOverlay=function()return nil end
for _,width in ipairs({263,360})do for _,height in ipairs({500,650})do for _,offset in ipairs({-17,23})do
 q.width=width;q.height=height;q.vlsF700OriginalHeight=nil
 SeatOffsetY['Base.87fordF700swat']=offset
 q.joyfocus=nil;q.mouseX=-1;q.mouseY=-1;q.images={};q.labels={};rects={}
 q:render();q:restored()
 local icons=exitImages(q);check(#icons==3,'SWAT keeps driver, passenger and shared rear exits')
 local left,right=icons[1],icons[2]
 near(right.y,left.y,'SWAT side icon aligns with driver exit')
 local scale=height*0.7/q.vehicle:getScript():getExtents():z()
 local outside=q.vehicle:getScript():getPassenger(1).outside
 local oldX=width/2-outside:get(0)*scale-door:getWidthOrig()/2
 local oldY=height/2-outside:get(2)*scale+offset-door:getHeightOrig()/2
 near(right.x,oldX,'SWAT side horizontal position unchanged')
 check(math.abs(oldY-right.y)>50,'fixture exposes original lower icon')
 local function point(x,y)
  q.mouseX=x;q.mouseY=y;q.images={};q:render();q:restored()
 end
 point(right.x+32,right.y+32)
 check(q.mouseOverExit==1 and q.mouseOverSeat==nil,'new side icon selects real front passenger')
 local switched,exited
 ISVehicleMenu.onSwitchSeat=function(_,seat)switched=seat end
 ISVehicleMenu.onExit=function(_,seat)q:restoredOutside();exited=seat end
 q:onMouseDown(0,0);check(switched==1 and exited==1,'native click uses unchanged front passenger exit')
 near(exitImages(q)[2].alpha,1,'new hover highlights relocated icon')
 point(oldX+32,oldY+32);check(q.mouseOverExit==nil,'old side-door center is no longer clickable')
 near(exitImages(q)[2].alpha,0.2,'old hover no longer highlights moved icon')
 for _,xy in ipairs({{1,1},{63,63}})do point(right.x+xy[1],right.y+xy[2]);check(q.mouseOverExit==1,'native-sized side hit box moved with icon')end
 for _,xy in ipairs({{-1,32},{64,32},{32,-1},{32,64}})do point(right.x+xy[1],right.y+xy[2]);check(q.mouseOverExit==nil,'outside side hit box does not exit')end
 q.mouseX=-1;q.mouseY=-1;shiftDown=true;q.labels={};q.images={};rects={};q:render()
 local labels=0;for _,label in ipairs(q.labels)do if label.label=='2' then labels=labels+1;near(label.x,right.x+32);near(label.y,right.y+32-8)end end
 check(labels==1,'one Shift passenger shortcut follows relocated side door')
 local backgrounds=0;for _,b in ipairs(rects)do if b.w==16 and math.abs(b.x+8-(right.x+32))<0.01 then
  backgrounds=backgrounds+1;near(b.y,right.y+32-8)
 end end
 check(backgrounds==1,'Shift background follows relocated shortcut');shiftDown=false
 q.joyfocus=true;q.joypadSeat=2;q.images={};q:render();q:restored()
 local joy=exitImages(q);check(#joy==1 and joy[1].name=='X','controller shows only selected side exit')
 near(joy[1].y+12,left.y+32,'controller button follows driver exit height')
 q.joyfocus=nil;q.mouseX=right.x+32;q.mouseY=right.y+32
 q.vehicle.isExitBlocked=function(_,_,seat)q:restoredOutside();return seat==1 end
 q.images={};q:render();check(q.mouseOverExit==nil and #exitImages(q)==2,'blocked real side door remains unavailable at new position')
 q.vehicle.isExitBlocked=function()q:restoredOutside();return false end
 q.vehicle.canSwitchSeat=function(_,_,seat)return seat~=1 end
 q.images={};q:render();check(q.mouseOverExit==nil and #exitImages(q)==2,'unreachable front passenger does not gain an exit')
 q.vehicle.canSwitchSeat=function()return true end
 q.vehicle.characters[1]={};q.images={};q:render()
 check(q.mouseOverExit==nil and #exitImages(q)==2,'occupied front passenger remains unavailable')
 q.vehicle.characters[1]=nil
end end end
q.width=savedWidth;q.height=savedHeight;q.vlsF700OriginalHeight=savedOriginal
SeatOffsetY['Base.87fordF700swat']=savedShift;q.drawRect=savedRects
q.images={};q.mouseX=-1;q.mouseY=-1;q:render()
local oldDraw=q.drawTextureScaledUniform
q.drawTextureScaledUniform=function(self,tex,x,y,...)
 if tex.name==exitPath and x>q.width/2 then error('SWAT side draw fault')end
 return oldDraw(self,tex,x,y,...)
end
local failure=q.drawTextureScaledUniform
check(not pcall(q.render,q),'side draw failure propagated');check(q.drawTextureScaledUniform==failure,'side draw wrapper restored on failure');q:restored()
check(q.drawRect==savedRects,'side hint wrapper restored on failure');q.drawTextureScaledUniform=oldDraw
-- An asymmetric Bank fixture still uses its original side-door position.
local bankTemplate=template:gsub('(passenger FrontRight%s*{.-position outside%s*{%s*offset%s*=%s*)[^,]+','%1-1.4667 -1.3333 0.3333',1)
local bank=seated('Base.87fordF700bank',bankTemplate);bank:render();bank:restored()
local bankRight=exitImages(bank)[2]
near(bankRight.y,500/2-0.3333*(500*0.7/2.1)-32,'Bank side exit unchanged')
print('SWAT_SIDE_EXIT_PASS real KI5 template; eight layouts; native mouse/controller/shift/blockage/fault paths')
-- Read the shipped translations and exercise actual native prerender plus both
-- addons, rather than testing a standalone title helper.
local oldText=getText
for _,lang in ipairs({'EN','CN','CH'})do
 local messages={}
 for key,value in read(mods..'VehicleLivingSlotsKI5F700/common/media/lua/shared/Translate/'..lang..'/IG_UI.json'):gmatch('"([^"\n]+)"%s*:%s*"([^"\n]*)"')do messages[key]=value end
 getText=function(key)return messages[key] or key end
 for i,pair in ipairs(profile.seatPairs)do
  local seat=i+1
  for _,mode in ipairs({'mouse','controller'})do
   for _,state in ipairs({'empty','seat','bed','equipment'})do
    for _,p in ipairs(profile.seatPairs)do q.vehicle.parts[p.seat].item=nil;q.vehicle.parts[p.living].item=nil end
    q.vehicle.characters={};q.vehicle.occupied={};q.mouseOverExit=nil
    q.mouseOverSeat=seat;q.joyfocus=mode=='controller';q.joypadSeat=seat+1
    local expected
    if state=='seat' then q.vehicle.parts[pair.seat].item={};expected=messages['IGUI_VLSF700Seat'..i]
    elseif state=='empty' then expected='SeatP'..(i+2)
    else local ft=state=='bed' and 'Base.Mov_Cot' or 'Base.Mov_FridgeMini';q:put(seat,ft);expected=ft end
    q.labels={};q.warnings={};q.seatText=nil;q:prerender()
    check(q.labels[#q.labels].label==expected,'rear '..(i+2)..' title '..state..' '..lang..' '..mode)
    check(#q.warnings==(state=='empty' and 1 or 0),'only empty space retains native removed-seat warning')
    q.vehicle.occupied[seat]=true;q.warnings={};q:prerender()
    check(#q.warnings==(state=='equipment' and 0 or 1),'native seat/bed occupancy remains visible')
    q.mouseOverExit=seat;q.labels={};q:prerender()
    check(q.labels[#q.labels].label=='IGUI_ExitVehicle','exit title never overwritten')
   end
  end
 end
end
getText=oldText
q.joyfocus=nil;q.mouseOverExit=nil;q.mouseOverSeat=0;q.labels={};q:prerender()
check(q.labels[#q.labels].label=='SeatFrontLeft','front driver title unchanged')
f.mouseOverExit=nil;f.mouseOverSeat=7;f.labels={};f:prerender()
check(f.labels[#f.labels].label=='Base.Mov_FridgeMini','Bank equipment title unchanged')
S.sync=realSync
print('VLS_SEAT_LAYOUT_PASS checks='..checks..' models='..models..' (native Lua bodies; mocked engine)')

-- The three buses share the actual KI5 passenger template; only UI inside
-- offsets are temporarily reflowed. Outside points must survive every frame.
local busTemplate=read(ki5..'/template_B700_passengers.txt')
S.sync=function()end
for _,model in ipairs({'87fordB700school','87fordB700prison','87fordB700military'})do
 local scriptText=read(ki5..'/'..model..'.txt')
 local ex,ey,ez=scriptText:match('extents%s*=%s*([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)')
 for _,width in ipairs({263,360})do
  local b=seated('Base.'..model,busTemplate,{tonumber(ex),tonumber(ez)})
  b.width=width
  local profile=V.getVehicleProfile(b.vehicle);local nativePart=b.vehicle.getPartForSeatContainer
  for _,pair in ipairs(profile.seatPairs)do
   local id=pair.seat
   b.vehicle.parts[id]={item={},getId=function()return id end,getVehicle=function()return b.vehicle end,getInventoryItem=function(self)return self.item end}
  end
  b.vehicle.getPartForSeatContainer=function(v,seat)
   local pair=profile.seatPairs[seat]
   return pair and v.parts[pair.seat].item and v.parts[pair.seat] or nativePart(v,seat)
  end
  b:render();b:restored()
  local seats={};for _,im in ipairs(b.images)do if im.name:find('/seatui/icon_')then seats[#seats+1]=im end end
  check(#seats==15,'bus keeps fifteen real passengers')
  for i=2,15 do
   near(seats[i].x,seats[i%2==0 and 1 or 3].x,'bus columns align with driver')
   near(seats[i].y,seats[1].y+math.ceil((i-1)/2)*70,'bus seven separated rows')
   check(seats[i].y+59<b.height-35,'last row clear of cancel')
   b.mouseX,b.mouseY=seats[i].x+20,seats[i].y+29;b.images={};b:render()
   check(b.mouseOverSeat==i-1,'bus native hit region follows seat')
   local selected;b.useSeat=function(_,seat)selected=seat end;b:onMouseDown(0,0);check(selected==i-1,'bus native click selects same number')
  end
  local icons=exitImages(b);check(#icons==1,'one shared real front-right entrance')
  local exit=icons[1];local x,y=exit.x+door:getOffsetX(),exit.y+door:getOffsetY()
  near(y+door:getHeight()/2,seats[1].y+59/2,'bus exit at driver row')
  check(x>seats[3].x+41,'bus exit outside passenger column')
  b.mouseX,b.mouseY=x+10,y+10;b.images={};b:render()
  check(b.mouseOverExit==0,'driver can use front-right entrance')
  local exited;ISVehicleMenu.onExit=function(_,seat)exited=seat or 0 end
  b:onMouseDown(0,0);check(exited==0,'shared icon routes native current seat')
  b.vehicle.isExitBlocked=function()b:restoredOutside();return true end
  b.images={};b:render();check(#exitImages(b)==0 and b.mouseOverExit==nil,'blocked bus entrance remains blocked')
  b.vehicle.isExitBlocked=function()b:restoredOutside();return false end
  b.joyfocus=true;b.joypadSeat=15;b.images={};b:render();check(#exitImages(b)==1,'last rear seat controller exit')
  b.joyfocus=nil;shiftDown=true;b.labels={};b.images={};b:render()
  local hints=0;for _,label in ipairs(b.labels)do if tonumber(label.label)then hints=hints+1 end end
  check(hints==1,'bus has one Shift exit hint');shiftDown=false
  local height=b.height
  for frame=1,3 do b.images={};b:render();near(b.height,height,'bus height stable');b:restored()end
  for _,pair in ipairs(profile.seatPairs)do b.vehicle.parts[pair.seat].item=nil end
  b.images={};b:render();check(#exitImages(b)==1,'driver entrance remains with empty rear spaces')
  b.joyfocus=true;b.joypadSeat=2;b.images={};b:render();check(#exitImages(b)==0,'empty rear position cannot exit')
  b:put(1,'Base.Mov_Cot');b.images={};b:render();check(#exitImages(b)==1,'bus bed can use real native entrance')
  b:put(1,'Base.Mov_FridgeMini');b.images={};b:render();check(#exitImages(b)==0,'bus equipment has no passenger exit')
  b.joyfocus=nil
  local draw=b.drawTextureScaledUniform
  b.drawTextureScaledUniform=function()error('bus draw fault')end
  local failing=b.drawTextureScaledUniform;check(not pcall(b.render,b),'bus fault propagated')
  check(b.drawTextureScaledUniform==failing,'bus hooks restored after fault');b:restored()
 end
end
S.sync=realSync
print('BUS_NATIVE_UI_PASS three models fifteen seats checks='..checks)
