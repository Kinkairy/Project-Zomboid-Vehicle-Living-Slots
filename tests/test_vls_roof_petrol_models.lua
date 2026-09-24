local root=assert(arg[1])
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/"
local function read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local R={}
local source=read(media.."lua/shared/VLS_RoofCargo.lua")
local fn=assert(source:match("(function R.SyncPetrolVisual.-)function R.UninstallPetrolComplete"))
assert(loadstring("local R=...;"..fn..";return R"))(R)
local cases=0
for _,file in ipairs({"VLS_StepVanRoofRackAdjustment.txt","VLS_VehicleRoofAdapters.txt"}) do
 local script=read(media.."scripts/"..file)
 for index,header in script:gmatch("part VLSRoofPetrol([123])%s*{([^{}]+)") do
  local flag=header:match("setAllModelsVisible%s*=%s*(%a+)")
  if flag then
   -- Native VehiclePartItem.parse calls setInventoryItem; that re-enables every
   -- model if the script flag is true, even after model visibility arrived.
   local part={models={},item=nil,getId=function()return "VLSRoofPetrol"..index end}
   function part:getInventoryItem()return self.item end
   function part:setModelVisible(id,v)self.models[id]=v end
   function part:receiveItem(kind)
    self.item=kind and {getFullType=function()return kind end} or nil
    if flag=="true" then
     self.models["PetrolCan"..index]=kind~=nil
     self.models["JerryCan"..index]=kind~=nil
    end
   end
   for _,kind in ipairs({"Base.PetrolCan","Base.JerryCan","Base.PetrolCan"}) do
    part:receiveItem(kind);R.SyncPetrolVisual(nil,part)
    part:receiveItem(kind) -- later/repeated inventory packet
    assert(part.models["PetrolCan"..index]==(kind=="Base.PetrolCan"),file..index..kind)
    assert(part.models["JerryCan"..index]==(kind=="Base.JerryCan"),file..index..kind)
   end
   part:receiveItem(nil);R.SyncPetrolVisual(nil,part)
   assert(not part.models["PetrolCan"..index] and not part.models["JerryCan"..index])
   cases=cases+1
  end
 end
end
assert(cases==4,cases)
print("PASS four roof fuel definitions: native item packets preserve one selected model")
