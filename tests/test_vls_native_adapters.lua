-- Native B42.20 completion/render bodies, mocked engine objects.
local root,native=assert(arg[1]),assert(arg[2])
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
local n=0
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local noop=function()end
local Base={}
function Base:derive(name)local c={Type=name};c.__index=c;return setmetatable(c,{__index=self})end
function Base:new(character)return setmetatable({character=character},{__index=self})end
ISBaseTimedAction=Base;package.loaded["TimedActions/ISBaseTimedAction"]=true
for _,name in ipairs({"ISInstallVehiclePart","ISUninstallVehiclePart"})do
 dofile(native.."/shared/Vehicles/TimedActions/"..name..".lua")
 package.loaded["Vehicles/TimedActions/"..name]=true
end
VLS={isUniversalPart=function(p)return p and p.managed end,
 isAllowedItem=function(p,i)return i~=nil end,
 getEquipmentCapability=function(i)return i and i.tv and "television" or nil end,
 isInstallationEnabled=function(p)return not p.disabled end,
 canUninstallManagedPart=function(p)return not p.disabled end,
 copyTelevisionStateToItem=function(p,i)i.copied=true;i:getDeviceData():cloneDevicePresets(p.currentTVPresets) end,allowedItems={}}
package.loaded.VLS_Config=VLS
instanceof=function(obj,kind)return obj and (kind=="InventoryItem" or kind=="Radio" and obj.radio) or false end
local nativeInstance=instanceof
isServer=function()return true end
Perks={Mechanics=1};IsoObjectChange={MECHANIC_ACTION_DONE=1}
getGameTime=function()return {getCalender=function()return {getTimeInMillis=function()return 42 end}end}end
sendRemoveItemFromContainer=noop;sendAddItemToContainer=noop;playServerSound=noop
local outcome="success"
ZombRand=function(a,b)if b then return 7 end;return outcome=="success" and 0 or 99 end
VehicleUtils={getPerksTableForChr=noop,calculateInstallationSuccess=function()return outcome=="success" and 100 or 0,100 end,
 callLua=function(fn,...)fn(...)end}
addXp=function(c)c.xp=(c.xp or 0)+1 end
ISTransferAction={GetDropItemOffset=function()return 0,0,0 end}
local function setup(tv)
 local i={tv=tv,radio=true,condition=100,id=5}
 i.setJobDelta=noop;i.setItemCapacity=noop
 local itemDevice={presets={name="original TV presets"}}
 function itemDevice:getDevicePresets()return self.presets end
 function itemDevice:cloneDevicePresets(presets)self.presets=presets end
 function i:getDeviceData()return itemDevice end
 function i:getID()return self.id end
 function i:getCondition()return self.condition end
 function i:setCondition(c)self.condition=c end
 local inv={items={i},room=true}
 function inv:DoRemoveItem(it)self.items={}end
 function inv:AddItem(it)table.insert(self.items,it)end
 function inv:hasRoomFor()return self.room end
 local square={AddWorldInventoryItem=function(_,it)inv.dropped=it end}
 local c={getInventory=function()return inv end,removeFromHands=noop,getPerkLevel=function()return 5 end,
 getCurrentSquare=function()return square end,sendObjectChange=noop,addMechanicsItem=noop}
 local v={transmitPartItem=noop,transmitPartCondition=noop,getMechanicalID=function()return 9 end}
 local p={managed=tv,item=nil,condition=100,signals=0,currentTVPresets={name="latest companion TV presets"},getVehicle=function()return v end}
 function p:getInventoryItem()return self.item end
 function p:setInventoryItem(it)self.item=it end
 function p:getContainerContentAmount()return 0 end
 function p:getCondition()return self.condition end
 function p:setCondition(x)self.condition=x end
 function p:getDeviceData()return self.device end
 function p:createSignalDevice()
  self.signals=self.signals+1;self.device={presets={name="default radio presets"}}
  function self.device:getDevicePresets()return self.presets end
  function self.device:cloneDevicePresets(presets)self.presets=presets end
  return self.device
 end
 function p:getTable()return {skills={},complete=function()
   eq(instanceof,nativeInstance);eq(instanceof(i,"Radio"),true)
   if p.throwCallback then error("callback fault")end
 end}end
 return {character=c,vehicle=v,part=p,item=i},inv
end
dofile(media.."shared/VLS_InstallGuard.lua")
for _,mode in ipairs({"success","failure"})do
 test("native TV install "..mode.." preserves the complete original transaction",function()
  outcome=mode;local a,inv=setup(true)
  eq(ISInstallVehiclePart.complete(a),true);eq(a.part.signals,1);eq(instanceof,nativeInstance)
  if mode=="success"then eq(a.part.item,a.item);eq(#inv.items,0)
  else eq(a.part.item,nil);eq(#inv.items,1);eq(a.item.condition,93);eq(a.character.xp,1)end
 end)
 for _,room in ipairs({true,false})do
  test("native TV uninstall "..mode.." room="..tostring(room),function()
   outcome=mode;local a,inv=setup(true);a.part.item=a.item;inv.items={};inv.room=room
   eq(VLSTelevisionUninstallVehiclePart.complete(a),true);eq(a.part.signals,1);eq(a.item.copied,true);eq(a.item:getDeviceData():getDevicePresets(),a.part.currentTVPresets);eq(instanceof,nativeInstance)
   if mode=="success"then eq(a.part.item,nil);eq(room and inv.items[1] or inv.dropped,a.item)
   else eq(a.part.item,a.item);eq(a.part.condition,93);eq(a.character.xp,1)end
  end)
 end
end
test("ordinary radio still creates native speaker",function()
 outcome="success";local a=setup(false);eq(ISInstallVehiclePart.complete(a),true);eq(a.part.signals,1)
end)
test("TV early native exception never replaces global predicate",function()
 local a=setup(true);a.character.removeFromHands=function()error("pre-branch fault")end
 eq(pcall(ISInstallVehiclePart.complete,a),false);eq(instanceof,nativeInstance)
end)
test("TV callback exception preserves global predicate",function()
 outcome="success";local a=setup(true);a.part.throwCallback=true
 eq(pcall(ISInstallVehiclePart.complete,a),false);eq(instanceof,nativeInstance)
end)
test("disabled TV install consumes nothing",function()
 local a,inv=setup(true);a.part.disabled=true;eq(ISInstallVehiclePart.complete(a),false);eq(#inv.items,1)
end)
-- Render the actual native seat UI, including mouse and joypad overlays.
ISPanelJoypad=Base;ISPanelJoypad.render=noop
package.loaded["ISUI/ISPanelJoypad"]=true
UIFont={Medium=1,Large=2};getTextManager=function()return {getFontHeight=function()return 16 end}end
dofile(native.."/client/Vehicles/ISUI/ISVehicleSeatUI.lua")
package.loaded["Vehicles/ISUI/ISVehicleSeatUI"]=true
local textures={}
getTexture=function(name)
 if not textures[name]then textures[name]={name=name,getWidth=function()return 24 end,getHeight=function()return 24 end}end
 return textures[name]
end
Joypad={Texture={AButton=getTexture("A")}};Keyboard={};isKeyDown=function()return false end
ISCarMechanicsOverlay={CarList={}};ISVehicleMenu={moveItemsFromSeat=function()return false end}
VLS.isSupportedVehicle=function(v)return v.supported end
VLS.getInstalledUniversalPartForSeat=function(v,seat)return v.equipment and {} end
VLS.getInstalledBedPartForSeat=function(v,seat)return v.bed and {} end
local pos={getOffset=function()return {get=function(_,i)return 0 end}end}
local passenger={getPositionById=function(_,id)return id=="inside" and pos end}
local script={getPassenger=function()return passenger end,getExtents=function()return {x=function()return 2 end,z=function()return 4 end}end,getCarMechanicsOverlay=noop}
local function panel()
 local v={supported=true,equipment=true,getScript=function()return script end,getScriptName=function()return "Base.StepVan"end,
 getMaxPassengers=function()return 1 end,getSeat=function()return -1 end,
 getPartForSeatContainer=function()return {getInventoryItem=function()return {}end}end}
 function v:isSeatOccupied()return self.person~=nil end
 function v:getCharacter()return self.person end
 local p=setmetatable({vehicle=v,width=263,height=500,drawn={},character={}},{__index=ISVehicleSeatUI})
 function p:getWidth()return self.width end;function p:getHeight()return self.height end
 function p:getMouseX()return 131 end;function p:getMouseY()return 250 end
 function p:drawTextureScaledUniform(t)self.drawn[#self.drawn+1]=t.name end
 p.drawRect=noop;p.drawRectBorder=noop;p.drawTextCentre=noop
 return p
end
dofile(media.."client/VLS_SeatDisplay.lua")
local prefix="media/ui/vehicles/seatui/"
for _,kind in ipairs({"equipment","bed","person","unsupported","empty"})do
 test("native render "..kind,function()
  local p=panel();local raw=p.drawTextureScaledUniform
  if kind=="bed"then p.vehicle.bed=true elseif kind=="person"then p.vehicle.person={}
  elseif kind=="unsupported"then p.vehicle.supported=false elseif kind=="empty"then p.vehicle.equipment=false end
  p:render();eq(p.drawTextureScaledUniform,raw);eq(p.mouseOverSeat,0)
  eq(p.drawn[1],prefix..(kind=="equipment" and "icon_vehicle_stuff.png" or kind=="person" and "icon_vehicle_person.png" or "icon_vehicle_empty.png"))
 end)
end
test("native numeric shortcuts remain identical and readable on substituted white icons",function()
 for _,equipment in ipairs({true,false}) do
  local p=panel();p.vehicle.equipment=equipment
  local text={}
  p.drawTextCentre=function(_,label,x,y,r,g,b,a,font)text[#text+1]={label,r,g,b,font}end
  local raw=p.drawTextCentre;p:render();eq(p.drawTextCentre,raw)
  eq(#text,1);eq(text[1][1],"1");eq(text[1][5],UIFont.Large)
  eq(text[1][2],equipment and 0 or 1);eq(text[1][3],text[1][2]);eq(text[1][4],text[1][2])
 end
end)
test("native joypad overlay retained over white equipment",function()
 local p=panel();p.joyfocus=true;p.joypadSeat=1;p:render()
 eq(p.drawn[1],prefix.."icon_vehicle_stuff.png");eq(p.drawn[2],"A")
end)
test("render exception restores instance draw method",function()
 local p=panel();p.drawTextureScaledUniform=function()error("draw fault")end;local raw=p.drawTextureScaledUniform
 eq(pcall(p.render,p),false);eq(p.drawTextureScaledUniform,raw)
end)
test("reload does not stack seat wrapper",function()
 local old=ISVehicleSeatUI.render;dofile(media.."client/VLS_SeatDisplay.lua");eq(ISVehicleSeatUI.render,old)
end)
test("seat reload preserves later mod wrapper without stacking",function()
 local own=ISVehicleSeatUI.render
 local other=function(self,...)return own(self,...)end
 ISVehicleSeatUI.render=other
 dofile(media.."client/VLS_SeatDisplay.lua");eq(ISVehicleSeatUI.render,other)
 local p=panel();p:render();eq(p.drawn[1],prefix.."icon_vehicle_stuff.png")
end)
-- KI5 mechanics masks move together with their native hit rectangles.
package.loaded.VLS_KI5Campers_Config=VLS
package.loaded.VLS_VehicleMechanicsOverlay=true
package.loaded["Vehicles/ISUI/ISCarMechanicsOverlay"]=true
package.loaded["Vehicles/ISUI/ISVehicleMechanics"]=true
local registered
VLS.registerMechanicsOverlay=function(parts)registered=parts end
local failOverlay=false
ISVehicleMechanics={renderCarOverlay=function(self)
 local prefix=self.vehicle:getScriptName()=="Base.Trailer61Airflyte" and "Trailer61shastaAirflyte_" or "Trailer61shastaAstrodome_"
 for _,suffix in ipairs({"left","right","left_guide","right_guide"})do
  self:drawTextureScaledUniform(getTexture("media/ui/vehicles/mechanic overlay/"..prefix.."vls_water_tank_"..suffix..".png"),10,10,1)
 end
 self:drawTextureScaledUniform(getTexture("native-base"),10,10,1)
 if failOverlay then error("overlay fault")end
end}
dofile(root.."/workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media/lua/client/VLS_KI5Campers_Overlay.lua")
for _,name in ipairs({"Airflyte","Astrodome"})do
 test("Shasta "..name.." masks and hit rectangles agree",function()
  local ys={};local p={vehicle={getScriptName=function()return "Base.Trailer61"..name end}}
  function p:drawTextureScaledUniform(t,x,y)ys[#ys+1]=y end
  local raw=p.drawTextureScaledUniform
  ISVehicleMechanics.renderCarOverlay(p);eq(p.drawTextureScaledUniform,raw)
  for i=1,4 do eq(ys[i],330)end;eq(ys[5],10)
  eq(registered.VLSKI5CamperWaterTank1.vehicles["Trailer61shasta"..name.."_"].y,384)
  failOverlay=true;eq(pcall(ISVehicleMechanics.renderCarOverlay,p),false);failOverlay=false
  eq(p.drawTextureScaledUniform,raw)
 end)
end
-- Execute the native renderer with KI5's actual offset and passenger layout.
dofile(root.."/workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media/lua/client/VLS_KI5Campers_SeatUI.lua")
for _,name in ipairs({"Airflyte","Astrodome"})do
 test("Shasta "..name.." visible seats fit body and mouse matches drawing",function()
  local ids={"DAMNFakeSeat","FrontL","FrontR","RearL","RearR","BackL","BackR"}
  if name=="Astrodome"then ids[#ids+1]="FrontTop"end
  for i=1,3 do ids[#ids+1]="VLSKI5Space"..i end
  local passengers,offsets={},{}
  for i,id in ipairs(ids)do
   local vec={0.6222,0.2444,1.9222}
   function vec:get(index)return self[index+1]end
   function vec:set(x,y,z)self[1],self[2],self[3]=x,y,z end
   offsets[i]=vec
   passengers[i]={getId=function()return id end,getPositionById=function(_,pos)return pos=="inside" and {getOffset=function()return vec end}end}
  end
  local script={getPassenger=function(_,i)return passengers[i+1]end,getPassengerCount=function()return #passengers end,
   getExtents=function()return {x=function()return 2.1111 end,z=function()return 4.1333 end}end,getCarMechanicsOverlay=noop}
  local p=panel();p.vehicle.supported=false
  p.vehicle.getScript=function()return script end
  p.vehicle.getScriptName=function()return "Base.Trailer61"..name end
  p.vehicle.getMaxPassengers=function()return #passengers end
  SeatOffsetY["Base.Trailer61"..name]=67
  p.mx,p.my=-100,-100
  p.getMouseX=function(self)return self.mx end;p.getMouseY=function(self)return self.my end
  local rects={}
  p.drawTextureScaledUniform=function(_,texture,x,y)
   if x>=0 and x<263 and y>=0 and y<500 then rects[#rects+1]={x=x,y=y}end
  end
  p:render();eq(#rects,#ids-1)
  for i,r in ipairs(rects)do
   assert(r.x>=48 and r.x+41<=215 and r.y>=113 and r.y+59<=438,"outside Shasta body")
   for j=i+1,#rects do
    local other=rects[j]
    assert(math.abs(r.x-other.x)>=41 or math.abs(r.y-other.y)>=59,"overlapping visible seats")
   end
  end
  local drawn=rects;rects={}
  for i,r in ipairs(drawn)do
   p.mx,p.my=r.x+20,r.y+29;p:render();eq(p.mouseOverSeat,i)
  end
  for _,v in ipairs(offsets)do eq(v[1],0.6222);eq(v[2],0.2444);eq(v[3],1.9222)end
  p.joyfocus=true;p.joypadSeat=1;p.mx,p.my=-100,-100;p:render();eq(p.joypadSeat,2)
  p:useSeat(0) -- fake cannot invoke gameplay actions
  p.drawTextureScaledUniform=function()error("draw fault")end
  eq(pcall(p.render,p),false)
  for _,v in ipairs(offsets)do eq(v[1],0.6222);eq(v[3],1.9222)end
 end)
end
-- Exercise the shared mechanics display entry with the real KI5 resolver.
test("empty KI5 mechanics slots use the same positional names as seat/container views",function()
 local snapshot={};for k,v in pairs(VLS)do snapshot[k]=v end
 VLS.ki5CampersAdapterApplied=nil
 VLS.OVERHEAD_PART_IDS={"VLSPantryCoffee","VLSOverhead1","VLSOverhead2"}
 VLS.vehicleProfiles={};VLS.FREEZER_PART_BY_UNIVERSAL={};VLS.UNIVERSAL_PART_BY_FREEZER={}
 VLS.sleepingBagTypes={};VLS.equipmentProfiles={};VLS.WATER_TANK_PART_IDS={};VLS.mechanicsDisplayProviders={}
 VLS.getVehicleProfile=function(v)return v and VLS.vehicleProfiles[v.name]end
 VLS.getAuxBatteryPart=noop
 VLS.getPartDisplayName=function(part,fallback)local item=part:getInventoryItem();return item and item:getDisplayName() or fallback end
 VLS.getSpaceAssignmentForPart=function(v,part)
  for _,a in ipairs(VLS.getVehicleProfile(v).spacePassengers)do if a.part==part:getId() then return a end end
 end
 package.loaded.VLS_Propane=VLS
 getText=function(key)return key end
 dofile(root.."/workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media/lua/shared/VLS_KI5Campers_Config.lua")
 package.loaded["Vehicles/ISUI/ISVehicleMechanics"]=true
 package.loaded["Vehicles/ISUI/ISVehiclePartMenu"]=true
 ISVehicleMechanics={};VLS.mechanicsUIProviders={}
 dofile(media.."client/VLS_VehicleMechanicsIcons.lua")
 for _,name in ipairs({"Trailer61Airflyte","Trailer61Astrodome"})do
  local v={name="Base."..name}
  for i,position in ipairs({"FrontLeft","MiddleLeft","RearLeft"})do
   local part={managed=true,getVehicle=function()return v end,getId=function()return "VLSKI5CamperSlot"..i end,getInventoryItem=function()return nil end}
   eq(VLS.getMechanicsPartName(part),"IGUI_VLSKI5Space"..position)
   part.getInventoryItem=function()return {getDisplayName=function()return "Microwave"end}end
   eq(VLS.getMechanicsPartName(part),"Microwave")
  end
 end
 for k in pairs(VLS)do VLS[k]=nil end;for k,v in pairs(snapshot)do VLS[k]=v end
end)
print("RESULT native-adapters tests="..n.." failures=0")
