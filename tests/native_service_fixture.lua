require=function()end
VLS={};package={loaded={}};unpack=unpack
ISBaseTimedAction={}
function ISBaseTimedAction:derive(n)local t={Type=n};t.__index=t;return setmetatable(t,{__index=self})end
function ISBaseTimedAction:new(c)return setmetatable({character=c},self)end
local noop=function()end
DebugType={CraftLogic=1};log=noop;CharacterTrait={ALL_THUMBS=1}
ArrayList={new=function()return {add=noop}end}
local recipe={getTimedActionScript=function()end,isCanWalk=function()return false end,getTime=function()return 50 end}
ScriptManager={instance={getCraftRecipe=function()return recipe end}}
local character={getInventory=function()return {}end,hasTrait=function()return false end,
 isWearingAwkwardGloves=function()return false end,isTimedActionInstant=function()return false end}
-- INSERT_HANDCRAFT
-- INSERT_BAD_PROPANE
local ok,err=pcall(function()return VLSRefillBlowTorchFromVehicleAction:new(character,42,"Tank",1,2)end)
assert(not ok and tostring(err):find("KahluaTable"),tostring(err))
-- INSERT_FIXED_PROPANE
local fixed=VLSRefillBlowTorchFromVehicleAction:new(character,42,"Tank",1,2)
assert(fixed.manualInputs==nil and fixed.maxTime==250)

-- The real native animation wrapper must fail on a dedicated-server action.
-- INSERT_BASE_HANDS
local presentationOk,presentationError=pcall(function()fixed:setOverrideHandModels(nil,nil)end)
assert(not presentationOk and tostring(presentationError):find('setOverrideHandModelsObject'))
local torch,tank={},{}
local inputItems={get=function(_,i)if i==0 then return torch else return tank end end,size=function()return 2 end}
local recipeInputs={size=function()return 2 end,get=function(_,i)return i end}
local data={offerInputItem=function()return true end,getAllInputItems=function()return inputItems end}
fixed.craftRecipe={getInputs=function()return recipeInputs end}
fixed.resolveInputs=function()return torch,tank end
fixed.isValid=function()return true end
fixed.clearItemsProgressBar=function()error('server invoked presentation')end
HandcraftLogic={new=function()return {setContainers=noop,setRecipe=noop,setTargetVariableInputRatio=noop,
 setManualSelectInputs=noop,clearManualInputs=noop,getRecipeData=function()return data end,
 canPerformCurrentRecipe=function()return true end}end}
fixed:serverStart()
assert(fixed.action==nil and fixed.items:get(1)==tank)

-- Reproduce the invalid server branch through the real native forceStop wrapper.
local cancelOk,cancelError=pcall(function()fixed:forceStop()end)
assert(not cancelOk and tostring(cancelError):find('forceStop'))
-- Then call the shipped repair using a real Java NetTimedAction (not a fake stop).
for _,invalid in ipairs({'invalid source','recipe rejects inputs'})do
 local rejected=VLSRefillBlowTorchFromVehicleAction:new(character,42,'Tank',1,2)
 rejected.netAction=NetTimedAction.new()
 rejected.clearItemsProgressBar=function()error('rejected server touched presentation')end
 local restoreLogic=HandcraftLogic.new
 if invalid=='invalid source' then
  rejected.resolveInputs=function()end
 else
  rejected.craftRecipe=fixed.craftRecipe
  rejected.resolveInputs=function()return torch,tank end
  HandcraftLogic.new=function(...)
   local logic=restoreLogic(...);logic.canPerformCurrentRecipe=function()return false end;return logic
  end
 end
 rejected:serverStart();HandcraftLogic.new=restoreLogic
 assert(rejected.vlsFinished and rejected.action==nil)
 -- Equipment can recover while completion is queued: do not resurrect this action.
 rejected.resolveInputs=function()return torch,tank end
 rejected.performRecipe=function()error('rejected server crafted output')end
 assert(rejected:complete()==true and rejected:complete()==true)
end

isClient=function()return false end;isServer=function()return true end
Metabolics={LightWork=1};ZomboidGlobals={EquippedOrWornEncumbranceMultiplier=.3}
syncItemFields=function()end;sendItemStats=function()end
local square={};getCell=function()return {getGridSquare=function()return square end}end
VLSRoofCargo={vehicleScripts={['Base.StepVan']=true}}
-- INSERT_TAKE_FUEL
-- INSERT_ROOF_FUEL
local function near(a,b)assert(math.abs(a-b)<.00001,tostring(a).." != "..tostring(b))end
local function create(amount,capacity)
 local f=FluidContainer.CreateContainer();f:setCapacity(capacity);f:addFluid(Fluid.Petrol,amount);return f
end
local function run(amount,capacity,progress)
 local roof,portable=create(amount,20),create(0,capacity)
 local function item(id,f)return {getID=function()return id end,getFullType=function()return 'Base.JerryCan' end,
  getFluidContainer=function()return f end,syncItemFields=function()end}end
 local roofItem,can=item(1,roof),item(2,portable)
 local part={getInventoryItem=function()return roofItem end,getArea=function()return 'VLSRoofGeneratorService' end}
 local v={getPartById=function(_,id)if id=='VLSRoofPetrol1'then return part end end,
  getScript=function()return {getFullName=function()return 'Base.StepVan' end}end,
  getAreaCenter=function()return {getX=function()return 1 end,getY=function()return 2 end}end,
  isStopped=function()return true end,isInArea=function()return true end,getZ=function()return 0 end,transmitPartItem=function()end}
 local pl={isDead=function()return false end,getVehicle=function()end,getZ=function()return 0 end,
  DistToProper=function()return 1 end,getInventory=function()return {contains=function()return true end}end,
  hasFullInventory=function()return false end,getFreeInventoryCapacity=function()return 100 end,
  isTimedActionInstant=function()return false end,setMetabolicTarget=function()end}
 local a=VLSRoofFuelAction:new(pl,v,can,1,-1,-1)
 if progress then a:updateUse(progress);near(roof:getAmount()+portable:getAmount(),amount)end
 a:complete();near(roof:getAmount()+portable:getAmount(),amount)
 near(portable:getAmount(),math.min(amount,capacity))
 for i=1,20 do
  local b=VLSRoofFuelAction:new(pl,v,can,1,-1,-1);b:complete()
  near(roof:getAmount()+portable:getAmount(),amount)
 end
 FluidContainer.DisposeContainer(roof);FluidContainer.DisposeContainer(portable)
end
run(8.75,3.25,.5);run(.25,10,1);run(.4,20,nil);run(19.75,20,.37);run(.9995,10,1);run(10,.9995,1)
return 'NATIVE_SERVICE_PROBE: boolean, animation and forceStop failures reproduced; native NetTimedAction rejection and safe completion; real fluid conservation 6 cases + 120 repeats'
