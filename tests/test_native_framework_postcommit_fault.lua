-- Native B42.20 completion/render bodies, mocked engine objects.
local root,native=assert(arg[1]),assert(arg[2])
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
local n=0
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local noop=function()end
local Base={}
function Base:derive(name)local c={Type=name};c.__index=c;return setmetatable(c,{__index=self})end
function Base:new(character)return setmetatable({character=character},{__index=self})end
ISBaseTimedAction=Base;package.loaded["TimedActions/ISBaseTimedAction"]=true
for _,name in ipairs({"ISInstallVehiclePart","ISUninstallVehiclePart"})do
 dofile(native.."/shared/Vehicles/TimedActions/"..name..".lua")
 package.loaded["Vehicles/TimedActions/"..name]=true
end
VLS={isUniversalPart=function(p)return p and p.managed end,
 isAllowedItem=function(p,i)return i~=nil end,
 getEquipmentCapability=function(i)return i and i.tv and "television" or nil end,
 isInstallationEnabled=function(p)return not p.disabled end,
 canUninstallManagedPart=function(p)return not p.disabled end,
 copyTelevisionStateToItem=function(p,i)i.copied=true;i:getDeviceData():cloneDevicePresets(p.currentTVPresets) end,allowedItems={}}
package.loaded.VLS_Config=VLS
instanceof=function(obj,kind)return obj and (kind=="InventoryItem" or kind=="Radio" and obj.radio) or false end
local nativeInstance=instanceof
isServer=function()return true end
Perks={Mechanics=1};IsoObjectChange={MECHANIC_ACTION_DONE=1}
getGameTime=function()return {getCalender=function()return {getTimeInMillis=function()return 42 end}end}end
sendRemoveItemFromContainer=noop;sendAddItemToContainer=noop;playServerSound=noop
local outcome="success"
ZombRand=function(a,b)if b then return 7 end;return outcome=="success" and 0 or 99 end
VehicleUtils={getPerksTableForChr=noop,calculateInstallationSuccess=function()return outcome=="success" and 100 or 0,100 end}
function VehicleUtils.callLua(fn,...)fn(...)end
addXp=function(c)c.xp=(c.xp or 0)+1 end
ISTransferAction={GetDropItemOffset=function()return 0,0,0 end}
local function setup(tv)
 local i={tv=tv,radio=true,condition=100,id=5}
 i.setJobDelta=noop;i.setItemCapacity=noop
 local itemDevice={presets={name="original TV presets"}}
 function itemDevice:getDevicePresets()return self.presets end
 function itemDevice:cloneDevicePresets(presets)self.presets=presets end
 function i:getDeviceData()return itemDevice end
 function i:getID()return self.id end
 function i:getCondition()return self.condition end
 function i:setCondition(c)self.condition=c end
 local inv={items={i},room=true}
 function inv:DoRemoveItem(it)self.items={}end
 function inv:AddItem(it)table.insert(self.items,it)end
 function inv:hasRoomFor()return self.room end
 local square={AddWorldInventoryItem=function(_,it)inv.dropped=it end}
 local c={getInventory=function()return inv end,removeFromHands=noop,getPerkLevel=function()return 5 end,
 getCurrentSquare=function()return square end,sendObjectChange=noop,addMechanicsItem=noop}
 local v={transmitPartItem=noop,transmitPartCondition=noop,getMechanicalID=function()return 9 end}
 local p={managed=tv,item=nil,condition=100,signals=0,currentTVPresets={name="latest companion TV presets"},getVehicle=function()return v end}
 function p:getId()return self.managed and "SeatBed" or "Radio" end
 function p:getInventoryItem()return self.item end
 function p:setInventoryItem(it)self.item=it end
 function p:getContainerContentAmount()return 0 end
 function p:getCondition()return self.condition end
 function p:setCondition(x)self.condition=x end
 function p:getDeviceData()return self.device end
 function p:createSignalDevice()
  self.signals=self.signals+1;self.device={presets={name="default radio presets"}}
  function self.device:getDevicePresets()return self.presets end
  function self.device:cloneDevicePresets(presets)self.presets=presets end
  return self.device
 end
 function p:getTable()return {skills={},complete=function()
   eq(instanceof,nativeInstance);eq(instanceof(i,"Radio"),true)
   if p.throwCallback then error("callback fault")end
 end}end
 return {character=c,vehicle=v,part=p,item=i},inv
end


VLS.isManagedPart=function(p)return p.managed end
VLS.isPropaneTankPart=function(p)return p:getId()=="VLSRoofPropane1" end
local Context=require "VLS_NativeContext"
Vehicles={InstallComplete={},UninstallComplete={}}
function Vehicles.InstallComplete.Default(vehicle, part)
	vehicle:doDamageOverlay();
end

function Vehicles.UninstallComplete.Default(vehicle, part, item)
	vehicle:doDamageOverlay();
end
dofile(media.."shared/VLS_InstallGuard.lua")
local function roof()
 local a,inv=setup(false)
 a.part.data={vlsNativeEpoch=0}
 a.part.getId=function()return "VLSRoofPropane1"end
 a.part.getModData=function(self)return self.data end
 a.part.getItemContainer=function()return nil end
 a.vehicle.getId=function()return 17 end
 a.vehicle.getPartById=function(_,id)return id=="VLSRoofPropane1" and a.part or nil end
 a.vehicle.transmitPartModData=noop;a.vehicle.doDamageOverlay=noop
 a.part.getTable=function(_,name)return {skills={},complete=name=="install" and Vehicles.InstallComplete.Default or Vehicles.UninstallComplete.Default}end
 return a,inv
end
-- Actual native complete bodies and current VLS wrappers, real Default callbacks.
outcome="success"
local a,inv=roof()
eq(ISInstallVehiclePart.complete(a),true);eq(a.part.data.vlsNativeEpoch,1)
eq(ISUninstallVehiclePart.complete(a),true);eq(a.part.data.vlsNativeEpoch,2)
eq(ISInstallVehiclePart.complete(a),true);eq(a.part.data.vlsNativeEpoch,3)
-- Native returns true even on a failed installation; no assignment means no bump.
local fail,inventory=roof();outcome="failure"
eq(ISInstallVehiclePart.complete(fail),true);eq(fail.part.item,nil);eq(fail.part.data.vlsNativeEpoch,0)
-- Already-bumped callback remains one increment.
outcome="success";local managed=roof();managed.part.managed=true
managed.part.getTable=function()return {skills={},complete=function(v,p)Context.installationChanged(v,p)end}end
eq(ISInstallVehiclePart.complete(managed),true);eq(managed.part.data.vlsNativeEpoch,1)
-- Notification exceptions occur after assignment, normal callback and inventory mutation.
-- Simulate the native server notification fault, without changing original action code.
local fault,bag=roof();fault.part.item=fault.item;bag.items={}
local oldEpoch=fault.part.data.vlsNativeEpoch
fault.character.sendObjectChange=function()error("native post-commit notification fault")end
local ok=pcall(ISUninstallVehiclePart.complete,fault)
eq(ok,false);eq(fault.part.item,nil);eq(bag.items[1],fault.item)
local removedEpoch=fault.part.data.vlsNativeEpoch
ok=pcall(ISInstallVehiclePart.complete,fault)
eq(ok,false);eq(fault.part.item,fault.item);eq(#bag.items,0)
-- This is the required invariant. It currently fails: old same-item binding revives.
local oldIdentity=Context.partIdentity(fault.vehicle,"VLSRoofPropane1",fault.item:getID(),oldEpoch)
assert(oldIdentity==nil,"REGRESSION: native committed uninstall+same-ID install then notification errors revived old epoch; removedEpoch="..tostring(removedEpoch).." currentEpoch="..tostring(fault.part.data.vlsNativeEpoch).." oldEpoch="..tostring(oldEpoch))

-- The supplied original-transaction regression above is retained verbatim.
-- Additional error-priority and no-change cases use original action bodies.
local originalError = {}
local priorFinish=VLS.NativeInstallation.finishIdentity
local dual,dualBag=roof();dual.part.item=dual.item;dualBag.items={}
dual.character.sendObjectChange=function()error(originalError)end
VLS.NativeInstallation.finishIdentity=function(part,before)
 priorFinish(part,before)
 error("observer reporting fault")
end
local returned,err=pcall(ISUninstallVehiclePart.complete,dual)
eq(returned,false);assert(err==originalError,"observer masked original exception")
eq(dual.part.data.vlsNativeEpoch,1);eq(dual.part.item,nil)
returned,err=pcall(ISInstallVehiclePart.complete,dual)
eq(returned,false);assert(err==originalError,"install observer masked original exception")
eq(dual.part.data.vlsNativeEpoch,2);eq(dual.part.item,dual.item)
VLS.NativeInstallation.finishIdentity=priorFinish
local unchanged=roof();unchanged.character.removeFromHands=function()error(originalError)end
returned,err=pcall(ISInstallVehiclePart.complete,unchanged)
eq(returned,false);assert(err==originalError);eq(unchanged.part.data.vlsNativeEpoch,0)
-- Changed transaction with an already-bumped callback followed by failure.
local callback=roof()
local function callbackFailure(v,p)
 Context.installationChanged(v,p);error(originalError)
end
callback.part.getTable=function()return {skills={},complete=callbackFailure}end
returned,err=pcall(ISInstallVehiclePart.complete,callback)
eq(returned,false);assert(err==originalError);eq(callback.part.data.vlsNativeEpoch,1)
print("PASS actual native postcommit install/uninstall: changed epochs reconciled, original errors preserved, no-change/no-double-count controls")
local observedFailure=roof()
VLS.NativeInstallation.finishIdentity=function(part,before)
 priorFinish(part,before);error('standalone observer failure')
end
returned,err=pcall(ISInstallVehiclePart.complete,observedFailure)
eq(returned,false);assert(tostring(err):find('standalone observer failure',1,true))
eq(observedFailure.part.item,observedFailure.item);eq(observedFailure.part.data.vlsNativeEpoch,1)
VLS.NativeInstallation.finishIdentity=priorFinish
print('PASS observer-only failure remains visible without undoing original transaction')
