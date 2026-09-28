-- Real shared power methods + F700 composition; mock engine items/network only.
local root=assert(arg[1])
package.loaded.VLS_InstallGuard=true
ISUninstallVehiclePart={complete=function()end}
Events={OnTick={Add=function()end}}
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/VLS_Config.lua")
package.loaded.VLS_Config=V
local client=false
isClient=function()return client end;isServer=function()return true end
instanceof=function(o,k)return o and o.kind==k end
getText=function(k)return k end
local A=require "VLS_KI5F700_Config"
require "VLS_KI5F700_Power"
local P=V.VehiclePower
local count=0
local function test(name,fn)fn();count=count+1;print("PASS "..name)end
local function near(a,b)assert(math.abs(a-b)<1e-8,tostring(a).." ~= "..tostring(b))end
local function battery(charge)
 return {kind="DrainableComboItem",charge=charge,getFullType=function()return "Base.CarBattery2"end,
 getCurrentUsesFloat=function(s)return s.charge end,setUsedDelta=function(s,v)s.charge=v end}
end
local function fixture(name,a,b)
 local v={parts={},sent={}}
 function v:getScriptName()return name end
 function v:getPartById(id)return self.parts[id]end
 function v:transmitPartUsedDelta(p)self.sent[p:getId()]=(self.sent[p:getId()] or 0)+1 end
 local function part(id,q)
  local p={item=q,getId=function()return id end,getVehicle=function()return v end,getInventoryItem=function(s)return s.item end}
  v.parts[id]=p;return p
 end
 part("Battery",battery(1))
 local first=part(V.AUX_BATTERY_PART_ID,a and battery(a))
 local second=part(A.battery3Id,b and battery(b))
 return v,first,second
end
for _,model in ipairs({"Base.87fordB700school","Base.87fordB700prison","Base.87fordB700military"})do
 test(model.." combines two living batteries without touching starter",function()
  local v,a,b=fixture(model,.25,.5)
  near(P.charge(v),.75);near(P.capacity(v,.1),7.5);assert(P.has(v,.7) and not P.has(v,.8))
  assert(P.consume(v,.4));near(a.item.charge,0);near(b.item.charge,.35);near(v.parts.Battery.item.charge,1)
  assert(v.sent[a:getId()]==1 and v.sent[b:getId()]==1 and not v.sent.Battery)
 end)
end
test("missing primary battery still powers appliances from battery 3",function()
 local v,a,b=fixture("Base.87fordB700school",nil,.3)
 assert(P.consume(v,.1));near(b.item.charge,.2)
 b.item=nil;assert(not P.has(v,0));assert(P.capacity(v,0)==0);assert(not P.consume(v,0))
end)
test("depleted combined supply reaches zero and reports exhaustion",function()
 local v,a,b=fixture("Base.87fordB700school",.1,.2)
 assert(not P.consume(v,.4));near(a.item.charge,0);near(b.item.charge,0)
end)
test("partial transaction refunds only unused energy and syncs both cells once",function()
 local v,a,b=fixture("Base.87fordB700school",.2,.5)
 local token=assert(P.reserve(v,.4));near(a.item.charge,0);near(b.item.charge,.3)
 assert(next(v.sent)==nil)
 assert(P.settle(token,.1));near(a.item.charge,.1);near(b.item.charge,.5)
 assert(not P.settle(token,0))
 P.sync(v,a);assert(v.sent[a:getId()]==1 and v.sent[b:getId()]==1)
end)
test("low power rejects reservation without spending; rollback restores all cells",function()
 local v,a,b=fixture("Base.87fordB700school",.2,.5)
 assert(not P.reserve(v,.8));near(a.item.charge,.2);near(b.item.charge,.5)
 local before=P.snapshot(v);assert(P.reserve(v,.4))
 assert(P.restore(before,true));near(a.item.charge,.2);near(b.item.charge,.5)
end)
test("failure on second debit rolls back first debit and clears scoped routing",function()
 local v,a,b=fixture("Base.87fordB700school",.2,.5)
 local write=b.item.setUsedDelta
 b.item.setUsedDelta=function(self,x)if x<self.charge then error("injected battery write fault")end;write(self,x)end
 assert(not pcall(P.reserve,v,.4));near(a.item.charge,.2);near(b.item.charge,.5)
 assert(V.getAuxBatteryPart(v)==a);near(P.charge(v),.7)
end)
test("replaced item prevents stale refund or partial rollback",function()
 local v,a,b=fixture("Base.87fordB700school",.2,.5)
 local before=P.snapshot(v);local token=P.reserve(v,.4)
 b.item=battery(.9)
 assert(not P.settle(token,0));assert(not P.restore(before));near(a.item.charge,0);near(b.item.charge,.9)
end)
test("client can inspect but cannot debit refund restore or transmit",function()
 local v,a,b=fixture("Base.87fordB700school",.2,.5)
 local before=P.snapshot(v);local token=P.reserve(v,.4)
 client=true
 near(P.charge(v),.3);assert(not P.consume(v,.1));assert(not P.reserve(v,.1))
 assert(not P.settle(token,0));assert(not P.restore(before));P.sync(v)
 near(a.item.charge,0);near(b.item.charge,.3);assert(next(v.sent)==nil);client=false
end)
test("invalid costs are rejected and floating point settlement is tolerated",function()
 local v,a,b=fixture("Base.87fordB700school",.2,.5)
 for _,bad in ipairs({-1,0/0,math.huge,"1"})do assert(not P.consume(v,bad));assert(not P.reserve(v,bad));assert(not P.has(v,bad))end
 near(a.item.charge,.2);near(b.item.charge,.5)
 local token=P.reserve(v,.3);assert(P.settle(token,.1+.2));near(P.charge(v),.4)
end)
test("Bank SWAT StepVan and unrelated models retain original single-cell behavior",function()
 for _,name in ipairs({"Base.87fordF700bank","Base.87fordF700swat","Base.StepVan","Base.PickUpVan"})do
  local v,a,b=fixture(name,.2,.5)
  assert(not V.isManagedPart(b) and not V.isAllowedItem(b,b.item))
  near(P.charge(v),.2);assert(not P.consume(v,.3));near(a.item.charge,0);near(b.item.charge,.5)
 end
end)
test("battery 3 requires a native battery and preserves microwave removal guard",function()
 local v,a,b=fixture("Base.87fordB700school",.2,.5)
 assert(V.isManagedPart(b) and V.isAllowedItem(b,b.item))
 assert(not V.isAllowedItem(b,{kind="Moveable",getFullType=function()return "Base.CarBattery2"end}))
 local old=V.getInstalledCapabilityParts
 V.getInstalledCapabilityParts=function()return {{getModData=function()return {vlsMicrowaveActive=true}end}}end
 assert(not V.canUninstallManagedPart(b))
 V.getInstalledCapabilityParts=function()return {}end
 assert(V.canUninstallManagedPart(b));V.getInstalledCapabilityParts=old
end)
-- Run the unchanged common TV synchronizer with native 0..1 DeviceData semantics.
local function device()
 local d={DeviceName="TV",MediaType=1,IsTelevision=true,IsTwoWay=false,TransmitRange=0,MicRange=0,BaseVolumeRange=15,
 IsPortable=false,MinChannelRange=200,MaxChannelRange=100000,IsBatteryPowered=false,HasBattery=false,IsHighTier=true,
 UseDelta=0,Channel=200,DeviceVolume=.5,Power=0,IsTurnedOn=true,
 DevicePresets={getPresets=function()return {size=function()return 1 end}end}}
 local keys={};for key in pairs(d)do keys[#keys+1]=key end
 for _,key in ipairs(keys)do
  d["get"..key]=function(s)return s[key]end;d["set"..key]=function(s,x)s[key]=x end
 end
 d.setChannelRaw=d.setChannel;d.setDeviceVolumeRaw=d.setDeviceVolume;d.setTurnedOnRaw=d.setIsTurnedOn
 d.cloneDevicePresets=function(s,x)s.DevicePresets=x end
 d.setPower=function(s,x)s.Power=math.max(0,math.min(1,x))end
 return d
end
test("shared TV sync is stable with two full batteries and keeps full energy budget",function()
 local v,a,b=fixture("Base.87fordB700school",1,1)
 local source,target=device(),device();local marker={vlsTelevisionItemId=7}
 local television={kind="Radio",getFullType=function()return "Base.TvWideScreen"end,getID=function()return 7 end,getDeviceData=function()return source end}
 local slot={getInventoryItem=function()return television end}
 local companion={getDeviceData=function()return target end,getModData=function()return marker end}
 local universal,devicePart=V.isUniversalPart,V.getTelevisionDevicePart
 V.isUniversalPart=function(p)return p==slot end;V.getTelevisionDevicePart=function()return companion end
 local sends=0;v.transmitPartItem=function()sends=sends+1 end;v.transmitPartModData=v.transmitPartItem
 assert(V.syncTelevisionDevice(v,slot,true));assert(sends==2);near(target.Power,1)
 assert(not V.syncTelevisionDevice(v,slot,true));assert(sends==2);near(P.charge(v),2);near(P.capacity(v,.1),20)
 local get=target.getPower;target.getPower=function()error("device fault")end
 assert(not pcall(V.syncTelevisionDevice,v,slot,true));near(P.charge(v),2);target.getPower=get
 assert(P.consume(v,1.5));assert(V.syncTelevisionDevice(v,slot,true));near(target.Power,.5)
 assert(P.consume(v,.5));assert(V.syncTelevisionDevice(v,slot,true));assert(not target.IsTurnedOn)
 V.isUniversalPart=universal;V.getTelevisionDevicePart=devicePart
end)

-- Exercise the unchanged common water transaction against both real adapter
-- cells, including an exception after fluid mutation. Engine fluids are mocked.
local function fluid(amount,capacity)
 local f={amount=amount,capacity=capacity,locked=false}
 function f:getAmount()return self.amount end
 function f:getCapacity()return self.capacity end
 function f:setCapacity(v)self.capacity=v end
 function f:copy()return fluid(self.amount,self.capacity)end
 function f:copyFluidsFrom(o)self.amount=o.amount end
 function f:getSpecificFluidAmount()return self.amount end
 function f:createFluidSample()return {size=function()return 1 end,getFluid=function()return "Water"end,release=function()end}end
 function f:isInputLocked()return self.locked end
 function f:setInputLocked(x)self.locked=x end
 function f:canAddFluid()return true end
 function f:addFluid(_,x)self.amount=self.amount+x end
 function f:removeFluid(x)self.amount=self.amount-x end
 return f
end
Fluid={Water="Water"}
FluidContainer={CreateContainer=function()return fluid(0,0)end,DisposeContainer=function()end}
V.canAcceptNormalizedWater=function(f,x)return f:getAmount()+x<=f:getCapacity()end
V.isPureWaterFluid=function()return true end
getTimestampMs=function()return 1 end
Events.OnClientCommand={Add=function()end};Events.EveryOneMinute={Add=function()end}
dofile(root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/server/VLS_ApplianceServer.lua")
for _,failure in ipairs({false,true})do
 test("common water transaction with two batteries; rollback="..tostring(failure),function()
  local rate=V.getWaterPurificationCost(1)
  local v,a,b=fixture("Base.87fordB700school",rate,rate*5)
  local sourceFluid,targetFluid=fluid(10,20),fluid(0,20)
  local source={getFluidContainer=function()return sourceFluid end,getOwner=function()return {}end,sync=function()end}
  local target={getFluidContainer=function()return targetFluid end,getOwner=function()return {}end,sync=function()end}
  local tank={getId=function()return "VLSF700WaterTank4"end,getVehicle=function()return v end}
  local action={amount=4,source=source,target=target,sourceStartAmount=10,
   resolveEndpoints=function()return source,target,v,nil,tank end}
  local result=V.Server.runVehicleFluidAction(action,function(self)
   self.target:getFluidContainer():addFluid("Water",2)
   if failure then error("injected fluid commit failure")end
  end)
  assert(result==not failure)
  near(sourceFluid.amount,failure and 10 or 8);near(targetFluid.amount,failure and 0 or 2)
  near(a.item.charge,failure and rate or 0);near(b.item.charge,failure and rate*5 or rate*4)
  assert(v.sent[a:getId()]==1 and v.sent[b:getId()]==1 and not v.sent.Battery)
  assert(action.source==source and action.target==target and action.sourceStartAmount==10)
 end)
end
print("F700_POWER_PASS scenarios="..count)
