-- Real native Lua + exact VLS wrapper; Java objects and complete vehicle geometry mocked.
-- Usage: lua5.1 test_vls_camper_seat_lag.lua MOD_ROOT NATIVE_LUA_ROOT [fixed|baseline]
local root,native=assert(arg[1]),assert(arg[2]);local expectation=arg[3]or'fixed'
local noop=function()end;local checks=0
local function check(v,m)assert(v,m);checks=checks+1 end
local function read(p)local f=assert(io.open(p));local s=f:read('*a');f:close();return s end
local report=rawget(_G,'VLS_LAG_REPORT')or function(r)print('LAG_CASE '..r.label)end
local media=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/'
local campers=root..'/workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media/lua/'
package.path=media..'shared/?.lua;'..campers..'shared/?.lua;'..package.path
for _,n in ipairs({'VLS_InstallGuard','Entity/TimedActions/ISHandcraftAction','TimedActions/ISDeviceBatteryAction','Vehicles/Vehicles'})do package.loaded[n]=true end
local V=require'VLS_Config';package.loaded.VLS_Propane=V;require'VLS_KI5Campers_Config'
instanceof=function(o,k)return o and o.kind==k end
getText=function(k)return k end;getTextOrNull=noop
UIFont={Medium=1,Large=2};getTextManager=function()return{getFontHeight=function()return 16 end}end
ISPanelJoypad={render=noop,prerender=noop};function ISPanelJoypad:derive()return setmetatable({},{__index=self})end
package.loaded['ISUI/ISPanelJoypad']=true;ISCarMechanicsOverlay={CarList={}}
Keyboard={KEY_LSHIFT=1,KEY_RSHIFT=2};isKeyDown=function()return false end
local textures={};getTexture=function(n)
 if not textures[n]then textures[n]={name=n,getOffsetX=function()return 0 end,getOffsetY=function()return 0 end,getWidth=function()return 24 end,getHeight=function()return 24 end,getWidthOrig=function()return 24 end,getHeightOrig=function()return 24 end}end
 return textures[n]
end
Joypad={Texture={AButton=getTexture('A'),XButton=getTexture('X')}}
ISVehicleMenu={}
local s=read(native..'/client/Vehicles/ISUI/ISVehicleMenu.lua')
local a=assert(s:find('function ISVehicleMenu.transferSeatItems',1,true));local b=assert(s:find('function ISVehicleMenu.onEnter(',a,true))
assert(loadstring(s:sub(a,b-1),'@native/ISVehicleMenu.transfer'))()
dofile(native..'/client/Vehicles/ISUI/ISVehicleSeatUI.lua');package.loaded['Vehicles/ISUI/ISVehicleSeatUI']=true
local nativeMove,nativeTransfer=ISVehicleMenu.moveItemsFromSeat,ISVehicleMenu.transferSeatItems
local counts={};local function inc(k,n)counts[k]=(counts[k]or 0)+(n or 1)end
local delegateMode,delegateCalls,delegateArgs='native',0,nil;local delegateError={}
ISVehicleMenu.moveItemsFromSeat=function(...)
 delegateCalls=delegateCalls+1;delegateArgs={n=select('#',...),...}
 if delegateMode=='spy'then return'delegated',17 end
 if delegateMode=='error'then error(delegateError)end
 inc('moveItemsFromSeat');return nativeMove(...)
end
ISVehicleMenu.transferSeatItems=function(...)inc('transferSeatItems');return nativeTransfer(...)end
local client=read(media..'client/VLS_Client.lua')
a=assert(client:find('    local vanillaMoveItemsFromSeat = ISVehicleMenu.moveItemsFromSeat',1,true));b=assert(client:find('    Events.OnTick.Add(processClientState)',a,true))
assert(loadstring('local SeatR6 = VLS.SeatR6\n'..client:sub(a,b-1),'@VLS_Client.exact-wrapper'))()
local wrappedMove=ISVehicleMenu.moveItemsFromSeat
local capturedTransfer=ISVehicleMenu.transferSeatItems
local savedSeatR6move=V.SeatR6.moveItems
-- Any accidental timed-action use from rendering is an immediate failure.
ISTimedActionQueue={add=function()error('UI must not enqueue actions')end}
ISInventoryTransferUtil={newInventoryTransferAction=function()error('UI must not construct actions')end}
dofile(media..'client/VLS_SeatDisplay.lua')
a=assert(client:find('if not VLS.bedSeatUIHookApplied then',1,true));b=assert(client:find('-- Reload-sensitive adapters',a,true))
assert(loadstring(client:sub(a,b-1),'@VLS_Client.seatUI'))()
dofile(campers..'client/VLS_KI5Campers_SeatUI.lua')
local models={'Base.Trailer87Scamp13','Base.Trailer87Scamp16','Base.Trailer61Bambi16','Base.Trailer54FlyingCloud22','Base.Trailer61Airflyte','Base.Trailer61Astrodome'}
local nativeNames={
 ['Base.Trailer87Scamp13']={'FrontL','FrontR','BackL','BackR'},
 ['Base.Trailer87Scamp16']={'FrontL','FrontR','RearL','RearR','BackL','BackR'},
 ['Base.Trailer61Bambi16']={'FrontB','SideB','RearL','RearR'},
 ['Base.Trailer54FlyingCloud22']={'FrontB','SideB','FrontL','FrontR','RearL','RearR'},
 ['Base.Trailer61Airflyte']={'FrontL','FrontR','RearL','RearR','BackL','BackR'},
 ['Base.Trailer61Astrodome']={'FrontL','FrontR','RearL','RearR','BackL','BackR','FrontTop'},
}
local function vector(x,y,z)local v={x,y,z};function v:get(i)return self[i+1]end;function v:set(a,b,c)self[1],self[2],self[3]=a,b,c end;return v end
local function item(ft)return{kind='Moveable',getFullType=function()return ft end,getDisplayName=function()return ft end,getScriptItem=noop,getWorldSprite=noop}end
local function fixture(name,num,inside,bed)
 local ids={'DAMNFakeSeat'};for _,id in ipairs(nativeNames[name])do ids[#ids+1]=id end
 local nativeCount=#ids;for _,x in ipairs(V.vehicleProfiles[name].spacePassengers)do ids[#ids+1]=x.passenger end
 local passengers,parts,byId={},{},{};local character={};local vehicle={}
 local script={getFullName=function()return name end,getExtents=function()return{x=function()return 2 end,z=function()return 5 end}end,getCarMechanicsOverlay=noop}
 function script:getPassengerCount()return #passengers end
 function script:getPassenger(i)inc('getPassenger');return passengers[i+1]end
 function script:getPassengerIndex(id)inc('getPassengerIndex');for i,x in ipairs(ids)do inc('passengerIdCompare');if x==id then return i-1 end end;return -1 end
 function vehicle:getScriptName()return name end;function vehicle:getScript()return script end
 function vehicle:getMaxPassengers()return #passengers end
 function vehicle:getSeat()return inside and 1 or -1 end
 function vehicle:getCharacter(seat)return inside and seat==1 and character or nil end
 function character:getVehicle()return inside and vehicle or nil end
 function vehicle:getPartById(id)inc('getPartById');return byId[id]end
 function vehicle:getPartForSeatContainer(seat)inc('getPartForSeatContainer');return parts[seat+1]end
 function vehicle:isSeatInstalled(seat)local p=self:getPartForSeatContainer(seat);return p and p:getInventoryItem()~=nil end
 function vehicle:isSeatOccupied(seat)
  inc('isSeatOccupied');local p=parts[seat+1];local c=p and p:getItemContainer()
  return c and not c:isEmpty()and c:getContentsWeight()*4>c:getCapacity()or self:getCharacter(seat)~=nil
 end
 function vehicle:canSwitchSeat(_,to)inc('canSwitchSeat');return to~=0 end
 function vehicle:getPartIndex()return -1 end
 function vehicle:getAllSeatParts()inc('getAllSeatParts');return{size=function()return #passengers end,get=function(_,i)return parts[i+1]end}end
 function vehicle:updateHasExtendOffsetForExit()inc('exitSetup')end
 function vehicle:updateHasExtendOffsetForExitEnd()inc('exitCleanup')end
 function vehicle:isExitBlocked()inc('isExitBlocked');return self.blocked or false end
 for i,id in ipairs(ids)do
  local insideOffset=vector(i%2==0 and -.6 or .6,0,1-(i-1)*.4);local outsideOffset=vector(1.2,0,-1)
  passengers[i]={getId=function()return id end,getPositionById=function(_,pos)return{getOffset=function()return pos=='inside'and insideOffset or outsideOffset end}end}
  local living=i>nativeCount;local partId=living and'VLSKI5CamperSlot'..(i-nativeCount)or'Seat'..id
  local c={count=living and num or 0,capacity=20,totalWeight=living and num>0 and 19.99 or 0}
  local cargo={getUnequippedWeight=function()inc('itemWeight');return c.count>0 and c.totalWeight/c.count or 0 end}
  local array={size=function()return c.count end,get=function()inc('itemGet');return cargo end}
  function c:isEmpty()return self.count==0 end;function c:getCapacity()return self.capacity end
  function c:getContentsWeight()inc('getContentsWeight');inc('weightAggregateItemVisits',self.count);return self.totalWeight end
  function c:getItems()return array end
  local part={item=item(living and(bed and'Base.Mov_Cot'or'Base.Mov_FridgeMini')or'Base.CarSeat'),container=c}
  function part:getId()return partId end;function part:getVehicle()return vehicle end
  function part:getInventoryItem()return self.item end;function part:getItemContainer()return self.container end
  parts[i]=part;byId[partId]=part
 end
 local p=setmetatable({vehicle=vehicle,character=character,width=263,height=500,firstLiving=nativeCount,characterSeat=inside and 1 or -1,backgroundColor={r=0,g=0,b=0},richText={setText=noop,render=noop},exitDraws=0},{__index=ISVehicleSeatUI})
 function p:getWidth()return self.width end;function p:getHeight()return self.height end
 function p:getMouseX()return -100 end;function p:getMouseY()return -100 end
 function p:drawTextureScaledUniform(tex)if tex.name=='media/ui/vehicles/vehicle_exit.png'then self.exitDraws=self.exitDraws+1 end end
 p.drawTextCentre=noop;p.drawRect=noop;p.drawRectBorder=noop
 p.parts,p.partsById,p.passengers=parts,byId,passengers
 return p
end
local function measure(name,num,inside,bed,hover,frames,blocked)
 local p=fixture(name,num,inside,bed);p.vehicle.blocked=blocked
 local snap={};for i,x in ipairs(p.passengers)do local o=x:getPositionById('inside'):getOffset();snap[i]={o:get(0),o:get(1),o:get(2)}end
 counts={};delegateMode='native'
 for _=1,frames do p:render();if hover then p.mouseOverSeat=p.firstLiving;p:prerender()end end
 local c=counts
 for i,x in ipairs(p.passengers)do local o=x:getPositionById('inside'):getOffset();for axis=0,2 do check(o:get(axis)==snap[i][axis+1],'restored display coordinates')end end
 check((c.exitSetup or 0)==(c.exitCleanup or 0),'exit setup cleanup paired')
 if blocked then check(p.exitDraws==0,'blocked exits not displayed')end
 if expectation=='fixed'and not bed then check((c.moveItemsFromSeat or 0)==0,'non-bed UI must skip native relocation '..name)end
 if expectation=='baseline'and num>0 and not bed then check((c.moveItemsFromSeat or 0)>0,'baseline must exercise expensive path')end
 if num==0 then check((c.transferSeatItems or 0)==0,'empty slots do not plan transfer')end
 report({label=name..'_'..num..'_'..tostring(inside)..'_'..tostring(bed)..'_'..tostring(hover)..'_'..tostring(blocked),model=name,itemsPerLivingSlot=num,inside=inside,bed=bed,hover=hover,blocked=blocked or false,frames=frames,passengerPositions=p.vehicle:getMaxPassengers(),counts=c,exitDraws=p.exitDraws})
end
for _,name in ipairs(models)do
 measure(name,0,true,false,false,60)
 measure(name,500,true,false,false,60)
 measure(name,500,true,false,true,60)
 measure(name,500,false,false,true,60)
 measure(name,500,true,false,true,3,true)
 measure(name,0,true,true,false,3)
end
if expectation=='fixed'then
 local function delegated(p,v,seat,move,enter,msg)
  delegateMode='spy';local before=delegateCalls;local a,b=wrappedMove(p and p.character,v,seat,move,enter)
  check(a=='delegated'and b==17,msg..' returns')
  check(delegateCalls==before+1,msg..' one prior invocation')
  check(delegateArgs.n==5 and delegateArgs[1]==(p and p.character)and delegateArgs[2]==v and delegateArgs[3]==seat and delegateArgs[4]==move and delegateArgs[5]==enter,msg..' real object identity/flags')
 end
 for _,name in ipairs(models)do
  local p=fixture(name,500,true,false);local v=p.vehicle;local seat=p.firstLiving
  check(not V.SeatR6.applies(v),'Camper stays outside original SeatR6 route')
  for _,assignment in ipairs(V.getVehicleProfile(v).spacePassengers)do
   local s=v:getScript():getPassengerIndex(assignment.passenger);delegateMode='spy';local before=delegateCalls
   check(wrappedMove(p.character,v,s,false,false)==false and delegateCalls==before,'all configured equipment slots bypass dry plan')
   delegated(p,v,s,true,false,'real movement');delegated(p,v,s,true,true,'real movement/entry');delegated(p,v,s,false,true,'entry')
   delegated(p,v,s,nil,false,'legacy nil move flag');delegated(p,v,s,false,nil,'legacy nil enter flag')
  end
  for _,s in ipairs({0,1,-1,99,'6'})do delegated(p,v,s,false,false,'nonliving or invalid seat')end
  delegated(p,v,nil,false,false,'nil seat')
  local part=v:getPartForSeatContainer(seat);local old=part.item
  for _,ft in ipairs({'Base.Mov_Cot','Base.Mattress','Base.SleepingBag_RedPlaid'})do part.item=item(ft);delegated(p,v,seat,false,false,'live installed bed '..ft)end
  part.item=old;delegateMode='spy';local before=delegateCalls
  check(wrappedMove(p.character,v,seat,false,false)==false and before==delegateCalls,'immediate bed-to-equipment change')
  part.item=nil;check(wrappedMove(p.character,v,seat,false,false)==false and before==delegateCalls,'uninstalled living slot')
  part.item=old;local id=part:getId();p.partsById[id]=nil
  check(wrappedMove(p.character,v,seat,false,false)==false and before==delegateCalls,'missing part')
  p.partsById[id]=part
  local script=v:getScript();v.getScript=function()return nil end;delegated(p,v,seat,false,false,'missing script');v.getScript=function()return script end
  local idx=script.getPassengerIndex;script.getPassengerIndex=function()return -1 end;delegated(p,v,seat,false,false,'missing passenger');script.getPassengerIndex=idx
  local oldName=v.getScriptName;v.getScriptName=function()return'Base.Unknown'end;delegated(p,v,seat,false,false,'unknown vehicle')
  v.getScriptName=function()return nil end;delegated(p,v,seat,false,false,'missing script name');v.getScriptName=oldName
  delegateMode='error';local ok,e=pcall(wrappedMove,p.character,v,seat,true,false);check(not ok and e==delegateError,'native errors preserved')
  -- Inventory changes on the SAME vehicle/panel immediately affect native occupancy;
  -- the dry-plan guard never caches or changes container contents.
  delegateMode='native';part.container.count=0;part.container.totalWeight=0;counts={};p:render();local empty=counts.weightAggregateItemVisits or 0
  part.container.count=500;part.container.totalWeight=19.99;counts={};p:render()
  check((counts.weightAggregateItemVisits or 0)>empty and(counts.itemGet or 0)==0,'same-panel inventory change seen, no transfer simulation')
  check(part.container.count==500 and part.container.totalWeight==19.99,'UI leaves contents unchanged')
 end
 delegated(nil,nil,nil,false,false,'nil vehicle')
 local p=fixture(models[1],0,true,false);local v=p.vehicle;local applies,move=V.SeatR6.applies,V.SeatR6.moveItems;local calls=0
 V.SeatR6.applies=function(x)return x==v end
 V.SeatR6.moveItems=function(fn,character,vehicle,seat,m,e)calls=calls+1;check(fn==capturedTransfer and character==p.character and vehicle==v and seat==1 and m==false and e==false,'existing SeatR6 args');return'seat-r6'end
 check(wrappedMove(p.character,v,1,false,false)=='seat-r6'and calls==1,'existing SeatR6 still delegated')
 V.SeatR6.applies,V.SeatR6.moveItems=applies,move
end
report({label='summary',checks=checks,passed=true,expectation=expectation,models=#models})
print('CAMPER_SEAT_LAG_PASS checks='..checks..' expectation='..expectation)
