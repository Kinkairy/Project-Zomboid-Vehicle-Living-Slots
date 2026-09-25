-- Top-space contract and real B42 native install/uninstall bodies; engine objects mocked.
local root,native=assert(arg[1]),assert(arg[2])
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/"
local function noop()end
local function eq(a,b)assert(a==b,tostring(a).." ~= "..tostring(b))end
local passed=0
local function test(name,fn)fn();passed=passed+1;print("PASS "..name)end
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(media.."lua/shared/VLS_Config.lua");package.loaded.VLS_Config=V
instanceof=function(o,k)return o and (k=="InventoryItem" or o.kind==k)end
getText=function(k)return k end
local function item(t,s)
 local o={kind="Moveable",type=t,sprite=s,condition=100,id=99}
 function o:getFullType()return self.type end
 function o:getScriptItem()return nil end
 function o:getWorldSprite()return self.sprite end
 function o:getDisplayName()return "native-cupboard-name"end
 function o:getCondition()return self.condition end
 function o:getConditionMax()return 100 end
 function o:setCondition(x)self.condition=x end
 function o:getID()return self.id end
 o.setItemCapacity=noop;o.setJobDelta=noop
 return o
end
local function container()
 local c={Capacity=0,Type="VLSPantryCoffee",OpenSound="",CloseSound="",PutSound="",TakeSound="",weight=0}
 for _,k in ipairs({"Capacity","Type","OpenSound","CloseSound","PutSound","TakeSound"})do
  c["get"..k]=function(self)return self[k]end;c["set"..k]=function(self,v)self[k]=v end
 end
 function c:getCapacityWeight()return self.weight end
 return c
end
local function vehicle(name)
 local v={parts={},name=name}
 function v:getScriptName()return self.name end
 function v:getPartById(id)return self.parts[id]end
 function v:getPartCount()return #self.order end
 function v:getPartByIndex(i)return self.order[i+1]end
 v.order={}
 local function part(id)
  local p={id=id,vehicle=v,container=container(),condition=100,data={}}
  function p:getId()return self.id end
  function p:getVehicle()return self.vehicle end
  function p:getInventoryItem()return self.item end
  function p:setInventoryItem(x)self.item=x end
  function p:getItemContainer()return self.container end
  function p:getContainerContentAmount()return self.container.weight end
  function p:getModData()return self.data end
  function p:getCondition()return self.condition end
  function p:setCondition(x)self.condition=x end
  function p:getItemType()return {isEmpty=function()return false end}end
  v.parts[id]=p;v.order[#v.order+1]=p;return p
 end
 return v,part
end
local catalog=require "VLS_OverheadCatalog"
local ordinary=item("Base.Mov_ModernCounter")

test("top slots share living category and offer only eight matching straight cupboards",function()
 eq(V.OVERHEAD_CATEGORY_ID,V.CATEGORY_ID)
 local f=assert(io.open(media.."scripts/VLS_ZTopSpaceVehicles.txt"));local script=f:read("*a");f:close()
 eq(script:find("category = VLSTopSpace",1,true),nil)
 local permitted,count={},0
 for _,entry in ipairs(catalog)do
  if entry.installable then permitted[entry.type]=true;count=count+1 end
 end
 eq(count,8)
 for row in script:gmatch("itemType = ([^\n]+),")do
  local n=0
  if row~="Base.VLSTopFrame" then
   for name in row:gmatch("[^;]+")do assert(permitted[name] or name=="Base.Mov_CoffeeMaker" or name=="Base.Mov_Toaster",name);n=n+1 end
   eq(n,10)
  end
 end
end)

for _,name in ipairs({"Base.SUV","Base.PickUpVan","Base.Van","Base.StepVan"})do
 test(name.." top storage is separate from living slots, with native names/capacity",function()
  local v,make=vehicle(name);make("VLSTopFrame1").item=item("Base.VLSTopFrame");local profile=V.getVehicleProfile(v)
  local wanted=name=="Base.StepVan" and 3 or name=="Base.Van" and 2 or 1
  eq(#profile.overheadParts,wanted)
  assert(not V.isOverheadPart(make("VLSOverhead4")))
  local floor=make(profile.universalParts[1]);eq(V.isAllowedItem(floor,ordinary),true)
  for _,id in ipairs(profile.overheadParts)do
   local p=make(id)
   make("VLSTopFrame"..V.getOverheadIndex({getId=function()return id end})).item=item("Base.VLSTopFrame")
   eq(V.getPartDisplayName(p),"IGUI_VehiclePartVLSOverhead1")
   eq(V.isAllowedItem(p,ordinary),false)
   for _,entry in ipairs(catalog)do
    for _,sprite in ipairs(entry.sprites)do
     local cabinet=item("Moveables.Moveable",sprite)
     eq(V.resolveEquipmentType(cabinet),entry.type)
     eq(V.isAllowedItem(p,cabinet),true);eq(V.isAllowedItem(floor,cabinet),false)
     eq(V.isInstallationEnabled(p,cabinet),entry.installable)
     eq(V.isGenericCraftSurfaceEquipment(cabinet),false)
     p.item=cabinet;V.ensureUniversalContainerProfile(p)
     eq(p.container:getCapacity(),50);eq(p.container:getType(),"overhead")
     eq(V.getPartDisplayName(p),"native-cupboard-name")
     eq(V.ContainerAccess.UniversalSlot(v,p,{getVehicle=function()return v end}),true)
     eq(V.ContainerAccess.UniversalSlot(v,p,{getVehicle=function()return nil end}),false)
     p.item=nil;V.ensureUniversalContainerProfile(p);eq(p.container:getCapacity(),0)
    end
   end
  end
  local invalid=make("VLSOverhead9");eq(V.isAllowedItem(invalid,item(catalog[1].type)),false)
  eq(V.isOverheadPart(invalid),false)
 end)
end
test("every existing vehicle family keeps its accepted living/passenger count",function()
 local n=0
 for name,profile in pairs(V.vehicleProfiles)do
  local wanted=profile.kind=="largeVan" and 3 or profile.kind=="mediumVan" and 2 or 1
  eq(#profile.overheadParts,wanted)
  eq(#profile.universalParts,profile.kind=="largeVan" and 5 or profile.kind=="mediumVan" and 3 or 1)
  eq(#profile.spacePassengers,#profile.universalParts);n=n+1
 end
 eq(n,97)
 eq(V.vehicleProfiles["Base.VanSeats"],nil)
end)
test("cabinet sandbox option gates new installation only",function()
 local v,make=vehicle("Base.Van");make("VLSTopFrame1").item=item("Base.VLSTopFrame");local p=make("VLSPantryCoffee");local i=item(catalog[1].type)
 SandboxVars={VehicleLivingSlots={EnableCabinets=false}}
 eq(V.isInstallationEnabled(p,i),false);p.item=i
 eq(V.getInstalledPart(v,p.id),p);eq(V.canUninstallManagedPart(p),true)
 SandboxVars=nil
end)
-- Verify the accepted native mechanical transaction against an actual top part.
ISBaseTimedAction={}
function ISBaseTimedAction:derive(n)local c={Type=n};c.__index=c;setmetatable(c,{__index=self});return c end
function ISBaseTimedAction.new(c,chr)return setmetatable({character=chr},{__index=c})end
package.loaded["TimedActions/ISBaseTimedAction"]=true
isClient=function()return false end;isServer=function()return true end
Perks={Mechanics=1};IsoObjectChange={MECHANIC_ACTION_DONE=1}
getGameTime=function()return {getCalender=function()return {getTimeInMillis=function()return 1 end}end}end
sendRemoveItemFromContainer=noop;sendAddItemToContainer=noop;playServerSound=noop;addXp=noop
LuaEventManager={AddEvent=noop};Events={OnUseVehicle={Add=noop},OnVehicleHorn={Add=noop}}
dofile(native.."/server/Vehicles/Vehicles.lua")
ZombRand=function()return 0 end
local success=100
VehicleUtils.getPerksTableForChr=function()return {}end
VehicleUtils.calculateInstallationSuccess=function()return success,0 end
VehicleUtils.callLua=function(fn,...)if type(fn)=="function"then return fn(...)end end
for _,name in ipairs({"ISInstallVehiclePart","ISUninstallVehiclePart"})do
 dofile(native.."/shared/Vehicles/TimedActions/"..name..".lua")
 package.loaded["Vehicles/TimedActions/"..name]=true
end
dofile(media.."lua/shared/VLS_InstallGuard.lua")
local inv={items={}}
function inv:contains(i)return self.items[i]==true end
function inv:containsID(id)for i in pairs(self.items)do if i:getID()==id then return true end end;return false end
function inv:DoRemoveItem(i)assert(self.items[i]);self.items[i]=nil end
function inv:AddItem(i)assert(not self.items[i]);self.items[i]=true end
function inv:hasRoomFor()return true end
local chr={getInventory=function()return inv end,isMechanicsCheat=function()return false end,
 isTimedActionInstant=function()return false end,getPerkLevel=function()return 10 end,removeFromHands=noop,
 addMechanicsItem=noop,sendObjectChange=noop,getCurrentSquare=function()return {}end}
local v,make=vehicle("Base.Van");make("VLSTopFrame1").item=item("Base.VLSTopFrame");local p=make("VLSPantryCoffee")
v.getMechanicalID=function()return 1 end;v.transmitPartItem=noop;v.transmitPartCondition=noop
v.canInstallPart=function()return not p.item end
function p:getTable()return {skills={},requireEmpty=true,complete=function()V.ensureUniversalContainerProfile(p)end}end
local cabinet=item("Moveables.Moveable",catalog[1].sprites[2])
test("native top cabinet install/uninstall/reinstall preserves exact item and sprite",function()
 inv.items[cabinet]=true
 for repeatIndex=1,3 do
  local a=ISInstallVehiclePart:new(chr,p,cabinet,200);assert(a:isValid());assert(a:complete())
  eq(p.item,cabinet);eq(p.container:getCapacity(),50);eq(inv.items[cabinet],nil)
  assert(ISUninstallVehiclePart:new(chr,p,200):complete())
  eq(p.item,nil);eq(p.container:getCapacity(),0);eq(inv.items[cabinet],true)
  eq(cabinet.sprite,catalog[1].sprites[2])
 end
end)
test("top frame is required at native queue validation and completion",function()
 local frame=v.parts.VLSTopFrame1;local saved=frame.item
 inv.items[cabinet]=true
 local a=ISInstallVehiclePart:new(chr,p,cabinet,200);assert(a:isValid())
 frame.item=nil;eq(a:isValid(),false);eq(a:complete(),false);eq(inv.items[cabinet],true);eq(p.item,nil)
 frame.item=saved;saved.condition=0;eq(a:isValid(),false);eq(a:complete(),false)
 saved.condition=100;assert(a:complete());eq(p.item,cabinet)
 -- Existing storage can still be emptied and removed even if the frame vanished.
 frame.item=nil;eq(V.getInstalledPart(v,p.id),p);assert(ISUninstallVehiclePart:new(chr,p,200):complete())
 eq(inv.items[cabinet],true);frame.item=saved
end)
test("retired shop/corner cupboards cannot install but already fitted storage stays usable",function()
 for _,entry in ipairs(catalog)do
  if not entry.installable then
   local retired=item("Moveables.Moveable",entry.sprites[1]);inv.items[retired]=true
   eq(ISInstallVehiclePart:new(chr,p,retired,200):isValid(),false)
   inv.items[retired]=nil;p.item=retired;V.ensureUniversalContainerProfile(p)
   eq(p.container:getCapacity(),50);eq(V.getInstalledPart(v,p.id),p)
   eq(V.canUninstallManagedPart(p),true)
   assert(ISUninstallVehiclePart:new(chr,p,200):complete());eq(p.item,nil)
   eq(inv.items[retired],true)
  end
 end
end)
test("floor cabinet cannot enter top native action queue",function()
 inv.items[ordinary]=true;eq(ISInstallVehiclePart:new(chr,p,ordinary,200):isValid(),false)
end)
test("native uninstall refuses a filled top cupboard",function()
 local a=ISInstallVehiclePart:new(chr,p,cabinet,200);assert(a:complete())
 p.container.weight=1
 ISVehicleMechanics={cheat=false}
 round=function(x,n)local a=10^n;return math.floor(x*a+0.5)/a end
 chr.getPlayerNum=function()return 0 end
 VehicleUtils.getItems=function()return {},{}end
 for _,key in ipairs({"testProfession","testRecipes","testTraits","testItems"})do VehicleUtils[key]=function()return true end end
 VehicleUtils.RequiredKeyNotFound=function()return false end
 function p:getContainerSeatNumber()return -1 end
 function p.container:isEmpty()return self.weight==0 end
 function v:canUninstallPart(c,part)return V.UninstallTest.UniversalSlot(self,part,c)end
 local u=ISUninstallVehiclePart:new(chr,p,200);eq(u:isValid(),false)
 eq(p.item,cabinet);eq(inv.items[cabinet],nil);p.container.weight=0
end)
-- Run the real vanilla condition calculation underneath the shared UI adapter.
local f=assert(io.open(native.."/client/Vehicles/ISUI/ISVehicleMechanics.lua"));local nativeUI=f:read("*a");f:close()
local renderedRow
ISVehicleMechanics={doMenuTooltip=noop,doPartContextMenu=noop,doDrawItem=function(self,y,row)renderedRow=row;return y end,initParts=noop,
 renderCarOverlayTooltip=noop,getConditionRGB=noop}
local body=assert(nativeUI:match("(function ISVehicleMechanics:recalculGeneralCondition%(%)%s*.-\nend)"))
assert((loadstring or load)(body))()
package.loaded["Vehicles/ISUI/ISVehicleMechanics"]=true
package.loaded["Vehicles/ISUI/ISVehiclePartMenu"]=true
ISVehiclePartMenu={}
dofile(media.."lua/client/VLS_VehicleMechanicsIcons.lua")
test("empty optional top slots leave healthy vehicle at 100 percent",function()
 local car,make=vehicle("Base.StepVan")
 local engine=make("Engine");engine.item={}
 for i=1,3 do make(VLS.OVERHEAD_PART_IDS[i])end
 make("VLSTopFrame1")
 local ui=setmetatable({vehicle=car},{__index=ISVehicleMechanics})
 ui:recalculGeneralCondition();eq(ui.generalCondition,100)
 engine.condition=80;ui:recalculGeneralCondition();eq(ui.generalCondition,80)
 engine.condition=100
 local top=car.parts.VLSPantryCoffee;top.item=item(catalog[1].type);top.condition=50;top.item.condition=50
 ui:recalculGeneralCondition();eq(ui.generalCondition,75)
end)

test("each slot requires its own frame and accepts either cupboard or original small appliance",function()
 local P=dofile(media.."lua/shared/VLS_Pantry.lua")
 local car,make=vehicle("Base.StepVan")
 local frames,slots={},{}
 for n=1,3 do frames[n]=make("VLSTopFrame"..n);slots[n]=make(VLS.OVERHEAD_PART_IDS[n])end
 local coffee=item("Base.Mov_CoffeeMaker");local toast=item("Base.Mov_Toaster");local cupboard=item(catalog[1].type)
 for n=1,3 do
  eq(V.isInstallationEnabled(slots[n],coffee),false)
  eq(V.isInstallationEnabled(slots[n],cupboard),false)
 end
 frames[2].item=item("Base.VLSTopFrame")
 for _,it in ipairs({coffee,toast,cupboard})do
  eq(V.isAllowedItem(slots[2],it),true);eq(V.isInstallationEnabled(slots[2],it),true)
  eq(V.isInstallationEnabled(slots[1],it),false);eq(V.isInstallationEnabled(slots[3],it),false)
 end
 SandboxVars={VehicleLivingSlots={EnableSmallAppliances=false,EnableCabinets=true}}
 eq(V.isInstallationEnabled(slots[2],coffee),false);eq(V.isInstallationEnabled(slots[2],cupboard),true)
 SandboxVars.VehicleLivingSlots.EnableSmallAppliances=true;SandboxVars.VehicleLivingSlots.EnableCabinets=false
 eq(V.isInstallationEnabled(slots[2],coffee),true);eq(V.isInstallationEnabled(slots[2],cupboard),false)
 SandboxVars=nil
end)
test("one, two or three top rows display, before and after independent construction",function()
 -- Execute the actual pantry provider registration, not a second UI implementation.
 local f=assert(io.open(media.."lua/client/VLS_PantryMenu.lua"));local src=f:read("*a");f:close()
 local begin=assert(src:find('VLS.registerMechanicsUIProvider("pantry", {',1,true))
 local finish=assert(src:find('\n})',begin,true))+2
 local registration=src:sub(begin,finish)
 assert((loadstring or load)("local P=VLSPantry\n"..registration))()
 for _,name in ipairs({"Base.SUV","Base.PickUpVan","Base.Van","Base.StepVan"})do
  local car,make=vehicle(name);local count=#V.getVehicleProfile(car).overheadParts
  local engine=make("Engine");engine.item=item("Base.TestEngine")
  local frames,slots={},{ }
  for n=1,count do frames[n]=make("VLSTopFrame"..n);slots[n]=make(VLS.OVERHEAD_PART_IDS[n])end
  local function panel()
   local rows={{item={cat=true,name="Living"}}}
   for n=1,count do rows[#rows+1]={item={part=frames[n]}};rows[#rows+1]={item={part=slots[n]}}end
   local list={items=rows,selected=2,mouseoverselected=2}
   function list:removeItemByIndex(i)table.remove(self.items,i)end
   return setmetatable({vehicle=car,listbox=list},{__index=ISVehicleMechanics})
  end
  local ui=panel();ui:initParts();eq(#ui.listbox.items,count+1);eq(ui.generalCondition,100)
  for n=1,count do eq(ui.listbox.items[n+1].item.part,frames[n])end
  frames[count].item=item("Base.VLSTopFrame");ui=panel();ui:initParts();eq(#ui.listbox.items,count+1)
  if count>1 then eq(ui.listbox.items[2].item.part,frames[1]) end;eq(ui.listbox.items[count+1].item.part,slots[count])
  eq(ui.listbox.items[count+1].item.name,"IGUI_VehiclePartVLSOverhead1")
  ui:doDrawItem(0,ui.listbox.items[count+1],false)
  eq(renderedRow.item.part:getInventoryItem(),nil)
  eq(frames[count].item:getCondition(),100);eq(ui.generalCondition,100)
  -- Empty equipment stays natively red; the installed frame and vehicle condition remain healthy.
  eq(ui.listbox.items[count+1].item.part,slots[count])
  slots[count].item=item(catalog[1].type);ui=panel();ui:initParts();eq(#ui.listbox.items,count+1)
  eq(ui.listbox.items[count+1].item.name,"native-cupboard-name")
  slots[count].item=nil;frames[count].item=nil;ui=panel();ui:initParts();eq(#ui.listbox.items,count+1)
  eq(ui.listbox.items[count+1].item.part,frames[count]);eq(ui.generalCondition,100)
 end
end)
package.loaded.VLS_Propane=true
dofile(root.."/workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media/lua/shared/VLS_KI5Campers_Config.lua")
for _,name in ipairs({"Trailer87Scamp13","Trailer87Scamp16","Trailer61Bambi16","Trailer54FlyingCloud22","Trailer61Airflyte","Trailer61Astrodome"})do
 test(name.." top count is living minus one, shared cupboard/appliance gating",function()
  local car,make=vehicle("Base."..name);local profile=V.getVehicleProfile(car)
  eq(#profile.overheadParts,#profile.universalParts-1)
  for n,id in ipairs(profile.overheadParts)do
   local frame=make("VLSTopFrame"..n);local slot=make(id)
   local coffee=item("Base.Mov_CoffeeMaker");local cupboard=item(catalog[1].type)
   eq(V.isInstallationEnabled(slot,coffee),false);eq(V.isInstallationEnabled(slot,cupboard),false)
   frame.item=item("Base.VLSTopFrame")
   eq(V.isInstallationEnabled(slot,coffee),true);eq(V.isInstallationEnabled(slot,cupboard),true)
  end
  eq(V.isOverheadPart(make(VLS.OVERHEAD_PART_IDS[#profile.overheadParts+1] or "VLSOverhead4")),false)
 end)
end
test("same open panel restores paired native rows through installation and removal",function()
 for _,name in ipairs({"Base.SUV","Base.PickUpVan","Base.Van","Base.StepVan","Base.Trailer54FlyingCloud22"})do
  local car,make=vehicle(name);local count=#V.getVehicleProfile(car).overheadParts
  local frames,slots,rows={},{},{{item={cat=true,name="Living"}}}
  for n=1,count do
   frames[n]=make("VLSTopFrame"..n);slots[n]=make(VLS.OVERHEAD_PART_IDS[n])
   rows[#rows+1]={item={part=frames[n]},height=20}
   rows[#rows+1]={item={part=slots[n]},height=20}
  end
  local unrelated={item={part=make("Engine")},height=20};rows[#rows+1]=unrelated
  local list={items=rows,selected=count*2,mouseoverselected=count*2,scroll=-60}
  function list:removeItemByIndex(i)table.remove(self.items,i)end
  local ui=setmetatable({vehicle=car,listbox=list,leftListSelection=count*2},{__index=ISVehicleMechanics})
  ui:initParts()
  local function check(part)
   eq(#list.items,count+2);eq(list.items[count+1].item.part,part)
   eq(list.items[#list.items],unrelated);eq(list.scroll,-60)
   eq(list.selected,count+1);eq(list.mouseoverselected,count+1);eq(ui.leftListSelection,count+1)
   for i,row in ipairs(list.items)do eq(row.itemindex,i);eq(row.index,i)end
  end
  check(frames[count])
  for cycle=1,3 do
   frames[count].item=item("Base.VLSTopFrame");ui:recalculGeneralCondition();check(slots[count])
   eq(list.items[count+1].item.name,"IGUI_VehiclePartVLSOverhead1")
   ui:doDrawItem(0,list.items[count+1],false);eq(renderedRow.item.part:getInventoryItem(),nil)
   local cabinet=item(catalog[1].type);slots[count].item=cabinet
   ui:recalculGeneralCondition();check(slots[count]);eq(list.items[count+1].item.name,"native-cupboard-name")
   slots[count].item=nil;ui:recalculGeneralCondition();check(slots[count])
   frames[count].item=nil;ui:recalculGeneralCondition();check(frames[count])
   eq(list.items[count+1].item.name,"IGUI_VehiclePartVLSTopFrame"..count)
  end
  -- An unrelated selected row stays selected while another slot changes.
  list.selected=#list.items;list.mouseoverselected=#list.items;ui.leftListSelection=#list.items
  frames[1].item=item("Base.VLSTopFrame");ui:recalculGeneralCondition()
  eq(list.items[list.selected],unrelated);eq(list.items[list.mouseoverselected],unrelated)
  eq(list.items[ui.leftListSelection],unrelated)
  local visible=list.items[2]
  for i=1,100 do ui:recalculGeneralCondition();eq(list.items[2],visible)end
  eq(#list.items,count+2)
 end
end)
print("RESULT top-space tests="..passed.." failures=0 (native Lua bodies; mocked engine)")
