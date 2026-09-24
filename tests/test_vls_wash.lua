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
CharacterStat={UNHAPPINESS=1,THIRST=2};ComponentType={FluidContainer=1};Fluid={CleaningLiquid=1}
ZomboidGlobals={CleanStainCleaningFluidAmount=0.1,EquippedOrWornEncumbranceMultiplier=0.3}
sendHumanVisual=noop;syncVisuals=noop;syncItemFields=noop;sendItemStats=noop;sendRemoveItemFromContainer=noop;sendAddItemToContainer=noop
local function water(amount,capacity)
 local f={amount=amount or 0,capacity=capacity or 65,water=true,emptyable=true}
 function f:getAmount()return self.amount end
 function f:getCapacity()return self.capacity end
 function f:setCapacity(n)self.capacity=n end
 function f:contains(kind)return self.tainted==true end
 function f:copyFluidsFrom(other)self.amount=other.amount;self.tainted=other.tainted end
 function f:canPlayerEmpty()return self.emptyable end
 function f:removeFluid(n)self.amount=math.max(0,self.amount-n)end
 function f:transferTo(target,n)
  n=math.min(n,self.amount,target.capacity-target.amount)
  self.amount=self.amount-n;target.amount=target.amount+n;target.tainted=self.tainted
 end
 return f
end
FluidContainer={CreateContainer=function()return water(0,1)end,DisposeContainer=noop,
 CanTransfer=function(source,target)return not target.locked and target.amount<target.capacity end}
local vehicles={}
getVehicleById=function(id)return vehicles[id]end
local function inventory()
 local c={items={},soaps={}}
 function c:getItemWithIDRecursiv(id)for _,it in ipairs(self.items)do if it.id==id then return it end end end
 function c:getSoapList()return list(self.soaps)end
 function c:isInCharacterInventory()return true end
 function c:setDrawDirty()end
 function c:getItems()return list(self.items)end
 function c:Remove(it)for i,v in ipairs(self.items)do if v==it then table.remove(self.items,i);it.container=nil;return end end end
 function c:AddItem(ft)local it={id=99,ft=ft,setFavorite=function()end};self.items[#self.items+1]=it;return it end
 return c
end
local function char()
 local c={inv=inventory(),dead=false,inside=false,near=true,thirst=0.4,free=100,visual={blood={1,1,1},dirt={1,1,1}}}
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
 function c:getStats()return {remove=noop,get=function()return c.thirst end}end
 function c:getFreeInventoryCapacity()return self.free end
 function c:hasFullInventory()return self.free<=0 end
 function c:isEquippedClothing()return false end
 function c:DrinkFluid(f)self.thirst=self.thirst-f:getAmount()/2 end
 function c:isPrimaryHandItem()return false end
 function c:isSecondaryHandItem()return false end
 c.updateHandEquips=noop;c.faceThisObject=noop;c.setMetabolicTarget=noop
 return c
end
local function tank(amount)
 local fluid=water(amount)
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

for _,fail in ipairs({false,true}) do
 test("native water action updates retain effects and restore endpoint fault="..tostring(fail),function()
  local c=char();local v=tank(20);local it=clothing(c)
  Metabolics={LightDomestic="light",HeavyDomestic="heavy"}
  c.faceThisObjectAlt=function(_,object)
   eq(object,v);c.faced=object;if fail then error("native facing fault")end
  end
  c.faceThisObject=c.faceThisObjectAlt
  c.setMetabolicTarget=function(_,value)c.metabolic=value end
  c.shouldBeTurning=function()return true end
  local a=body(c);local source=a.sink
  eq(pcall(a.update,a),not fail);eq(a.sink,source);eq(c.faced,v)
  if not fail then eq(c.metabolic,"light")end
  a=wash(c,it);a.getJobDelta=function()return 0.25 end;source=a.sink
  eq(pcall(a.update,a),not fail);eq(a.sink,source);eq(it.delta,0.25)
  if not fail then eq(c.metabolic,"heavy")end
  a=setmetatable({character=c,vehicleId=42,partId="Tank",tankId=7,item=it,
   waterObject={fixture="source"},getJobDelta=function()return 0.5 end},
   {__index=VLSCleanBandageFromTank})
  source=a.waterObject
  local ok,result=pcall(a.waitToStart,a);eq(ok,not fail)
  if ok then eq(result,true)end
  eq(a.waterObject,source)
  eq(pcall(a.update,a),not fail);eq(a.waterObject,source);eq(it.delta,0.5)
 end)
end
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
ISInventoryTransferUtil={newInventoryTransferAction=function(c,it,from,to)
 return {Type="ReturnToBag",item=it,from=from,to=to}
end}
luautils={walkAdjObject=function()return true end}
ISVehicleMenu={getVehicleToInteractWith=function()return vehicles[42]end}
VLS.getWaterTankPartIds=function()return {"Tank"}end
getCell=function()return {} end
getText=function(key)return key end
local current
getSpecificPlayer=function()return current end
local sprite={getName=function()return "floor"end}
local square={getFloor=function()return {getSprite=function()return sprite end}end}
local function menuCharacter()local c=char();function c:getSquare()return square end;return c end
IsoObject={new=function()return {setSquare=function(self,s)self.square=s end,setSprite=noop,
 getSquare=function(self)return self.square end,getFluidAmount=function(self)return self.fluid.amount end,
 isTaintedWater=function(self)return self.fluid.tainted or false end}end}
ComponentType.FluidContainer={CreateComponent=function()
 local f={setCapacity=noop,setCanPlayerEmpty=noop}
 function f:copyFluidsFrom(real)self.amount=real.amount;self.tainted=real.tainted end
 return f
end}
Fluid.TaintedWater="tainted"
GameEntityFactory={AddComponent=function(proxy,_,f)proxy.fluid=f end}
-- Capture real native callbacks BEFORE VLS installs anything, as the Java menu
-- cache does when a player uses an ordinary tap first. Calling the current Lua
-- table alone missed this regression in the old tests.
local contextFile=assert(io.open(native.."/client/ISUI/ISWorldObjectContextMenu.lua"))
local nativeContext=contextFile:read("*a"):gsub("\r\n","\n");contextFile:close()
ISWorldObjectContextMenu={setTest=function()return true end,transferIfNeeded=noop}
local cached={}
for _,name in ipairs({"onTakeWater","onDrink","onWashYourself","onWashClothing"})do
 local code=assert(nativeContext:match("ISWorldObjectContextMenu%."..name.." = function.-\nend"))
 assert((loadstring or load)(code))();cached[name]=ISWorldObjectContextMenu[name]
end
ISInventoryPaneContextMenu.getEatingMask=function()return nil end
local function bottle(c,amount,capacity,bag)
 local it={id=100+#c.inv.items,fluid=water(amount,capacity),container=bag or c.inv}
 function it:getID()return self.id end
 function it:getFluidContainer()return self.fluid end
 function it:getContainer()return self.container end
 function it:canStoreWater()return false end
 function it:isEquipped()return false end
 it.syncItemFields=noop;it.setJobDelta=noop;it.setBeingFilled=noop
 c.inv.items[#c.inv.items+1]=it;return it
end
dofile(path.."client/VLS_WaterTankWashMenu.lua")
local function fetch(tainted)
 current=menuCharacter();local v,t,f=tank(20);f.tainted=tainted
 ISWorldObjectContextMenu.fetchVars={c=0,storeWater={}}
 local context={options={}}
 hooks.pre[1](0,context,{},false)
 return context,ISWorldObjectContextMenu.fetchVars.storeWater[1],f
end
local function near(a,b)assert(math.abs(a-b)<0.000001,tostring(a).." != "..tostring(b))end
test("cached native Fill callback queues IDs instead of the transient world object",function()
 local context,proxy=fetch(false);queue={};local it=bottle(current,0,0.9)
 cached.onTakeWater({},proxy,nil,it,0)
 eq(#queue,1);eq(queue[1].Type,"VLSTakeWaterFromTank")
 eq(queue[1].vehicleId,42);eq(queue[1].partId,"Tank");eq(queue[1].tankId,7)
 assert(queue[1].waterObject~=proxy)
 for name,callback in pairs(cached)do eq(ISWorldObjectContextMenu[name],callback)end
end)
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
 cached.onWashYourself(current,proxy,nil)
 eq(#queue,1);eq(queue[1].Type,"VLSWashYourselfFromTank");eq(queue[1].tankId,7)
end)
test("world-menu test pass creates no proxy",function()
 local before=#ISWorldObjectContextMenu.fetchVars.storeWater
 hooks.pre[1](0,{options={}},{},true)
 eq(#ISWorldObjectContextMenu.fetchVars.storeWater,before)
end)
test("tank changed after menu rejects the queued native callback result",function()
 local context,proxy=fetch(false);queue={};vehicles[42].tank.id=8
 cached.onWashYourself(current,proxy,nil)
 eq(#queue,1);eq(queue[1]:isValid(),false);eq(queue[1]:complete(),false)
end)
test("menu hooks installed once",function()
 dofile(path.."client/VLS_WaterTankWashMenu.lua");eq(#hooks.pre,1);eq(#hooks.post,1)
end)
test("wash queue stops when a second garment lacks water",function()
 local context,proxy,f=fetch(false);f.amount=12
 local a,b=clothing(current),clothing(current);b.id=9
 queue={};cached.onWashClothing(current,proxy,nil,{a,b},nil);eq(#queue,2)
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
test("Fill All uses native bag return and preserves both container identities",function()
 local context,proxy,f=fetch(false);queue={};local bag=inventory()
 local a,b=bottle(current,0,0.9,bag),bottle(current,0.1,0.5)
 cached.onTakeWater({},proxy,{a,b},nil,0)
 eq(#queue,3);eq(queue[1].Type,"VLSTakeWaterFromTank");eq(queue[1].item,a)
 eq(queue[2].Type,"ReturnToBag");eq(queue[2].to,bag)
 eq(queue[3].Type,"VLSTakeWaterFromTank");eq(queue[3].item,b)
 queue[1]:complete();queue[3]:complete()
 near(a.fluid.amount,0.9);near(b.fluid.amount,0.5);near(f.amount,18.7)
end)
for _,raining in ipairs({false,true})do
 for _,initial in ipairs({0.15,0.9,2})do
  test("MP Fill debits actual tank, rain="..tostring(raining).." water="..initial,function()
   local context,proxy,f=fetch(false);f.amount=initial;queue={}
   proxy.isTaintedWater=function()return raining end
   local it=bottle(current,0,0.9)
   cached.onTakeWater({},proxy,nil,it,0)
   local a=queue[1];eq(a.Type,"VLSTakeWaterFromTank");eq(a.waterTaintedCL,false)
   local roundtrip=dofile((io.open(root.."/tests/net_action_roundtrip.lua", "r") and root.."/tests/net_action_roundtrip.lua") or root.."/../../tests/vehicle-living-slots/net_action_roundtrip.lua")
   local server=roundtrip(VLSTakeWaterFromTank,path.."shared/VLS_WaterTankWash.lua",a)
   eq(server:isValid(),true);near(server.waterUnit,math.min(initial,0.9))
   server:updateUse(0.5);near(f.amount+it.fluid.amount,initial)
   server:complete();near(it.fluid.amount,math.min(initial,0.9))
   near(f.amount+it.fluid.amount,initial);assert(not it.fluid.tainted)
   server:complete();near(f.amount+it.fluid.amount,initial)
  end)
 end
end
test("partial Fill cancellation retains exactly the amount already transferred",function()
 local context,proxy,f=fetch(false);queue={};local it=bottle(current,0,1)
 cached.onTakeWater({},proxy,nil,it,0);local a=queue[1]
 a:updateUse(0.25);a:stop();near(it.fluid.amount,0.25);near(f.amount,19.75)
end)
test("cached Drink preserves native mask handling and real tank debit",function()
 local context,proxy,f=fetch(false);queue={}
 local mask={};ISInventoryPaneContextMenu.getEatingMask=function()return mask end
 ISWearClothing={new=function(_,c,item)return {Type="WearMask",item=item}end}
 cached.onDrink({},proxy,0)
 eq(#queue,2);eq(queue[1].Type,"VLSTakeWaterFromTank");eq(queue[2].item,mask)
 queue[1]:complete();near(current.thirst,0);near(f.amount,19.2)
 ISInventoryPaneContextMenu.getEatingMask=function()return nil end
end)
test("ordinary dispenser keeps the original native action",function()
 local context,proxy=fetch(false);queue={};local it=bottle(current,0,1)
 local dispenser={getSquare=function()return square end,getFluidAmount=function()return 20 end,
  isTaintedWater=function()return false end}
 cached.onTakeWater({},dispenser,nil,it,0)
 eq(#queue,1);eq(queue[1].Type,"ISTakeWaterAction");eq(queue[1].waterObject,dispenser)
 queue={};cached.onWashYourself(current,dispenser,nil)
 eq(#queue,1);eq(queue[1].Type,"ISWashYourself");eq(queue[1].sink,dispenser)
end)
test("another player exhausting the tank cannot create water",function()
 local context,proxy,f=fetch(false);f.amount=0.5;queue={}
 local a,b=bottle(current,0,1),bottle(current,0,1)
 cached.onTakeWater({},proxy,{a,b},nil,0)
 queue[1]:complete();queue[2]:complete()
 near(a.fluid.amount,0.5);near(b.fluid.amount,0);near(f.amount,0)
end)
test("tainted tank composition is preserved during collection",function()
 local context,proxy,f=fetch(true);queue={};local it=bottle(current,0,1)
 cached.onTakeWater({},proxy,nil,it,0)
 eq(queue[1].waterTaintedCL,true);queue[1]:complete()
 eq(it.fluid.tainted,true);near(f.amount,19);near(it.fluid.amount,1)
end)
test("native inventory capacity caps vehicle water collection",function()
 local context,proxy,f=fetch(false);queue={};local it=bottle(current,0,1);current.free=0.2
 cached.onTakeWater({},proxy,nil,it,0);near(queue[1].waterUnit,0.2)
 queue[1]:complete();near(it.fluid.amount,0.2);near(f.amount,19.8)
end)
for _,fault in ipairs({"changedtank","moving","away","empty","locked","disabled","client"})do
 test("queued Fill refuses stale or invalid source: "..fault,function()
  local context,proxy,f=fetch(false);queue={};local it=bottle(current,0,1)
  cached.onTakeWater({},proxy,nil,it,0);local a=queue[1]
  if fault=="changedtank"then vehicles[42].tank.id=9 elseif fault=="moving"then vehicles[42].stopped=false
  elseif fault=="away"then current.near=false elseif fault=="empty"then f.amount=0
  elseif fault=="locked"then it.fluid.locked=true elseif fault=="disabled"then SandboxVars={VehicleLivingSlots={EnableWaterTankShortcut=false}}
  elseif fault=="client"then client=true end
  local before=f.amount;a:complete();near(it.fluid.amount,0);near(f.amount,before)
  client=false;SandboxVars=nil
 end)
end
test("vehicle water start delegates original tap setup and restores facing target",function()
 local context,proxy,f=fetch(false);queue={};local it=bottle(current,0,1)
 it.getName=function()return "Bottle"end
 it.getFillFromTapSound=function()return "NativeFillSound"end
 it.getPourType=function()return "bottle"end;it.getStaticModel=function()return "BottleModel"end
 it.setJobType=function(_,v)it.job=v end
 it.setBeingFilled=function(_,v)it.filling=v end
 current.playSound=function(_,v)current.sound=v;return 1 end
 current.reportEvent=function(_,v)current.event=v end
 cached.onTakeWater({},proxy,nil,it,0);local a=queue[1]
 a.setAnimVariable=noop;a.setActionAnim=function(_,v)a.animation=v end;a.setOverrideHandModels=noop
 a:start();eq(a.waterObject,vehicles[42]);eq(it.filling,true)
 eq(a.animation,"fill_container_tap");eq(current.sound,"NativeFillSound");eq(current.event,"EventTakeWater")
 near(it.fluid.amount,0);near(f.amount,20)
end)

-- Exercise native queue advancement after authoritative fluid sync, not just
-- two direct complete() calls. Full target state arrives before client perform.
test("Fill All survives MP full-container sync and advances the native queue",function()
 local context,proxy,f=fetch(false)
 local a,b,c=bottle(current,0,1),bottle(current,0.25,0.5),bottle(current,0,0.75)
 local savedQueue,savedPerform,savedBaseObject=ISTimedActionQueue,Base.perform,ISBaseObject
 package.loaded.ISBaseObject=true;ISBaseObject=Base
 local file=assert(io.open(native.."/client/TimedActions/ISTimedActionQueue.lua"))
 local code=file:read("*a"):gsub("\r\n","\n");file:close()
 assert((loadstring or load)(code:sub(1,assert(code:find("local STATES =",1,true))-1)))()
 local baseFile=assert(io.open(native.."/shared/TimedActions/ISBaseTimedAction.lua"))
 local baseCode=baseFile:read("*a"):gsub("\r\n","\n");baseFile:close()
 assert((loadstring or load)(assert(baseCode:match("function ISBaseTimedAction:perform%(%)\n.-\nend"))))()
 ISLogSystem={logAction=noop};current.setIsFarming=noop
 local started=0
 Base.begin=function()started=started+1 end
 Base.isValidStart=function()return true end
 Base.isStarted=function()return false end;Base.forceCancel=noop
 cached.onTakeWater({},proxy,{a,b,c},nil,0)
 local q=ISTimedActionQueue.getTimedActionQueue(current);eq(#q.queue,3);eq(started,1)
 local roundtrip=dofile((io.open(root.."/tests/net_action_roundtrip.lua", "r") and root.."/tests/net_action_roundtrip.lua") or root.."/../../tests/vehicle-living-slots/net_action_roundtrip.lua")
 for index,item in ipairs({a,b,c}) do
  local action=q.current;eq(action.item,item);eq(action:isValid(),true)
  local server=roundtrip(VLSTakeWaterFromTank,path.."shared/VLS_WaterTankWash.lua",action)
  server:updateUse(0.5);eq(action:isValid(),true);server:complete()
  near(item.fluid.amount,item.fluid.capacity)
  eq(action:isValid(),true) -- used to cancel the rest of Fill All here
  action:perform();eq(#q.queue,3-index)
 end
 eq(started,3);eq(q.current,nil);near(f.amount,18)
 ISTimedActionQueue=savedQueue;Base.perform=savedPerform;ISBaseObject=savedBaseObject
end)

-- Actual vehicle/tank registration, without granting every fixture a water tank.
package.path=path.."shared/?.lua;"..root.."/workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media/lua/shared/?.lua;"..package.path
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
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
