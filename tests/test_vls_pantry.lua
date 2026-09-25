local root = assert(arg[1])
local native = assert(arg[2])
local count = 0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn(); count=count+1; print("PASS "..name) end
local function noop() end
local function list(items)
    items=items or {}
    function items:size() return #self end
    function items:get(i) return self[i+1] end
    function items:add(x) self[#self+1]=x end
    function items:contains(x) for _,v in ipairs(self) do if v==x then return true end end;return false end
    return items
end
ArrayList={new=function()return list()end}
function instanceof(x,t) return x and x.kind==t or false end
package.loaded["VLS_Config"]=nil
local V={allowedItems={},mechanicsDisplayProviders={},installationOptionProviders={}}
V.isSupportedVehicle=function(v)return v and v.supported end
V.isOverheadPart=function(p)return p and (p:getId()=="VLSPantryCoffee" or p:getId():match("^VLSOverhead[1-2]$")~=nil) end
V.resolveEquipmentType=function()return "old" end
V.getEquipmentProfileByType=function()return nil end
V.isAllowedItem=function(p)if p and p:getId():match("^VLSOverhead")then return false end;return "old" end
V.isInstallationEnabled=function(p)return not p or p.frameReady~=false end
V.hasTopFrame=function(p)return p and p.frameReady~=false end
V.getSmallApplianceDrainPerUse=function()return 0.0004 end
V.walkApplianceContainer=function(inv,fn) for _,i in ipairs(inv.items or {})do fn(i)end end
V.hasAuxBatteryPower=function(v,n)return v.charge and v.charge>=n end
V.consumeAuxBattery=function(v,n)v.charge=v.charge-n;v.debits=(v.debits or 0)+1 end
V.OVERHEAD_PART_IDS={"VLSPantryCoffee","VLSOverhead1","VLSOverhead2"}
VLS=V;package.loaded["VLS_Config"]=V;package.loaded["VLS_InstallGuard"]=true
ISInstallVehiclePart={complete=function(a)a.nativeInstalled=true;return true end}
local base=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
local sharedInstallComplete = ISInstallVehiclePart.complete
local P=dofile(base.."shared/VLS_Pantry.lua")
package.loaded["VLS_Pantry"]=P
local recipes={}
for _,def in pairs(P.choices)do
 local r={name=def.recipe,getTimedActionScript=function()return nil end,getTime=function()return 20 end,isCanWalk=function()return false end,isAnySurfaceCraft=function()return false end}
 recipes[def.recipe]=r
end
ScriptManager={instance={getCraftRecipe=function(_,id)return recipes[id]end}}
local inventory={items={}}
local character={getInventory=function()return inventory end,hasTrait=function()return false end,isWearingAwkwardGloves=function()return false end,isTimedActionInstant=function()return false end}
local vehicle={supported=true,stopped=true,charge=1,parts={},getId=function()return 17 end}
function vehicle:getPartById(id)return self.parts[id]end
function vehicle:isStopped()return self.stopped end
function character:getVehicle()return self.vehicle end
character.vehicle=vehicle
local function item(ft,sprite,id)
 return {kind="Moveable",getFullType=function()return ft end,getWorldSprite=function()return sprite end,getID=function()return id or 42 end,
 getCondition=function(self)return self.condition or 100 end,setJobDelta=noop,setJobType=noop}
end
local coffee=item("Base.Mov_CoffeeMaker",nil,42)
local toaster=item("Base.Mov_Toaster",nil,43)
-- Include an old saved-part fixture to verify it is rejected.
for _,id in ipairs({P.PART_ID,"VLSPantryToaster"})do
 local part={id=id,item=id=="VLSPantryCoffee" and coffee or nil}
 function part:getId()return self.id end
 function part:getVehicle()return vehicle end
 function part:getInventoryItem()return self.item end
 function part:setInventoryItem(i)self.item=i end
 vehicle.parts[id]=part
end
test("one flexible slot accepts either appliance without accepting other furniture",function()
 assert(P.canInstall(vehicle.parts.VLSPantryCoffee,coffee))
 assert(P.canInstall(vehicle.parts.VLSPantryCoffee,toaster))
 assert(not P.canInstall(vehicle.parts.VLSPantryCoffee,item("Base.Wood",nil,44)))
 assert(not P.canInstall(vehicle.parts.VLSPantryToaster,toaster))
end)
test("small-appliance sandbox disables only new installation",function()
 local enabled=V.isInstallationEnabled
 V.isInstallationEnabled=function()return false end
 assert(not P.canInstall(vehicle.parts.VLSPantryCoffee,coffee))
 assert(P.accepts(vehicle.parts.VLSPantryCoffee,coffee))
 V.isInstallationEnabled=enabled
end)
test("retired toaster part cannot install or provide crafting authority",function()
 local part=vehicle.parts.VLSPantryToaster
 part.item=toaster;assert(not P.isPart(part));assert(not P.accepts(part,toaster))
 assert(not P.canInstall(part,toaster));assert(P.reason(character,vehicle,part.id))
 eq(P.choiceForRecipe(P.recipe("toast"),part.id,toaster),nil)
 part.item=nil;assert(not P.accepts(part,nil))
end)
test("six native moveable orientations",function()
 for i=56,59 do eq(P.resolveType(item("Moveables.Furniture","appliances_cooking_01_"..i)),"Base.Mov_CoffeeMaker")end
 for i=32,33 do eq(P.resolveType(item("Moveables.Furniture","ct_oac_appliances_cooking_01_"..i)),"Base.Mov_Toaster")end
 eq(P.resolveType(item("Base.Wood","unknown")),nil)
end)
test("unrelated VLS install rules preserved",function() eq(V.isAllowedItem({getId=function()return "old"end},coffee),"old")end)
test("wrong vehicle and stale part denied",function()
 vehicle.supported=false;assert(not P.accepts(vehicle.parts.VLSPantryCoffee,coffee));vehicle.supported=true
 local copy={getId=function()return "VLSPantryCoffee"end,getVehicle=function()return vehicle end}
 assert(not P.accepts(copy,coffee))
end)
test("inside required and movement does not block appliance",function()
 character.vehicle=nil;assert(P.reason(character,vehicle,"VLSPantryCoffee"));character.vehicle=vehicle
 vehicle.stopped=false;eq(P.reason(character,vehicle,"VLSPantryCoffee"),nil);vehicle.stopped=true
 eq(P.reason(character,vehicle,"VLSPantryCoffee"),nil)
end)
test("missing broken swapped and unpowered denied",function()
 local part=vehicle.parts.VLSPantryCoffee;part.item=nil;assert(P.reason(character,vehicle,part.id));part.item=coffee
 coffee.condition=0;assert(P.reason(character,vehicle,part.id));coffee.condition=100
 assert(P.reason(character,vehicle,part.id,999))
 vehicle.charge=0;assert(P.reason(character,vehicle,part.id));vehicle.charge=1
end)
test("pantry preserves the shared installation completion function",function()
 eq(ISInstallVehiclePart.complete,sharedInstallComplete)
end)

-- Load the actual game action rather than a copy of its transaction.
ISBaseTimedAction={}
function ISBaseTimedAction:derive(name)local c={Type=name};c.__index=c;setmetatable(c,{__index=self});return c end
function ISBaseTimedAction.new(class,chr)return setmetatable({character=chr},{__index=class})end
ISBaseTimedAction.stop=noop;ISBaseTimedAction.perform=noop
package.loaded["TimedActions/ISBaseTimedAction"]=true
dofile(native.."/shared/Entity/TimedActions/ISHandcraftAction.lua")
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
function log()end
DebugType={CraftLogic=1};CharacterTrait={ALL_THUMBS=1}
convertToPZNetTable=function(x)assert(type(x)=="table", "expected KahluaTable");return x end
getVehicleById=function(id)return id==17 and vehicle or nil end
local client,server=false,true
isClient=function()return client end;isServer=function()return server end
local outputCount=0
Actions={addOrDropItem=function()outputCount=outputCount+1 end}
CraftRecipeManager={isValidRecipeForCharacter=function()return true end}
local canCraft=true
local nativeFail=false
local observedManual
HandcraftLogic={new=function(chr, bench, object)
 local data={getAllInputItems=function()return list()end,getVariableInputRatio=function()return 1 end,
 luaCallOnCreate=noop,processDestroyAndUsedItems=noop,getAllConsumedItems=function()return list()end}
 local logic={recipe=nil,manual=false,containers=list(),bench=bench,object=object}
 function logic:getCraftBench()return self.bench end
 function logic:getIsoObject()return self.object end
 function logic:addEventListener(name,callback,target)
  self.listeners=self.listeners or {};self.listeners[name]={callback,target}
 end
 function logic:setIsoObject(object)self.object=object end
 function logic:getRecipe()return self.recipe end
 function logic:filterRecipeList(filter)self.filter=filter end
 function logic:getRecipeList()return {getFirstRecipe=function()
  return self.filter and self.filter:find("BreadSlices",1,true) and P.recipe("toast") or P.recipe("coffeeMug")
 end}end
 logic.shouldShowManualSelectInputs=function()return false end
 function data:getRecipe()return logic.recipe end
 function data:canPerform(c,res,inputs,check,containers)
  assert(c==chr and res==logic.resources and check==true and containers==logic.containers)
  observedManual=inputs==nil
  return canCraft
 end
 logic.resources=list();logic.all=list()
 function logic:getRecipeData()return data end
 function logic:getPlayer()return chr end
 function logic:isUsingRecipeAtHandBenefit()return false end
 function logic:getContainers()return self.containers end
 function logic:isContainersAccessible()return true end
 function logic:getSourceResources()return self.resources end
 function logic:getAllItems()return self.all end
 function logic:isManualSelectInputs()return self.manual end
 function logic:setManualSelectInputs(b)self.manual=b end
 function logic:setContainers(c)self.containers=c end
 function logic:setRecipe(r)
  self.recipe=r
  local event=self.listeners and self.listeners.onRecipeChanged
  if event then event[1](event[2],r)end
 end
 function logic:setTargetVariableInputRatio()end
 function logic:clearManualInputs()end
 function logic:canPerformCurrentRecipe()return false end -- native world bench unavailable
 function logic:performCurrentRecipe()return not nativeFail end
 function logic:getCreatedOutputItems(out)out:add({getModData=function()return {}end})end
 return logic
end}
dofile(arg[4] or (base.."shared/VLS_PantryCraftAction.lua"))
local function action(choice)
 vehicle.parts.VLSPantryCoffee.item=choice=="toast" and toaster or coffee
 local a=VLSPantryCraftAction:new(character,17,P.PART_ID,choice=="toast" and 43 or 42,choice,nil,nil,nil)
 a.netAction={forceComplete=function()a.forced=true end}
 return a
end
test("native action creates and preserves primitive authority",function()
 local a=action("coffeeMug");assert(a:isValid());a:serverStart();assert(a.logic);assert(not a.forced)
 eq(a.isoObject,nil);eq(a.craftBench,nil);eq(a.variableInputRatio,1)
end)
test("each original recipe executes once",function()
 for _,choice in ipairs(P.choiceOrder)do
  local a=action(choice);a:serverStart();local outputs=outputCount;local debits=vehicle.debits or 0
  a:complete();eq(outputCount,outputs+1);eq(vehicle.debits,debits+1)
  a:complete();eq(outputCount,outputs+1);eq(vehicle.debits,debits+1)
 end
end)
test("failure consumes no electricity",function()
 local a=action("toast");a:serverStart();nativeFail=true
 local n=vehicle.debits;local outputs=outputCount;a:complete()
 eq(vehicle.debits,n);eq(outputCount,outputs);nativeFail=false
end)
for _,case in ipairs({"leave","remove","replace","power","break"})do
 test("completion rejects "..case,function()
  local a=action("coffeeMug");a:serverStart();local n=outputCount
  if case=="leave"then character.vehicle=nil
  elseif case=="remove"then vehicle.parts.VLSPantryCoffee.item=nil
  elseif case=="replace"then vehicle.parts.VLSPantryCoffee.item=item("Base.Mov_CoffeeMaker",nil,999)
  elseif case=="power"then vehicle.charge=0 elseif case=="break"then coffee.condition=0 end
  a:complete();eq(outputCount,n)
  character.vehicle=vehicle;vehicle.stopped=true;vehicle.parts.VLSPantryCoffee.item=coffee;vehicle.charge=1;coffee.condition=100
 end)
end
test("native missing-input failure stops server safely",function()
 local a=action("toast");canCraft=false;a:serverStart();assert(a.finished and a.forced);canCraft=true
end)
test("malformed network descriptors rejected",function()
 for _,value in ipairs({0/0,math.huge,1.5,"17"})do local a=action("toast");a.vehicleId=value;assert(not a:isValid())end
 local a=action("toast");a.choice="unknown";assert(not a:isValid())
end)
test("manual input mode preserved by native validator",function()
 local logic,recipe=P.newLogic(character,"toast")
 logic:setManualSelectInputs(true);assert(P.canCraft(character,logic,recipe));eq(observedManual,true)
 logic:setManualSelectInputs(false);assert(P.canCraft(character,logic,recipe));eq(observedManual,false)
end)
test("local logic interception preserves constructor, identity and nested actions",function()
 local a=action("toast");local original=HandcraftLogic.new;local meta=getmetatable(a)
 a:withNativeLogic(function(current)
  eq(current,a);eq(HandcraftLogic.new,original)
  current.logic=HandcraftLogic.new(character,nil,nil)
  local unrelated=HandcraftLogic.new(character,nil,nil)
  assert(current.logic~=unrelated)
  -- The nested constructor is still the original engine entry during execution.
  eq(HandcraftLogic.new,original)
  current.nativeStateWritten=true
 end)
 eq(getmetatable(a),meta);eq(a.nativeStateWritten,true);assert(a.logic)
 local before=a.logic
 local ok=pcall(function()a:withNativeLogic(function(current)
  eq(current,a);eq(HandcraftLogic.new,original);error("injected")
 end)end)
 eq(ok,false);eq(HandcraftLogic.new,original);eq(getmetatable(a),meta);eq(a.logic,before)
end)
test("client completion cannot create outputs",function()
 local a=action("toast");a:serverStart();local n=outputCount
 client=true;a:performRecipe();client=false;eq(outputCount,n)
end)
print("RESULT pantry tests="..count.." failures=0")

-- Menu adapters preserve native objects at Java boundaries and never serialize
-- the UI backing entity in a craft action.
package.loaded["VLS_PantryCraftAction"]=VLSPantryCraftAction
package.loaded["VLS_Client"]=true
package.loaded["VLS_VehicleMechanicsIcons"]=true
package.loaded["ISUI/Crafting/ISHandcraftWindow"]=true
package.loaded["Entity/ISUI/CraftRecipe/ISHandCraftPanel"]=true
V.registerMechanicsUIProvider=function(id,provider)V.pantryProvider=provider end
V.getMechanicsPreviewTexture=function()return nil end
getText=function(key)return key end
getTexture=function(path)return path end
UIFont={Small=1}
local square={DistToProper=function()return 0 end}
local vehicleSquare={farFromOccupant=true}
vehicle.getSquare=function()return vehicleSquare end
vehicle.getProperties=function()return nil end
V.genericSurface=vehicle
character.getSquare=function()return square end
character.getPlayerNum=function()return 0 end
coffee.getDisplayName=function()return "Coffee maker" end
toaster.getDisplayName=function()return "Toaster" end
coffee.getTex=getTexture;toaster.getTex=getTexture
local scriptNames={}
ScriptManager.instance.getGameEntityScript=function(_,id)
 scriptNames[#scriptNames+1]=id
 return {getComponentScriptFor=function(_,kind)return {kind=kind,query=id=="Base.Toaster" and "Toaster" or "CoffeeMachine"}end}
end
ComponentType={}
for _,id in ipairs({"CraftBench","Script"})do
 local kind={id=id};ComponentType[id]=kind
 kind.CreateComponentFromScript=function(self,def)
  eq(def.kind,self);return {kind=self,getRecipeTagQuery=function()return def.query end}
 end
 kind.CreateComponent=function(self)return {kind=self,setOriginalScript=function(s,v)s.script=v end}end
end
local networkWrites=0
IsoObject={new=function()
 local obj={components={},setSquare=function(self,s)self.square=s end,setSprite=function(self,s)self.sprite=s end,
 setUsingPlayer=function()networkWrites=networkWrites+1 end}
 function obj:getComponent(k)return self.components[k]end
 function obj:getProperties()return nil end
 return obj
end}
GameEntityFactory={AddComponent=function(obj,component)obj.components[component.kind]=component end}
-- Run the actual native window opener, window constructor/createChildren and
-- handcraft-panel constructor. Stub rendering widgets, not the bench binding.
local widget={}
widget.__index=widget
function widget:new(x,y,w,h)return setmetatable({x=x,y=y,width=w,height=h,borderColor={},backgroundColor={},backgroundColorMouseOver={},resizeWidget={},resizeWidget2={}},self)end
function widget:derive(name)local c={Type=name};c.__index=c;setmetatable(c,{__index=self});return c end
for _,method in ipairs({"initialise","createChildren","addChild","setVisible","setWantKeyEvents","setImage","setUIName","addToUIManager","removeFromUIManager","bringToTop","update","prerender","close","xuiRecalculateLayout"})do widget[method]=noop end
function widget:instantiate()
 if self.Type=="ISHandcraftWindow" then self:createChildren()
 elseif self.Type=="ISHandCraftPanel" then
  local panel=self
  self.recipesPanel={onRecipeChanged=noop,updateContainers=noop,filterRecipeList=noop,
   recipeFilterPanel={filterTypeCombo={setSelected=function(_,n)panel.fixtureFilterMode=n end},
    searchEntryBox={setText=function(_,text)panel.fixtureFilterText=text end}}}
  self.inventoryPanelColumn={};self.inventoryPanel={updateContainers=noop}
 else self.title={name=self.titleStr}end
end
function widget:titleBarHeight()return 20 end
function widget:getWidth()return self.width end
function widget:getHeight()return self.height end
function widget:getX()return self.x end
function widget:getY()return self.y end
function widget:setX(x)self.x=x end
function widget:setY(y)self.y=y end
ISPanel=widget;ISCollapsableWindow=widget;ISButton=widget;ISHandcraftWindowHeader=widget
ISUIElement={stayOnSplitScreen=noop}
package.loaded["ISUI/ISPanel"]=true;package.loaded["ISUI/ISCollapsableWindow"]=true
Events={OnPlayerDeath={Add=noop},OnPostSave={Add=noop}}
JoypadState={players={}}
getCore=function()return {getScreenWidth=function()return 1920 end,getScreenHeight=function()return 1080 end,getGameMode=function()return "Sandbox" end}end
getFileReader=function()return {readLine=function()return nil end,close=noop} end
XuiManager={GetDefaultSkin=function()return {}end}
ISXuiSkin={build=function(skin,style,class,...)
 local ui=class:new(...);ui.xuiSkin=skin;ui.xuiStyleName=style;return ui
end}
dofile(native.."/client/Entity/ISEntityUI.lua")
ISEntityUI.FindCraftSurface=function()return V.genericSurface end
dofile(native.."/client/ISUI/Crafting/ISHandcraftWindow.lua")
dofile(native.."/client/Entity/ISUI/CraftRecipe/ISHandCraftPanel.lua")
ISHandcraftWindow.calculateLayout=noop
local getNativeContainers=function()return "native-containers"end
ISInventoryPaneContextMenu={getContainers=getNativeContainers}
ISHandCraftPanel.updateContainers=function(self)return ISInventoryPaneContextMenu.getContainers(self.player)end
local failures={}
HaloTextHelper={addBadText=function(_,reason)failures[#failures+1]=reason end}
local function opened()return ISEntityUI.GetWindowInstance(0,"HandcraftWindow")end
local menu={slices={},addToUIManager=noop}
function menu:addSlice(...)self.slices[#self.slices+1]={...}end
getPlayerRadialMenu=function()return menu end
ISVehicleMenu={showRadialMenu=function()menu:addToUIManager()end}
dofile(arg[3] or (base.."client/VLS_PantryMenu.lua"))
package.loaded["VLS_PantryMenu"]=true
test("same flexible slot opens the installed device native menu",function()
 for _,device in ipairs({coffee,toaster})do
  vehicle.parts.VLSPantryCoffee.item=device
  P.openAppliance(character,vehicle,P.PART_ID)
  local source=P.uiSources[opened().isoObject]
  local spec=P.devices[P.resolveType(device)]
  eq(source.object.square,square);eq(source.object.sprite,spec.sprite)
  assert(source.object:getComponent(ComponentType.CraftBench))
  eq(opened().handCraftPanel.craftBench,source.bench)
  eq(opened().handCraftPanel.logic:getCraftBench(),source.bench)
  eq(opened().handCraftPanel.tooltipLogic:getCraftBench(),source.bench)
  eq(opened().handCraftPanel.logic:getIsoObject(),source.object)
  eq(opened().handCraftPanel.recipeQuery,source.bench:getRecipeTagQuery())
  eq(#failures,0)
  eq(scriptNames[#scriptNames],spec.entity)
  eq(source.character,character)
 end
 vehicle.parts.VLSPantryCoffee.item=coffee
 eq(networkWrites,0)
end)
test("UI backing objects never enter native timed action serialization",function()
 P.openAppliance(character,vehicle,"VLSPantryCoffee")
 local source=P.uiSources[opened().isoObject]
 local a=ISHandcraftAction:new(character,P.recipe("coffeeMug"),list(),source.object,
  source.object:getComponent(ComponentType.CraftBench),false,nil,nil,1,0)
 eq(a.Type,"VLSPantryCraftAction");eq(a.vehicleId,17);eq(a.applianceId,42)
 eq(a.isoObject,nil);eq(a.craftBench,nil);eq(a.manualInputs,nil);assert(a:isValid())
 local wrong=ISHandcraftAction:new(character,P.recipe("toast"),list(),source.object,nil,false,nil,nil,1,0)
 assert(not wrong:isValid())
end)
test("both appliance windows close on power loss and cannot reopen unpowered",function()
 for _,device in ipairs({coffee,toaster})do
  vehicle.parts.VLSPantryCoffee.item=device
  P.openAppliance(character,vehicle,P.PART_ID)
  local panel=opened()
  eq(panel:update(),true);assert(not panel.hasClosedWindowInstance)
  panel:prerender();eq(panel.windowHeader.title.name,device:getDisplayName())
  vehicle.charge=0;eq(panel:update(),false);assert(panel.hasClosedWindowInstance)
  local before=#failures;P.openAppliance(character,vehicle,P.PART_ID);eq(#failures,before+1)
  eq(failures[#failures],"ContextMenu_VLSNoAuxPower");vehicle.charge=1
 end
 vehicle.parts.VLSPantryCoffee.item=coffee
 P.openAppliance(character,vehicle,P.PART_ID)
end)
test("UI and authority use same carried material containers",function()
 local result=ISHandCraftPanel.updateContainers({player=character,isoObject=opened().isoObject})
 eq(result:get(0),inventory);eq(ISInventoryPaneContextMenu.getContainers,getNativeContainers)
 eq(ISHandCraftPanel.updateContainers({player=character}),"native-containers")
end)
test("one shared lightning icon for both installed devices",function()
 for _,device in ipairs({coffee,toaster})do
  vehicle.parts.VLSPantryCoffee.item=device
  menu.slices={};ISVehicleMenu.showRadialMenu(character);eq(#menu.slices,1)
  eq(menu.slices[1][2],"media/ui/VLS_SmallAppliances.png")
  eq(menu.slices[1][3],P.openAppliance);eq(menu.slices[1][6],P.PART_ID)
  eq(menu.slices[1][1],device:getDisplayName())
 end
 vehicle.charge=0;menu.slices={};ISVehicleMenu.showRadialMenu(character);eq(#menu.slices,1);eq(menu.slices[1][3],nil);vehicle.charge=1
 vehicle.parts.VLSPantryCoffee.item=nil;menu.slices={};ISVehicleMenu.showRadialMenu(character);eq(#menu.slices,0)
 vehicle.parts.VLSPantryCoffee.item=coffee
end)
package.loaded["Vehicles/ISUI/ISVehicleMechanics"]=true
local initCount=0
ISVehicleMechanics={initParts=function()initCount=initCount+1 end}
dofile(base.."client/VLS_PantryMechanics.lua")
local function row(id)return {item={part={getId=function()return id end}}}end
test("top positions precede living equipment and preserve selection",function()
 for count=2,3 do
  local header={item={cat=true,name="Living equipment"}}
  local other={item={cat=true,name="Engine"}}
  local bed,weapon=row("SeatBed"),row("VLSWeaponCabinetSlot")
  local rows={other,row("Engine"),header,bed,weapon}
  local top={}
  for i=count,1,-1 do
   top[i]=row(i==2 and "VLSTopFrame2" or VLS.OVERHEAD_PART_IDS[i]);table.insert(rows,top[i])
  end
  local panel={vehicle=vehicle,leftListSelection=4,listbox={items=rows,selected=#rows,mouseoverselected=5}}
  ISVehicleMechanics.initParts(panel)
  eq(rows[1],other);eq(rows[3],header)
  for i=1,count do eq(rows[3+i],top[i])end
  eq(rows[4+count],bed);eq(rows[5+count],weapon)
  eq(rows[panel.listbox.selected],top[1]);eq(rows[panel.listbox.mouseoverselected],weapon)
  eq(rows[panel.leftListSelection],bed)
  P.orderMechanicsRows(panel,panel.listbox)
  for i=1,count do eq(rows[3+i],top[i])end
  for i,r in ipairs(rows)do eq(r.itemindex,i);eq(r.index,i)end
 end
end)
test("unrelated vehicle rows retain their original order",function()
 local a,b=row("Engine"),row("Battery")
 local panel={listbox={items={a,b},selected=2}}
 P.orderMechanicsRows(panel,panel.listbox);eq(panel.listbox.items[1],a);eq(panel.listbox.items[2],b)
end)
test("paired frame rows precede matching storage without changing clicked part",function()
 local header={item={cat=true,name="Living equipment"}}
 local bed,top,frame=row("SeatBed"),row("VLSPantryCoffee"),row("VLSTopFrame1")
 local panel={leftListSelection=2,listbox={items={header,bed,top,frame},selected=4,mouseoverselected=3}}
 P.orderMechanicsRows(panel,panel.listbox)
 eq(panel.listbox.items[2],frame);eq(panel.listbox.items[3],top);eq(panel.listbox.items[4],bed)
 eq(panel.listbox.selected,2);eq(panel.leftListSelection,4);eq(panel.listbox.mouseoverselected,3)
 P.orderMechanicsRows(panel,panel.listbox);eq(panel.listbox.items[2],frame)
end)
test("installed-device mismatch cannot execute a different appliance recipe",function()
 local a=action("coffeeMug");a.applianceId=43;vehicle.parts.VLSPantryCoffee.item=toaster
 assert(not a:isValid());vehicle.parts.VLSPantryCoffee.item=coffee
end)
test("only the current appliance slot is exposed by pantry UI",function()
 local old=vehicle.parts.VLSPantryToaster
 old.item=toaster;assert(not V.pantryProvider.matches(old));old.item=nil
 eq(#P.stationOrder,3);eq(P.stationOrder[1],P.PART_ID)
 assert(V.pantryProvider.matches(vehicle.parts[P.PART_ID]))
end)
test("closed appliance window releases local registry without network ownership",function()
 P.openAppliance(character,vehicle,"VLSPantryCoffee")
 local source=P.uiSources[opened().isoObject]
 opened():close()
 eq(P.uiSources[source.object],nil);eq(networkWrites,0)
end)
test("mechanics uses installed name and empty small-appliance label",function()
 local part=vehicle.parts[P.PART_ID]
 for _,device in ipairs({coffee,toaster})do part.item=device;eq(V.pantryProvider.name(part),device:getDisplayName())end
 part.item=nil;eq(V.pantryProvider.name(part),"IGUI_VehiclePartVLSOverhead1");part.item=coffee
end)
test("ordinary crafting keeps its own bench and object",function()
 local bench,obj={},{}
 local panel=ISHandCraftPanel:new(0,0,10,10,character,bench,obj,"AnySurfaceCraft")
 eq(panel.craftBench,bench);eq(panel.logic:getCraftBench(),bench);eq(panel.logic:getIsoObject(),obj)
 eq(panel.recipeQuery,"AnySurfaceCraft")
end)
test("failed native bench binding is reported and its detached object released",function()
 local previous=ISHandCraftPanel.new
 ISHandCraftPanel.new=function(self,...)
  local panel=previous(self,...);panel.craftBench=nil;return panel
 end
 local countBefore=#failures
 P.openAppliance(character,vehicle,P.PART_ID)
 ISHandCraftPanel.new=previous
 eq(#failures,countBefore+1);eq(failures[#failures],"ContextMenu_VLSPantryMenuUnavailable")
 for _,source in pairs(P.uiSources)do assert(source.character~=character)end
end)
test("actual VLS auxiliary battery helpers gate and debit all three native recipes",function()
 local f=assert(io.open(base.."shared/VLS_Config.lua"));local config=f:read("*a");f:close()
 local has,consume,partGetter=V.hasAuxBatteryPower,V.consumeAuxBattery,V.getAuxBatteryPart
 local powerSource=assert(config:match("(VLS.VehiclePower =.-)function VLS.getInstalledWaterBottlePart"))
 local smallRate=V.getSmallApplianceDrainPerUse
 assert(loadstring(powerSource))()
 V.getSmallApplianceDrainPerUse=smallRate
 local charge,transmissions,installed=1,0,true
 local battery={getCurrentUsesFloat=function()return charge end,setUsedDelta=function(_,n)charge=n end}
 local batteryPart={getInventoryItem=function()return installed and battery or nil end}
 V.getAuxBatteryPart=function()return batteryPart end
 vehicle.transmitPartUsedDelta=function()transmissions=transmissions+1 end
 for _,choice in ipairs({"coffeeMug","coffeeCup","toast"})do
  local a=action(choice);installed=false;assert(not a:isValid())
  installed=true;charge=0;assert(not a:isValid())
  charge=V.getSmallApplianceDrainPerUse()/2;assert(not a:isValid())
  charge=1;assert(a:isValid());a:serverStart()
  local before=transmissions;a:complete();eq(charge,1-V.getSmallApplianceDrainPerUse());eq(transmissions,before+1)
  a:complete();eq(charge,1-V.getSmallApplianceDrainPerUse());eq(transmissions,before+1)
 end
 V.hasAuxBatteryPower,V.consumeAuxBattery,V.getAuxBatteryPart=has,consume,partGetter
 vehicle.parts.VLSPantryCoffee.item=coffee
end)
-- Use the shipped item-context-menu callback, not a fabricated radial call.
local contextFile=assert(io.open(native.."/client/ISUI/ISInventoryPaneContextMenu.lua"))
local contextText=contextFile:read("*a");contextFile:close()
local contextStart=assert(contextText:find("function ISInventoryPaneContextMenu.doRecipeListForItem(",1,true))
local contextEnd=assert(contextText:find("\nend",contextStart,true))+3
assert(loadstring(contextText:sub(contextStart,contextEnd)))()
local function openFromItem(fullName)
 local context={}
 function context:addOption(label,target,callback,...)
  self.target,self.callback,self.args,self.n=target,callback,{...},select("#",...);return {}
 end
 local texture=getTexture;getTexture=function()return {splitIcon=function()return "recipe-icon"end}end
 ISInventoryPaneContextMenu.doRecipeListForItem(context,"Crafting",{getFullName=function()return fullName end},character)
 getTexture=texture
 context.callback(context.target,unpack(context.args,1,context.n))
 return opened()
end
test("item-right-click with either appliance keeps native item-filtered crafting",function()
 for _,device in ipairs({coffee,toaster})do
  vehicle.parts[P.PART_ID].item=device
  for _,fullName in ipairs({"Base.Teacup","Base.Coffee2","Base.BreadSlices"})do
   local window=openFromItem(fullName);local panel=window.handCraftPanel
   eq(window.isoObject,V.genericSurface)
   eq(panel.craftBench,nil);eq(panel.logic:getCraftBench(),nil)
   eq(panel.logic:getIsoObject(),V.genericSurface)
   eq(panel.recipeQuery,"*")
   eq(panel.fixtureFilterText,"!"..fullName);eq(panel.fixtureFilterMode,2)
   eq(P.uiSources[window.isoObject],nil)
  end
 end
 vehicle.parts[P.PART_ID].item=coffee
end)
test("generic and selected-recipe menus stay native with either appliance",function()
 for _,device in ipairs({coffee,toaster})do
  vehicle.parts[P.PART_ID].item=device
  for _,query in ipairs({"*", "InHandCraft;AnySurfaceCraft"})do
   ISEntityUI.OpenHandcraftWindow(character,nil,query,false)
   local window=opened();local panel=window.handCraftPanel
   eq(window.isoObject,V.genericSurface);eq(panel.recipeQuery,query)
   eq(panel.craftBench,nil);eq(panel.logic:getCraftBench(),nil)
   eq(P.uiSources[window.isoObject],nil)
  end
  ISEntityUI.OpenHandcraftWindow(character,nil,"*",false,P.recipe("coffeeMug"))
  eq(opened().handCraftPanel.craftBench,nil)
  eq(P.uiSources[opened().isoObject],nil)
  ISEntityUI.OpenHandcraftWindow(character,nil,nil,false)
  local panel=opened().handCraftPanel
  eq(panel.recipeQuery,"InHandCraft;AnySurfaceCraft")
  eq(panel.logic:getIsoObject(),V.genericSurface)
  local ordinary=setmetatable({
   isAnySurfaceCraft=function()return true end,
   getInputs=function()return list()end,
  },{__index=P.recipe("coffeeMug")})
  panel.logic:setRecipe(ordinary)
  panel.logic:setManualSelectInputs(true)
  local action=ISHandcraftAction.FromLogic(panel.logic,0)
  eq(action.Type,"ISHandcraftAction")
  eq(action.isoObject,V.genericSurface)
  eq(action.craftBench,nil)
  assert(action:isValid())
  local outputs=outputCount
  action:serverStart();action:complete()
  eq(outputCount,outputs+1)
 end
 V.genericSurface=nil
 ISEntityUI.OpenHandcraftWindow(character,nil,nil,false)
 eq(opened().isoObject,nil)
 eq(opened().handCraftPanel.craftBench,nil)
 V.genericSurface=vehicle;vehicle.parts[P.PART_ID].item=coffee
end)
test("no vehicle appliance means untouched native crafting menu",function()
 for _,mode in ipairs({"empty","no-power","outside","moving"})do
  if mode=="empty" then vehicle.parts[P.PART_ID].item=nil end
  if mode=="no-power" then vehicle.charge=0 end
  if mode=="outside" then character.vehicle=nil end
  if mode=="moving" then vehicle.stopped=false end
  local window=openFromItem("Base.BreadSlices")
  eq(window.handCraftPanel.craftBench,nil);eq(P.uiSources[window.isoObject],nil)
  vehicle.parts[P.PART_ID].item=coffee;vehicle.charge=1;character.vehicle=vehicle;vehicle.stopped=true
 end
end)
test("explicit real world workstation is not replaced by vehicle appliance",function()
 local object={getProperties=function()return nil end}
 ISEntityUI.OpenHandcraftWindow(character,object,"Wood",true)
 eq(opened().isoObject,object);eq(opened().handCraftPanel.recipeQuery,"Wood");eq(P.uiSources[object],nil)
end)
-- Native completion callback, driven by actions made from each actual UI entry.
ISPanelJoypad=ISPanel;package.loaded["ISUI/ISPanelJoypad"]=true
getTextManager=function()return {getFontHeight=function()return 12 end}end
dofile(native.."/client/Entity/ISUI/CraftRecipe/ISWidgetHandCraftControl.lua")
ISInventoryPage={dirtyUI=noop}
for _,entry in ipairs({"lightning"})do
 for _,choice in ipairs({"toast","coffeeMug","coffeeCup"})do
  test(entry.." "..choice.." completes and repeats without reopening",function()
   server=false;client=false
   vehicle.parts[P.PART_ID].item=choice=="toast" and toaster or coffee
   P.openAppliance(character,vehicle,P.PART_ID)
   local window=opened();local panel=window.handCraftPanel;local logic=panel.logic
   P.recipe(choice).getInputs=function()return list()end
   logic:setRecipe(P.recipe(choice))
   logic.getPlayer=function()return character end
   logic.isUsingRecipeAtHandBenefit=function()return false end
   logic:getRecipeData().getVariableInputRatio=function()return 1 end
   logic:getRecipeData().getAllInputItems=function()return list()end
   local busy,notifications=false,0
   logic.stopCraftAction=function()busy=false;notifications=notifications+1 end
   local control={logic=logic,craftTimes=2,setCraftQuantity=function(self,n)self.remaining=n end}
   for iteration=1,2 do
    assert(not busy,"native craft state still busy before repeat");busy=true
    local a=ISHandcraftAction.FromLogic(logic,0)
    eq(a.Type,"VLSPantryCraftAction");eq(a.isoObject,nil);eq(a.craftBench,nil)
    a.netAction={forceComplete=noop};a:serverStart()
    a:setOnComplete(ISWidgetHandCraftControl.onHandcraftActionComplete,control)
    local outputs,debits=outputCount,vehicle.debits or 0
    a:perform();eq(outputCount,outputs+1);eq(vehicle.debits,debits+1)
    a:complete()
    assert(not busy,"native completion must release busy/99-percent state")
    eq(notifications,iteration);eq(opened(),window)
    if iteration==1 then eq(control.craftTimes,1);eq(control.remaining,1)
    else eq(control.craftTimes,nil)end
    a:complete();eq(notifications,iteration);eq(outputCount,outputs+1);eq(vehicle.debits,debits+1)
   end
   server=true;vehicle.parts[P.PART_ID].item=coffee
  end)
 end
end
for _,failure in ipairs({"power","missing-materials","missing-logic"})do
 test("native completion releases rejected "..failure.." once without output",function()
  local a=action("toast");a:serverStart()
  local notifications=0;a:setOnComplete(function()notifications=notifications+1 end,{})
  local outputs,debits=outputCount,vehicle.debits
  if failure=="power" then vehicle.charge=0
  elseif failure=="missing-materials" then canCraft=false
  else a.logic=nil end
  a:complete();a:complete();eq(notifications,1);eq(outputCount,outputs);eq(vehicle.debits,debits)
  vehicle.charge=1;canCraft=true;vehicle.parts[P.PART_ID].item=coffee
 end)
end
-- Match the shipped NetTimedAction constructor-field collection and ordered
-- server reconstruction. No manually copied vehicle/choice fields are allowed.
local function roundtrip(class, path, original, serverConstructor)
 local f=assert(io.open(path));local source=f:read("*a");f:close()
 local params=assert(source:match("function%s+"..class.Type..":new%(([^)]*)%)"))
 local args,n={},0
 for name in params:gmatch("[%w_]+")do n=n+1;args[n]=rawget(original,name)end
 return serverConstructor(class,unpack(args,1,n))
end
for _,choice in ipairs(P.choiceOrder)do
 for _,entry in ipairs({"lightning"})do
  test(entry.." "..choice.." survives named-field MP reconstruction twice",function()
   vehicle.parts[P.PART_ID].item=choice=="toast" and toaster or coffee
   P.openAppliance(character,vehicle,P.PART_ID)
   for iteration=1,2 do
    local panel=opened().handCraftPanel;panel.logic:setRecipe(P.recipe(choice))
    local clientAction=ISHandcraftAction.FromLogic(panel.logic,0)
    local a=roundtrip(VLSPantryCraftAction,base.."shared/VLS_PantryCraftAction.lua",clientAction,VLSPantryCraftAction.new)
    eq(a.vehicleId,17);eq(a.partId,P.PART_ID);eq(a.applianceId,choice=="toast" and 43 or 42);eq(a.choice,choice)
    eq(a.craftRecipe,P.recipe(choice));eq(a.isoObject,nil);eq(a.craftBench,nil)
    a.netAction={forceComplete=noop};a:serverStart();assert(a:isValid())
    local outputs,debits=outputCount,vehicle.debits or 0
    a:complete();eq(outputCount,outputs+1);eq(vehicle.debits,debits+1)
   end
  end)
 end
end
test("ordinary crafting retains native constructor field names and values",function()
 -- Capture a fresh unwrapped constructor for the server's original class.
 local saved=ISHandcraftAction
 dofile(native.."/shared/Entity/TimedActions/ISHandcraftAction.lua")
 local serverNew=ISHandcraftAction.new;ISHandcraftAction=saved
 local object,bench,containers={},{},list()
 local a=ISHandcraftAction:new(character,P.recipe("toast"),containers,object,bench,{},nil,nil,0.5,0.25)
 eq(a.Type,"ISHandcraftAction")
 local b=roundtrip(ISHandcraftAction,base.."client/VLS_PantryMenu.lua",a,serverNew)
 eq(b.craftRecipe,a.craftRecipe);eq(b.isoObject,object);eq(b.craftBench,bench)
 eq(b.containers,containers);eq(b.variableInputRatio,0.5);eq(b.eatPercentage,0.25)
end)
test("malformed remote appliance choice rejects without output or exception",function()
 local a=VLSPantryCraftAction:new(character,17,P.PART_ID,42,"invalid-choice",nil,nil,nil)
 a.netAction={forceComplete=function()a.rejected=true end}
 local outputs=outputCount;a:serverStart();assert(a.rejected);eq(outputCount,outputs)
end)

test("three independent appliance slots retain their own native recipe and MP identity",function()
 local old=vehicle.parts[P.PART_ID].item
 local devices={item("Base.Mov_CoffeeMaker",nil,101),item("Base.Mov_Toaster",nil,102),item("Base.Mov_CoffeeMaker",nil,103)}
 for n=1,3 do
  local id=VLS.OVERHEAD_PART_IDS[n];local p=vehicle.parts[id] or {getVehicle=function()return vehicle end}
  p.getId=function()return id end;p.getInventoryItem=function(self)return self.item end
  p.item=devices[n];p.item.getDisplayName=function()return "Native device "..n end;vehicle.parts[id]=p
 end
 menu.slices={};ISVehicleMenu.showRadialMenu(character);eq(#menu.slices,3)
 for n=1,3 do
  local id=VLS.OVERHEAD_PART_IDS[n];local choice=n==2 and "toast" or "coffeeCup"
  P.openAppliance(character,vehicle,id)
  local panel=opened().handCraftPanel;panel.logic:setRecipe(P.recipe(choice))
  local a=ISHandcraftAction.FromLogic(panel.logic,0)
  local b=roundtrip(VLSPantryCraftAction,base.."shared/VLS_PantryCraftAction.lua",a,VLSPantryCraftAction.new)
  eq(b.partId,id);eq(b.applianceId,100+n);eq(b.choice,choice)
  b.netAction={forceComplete=noop};b:serverStart();assert(b:isValid())
  local outputs,debits=outputCount,vehicle.debits or 0;b:complete();eq(outputCount,outputs+1);eq(vehicle.debits,debits+1)
 end
 local a=VLSPantryCraftAction:new(character,17,"VLSOverhead1",102,"toast",nil,nil,nil)
 vehicle.parts.VLSOverhead1.frameReady=false;eq(a:isValid(),false)
 vehicle.parts.VLSPantryCoffee.item=old;vehicle.parts.VLSOverhead1=nil;vehicle.parts.VLSOverhead2=nil
end)
print("RESULT pantry UI and transaction tests="..count.." failures=0")
