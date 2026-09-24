-- Execute the shipped B42.20 menu builders with engine objects mocked.
local root,native=assert(arg[1]),assert(arg[2])
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
package.path=media.."shared/?.lua;"..media.."client/?.lua;"..native.."/shared/?.lua;"..package.path
local noop=function()end
local n=0
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
local function list(items)
 return {size=function()return #items end,isEmpty=function()return #items==0 end,get=function(_,i)return items[i+1]end}
end
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
-- Cargo access is exercised against native Vehicles.lua in its own suite.
package.loaded["Vehicles/Vehicles"]=true
require "VLS_Config"
require "VLS_RoofCargo"
for _,name in ipairs({"TimedActions/ISBaseTimedAction","TimedActions/ISTimedActionQueue",
 "Vehicles/TimedActions/ISPathFindAction","ISUI/ISContextMenu","ISUI/ISWorldObjectContextMenu",
 "TimedActions/ISGeneratorInfoAction","TimedActions/ISInventoryTransferUtil","Vehicles/ISUI/ISVehicleMenu","VLS_GeneratorOwnership"})do package.loaded[name]=true end
ISBaseTimedAction={derive=function(self,name)local c={Type=name};c.__index=c;return setmetatable(c,{__index=self})end,
 new=function(self,character)return setmetatable({character=character},self)end}
Fluid={Petrol="Petrol"};FluidContainer={CanTransfer=function()return true end}
getText=function(key)return key end;instanceof=function()return false end
string.sort=function(a,b)return a>b end
isClient=function()return false end
local menus={}
local function menu()
 local m={options={}}
 function m:addOption(name,target,callback,...)
  local o={name=name,target=target,onSelect=callback,args={...}};self.options[#self.options+1]=o;return o
 end
 m.addGetUpOption=m.addOption
 function m:addSubMenu(o,sub)menus[#menus+1]=sub;o.subOption=#menus end
 function m:getSubMenu(id)return menus[id]end
 function m:getOptionFromName(name)for _,o in ipairs(self.options)do if o.name==name then return o end end end
 function m:removeOptionByName(name)for i,o in ipairs(self.options)do if o.name==name then table.remove(self.options,i);return end end end
 return m
end
ISContextMenu={getNew=menu}
ISWorldObjectContextMenu={addToolTip=function()return {}end,onTakeFuelNew=noop,doAddFuelGenerator=noop,
 onInfoGenerator=function()end,onPlugGenerator=function()end,onActivateGenerator=function()end,onFixGenerator=function()end,
 equip=noop,transferIfNeeded=noop}
local W=ISWorldObjectContextMenu
local file=assert(io.open(native.."/client/ISUI/ISWorldObjectContextMenu.lua"));local source=file:read("*a"):gsub("\r","");file:close()
local function extract(start)
 local pos=assert(source:find(start,1,true));local finish=assert(source:find("\nend",pos,true))
 return source:sub(pos,finish+3)
end
local code=extract("local function predicateStoreFuel(item)").."\n"..
 extract("ISWorldObjectContextMenu.doFillFuelMenu = function").."\n"..
 extract("ISWorldObjectContextMenu.onAddFuelGenerator = function").."\n"..
 extract("ISWorldObjectContextMenu.onTakeFuelNew = function").."\n"..
 extract("ISWorldObjectContextMenu.doAddFuelGenerator = function").."\n"..
 extract("ISWorldObjectContextMenu.onPlugGenerator = function").."\n"..
 extract("ISWorldObjectContextMenu.onActivateGenerator = function").."\n"..
 extract("ISWorldObjectContextMenu.onFixGenerator = function")
assert((loadstring or load)(code))()
local nativePump,nativeFuel=W.doFillFuelMenu,W.onAddFuelGenerator
local player,vehicle,queued
local square={getBuilding=function()return nil end}
AdjacentFreeTileFinder={Find=function()return square end}
getCell=function()return {getGridSquare=function()return square end}end
ZomboidGlobals={EquippedOrWornEncumbranceMultiplier=.3}
luautils={walkAdj=function()return true end}
getSpecificPlayer=function()return player end
ISVehicleMenu={getVehicleToInteractWith=function()return vehicle end}
ISPathFindAction={pathToVehicleArea=function()return {Type="path"}end}
ISTimedActionQueue={add=function(action)queued[#queued+1]=action end}
ISInventoryTransferUtil={newInventoryTransferAction=function()return {Type="return"}end}
ISInventoryPaneContextMenu={equipWeapon=noop,transferIfNeeded=noop}
ISGeneratorInfoAction={new=function(_,p,o)return {Type="info",object=o}end}
local inventoryAdds,removedOld=0,false
local oldInventoryMenu=function()end
VLS.roofFuelInventoryMenu=oldInventoryMenu
Events={OnObjectAdded={Add=noop,Remove=noop},LoadGridsquare={Add=noop,Remove=noop},OnTick={Add=noop,Remove=noop},OnFillInventoryObjectContextMenu={Add=function()inventoryAdds=inventoryAdds+1 end,
 Remove=function(fn)removedOld=fn==oldInventoryMenu end},OnFillWorldObjectContextMenu={Add=noop,Remove=noop},OnPreFillWorldObjectContextMenu={Add=noop,Remove=noop}}
local F=require "VLS_RoofFuel"
local G=require "VLS_Generator"
package.loaded.VLS_GeneratorOwnership=G
require "VLS_RoofServicesMenu"
test("old inventory shortcut is removed and never registered again",function()
 eq(inventoryAdds,0);eq(removedOld,true);eq(VLS.roofFuelInventoryMenu,nil)
end)
local function fluid(amount,capacity,kind)
 return {getAmount=function()return amount end,getCapacity=function()return capacity end,
 getFreeCapacity=function()return capacity-amount end,isEmpty=function()return amount==0 end,
 isInputLocked=function()return false end,contains=function(_,k)return kind==k end,canPlayerEmpty=function()return true end}
end
local nativeGeneratorObject=G.object
local function fixture(name)
 queued={};menus={}
 local inventory={items={}}
 function inventory:getAllEvalRecurse(predicate)
  local found={};for _,it in ipairs(self.items)do if predicate(it)then found[#found+1]=it end end;return list(found)
 end
 function inventory:isInCharacterInventory()return true end
 function inventory:contains(item)return item.carried==true end
 function inventory:getItemWithIDRecursiv(id)for _,it in ipairs(self.items)do if it.id==id then return it end end end
 function inventory:containsTypeRecurse()return false end
 local function item(id,name,amount,capacity,kind)
  local it={id=id,carried=true,kind=kind or "Base.PetrolCan",condition=100,md={fuel=5}}
  local f=fluid(amount,capacity,"Petrol")
  function it:getFluidContainer()return f end
  function it:getName()return name end;it.getDisplayName=it.getName
  function it:isBroken()return false end;function it:getID()return self.id end
  function it:getFullType()return self.kind end;function it:getContainer()return inventory end
  function it:getModData()return self.md end;function it:getCondition()return self.condition end
  return it
 end
 player={known=true,getPlayerNum=function()return 0 end,getVehicle=function()return nil end,getPrimaryHandItem=noop,
 getZ=function()return 0 end,DistToProper=function()return 1 end,getInventory=function()return inventory end,
 getBuilding=function()return nil end,getFreeInventoryCapacity=function()return 100 end,hasFullInventory=function()return false end,isTimedActionInstant=function()return false end,
 isDead=function()return false end,getKnownRecipes=function(self)return {contains=function()return self.known end}end}
 vehicle={parts={},getAreaCenter=function()return {getX=function()return 10 end,getY=function()return 10 end}end,getScript=function()return {getFullName=function()return name or "Base.StepVan"end}end,
 getSquare=function()return square end,isStopped=function()return true end,getZ=function()return 0 end,isInArea=function()return true end,
 getPartById=function(self,id)return self.parts[id]end}
 local function part(id,it)
  local p={getId=function()return id end,getArea=function()return "VLSRoofGeneratorService"end,getInventoryItem=function()return it end}
  vehicle.parts[id]=p;return p
 end
 local gen=item(1,"Generator",0,0,"Base.Generator");part(G.PART,gen)
 part("VLSRoofPetrol1",item(2,"roof red",2,10))
 part("VLSRoofPetrol2",item(3,"roof green",20,20,"Base.JerryCan"))
 inventory.items={item(10,"Empty can",0,10),item(11,"Empty can",0,10),item(12,"Bottle",0,1)}
 G.object=function()return nil end
 return inventory,gen,item
end
test("native pump builds one parent and groups identical portable containers",function()
 fixture();local c=menu();local callback=W.onTakeFuelNew
 F.addCollectMenu(0,vehicle,c);eq(W.onTakeFuelNew,callback);eq(#c.options,1)
 eq(c.options[1].name,"ContextMenu_TakeGasFromPump")
 local sub=c:getSubMenu(c.options[1].subOption)
 eq(#sub.options,3);eq(sub.options[1].name,"ContextMenu_FillAll")
 local grouped=sub:getOptionFromName("Empty can (2)");assert(grouped)
 local group=sub:getSubMenu(grouped.subOption);eq(group.options[1].name,"ContextMenu_FillOne")
 eq(group.options[2].name,"ContextMenu_FillAll")
 eq(sub:getOptionFromName("Bottle").toolTip.description,"ContextMenu_FuelCapacity1 / 1")
end)
test("original fill-all callback queues one native derived action per container",function()
 fixture();local c=menu();F.addCollectMenu(0,vehicle,c)
 local option=c:getSubMenu(c.options[1].subOption).options[1]
 eq(option.onSelect,W.onTakeFuelNew)
 option.onSelect(option.target,unpack(option.args))
 local actions=0
 for _,a in ipairs(queued)do
  if a.Type=="VLSRoofFuelAction"then
   actions=actions+1;eq(a.roofId1,2);eq(a.roofId2,3)
   eq(a.stop,ISTakeFuel.stop);eq(a.animEvent,ISTakeFuel.animEvent)
  end
 end
 eq(actions,3)
end)
test("native pump callbacks stay untouched even when menu building fails",function()
 fixture();local callback=W.onTakeFuelNew;W.doFillFuelMenu=function()error("fault")end
 eq(pcall(F.addCollectMenu,0,vehicle,menu()),false);eq(W.onTakeFuelNew,callback);W.doFillFuelMenu=nativePump
end)
test("mounted generator injects real object before original Java menu construction",function()
 fixture();local obj={getModData=function()return {vlsMountedGenerator=1}end}
 G.object=function()return obj end;W.fetchVars={c=0}
 local calls=0
 ISWorldObjectContextMenuLogic={fetch=function(fetch,object,pn,test)
  eq(object,obj);eq(pn,0);eq(test,true);calls=calls+1;fetch.generator=object;fetch.c=fetch.c+1
 end}
 VLS.generatorPreMenu(0);eq(calls,1);eq(W.fetchVars.generator,obj);eq(W.fetchVars.c,1)
 eq(G.addMenu,nil)
end)
test("explicitly clicked ordinary generator is preserved",function()
 fixture();local other={};W.fetchVars={generator=other}
 G.object=function()return {}end
 ISWorldObjectContextMenuLogic.fetch=function()error("must not replace clicked generator")end
 VLS.generatorPreMenu(0);eq(W.fetchVars.generator,other)
end)
test("native existing mounted menu keeps everything except duplicate pickup",function()
 fixture();local obj={getModData=function()return {vlsMountedGenerator=1}end};W.fetchVars={generator=obj}
 local c=menu();local parent=c:addOption("ContextMenu_Generator");local sub=menu();c:addSubMenu(parent,sub)
 sub:addOption("ContextMenu_GeneratorInfo");sub:addOption("ContextMenu_GeneratorTake")
 sub:addOption("ContextMenu_GeneratorAddFuel");sub:addOption("ContextMenu_GeneratorFix")
 VLS.generatorPostMenu(0,c);eq(#c.options,1);eq(#sub.options,3)
 eq(sub.options[2].name,"ContextMenu_GeneratorAddFuel");eq(sub.options[3].name,"ContextMenu_GeneratorFix")
end)
test("ordinary generator menu pickup remains available",function()
 fixture();W.fetchVars={generator={getModData=function()return {}end}}
 local c=menu();local parent=c:addOption("ContextMenu_Generator");local sub=menu();c:addSubMenu(parent,sub)
 sub:addOption("ContextMenu_GeneratorTake");VLS.generatorPostMenu(0,c);eq(#sub.options,1)
end)
test("native generator fuel callback retains original action and routes only mounted walking to vehicle area",function()
 local inv=fixture();local obj={getModData=function()return {vlsMountedGenerator=1}end,
  getSquare=function()return square end,getFuelPercentage=function()return 0 end}
 G.getOwner=function()return vehicle end
 local savedWalk=luautils.walkAdj;local ordinaryWalks=0
 luautils.walkAdj=function()ordinaryWalks=ordinaryWalks+1;return true end
 local walk=luautils.walkAdj
 vehicle.isInArea=function()return false end
 ISPathFindAction.pathToVehicleArea=function(_,chr,v,area)
  eq(chr,player);eq(v,vehicle);eq(area,vehicle.parts[G.PART]:getArea());return {Type="nativeVehiclePath"}
 end
 ISAddFuel={new=function(_,chr,g,item)return {Type="ISAddFuel",generator=g,petrol=item}end}
 W.doAddFuelGenerator({},obj,{inv.items[1],inv.items[2]},nil,0)
 eq(ordinaryWalks,0);eq(#queued,3);eq(queued[1].Type,"nativeVehiclePath")
 eq(queued[2].Type,"ISAddFuel");eq(queued[2].petrol,inv.items[1]);eq(queued[3].petrol,inv.items[2])
 eq(luautils.walkAdj,walk)
 obj.getModData=function()return {}end;queued={}
 W.doAddFuelGenerator({},obj,{},inv.items[1],0)
 eq(ordinaryWalks,1);eq(#queued,1);eq(queued[1].Type,"ISAddFuel")
 obj.getModData=function()return {vlsMountedGenerator=1}end
 local equip=W.equip;W.equip=function()error("native callback fault")end
 eq(pcall(W.doAddFuelGenerator,{},obj,{},inv.items[1],0),false);eq(luautils.walkAdj,walk)
 W.equip=equip;luautils.walkAdj=savedWalk
end)
test("late mounted tag hides only its object and invalidates cached rendering",function()
 FBORenderChunk={DIRTY_REDRAW=16}
 local function object()
  return {generator=true,md={},render=true,dirty=0,getModData=function(self)return self.md end,
   getObjectIndex=function()return 0 end,getDoRender=function(self)return self.render end,
   setDoRender=function(self,v)self.render=v end,invalidateRenderChunkLevel=function(self,why)
    eq(why,16);self.dirty=self.dirty+1
   end}
 end
 local original=instanceof;instanceof=function(o,k)return k=="IsoGenerator" and o.generator or original(o,k)end
 local mounted,ordinary=object(),object()
 VLS.generatorObjectAdded(mounted);VLS.generatorObjectAdded(ordinary)
 eq(mounted.render,true);eq(ordinary.render,true)
 mounted.md.vlsMountedGenerator=123;VLS.generatorVisualTick()
 eq(mounted.render,false);eq(mounted.dirty,1);eq(ordinary.render,true)
 VLS.generatorVisualTick();eq(mounted.dirty,1)
 mounted.render=true;VLS.generatorVisualTick();eq(mounted.render,false);eq(mounted.dirty,2)
 instanceof=original
end)
test("roof petrol uses generator area once while native Fill All and bag returns remain",function()
 local inv=fixture();vehicle.isInArea=function()return false end
 local savedWalk=luautils.walkAdj;local walks=0
 luautils.walkAdj=function()walks=walks+1;return true end;local walk=luautils.walkAdj
 ISPathFindAction.pathToVehicleArea=function(_,chr,v,area)
  eq(chr,player);eq(v,vehicle);eq(area,vehicle.parts[G.PART]:getArea());return {Type="servicePath"}
 end
 local bag={isInCharacterInventory=function()return true end};inv.items[1].getContainer=function()return bag end
 W.onTakeFuelNew({},F.capture(vehicle),inv.items,nil,0)
 eq(walks,0);eq(queued[1].Type,"servicePath");eq(#queued,5)
 eq(queued[2].Type,"VLSRoofFuelAction");eq(queued[3].Type,"return")
 eq(luautils.walkAdj,walk)
 local transfer=W.transferIfNeeded;W.transferIfNeeded=function()error("native equip failure")end
 eq(pcall(W.onTakeFuelNew,{},F.capture(vehicle),nil,inv.items[1],0),false)
 eq(luautils.walkAdj,walk);W.transferIfNeeded=transfer;luautils.walkAdj=savedWalk
end)
test("ordinary station keeps its original walk and original action",function()
 local inv=fixture();local old=luautils.walkAdj;local walks=0
 luautils.walkAdj=function()walks=walks+1;return true end
 local pump={getSquare=function()return square end,getPipedFuelAmount=function()return 50 end}
 W.onTakeFuelNew({},pump,nil,inv.items[1],0)
 eq(walks,1);eq(#queued,1);eq(queued[1].Type,"ISTakeFuel")
 luautils.walkAdj=old
end)
-- Cover the real roof registry, including vehicles with no interior profile.
for name in pairs(VLSRoofCargo.vehicleScripts)do
 test("installed roof menus across real vehicle profile "..name,function()
  local inv,gen,item=fixture(name)
  local c=menu();F.addCollectMenu(0,vehicle,c);eq(#c.options,1)
  vehicle.parts.VLSRoofPetrol1=nil;vehicle.parts.VLSRoofPetrol2=nil
  c=menu();F.addCollectMenu(0,vehicle,c);eq(#c.options,0)
  vehicle.parts.VLSRoofPetrol1={getInventoryItem=function()return item(20,"wrong",5,10,"Base.WaterBottle")end}
  c=menu();F.addCollectMenu(0,vehicle,c);eq(#c.options,0)
  vehicle.parts.VLSRoofPetrol1={getInventoryItem=function()return nil end}
  c=menu();F.addCollectMenu(0,vehicle,c);eq(#c.options,0)
  for kind in pairs(VLSRoofCargo.allowed[G.PART])do
   gen.kind=kind;assert(G.getPart(vehicle))
  end
  gen.kind="Base.Generator";gen.md.vlsGenerator={dock={x=1,y=2,z=0}}
  local obj={getModData=function()return {vlsMountedGenerator=gen.id}end}
  square.getSpecialObjects=function()return list({obj})end
  local originalInstanceof=instanceof
  instanceof=function(o,cls)return o==obj and cls=="IsoGenerator" end
  G.object=nativeGeneratorObject
  ISWorldObjectContextMenuLogic.fetch=function(fetch,o)fetch.generator=o end
  W.fetchVars={};VLS.generatorPreMenu(0);eq(W.fetchVars.generator,obj)
  gen.kind="Base.MetalBar"
  W.fetchVars={};VLS.generatorPreMenu(0);eq(W.fetchVars.generator,nil)
  gen.kind="Base.Generator";vehicle.parts[G.PART]={getInventoryItem=function()return nil end}
  W.fetchVars={};VLS.generatorPreMenu(0);eq(W.fetchVars.generator,nil)
  vehicle.parts[G.PART]=nil
  W.fetchVars={};VLS.generatorPreMenu(0);eq(W.fetchVars.generator,nil)
  instanceof=originalInstanceof
 end)
end
for _,name in ipairs({"Base.Trailer87Scamp13","Base.Trailer87Scamp16","Base.Trailer61Bambi16",
 "Base.Trailer54FlyingCloud22","Base.Trailer61Airflyte","Base.Trailer61Astrodome"})do
 test("KI5 has no VLS roof generator or petrol support "..name,function()
  fixture(name);eq(VLSRoofCargo.vehicleScripts[name],nil)
  eq(G.getPart(vehicle),nil);G.object=nativeGeneratorObject
  W.fetchVars={};VLS.generatorPreMenu(0);eq(W.fetchVars.generator,nil)
  local c=menu();F.addCollectMenu(0,vehicle,c);eq(#c.options,0)
 end)
end
print("RESULT native service menu tests="..n.." failures=0")
