-- Actual optional module + unchanged Workshop core. Only engine objects mocked.
local root=assert(arg[1])
package.loaded['Vehicles/Vehicles']=true
package.loaded['Entity/TimedActions/ISHandcraftAction']=true
package.loaded['TimedActions/ISDeviceBatteryAction']=true
package.loaded.VLS_InstallGuard=true
local ticks={}
Events={OnTick={Add=function(f)ticks[#ticks+1]=f end}}
isClient=function()return false end
local A=require 'VLS_KI5F700_Config'
local C=require 'VLS_KI5F700_Frames'
local R=VLSRoofCargo
local checks=0
local function check(x,s)assert(x,s);checks=checks+1 end
local function near(a,b)check(math.abs(a-b)<0.000001,'mass '..tostring(a)..' vs '..tostring(b))end
local nextId=0
local function item()
 nextId=nextId+1
 return {getFullType=function()return 'Base.VLSTopFrame'end,getWeight=function()return 0 end,getID=function()return nextId end,getCondition=function()return 100 end}
end
instanceItem=item
for _,name in ipairs({'Base.87fordF700bank','Base.87fordF700swat'})do
 local nominal=950+50*(#VLS.vehicleProfiles[name].universalParts+4)
 local v={name=name,initial=950,cargo=1550,parts={},list={},updates=0,controller={}}
 function v:getScriptName()return self.name end
 function v:getScript()return {getMass=function()return 950 end,getFullName=function()return name end}end
 function v:getPartById(id)return self.parts[id]end
 function v:getPartCount()return #self.list end
 function v:getPartByIndex(i)return self.list[i+1]end
 function v:getInitialMass()return self.initial end
 function v:setInitialMass(m)self.initial=m end
 function v:updateTotalMass()self.updates=self.updates+1;self.mass=math.floor(self.initial+self.cargo+0.5)end
 function v:getController()return self.controller end
 function v:isLocalPhysicSim()return true end
 function v:isRemovedFromWorld()return false end
 function v:isStopped()return true end
 function v:isEngineRunning()return false end
 function v:isInArea()return true end
 function v:transmitPartItem()end
 local function part(id)
  local p={id=id}
  function p:getId()return self.id end
  function p:getVehicle()return v end
  function p:getInventoryItem()return self.item end
  function p:setInventoryItem(it)self.item=it end
  function p:getItemContainer()return nil end
  function p:getArea()return 'TruckBed'end
  v.parts[id]=p;v.list[#v.list+1]=p;return p
 end
 local cargo=part('TruckBed')
 function cargo:getItemContainer()return {getCapacityWeight=function()return v.cargo end}end
 local frames={};for i=1,4 do frames[i]=part(A.frames[i]);part(A.overhead[i])end
 local chr={isDead=function()return false end,getVehicle=function()return nil end}
 v:updateTotalMass()
 for i,frame in ipairs(frames)do
  check(C.isPart(frame),'frame identity')
  check(R.fabricationSpec(frame).materials['Base.MetalPipe']==4,'StepVan materials')
  check(C.canInstall(chr,frame),'can install frame '..i)
  local fixed=item();local txn=assert(C.prepareInstall(chr,frame,fixed))
  frame.item=fixed;txn.commit()
  near(v.initial,950-(950+v.cargo)*i*40.625/nominal)
 end
 local old=v.updates;for i=1,100 do C.sync(v,frames[4])end;check(v.updates==old,'stable update is idempotent')
 v.cargo=2500;for i=1,30 do for _,f in ipairs(ticks)do f()end end
 near(v.initial,950-3450*4*40.625/nominal)
 local cupboard=v.parts[A.overhead[4]];cupboard.item={getWeight=function()return 1 end}
 check(not C.canDismantle(chr,frames[4]),'cannot remove support under installed furniture')
 cupboard.item=nil
 for i=4,1,-1 do
  check(C.canDismantle(chr,frames[i]),'can dismantle empty support')
  frames[i].item=nil;C.destroyed(v,frames[i])
  near(v.initial,950-(950+v.cargo)*(i-1)*40.625/nominal)
 end
 near(v.initial,950)
 -- The native fabrication transaction calls rollback after assignment failure.
 local txn=assert(C.prepareInstall(chr,frames[4],item()))
 frames[4].item=item();check(not pcall(txn.commit),'wrong assigned item aborts commit')
 frames[4].item=nil;txn.rollback();near(v.initial,950)
 v.initial=123;check(C.preview(frames[4])==nil,'foreign mass rejected');check(C.sync(v,frames[4])==false,'foreign mass untouched');near(v.initial,123)
 v.initial=950;v.cargo=0/0;check(C.preview(frames[4])==nil,'invalid cargo rejected');v.cargo=0
 local oldName=v.name;v.name='Base.87fordF700box';check(not C.isPart(frames[4]),'unrequested model excluded');check(R.fabricationSpec(frames[4])==nil,'no recipe leaks');v.name=oldName
 isClient=function()return true end;check(C.prepareInstall(chr,frames[1],item())==nil,'client cannot commit server transaction');isClient=function()return false end
end
check(#VLS.TOP_FRAME_PART_IDS==3 and #VLS.Chassis.TOP_IDS==3,'core frame registries unchanged')
check(VLS.Chassis.family({getScript=function()return {getFullName=function()return 'Base.87fordF700swat'end}end})==nil,'no vanilla or camper masquerading')
print('F700_FRAMES_PASS checks='..checks)
