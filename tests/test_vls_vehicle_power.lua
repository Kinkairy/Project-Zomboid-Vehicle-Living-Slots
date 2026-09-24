local root=assert(arg[1])
local path=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(path.."shared/VLS_Config.lua")
local P=V.VehiclePower
local client=false
isClient=function()return client end
local n=0
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
local function near(a,b)assert(math.abs(a-b)<1e-9,tostring(a).." != "..tostring(b))end
local function fixture(charge)
 local item={charge=charge,getCurrentUsesFloat=function(self)return self.charge end,
  setUsedDelta=function(self,v)self.charge=v end}
 local part={item=item,getInventoryItem=function(self)return self.item end}
 local v={sent=0,part=part,transmitPartUsedDelta=function(self)self.sent=self.sent+1 end}
 V.getAuxBatteryPart=function(vehicle)return vehicle.part end
 return v,item,part
end
test("all devices share the same display conversion and configured rates",function()
 SandboxVars={VehicleLivingSlots={}}
 near(V.getSmallApplianceDrainPerUse()*10,V.getMicrowaveDrainPerMinute()*5)
 near(V.getLaundryDrainPerMinute("laundryWasher"),V.getMicrowaveDrainPerMinute())
 near(V.getLaundryDrainPerMinute("laundryDryer"),V.getMicrowaveDrainPerMinute())
 SandboxVars.VehicleLivingSlots.ComboWashPowerConsumption=0.8
 near(V.getLaundryDrainPerMinute("laundryWasher"),0.0008)
 near(V.getLaundryDrainPerMinute("laundryDryer"),0.0008)
end)
test("reserve rejects low charge without spending; partial capacity is shared",function()
 local v,i=fixture(.1);assert(not P.reserve(v,.2));near(i.charge,.1)
 near(P.capacity(v,.2),.5);assert(not P.has(v,.2));assert(v.sent==0)
end)
test("settlement charges accepted units once and defers one final sync",function()
 local v,i=fixture(1);local token=assert(P.reserve(v,.4));near(i.charge,.6);assert(v.sent==0)
 assert(P.settle(token,.1));near(i.charge,.9)
 assert(not P.settle(token,0));near(i.charge,.9)
 P.sync(v);assert(v.sent==1)
end)
test("failed resource transaction restores the exact original battery",function()
 local v,i=fixture(.7);local before=P.snapshot(v);assert(P.reserve(v,.3))
 assert(P.restore(before,true));near(i.charge,.7);assert(v.sent==0)
 P.sync(v);assert(v.sent==1)
end)
test("replacement battery cannot receive another battery's refund or rollback",function()
 local v,i,part=fixture(1);local token=P.reserve(v,.2);local before=P.snapshot(v)
 local other={charge=.4,getCurrentUsesFloat=function(self)return self.charge end,setUsedDelta=function(self,x)self.charge=x end}
 part.item=other;assert(not P.settle(token,0));assert(not P.restore(before));near(other.charge,.4)
end)
test("client can inspect power but cannot debit, refund or rollback",function()
 local v,i=fixture(1);local before=P.snapshot(v);local token=P.reserve(v,.2)
 client=true;assert(P.has(v,.1));near(P.capacity(v,.2),4)
 assert(not P.consume(v,.1));assert(not P.reserve(v,.1));assert(not P.settle(token,0));assert(not P.restore(before))
 near(i.charge,.8);assert(v.sent==0);client=false
end)
test("missing batteries and non-finite requests never grant power",function()
 local v,i=fixture(1)
 for _,bad in ipairs({-1,0/0,math.huge,"1"})do
  assert(not P.has(v,bad));assert(not P.consume(v,bad));assert(not P.reserve(v,bad));near(i.charge,1)
 end
 v.part=nil;assert(not P.has(v,0));assert(P.capacity(v,0)==0);assert(not P.consume(v,0))
end)
test("floating point accepted volume does not reject an otherwise exact reservation",function()
 local v,i=fixture(1);local token=assert(P.reserve(v,0.3))
 assert(P.settle(token,0.1+0.2));near(i.charge,0.7)
end)
-- Exercise the actual server dispatcher: several devices share one battery,
-- and a repeated per-part callback must not bill the microwave minute twice.
local eventHandlers={}
local function event(name)return {Add=function(fn)eventHandlers[name]=fn end}end
Events={OnClientCommand=event("command"),EveryOneMinute=event("minute")}
isServer=function()return true end
getTimestampMs=function()return 1 end
local hours=10
getGameTime=function()return {getWorldAgeHours=function()return hours end}end
getOnlinePlayers=function()return {size=function()return 0 end}end
local v,battery=fixture(1)
v.getId=function()return 7 end;v.getSquare=function()return {} end
v.transmitPartModData=function()end;v.transmitPartItem=function()end
local ids={"Microwave","Fridge","TV","Combo"};local parts={}
for i,cap in ipairs({"cooking","cooling","television","laundryCombo"})do
 local data={};local item={cap=cap,getID=function()return i end,getCondition=function()return 100 end}
 parts[ids[i]]={getId=function()return ids[i] end,getInventoryItem=function()return item end,
  getVehicle=function()return v end,getModData=function()return data end,
  getItemContainer=function()return nil end,getCondition=function()return 100 end}
end
v.getPartById=function(_,id)return parts[id]end
local player={getVehicle=function()return v end}
getVehicleById=function(id)return id==7 and v or nil end
V.isSupportedVehicle=function(vehicle)return vehicle==v end
V.getVehicleProfile=function()return {universalParts=ids}end
V.getInstalledPart=function(vehicle,id)return vehicle:getPartById(id)end
V.getEquipmentCapability=function(item)return item and item.cap end
V.getTelevisionDeviceData=function()return {getIsTurnedOn=function()return true end,setIsTurnedOn=function()end}end
V.getFreezerPartForUniversal=function()return nil end
V.isUniversalPart=function()return true end
V.refreshApplianceEnvironment=function()end
V.ensureUniversalContainerProfile=function()end
package.loaded.VLS_Config=V
V.installGenericCraftSurfaceActionHooks=nil
dofile(path.."server/VLS_ApplianceServer.lua")
test("four active devices debit one shared battery once per running unit",function()
 assert(V.Server.toggleMicrowave(player,{vehicle=7,part="Microwave",item=1,active=true,timer=300,temperature=90}))
 assert(V.Server.setLaundryMode(player,{vehicle=7,part="Combo",item=4,mode="dryer"}))
 assert(V.Server.toggleLaundry(player,{vehicle=7,part="Combo",item=4,active=true}))
 hours=hours+1/60;eventHandlers.minute()
 local expected=1-V.getMicrowaveDrainPerMinute()-V.getFridgeDrainPerMinute()
  -V.getTelevisionDrainPerMinute()-V.getLaundryDrainPerMinute("laundryDryer")
 near(battery.charge,expected)
 V.Server.updateAppliance(v,parts.Microwave,1,true,true)
 near(battery.charge,expected)
end)
test("microwave exhausts only available shared power and stops without a second bill",function()
 ids={"Microwave"};battery.charge=.0006
 local before=v.sent;hours=hours+2/60;eventHandlers.minute()
 near(battery.charge,0);assert(parts.Microwave:getModData().vlsMicrowaveActive==false)
 V.Server.updateAppliance(v,parts.Microwave,1,true,true)
 assert(v.sent==before+1)
end)
print("RESULT shared vehicle power tests="..n.." failures=0")
