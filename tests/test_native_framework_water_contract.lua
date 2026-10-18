-- W0 contract tests: ORIGINAL native Lua action/container/util; all Java actors,
-- fluids and networking below are MOCKS. This is not native host or netgame proof.
local root,native=assert(arg[1]),assert(arg[2])
loadstring=loadstring or load
unpack=unpack or table.unpack
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
Base.stop=noop;Base.perform=noop;Base.forceCancel=noop;Base.setActionAnim=noop;Base.setOverrideHandModels=noop
function Base:getDuration()return self.maxTime end
function Base:forceStop()self.stopped=true end
function Base:getJobDelta()return self.progress or 0 end
ISBaseTimedAction=Base;ISBaseObject=Base
package.loaded['TimedActions/ISBaseTimedAction']=true;package.loaded.ISBaseObject=true
for _,name in ipairs({'ISFluidUtil','ISFluidContainer','ISFluidTransferAction'})do
 package.preload['Fluids/'..name]=function()dofile(native..'/shared/Fluids/'..name..'.lua');return _G[name]end
end
local client=false;local server=true;isClient=function()return client end;isServer=function()return server and not client end
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
 function v:getPartById(id)return self.parts[id]end
 function v:transmitPartItem()self.sent=self.sent+1 end
 v.transmitPartModData=noop;v.transmitPartUsedDelta=noop
 local tank={getId=function()return 'Tank' end,it=targetTank and b or a,water=true,data={vlsNativeEpoch=6},vehicle=v}
 function tank:getVehicle()return self.vehicle end
 function tank:getInventoryItem()return self.it end
 function tank:getItemContainer()return nil end
 function tank:getModData()return self.data end
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
 isManagedPart=function(p)return p~=nil end,
 getVehicleFluidItem=function(v,id)local p=v.parts[id];return p and p.it,p end,
 isWaterTankPart=function(p)return p and p.water or false end,syncVehicleWaterTank=noop,
 isPureWaterFluid=function(f)return f.amount>0 and (f.kind=='water' or f.kind=='tainted')end,
 getAuxBatteryPart=function(v)return v.batteryPart end,
 getWaterPurificationCapacity=function(v)return v.charge*10 end,
 getWaterPurificationCost=function(a)return a/10 end,
 canAcceptNormalizedWater=function(f,a)return not f.refuse and not f.locked and f.amount+a<=f.cap end}
local batteryGetter=VLS.getAuxBatteryPart
require("VLS_NativePower").bind(VLS)
VLS.getAuxBatteryPart=batteryGetter
VLS.getWaterPurificationDrainPerLiter=function()return 0.1 end
package.loaded.VLS_Config=VLS
getTimestampMs=function()return 0 end
Events={OnClientCommand={Add=noop},EveryOneMinute={Add=noop}}
dofile(path..'server/VLS_ApplianceServer.lua')
require 'VLS_VehicleFluidTransferAction'
local Action=VLSVehicleFluidTransferAction
local function action(f,amount)return Action:new(f.c,42,f.sourcePart,1,f.targetPart,2,amount or 4,
 f.sourcePart=='' and -1 or 6,f.targetPart=='' and -1 or 6)end
test('original Lua duration and MOCK argument-name reconstruction use exact fields',function()
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
 local s=fixture(false);local copy=Action:new(s.c,a.vehicleId,a.sourcePartId,a.sourceItemId,a.targetPartId,a.targetItemId,a.amount,a.sourceEpoch,a.targetEpoch)
 eq(copy:complete(),true);near(c.a.fc.amount,10);near(s.a.fc.amount,6)
end)
test('all temporary fluid snapshots disposed',function()eq(fluidsCreated,fluidsDisposed)end)

local Context=require 'VLS_NativeContext'
local function wrap(f)
 return VLSVehicleFluidContainer:new(f.tank.it:getFluidContainer(),f.c,f.v,f.tank.it,f.tank)
end
local function oldAction(f)
 return Action:new(f.c,42,f.sourcePart,1,f.targetPart,2,4)
end
local function secondVehicleEndpoint(f)
 local p={it=f.b,water=false,data={vlsNativeEpoch=12},vehicle=f.v}
 function p:getId()return 'Bottle' end
 function p:getVehicle()return self.vehicle end
 function p:getInventoryItem()return self.it end
 function p:getItemContainer()return nil end
 function p:getModData()return self.data end
 f.v.parts.Bottle=p;f.b.carried=false
 return p
end

test('negative control native validation rejects installed owner without vehicle bridge',function()
 local f=fixture(false)
 local fallback=getPlayer;getPlayer=function()return {getInventory=function()return {containsID=function()return false end}end}end
 eq(VLS.vanillaValidateFluidContainer(ISFluidContainer:new(f.a.fc)),false);getPlayer=fallback
 eq(VLS.vanillaValidateFluidContainer(ISFluidContainer:new(f.b.fc)),true)
 eq(ISFluidUtil.validateContainer(wrap(f)),true)
end)
test('W0 public binding carries the tank own identity and exact original fluid',function()
 local f=fixture(false);local c=assert(Context.fluid(f.c,f.v,'Tank',1,6))
 local t=assert(Context.token(c));eq(t.vehicleId,42);eq(t.partId,'Tank');eq(t.installedItemId,1);eq(t.installationEpoch,6)
 eq(c.fluidContainer,f.a.fc);eq(c.fluidContainer:getOwner(),f.a);eq(c.part,f.tank)
end)
test('identity alone grants no outside access',function()
 local f=fixture(false);f.c.v=nil
 eq(Context.identity(f.v,'Tank',1,6).item,f.a)
 eq(Context.fluid(f.c,f.v,'Tank',1,6),nil)
 eq(action(f):isValid(),false)
end)
test('request carries tank epoch and rejects foreign actor inventory',function()
 local f=fixture(false);local s=wrap(f);local t=ISFluidContainer:new(f.b.fc)
 local r=assert(VLS.makeVehicleFluidTransferRequest(f.c,s,t,4));eq(r.source.epoch,6);eq(r.target.kind,'inventory')
 local other=fixture(false);eq(VLS.makeVehicleFluidTransferRequest(other.c,s,t,4),nil)
end)
test('W0 operation delegates original methods and makes no temporary fluid',function()
 local f=fixture(false);local before=fluidsCreated;local a=action(f)
 eq(a.source:getFluidContainer(),f.a.fc);eq(a.target:getFluidContainer(),f.b.fc)
 a.progress=.25;a:update();eq(a:complete(),true)
 near(f.a.fc.amount,6);near(f.b.fc.amount,4);eq(f.b.fc.kind,'tainted');eq(fluidsCreated,before)
 near(f.v.charge,1)
end)
test('W0 does not normalize non-water composition',function()
 local f=fixture(false);f.a.fc.kind='petrol';local a=action(f);eq(a:complete(),true)
 eq(f.b.fc.kind,'petrol');near(f.a.fc.amount,6);near(f.v.charge,1)
end)
test('W0 target capacity remains native-authoritative',function()
 local f=fixture(false);f.b.fc.cap=1;local a=action(f);eq(a:complete(),true)
 near(f.a.fc.amount,9);near(f.b.fc.amount,1)
end)
for _,why in ipairs({'target input lock','target full','source empty','source empty lock','inventory removed','invalid FC owner','foreign part','wrong vehicle'})do
 test('W0 rejects '..why..' before original mutation',function()
  local f=fixture(false);local a=action(f)
  if why=='target input lock'then f.b.fc.locked=true
  elseif why=='target full'then f.b.fc.amount=f.b.fc.cap
  elseif why=='source empty'then f.a.fc.amount=0
  elseif why=='source empty lock'then f.a.fc.noEmpty=true
  elseif why=='inventory removed'then f.b.id=99
  elseif why=='invalid FC owner'then f.a.fc.owner=f.b
  elseif why=='foreign part'then f.tank.vehicle={}
  elseif why=='wrong vehicle'then f.c.v=fixture(false).v end
  local sa,ta=f.a.fc.amount,f.b.fc.amount
  eq(a:isValid(),false);eq(a:complete(),false);a:update();eq(a.stopped,true)
  near(f.a.fc.amount,sa);near(f.b.fc.amount,ta)
 end)
end
test('same item ID reinstall invalidates old wrapper copy refresh action and request',function()
 local f=fixture(false);local a=action(f);local endpoint=wrap(f);local originalFC=f.a.fc
 f.tank.data.vlsNativeEpoch=8
 f.a.fc=fluid(10,20,'water');f.a.fc.owner=f.a
 eq(a:isValid(),false);eq(a:complete(),false);eq(VLS.refreshVehicleFluidEndpoint(endpoint,f.c),false)
 local copy=endpoint:copy();eq(copy.vlsInstallationEpoch,6);eq(copy:getFluidContainer(),originalFC)
 eq(ISFluidUtil.validateContainer(copy),false)
 eq(VLS.makeVehicleFluidTransferRequest(f.c,copy,ISFluidContainer:new(f.b.fc),1),nil)
 eq(Action:new(f.c,42,'Tank',1,'',2,4,6,-1):isValid(),false)
 eq(Action:new(f.c,42,'Tank',1,'',2,4,8,-1):isValid(),true)
end)
test('client same-generation replica refresh keeps token and may rebind exact current FC',function()
 local f=fixture(false);local endpoint=wrap(f);client=true;local a=action(f)
 local replacement=item(1,10,'tainted');f.tank.it=replacement
 eq(VLS.refreshVehicleFluidEndpoint(endpoint,f.c),true);eq(endpoint.vlsInstallationEpoch,6)
 eq(endpoint:getOwner(),replacement);eq(endpoint:getFluidContainer(),replacement.fc)
 eq(a:isValid(),true);eq(a.source:getOwner(),replacement);client=false
end)
test('server same-generation FC replacement cannot rebind an active action',function()
 local f=fixture(false);local a=action(f);f.tank.it=item(1,10,'tainted')
 eq(a:isValid(),false);eq(a:complete(),false)
end)
test('client replica refresh cannot cross generation even with same item ID',function()
 local f=fixture(false);client=true;local a=action(f);local endpoint=wrap(f)
 f.tank.it=item(1,10,'tainted');f.tank.data.vlsNativeEpoch=7
 eq(VLS.refreshVehicleFluidEndpoint(endpoint,f.c),false);eq(a:isValid(),false);client=false
end)
test('legacy W0 seven-argument local constructor pins epoch for reconstruction',function()
 local f=fixture(false);client=true;local a=oldAction(f);eq(a:isValid(),true);eq(a.sourceEpoch,6);eq(a.targetEpoch,-1)
 client=false;eq(oldAction(f):isValid(),false)
 server=false;eq(oldAction(f):isValid(),true);server=true
end)
test('legacy reverse-fill and vehicle bottle seven-argument constructors still execute',function()
 local reverse=fixture(true);local a=oldAction(reverse);eq(a:isValid(),true);eq(a.targetEpoch,6);eq(a:complete(),true)
 local bottle=fixture(false);bottle.tank.water=false;local b=oldAction(bottle);eq(b:isValid(),true);eq(b:complete(),true)
end)
test('both vehicle endpoints serialize distinct epochs and reject stale target',function()
 local f=fixture(false);local p=secondVehicleEndpoint(f)
 local a=Action:new(f.c,42,'Tank',1,'Bottle',2,4,6,12)
 eq(a:isValid(),true);eq(a.sourceEpoch,6);eq(a.targetEpoch,12)
 p.data.vlsNativeEpoch=13;eq(a:isValid(),false);eq(a:complete(),false)
 local b=Action:new(f.c,42,'Tank',1,'Bottle',2,4,6,13);eq(b:complete(),true)
end)
test('legacy vehicle-to-vehicle seven-argument constructor remains compatible',function()
 local f=fixture(false);secondVehicleEndpoint(f)
 local a=Action:new(f.c,42,'Tank',1,'Bottle',2,4);eq(a.sourceEpoch,6);eq(a.targetEpoch,12);eq(a:complete(),true)
end)
for _,epoch in ipairs({-1,0/0,math.huge,6.5,'6',false,{}})do
 test('malformed or stale vehicle generation rejected',function()
  local f=fixture(false);eq(Action:new(f.c,42,'Tank',1,'',2,4,epoch,-1):isValid(),false)
 end)
end
test('repeat completion does not invoke original transfer or sync twice',function()
 local f=fixture(false);local a=action(f);eq(a:complete(),true)
 local count=f.v.sent;eq(a:complete(),false);eq(f.v.sent,count);near(f.b.fc.amount,4)
end)
test('two sequential mocked competitors cannot create extra fluid',function()
 local f=fixture(false);f.a.fc.amount=1
 local a=action(f);local b=action(f);eq(a:complete(),true);eq(b:complete(),false)
 near(f.a.fc.amount+f.b.fc.amount,1);near(f.b.fc.amount,1)
end)


test('saturated or corrupted epoch fails closed',function()
 local f=fixture(false)
 for _,epoch in ipairs({2147483647,-1,6.5,math.huge,'6'})do
  f.tank.data.vlsNativeEpoch=epoch
  eq(Context.identity(f.v,'Tank',1,epoch),nil)
  eq(Context.installationChanged(f.v,f.tank),false)
 end
end)
test('W0 thrown native completion is not retried or privately rolled back',function()
 local f=fixture(false);local a=action(f);fault=true
 eq(pcall(function()a:complete()end),false)
 near(f.a.fc.amount+f.b.fc.amount,10)
 local sa,ta=f.a.fc.amount,f.b.fc.amount
 eq(a:complete(),false);near(f.a.fc.amount,sa);near(f.b.fc.amount,ta)
end)
test('ordinary inventory remains on original validation during native construction',function()
 local f=fixture(false);local original=VLS.vanillaValidateFluidContainer;local inventoryCalls=0
 VLS.vanillaValidateFluidContainer=function(container)
  if container:getOwner()==f.b then inventoryCalls=inventoryCalls+1 end
  return original(container)
 end
 local a=action(f);assert(inventoryCalls>0);eq(a:isValid(),true)
 f.b.id=99;f.b.carried=false;eq(a:isValid(),false)
 VLS.vanillaValidateFluidContainer=original
end)
test('constructor failure cannot leak the vehicle validation exception',function()
 local f=fixture(false);local original=ISFluidTransferAction.new
 ISFluidTransferAction.new=function()error('injected constructor failure')end
 eq(pcall(function()action(f)end),false);ISFluidTransferAction.new=original
 local fallback=getPlayer;getPlayer=function()return {getInventory=function()return {containsID=function()return false end}end}end
 eq(ISFluidUtil.validateContainer(ISFluidContainer:new(f.a.fc)),false);getPlayer=fallback
 eq(ISFluidUtil.validateContainer(ISFluidContainer:new(f.b.fc)),true)
end)
-- Load the supplied original base to test actual lifecycle cleanup/duration.
-- Existing action class inherits Base, so link the original inherited methods
-- and attach only engine/queue mocks; the method bodies remain unchanged.
dofile(native..'/shared/TimedActions/ISBaseTimedAction.lua')
Base.getDuration=ISBaseTimedAction.getDuration
Base.forceCancel=ISBaseTimedAction.forceCancel
ISLogSystem={logAction=noop}
local resetCalls,performedCalls=0,0
ISTimedActionQueue={getTimedActionQueue=function()return {
 resetQueue=function()resetCalls=resetCalls+1 end,
 onCompleted=function()performedCalls=performedCalls+1 end}end}
local function lifecycle(f,a)
 f.c.setIsFarming=noop
 a.action={forceStop=function()a.stopped=true end,setActionAnim=function()a.animated=true end,
 setOverrideHandModelsObject=noop}
 return a
end
test('invalid and stale constructors have safe original duration stop and perform cleanup',function()
 local f=fixture(false)
 for _,a in ipairs({Action:new(f.c,42,'Tank',1,'',2,4,5,-1),Action:new(f.c,42,'Missing',1,'',2,4,6,-1)})do
  lifecycle(f,a);eq(a:isValidStart(),false);eq(a:getDuration(),1)
  a:start();eq(a.animated,nil);eq(a.sound,nil);eq(a:isValid(),false)
  eq(a.serverStart,nil) -- Neither supplied original base nor transfer action defines this method.
  local beforeReset,beforePerform=resetCalls,performedCalls
  a:stop();a:perform();eq(resetCalls,beforeReset+1);eq(performedCalls,beforePerform+1)
  eq(a:complete(),false);near(f.b.fc.amount,0)
 end
end)
test('valid start delegates original sound animation then cancellation forbids later transfer',function()
 local f=fixture(false);local a=lifecycle(f,action(f));eq(a:isValidStart(),true)
 a:start();eq(a.sound,1);a.progress=.25;a:update();a:stop()
 local amount=f.b.fc.amount;eq(a:complete(),false);a:update();near(f.b.fc.amount,amount)
end)
test('forceCancel before start closes the queued action without fluid mutation',function()
 local f=fixture(false);local a=action(f);a:forceCancel();eq(a:isValidStart(),false);eq(a:complete(),false)
 near(f.a.fc.amount,10);near(f.b.fc.amount,0)
end)

local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
ISFluidTransferUI={}
local uiSource=read(native..'/client/Fluids/ISFluidTransferUI.lua')
local ua=assert(uiSource:find('function ISFluidTransferUI:validatePanel(',1,true))
local ub=assert(uiSource:find('function ISFluidTransferUI:prerender(',ua,true))
assert(loadstring(uiSource:sub(ua,ub-1)))()
local vlsClient=read(path..'client/VLS_Client.lua')
local ra=assert(vlsClient:find('local function refreshVLSFluidPanelEndpoint',1,true))
local rb=assert(vlsClient:find('local function updateVLSFluidTransfer',ra,true))
local refreshPanel=assert(loadstring(vlsClient:sub(ra,rb-1)..'\nreturn refreshVLSFluidPanelEndpoint'))()
PZMath={min=math.min};FluidUtil.roundTransfer=function(x)return x end
local function uiFixture(f)
 local allNoops=setmetatable({},{__index=function()return noop end})
 local function panel(endpoint)
  local p={container=endpoint,fluidBar=allNoops,setPanelLocked=noop,setInvalid=noop}
  function p:getContainer()return self.container:getFluidContainer()end
  function p:getContainerOwnerObject()return self.container:getOwner()end
  return p
 end
 f.a.fc.getPrimaryFluid=function()return nil end
 f.b.fc.getPrimaryFluid=function()return nil end
 return setmetatable({player=f.c,panelLeft=panel(wrap(f)),panelRight=panel(ISFluidContainer:new(f.b.fc)),
  fromPreviousOwner=f.a,toPreviousOwner=f.b,fluidTitleLabel=allNoops,errorLabel=allNoops,
  slider={getCurrentValue=function()return 0 end},info={maxTransfer=4,transferring=0},
  btnTransfer=allNoops,btnSwap=allNoops,setMaxTransfer=noop,setTransferring=noop,
  close=function(self)self.closed=true end},{__index=ISFluidTransferUI})
end
test('original native UI stays open only for same-generation replica replacement',function()
 local f=fixture(false);local ui=uiFixture(f);client=true
 local replacement=item(1,10,'tainted');replacement.fc.getPrimaryFluid=function()return nil end
 f.tank.it=replacement
 refreshPanel(ui,ui.panelLeft);ui:validatePanel(false)
 eq(ui.closed,nil);eq(ui.fromPreviousOwner,replacement);eq(ui.panelLeft.container.vlsInstallationEpoch,6)
 client=false
end)
test('original native UI still closes for same-ID new-generation replacement',function()
 local f=fixture(false);local ui=uiFixture(f);client=true
 local original=ui.panelLeft.container:getFluidContainer()
 f.tank.it=item(1,10,'tainted');f.tank.data.vlsNativeEpoch=8
 refreshPanel(ui,ui.panelLeft);ui:validatePanel(false)
 eq(ui.closed,true);eq(ui.panelLeft.container:getFluidContainer(),original);eq(ui.fromPreviousOwner,f.a)
 client=false
end)

local ca=assert(vlsClient:find('local function onVLSFluidTransferClick',1,true))
local cb=assert(vlsClient:find('local function refreshVLSFluidPanelEndpoint',ca,true))
local transferClick=assert(loadstring('local vanillaFluidOnButton = function() end\n'..vlsClient:sub(ca,cb-1)..'\nreturn onVLSFluidTransferClick'))()
test('native UI W0 click queues once and carries explicit epoch primitives',function()
 local f=fixture(false);local ui=uiFixture(f);local queued={};client=true
 ui.info.transferring=4;ui.slider.setCurrentValue=noop
 ISTimedActionQueue.add=function(a)table.insert(queued,a)end
 transferClick(ui,{internal='TRANSFER'});transferClick(ui,{internal='TRANSFER'})
 eq(#queued,1);eq(queued[1].sourceEpoch,6);eq(queued[1].targetEpoch,-1)
 eq(queued[1].source:getFluidContainer(),f.a.fc);eq(ui.disableTransfer,true);client=false
end)
test('stale native UI W0 click cannot silently acquire the current tank generation',function()
 local f=fixture(false);local ui=uiFixture(f);local queued=0;client=true
 ui.info.transferring=4;ui.slider.setCurrentValue=noop
 ISTimedActionQueue.add=function()queued=queued+1 end
 f.tank.data.vlsNativeEpoch=8
 transferClick(ui,{internal='TRANSFER'});eq(queued,0);eq(ui.action,nil);client=false
end)
print('RESULT W0 original-Lua contract + mocked Java fixtures tests='..n..' failures=0; LIVE HOST / NETACTION TRANSPORT / GAMEPLAY NOT RUN')
