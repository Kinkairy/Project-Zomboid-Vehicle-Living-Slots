-- Loads the actual shared resolver, shared refill handler, client action and KI5
-- adapter. Native PZ objects are mocked; this is not an engine/MP playtest.
local root=assert(arg[1], 'repo root required')
local base=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/'
local ki5=root..'/workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..base..'server/?.lua;'..ki5..'shared/?.lua;'..package.path
local total,failures=0,0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<1e-7,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn)
 total=total+1;local ok,err=pcall(fn)
 if not ok then failures=failures+1 end
 print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(err)))
end
local noop=function() end
local isMPClient=false
isClient=function() return isMPClient end
isServer=function() return not isMPClient end
VLS={MOD_ID='VehicleLivingSlots',equipmentProfiles={},supportedMoveableSprites={},installationOptionProviders={},
 vehicleProfiles={},FREEZER_PART_BY_UNIVERSAL={},UNIVERSAL_PART_BY_FREEZER={},allowedItems={},sleepingBagTypes={},
 WATER_TANK_PART_IDS={},mechanicsDisplayProviders={},getAuxBatteryPart=noop,getPartDisplayName=noop}
function VLS.getVehicleProfile(vehicle) return vehicle and VLS.vehicleProfiles[vehicle.name] end
function VLS.isSupportedVehicle(vehicle) return VLS.getVehicleProfile(vehicle)~=nil end
package.loaded.VLS_Config=VLS
require 'VLS_Propane'
for name in pairs(VLSRoofCargo.vehicleScripts) do VLS.vehicleProfiles[name]={} end
local nextId=10
local function item(ft,charge,maxUses)
 nextId=nextId+1
 local i={ft=ft,id=nextId,charge=charge or 0,maximum=maxUses or 10000,synced=0,job=0,drainable=true}
 function i:getFullType() return self.ft end
 function i:getID() return self.id end
 function i:getCurrentUses() return math.floor(self.charge*self.maximum+1e-6) end
 function i:getCurrentUsesFloat() return self.charge end
 function i:getMaxUses() return self.maximum end
 function i:setCurrentUses(n) self.charge=n/self.maximum end
 function i:setCurrentUsesFloat(n) self.charge=n end
 function i:syncItemFields() self.synced=self.synced+1 end
 function i:setJobDelta(n) self.job=n end
 return i
end
instanceof=function(o,cls) return o and (cls=='InventoryItem' and o.ft~=nil or cls=='DrainableComboItem' and o.drainable) or false end
local vehicles={}
local function vehicle(name)
 nextId=nextId+1;local v={id=nextId,name=name or 'Base.StepVan',parts={},stopped=true,area=true,synced=0}
 function v:getId() return self.id end
 function v:getScript() return {getFullName=function() return self.name end} end
 function v:getPartById(id) return self.parts[id] end
 function v:isStopped() return self.stopped end
 function v:isInArea() return self.area end
 function v:transmitPartUsedDelta(p) self.synced=self.synced+1;self.lastPart=p end
 function v:add(id,it)
  local p={id=id,it=it,v=self}
  function p:getId() return self.id end
  function p:getVehicle() return self.v end
  function p:getInventoryItem() return self.it end
  function p:getArea() return 'TruckBed' end
  self.parts[id]=p;return p
 end
 v:add('VLSFixedRoofRack',item('Base.VLSFixedRoofRack'))
 vehicles[v.id]=v;return v
end
getVehicleById=function(id) assert(type(id)=='number');return vehicles[id] end
local function player(torch)
 local p={items={[torch.id]=torch},distance=1,inside=nil,sounds=0,stoppedSounds=0}
 local inv={getItemWithIDRecursiv=function(_,id) return p.items[id] end}
 function p:getInventory() return inv end
 function p:getVehicle() return self.inside end
 function p:DistToProper() return self.distance end
 function p:getX() return 0 end;function p:getY() return 0 end;function p:getZ() return 0 end
 function p:faceThisObject() end;function p:setMetabolicTarget() end
 function p:playSound() self.sounds=self.sounds+1;return 1 end
 function p:getEmitter() return {isPlaying=function() return true end} end
 function p:stopOrTriggerSound() self.stoppedSounds=self.stoppedSounds+1 end
 return p
end
local function fixture(name,id)
 local v=vehicle(name);local gas=item('Base.PropaneTank',1);local part=v:add(id or 'VLSRoofPropane1',gas)
 local torch=item('Base.BlowTorch',0.25,10);local chr=player(torch)
 return {v=v,gas=gas,part=part,torch=torch,chr=chr,args={vehicle=v.id,part=part.id,torch=torch.id,tank=gas.id}}
end
local handlers,menuHooks={},{}
Events={OnClientCommand={Add=function(fn) handlers[#handlers+1]=fn end},
 OnFillInventoryObjectContextMenu={Add=function(fn) menuHooks[#menuHooks+1]=fn end}}
require 'VLS_PropaneServer'
local function refill(f) return VLS.PropaneServer.refillBlowTorch(f.chr,f.args) end
local function unchanged(f) near(f.torch.charge,0.25);near(f.gas.charge,1);eq(f.v.synced,0) end

test('main mod alone supports roof tank without KI5 adapter',function()
 local f=fixture();eq(VLS.ki5CampersAdapterApplied,nil);eq(refill(f),true);near(f.torch.charge,1);eq(f.gas:getCurrentUses(),9475)
end)
for _,name in ipairs({'Base.StepVan','Base.Van','Base.VanSeats','Base.SUV','Base.PickUpVan'}) do
 test(name..' installed roof propane source works',function() local f=fixture(name);eq(refill(f),true) end)
end
test('second roof tank supported when present',function() local f=fixture(nil,'VLSRoofPropane2');eq(refill(f),true) end)
test('first empty tank is skipped by selection',function()
 local f=fixture(nil,'VLSRoofPropane2');f.v:add('VLSRoofPropane1',item('Base.PropaneTank',0))
 local gas,part=VLS.getInstalledPropaneSource(f.v);eq(gas,f.gas);eq(part,f.part)
end)
test('one tank does not require a second tank slot',function() local f=fixture('Base.SUV');eq(f.v:getPartById('VLSRoofPropane2'),nil);eq(refill(f),true) end)
for _,mode in ipairs({'no rack','wrong rack','uninstalled tank','petrol','empty tank','not drainable','unknown vehicle'}) do
 test('reject '..mode,function()
  local f=fixture()
  if mode=='no rack' then f.v.parts.VLSFixedRoofRack.it=nil
  elseif mode=='wrong rack' then f.v.parts.VLSFixedRoofRack.it=item('Base.MetalBar')
  elseif mode=='uninstalled tank' then f.part.it=nil
  elseif mode=='petrol' then f.gas.ft='Base.PetrolCan'
  elseif mode=='empty tank' then f.gas.charge=0
  elseif mode=='not drainable' then f.gas.drainable=false
  elseif mode=='unknown vehicle' then f.v.name='Other.StepVan' end
  local before=f.gas.charge;eq(refill(f),false);near(f.torch.charge,0.25);near(f.gas.charge,before)
 end)
end
for _,mode in ipairs({'moving','inside','too far','wrong area','missing torch','wrong torch','full torch','zero max uses'}) do
 test('no debit when '..mode,function()
  local f=fixture()
  if mode=='moving' then f.v.stopped=false elseif mode=='inside' then f.chr.inside=f.v
  elseif mode=='too far' then f.chr.distance=4 elseif mode=='wrong area' then f.v.area=false
  elseif mode=='missing torch' then f.chr.items={} elseif mode=='wrong torch' then f.torch.ft='Base.Torch'
  elseif mode=='full torch' then f.torch.charge=1 elseif mode=='zero max uses' then f.torch.maximum=0 end
  local before=f.torch.charge;eq(refill(f),false);near(f.torch.charge,before);near(f.gas.charge,1)
 end)
end
test('tank replaced in same slot is rejected',function()
 local f=fixture();local other=item('Base.PropaneTank',1);f.part.it=other
 eq(refill(f),false);unchanged(f);near(other.charge,1)
end)
test('pinned empty source does not silently charge second tank',function()
 local f=fixture();f.gas.charge=0;local other=item('Base.PropaneTank',1);f.v:add('VLSRoofPropane2',other)
 eq(refill(f),false);near(f.torch.charge,0.25);near(other.charge,1)
end)
test('missing source identity rejected before native lookup',function() local f=fixture();f.args.tank=nil;eq(refill(f),false);unchanged(f) end)
for _,field in ipairs({'vehicle','torch','tank'}) do
 test('malformed '..field..' rejected',function()
  for _,value in ipairs({'2',{},true,1.5,0/0,math.huge,-math.huge}) do
   local f=fixture();f.args[field]=value;eq(refill(f),false);unchanged(f)
  end
 end)
end
test('partial refill consumes only remaining source',function()
 local f=fixture();f.torch.charge=0;f.gas:setCurrentUses(70)
 eq(refill(f),true);near(f.torch.charge,0.1);eq(f.gas:getCurrentUses(),0);eq(f.part.it,f.gas)
end)
test('normal refill synchronizes both items and vehicle fuel part',function()
 local f=fixture();eq(refill(f),true);eq(f.gas.synced,1);eq(f.torch.synced,1);eq(f.v.synced,1);eq(f.v.lastPart,f.part)
end)
test('two players cannot spend the same gas twice',function()
 local f=fixture();f.gas:setCurrentUses(70);f.torch.charge=0
 local other=item('Base.BlowTorch',0,10);local chr2=player(other)
 eq(refill(f),true)
 eq(VLS.PropaneServer.refillBlowTorch(chr2,{vehicle=f.v.id,part=f.part.id,tank=f.gas.id,torch=other.id}),false)
 near(f.torch.charge,0.1);near(other.charge,0);eq(f.gas:getCurrentUses(),0)
end)
test('immediate duplicate command after full refill does not debit',function()
 local f=fixture();eq(refill(f),true);local gas=f.gas:getCurrentUses();eq(refill(f),false);eq(f.gas:getCurrentUses(),gas)
end)
-- Register the actual KI5 profiles after the main common service is loaded.
require 'VLS_KI5Campers_Config'
for _,name in ipairs({'Base.Trailer87Scamp13','Base.Trailer87Scamp16','Base.Trailer61Bambi16','Base.Trailer54FlyingCloud22'}) do
 test('existing KI5 source works '..name,function()
  local f=fixture(name,'DAMNPropaneTankOne');f.v.parts.VLSFixedRoofRack=nil
  eq(refill(f),true);eq(f.gas:getCurrentUses(),9475)
 end)
end
test('KI5 second tank works unchanged',function() local f=fixture('Base.Trailer87Scamp13','DAMNPropaneTankTwo');eq(refill(f),true) end)
-- Mock native timed action shell and UI infrastructure only.
ISBaseTimedAction={}
function ISBaseTimedAction:derive() return setmetatable({},{__index=self}) end
function ISBaseTimedAction:new(chr) return setmetatable({character=chr},{__index=self}) end
function ISBaseTimedAction:perform() self.didPerform=true end
function ISBaseTimedAction:stop() self.didStop=true end
function ISBaseTimedAction:setActionAnim(v) self.anim=v end
function ISBaseTimedAction:setOverrideHandModels(a,b) self.handA=a;self.handB=b end
function ISBaseTimedAction:getJobDelta() return 0.5 end
local currentPlayer,currentVehicle
getSpecificPlayer=function() return currentPlayer end
ISVehicleMenu={getVehicleToInteractWith=function() return currentVehicle end}
getCell=function() return {getGridSquare=function() return nil end} end
local queue={}
ISTimedActionQueue={add=function(a) queue[#queue+1]=a end}
ISPathFindAction={pathToVehicleArea=function(_,v,area) return {v=v,area=area,setOnFail=function(self,fn,chr) self.failed=fn end} end}
HaloTextHelper={addBadText=noop}
Metabolics={LightWork='LightWork'}
getText=function(key) return key=='IGUI_VLSRefillBlowTorch' and '为喷枪充气' or key end
VLS.providers={};VLS.registerMechanicsUIProvider=function(id,p) VLS.providers[id]=p end
for _,m in ipairs({'Definitions/ContainerButtonIcons','ISUI/ISInventoryPaneContextMenu','Vehicles/ISUI/ISVehicleMenu',
 'Vehicles/ISUI/ISVehicleMechanics','Vehicles/TimedActions/ISPathFindAction','TimedActions/ISBaseTimedAction',
 'TimedActions/ISTimedActionQueue','VLS_VehicleMechanicsIcons'}) do package.loaded[m]=true end
local requests={}
sendClientCommand=function(chr,module,command,args) requests[#requests+1]={chr=chr,module=module,command=command,args=args} end
require 'VLS_PropaneRefill'
dofile(ki5..'client/VLS_KI5Campers_Utilities.lua')
dofile(ki5..'server/VLS_KI5Campers_Server.lua')
test('main plus KI5 registers only one refill menu and one command handler',function() eq(#menuHooks,1);eq(#handlers,1) end)
local function menu(f,items)
 currentPlayer=f.chr;currentVehicle=f.v
 local ctx={options={}}
 function ctx:addOption(label,target,fn,...) self.options[#self.options+1]={label=label,target=target,fn=fn,args={...}} end
 menuHooks[1](0,ctx,items or {f.torch});return ctx
end
for _,kind in ipairs({'roof','KI5'}) do
 test(kind..' UI follows existing path, action, duration, animation',function()
  local f=kind=='roof' and fixture() or fixture('Base.Trailer87Scamp13','DAMNPropaneTankOne')
  local ctx=menu(f,{{items={f.torch}}});eq(#ctx.options,1);local op=ctx.options[1];eq(op.label,'为喷枪充气')
  queue={};op.fn(op.target,(table.unpack or unpack)(op.args));eq(#queue,2)
  local action=queue[2];eq(action.maxTime,50);eq(action.partId,f.part.id);eq(action.tankId,f.gas.id)
  action:start();eq(action.anim,'Welding');eq(action.handA,'Base.CraftingWeldingTorch');eq(f.chr.sounds,1)
  action:update();near(f.torch.job,0.5)
 end)
end
test('menu absent for full torch or moving vehicle',function()
 local f=fixture();f.torch.charge=1;eq(#menu(f).options,0)
 f.torch.charge=0.25;f.v.stopped=false;eq(#menu(f).options,0)
end)
test('MP client only requests; server alone performs debit',function()
 local f=fixture();local action=VLSRefillBlowTorchFromVehicleAction:new(f.chr,f.v,f.part,f.torch)
 requests={};isMPClient=true;action:perform();isMPClient=false
 eq(#requests,1);unchanged(f);local req=requests[1];eq(req.module,'VehicleLivingSlots');eq(req.args.tank,f.gas.id)
 handlers[1](req.module,req.command,req.chr,req.args);near(f.torch.charge,1);eq(f.gas:getCurrentUses(),9475)
end)
test('single player action invokes same authoritative refill',function()
 local f=fixture();requests={};VLSRefillBlowTorchFromVehicleAction:new(f.chr,f.v,f.part,f.torch):perform()
 eq(#requests,0);near(f.torch.charge,1);eq(f.gas:getCurrentUses(),9475)
end)
test('cancelled action does not consume gas',function()
 local f=fixture();local a=VLSRefillBlowTorchFromVehicleAction:new(f.chr,f.v,f.part,f.torch);a:start();a:update();a:stop()
 unchanged(f);near(f.torch.job,0);eq(a.didStop,true)
end)
test('source replaced during action cancels before submission',function()
 local f=fixture();local a=VLSRefillBlowTorchFromVehicleAction:new(f.chr,f.v,f.part,f.torch)
 f.part.it=item('Base.PropaneTank',1);requests={};isMPClient=true;a:perform();isMPClient=false
 eq(#requests,0);unchanged(f)
end)
test('source replaced after MP send rejected by server',function()
 local f=fixture();requests={};isMPClient=true
 VLSRefillBlowTorchFromVehicleAction:new(f.chr,f.v,f.part,f.torch):perform();isMPClient=false
 local q=requests[1];f.part.it=item('Base.PropaneTank',1);handlers[1](q.module,q.command,q.chr,q.args);unchanged(f)
end)
test('moved torch found recursively and submitted by identity',function()
 local f=fixture();local subbag={f.torch};f.chr.items={}
 function f.chr:getInventory() return {getItemWithIDRecursiv=function(_,id) return subbag[1].id==id and subbag[1] or nil end} end
 eq(refill(f),true)
end)
test('propane UI remaining percentage covers roof and KI5',function()
 for _,f in ipairs({fixture(),fixture('Base.Trailer87Scamp13','DAMNPropaneTankOne')}) do
  local p=VLS.providers.vehiclePropane;eq(p.matches(f.part),true);near(p.remaining(f.part),1)
 end
end)
print(string.format('RESULT tests=%d failures=%d',total,failures))
if failures>0 then error('vehicle propane regression failures') end
