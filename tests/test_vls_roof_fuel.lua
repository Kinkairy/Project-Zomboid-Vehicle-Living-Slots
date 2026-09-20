local root,native=assert(arg[1]),assert(arg[2])
local roundtripPath=root.."/tests/net_action_roundtrip.lua"
local roundtripFile=io.open(roundtripPath)
if roundtripFile then roundtripFile:close()
else roundtripPath=root.."/../../tests/vehicle-living-slots/net_action_roundtrip.lua" end
local base=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
package.path=base.."shared/?.lua;"..native.."/shared/?.lua;"..package.path
VLS={};package.loaded.VLS_Config=VLS;package.loaded.VLS_RoofCargo=true
VLSRoofCargo={vehicleScripts={["Base.StepVan"]=true}}
package.loaded["TimedActions/ISBaseTimedAction"]=true
ISBaseTimedAction={derive=function(self,name)local c={Type=name};c.__index=c;setmetatable(c,{__index=self});return c end,
 new=function(self,character)return setmetatable({character=character},self)end}
Fluid={Petrol="petrol"}
isClient=function()return false end
ZomboidGlobals={EquippedOrWornEncumbranceMultiplier=0.3}
FluidContainer={CanTransfer=function(a,b)return a~=b end,Transfer=function(a,b,n)
 n=math.min(n,a.amount,b.capacity-b.amount);a.amount=a.amount-n;b.amount=b.amount+n;b.kind=a.kind end}
local square={getX=function()return 10 end,getY=function()return 10 end}
getCell=function()return {getGridSquare=function()return square end}end
Vector2={new=function()return {}end}
Metabolics={LightWork=1}
syncItemFields=function()end;sendItemStats=function()end
isServer=function()return true end
local F=require "VLS_RoofFuel"
local n=0
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local function near(a,b)assert(math.abs(a-b)<1e-7)end
local function fluid(amount,capacity,kind)
 local o={amount=amount,capacity=capacity,kind=kind or "petrol"}
 function o:getAmount()return self.amount end;function o:getCapacity()return self.capacity end
 function o:getFreeCapacity()return self.capacity-self.amount end;function o:isEmpty()return self.amount<=0 end
 function o:contains(k)return self.kind==k end;function o:canPlayerEmpty()return true end
 function o:isInputLocked()return false end
 function o:addFluid(k,v)self.amount=self.amount+v;self.kind=k end
 function o:adjustAmount(v)assert(v>=0 and v<=self.capacity);self.amount=v end
 return o
end
local function item(id,f)
 return {getID=function()return id end,getFullType=function()return "Base.PetrolCan"end,
 getFluidContainer=function()return f end,syncItemFields=function()end}
end
local function fixture()
 local fuel=fluid(8.75,10);local carried=fluid(0,3);local roof=item(10,fuel);local portable=item(20,carried)
 local tank={amount=52.5,capacity=55,getInventoryItem=function()return {}end}
 function tank:getContainerContentAmount()return self.amount end;function tank:getContainerCapacity()return self.capacity end
 function tank:setContainerContentAmount(v)self.amount=math.min(v,self.capacity)end
 local part={item=roof,getId=function()return "VLSRoofPetrol1"end,getArea=function()return "VLSRoofGeneratorService"end}
 function part:getInventoryItem()return self.item end
 local v={stopped=true,area=true,name="Base.StepVan"}
 function v:getAreaFacingPosition(area)self.lastArea=area;return {getX=function()return 10.5 end,getY=function()return 10.75 end}end
 function v:getAreaCenter()return {getX=function()return 10 end,getY=function()return 10 end}end
 function v:getScript()return {getFullName=function()return self.name end}end
 function v:getPartById(id)return id=="GasTank" and tank or id=="VLSRoofPetrol1" and part or nil end
 function v:isStopped()return self.stopped end;function v:isInArea()return self.area end
 function v:getZ()return 0 end;function v:transmitPartModData()end;function v:transmitPartItem()end
 local pl={distance=2,z=0,carried=portable}
 function pl:faceLocation()end
 function pl:faceLocationF(x,y)self.facing={x,y}end
 function pl:shouldBeTurning()return false end
 function pl:setMetabolicTarget()end
 function pl:isDead()return false end;function pl:getVehicle()return self.vehicle end
 function pl:getZ()return self.z end;function pl:DistToProper()return self.distance end
 function pl:isTimedActionInstant()return false end
 function pl:getFreeInventoryCapacity()return 100 end
 function pl:getInventory()return {contains=function(_,it)return it==self.carried end}end
 function pl:hasFullInventory()return false end
 return pl,v,part,fuel,carried,tank,portable
end
local function action()
 local pl,v,p,f,c,t,i=fixture()
 return VLSRoofFuelAction:new(pl,v,i,p:getInventoryItem():getID(),-1,-1),pl,v,p,f,c,t,i
end
test("native class owns pump animation sound duration progress and stop",function()
 local a=action()
 eq(a.maxTime,150);eq(a.stop,ISTakeFuel.stop)
 eq(a.perform,ISTakeFuel.perform)
 eq(a.animEvent,ISTakeFuel.animEvent);eq(a.getDuration,ISTakeFuel.getDuration)
end)
test("original constructor is retained for actual pumps",function()
 local a,pl=action();local pump={getSquare=function()return {}end,getPipedFuelAmount=function()return 20 end}
 local result=ISTakeFuel:new(pl,pump,a.petrolCan);eq(result.Type,"ISTakeFuel");eq(result.fuelStation,pump)
end)
test("original constructor routes only roof endpoints to serializable subclass",function()
 local a,pl,v=action();local result=ISTakeFuel:new(pl,F.capture(v),a.petrolCan)
 eq(result.Type,"VLSRoofFuelAction");eq(result.vehicle,v);eq(result.roofId1,10)
end)
test("native progress and fractional completion conserve petrol",function()
 local a,pl,v,p,f,c=action();c.capacity=3.25;a:refresh()
 a:updateUse(.5);near(c.amount,1);near(f.amount,7.75)
 eq(a:complete(),true);near(c.amount,3.25);near(f.amount,5.5)
 eq(a:complete(),false);near(f.amount,5.5)
end)
test("cancel after native progress preserves only transferred litres",function()
 local a,pl,v,p,f,c=action();a:updateUse(.5)
 near(c.amount,1);near(f.amount,7.75)
end)
test("fractional source remainder is depleted without fuel creation",function()
 local a,pl,v,p,f,c=action();f.amount=.25;a:refresh()
 a:updateUse(1);eq(a:complete(),true);near(c.amount,.25);near(f.amount,0)
end)
test("green JerryCan retains native 20 litre capacity",function()
 local a,pl,v,p,f,c=action();p.item.getFullType=function()return "Base.JerryCan"end
 f.capacity=20;f.amount=19.75;eq(a:complete(),true);near(c.amount,3);near(f.amount,16.75)
end)
test("native inventory weight limit is applied by original constructor",function()
 local a,pl,v,p,f,c=action();pl.getFreeInventoryCapacity=function()return .3 end;a:refresh()
 near(a.amount,1);eq(a:complete(),true);near(c.amount,1);near(f.amount,7.75)
end)
for _,change in ipairs({
 {"moving",function(a,pl,v)v.stopped=false end},
 {"away from service area",function(a,pl,v)v.area=false end},
 {"too far",function(a,pl)pl.distance=4 end},
 {"other floor",function(a,pl)pl.z=1 end},
 {"inside vehicle",function(a,pl,v)pl.vehicle=v end},
 {"unsupported vehicle",function(a,pl,v)v.name="Base.Other"end},
 {"replaced source",function(a,pl,v,p,f)p.item=item(11,f)end},
 {"removed portable",function(a,pl)pl.carried=nil end},
 {"non-petrol source",function(a,pl,v,p,f)f.kind="water"end},
 {"full portable",function(a,pl,v,p,f,c)c.amount=c.capacity end},
})do test(change[1].." rejects without transfer",function()
 local a,pl,v,p,f,c=action();change[2](a,pl,v,p,f,c)
 local total=f.amount+c.amount;eq(a:complete(),false);near(total,f.amount+c.amount)
end)end
test("concurrent source depletion limits native completion",function()
 local a,pl,v,p,f,c=action();f.amount=.4
 eq(a:complete(),true);near(c.amount,.4);near(f.amount,0)
end)
test("concurrent target fill cannot overfill portable",function()
 local a,pl,v,p,f,c=action();c.amount=2.75
 eq(a:complete(),true);near(c.amount,3);near(f.amount,8.5)
end)
test("multiple source tanks behave as one finite pump",function()
 local a,pl,v,p,f,c=action();f.amount=1
 local second=fluid(2.25,20);local p2={getInventoryItem=function()return item(30,second)end}
 local get=v.getPartById
 v.getPartById=function(self,id)if id=="VLSRoofPetrol2"then return p2 end;return get(self,id)end
 a=VLSRoofFuelAction:new(pl,v,a.petrolCan,10,30,-1)
 eq(a:complete(),true);near(c.amount,3);near(f.amount,0);near(second.amount,.25)
end)
test("native server animation events advance petrol",function()
 local a,pl,v,p,f,c=action();local event
 emulateAnimEvent=function(net,period,name)event=name;eq(period,100)end
 a.netAction={getProgress=function()return .5 end}
 a:serverStart();eq(event,"takeFuel");a:animEvent(event)
 near(c.amount,1);near(f.amount,7.75)
end)
local roundTrip=dofile(roundtripPath)
test("network reconstruction preserves source identities and native petrol item",function()
 local a,pl,v,p,f,c=action()
 local server=roundTrip(VLSRoofFuelAction,base.."shared/VLS_RoofFuel.lua",a)
 eq(server.roofId1,10);eq(server.petrolCan,a.petrolCan);eq(server:isValid(),true)
 eq(server:complete(),true);near(c.amount,3);near(f.amount,5.75)
end)
test("network reconstruction cannot adopt replacement source",function()
 local a,pl,v,p,f,c=action();p.item=item(11,f)
 local server=roundTrip(VLSRoofFuelAction,base.."shared/VLS_RoofFuel.lua",a)
 eq(server:isValid(),false);eq(server:complete(),false);near(c.amount,0)
end)
test("removed network portable reference cancels without calling Java contains with nil",function()
 local a,pl,v=action()
 pl.getInventory=function()return {contains=function(_,item)assert(item~=nil);return false end}end
 local missing=VLSRoofFuelAction:new(pl,v,nil,10,-1,-1)
 eq(missing:isValid(),false);eq(missing:complete(),false)
end)
test("fill-all queued before earlier containers finish refreshes remaining fuel",function()
 local first,pl,v,p,f,c=action()
 local c2,c3=fluid(0,3),fluid(0,4)
 local i2,i3=item(21,c2),item(22,c3)
 pl.getInventory=function()return {contains=function()return true end}end
 local second=VLSRoofFuelAction:new(pl,v,i2,10,-1,-1)
 local third=VLSRoofFuelAction:new(pl,v,i3,10,-1,-1)
 first:refresh();eq(first:complete(),true)
 second:refresh();eq(second:complete(),true)
 third:refresh();eq(third:complete(),true)
 near(c.amount,3);near(c2.amount,3);near(c3.amount,2.75);near(f.amount,0)
end)
test("petrol shortcut disables stale native actions without removing installed cans",function()
 local saved=SandboxVars;SandboxVars=nil;eq(F.enabled(),true)
 local a,pl,v,p,f,c=action()
 SandboxVars={VehicleLivingSlots={EnableRoofPetrolShortcut=false}}
 eq(a:isValid(),false);eq(a:complete(),false);near(c.amount,0);near(f.amount,8.75)
 eq(F.capture(v):getPipedFuelAmount(),0);eq(F.getPart(v,"VLSRoofPetrol1"),p)
 SandboxVars.VehicleLivingSlots.EnableRoofPetrolShortcut=true
 eq(a:complete(),true);near(c.amount,3);near(f.amount,5.75)
 SandboxVars=saved
end)
test("native facing uses the same generator service area",function()
 local a,pl,v=action();eq(a:waitToStart(),false);eq(v.lastArea,"VLSRoofGeneratorService")
 near(pl.facing[1],10.5);near(pl.facing[2],10.75)
end)
test("repeated empty-source attempts never refill or create fuel",function()
 local a,pl,v,p,f,c=action();f.amount=.25;a:refresh();eq(a:complete(),true)
 for i=1,20 do local b=VLSRoofFuelAction:new(pl,v,a.petrolCan,10,-1,-1);eq(b:complete(),false) end
 near(f.amount,0);near(c.amount,.25)
end)
for _,case in ipairs({{.9995,10},{10,.9995},{.0005,10},{10,1.9995}})do
 test("finite source and portable capacity survive native progress rounding",function()
  local a,pl,v,p,f,c=action();f.amount=case[1];c.capacity=case[2];a:refresh()
  a:updateUse(1);a:complete();near(f.amount+c.amount,case[1]);near(c.amount,math.min(case[1],case[2]))
 end)
end
print("RESULT roof fuel tests="..n.." failures=0")
