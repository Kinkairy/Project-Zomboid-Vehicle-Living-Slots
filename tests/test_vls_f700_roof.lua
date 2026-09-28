local root=assert(arg[1])
local f=assert(io.open(root..'/tests/test_vls_generator.lua'));local source=f:read('*a');f:close()
local boundary=assert(source:find('test("parked installed generator',1,true))
local prelude=source:sub(1,boundary-1)
local extra=[=[
package.loaded["Vehicles/TimedActions/ISUninstallVehiclePart"]=true
local returned
ISUninstallVehiclePart={complete=function(self)
 returned=self.part.item;self.part.item=nil;return true
end}
Vehicles={UninstallTest={Default=function()return true end}}
package.loaded.VLS_InstallGuard=true
local A=require "VLS_KI5F700_Config"
local R=require "VLS_KI5F700_Roof"
local F=V.RoofFuel
local originalF,originalG=F.getPart,G.getPart
dofile(root.."/workshop/Contents/mods/VehicleLivingSlotsKI5F700/common/media/lua/shared/VLS_KI5F700_Roof.lua")
eq(F.getPart,originalF);eq(G.getPart,originalG)
local plain=fixture();eq(G.getPart(plain),plain.parts[G.PART])
for _,model in ipairs({"Base.87fordB700school","Base.87fordB700prison","Base.87fordB700military"})do
 test(model.." core generator state and native uninstall safety",function()
  local v,it,s,b,pl,gp=fixture()
  v.name=model;v.parts[G.PART]=nil;v.parts.DAMNGenerator=gp;gp.id="DAMNGenerator"
  eq(G.getPart(v),gp);G.update(v)
  local obj=assert(G.object(v));eq(obj:isConnected(),false)
  local action=setmetatable({vehicle=v,part=gp},{__index=ISUninstallVehiclePart})
  obj:setConnected(true);eq(R.uninstallTest(v,gp,pl),false);eq(action:complete(),false)
  obj:setConnected(false);obj:setActivated(true);eq(action:complete(),false)
  obj:setActivated(false);obj:setFuel(2.375);obj:setCondition(71)
  eq(R.uninstallTest(v,gp,pl),true);eq(action:complete(),true)
  eq(returned,it);eq(gp.item,nil);eq(G.object(v),nil);eq(obj:getObjectIndex(),-1)
  near(it.md.fuel,2.375);eq(it.condition,71);eq(s.dock,nil)
  gp.item=it;G.update(v);eq(G.object(v):isConnected(),false)
  local old=G.object(v);v.x=v.x+1;G.update(v)
  eq(old:getObjectIndex(),-1);eq(s.dock,nil);near(it.md.fuel,2.375)
 end)
 test(model.." two original roof cans use common finite source",function()
  local v=fixture();v.name=model
  local function add(id,identity,amount)
   local fluid={amount=amount,getAmount=function(self)return self.amount end,
    contains=function(_,kind)return kind==Fluid.Petrol end,canPlayerEmpty=function()return true end,
    adjustAmount=function(self,n)self.amount=n end}
   local it=item(identity,"Base.PetrolCan",fluid)
   local part={getInventoryItem=function()return it end,getArea=function()return "Roofrack" end}
   v.parts[id]=part;return it,fluid,part
  end
  local a,fa,pa=add("DAMNGasCanOne",11,2.5);local b,fb,pb=add("DAMNGasCanTwo",12,7.25)
  eq(F.getPart(v,"VLSRoofPetrol1"),pa);eq(F.getPart(v,"VLSRoofPetrol2"),pb);eq(F.getPart(v,"VLSRoofPetrol3"),nil)
  local source=F.capture(v);near(source:getPipedFuelAmount(),9.75)
  source:setPipedFuelAmount(5);near(fa.amount,0);near(fb.amount,5)
  source:setPipedFuelAmount(0);near(fa.amount+fb.amount,0)
  fa.amount=2;fb.amount=4;source=F.capture(v)
  add("DAMNGasCanOne",13,100);near(source:getPipedFuelAmount(),4)
  source:setPipedFuelAmount(1);near(fb.amount,1)
  SandboxVars.VehicleLivingSlots={EnableRoofPetrolShortcut=false}
  near(source:getPipedFuelAmount(),0)
  SandboxVars.VehicleLivingSlots=nil
 end)
end
print("BUS_SHARED_ROOF_PASS tests="..n.." core fuel and generator functions executed")
]=]
assert(loadstring(prelude..extra,'@bus-shared-roof-regression'))()
