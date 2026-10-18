-- Pinned native Refuel/Base action bodies + actual VLS callbacks and receiving
-- identity boundaries. Engine, transfer transaction and transport are mocks.
local root,native=assert(arg[1]),assert(arg[2])
local base=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/'
package.path=base..'shared/?.lua;'..package.path
loadstring=loadstring or load;unpack=unpack or table.unpack
local function read(p)local f=assert(io.open(p));local s=f:read('*a');f:close();return s end
local function cut(s,a,b)local i=assert(s:find(a,1,true));local j=assert(s:find(b,i+#a,true));return s:sub(i,j-1)end
local noop=function()end
ISBaseObject={};function ISBaseObject:derive(name)local c={Type=name};c.__index=c;return setmetatable(c,{__index=self})end
package.loaded.ISBaseObject=true
package.preload['TimedActions/ISBaseTimedAction']=function()dofile(native..'/shared/TimedActions/ISBaseTimedAction.lua');return ISBaseTimedAction end
package.preload['Vehicles/TimedActions/ISRefuelFromGasPump']=function()dofile(native..'/shared/Vehicles/TimedActions/ISRefuelFromGasPump.lua');return ISRefuelFromGasPump end
local client=false;isClient=function()return client end;isServer=function()return not client end
Vehicles={JerryCanLitres=8};Metabolics={HeavyDomestic=1};ISLogSystem={logAction=noop}
local F;local queue={};local resets,completed=0,0
ISTimedActionQueue={add=function(a)queue[#queue+1]=a end,getTimedActionQueue=function()return {resetQueue=function()resets=resets+1 end,onCompleted=function()completed=completed+1 end}end}
ISPathFindAction={pathToVehicleArea=function()return {setOnFail=noop}end}
HaloTextHelper={addBadText=noop};getText=function(x)return x end
local function fixture()
 local f={moved=0,writes=0,near=true,at=true,enabled=true,stopped=true,sourceAmount=20}
 local v,p,it,c,src={},{},{},{},{}
 f.v=v;f.p=p;f.it=it;f.c=c;f.src=src;f.data={vlsNativeEpoch=4};f.amount=0
 v.getId=function()return 7 end;v.getPartById=function(_,id)return id=='Tank' and p end
 v.isStopped=function()return f.stopped end;v.isEngineStarted=function()return false end;v.transmitPartModData=noop
 p.getVehicle=function()return v end;p.getId=function()return 'Tank' end;p.getInventoryItem=function()return it end
 p.getItemContainer=function()return nil end;p.getModData=function()return f.data end;p.getArea=function()return 'TankArea' end
 p.getContainerContentAmount=function()return f.amount end;p.getContainerCapacity=function()return 10 end
 p.setContainerContentAmount=function(_,n)f.writes=f.writes+1;f.amount=n end
 it.getID=function()return 12 end;it.getFluidContainer=function()return {getAmount=function()return f.amount end,getCapacity=function()return 10 end}end
 src.getSquare=function()return {}end
 c.getVehicle=function()return f.inside and v or nil end;c.DistToProper=function()return 1 end;c.setMetabolicTarget=noop;c.stopOrTriggerSound=noop;c.setIsFarming=noop
 F=f;queue={};return f
end
VLS={Server={},isSupportedVehicle=function(v)return v==F.v end,isManagedPart=function(p)return p==F.p end,
 isWaterTankShortcutEnabled=function()return F.enabled end,hasWaterTankCapability=function(v)return v==F.v end,
 getInstalledWaterTank=function(v,id)if v==F.v and id=='Tank' then return F.it,F.p end end,
 getFillableWaterTank=function()return F.it,F.p end,isPlayerAtWaterTankInlet=function()return F.at end,
 isWaterSourceNearTank=function()return F.near end,getWaterTankFillAmount=function()return math.min(10-F.amount,F.sourceAmount)end}
package.loaded.VLS_Config=true
local Context=require 'VLS_NativeContext'
-- Execute the actual receiving wrapper; only the existing transfer engine is mocked.
local water=read(base..'shared/VLS_NativeWater.lua')
local recv=cut(water,'function Water.transferWaterTankFillStep','function Water.fillWaterTank')
local factory=assert(loadstring('return function(Context,VLS,transferWaterTankFillStep) local Water={}\n'..recv..'\nreturn Water.transferWaterTankFillStep end'))()
VLS.Server.transferWaterTankFillStep=factory(Context,VLS,function(c,v,it,p,src,n)
 if not F.at or not F.near or not F.stopped or F.inside or not F.enabled then return 0 end
 local moved=math.min(n,F.sourceAmount);F.sourceAmount=F.sourceAmount-moved;F.moved=F.moved+moved
 if F.throw then error('transfer fault')end
 return moved
end)
getVehicleById=function(id)return id==7 and F.v end
local rawResolve=assert(loadstring('return function(Context,VLS)\n'..cut(water,'local function getOutsideWaterTankVehicle','local function resolveWaterSource')..'\nreturn getOutsideWaterTankVehicle end'))()(Context,VLS)
require 'VLS_FillVehicleWaterTankAction'
local actionPath=base..'shared/VLS_FillVehicleWaterTankAction.lua'
local roundtrip=dofile(root..'/tests/net_action_roundtrip.lua')
local source=read(base..'client/VLS_Client.lua')
local callbacks=cut(source,'local function fillVehicleWaterTank','local function addBedSlices')
local menuFn=assert(loadstring('return function(NativeContext,getNearbyWaterSource)\n'..callbacks..'\nreturn addOutsideWaterTankSlice end'))()(Context,function()return F.src end)
ISVehicleMenu={getVehicleToInteractWith=function()return F.v end}
local function menu()
 local m={addSlice=function(self,label,icon,callback,...)self.callback=callback;self.args={...}end};menuFn(m,F.c);return m
end
local function action(epoch)
 local a=VLSFillVehicleWaterTankAction:new(F.c,F.p,F.src,epoch)
 a.action={getJobDelta=function()return 0.5 end};a.netAction={getProgress=function()return 0.5 end};return a
end
local n=0;local function test(name,fn)fn();n=n+1;print('PASS '..name)end
local function eq(a,b)if a~=b then error(tostring(a)..' != '..tostring(b))end end
for _,method in ipairs({'complete','serverStop','update'})do
 test('old actual menu / reconstructed action rejects direct '..method,function()
  local f=fixture();client=true;local m=menu();m.callback(unpack(m.args));eq(#queue,2);local a=queue[2];eq(a.installationEpoch,4)
  client=false;local b=roundtrip(VLSFillVehicleWaterTankAction,actionPath,a);b.action={getJobDelta=function()return 0.5 end};b.netAction={getProgress=function()return 0.5 end}
  f.data.vlsNativeEpoch=5;f.amount=7;b[method](b);eq(f.amount,7);eq(f.writes,0);eq(f.sourceAmount,20);eq(f.moved,0)
  client=true;queue={};m.callback(unpack(m.args));eq(#queue,0)
  local fresh=menu();fresh.callback(unpack(fresh.args));eq(queue[2].installationEpoch,5);client=false
 end)
end
test('new binding completes once through actual native body',function()
 local f=fixture();local a=action(4);eq(a:complete(),true);eq(f.moved,10);eq(f.sourceAmount,10);eq(f.amount,10)
 eq(a:complete(),false);a:update();a:serverStop();eq(f.moved,10);eq(f.writes,1)
end)
test('stop preserves original queue cleanup and one partial server settlement',function()
 local f=fixture();local a=action(4);local old=resets;a:stop();eq(resets,old+1);a:serverStop()
 eq(f.moved,5);eq(f.amount,5);eq(f.sourceAmount,15);local w=f.writes;a:serverStop();a:update();eq(a:complete(),false);eq(f.writes,w);eq(f.moved,5)
end)
test('partial update then cancellation never charges progress twice',function()
 local f=fixture();local a=action(4);a:update();eq(f.moved,5);a:stop();a:serverStop();eq(f.moved,5);eq(f.amount,5)
end)
test('invalid action cleanup retains native queue/sound cleanup without writes',function()
 local f=fixture();local a=action(4);f.data.vlsNativeEpoch=5;f.amount=8;local old=resets;a:stop();eq(resets,old+1);a:serverStop();a:perform();eq(f.writes,0);eq(f.amount,8);eq(f.moved,0)
end)
test('unstarted forceCancel cannot settle or complete',function()
 local f=fixture();local a=action(4);a:forceCancel();a:serverStop();a:update();eq(a:complete(),false);eq(f.moved,0);eq(f.writes,0)
end)
for _,field in ipairs({'at','near','stopped','enabled'})do
 test('changed '..field..' blocks every writing callback',function()
  local f=fixture();local a=action(4);f[field]=false;a:update();a:serverStop();eq(a:complete(),false);eq(f.writes,0);eq(f.moved,0)
 end)
end
test('outside action cannot write after entering vehicle',function()
 local f=fixture();local a=action(4);f.inside=true;a:update();a:serverStop();eq(a:complete(),false);eq(f.writes,0)
end)
test('missing server generation is never inferred',function()
 local f=fixture();local a=action(nil);eq(a.installationEpoch,-1);a:update();a:serverStop();eq(a:complete(),false);eq(f.writes,0)
end)
test('actual public water service rejects stale or missing identity',function()
 local f=fixture();local step=VLS.Server.transferWaterTankFillStep
 eq(step(f.c,f.p,f.src,2,12,3),0);eq(step(f.c,f.p,f.src,2,12,nil),0);eq(step(f.c,f.p,f.src,2,nil,4),0);eq(f.moved,0)
 eq(step(f.c,f.p,f.src,2,12,4),2);eq(f.moved,2)
end)
test('legacy fill command receiver requires fixed primitive generation',function()
 local f=fixture();local args={vehicle=7,part='Tank',tank=12};eq(rawResolve(f.c,args),nil);args.epoch=3;eq(rawResolve(f.c,args),nil);args.epoch=4;eq(rawResolve(f.c,args),f.v)
end)
test('failed complete is terminal and does not retry transfer',function()
 local f=fixture();local a=action(4);f.throw=true;eq(pcall(a.complete,a),false);local moved=f.moved;eq(a:complete(),false);eq(f.moved,moved);eq(f.writes,0)
end)
print('RESULT native fill identity tests='..n..' failures=0; mocked engine/transaction/transport, not live gameplay')
