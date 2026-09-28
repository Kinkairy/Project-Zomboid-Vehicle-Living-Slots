-- Native B42 action bodies with engine doubles: original packed item round trip.
-- lua5.1 test_vls_roof_tents.lua MODULE_ROOT GAME_MEDIA_LUA
local root=assert(arg[1])
local T=dofile(root.."/tests/test_vls_top_space.lua")
local function noop()end
local count=0
local function eq(a,b)T.eq(a,b);count=count+1 end
local R=dofile(root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/VLS_RoofCargo.lua")
R=VLSRoofCargo
local kinds={"Base.CampingTentKit2_Packed","Base.TentBlue_Packed","Base.TentBrown_Packed",
    "Base.TentGreen_Packed","Base.TentYellow_Packed","Base.HideTent_Packed","Base.ImprovisedTentKit_Packed"}
for _,name in ipairs({"Base.StepVan","Base.Van"})do
 local v,make=T.vehicle(name)
 function v:getScript()return {getFullName=function()return name end}end
 v.isRemovedFromWorld=function()return false end;v.isStopped=function()return true end
 v.isInArea=function()return true end;v.getMechanicalID=function()return 1 end
 v.doDamageOverlay=noop;v.transmitPartItem=noop
 local rack=make(R.fixedId);rack.item=T.item(R.fixedType)
 local part=make("VLSRoofTent")
 part.getArea=function()return "TruckBed" end
 function part:getTable(kind)return {skills={},requireEmpty=true,
     complete=kind=="install" and R.InstallComplete or Vehicles.UninstallComplete.Default}end
 local inv={items={}}
 function inv:contains(i)return self.items[i]==true end
 function inv:containsID(id)for i in pairs(self.items)do if i:getID()==id then return true end end;return false end
 function inv:DoRemoveItem(i)assert(self.items[i]);self.items[i]=nil end
 function inv:AddItem(i)assert(not self.items[i]);self.items[i]=true end
 function inv:hasRoomFor()return true end
 local chr={getInventory=function()return inv end,isMechanicsCheat=function()return false end,
     isTimedActionInstant=function()return false end,getPerkLevel=function()return 10 end,removeFromHands=noop,
     addMechanicsItem=noop,sendObjectChange=noop,getCurrentSquare=function()return {}end,
     isDead=function()return false end,getVehicle=function()return nil end}
 v.canInstallPart=function(_,who,p)return not p.item and R.fixed(v) end
 for _,ft in ipairs(kinds)do
  local tent=T.item(ft);tent.condition=67;tent.savedData={original=true};inv.items[tent]=true
  for cycle=1,3 do
   eq(R.validateInstall(chr,part,tent,true),true)
   local action=ISInstallVehiclePart:new(chr,part,tent,350)
   eq(action:isValid(),true);eq(action:complete(),true)
   eq(part.item,tent);eq(inv.items[tent],nil);eq(tent:getCondition(),67)
   eq(ISUninstallVehiclePart:new(chr,part,250):complete(),true)
   eq(part.item,nil);eq(inv.items[tent],true);eq(tent:getFullType(),ft)
   eq(tent:getCondition(),67);eq(tent.savedData.original,true)
  end
  inv.items[tent]=nil
 end
end
print("ROOF_TENT_NATIVE_ROUNDTRIP_PASS types=7 families=2 cycles=3 assertions="..count)
print("Actual native Lua actions; engine doubles. Live inventory/gameplay acceptance pending.")
