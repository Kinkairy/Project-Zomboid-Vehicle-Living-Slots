local root=assert(arg[1])
local fridgeType=arg[3] or "Base.Mov_FridgeMini"
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(media.."shared/VLS_Config.lua")
package.loaded.VLS_Config=V
local n=0
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local function near(a,b)assert(math.abs(a-b)<0.000001,tostring(a).." != "..tostring(b))end
local food={canBeFrozen=function()return true end}
for _,case in ipairs({
 {"native four-hour freeze",0,0,4,true,0,100},
 {"native three-hour fridge thaw",1,100,3,false,1.025,0},
 {"native fully frozen zero aging",2,100,1,true,2,100},
 {"native one-hour fridge aging",0,0,1,false,1/120,0},
 {"partial freezing",0,0,1,true,1/120,25}})do
 test(case[1],function()
  local age,freezing=V.getPoweredFoodProgress(food,case[2],case[3],case[4],case[5]);near(age,case[6]);near(freezing,case[7])
 end)
end
test("repeated client projection cannot compound baseline",function()
 local age,freezing=V.getPoweredFoodProgress(food,2,20,1/60,true)
 for i=1,30 do local a,f=V.getPoweredFoodProgress(food,2,20,1/60,true);eq(a,age);eq(f,freezing)end
end)
local function battery(charge)
 local i={charge=charge,writes=0,getCurrentUsesFloat=function(self)return self.charge end,
 setUsedDelta=function(self,c)self.charge=c;self.writes=self.writes+1 end}
 local p={getInventoryItem=function()return i end}
 local v={sent=0,transmitPartUsedDelta=function(self)self.sent=self.sent+1 end}
 V.getAuxBatteryPart=function()return p end
 return i,v
end
test("empty battery sends no redundant mutation",function()
 local i,v=battery(0);eq(V.consumeAuxBattery(v,0.1),false);eq(i.writes,0);eq(v.sent,0)
end)
test("partial battery drains once to zero",function()
 local i,v=battery(0.1);eq(V.consumeAuxBattery(v,0.2),false);eq(i.charge,0);eq(v.sent,1)
 eq(V.consumeAuxBattery(v,0.2),false);eq(v.sent,1)
end)
test("exact charge and free drain preserve native values",function()
 local i,v=battery(0.2);eq(V.consumeAuxBattery(v,0),true);eq(v.sent,0)
 eq(V.consumeAuxBattery(v,0.2),true);eq(i.charge,0);eq(v.sent,1)
end)
for _,value in ipairs({-1,0/0,math.huge,"2"})do
 test("invalid drain rejected",function()local i,v=battery(1);eq(V.consumeAuxBattery(v,value),false);eq(i.charge,1);eq(v.sent,0)end)
end
for _,capacity in ipairs({55,65,75,27.5,32.5,37.5})do
 test("water uses native effective gas tank capacity "..capacity,function()
  local f={amount=10}
  function f:setCapacity(c)self.capacity=c end
  function f:getAmount()return self.amount end
  function f:adjustAmount(c)self.amount=c end
  local i={getFullType=function()return "Base.NormalGasTank2"end,getFluidContainer=function()return f end}
  local v={getScriptName=function()return "Base.StepVan"end}
  local p={getVehicle=function()return v end,getId=function()return V.LARGE_VAN_WATER_TANK_PART_ID end,
   getInventoryItem=function()return i end,getContainerCapacity=function()return capacity end,
   setContainerContentAmount=function(_,c)eq(c,10)end}
  local actual=V.syncVehicleWaterTank(v,p);eq(actual,i);eq(f.capacity,capacity)
 end)
end
package.loaded["Vehicles/VehicleDistributions"]=true
local native={TruckBed={items={"stock"}}}
local selection={Normal=native,Specific={native},chance=20}
VehicleDistributions={EmptySeat={items={}},[1]={StepVan=selection,CarNormal=selection}}
dofile(media.."server/VLS_VehicleDistributions.lua")
test("distribution isolation retains native loot and unrelated aliases",function()
 local patched=VehicleDistributions[1].StepVan
 eq(VehicleDistributions[1].CarNormal,selection);eq(native.SeatBed,nil);eq(selection.Normal,native)
 eq(patched.chance,20);eq(patched.Normal.TruckBed,native.TruckBed)
 eq(patched.Normal.SeatBed,VehicleDistributions.EmptySeat)
 eq(patched.Normal[V.WEAPON_PART_ID],VehicleDistributions.EmptySeat)
 eq(patched.Specific[1].SeatBed,VehicleDistributions.EmptySeat)
end)
-- A malformed cooling request must be rejected before Java lookup.
isClient=function()return false end
getTimestampMs=function()return 1000 end
local minute
Events={OnClientCommand={Add=function()end},EveryOneMinute={Add=function(f)minute=f end}}
local lookups=0
getVehicleById=function()lookups=lookups+1;error("unexpected Java lookup")end
dofile(media.."server/VLS_ApplianceServer.lua")
for _,args in ipairs({false,{}, {vehicle="42",part="SeatBed"}, {vehicle=0/0,part="SeatBed"},
 {vehicle=math.huge,part="SeatBed"}, {vehicle=42.5,part="SeatBed"}, {vehicle=42,part={}}, {vehicle=42,part=""}})do
 test("malformed cooling packet rejected before lookup",function()
  eq(V.Server.requestCoolingSnapshot({},args),false);eq(lookups,0)
 end)
end
test("empty fridge leaves active work; charged fridge can register again",function()
 local i=battery(0)
 local fridge={getFullType=function()return fridgeType end}
 local part={getInventoryItem=function()return fridge end}
 local v={getScriptName=function()return "Base.StepVan"end,getId=function()return 42 end,
  getPartById=function(_,id)return id=="SeatBed" and part end}
 function part:getVehicle()return v end
 function part:getId()return "SeatBed"end
 getGameTime=function()return {getWorldAgeHours=function()return 1 end}end
 lookups=0;getVehicleById=function()lookups=lookups+1;return nil end
 V.Server.trackVehicle(v);minute();eq(lookups,0)
 i.charge=1;V.Server.trackVehicle(v);minute();eq(lookups,1)
end)
test("authoritative freezer mirrors native progress and egg viability",function()
 local charge,vehicle=battery(1);local hours=0
 isServer=function()return false end
 instanceof=function(item,kind)return kind=="Food" and item.food==true end
 sendItemStats=function()end
 local function list(items)return {size=function()return #items end,get=function(_,i)return items[i+1]end}end
 local function container(items)return {getItems=function()return list(items)end}end
 local egg={food=true,age=0,freezing=0,heat=0.1,fertilized=true,getID=function()return 1234 end,canBeFrozen=function()return true end}
 function egg:getAge()return self.age end;function egg:setAge(v)self.age=v end
 function egg:getFreezingTime()return self.freezing end;function egg:setFreezingTime(v)self.freezing=v end
 function egg:getHeat()return self.heat end;function egg:setHeat(v)self.heat=v end
 function egg:setLastAged(v)self.last=v end;function egg:setFertilized(v)self.fertilized=v end
 local cabinet=container({});local freezer=container({egg})
 local parts={}
 parts.SeatBed={getId=function()return "SeatBed"end,getVehicle=function()return vehicle end,
 getInventoryItem=function()return {getFullType=function()return fridgeType end}end,
 getItemContainer=function()return cabinet end,getModData=function()return {}end}
 parts.VLSUniversalFreezer={getId=function()return "VLSUniversalFreezer"end,getItemContainer=function()return freezer end}
 function vehicle:getPartById(id)return parts[id]end
 function vehicle:getScriptName()return "Base.StepVan"end
 function vehicle:getId()return 88 end
 function vehicle:getSquare()return {}end
 getVehicleById=function()return vehicle end
 getGameTime=function()return {getWorldAgeHours=function()return hours end}end
 local refresh=V.refreshApplianceEnvironment;V.refreshApplianceEnvironment=function()end
 V.Server.trackVehicle(vehicle);minute();hours=1;minute()
 V.refreshApplianceEnvironment=refresh
 near(egg.freezing,25);near(egg.age,1/120);eq(egg.fertilized,false);eq(egg.last,1)
end)
-- Unsupported vehicles must not even be scanned by the mechanics adapter.
package.loaded.VLS_ComponentDamage=true;package.loaded.VLS_InstallGuard=true
package.loaded["TimedActions/ISFixVehiclePartAction"]=true
isClient=function()return false end
local scans,rebases,nativeCalls=0,0,0
V.Damage={supportsVehicle=function(v)return v.supported end,IsSource=function()return true end,
 Update=function()scans=scans+1 end,RebaseSource=function()rebases=rebases+1 end}
local function class()return {complete=function()nativeCalls=nativeCalls+1;return true end}end
ISInstallVehiclePart=class();ISUninstallVehiclePart=class();ISFixVehiclePartAction=class()
dofile(media.."shared/VLS_DamageMechanics.lua")
for _,supported in ipairs({false,true})do
 test("mechanics scope supported="..tostring(supported),function()
  scans=0;rebases=0;nativeCalls=0
  local part={getVehicle=function()return {supported=supported}end}
  eq(ISInstallVehiclePart.complete({part=part}),true)
  eq(scans,supported and 1 or 0);eq(rebases,scans);eq(nativeCalls,1)
 end)
end
print("RESULT boundaries tests="..n.." failures=0")
