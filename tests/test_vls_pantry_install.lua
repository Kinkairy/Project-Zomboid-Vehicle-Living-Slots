-- Runs actual B42.20 Lua transactions with host objects mocked; not a live MP test.
local root,native=assert(arg[1]),assert(arg[2])
local base=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/"
local function noop() end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local n=0
local function test(name,fn) fn();n=n+1;print("PASS "..name) end
ISBaseTimedAction={}
function ISBaseTimedAction:derive(name)local c={Type=name};c.__index=c;setmetatable(c,{__index=self});return c end
function ISBaseTimedAction.new(c,chr)return setmetatable({character=chr},{__index=c})end
package.loaded["TimedActions/ISBaseTimedAction"]=true
isClient=function()return false end;isServer=function()return true end
function instanceof(o,t)return o~=nil and (t=="InventoryItem" or t==o.kind) end
getText=function(s)return s end
Perks={Mechanics=1};IsoObjectChange={MECHANIC_ACTION_DONE=1}
getGameTime=function()return {getCalender=function()return {getTimeInMillis=function()return 1 end}end}end
sendRemoveItemFromContainer=noop;sendAddItemToContainer=noop;playServerSound=noop;addXp=noop
local success=100
VehicleUtils={getPerksTableForChr=function()return {}end,calculateInstallationSuccess=function()return success,0 end,callLua=noop}
LuaEventManager={AddEvent=noop};Events={OnUseVehicle={Add=noop},OnVehicleHorn={Add=noop}}
dofile(native.."/server/Vehicles/Vehicles.lua")
VehicleUtils.getPerksTableForChr=function()return {}end
VehicleUtils.calculateInstallationSuccess=function()return success,0 end
VehicleUtils.callLua=noop
dofile(native.."/shared/Vehicles/TimedActions/ISInstallVehiclePart.lua")
dofile(native.."/shared/Vehicles/TimedActions/ISUninstallVehiclePart.lua")
package.loaded["Vehicles/TimedActions/ISInstallVehiclePart"]=true
package.loaded["Vehicles/TimedActions/ISUninstallVehiclePart"]=true
local V={allowedItems={},mechanicsDisplayProviders={},isUniversalPart=function()return false end,
 isSupportedVehicle=function(v)return v.supported end,resolveEquipmentType=noop,getEquipmentProfileByType=noop,
 isAllowedItem=function()return true end,isInstallationEnabled=function()return true end,
 canUninstallManagedPart=function()return true end}
VLS=V;package.loaded.VLS_Config=V
dofile(base.."VLS_InstallGuard.lua");package.loaded.VLS_InstallGuard=true
local sharedComplete=ISInstallVehiclePart.complete
local P=dofile(arg[3] or (base.."VLS_Pantry.lua"))
local inventory={items={}}
function inventory:contains(i)return self.items[i]==true end
function inventory:containsID(id)for i in pairs(self.items)do if i:getID()==id then return true end end;return false end
function inventory:DoRemoveItem(i)assert(self.items[i]);self.items[i]=nil end
function inventory:AddItem(i)assert(not self.items[i]);self.items[i]=true end
function inventory:hasRoomFor()return true end
local character={getInventory=function()return inventory end,isMechanicsCheat=function()return false end,
 isTimedActionInstant=function()return false end,getPerkLevel=function()return 10 end,removeFromHands=noop,
 addMechanicsItem=noop,sendObjectChange=noop,getCurrentSquare=function()return {}end}
local vehicle={supported=true,transmissions=0}
local part={id=P.PART_ID,getId=function(self)return self.id end,getVehicle=function()return vehicle end,
 getInventoryItem=function(self)return self.item end,setInventoryItem=function(self,i)self.item=i end,
 getTable=function()return {skills="Mechanics:1"}end,getContainerContentAmount=function()return 0 end}
function vehicle:getPartById(id)return id==part.id and part or nil end
function vehicle:canInstallPart(chr,p)return Vehicles.InstallTest.Default(self,p,chr) end
function vehicle:transmitPartItem()self.transmissions=self.transmissions+1 end
function vehicle:getMechanicalID()return 7 end
local function item(ft,id)return {kind="Moveable",getFullType=function()return ft end,getID=function()return id end,
 getDisplayName=function()return ft end,setJobDelta=noop,setItemCapacity=noop}end
local coffee,toaster=item("Base.Mov_CoffeeMaker",1),item("Base.Mov_Toaster",2)
ZombRand=function()return 0 end
ISVehicleMechanics=nil -- dedicated server has no client mechanics UI
local function install(i)
 inventory.items={[i]=true};part.item=nil
 return ISInstallVehiclePart:new(character,part,i,100)
end
test("native validity check reproduces missing server mechanics UI",function()
 local a=install(coffee);local ok,err=pcall(a.isValid,a);assert(not ok and tostring(err):find("ISVehicleMechanics"));eq(part.item,nil);assert(inventory:contains(coffee))
end)
test("small appliances use the same completion as existing vehicle parts",function()eq(ISInstallVehiclePart.complete,sharedComplete)end)
for _,i in ipairs({coffee,toaster})do
 test(i:getFullType().." server install remove and reinstall without client UI",function()
  for repeatIndex=1,3 do
   local a=install(i);local tx=vehicle.transmissions
   assert(a:complete());eq(part.item,i);assert(not inventory:contains(i));eq(vehicle.transmissions,tx+1)
   local u=ISUninstallVehiclePart:new(character,part,100)
   assert(u:complete());eq(part.item,nil);assert(inventory:contains(i));eq(vehicle.transmissions,tx+2)
  end
 end)
end
test("shared disabled-feature guard retains item and leaves slot empty",function()
 local a=install(coffee);V.isInstallationEnabled=function()return false end
 eq(a:complete(),false);eq(part.item,nil);assert(inventory:contains(coffee))
 V.isInstallationEnabled=function()return true end
end)
test("native failed installation returns original item",function()
 local a=install(coffee);success=0;assert(a:complete());success=100
 eq(part.item,nil);assert(inventory:contains(coffee))
end)
test("native nil-item completion remains harmless",function()
 local a=install(coffee);a.item=nil;eq(a:complete(),false);assert(inventory:contains(coffee))
end)
test("ordinary vehicle part installation keeps native behavior",function()
 local a=install(coffee);part.id="ExistingPart";assert(a:complete());eq(part.item,coffee);part.id=P.PART_ID
end)
print("RESULT tests="..n.." failures=0")
