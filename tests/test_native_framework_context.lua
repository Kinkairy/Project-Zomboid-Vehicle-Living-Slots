local root = assert(arg[1])
package.path = root .. '/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/?.lua;' .. package.path
local n=0
local function test(name, fn) fn(); n=n+1; print('PASS '..name) end
local function eq(a,b) assert(a==b, tostring(a)..' != '..tostring(b)) end
local cargo = {}
local fluid = {}
local item = {id=10, cabinet=true}
function item:getID() return self.id end
local part = {item=item, managed=true,data={}}
function part:getModData()return self.data end
function part:getInventoryItem() return self.item end
function part:getItemContainer() return cargo end
function part:getId() return 'SeatBed' end
local vehicle = {id=3, supported=true}
function part:getVehicle()return vehicle end
function vehicle:transmitPartModData(p)self.sent=(self.sent or 0)+1 end
function vehicle:getId() return self.id end
function vehicle:getPartById(id) if id=='SeatBed' then return part end end
local player = {vehicle=vehicle}
function player:getVehicle() return self.vehicle end
getVehicleById=function(id) if id==3 then return vehicle end end
instanceof=function(o,t) return o==vehicle and t=='BaseVehicle' end
VLS={
 isSupportedVehicle=function(v) return v.supported end,
 isManagedPart=function(p) return p.managed end,
 getInstalledGenericCraftSurfacePart=function(v) return part.item and part or nil end,
 isGenericCraftSurfaceEquipment=function(i) return i.cabinet end,
 VehiclePower={snapshot=function(v) return v end},
 getInstalledWaterTank=function(v) return {getFluidContainer=function() return fluid end},part end
}
local C=require 'VLS_NativeContext'
test('native container and surface retain original identity',function()
 local c=assert(C.cabinet(player)); eq(c.surface,vehicle);eq(C.storage(c),cargo)
 eq(C.water(c),fluid);eq(C.power(c),vehicle)
end)
test('token contains only primitive canonical installation identity',function()
 local t=C.token(C.cabinet(player));eq(t.vehicleId,3);eq(t.partId,'SeatBed');eq(t.installedItemId,10)
 local count=0;for _,v in pairs(t) do assert(type(v)=='number' or type(v)=='string');count=count+1 end;eq(count,4)
 eq(C.restore(player,t).item,item)
end)
test('leaving host rejects restored token',function()
 local t=C.token(C.cabinet(player));player.vehicle=nil;eq(C.restore(player,t),nil);player.vehicle=vehicle
end)
test('replacement item in same part rejects old token',function()
 local t=C.token(C.cabinet(player));part.item={getID=function()return 11 end,cabinet=true};eq(C.restore(player,t),nil);part.item=item
end)
test('uninstall and foreign part fail closed',function()
 local t=C.token(C.cabinet(player));part.item=nil;eq(C.restore(player,t),nil);part.item=item
 eq(C.resolve(player,vehicle,'Fake'),nil);part.managed=false;eq(C.restore(player,t),nil);part.managed=true
end)
test('same item removal and reinstall epoch invalidates queued identity',function()
 local t=C.token(C.cabinet(player));assert(C.installationChanged(vehicle,part));eq(C.restore(player,t),nil)
 eq(vehicle.sent,1)
end)
test('clients cannot advance authority epoch',function()
 isClient=function()return true end;local epoch=part.data.vlsNativeEpoch
 eq(C.installationChanged(vehicle,part),false);eq(part.data.vlsNativeEpoch,epoch);isClient=nil
end)
test('malformed network identity rejected' ,function()
 eq(C.restore(player,{vehicleId=0/0,partId='SeatBed',installedItemId=10}),nil)
 eq(C.restore(player,{vehicleId=3,partId='SeatBed',installedItemId=math.huge}),nil)
end)
local Base={}
function Base:derive(name) local c={Type=name};c.__index=c;return setmetatable(c,{__index=self}) end
function Base:new(character) return setmetatable({character=character},{__index=self}) end
function Base:forceStop()self.stopped=true end
ISHandcraftAction=Base:derive('ISHandcraftAction')
function ISHandcraftAction:new(character,craftRecipe,containers,isoObject,craftBench,manualInputs,items,recipeItem,variableInputRatio,eatPercentage)
 local o=Base.new(self,character)
 o.craftRecipe,o.containers,o.isoObject,o.craftBench=craftRecipe,containers,isoObject,craftBench
 o.manualInputs,o.items,o.recipeItem=manualInputs,items,recipeItem
 o.variableInputRatio,o.eatPercentage=variableInputRatio,eatPercentage
 return o
end
function ISHandcraftAction:isValid() return self.craftRecipe ~= nil end
function ISHandcraftAction:start() self.started=true;self.logic={getRecipeData=function()return nil end} end
function ISHandcraftAction:serverStart() self.serverStarted=true;self.logic={getRecipeData=function()return nil end} end
function ISHandcraftAction:complete()
 if self.eatPercentage > 0 then self.logic:getRecipeData() end
 self.cleaned=true
 self:performRecipe();self.completedCalls=(self.completedCalls or 0)+1
 if self.onCompleteFunc then self.onCompleteFunc(self.onCompleteTarget) end
 return true
end
function ISHandcraftAction:performRecipe() self.nativeCalls=(self.nativeCalls or 0)+1;return 'native_result' end
package.loaded['Entity/TimedActions/ISHandcraftAction']=true
local A=require 'VLS_NativeHandcraftAction'; A.install()
local recipe={isAnySurfaceCraft=function()return true end}
local function action() return ISHandcraftAction:new(player,recipe,cargo,vehicle,nil,{},nil,nil,0.5,0.2) end
test('constructor keeps all native arguments and appends pinned identity',function()
 local a=action();eq(a.Type,'VLSNativeHandcraftAction');eq(a.isoObject,vehicle);eq(a.containers,cargo)
 eq(a.variableInputRatio,0.5);eq(a.eatPercentage,0.2);eq(a.installedItemId,10);eq(a.force,nil)
 a:start();a:serverStart();eq(a.started,true);eq(a.serverStarted,true);eq(a:performRecipe(),'native_result');eq(a.nativeCalls,1)
end)
test('serialized constructor rebuild preserves authority',function()
 local a=action()
 local b=A:new(a.character,a.craftRecipe,a.containers,a.isoObject,a.craftBench,a.manualInputs,a.items,a.recipeItem,a.variableInputRatio,a.eatPercentage,a.vehicleId,a.partId,a.installedItemId,a.installationEpoch)
 eq(b:isValid(),true);item.id=11;eq(b:isValid(),false);eq(b:performRecipe(),nil);eq(b.nativeCalls,nil);item.id=10
end)
test('invalid start never delegates native mutation',function()
 local a=action();a.netAction={forceComplete=function()a.netCompleted=true end};player.vehicle=nil;a:serverStart();eq(a.netCompleted,true);eq(a.serverStarted,nil);local notified=0;a.onCompleteFunc=function()notified=notified+1 end
 eq(a:complete(),true);eq(a.completedCalls,1);eq(a.cleaned,true);eq(notified,1);eq(a.eatPercentage,0.2)
 a:complete();eq(notified,1);eq(a.nativeCalls,nil);player.vehicle=vehicle
end)
test('native execution and completion are not repeated',function()
 local a=action();a:serverStart();a:complete();a:complete();a:performRecipe()
 eq(a.nativeCalls,1);eq(a.completedCalls,1)
end)
test('rejected completion restores native argument even if callback throws',function()
 local a=action();a.vlsRejected=true;a.logic=nil
 a.onCompleteFunc=function()error('callback failure')end
 local ok=pcall(function()a:complete()end);eq(ok,false);eq(a.eatPercentage,0.2);eq(a.nativeCalls,nil)
end)
test('client completion never produces outputs',function()
 local a=action();a:start();isClient=function()return true end
 a:complete();eq(a.nativeCalls,nil);eq(a.completedCalls,1);isClient=nil
end)
test('forged action cannot substitute another native bench or recipe kind',function()
 local a=action();a.craftBench={};eq(a:isValid(),false);a.craftBench=nil
 a.craftRecipe={isAnySurfaceCraft=function()return false end};eq(a:isValid(),false)
end)
test('repeat install is idempotent and ordinary craft unchanged',function()
 local f=ISHandcraftAction.new;A.install();eq(ISHandcraftAction.new,f)
 local a=ISHandcraftAction:new(player,recipe,cargo,nil,nil,nil,nil,nil,1,0);eq(a.Type,'ISHandcraftAction')
 local subclass=ISHandcraftAction:derive('OtherModAction');eq(subclass:new(player,recipe,cargo,vehicle).Type,'OtherModAction')
end)
print('TOTAL '..n..' host stub tests; not real-game acceptance')
