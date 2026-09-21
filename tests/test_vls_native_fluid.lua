-- Real native Lua action/container/util with distinct MP actors and mocked fluids.
local root,native=assert(arg[1]),assert(arg[2])
local roundtripPath=root.."/tests/net_action_roundtrip.lua"
local roundtripFile=io.open(roundtripPath)
if roundtripFile then roundtripFile:close()
else roundtripPath=root.."/../../tests/vehicle-living-slots/net_action_roundtrip.lua" end
local path=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/'
package.path=path..'shared/?.lua;'..package.path
local n=0;local function test(name,fn)fn();n=n+1;print('PASS '..name)end
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function near(a,b)assert(math.abs(a-b)<1e-6,tostring(a)..' != '..tostring(b))end
local noop=function()end
local Base={};function Base:derive(name)local c={Type=name};c.__index=c;return setmetatable(c,{__index=self})end
function Base:new(c)return setmetatable({character=c},{__index=self})end
Base.stop=noop;Base.perform=noop;Base.setActionAnim=noop;Base.setOverrideHandModels=noop
function Base:forceStop()self.stopped=true end
function Base:getJobDelta()return self.progress or 0 end
ISBaseTimedAction=Base;ISBaseObject=Base
package.loaded['TimedActions/ISBaseTimedAction']=true;package.loaded.ISBaseObject=true
for _,name in ipairs({'ISFluidUtil','ISFluidContainer','ISFluidTransferAction'})do
 package.preload['Fluids/'..name]=function()dofile(native..'/shared/Fluids/'..name..'.lua');return _G[name]end
end
local client=false;isClient=function()return client end;isServer=function()return not client end
instanceof=function(o,t)return o and o.class==t or false end
FluidUtil={getTransferActionTimePerLiter=function()return 100 end,getMinTransferActionTime=function()return 10 end}
Fluid={Water='water'};Metabolics={LightDomestic=1,HeavyDomestic=2,MediumWork=3}
local fluidsCreated,fluidsDisposed=0,0
local function fluid(amount,cap,kind)
 local f={class='FluidContainer',amount=amount or 0,cap=cap or 20,kind=kind or 'water',locked=false}
 function f:getAmount()return self.amount end;function f:getCapacity()return self.cap end
 function f:setCapacity(v)self.cap=v end;function f:getOwner()return self.owner end
 function f:canPlayerEmpty()return not self.noEmpty end
 function f:isInputLocked()return self.locked end;function f:setInputLocked(v)self.locked=v end
 function f:canAddFluid()return not self.locked and not self.refuse end
 function f:addFluid(k,a)self.amount=self.amount+a;self.kind=k end
 function f:removeFluid(a)self.amount=math.max(0,self.amount-a)end
 function f:copy()fluidsCreated=fluidsCreated+1;return fluid(self.amount,self.cap,self.kind)end
 function f:copyFluidsFrom(o)self.amount=o.amount;self.kind=o.kind end
 function f:getSpecificFluidAmount(k)return k==self.kind and self.amount or 0 end
 function f:createFluidSample()return {size=function()return 1 end,getFluid=function()return self.kind end,release=noop}end
 return f
end
local fault=false
FluidContainer={CanTransfer=function(s,t)return s~=t and s.amount>0 and not t.locked and not t.refuse and t.amount<t.cap end,
 CreateContainer=function()fluidsCreated=fluidsCreated+1;return fluid()end,
 DisposeContainer=function()fluidsDisposed=fluidsDisposed+1 end,
 Transfer=function(s,t,a)
  if not FluidContainer.CanTransfer(s,t)then return end
  local moved=math.min(a,s.amount,t.cap-t.amount);s.amount=s.amount-moved;t.amount=t.amount+moved;t.kind=s.kind
  if fault then fault=false;error('native transfer fault after mutation')end
 end}
local function item(id,amt,kind)
 local i={id=id,class='InventoryItem',fc=fluid(amt,20,kind),synced=0};i.fc.owner=i
 function i:getID()return self.id end;function i:getFluidContainer()return self.fc end
 function i:isInPlayerInventory()return self.carried==true end
 function i:syncItemFields()self.synced=self.synced+1 end
 function i:getItemHeat()return 0 end
 return i
end
local current
local function fixture(targetTank)
 local a,b=item(1,10,'tainted'),item(2,0)
 local v={id=42,parts={},sent=0,charge=1}
 function v:getId()return self.id end
 function v:transmitPartItem()self.sent=self.sent+1 end
 v.transmitPartModData=noop;v.transmitPartUsedDelta=noop
 local tank={getId=function()return 'Tank' end,it=targetTank and b or a,water=targetTank}
 v.parts.Tank=tank
 local carried=targetTank and a or b;carried.carried=true
 local inventory={getItemWithIDRecursiv=function(_,id)return carried and carried.id==id and carried or nil end}
 local c={v=v,getPlayerNum=function()return 0 end,getInventory=function()return inventory end,
 getVehicle=function(self)return self.v end,isTimedActionInstant=function()return false end,
 setMetabolicTarget=noop,faceThisObject=noop,playSound=function()return 1 end,
 getEmitter=function()return {isPlaying=function()return false end}end}
 current=c
 v.battery={getCurrentUsesFloat=function()return v.charge end,setUsedDelta=function(_,x)v.charge=x end}
 v.batteryPart={getInventoryItem=function()return v.battery end}
 return {c=c,v=v,a=a,b=b,tank=tank,sourcePart=targetTank and '' or 'Tank',targetPart=targetTank and 'Tank' or ''}
end
getSpecificPlayer=function()return current end
getPlayer=function()error('server must never use local player fallback')end
VLS={VERSION='3.8.8',Server={},isSupportedVehicle=function(v)return v and v.id==42 end,
 getVehicleFluidItem=function(v,id)local p=v.parts[id];return p and p.it,p end,
 isWaterTankPart=function(p)return p and p.water or false end,syncVehicleWaterTank=noop,
 isPureWaterFluid=function(f)return f.amount>0 and (f.kind=='water' or f.kind=='tainted')end,
 getAuxBatteryPart=function(v)return v.batteryPart end,
 getWaterPurificationCapacity=function(v)return v.charge*10 end,
 getWaterPurificationCost=function(a)return a/10 end,
 canAcceptNormalizedWater=function(f,a)return not f.refuse and not f.locked and f.amount+a<=f.cap end}
package.loaded.VLS_Config=VLS
getTimestampMs=function()return 0 end
Events={OnClientCommand={Add=noop},EveryOneMinute={Add=noop}}
dofile(path..'server/VLS_ApplianceServer.lua')
require 'VLS_VehicleFluidTransferAction'
local Action=VLSVehicleFluidTransferAction
local function action(f,amount)return Action:new(f.c,42,f.sourcePart,1,f.targetPart,2,amount or 4)end
test('native duration and MP ID roundtrip use exact constructor fields',function()
 local f=fixture(false);client=true;local a=action(f);eq(a.maxTime,400)
 client=false;local roundtrip=dofile(roundtripPath)
 local b=roundtrip(Action,path..'shared/VLS_VehicleFluidTransferAction.lua',a)
 eq(b:isValid(),true);eq(b.source:getOwner(),f.a);eq(b.sourcePartId,'Tank');eq(b.targetItemId,2)
end)
test('native progressive transfer and cancel retain only completed amount',function()
 local f=fixture(false);local a=action(f);a.progress=.25;a:update();near(f.a.fc.amount,9);near(f.b.fc.amount,1)
 a:stop();near(f.a.fc.amount,9);near(f.b.fc.amount,1);eq(f.v.sent,1)
end)
test('native completion transfers once with source and target sync',function()
 local f=fixture(false);local a=action(f);eq(a:complete(),true);near(f.a.fc.amount,6);near(f.b.fc.amount,4)
 eq(a:complete(),false);eq(f.a.synced,1);eq(f.b.synced,1)
end)
test('native client update never consumes resources',function()
 local f=fixture(false);client=true;local a=action(f);a.progress=.75;a:update();eq(a:complete(),false)
 near(f.a.fc.amount,10);near(f.b.fc.amount,0);client=false
end)
test('purification delegates native progress and bills actual accepted water',function()
 local f=fixture(true);local a=action(f);a.progress=.25;a:update()
 near(f.a.fc.amount,9);near(f.b.fc.amount,1);eq(f.b.fc.kind,'water');near(f.v.charge,.9)
 a.progress=.5;a:update();near(f.a.fc.amount,8);near(f.b.fc.amount,2);near(f.v.charge,.8)
 eq(a:complete(),true);near(f.a.fc.amount,6);near(f.b.fc.amount,4);near(f.v.charge,.6)
end)
test('power-limited purification cannot overdraw fuel or battery',function()
 local f=fixture(true);f.v.charge=.05;local a=action(f);a.progress=.5;a:update()
 near(f.a.fc.amount,9.5);near(f.b.fc.amount,.5);near(f.v.charge,0)
 a:update();eq(a.stopped,true);near(f.b.fc.amount,.5)
end)
test('target capacity wins over requested amount',function()
 local f=fixture(true);f.b.fc.cap=1;local a=action(f);eq(a:complete(),true)
 near(f.a.fc.amount,9);near(f.b.fc.amount,1);near(f.v.charge,.9)
end)
test('failed native purification restores water, composition, battery and views',function()
 local f=fixture(true);local a=action(f);local source=a.source;fault=true;a.progress=.5;a:update()
 eq(a.stopped,true);near(f.a.fc.amount,10);near(f.b.fc.amount,0);eq(f.a.fc.kind,'tainted');near(f.v.charge,1)
 eq(a.source,source);near(a.sourceStartAmount,10)
end)
for _,why in ipairs({'exit','replacement','inventory missing','locked','empty source','wrong liquid','no power'})do
 test('authoritative rejection after '..why,function()
  local f=fixture(true);local a=action(f)
  if why=='exit'then f.c.v=nil elseif why=='replacement'then f.tank.it=item(999,0)
  elseif why=='inventory missing'then f.a.id=99 elseif why=='locked'then f.a.fc.noEmpty=true
  elseif why=='empty source'then f.a.fc.amount=0 elseif why=='wrong liquid'then f.a.fc.kind='petrol'
  elseif why=='no power'then f.v.charge=0 end
  eq(a:isValid(),false);eq(a:complete(),false);near(f.b.fc.amount,0)
 end)
end
for _,bad in ipairs({0,-1,0/0,math.huge,'4',{},true})do
 test('malformed amount rejected',function()eq(action(fixture(false),bad):isValid(),false)end)
end
test('two peers resolve server containers rather than client object copies',function()
 local c=fixture(false);client=true;local a=action(c);client=false
 local s=fixture(false);local copy=Action:new(s.c,a.vehicleId,a.sourcePartId,a.sourceItemId,a.targetPartId,a.targetItemId,a.amount)
 eq(copy:complete(),true);near(c.a.fc.amount,10);near(s.a.fc.amount,6)
end)
test('all temporary fluid snapshots disposed',function()eq(fluidsCreated,fluidsDisposed)end)
print('RESULT native-fluid tests='..n..' failures=0')
