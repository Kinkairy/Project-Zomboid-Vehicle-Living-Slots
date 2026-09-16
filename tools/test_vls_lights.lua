-- Real VLS code, simulated native condition attenuation; no rendered-light claim.
local root=arg[1] or "."
local path=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
local n=0
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local function near(a,b)assert(math.abs(a-b)<0.00001,tostring(a).." != "..tostring(b))end
local server=false
isServer=function()return server end
local noop=function()end
VLSRoofCargo={lamps={VLSRoofHeadlight1=1,VLSRoofHeadlight2=2,VLSRoofHeadlight3=3,VLSRoofHeadlight4=4},Create=noop}
package.loaded.VLS_RoofCargo=true
local charges=0
Vehicles={Update={Headlight=function(v,p,minutes)
 local active=v.on and p.item~=nil and v.charge>0;p:setLightActive(active)
 if active and not v.engine then charges=charges+minutes end
end},InstallComplete={Default=noop},UninstallComplete={Default=noop}}
dofile(path.."shared/VLS_RoofLights.lua")
local L=VLSRoofLights
local function vector(x,y,z)return {x=function()return x end,y=function()return y end,z=function()return z end}end
local function fixture(i,condition,maximum,normalized)
 local it={condition=condition,maximum=maximum,activated=true,getCondition=function(self)return self.condition end,getConditionMax=function(self)return self.maximum end,
 setActivated=function(self,v)self.activated=v end}
 local model={getOffset=function()return vector(i/10,0.5,1)end}
 local script={getModelOffset=function()return vector(0,0,0)end,getModelScale=function()return 1 end,getExtents=function()return vector(2,1,4)end}
 local v={charge=1,on=true,engine=true,getScript=function()return script end,
 getHeadlightsOn=function(self)return self.on end,getBatteryCharge=function(self)return self.charge end,getSquare=function()return {}end}
 local p={item=it,condition=condition,models={},calls=0}
 function p:getInventoryItem()return self.item end
 function p:getId()return 'VLSRoofHeadlight'..i end
 function p:getVehicle()return v end
 function p:getCondition()return self.condition end
 function p:getScriptPart()return {getModel=function()return model end}end
 function p:getLight()return self.light end
 function p:createSpotLight(x,z,dist,intensity,dot,focus)
  self.calls=self.calls+1
  self.light=self.light or {active=false,getActive=function(self)return self.active end}
  self.light.x=x;self.light.z=z;self.light.dist=dist;self.light.intensity=intensity;self.light.dot=dot
 end
 function p:ratio()return 0.5+0.5*(normalized and (self.item and self.item.condition/self.item.maximum or 0) or self.condition/100)end
 function p:getLightDistance()return self.light.dist*self:ratio()end
 function p:getLightIntensity()return self.light.intensity*self:ratio()end
 function p:setLightActive(active)if self.light then self.light.active=active end end
 function p:setModelVisible(name,visible)self.models[name]=visible end
 return v,p,it
end
for i=1,4 do
 for _,max in ipairs({10,100})do
  for _,ratio in ipairs({0,0.5,1})do
   for _,normalized in ipairs({false,true})do
    test('lamp '..i..' max '..max..' health '..ratio..' normalized '..tostring(normalized),function()
     local v,p,it=fixture(i,max*ratio,max,normalized)
     L.Init(v,p)
     near(p:getLightDistance(),48*(0.5+0.5*ratio));near(p:getLightIntensity(),0.5+0.5*ratio)
     near(p.light.x,i/10);near(p.light.z,0.5);eq(p.light.dot,0.75)
     eq(it.condition,max*ratio);eq(it.maximum,max);eq(p.light.active,true)
     eq(p.models['RoofSpotlightGlow'..i],true)
    end)
   end
  end
 end
end
test('existing stale light refreshed in place',function()
 local v,p=fixture(1,10,10,false);p:createSpotLight(99,99,1,0.01,0,0);local light=p.light
 L.Init(v,p);eq(p.light,light);near(p:getLightDistance(),48);near(p:getLightIntensity(),1)
end)
test('reinstall reconfigures and only clears portable switch',function()
 local v,p,it=fixture(1,10,10,false);L.Init(v,p);p.light.dist=1
 L.InstallComplete(v,p);near(p:getLightDistance(),48);eq(it.activated,false);eq(it.condition,10)
end)
test('unchanged tick reuses configured light',function()
 local v,p=fixture(1,10,10,false);L.Init(v,p);local before=p.calls
 for i=1,100 do L.Update(v,p,1)end;eq(p.calls,before)
end)
test('condition change recalibrates without editing item',function()
 local v,p,it=fixture(1,10,10,false);L.Init(v,p);it.condition=5;p.condition=5;L.Update(v,p,0)
 near(p:getLightDistance(),36);near(p:getLightIntensity(),0.75);eq(it.condition,5)
end)
test('uninstalled lamp switches off but keeps native slot light',function()
 local v,p,it=fixture(1,10,10,false);L.Init(v,p);local light=p.light;p.item=nil
 L.UninstallComplete(v,p,it);eq(p.light,light);eq(p.light.active,false);eq(p.models.RoofSpotlightHousing1,false)
end)
for _,case in ipairs({'off','battery','empty','engineoff'})do
 test('native switch/drain path '..case,function()
  local v,p=fixture(1,10,10,false);L.Init(v,p);charges=0
  if case=='off'then v.on=false elseif case=='battery'then v.charge=0 elseif case=='empty'then p.item=nil else v.engine=false end
  L.Update(v,p,2);L.SyncVisual(p)
  eq(p.light.active,case=='engineoff');eq(charges,case=='engineoff'and 2 or 0)
 end)
end
test('dedicated server does not populate visual cache',function()
 local v,p=fixture(1,10,10,false);server=true;L.Init(v,p);server=false;eq(L.visualParts[p],nil)
end)
print('RESULT roof-light tests='..n..' failures=0 (mocked native getters; no render test)')
