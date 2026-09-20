-- Loads the actual shared resolver, shared refill handler, client action and KI5
-- adapter. Native PZ objects are mocked; this is not an engine/MP playtest.
local root=assert(arg[1], 'repo root required')
local roundtripPath=root.."/tests/net_action_roundtrip.lua"
local roundtripFile=io.open(roundtripPath)
if roundtripFile then roundtripFile:close()
else roundtripPath=root.."/../../tests/vehicle-living-slots/net_action_roundtrip.lua" end
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
Translator={getRecipeName=function(name) return name end}
local noop=function() end
Vector2={new=function()return {}end}
local isMPClient=false
isClient=function() return isMPClient end
isServer=function() return not isMPClient end
-- Use real profiles: VanSeats has roof equipment but no interior profile.
package.loaded['Entity/TimedActions/ISHandcraftAction']=true
package.loaded['TimedActions/ISDeviceBatteryAction']=true
require 'VLS_Config'
require 'VLS_Propane'
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
 function i:setJobType(n) self.jobType=n end
 function i:getModData() self.md=self.md or {};return self.md end
 function i:setJobDelta(n) self.job=n end
 return i
end
instanceof=function(o,cls) return o and (cls=='InventoryItem' and o.ft~=nil or cls=='DrainableComboItem' and o.drainable) or false end
local vehicles={}
local function vehicle(name)
 nextId=nextId+1;local v={id=nextId,name=name or 'Base.StepVan',parts={},stopped=true,area=true,synced=0}
 function v:getId() return self.id end
  function v:getScriptName() return self.name end
 function v:getScript() return {getFullName=function() return self.name end} end
 function v:getPartById(id) return self.parts[id] end
 function v:isStopped() return self.stopped end
 function v:isInArea() return self.area end
 function v:getAreaFacingPosition(area,point)
  self.facingArea=area;return {getX=function()return 8.5 end,getY=function()return 11.25 end}
 end
 function v:transmitPartUsedDelta(p) self.synced=self.synced+1;self.lastPart=p end
 function v:add(id,it)
  local p={id=id,it=it,v=self}
  function p:getId() return self.id end
  function p:getVehicle() return self.v end
  function p:getInventoryItem() return self.it end
  function p:getArea() return self.id:find('VLSRoofPropane') and 'VLSRoofPropaneService' or 'TruckBed' end
  self.parts[id]=p;return p
 end
 v:add('VLSFixedRoofRack',item('Base.VLSFixedRoofRack'))
 vehicles[v.id]=v;return v
end
getVehicleById=function(id) assert(type(id)=='number');return vehicles[id] end
local function player(torch)
 local p={items={[torch.id]=torch},distance=1,inside=nil,sounds=0,stoppedSounds=0}
 local inv={getItemWithIDRecursiv=function(_,id) return p.items[id] end}
 function p:isTimedActionInstant() return false end
 function p:hasTrait() return false end
 function p:isWearingAwkwardGloves() return false end
 function p:getInventory() return inv end
 function p:getVehicle() return self.inside end
 function p:DistToProper() return self.distance end
 function p:getX() return 0 end;function p:getY() return 0 end;function p:getZ() return 0 end
  function p:shouldBeTurning() return self.turning==true end
 function p:faceLocationF(x,y)self.facing={x,y}end
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

local native=assert(arg[2])
package.loaded['TimedActions/ISBaseTimedAction']=true
ISBaseTimedAction={}
function ISBaseTimedAction:derive() return setmetatable({},{__index=self}) end
function ISBaseTimedAction:new(chr) return setmetatable({character=chr},{__index=self}) end
function ISBaseTimedAction:perform() self.didPerform=true end
function ISBaseTimedAction:stop() self.didStop=true end
-- Use native forceStop: server actions have no client self.action.
function ISBaseTimedAction:setActionAnim(v) self.anim=v end
-- Execute the real native method: dedicated server actions have no self.action.
local f=assert(io.open(native..'/shared/TimedActions/ISBaseTimedAction.lua','r'))
local nativeBase=f:read('*a');f:close()
local first=assert(nativeBase:find('function ISBaseTimedAction:setOverrideHandModels(',1,true))
local last=assert(nativeBase:find('\nend',first,true))
assert((loadstring or load)(nativeBase:sub(first,last+3)))()
local stopFirst=assert(nativeBase:find('function ISBaseTimedAction:forceStop()',1,true))
local stopLast=assert(nativeBase:find('\nend',stopFirst,true))
assert((loadstring or load)(nativeBase:sub(stopFirst,stopLast+3)))()
function ISBaseTimedAction:getJobDelta() return 0.5 end
ArrayList={new=function()
 local t={};function t:add(x) self[#self+1]=x end;function t:size() return #self end
 function t:get(i) return self[i+1] end; return t
end}
local inputs=ArrayList.new();inputs:add('torch');inputs:add('tank')
local recipe={getInputs=function()return inputs end,getTime=function()return 50 end,
 getTranslationName=function()return 'RefillBlowTorch' end,getName=function()return 'RefillBlowTorch' end,
 isCanWalk=function()return false end,getTimedActionScript=function()return nil end}
ScriptManager={instance={getCraftRecipe=function(_,name)eq(name,'Base.RefillBlowTorch');return recipe end}}
CharacterTrait={ALL_THUMBS=1};DebugType={CraftLogic=1};log=noop;showDebugInfoInChat=noop
convertToPZNetTable=function(x)assert(type(x)=="table", "expected argument of type KahluaTable");return x end;ISInventoryPage={dirtyUI=noop}
local nativePerform=0
HandcraftLogic={new=function(chr)
 local supplied=ArrayList.new();local consumed=ArrayList.new()
 local output=item('Base.BlowTorch',1,10)
 local data={offerInputItem=function(_,script,it) supplied:add(it);return true end,
 getAllInputItems=function()return supplied end,getAllConsumedItems=function()return consumed end,
 luaCallOnCreate=function()nativePerform=nativePerform+1 end,
 processDestroyAndUsedItems=function()chr.items[supplied:get(0).id]=nil end}
 return {setContainers=noop,setRecipe=noop,setTargetVariableInputRatio=noop,
 setManualSelectInputs=noop,clearManualInputs=function()for i=#supplied,1,-1 do supplied[i]=nil end end,
 getRecipeData=function()return data end,canPerformCurrentRecipe=function()return #supplied==2 end,
 getModelHandOne=function()return 'native-hand-one' end,getModelHandTwo=function()return 'native-hand-two' end,
 performCurrentRecipe=function()consumed:add(supplied:get(0));return true end,
 getCreatedOutputItems=function(_,list)list:add(output)end}
end}
Actions={addOrDropItem=function(chr,it)chr.items[it.id]=it end}
dofile(native..'/shared/Entity/TimedActions/ISHandcraftAction.lua')
package.loaded['Entity/TimedActions/ISHandcraftAction']=true
require 'VLS_PropaneRefillAction'
local Action=VLSRefillBlowTorchFromVehicleAction
local function action(f) return Action:new(f.chr,f.args.vehicle,f.args.part,f.args.torch,f.args.tank) end
local function clientAction(f)
 local a=action(f)
 a.action={setOverrideHandModelsObject=function(_,one,two) a.handA=one;a.handB=two end}
 return a
end
local function valid(f) return not not action(f):isValid() end
for _,name in ipairs({'Base.StepVan','Base.Van','Base.VanSeats','Base.SUV','Base.PickUpVan'}) do
 test(name..' mounted input identity',function()eq(valid(fixture(name)),true)end)
end
for _,mode in ipairs({'moving','inside','far','wrong area','missing torch','wrong torch','full torch',
 'no rack','wrong rack','missing tank','empty tank','wrong tank','replacement','unsupported'}) do
 test('reject '..mode,function()
  local f=fixture()
  if mode=='moving' then f.v.stopped=false elseif mode=='inside' then f.chr.inside=f.v
  elseif mode=='far' then f.chr.distance=4 elseif mode=='wrong area' then f.v.area=false
  elseif mode=='missing torch' then f.chr.items={} elseif mode=='wrong torch' then f.torch.ft='Base.Torch'
  elseif mode=='full torch' then f.torch.charge=1 elseif mode=='no rack' then f.v.parts.VLSFixedRoofRack=nil
  elseif mode=='wrong rack' then f.v.parts.VLSFixedRoofRack.it=item('Base.MetalBar')
  elseif mode=='missing tank' then f.part.it=nil elseif mode=='empty tank' then f.gas.charge=0
  elseif mode=='wrong tank' then f.gas.ft='Base.PetrolCan' elseif mode=='replacement' then f.part.it=item('Base.PropaneTank',1)
  elseif mode=='unsupported' then f.v.name='Other.Vehicle' end
  eq(valid(f),false)
 end)
end
for _,field in ipairs({'vehicle','tank','torch'}) do
 test('malformed '..field..' stops before Java lookup',function()
  for _,bad in ipairs({true,{},'1',1.5,0/0,math.huge,-math.huge}) do
   local f=fixture();f.args[field]=bad;eq(valid(f),false)
  end
 end)
end
test('original recipe duration replaces hardcoded action time',function()eq(action(fixture()).maxTime,250)end)
test('native start and original recipe receive the real installed tank',function()
 local f=fixture();local a=clientAction(f);a:start();eq(a.didStop,nil)
 eq(a.items:get(0),f.torch);eq(a.items:get(1),f.gas);eq(a.handA,'native-hand-one')
 a:update();eq(f.v.facingArea,'VLSRoofPropaneService');near(f.chr.facing[1],8.5)
end)
test('dedicated server binds installed recipe inputs without presentation action',function()
 local f=fixture();local a=action(f);eq(a.action,nil)
 a:serverStart();eq(a.didStop,nil);eq(a.items:get(1),f.gas)
 eq(a.handA,nil);eq(f.gas.jobType,nil);eq(f.torch.jobType,nil)
end)
for _,mode in ipairs({'moving','inside','far','missing torch','full torch',
 'missing tank','empty tank','replacement','native recipe rejects inputs'})do
 test('headless server rejects '..mode..' without effects',function()
  local f=fixture();local a=action(f);local before=nativePerform
  local oldLogic=HandcraftLogic.new
  if mode=='moving' then f.v.stopped=false elseif mode=='inside' then f.chr.inside=f.v
  elseif mode=='far' then f.chr.distance=4 elseif mode=='wrong area' then f.v.area=false
  elseif mode=='missing torch' then f.chr.items={} elseif mode=='full torch' then f.torch.charge=1
  elseif mode=='missing tank' then f.part.it=nil elseif mode=='empty tank' then f.gas.charge=0
  elseif mode=='replacement' then f.part.it=item('Base.PropaneTank',1)
  elseif mode=='native recipe rejects inputs' then HandcraftLogic.new=function(...)
   local logic=oldLogic(...);logic.canPerformCurrentRecipe=function()return false end;return logic end
  end
  local gasBefore=f.gas.charge;local torchBefore=f.torch.charge
  local finished=0;a.netAction={forceComplete=function()finished=finished+1 end}
  eq(a.action,nil)
  local ok,err=pcall(function()a:serverStart()end);HandcraftLogic.new=oldLogic
  assert(ok,err);eq(finished,1);eq(a:isValid(),false)
  near(f.gas.charge,gasBefore);near(f.torch.charge,torchBefore)
  -- Scheduler completes even rejected actions; later recovery must not revive crafting.
  f.v.stopped=true;f.chr.inside=nil;f.chr.distance=1;f.v.area=true
  f.part.it=f.gas;f.gas.charge=1;f.torch.charge=.25;f.chr.items[f.torch.id]=f.torch
  eq(a:complete(),true);eq(a:complete(),true)
  eq(nativePerform,before);near(f.gas.charge,1);near(f.torch.charge,.25);eq(f.v.synced,0)
  eq(f.chr.items[f.torch.id],f.torch)
 end)
end
test('native turning wait completes before client crafting starts',function()
 local f=fixture();local a=clientAction(f);f.chr.turning=true
 eq(a:waitToStart(),true);eq(a.logic,nil);eq(f.v.facingArea,'VLSRoofPropaneService')
 f.chr.turning=false;eq(a:waitToStart(),false);a:start();eq(a.items:get(1),f.gas)
end)
for _,arrives in ipairs({true,false})do
 test('path arrival with delayed server coordinates: arrives='..tostring(arrives),function()
  local f=fixture();local a=action(f);local finished=0;local before=nativePerform
  a.netAction={forceComplete=function()finished=finished+1 end}
  -- Native path has completed locally; server still has the last nearby position.
  f.v.area=false;a:serverStart();eq(finished,0);eq(a.items:get(1),f.gas)
  eq(nativePerform,before);eq(a:isValid(),false)
  f.v.area=arrives;eq(a:complete(),true)
  eq(nativePerform,before+(arrives and 1 or 0));eq(f.v.synced,arrives and 1 or 0)
  if not arrives then
   eq(f.chr.items[f.torch.id],f.torch);near(f.gas.charge,1)
   f.v.area=true;eq(a:complete(),true);eq(nativePerform,before)
  end
 end)
end
test('native client forceStop is retained on invalid input',function()
 local f=fixture();local a=clientAction(f);local stopped=0
 a.action.forceStop=function()stopped=stopped+1 end
 f.part.it=nil;a:start();eq(stopped,1)
end)
test('native completion creates output and destroys old torch once',function()
 local f=fixture();local a=action(f);a:serverStart();local before=nativePerform
 a:complete();eq(nativePerform,before+1);eq(f.chr.items[f.torch.id],nil);eq(f.v.synced,1)
 a:complete();eq(nativePerform,before+1)
end)
test('cancel never invokes recipe or consumes mounted input',function()
 local f=fixture();local a=clientAction(f);a:start();local before=nativePerform;a:stop()
 eq(nativePerform,before);eq(f.chr.items[f.torch.id],f.torch);near(f.gas.charge,1)
end)
test('replacement during action blocks native completion',function()
 local f=fixture();local a=action(f);a:serverStart();f.part.it=item('Base.PropaneTank',1)
 local before=nativePerform;a:complete();eq(nativePerform,before)
end)
test('native constructor-name MP roundtrip preserves all identities',function()
 local f=fixture();local a=action(f)
 local roundtrip=dofile(roundtripPath)
 local server=roundtrip(Action,base..'shared/VLS_PropaneRefillAction.lua',a)
 eq(server.vehicleId,f.v.id);eq(server.partId,f.part.id);eq(server.torchId,f.torch.id);eq(server.tankId,f.gas.id)
 server:serverStart();eq(server.items:get(1),f.gas)
end)
require 'VLS_KI5Campers_Config'
for _,name in ipairs({'Base.Trailer87Scamp13','Base.Trailer87Scamp16','Base.Trailer61Bambi16',
 'Base.Trailer54FlyingCloud22','Base.Trailer61Airflyte','Base.Trailer61Astrodome'}) do
 test('KI5 native propane input '..name,function()eq(valid(fixture(name,'DAMNPropaneTankOne')),true)end)
end
test('sandbox disables roof refill but preserves KI5 tank',function()
 SandboxVars={VehicleLivingSlots={EnableRoofPropaneShortcut=false}}
 eq(valid(fixture()),false);eq(valid(fixture('Base.Trailer61Airflyte','DAMNPropaneTankOne')),true)
 SandboxVars=nil
end)
test('legacy custom command is no longer registered',function()require 'VLS_PropaneServer';eq(#handlers,0)end)
-- Exercise the real inventory hook with real profiles and mounted-item resolver.
for _,module in ipairs({'Definitions/ContainerButtonIcons','ISUI/ISInventoryPaneContextMenu',
 'Vehicles/ISUI/ISVehicleMenu','Vehicles/ISUI/ISVehicleMechanics',
 'Vehicles/TimedActions/ISPathFindAction','TimedActions/ISTimedActionQueue',
 'VLS_VehicleMechanicsIcons'}) do package.loaded[module]=true end
VLS.registerMechanicsUIProvider=noop
local nearby,current
ISVehicleMenu={getVehicleToInteractWith=function()return nearby end}
getSpecificPlayer=function()return current end
getCell=function()return nil end
require 'VLS_PropaneRefill'
local function menuCount(f)
 nearby,current=f.v,f.chr
 local count=0
 local context={addOption=function(_,name)eq(name,'RefillBlowTorch');count=count+1 end}
 for _,hook in ipairs(menuHooks)do hook(0,context,{f.torch})end
 return count
end
for name in pairs(VLSRoofCargo.vehicleScripts) do
 test('roof equipment only, menu and action '..name,function()
  for _,partId in ipairs({'VLSRoofPropane1','VLSRoofPropane2'})do
   local f=fixture(name,partId)
   eq(menuCount(f),1);eq(valid(f),true)
   f.part.it=nil;eq(menuCount(f),0);eq(valid(f),false)
   f.part.it=item('Base.PetrolCan',1);eq(menuCount(f),0);eq(valid(f),false)
   f.part.it=f.gas;f.gas.charge=0;eq(menuCount(f),0);eq(valid(f),false)
   f.gas.charge=1;f.v.parts[partId]=nil;eq(menuCount(f),0);eq(valid(f),false)
  end
 end)
end
for name,profile in pairs(VLS.vehicleProfiles)do
 for _,partId in ipairs(profile.propaneTankParts or {})do
  test('KI5 actual installed tank menu '..name..' '..partId,function()
   local f=fixture(name,partId);eq(menuCount(f),1);eq(valid(f),true)
   f.part.it=nil;eq(menuCount(f),0);eq(valid(f),false)
  end)
 end
end
test('VanSeats has no artificial interior profile',function()
 eq(VLS.getVehicleProfile(vehicle('Base.VanSeats')),nil)
end)
-- One real menu callback queues native walking followed by one recipe action.
dofile(native..'/client/Vehicles/TimedActions/ISPathFindAction.lua')
for _,case in ipairs({{'Base.StepVan','VLSRoofPropane1'},{'Base.VanSeats','VLSRoofPropane1'},
 {'Base.Trailer61Airflyte','DAMNPropaneTankOne'}})do
 test('one click walk then original refill '..case[1],function()
  local f=fixture(case[1],case[2]);nearby,current=f.v,f.chr;local queued={};local option
  ISTimedActionQueue={add=function(a)queued[#queued+1]=a end}
  local context={addOption=function(_,label,target,callback,...)option={target=target,callback=callback,args={...}}end}
  for _,hook in ipairs(menuHooks)do hook(0,context,{f.torch})end
  f.v.area=false;option.callback(option.target,unpack(option.args))
  eq(#queued,2);eq(queued[1].goal[1],'VehicleArea');eq(queued[1].goal[3],f.part:getArea())
  f.chr.getPathFindBehavior2=function()return {cancel=noop}end;f.chr.setPath2=noop
  queued[1]:perform();f.v.area=true;f.chr.turning=true
  local client=queued[2];client.action={setOverrideHandModelsObject=noop}
  eq(client:waitToStart(),true);f.chr.turning=false;eq(client:waitToStart(),false);client:start()
  local server=action(f);server.netAction={forceComplete=function()error('stale path position rejected')end}
  f.v.area=false;server:serverStart();f.v.area=true
  local count=nativePerform;server:complete();eq(nativePerform,count+1);server:complete();eq(nativePerform,count+1)
 end)
end
print('RESULT propane-native tests='..total..' failures='..failures)
assert(failures==0)
