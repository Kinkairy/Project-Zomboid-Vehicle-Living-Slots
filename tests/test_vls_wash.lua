-- Actual VLS + pinned native wash bodies; mocked Java objects, not a live MP test.
local root,native=arg[1] or ".",assert(arg[2],"Pass native Lua repository root")
local path=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
local n=0
local function test(name,fn) fn();n=n+1;print("PASS "..name) end
local function eq(a,b) assert(a==b,tostring(a).." != "..tostring(b)) end
local noop=function() end
local function list(t) t=t or {};return {size=function() return #t end,get=function(_,i)return t[i+1]end,isEmpty=function()return #t==0 end} end
local Base={}
function Base:derive(name)local c={Type=name};c.__index=c;return setmetatable(c,{__index=self})end
function Base:new(character)return setmetatable({character=character},{__index=self})end
Base.perform=noop;Base.stop=noop;Base.adjustMaxTime=function(_,v)return v end
ISBaseTimedAction=Base;package.loaded["TimedActions/ISBaseTimedAction"]=true
package.preload["TimedActions/ISWashClothing"]=function() dofile(native.."/shared/TimedActions/ISWashClothing.lua");return ISWashClothing end
package.preload["TimedActions/ISWashYourself"]=function() dofile(native.."/shared/TimedActions/ISWashYourself.lua");return ISWashYourself end
for _,name in ipairs({"ISTakeWaterAction","ISCleanBandage"}) do
 package.preload["TimedActions/"..name]=function() dofile(native.."/shared/TimedActions/"..name..".lua");return _G[name] end
end
local client=false
isClient=function()return client end
instanceof=function(obj,kind)return type(obj)=="table" and (obj.class==kind or (kind=="InventoryItem" and obj.id~=nil)) end
Math={ceil=math.ceil}
BloodBodyPartType={MAX={index=function()return 3 end},FromIndex=function(i)return i end}
BloodClothingType={getCoveredParts=function()return list({0,1})end}
ItemBodyLocation={MAKE_UP_FULL_FACE=1,MAKE_UP_EYES=2,MAKE_UP_EYES_SHADOW=3,MAKE_UP_LIPS=4}
CharacterStat={UNHAPPINESS=1};ComponentType={FluidContainer=1};Fluid={CleaningLiquid=1}
ZomboidGlobals={CleanStainCleaningFluidAmount=0.1}
sendHumanVisual=noop;syncVisuals=noop;syncItemFields=noop;sendItemStats=noop;sendRemoveItemFromContainer=noop;sendAddItemToContainer=noop
FluidContainer={CreateContainer=function()
 local f={setCapacity=noop}
 function f:copyFluidsFrom(other)self.amount=other.amount;self.tainted=other.tainted end
 return f
end,DisposeContainer=noop}
local vehicles={}
getVehicleById=function(id)return vehicles[id]end
local function inventory()
 local c={items={},soaps={}}
 function c:getItemWithIDRecursiv(id)for _,it in ipairs(self.items)do if it.id==id then return it end end end
 function c:getSoapList()return list(self.soaps)end
 function c:getItems()return list(self.items)end
 function c:Remove(it)for i,v in ipairs(self.items)do if v==it then table.remove(self.items,i);it.container=nil;return end end end
 function c:AddItem(ft)local it={id=99,ft=ft,setFavorite=function()end};self.items[#self.items+1]=it;return it end
 return c
end
local function char()
 local c={inv=inventory(),dead=false,inside=false,near=true,visual={blood={1,1,1},dirt={1,1,1}}}
 function c.visual:getBlood(i)return self.blood[i+1]end
 function c.visual:getDirt(i)return self.dirt[i+1]end
 function c.visual:setBlood(i,v)self.blood[i+1]=v end
 function c.visual:setDirt(i,v)self.dirt[i+1]=v end
 function c:getInventory()return self.inv end
 function c:isDead()return self.dead end
 function c:getVehicle()return self.inside and {} or nil end
 function c:getHumanVisual()return self.visual end
 function c:getWornItem()return nil end
 function c:isTimedActionInstant()return false end
 function c:getStats()return {remove=noop}end
 function c:isPrimaryHandItem()return false end
 function c:isSecondaryHandItem()return false end
 c.updateHandEquips=noop;c.faceThisObject=noop;c.setMetabolicTarget=noop
 return c
end
local function tank(amount)
 local fluid={amount=amount,water=true,emptyable=true}
 function fluid:getAmount()return self.amount end
 function fluid:getCapacity()return 65 end
 function fluid:contains(kind)return self.tainted==true end
 function fluid:copyFluidsFrom(other)self.amount=other.amount;self.tainted=other.tainted end
 function fluid:canPlayerEmpty()return self.emptyable end
 function fluid:removeFluid(n)self.amount=math.max(0,self.amount-n)end
 local t={id=7,fluid=fluid,getID=function(self)return self.id end,getFluidContainer=function(self)return self.fluid end,syncItemFields=noop}
 local p={getId=function()return "Tank"end}
 local v={id=42,tank=t,part=p,stopped=true,removed=false,sync=0}
 function v:getId()return self.id end
 function v:isRemovedFromWorld()return self.removed end
 function v:isStopped()return self.stopped end
 function v:transmitPartItem()self.sync=self.sync+1 end
 v.transmitPartModData=noop
 vehicles[42]=v;return v,t,fluid
end
VLS={isSupportedVehicle=function(v)return v.id==42 end,
 getInstalledWaterTank=function(v,id)if id=="Tank"then return v.tank,v.part end end,
 isPlayerAtWaterTankInlet=function(v,p,c)return c.near end,
 isPureWaterFluid=function(f)return f.water and f.amount>0 end,
 syncVehicleWaterTank=noop}
local configFile=assert(io.open(path.."shared/VLS_Config.lua"))
local configSource=configFile:read("*a");configFile:close()
assert((loadstring or load)(assert(configSource:match("function VLS.isWaterTankShortcutEnabled%(%)\n.-\nend"))))()
package.loaded.VLS_Config=true
local W=dofile(path.."shared/VLS_WaterTankWash.lua")
local function clothing(c)
 local it={id=8,class="Clothing",blood={1,0},dirt={0,1},dirtiness=1,wetness=0,container=c.inv,fulltype="Base.Shirt"}
 function it:getID()return self.id end
 function it:getContainer()return self.container end
 function it:getBloodClothingType()return "shirt"end
 function it:getBlood(i)return self.blood[i+1]end
 function it:getDirt(i)return self.dirt[i+1]end
 function it:setBlood(i,v)self.blood[i+1]=v end
 function it:setDirt(i,v)self.dirt[i+1]=v end
 function it:getDirtiness()return self.dirtiness end
 function it:setDirtiness(v)self.dirtiness=v end
 function it:getBloodLevel()return self.blood[1]+self.blood[2]end
 function it:setBloodLevel(v)self.level=v end
 function it:setWetness(v)self.wetness=v end
 function it:getItemAfterCleaning()return nil end
 function it:setJobDelta(v)self.delta=v end
 function it:getName()return "shirt"end
 c.inv.items[#c.inv.items+1]=it;return it
end
local function body(c)return VLSWashYourselfFromTank:new(c,42,"Tank",7)end
local function wash(c,it)return VLSWashClothingFromTank:new(c,42,"Tank",7,it)end
for _,amount in ipairs({0,0.5,1,2,3,10}) do
 test("body actual native completion amount "..amount,function()
  local c=char();local v,t,f=tank(amount);local a=body(c)
  local expected=math.min(3,math.floor(amount))
  eq(a:complete(),expected>0);eq(f.amount,amount-expected)
  for i=1,3 do eq(c.visual.blood[i],i<=expected and 0 or 1)end
  eq(a:complete(),false);eq(f.amount,amount-expected)
 end)
end
for _,fault in ipairs({"dead","inside","away","moving","removed","wrongtank","notwater","locked","missing"}) do
 test("reject "..fault.." without cleanup or debit",function()
  local c=char();local v,t,f=tank(20);local a=body(c)
  if fault=="dead"then c.dead=true elseif fault=="inside"then c.inside=true elseif fault=="away"then c.near=false
  elseif fault=="moving"then v.stopped=false elseif fault=="removed"then v.removed=true elseif fault=="wrongtank"then t.id=9
  elseif fault=="notwater"then f.water=false elseif fault=="locked"then f.emptyable=false elseif fault=="missing"then v.tank=nil end
  eq(a:isValid(),false);eq(a:complete(),false);eq(f.amount,20);eq(c.visual.blood[1],1)
 end)
end
for _,value in ipairs({"42",{},true,0/0,math.huge,42.5}) do
 test("invalid vehicle ID rejected",function()local c=char();tank(20);eq(W.resolve(c,value,"Tank",7,true),nil)end)
end
test("native clothing completion cleans, wets and consumes exact water",function()
 local c=char();local v,t,f=tank(20);local it=clothing(c);local a=wash(c,it)
 local req=ISWashClothing.GetRequiredWater(it);eq(req,8)
 eq(a:isValid(),true);eq(a:complete(),true);eq(f.amount,12);eq(it.wetness,100);eq(it.dirtiness,0);eq(it.blood[1],0);eq(it.dirt[2],0)
 eq(a:complete(),false);eq(f.amount,12)
end)
test("clothing insufficient water leaves everything untouched",function()
 local c=char();local v,t,f=tank(7);local it=clothing(c);local a=wash(c,it)
 eq(a:isValid(),false);eq(a:complete(),false);eq(f.amount,7);eq(it.wetness,0);eq(it.blood[1],1)
end)
test("another player consumes available water before completion",function()
 local c1,c2=char(),char();local v,t,f=tank(3);local a1,a2=body(c1),body(c2)
 eq(a1:complete(),true);eq(a2:complete(),false);eq(f.amount,0);eq(c2.visual.blood[1],1)
end)
test("removed clothing rejected",function()
 local c=char();tank(20);local it=clothing(c);local a=wash(c,it);c.inv:Remove(it);eq(a:complete(),false)
end)
test("client completion never edits state",function()
 local c=char();local v,t,f=tank(20);local it=clothing(c);client=true
 eq(body(c):complete(),false);eq(wash(c,it):complete(),false);client=false
 eq(f.amount,20);eq(it.wetness,0);eq(c.visual.blood[1],1)
end)
test("native soap and duration rules retained",function()
 local c=char();tank(20);local soap={class="DrainableComboItem",uses=5,getCurrentUses=function(self)return self.uses end,
 UseAndSync=function(self)self.uses=self.uses-1 end,hasComponent=function()return false end}
 local a=body(c);eq(a:getDuration(),378);c.inv.soaps={soap};eq(a:getDuration(),210);eq(a:complete(),true);eq(soap.uses,2)
end)
test("cancel does not consume water",function()
 local c=char();local v,t,f=tank(20);local a=body(c);a:stop();eq(f.amount,20);eq(c.visual.blood[1],1)
end)
test("native failure is not free cleaning and cannot repeat debit",function()
 local c=char();local v,t,f=tank(20);local a=body(c);local old=sendHumanVisual
 sendHumanVisual=function()error("native transport fault")end;eq(a:complete(),false);sendHumanVisual=old
 eq(f.amount,17);eq(a:complete(),false);eq(f.amount,17);assert(v.sync>0)
end)
test("constructor fields required by network reconstruction retained",function()
 local c=char();tank(20);local it=clothing(c);local a=wash(c,it)
 eq(a.vehicleId,42);eq(a.partId,"Tank");eq(a.tankId,7);eq(a.item,it)
 local b=VLSWashClothingFromTank:new(a.character,a.vehicleId,a.partId,a.tankId,a.item)
 eq(b:isValid(),true);eq(b:getDuration(),a:getDuration())
end)
for _,mode in ipairs({"partial","exception"})do
 test("reservation "..mode.." restores water before native effects",function()
  local c=char();local v,t,f=tank(20);local a=body(c)
  f.removeFluid=function(self,n)self.amount=self.amount-1;if mode=="exception"then error("debit failure")end end
  eq(a:complete(),false);eq(f.amount,20);eq(c.visual.blood[1],1);eq(a.vlsCommitted,nil)
 end)
end
-- Native menu fetch/proxy and callback integration (no custom wash submenu).
package.loaded.VLS_WaterTankWash=W
for _,name in ipairs({"Vehicles/ISUI/ISVehicleMenu","ISUI/ISInventoryPaneContextMenu",
 "ISUI/ISWorldObjectContextMenu","TimedActions/ISTimedActionQueue","TimedActions/ISInventoryTransferUtil"})do package.loaded[name]=true end
local hooks={pre={},post={}}
Events={OnPreFillWorldObjectContextMenu={Add=function(f)table.insert(hooks.pre,f)end},
 OnFillWorldObjectContextMenu={Add=function(f)table.insert(hooks.post,f)end}}
local queue={}
ISTimedActionQueue={add=function(a)queue[#queue+1]=a end}
ISInventoryPaneContextMenu={transferIfNeeded=noop}
ISVehicleMenu={getVehicleToInteractWith=function()return vehicles[42]end}
VLS.getWaterTankPartIds=function()return {"Tank"}end
getCell=function()return {} end
getText=function(key)return key end
local current
getSpecificPlayer=function()return current end
local sprite={getName=function()return "floor"end}
local square={getFloor=function()return {getSprite=function()return sprite end}end}
local function menuCharacter()local c=char();function c:getSquare()return square end;return c end
IsoObject={new=function()return {setSquare=noop,setSprite=noop}end}
ComponentType.FluidContainer={CreateComponent=function()
 local f={setCapacity=noop,setCanPlayerEmpty=noop}
 function f:copyFluidsFrom(real)self.amount=real.amount;self.tainted=real.tainted end
 return f
end}
Fluid.TaintedWater="tainted"
GameEntityFactory={AddComponent=function(proxy,_,f)proxy.fluid=f end}
ISWorldObjectContextMenu={onWashYourself=noop,onWashClothing=noop,onDrink=noop,onTakeWater=noop,setTest=function()return true end}
dofile(path.."client/VLS_WaterTankWashMenu.lua")
local function fetch(tainted)
 current=menuCharacter();local v,t,f=tank(20);f.tainted=tainted
 ISWorldObjectContextMenu.fetchVars={c=0,storeWater={}}
 local context={options={}}
 hooks.pre[1](0,context,{},false)
 return context,ISWorldObjectContextMenu.fetchVars.storeWater[1],f
end
test("native fetch receives actual composition without draining tank",function()
 local context,proxy,f=fetch(true)
 eq(proxy.fluid.amount,20);eq(proxy.fluid.tainted,true);eq(f.amount,20)
 eq(ISWorldObjectContextMenu.fetchVars.c,1);eq(#context.options,0)
end)
test("clean proxy removes only false tainted label",function()
 local context,proxy=fetch(false)
 local op={target=proxy,toolTip={description="Capacity 65 <LINE> Tooltip_item_TaintedWater"}}
 context.options={op};hooks.post[1](0,context,{},false)
 assert(op.toolTip.description:find("Capacity 65",1,true))
 assert(not op.toolTip.description:find("Tooltip_item_TaintedWater",1,true))
end)
test("real tainted water retains native warning",function()
 local context,proxy=fetch(true)
 local op={target=proxy,toolTip={description="Tooltip_item_TaintedWater"}}
 context.options={op};hooks.post[1](0,context,{},false)
 eq(op.toolTip.description,"Tooltip_item_TaintedWater")
end)
test("unrelated native water option unchanged",function()
 local context=fetch(false)
 local op={target={},toolTip={description="Tooltip_item_TaintedWater"}}
 context.options={op};hooks.post[1](0,context,{},false)
 eq(op.toolTip.description,"Tooltip_item_TaintedWater")
end)
test("native callback queues real tank action",function()
 local context,proxy=fetch(false);queue={}
 ISWorldObjectContextMenu.onWashYourself(current,proxy,nil)
 eq(#queue,1);eq(queue[1].Type,"VLSWashYourselfFromTank");eq(queue[1].tankId,7)
end)
test("world-menu test pass creates no proxy",function()
 local before=#ISWorldObjectContextMenu.fetchVars.storeWater
 hooks.pre[1](0,{options={}},{},true)
 eq(#ISWorldObjectContextMenu.fetchVars.storeWater,before)
end)
test("tank changed after menu cancels queue submission",function()
 current=char();local v,t=tank(20);queue={};t.id=8
 W.queueBody(current,42,"Tank",7);eq(#queue,0)
end)
test("menu hooks installed once",function()
 dofile(path.."client/VLS_WaterTankWashMenu.lua");eq(#hooks.pre,1);eq(#hooks.post,1)
end)
test("wash queue stops when a second garment lacks water",function()
 current=char();local v,t,f=tank(12);local a,b=clothing(current),clothing(current);b.id=9
 queue={};W.queueClothes(current,42,"Tank",7,{a,b});eq(#queue,2)
 eq(queue[1]:complete(),true);eq(queue[2]:complete(),false);eq(f.amount,4);eq(b.wetness,0)
end)
test("bandage delegates native replacement once with reserved water",function()
 local c=char();local v,t,f=tank(12);local it=clothing(c)
 sendReplaceItemInContainer=noop;sendEquip=noop
 local recipe={getResult=function()return {getType=function()return "Base.Bandage"end}end,getTimeToMake=function()return 10 end}
 local action=VLSCleanBandageFromTank:new(c,42,"Tank",7,it,recipe)
 eq(action:complete(),true);eq(f.amount,11);eq(#c.inv.items,1);eq(c.inv.items[1].ft,"Base.Bandage")
 eq(action:complete(),false);eq(f.amount,11)
end)
test("water shortcut defaults on and disabled queued actions cannot spend water",function()
 local saved=SandboxVars
 SandboxVars=nil;eq(VLS.isWaterTankShortcutEnabled(),true)
 SandboxVars={VehicleLivingSlots={}};eq(VLS.isWaterTankShortcutEnabled(),true)
 local c=char();local v,t,f=tank(20);local a=body(c)
 SandboxVars.VehicleLivingSlots.EnableWaterTankShortcut=false
 eq(a:isValid(),false);eq(a:complete(),false);eq(f.amount,20)
 SandboxVars.VehicleLivingSlots.EnableWaterTankShortcut=true
 eq(a:complete(),true);eq(f.amount,17)
 SandboxVars=saved
end)
-- Actual vehicle/tank registration, without granting every fixture a water tank.
package.path=path.."shared/?.lua;"..root.."/workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media/lua/shared/?.lua;"..package.path
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded.VLS_Config=dofile(path.."shared/VLS_Config.lua")
require "VLS_KI5Campers_Config"
-- Geometry is covered by the inlet tests; keep this matrix about actual equipment.
VLS.isPlayerAtWaterTankInlet=function(v,p,c)return c.near end
getCell=function()return {getGridSquare=function()return nil end}end
square.getX=function()return 0 end;square.getY=square.getX;square.getZ=square.getX
local function waterMenuCount()
 ISWorldObjectContextMenu.fetchVars={c=0,storeWater={}}
 hooks.pre[1](0,{options={}},{},false)
 return #ISWorldObjectContextMenu.fetchVars.storeWater
end
local covered=0
for name,profile in pairs(VLS.vehicleProfiles)do
 for _,partId in ipairs(profile.waterTankParts or {})do
  covered=covered+1
  test("actual water equipment menu "..name.." "..partId,function()
   current=menuCharacter();local v,t,f=tank(20)
   local part={getId=function()return partId end,getInventoryItem=function()return v.tank end}
   v.parts={[partId]=part};v.getScriptName=function()return name end
   v.getPartById=function(self,id)return self.parts[id]end
   t.ft="Base.NormalGasTank2";t.getFullType=function(self)return self.ft end
   f.getPrimaryFluid=function()return {getFluidTypeString=function()return "Base.Water"end}end
   f.getPrimaryFluidAmount=function(self)return self.amount end
   eq(waterMenuCount(),1)
   v.tank=nil;eq(waterMenuCount(),0)
   v.tank=t;t.ft="Base.PetrolCan";eq(waterMenuCount(),0)
   t.ft="Base.NormalGasTank2";f.amount=0;eq(waterMenuCount(),0)
   f.amount=20;v.parts[partId]=nil;eq(waterMenuCount(),0)
  end)
 end
end
test("registered water tank matrix includes 29 StepVans and both tanks on six KI5 campers",function()eq(covered,41)end)
for _,name in ipairs({"Base.Van","Base.VanSeats","Base.SUV","Base.PickUpVan","Other.Vehicle"})do
 test("no water hardware no water menu "..name,function()
  current=menuCharacter();local v=tank(20)
  v.getScriptName=function()return name end
  eq(waterMenuCount(),0)
 end)
end
print("RESULT water-wash tests="..n.." failures=0 (actual native action bodies; mocked engine)")
