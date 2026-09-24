local root=assert(arg[1])
local mods=root.."/workshop/Contents/mods/"
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(mods.."VehicleLivingSlots/common/media/lua/shared/VLS_Config.lua")
package.loaded.VLS_Config=V;package.loaded.VLS_Propane=true
instanceof=function(item,kind)return item and item.kind==kind end
getText=function(k)return k end
getItemNameFromFullType=function(k) assert(k=="Base.Mov_BlueComboWasherDryer");return "native-combo-name" end
SandboxVars={VehicleLivingSlots={EnableAuxBatteries=false}}
dofile(mods.."VehicleLivingSlotsKI5Campers/common/media/lua/shared/VLS_KI5Campers_Config.lua")
local combo={kind="Moveable",getFullType=function()return "Base.Mov_BlueComboWasherDryer" end,
 getDisplayName=function()return "old-moveable-name" end}
local tankType=assert(next(V.LARGE_VAN_WATER_TANK_ITEMS))
local tank={getFullType=function()return tankType end,getFluidContainer=function()return {getAmount=function()return 0 end} end}
local models,ki5,slots,tankModels,tankPositions=0,0,0,0,0
for name,profile in pairs(V.vehicleProfiles) do
 models=models+1;if profile.kind=="ki5Camper" then ki5=ki5+1 end
 local parts={}
 local vehicle={getScriptName=function()return name end,getPartById=function(_,id)return parts[id] end}
 local function part(id,item)
  local p={item=item,getId=function()return id end,getVehicle=function()return vehicle end,
   getInventoryItem=function(self)return self.item end};parts[id]=p;return p
 end
 local battery=part(profile.auxBatteryPartId or V.AUX_BATTERY_PART_ID,{kind="DrainableComboItem",getFullType=function()return "Base.CarBattery1" end})
 assert(V.isInstallationEnabled(battery,"Base.CarBattery1"),name.." battery")
 assert(V.getAuxBatteryPart(vehicle)==battery,name.." battery lookup")
 if #(profile.waterTankParts or {})>0 then tankModels=tankModels+1 end
 for _,id in ipairs(profile.waterTankParts or {}) do part(id,nil);tankPositions=tankPositions+1 end
 for _,id in ipairs(profile.universalParts) do
  slots=slots+1;local p=part(id,nil)
  assert(V.isInstallationEnabled(p,combo),name.." no tank still permits install")
  assert(V.isInstallationEnabled(p,"Base.Mov_BlueComboWasherDryer"),name.." type menu permits install")
  for _,tid in ipairs(profile.waterTankParts or {}) do
   parts[tid].item=tank
   assert(V.isInstallationEnabled(p,combo),name.." installed empty tank "..tid)
   assert(V.isInstallationEnabled(p,"Base.Mov_BlueComboWasherDryer"),name.." parent install menu")
   parts[tid].item=nil
  end
  p.item=combo
  assert(V.getInstalledPart(vehicle,id)==p,name.." existing machine recognition")
  assert(V.getPartDisplayName(p)=="native-combo-name",name.." installed item name")
 end
end
assert(ki5==6,ki5)
print(string.format("VEHICLE_MATRIX_OK models=%d ki5=%d slots=%d tankModels=%d tankPositions=%d",models,ki5,slots,tankModels,tankPositions))
