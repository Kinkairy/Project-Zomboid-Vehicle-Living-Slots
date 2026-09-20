local root,native=assert(arg[1]),assert(arg[2])
local roundtripPath=root.."/tests/net_action_roundtrip.lua"
local roundtripFile=io.open(roundtripPath)
if roundtripFile then roundtripFile:close()
else roundtripPath=root.."/../../tests/vehicle-living-slots/net_action_roundtrip.lua" end
local base=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
package.path=base.."shared/?.lua;"..base.."server/?.lua;"..native.."/shared/?.lua;"..package.path
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["TimedActions/ISInventoryTransferUtil"]=true
local V=require "VLS_Config"
package.loaded.VLS_RoofCargo=true
VLSRoofCargo={vehicleScripts={["Base.StepVan"]=true},allowed={VLSRoofGenerator={["Base.Generator"]=true}}}
package.loaded["TimedActions/ISBaseTimedAction"]=true
ISBaseTimedAction={derive=function(self,name)local c={};c.__index=c;setmetatable(c,{__index=self});return c end,
 new=function(self,character)return setmetatable({character=character},self)end}
isClient=function()return false end;isServer=function()return true end
local hours=0;local stamp=10000;local random=1
getGameTime=function()return {getWorldAgeHours=function()return hours end}end
getTimestampMs=function()return stamp end
ZombRand=function(a,b)return b and a or math.min(random,a-1)end
SandboxVars={GeneratorFuelConsumption=1}
playServerSound=function()end
getSprite=function()return nil end
addSound=function()end
IsoFireManager={StartFire=function()error("unexpected fire")end,explode=function()error("unexpected explosion")end}
V.refreshApplianceEnvironment=function()end
local function list(a)return {size=function()return #a end,get=function(_,i)return a[i+1]end}end
local square={isFree=function()return true end,objects={},getX=function()return 10 end,getY=function()return 10 end,getZ=function()return 0 end}
function square:getSpecialObjects()return list(self.objects)end
local vehicles={}
getCell=function()return {getGridSquare=function(_,x,y,z)if x==10 and y==10 and z==0 then return square end end,
 getVehicles=function()
  -- Match actual B42.20 java.util.Set: deliberately no indexed get().
  return {size=function()return #vehicles end,iterator=function()
   local i=0;return {hasNext=function()return i<#vehicles end,next=function()i=i+1;return vehicles[i]end}
  end}
 end}end
instanceof=function(o,kind)return kind=="IsoGenerator" and o.generator==true or kind=="DrainableComboItem" and o.charge~=nil end
IsoGenerator={new=function(item,cell,sq)
 local o={generator=true,md={},fuel=item:getModData().fuel or 0,condition=item:getCondition(),active=false,connected=false,index=0,square=sq,stops=0}
 function o:setDoRender(value)self.render=value end
 function o:getModData()return self.md end;function o:getFuel()return self.fuel end
 function o:getFuelPercentage()return self.fuel*10 end
 function o:getMaxFuel()return 10 end;function o:failToStart()self.failed=true end
 function o:setFuel(v)self.fuel=math.max(0,math.min(10,v))end
 function o:getCondition()return self.condition end;function o:setCondition(v)self.condition=v end
 function o:isActivated()return self.active end
 function o:setActivated(v)self.active=v;if not v then self.stops=self.stops+1 end end
 function o:isConnected()return self.connected end;function o:setConnected(v)self.connected=v end
 function o:getObjectIndex()return self.index end
 function o:getSquare()return self.square end
 function o:sync()end;function o:transmitModData()end
 function o:remove()self.index=-1;for i=#sq.objects,1,-1 do if sq.objects[i]==self then table.remove(sq.objects,i)end end end
 table.insert(sq.objects,o);return o
end}
local G=require "VLS_Generator"
require "VLS_GeneratorOwnership"
local callbacks={}
Events={OnTick={Add=function(f)callbacks.tick=f end,Remove=function()end},
 LoadGridsquare={Add=function(f)callbacks.load=f end,Remove=function()end}}
require "VLS_GeneratorServer"
local n=0
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local function near(a,b)assert(math.abs(a-b)<1e-6,tostring(a).." != "..tostring(b))end
local function item(id,kind,fluid)
 local o={id=id,kind=kind,condition=100,md={fuel=5},fluid=fluid}
 function o:getID()return self.id end;function o:getFullType()return self.kind end
 function o:getModData()return self.md end;function o:getCondition()return self.condition end
 function o:setCondition(c)self.condition=c end;function o:syncItemFields()end
 function o:getFluidContainer()return self.fluid end
 function o:getScriptItem()return {getConditionLowerChance=function()return 30 end,getWorldObjectSprite=function()return "generator"end,
 getSoundRadius=function()return 20 end,getSoundVolume=function()return 1 end}end
 return o
end
local function fixture()
 hours=0;stamp=stamp+10000;random=1;SandboxVars.GeneratorFuelConsumption=1
 G.active={};G.grounded={};G.pending=nil;square.objects={}
 local gen=item(1,"Base.Generator")
 local battery={charge=.8,getFullType=function()return "Base.CarBattery2"end,getCurrentUsesFloat=function(self)return self.charge end,setUsedDelta=function(self,n)self.charge=n end}
 local function part(id,it)
  return {id=id,item=it,getId=function(self)return self.id end,getInventoryItem=function(self)return self.item end,
   getArea=function()return "TruckBed"end,setCondition=function(self,n)self.condition=n end}
 end
 local gp=part(G.PART,gen);local bp=part(V.AUX_BATTERY_PART_ID,battery)
 local v={x=10,y=10,z=0,stopped=true,parts={[G.PART]=gp,[V.AUX_BATTERY_PART_ID]=bp},square=square,name="Base.StepVan"}
 function v:getAreaCenter()return {getX=function()return 10 end,getY=function()return 10 end}end
 function v:getScript()return {getFullName=function()return self.name end}end
 function v:getScriptName()return self.name end
 function v:getPartById(id)return self.parts[id]end
 function v:isStopped()return self.stopped end
 function v:getX()return self.x end;function v:getY()return self.y end;function v:getZ()return self.z end
 function v:getSquare()return self.square end;function v:getId()return 1 end
 function v:isInArea()return true end
 function v:transmitPartItem()end;function v:transmitPartCondition()end;function v:transmitPartUsedDelta()end
 vehicles={v}
 function gp:getVehicle()return v end;function bp:getVehicle()return v end
 local pl={known=true,distance=2,inventory={}}
 function pl:getInventory()return {getItemWithIDRecursiv=function(_,id)return self.inventory[id]end}end
 function pl:getKnownRecipes()return {contains=function()return self.known end}end
 function pl:getVehicle()return nil end;function pl:isDead()return false end
 function pl:getZ()return 0 end;function pl:DistToProper()return self.distance end
 function pl:isTimedActionInstant()return false end;function pl:getSquare()return square end
 local state=G.state(gen)
 return v,gen,state,battery,pl,gp
end
Fluid={Petrol="petrol"}
local function can(pl,amount)
    local it=item(20,"Base.PetrolCan",{
        amount=amount,getAmount=function(self)return self.amount end,
        adjustAmount=function(self,n)self.amount=n end})
    pl.inventory[20]=it
    return it
end
local function ground()
    local v,it,s,b,pl,gp=fixture()
    G.active[v]=true;G.update(v)
    return v,it,s,b,pl,G.object(v),gp
end
local function start(pl,obj)
    assert(ISPlugGenerator:new(pl,obj,true):complete())
    assert(ISActivateGenerator:new(pl,obj,true):complete())
end
test("parked installed generator materializes off and unconnected",function()
 local v,it,s,b,pl,obj=ground()
 eq(#square.objects,1);eq(obj:isConnected(),false);eq(obj:isActivated(),false)
 G.update(v);eq(#square.objects,1);eq(G.fuelHandle,nil);eq(VLSGeneratorAction,nil)
end)
test("old rear projection migrates once while preserving native fuel condition and power",function()
 local v,it,s,b,pl,obj=ground();start(pl,obj)
 obj:setFuel(2.375);obj:setCondition(73);s.dock.serviceArea=nil
 G.update(v);local replacement=G.object(v)
 assert(replacement and replacement~=obj);eq(obj:getObjectIndex(),-1)
 eq(#square.objects,1);eq(replacement.render,false)
 near(replacement:getFuel(),2.375);eq(replacement:getCondition(),73)
 eq(replacement:isConnected(),true);eq(replacement:isActivated(),true)
 G.update(v);eq(G.object(v),replacement)
end)
test("native connect start stop unplug retain one native object",function()
 local v,it,s,b,pl,obj=ground();start(pl,obj);eq(obj:isActivated(),true)
 eq(ISActivateGenerator:new(pl,obj,false):complete(),true);eq(obj:isActivated(),false)
 eq(ISPlugGenerator:new(pl,obj,false):complete(),true);eq(obj:isConnected(),false)
 G.update(v);eq(G.object(v),obj);eq(#square.objects,1)
end)
test("native refuel works before connection and persists litres immediately",function()
 local v,it,s,b,pl,obj=ground();obj:setFuel(9.25);local petrol=can(pl,3)
 eq(ISAddFuel:new(pl,obj,petrol):complete(),true);near(obj:getFuel(),10)
 near(G.fuel(it),10);near(petrol.fluid.amount,2.25)
end)
test("native refuel works after connection",function()
 local v,it,s,b,pl,obj=ground();ISPlugGenerator:new(pl,obj,true):complete()
 local petrol=can(pl,3);eq(ISAddFuel:new(pl,obj,petrol):complete(),true)
 near(G.fuel(it),8);near(petrol.fluid.amount,0)
end)
test("interior appliances retain their battery circuit",function()
 local v,it,s,b,pl,obj=ground();start(pl,obj)
 eq(V.consumeAuxBattery(v,.2),true);near(b.charge,.6)
 b.charge=0;eq(V.hasAuxBatteryPower(v,.2),false);eq(V.hasLivingPower,nil)
end)
test("native fuel consumption owns the only fuel clock",function()
 local v,it,s,b,pl,obj=ground();start(pl,obj);hours=100;G.update(v);near(G.fuel(it),5)
 obj:setFuel(3.125);G.update(v);near(G.fuel(it),3.125)
end)
test("movement removes power and parking does not reconnect",function()
 local v,it,s,b,pl,obj=ground();start(pl,obj);obj:setFuel(2.75);obj:setCondition(88)
 v.stopped=false;G.update(v);eq(obj:getObjectIndex(),-1);eq(obj:isActivated(),false)
 near(G.fuel(it),2.75);eq(it.condition,88)
 v.stopped=true;G.active[v]=true;G.update(v);local next=G.object(v)
 assert(next and next~=obj);eq(next:isConnected(),false);eq(next:isActivated(),false)
end)
test("lagging stopped flag cannot keep power after position changes",function()
 local v,it,s,b,pl,obj=ground();start(pl,obj);v.x=10.06;G.update(v)
 eq(obj:getObjectIndex(),-1);eq(obj:isActivated(),false)
end)
test("moving vehicle cannot materialize",function()
 local v=fixture();v.stopped=false;G.active[v]=true;G.update(v);eq(#square.objects,0)
end)
test("native start failure is preserved",function()
 local v,it,s,b,pl,obj=ground();obj:setCondition(40);random=0;start(pl,obj)
 eq(obj:isActivated(),false);eq(obj.failed,true)
end)
test("ownership guard rejects native action after replacement",function()
 local v,it,s,b,pl,obj=ground();local petrol=can(pl,3);local a=ISAddFuel:new(pl,obj,petrol)
 v.parts[G.PART].item=item(2,"Base.Generator")
 eq(a:isValid(),false);eq(a:complete(),false);near(petrol.fluid.amount,3)
end)
test("ownership guard rejects native actions while moving",function()
 local v,it,s,b,pl,obj=ground();local a=ISPlugGenerator:new(pl,obj,true)
 v.stopped=false;eq(a:isValid(),false);eq(a:complete(),false)
end)
test("native pickup cannot duplicate installed generator",function()
 local v,it,s,b,pl,obj=ground()
 eq(ISTakeGenerator:new(pl,obj):isValid(),false);eq(ISTakeGenerator:new(pl,obj):complete(),false)
end)
test("orphan owner revokes native power and stores current state",function()
 local v,it,s,b,pl,obj=ground();start(pl,obj);obj:setFuel(1.75);v.parts[G.PART]=nil
 callbacks.tick();eq(obj:getObjectIndex(),-1);near(G.fuel(it),1.75)
end)
test("parked save resumes legitimate original state without duplicate",function()
 local v,it,s,b,pl,obj=ground();start(pl,obj);G.active={};G.grounded={}
 callbacks.load(square);eq(obj:isActivated(),false);callbacks.tick()
 eq(obj:isActivated(),true);eq(#square.objects,1)
end)
test("unconnected save stays unconnected and off",function()
 local v,it,s,b,pl,obj=ground();G.active={};G.grounded={}
 callbacks.load(square);callbacks.tick();eq(obj:isConnected(),false);eq(obj:isActivated(),false)
end)
test("saved moved owner cannot resume old building power",function()
 local v,it,s,b,pl,obj=ground();start(pl,obj);G.active={};G.grounded={};v.x=11;v.stopped=false
 callbacks.load(square);callbacks.tick();eq(obj:getObjectIndex(),-1);eq(obj:isActivated(),false)
end)
test("orphan saved projection is retired",function()
 local v,it,s,b,pl,obj=ground();start(pl,obj);G.active={};G.grounded={};vehicles={}
 callbacks.load(square);callbacks.tick();stamp=stamp+6000;callbacks.tick();eq(obj:getObjectIndex(),-1)
end)
test("collision damage and native repair synchronize both directions",function()
 local v,it,s,b,pl,obj=ground();it.condition=70;G.update(v);eq(obj.condition,70)
 obj:setCondition(80);G.update(v);eq(it.condition,80)
end)
test("missing object cannot resurrect stale fuel",function()
 local v,it,s,b,pl,obj=ground();obj:remove();G.update(v);eq(G.fuel(it),0)
 G.update(v);near(G.object(v):getFuel(),0)
end)
test("server Set scan discovers newly installed parked generators",function()
 local v=fixture();callbacks.tick();eq(#square.objects,1)
 v.stopped=false;stamp=stamp+1000;callbacks.tick();eq(#square.objects,0)
end)
local roundTrip=dofile(roundtripPath)
test("native refuel network constructor receives real generator and petrol",function()
 local v,it,s,b,pl,obj=ground();local petrol=can(pl,3)
 local a=roundTrip(ISAddFuel,native.."/shared/TimedActions/ISAddFuel.lua",ISAddFuel:new(pl,obj,petrol))
 eq(a.generator,obj);eq(a.petrol,petrol);eq(a:complete(),true);near(G.fuel(it),8)
end)
test("native plug network constructor preserves original arguments",function()
 local v,it,s,b,pl,obj=ground()
 local a=roundTrip(ISPlugGenerator,native.."/shared/TimedActions/ISPlugGenerator.lua",ISPlugGenerator:new(pl,obj,true))
 eq(a.generator,obj);eq(a.plug,true);eq(a:complete(),true);eq(obj:isConnected(),true)
end)
test("native repair consumes scrap grants original XP and synchronizes condition",function()
 local v,it,s,b,pl,obj=ground();obj:setCondition(60);G.update(v)
 local scrap={};local inventory={remaining=scrap}
 function inventory:getFirstTypeRecurse()return self.remaining end
 function inventory:containsTypeRecurse()return self.remaining~=nil end
 function inventory:Remove(it)eq(it,scrap);self.remaining=nil end
 pl.getInventory=function()return inventory end;pl.getPerkLevel=function()return 4 end
 pl.removeFromHands=function()end
 Perks={Electricity=1};sendRemoveItemFromContainer=function()end
 local xp=0;addXp=function(_,perk,value)eq(perk,Perks.Electricity);xp=xp+value end
 local repair=ISFixGenerator:new(pl,obj);eq(repair.maxTime,138);eq(repair:isValid(),true)
 eq(repair:complete(),true);eq(inventory.remaining,nil);near(it.condition,66);eq(xp,5)
end)
test("ordinary generator actions bypass mounted ownership boundary",function()
 local v,it,s,b,pl,obj=ground();obj:getModData().vlsMountedGenerator=nil;vehicles={}
 local plug=ISPlugGenerator:new(pl,obj,true)
 eq(plug:isValid(),true);eq(plug:complete(),true);eq(obj:isConnected(),true)
end)
test("unconnected native projection permits normal vehicle uninstall checks",function()
 local file=assert(io.open(base.."shared/VLS_RoofCargo.lua"))
 local code=file:read("*a");file:close()
 local fn=assert(code:match("(function R.UninstallTest.-)\n%-%- Disassembly"))
 local env=setmetatable({R=VLSRoofCargo,VLS=V},{__index=_G})
 assert(load(fn,"uninstall-test","t",env))()
 local R=VLSRoofCargo
 R.isActionPart=function()return true end;R.fabricationSpec=function()return nil end
 R.empty=function()return true end;R.serverCargoToolsReady=function()return true end
 local v,it,s,b,pl,obj,gp=ground()
 eq(R.UninstallTest(v,gp,pl),true)
 ISPlugGenerator:new(pl,obj,true):complete();eq(R.UninstallTest(v,gp,pl),false)
 ISPlugGenerator:new(pl,obj,false):complete();eq(R.UninstallTest(v,gp,pl),true)
 obj:setActivated(true);eq(R.UninstallTest(v,gp,pl),false)
end)
test("generator shortcut disabling revokes supply without losing stored state or equipment",function()
 local saved=SandboxVars.VehicleLivingSlots
 SandboxVars.VehicleLivingSlots=nil;eq(G.enabled(),true)
 local v,it,s,b,pl,obj,part=ground();start(pl,obj);obj:setFuel(3.375);obj:setCondition(81)
 SandboxVars.VehicleLivingSlots={EnableRoofGeneratorShortcut=false}
 eq(ISPlugGenerator:new(pl,obj,false):complete(),false)
 G.update(v);eq(obj:getObjectIndex(),-1);eq(obj:isActivated(),false);eq(G.object(v),nil)
 eq(part:getInventoryItem(),it);near(G.fuel(it),3.375);eq(it:getCondition(),81)
 G.update(v);eq(G.object(v),nil)
 SandboxVars.VehicleLivingSlots.EnableRoofGeneratorShortcut=true;G.update(v)
 eq(G.object(v):isActivated(),false);eq(G.object(v):isConnected(),false);near(G.object(v):getFuel(),3.375)
 SandboxVars.VehicleLivingSlots=saved
end)
print("RESULT generator tests="..n.." failures=0")
