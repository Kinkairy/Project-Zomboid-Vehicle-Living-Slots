local root=assert(arg[1])
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(media.."shared/VLS_Config.lua");package.loaded.VLS_Config=V
local count=0
local function test(n,fn)fn();count=count+1;print("PASS "..n)end
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
function instanceof(o,kind)return o and o.kind==kind end
local function item(ft,sprite)return {kind="Moveable",getFullType=function()return ft end,getWorldSprite=function()return sprite end,getScriptItem=function()return nil end}end
local profile=V.getEquipmentProfileByType("Base.Mov_TrailerFridge")
test("same existing refrigerator profile, power and containers",function()
 local mini=V.getEquipmentProfileByType("Base.Mov_FridgeMini")
 assert(profile);for k,v in pairs(mini)do if k~="previewSprite" then eq(profile[k],v)end end
 eq(profile.capacity,20);eq(V.FREEZER_CAPACITY,5)
 eq(V.getEquipmentCapability(item("Base.Mov_TrailerFridge")),"cooling")
end)
for _,sprite in ipairs({10,11,16,17})do
 test("picked-up trailer fridge orientation "..sprite,function()
  local i=item("Moveables.Furniture","location_trailer_02_"..sprite)
  eq(V.resolveEquipmentType(i),"Base.Mov_TrailerFridge");eq(V.getEquipmentCapability(i),"cooling")
 end)
end
test("unrelated trailer furniture rejected",function()
 assert(V.resolveEquipmentType(item("Moveables.Furniture","location_trailer_02_18"))~="Base.Mov_TrailerFridge")
end)
test("all existing mini-fridge slot whitelists include trailer fridge",function()
 for _,rel in ipairs({"VehicleLivingSlots/common/media/scripts/VLS_VanPatch.txt","VehicleLivingSlots/common/media/scripts/VLS_StepVanWaterPatch.txt","VehicleLivingSlotsKI5Campers/common/media/scripts/VLS_KI5CampersPatch.txt"})do
  local f=assert(io.open(root.."/workshop/Contents/mods/"..rel));local s=f:read("*a");f:close()
  local seen=0
  for line in s:gmatch("[^\n]+")do
   if line:find("itemType",1,true) and line:find("Base.Mov_FridgeMini;",1,true)then assert(line:find("Base.Mov_TrailerFridge;",1,true));seen=seen+1 end
  end
  assert(seen>0)
 end
end)
test("universal slot accepts trailer fridge but weapon slot does not",function()
 local v={getScriptName=function()return "Base.StepVan"end}
 local p={getVehicle=function()return v end,getId=function()return V.UNIVERSAL_PART_ID end}
 local i=item("Base.Mov_TrailerFridge")
 assert(V.isAllowedItem(p,i))
 p.getId=function()return V.WEAPON_PART_ID end;assert(not V.isAllowedItem(p,i))
end)
print("RESULT trailer fridge tests="..count.." failures=0")
