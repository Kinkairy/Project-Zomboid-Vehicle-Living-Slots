ISUninstallVehiclePart=ISUninstallVehiclePart or {complete=function()end}
Events=Events or {};Events.OnTick=Events.OnTick or {Add=function()end}
-- Requirement regressions retained from the discarded candidate; run against the approved 3.9 source lineage.
local root=assert(arg[1])
package.loaded.VLS_InstallGuard=true
local mods=root.."/workshop/Contents/mods/"
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(mods.."VehicleLivingSlots/common/media/lua/shared/VLS_Config.lua")
package.loaded.VLS_Config=V
getText=function(k)return k end
instanceof=function(item,kind)return item and item.kind==kind end
getItemNameFromFullType=function(k)return k end
if arg[2]=="campers-first" then
 package.loaded.VLS_Propane=true
 dofile(mods.."VehicleLivingSlotsKI5Campers/common/media/lua/shared/VLS_KI5Campers_Config.lua")
end
local baseline={};for name,p in pairs(V.vehicleProfiles)do baseline[name]=p end
local adapter=mods.."VehicleLivingSlotsKI5F700/common/media/lua/shared/VLS_KI5F700_Config.lua"
local A=dofile(adapter);local nameHook=V.getPartDisplayName;dofile(adapter);assert(nameHook==V.getPartDisplayName)
for name,p in pairs(baseline)do assert(V.vehicleProfiles[name]==p)end
for _,name in ipairs({"Base.87fordF700box"})do assert(V.vehicleProfiles[name]==nil)end
local checks=0
local function check(ok,message)assert(ok,message);checks=checks+1 end
for _,name in ipairs({"Base.87fordF700bank","Base.87fordB700school","Base.87fordB700prison","Base.87fordB700military"})do
 local p=assert(V.vehicleProfiles[name]);check(#p.universalParts==(A.isBus({getScriptName=function()return name end}) and 14 or 7) and #p.overheadParts==4 and #p.waterTankParts==(p.driverOnly and 4 or 2),"per-model capacities")
 local parts={};local v={getScriptName=function()return name end,getPartById=function(_,id)return parts[id]end}
 local function part(id,item)
  local x={item=item,getId=function()return id end,getVehicle=function()return v end,getInventoryItem=function(self)return self.item end};parts[id]=x;return x
 end
 local battery=part(V.AUX_BATTERY_PART_ID,{kind="DrainableComboItem",getFullType=function()return "Base.CarBattery2"end})
 check(V.getAuxBatteryPart(v)==battery,"auxiliary power")
 check(not V.isLargeVan(v) and not V.isMediumVan(v),"no vanilla class/exterior opt-in")
 for i,id in ipairs(p.universalParts)do
  local slot=part(id,nil)
  check(V.isUniversalPart(slot),"living part")
  check(V.getPartDisplayName(slot)==p.spacePassengers[i].nameKey,"localized empty name")
  for _,itemType in ipairs({"Base.Mov_Cot","Base.Mov_Microwave","Base.Mov_FridgeMini","Base.Mov_TrailerFridge","Base.Mov_BlueComboWasherDryer","Base.Mov_SmallPineCabinet","Base.TvWideScreen","Base.WaterDispenserBottle"})do
   check(V.isInstallationEnabled(slot,itemType),"install "..itemType)
  end
  SandboxVars={VehicleLivingSlots={EnableBeds=false}};check(not V.isInstallationEnabled(slot,"Base.Mov_Cot"),"bed sandbox");SandboxVars=nil
  slot.item={kind="Moveable",getWorldSprite=function()return nil end,getFullType=function()return "Base.Mov_Microwave"end,getDisplayName=function()return "native-microwave"end}
  check(V.getPartDisplayName(slot)=="native-microwave","native installed name")
 end
 for _,id in ipairs(p.waterTankParts)do
  local tank=part(id,nil);check(V.isWaterTankPart(tank) and V.hasWaterTankCapability(v),"water profile "..id)
 end
 local water={}
 for i,id in ipairs(p.waterTankParts)do
  local fluid={amount=i==1 and 0 or 65,getAmount=function(self)return self.amount end,getCapacity=function()return 65 end}
  local tankItem={getFullType=function()return "Base.NormalGasTank2"end,getID=function()return 900+i end,getFluidContainer=function()return fluid end}
  parts[id].item=tankItem;water[i]=tankItem
 end
 check(V.getInstalledWaterTank(v)==water[2],"use nonempty second tank")
 check(V.getInstalledWaterTank(v,p.waterTankParts[1])==water[1],"explicit first tank identity")
 check(V.getFillableWaterTank(v)==water[1],"fill first nonfull tank")
 local endpoints=V.getInstalledVehicleFluidEndpoints(v)
 check(#endpoints==#p.waterTankParts and endpoints[1].item~=endpoints[2].item,"two independent fluid endpoints")
 for i,id in ipairs(p.overheadParts)do
  local overhead=part(id,nil);check(V.isOverheadPart(overhead),"overhead "..i)
  local frame=part(A.frames[i],nil)
  check(A.frameIndex(frame)==i and not V.hasTopFrame(overhead),"empty frame "..i)
  frame.item={getFullType=function()return V.TOP_FRAME_ITEM_TYPE end,getCondition=function()return 100 end}
  check(V.hasTopFrame(overhead),"installed top frame "..i)
 end
 check(not V.isTopFramePart(part("VLSTopFrame5",nil)),"fifth frame excluded")
 check(not V.isOverheadPart(part("VLSOverhead4",nil)),"fifth overhead excluded")
 for _,id in ipairs(p.universalParts)do
  local freezer=part(V.FREEZER_PART_BY_UNIVERSAL[id],nil)
  check(V.UNIVERSAL_PART_BY_FREEZER[freezer:getId()]==id,"fridge/freezer mapping "..id)
 end
end
-- Compatibility in both optional-adapter load orders and repeat loading.
package.loaded.VLS_Propane=true
dofile(mods.."VehicleLivingSlotsKI5Campers/common/media/lua/shared/VLS_KI5Campers_Config.lua")
check(V.vehicleProfiles['Base.Trailer87Scamp13'].kind=='ki5Camper','campers retained')
check(V.vehicleProfiles['Base.87fordF700bank'].kind=='ki5F700','F700 retained')
-- Exact native distribution isolation: preserve the original KI5 cargo tables.
local oldCargo={rolls=4};local original={TruckBed=oldCargo};local selection={Normal=original,Specific={original}}
local untouchedSwat={Normal={TruckBed={rolls=9}}}
VehicleDistributions={{['87fordF700bank']=selection,['87fordF700swat']=untouchedSwat},EmptySeat={rolls=0}}
package.loaded['Vehicles/VehicleDistributions']=true
dofile(mods..'VehicleLivingSlots/common/media/lua/server/VLS_VehicleDistributions.lua')
check(VehicleDistributions[1]['87fordF700swat'].Normal.TruckBed==untouchedSwat.Normal.TruckBed,'SWAT native cargo retained')
check(#V.vehicleProfiles['Base.87fordF700swat'].seatPairs==6,'SWAT conversion profile')
local nextSelection=VehicleDistributions[1]['87fordF700bank']
check(nextSelection~=selection and nextSelection.Normal~=original,'isolated distributions')
check(nextSelection.Normal.TruckBed==oldCargo and original.SeatBed==nil,'native cargo retained')
local f700=V.vehicleProfiles['Base.87fordF700bank']
for _,id in ipairs(f700.universalParts)do
 check(nextSelection.Normal[id]==VehicleDistributions.EmptySeat,'empty '..id)
 check(nextSelection.Normal[V.FREEZER_PART_BY_UNIVERSAL[id]]==VehicleDistributions.EmptySeat,'empty freezer '..id)
end
for _,id in ipairs(f700.overheadParts)do check(nextSelection.Normal[id]==VehicleDistributions.EmptySeat,'empty '..id)end
check(#V.vehicleProfiles['Base.StepVan'].universalParts==5 and #V.vehicleProfiles['Base.StepVan'].overheadParts==3 and #V.vehicleProfiles['Base.StepVan'].waterTankParts==1,'StepVan remains 5/3/1')
-- Native seats/exits retain their original pixel positions; added rows are 2/2/2/1.
package.loaded.VLS_KI5F700_Config=A;package.loaded.VLS_SeatDisplay=true
SeatOffsetX={};SeatOffsetY={}
UIFont={Large=1};getTextManager=function()return {getFontHeight=function()return 16 end}end
ISCarMechanicsOverlay={CarList={}}
local inspect,fail
ISVehicleSeatUI={render=function(panel) if inspect then inspect(panel)end;if fail then error('injected render failure')end;return 42 end}
package.loaded['Vehicles/ISUI/ISVehicleSeatUI']=true
package.loaded.VLS_KI5Campers_Config=V
local camperUI=mods..'VehicleLivingSlotsKI5Campers/common/media/lua/client/VLS_KI5Campers_SeatUI.lua'
if arg[2]=='campers-first' then dofile(camperUI)end
dofile(mods..'VehicleLivingSlotsKI5F700/common/media/lua/client/VLS_KI5F700_SeatUI.lua')
if arg[2]~='campers-first' then dofile(camperUI)end
for _,name in ipairs({'Base.87fordF700bank'})do
 fail=false;SeatOffsetX[name]=5;SeatOffsetY[name]=-3
 local ids={'FrontLeft','FrontRight'}
 local nativeCount=#ids
 for _,a in ipairs(f700.spacePassengers)do ids[#ids+1]=a.passenger end
 local passengers,originals={},{}
 for i,id in ipairs(ids)do
  local x=(i%2==1 and 1 or -1)*(i<=2 and 0.6222 or 0.6778)
  local z=i<=2 and 1.6222 or ({0.1222,-0.6,-1.3556})[math.ceil((i-2)/2)] or -2.15
  local positions={}
  for _,key in ipairs({'inside','outside'})do
   local values=key=='inside' and {x,0.0556,z} or {x*2,-1.3333,-2.0556}
   local o={values=values,get=function(self,j)return self.values[j+1]end,set=function(self,X,Y,Z)self.values={X,Y,Z}end}
   originals[#originals+1]={o,values[1],values[2],values[3]}
   positions[key]={getOffset=function()return o end}
  end
  passengers[i]={getId=function()return id end,getPositionById=function(_,key)return positions[key]end,positions=positions}
 end
 local script={getCarMechanicsOverlay=function()return nil end,getExtents=function()return {x=function()return 2.4889 end,z=function()return 5.9778 end}end,getPassenger=function(_,i)return passengers[i+1]end,getPassengerCount=function()return #passengers end}
 local panel={width=263,height=500,close={setY=function(self,y)self.y=y end},setHeight=function(self,h)self.height=h end,vehicle={getScriptName=function()return name end,getScript=function()return script end}}
 local baseScale=500*0.7/5.9778
 local expected={}
 for i,p in ipairs(passengers)do
  local o=p.positions.inside:getOffset();expected[i]={x=131.5+5-o:get(0)*baseScale,y=250-3-o:get(2)*baseScale}
 end
 inspect=function()
  local rects={};local scale=panel.height*0.7/5.9778
  for i,p in ipairs(passengers)do
   local o=p.positions.inside:getOffset();rects[i]={x=131.5+5-o:get(0)*scale,y=panel.height/2-3-o:get(2)*scale}
   if i<=nativeCount then
    check(math.abs(rects[i].x-expected[i].x)<1e-8 and math.abs(rects[i].y-expected[i].y)<1e-8,'original native seat pixel coordinates')
    local original=originals[i*2-1];check(o:get(0)==original[2] and o:get(2)==original[4],'native seat vectors unchanged even during render')
   end
   local out=p.positions.outside:getOffset();local original=originals[i*2]
   check(math.abs((131.5-out:get(0)*scale)-(131.5-original[2]*baseScale))<1e-8,'original exit x')
   check(math.abs((panel.height/2-3-out:get(2)*scale)-(250-3-original[4]*baseScale))<1e-8,'original exit y')
  end
  local bottom=0;for i=1,nativeCount do bottom=math.max(bottom,expected[i].y)end
  for n=1,7 do
   local point=rects[nativeCount+n]
   local wantedX=n==7 and (expected[1].x+expected[2].x)/2 or expected[n%2==1 and 1 or 2].x
   check(math.abs(point.x-wantedX)<1e-8,'living columns align with native front seats; seventh centered')
   check(math.abs(point.y-(bottom+math.ceil(n/2)*70))<1e-8,'living rows 2/2/2/1')
   check(point.y+29.5<panel.close.y,'last row clears cancel button')
   for j,b in ipairs(rects)do if nativeCount+n~=j then
    check(math.abs(point.x-b.x)>=41 or math.abs(point.y-b.y)>=59,'new seat rectangles do not overlap native/new seats')
   end end
  end
 end
 check(ISVehicleSeatUI.render(panel)==42,'native return')
 local height=panel.height
 for _,shouldFail in ipairs({false,true})do
  fail=shouldFail;local ok=pcall(ISVehicleSeatUI.render,panel);check(ok~=shouldFail,'render failure propagates');check(panel.height==height,'panel height stable')
  for _,o in ipairs(originals)do for j=1,3 do check(o[1].values[j]==o[j+1],'original inside/outside geometry restored')end end
 end
end
inspect=nil;fail=nil;check(ISVehicleSeatUI.render({vehicle={getScriptName=function()return 'Base.StepVan'end}})==42,'unrelated UI delegates')

check(#V.TOP_FRAME_PART_IDS==3 and #V.OVERHEAD_PART_IDS==3,'core arrays unchanged')
check(VLSPantry.slots.VLSOverhead3~=nil,'fourth station registered')
print('F700_FEATURES_PASS checks='..checks)
