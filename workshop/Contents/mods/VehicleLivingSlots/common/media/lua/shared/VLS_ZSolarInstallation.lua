require 'VLS_RoofCargoActions'
local S=require 'VLS_ZSolarVisualR1'
local R=VLSRoofCargo
VLS.SolarInstallation=VLS.SolarInstallation or {}
local F=VLS.SolarInstallation
F.ID='VLSSolarPanel';F.TYPE='Base.VLSSolarPanelKit';F.REVISION='direct-material-r8'
F.materials={['Base.CarBatteryCharger']=1,['Base.SheetMetal']=2,['Base.ElectricWire']=4,['Base.ElectronicsScrap']=8,['Base.Screws']=16}
-- Same native salvage roll as rack dismantling. Electronics, wire and charger
-- are unrecoverable; metal1 denominator15 and screws8 denominator25, not full refund.
F.salvage={{'SheetMetal',1,15},{'Screws',8,25}}
function F.isPart(part)
 local v=part and part:getVehicle();local script=v and v:getScript()
 return part and part:getId()==F.ID and v:getPartById(F.ID)==part and script and R.vehicleScripts[script:getFullName()]==true
end
function F.installed(v)
 local p=v and v:getPartById(F.ID);local i=p and p:getInventoryItem()
 return F.isPart(p) and i and i:getFullType()==F.TYPE
end
-- Same category and not-broken rules as native vehicle mechanics tools.
function F.toolCounts(chr)
 local counts={screwdriver=0,wrench=0}
 for _,entry in ipairs(R.inventoryEntries(chr)) do
  local item=entry.item
  if not item:isBroken() then
   if item:hasTag(ItemTag.SCREWDRIVER) then counts.screwdriver=counts.screwdriver+1 end
   if item:hasTag(ItemTag.WRENCH) then counts.wrench=counts.wrench+1 end
  end
 end
 return counts
end
function F.tools(chr)
 local counts=F.toolCounts(chr)
 return counts.screwdriver>0 and counts.wrench>0
end
local function qualified(v,p,chr,position)
 return F.isPart(p) and chr and not chr:isDead() and p:getVehicle()==v and S.isStopped(v)
  and (not position or chr:isMechanicsCheat() or R.atVehicle(chr,p)) and chr:getPerkLevel(Perks.Electricity)>=3 and chr:getPerkLevel(Perks.Mechanics)>=2 and F.tools(chr)
end
function F.plan(chr,anchor)
 if not chr or chr:isDead() then return nil end
 local need={};for ft,n in pairs(F.materials) do need[ft]=n end
 local entries={};local seen={};local anchorFound=not anchor
 if anchor then
  if anchor:getFullType()~='Base.CarBatteryCharger' then return nil end
  for _,e in ipairs(R.inventoryEntries(chr)) do if e.item==anchor then
   if not e.container or not e.container:contains(anchor) then return nil end
   entries[#entries+1]=e;seen[anchor]=true;need['Base.CarBatteryCharger']=0;anchorFound=true;break
  end end
 end
 if not anchorFound then return nil end
 for _,e in ipairs(R.inventoryEntries(chr)) do
  local item=e.item;local ft=item:getFullType()
  if not seen[item] and need[ft] and need[ft]>0 then
   if not e.container or not e.container:contains(item) then return nil end
   seen[item]=true;entries[#entries+1]=e;need[ft]=need[ft]-1
  end
 end
 for _,n in pairs(need) do if n>0 then return nil end end
 return entries
end
function F.InstallTest(v,p,chr,position)
 return qualified(v,p,chr,position~=false) and R.fixed(v) and not p:getInventoryItem() and VLS.isInstallationEnabled(p) and S.enabled() and F.plan(chr)~=nil
end
function F.UninstallTest(v,p,chr,position)
 return S.enabled() and qualified(v,p,chr,position~=false) and F.installed(v)
end
function F.Create(v,p) p:setInventoryItem(nil) end
local function rackId(v)
 local p=v and v:getPartById(R.fixedId);local i=p and p:getInventoryItem();return i and i:getID()
end
local function reset(v)
 local p=v:getPartById(R.fixedId)
 if p then local d=p:getModData();d.vlsSolarVisualR1Expanded=false;d.vlsSolarVisualR1RackItem=nil;S.powerTargetRevision[p]=(S.powerTargetRevision[p] or 0)+1;v:transmitPartModData(p);S.track(p,true) end
end
local function install(a)
 if isClient() or not a:isValid() then return false end
 local chr,p=a.character,a.part;local v=p:getVehicle();local plan=F.plan(chr,a.item)
 if not plan then return false end
 local marker=instanceItem(F.TYPE);if not marker or marker:getFullType()~=F.TYPE then return false end
 marker:setCondition(marker:getConditionMax());marker:getModData().vlsSolarDirectMaterialR7=true
 local removed={};local primary,secondary=chr:getPrimaryHandItem(),chr:getSecondaryHandItem();local oldSkill=p:getMechanicSkillInstaller()
 local ok,err=pcall(function()
  for _,e in ipairs(plan) do
   assert(e.container:contains(e.item),'material moved');removed[#removed+1]=e;chr:removeFromHands(e.item);e.container:DoRemoveItem(e.item);assert(not e.container:contains(e.item),'debit failed')
  end
  p:setInventoryItem(marker,chr:getPerkLevel(Perks.Mechanics));assert(p:getInventoryItem()==marker,'assignment failed')
 end)
 if not ok then
  if p:getInventoryItem()==marker then p:setInventoryItem(nil,oldSkill) end
  for _,e in ipairs(removed) do if not e.container:contains(e.item) then e.container:AddItem(e.item) end;assert(e.container:contains(e.item),'rollback failed') end
  chr:setPrimaryHandItem(primary);chr:setSecondaryHandItem(secondary);print('[VLS SolarDirect] ROLLBACK '..tostring(err));return false
 end
 local notified=pcall(function() for _,e in ipairs(removed) do sendRemoveItemFromContainer(e.container,e.item) end;v:transmitPartItem(p);reset(v) end)
 if not notified then print('[VLS SolarDirect] committed; notification failed') end
 return true
end
local function remove(a)
 if isClient() or not a:isValid() then return false end
 local chr,p=a.character,a.part;local v=p:getVehicle();local item=p:getInventoryItem();local inv=chr:getInventory();local direct=item:getModData().vlsSolarDirectMaterialR7==true
 if direct and not v:getSquare() then return false end
 if not direct and not inv:hasRoomFor(chr,item) then return false end
 local oldSkill=p:getMechanicSkillInstaller()
 local ok,err=pcall(function()
  p:setInventoryItem(nil);assert(not p:getInventoryItem(),'clear failed')
  if not direct then inv:AddItem(item);assert(inv:contains(item),'legacy return failed') end
 end)
 if not ok then
  if inv:contains(item) then inv:DoRemoveItem(item) end;p:setInventoryItem(item,oldSkill);assert(p:getInventoryItem()==item,'rollback failed');print('[VLS SolarDirect] ROLLBACK '..tostring(err));return false
 end
 -- Commit before notifications/salvage. Never restore/refund on notification failure.
 local notified=pcall(function()
  if not direct then sendAddItemToContainer(inv,item) end;v:transmitPartItem(p);reset(v)
  if direct then for _,e in ipairs(F.salvage) do for n=1,e[2] do ISRemoveBurntVehicle.checkAddItem(a,e[1],e[3]) end end end
 end)
 if not notified then print('[VLS SolarDirect] committed removal; notification/salvage failed') end
 return true
end
local function identity(n) return type(n)=='number' and n==n and math.abs(n)<math.huge and n==math.floor(n) end
if not F.hooked then
 F.hooked=true
 VLS.installationOptionProviders.solar=function(p) if F.isPart(p) then return 'EnableSolarPanel' end end
 local installNew,uninstallNew=ISInstallVehiclePart.new,ISUninstallVehiclePart.new
 VLSSolarInstallAction=ISInstallVehiclePart:derive('VLSSolarInstallAction')
 function VLSSolarInstallAction:isValid()
  if not self.item or self.item:getID()~=self.solarExpectedId or self.item:getFullType()~='Base.CarBatteryCharger' or rackId(self.vehicle)~=self.solarRackExpectedId then return false end
  local found=false;for _,e in ipairs(R.inventoryEntries(self.character)) do if e.item==self.item then found=true end end
  return found and F.InstallTest(self.vehicle,self.part,self.character)
 end
 function VLSSolarInstallAction:complete() return install(self) end
 function VLSSolarInstallAction:new(character,part,item,maxTimeInit,solarExpectedId,solarRackExpectedId)
  if not character or not F.isPart(part) or not item or not identity(solarExpectedId) or not identity(solarRackExpectedId) or type(maxTimeInit)~='number' then return nil end
  local a=installNew(self,character,part,item,maxTimeInit);a.maxTimeInit=maxTimeInit;a.solarExpectedId=solarExpectedId;a.solarRackExpectedId=solarRackExpectedId;return a
 end
 VLSSolarUninstallAction=ISUninstallVehiclePart:derive('VLSSolarUninstallAction')
 function VLSSolarUninstallAction:isValid() local item=self.part and self.part:getInventoryItem();return item and item:getID()==self.solarExpectedId and F.UninstallTest(self.vehicle,self.part,self.character) end
 function VLSSolarUninstallAction:complete() return remove(self) end
 function VLSSolarUninstallAction:new(character,part,workTime,solarExpectedId)
  if not character or not F.isPart(part) or not identity(solarExpectedId) or type(workTime)~='number' then return nil end
  local a=uninstallNew(self,character,part,workTime);a.workTime=workTime;a.solarExpectedId=solarExpectedId;return a
 end
 function ISInstallVehiclePart:new(character,part,item,maxTimeInit) if F.isPart(part) then return VLSSolarInstallAction:new(character,part,item,maxTimeInit,item and item:getID(),rackId(part:getVehicle())) end;return installNew(self,character,part,item,maxTimeInit) end
 function ISUninstallVehiclePart:new(character,part,workTime) if F.isPart(part) then local i=part:getInventoryItem();return VLSSolarUninstallAction:new(character,part,workTime,i and i:getID()) end;return uninstallNew(self,character,part,workTime) end
 local dismantle=R.canDismantle
 R.canDismantle=function(chr,p,position) if p and p:getId()==R.fixedId then local solar=p:getVehicle():getPartById(F.ID);if solar and solar:getInventoryItem() then return false end end;return dismantle(chr,p,position) end
end
print('[VLS SolarDirect] direct-material-r8 READY; legacy identity retained')
return F
