local F=require 'VLS_ZSolarInstallation'
require 'Vehicles/ISUI/ISVehicleMechanics'
require 'Vehicles/ISUI/ISVehiclePartMenu'
local R=VLSRoofCargo
local S=VLS.SolarVisualR1
local function install(chr,p)
 if not F.InstallTest(p:getVehicle(),p,chr,false) or chr:getVehicle() then return end
 for _,e in ipairs(R.inventoryEntries(chr)) do if e.item:getFullType()=='Base.CarBatteryCharger' then ISVehiclePartMenu.onInstallPart(chr,p,e.item);return end end
end
local function remove(chr,p)
 if not F.UninstallTest(p:getVehicle(),p,chr,false) or chr:getVehicle() then return end
 ISVehiclePartMenu.onUninstallPart(chr,p)
end
local function tip(chr,p,installing)
 local t=ISWorldObjectContextMenu.addToolTip();t.description=''
 local counts={};for _,e in ipairs(R.inventoryEntries(chr)) do local ft=e.item:getFullType();counts[ft]=(counts[ft] or 0)+1 end
 local function line(text,ok) t.description=t.description..(ok and ISVehicleMechanics.ghs or ISVehicleMechanics.bhs)..' '..text..' <LINE> ' end
 if installing then for _,ft in ipairs({'Base.CarBatteryCharger','Base.SheetMetal','Base.ElectricWire','Base.ElectronicsScrap','Base.Screws'}) do local n=F.materials[ft];line(getItemDisplayName(ft)..' '..(counts[ft] or 0)..'/'..n,(counts[ft] or 0)>=n) end end
 local tools=F.toolCounts(chr)
 for _,tool in ipairs({{'Base.Screwdriver','screwdriver'},{'Base.Wrench','wrench'}}) do
  local count=tools[tool[2]]
  line(getItemDisplayName(tool[1])..' '..count..'/1',count>0)
 end
 line(getText('IGUI_perks_Electricity')..' '..chr:getPerkLevel(Perks.Electricity)..'/3',chr:getPerkLevel(Perks.Electricity)>=3)
 line(getText('IGUI_perks_Mechanics')..' '..chr:getPerkLevel(Perks.Mechanics)..'/2',chr:getPerkLevel(Perks.Mechanics)>=2)
 if installing then line(getText('IGUI_VehiclePartVLSFixedRoofRack'),R.fixed(p:getVehicle())) end
 return t
end
if not F.menuHookR7 then
 F.menuHookR7=true;local original=ISVehicleMechanics.doPartContextMenu
 function ISVehicleMechanics:doPartContextMenu(part,x,y)
  if F.isPart(part) and not S.enabled() then return end
  self.vlsSolarContextPart=F.isPart(part) and part or nil
  original(self,part,x,y)
  if not F.isPart(part) or not self.context then return end
  self.context:removeOptionByName(getText('IGUI_Install'));self.context:removeOptionByName(getText('IGUI_Uninstall'))
  local installed=part:getInventoryItem()~=nil
  local key=installed and 'ContextMenu_Disassemble' or 'IGUI_Install'
  local o=self.context:addOption(getText(key),self.chr,installed and remove or install,part)
  o.notAvailable=self.chr:getVehicle()~=nil or not (installed and F.UninstallTest(part:getVehicle(),part,self.chr,false) or not installed and F.InstallTest(part:getVehicle(),part,self.chr,false))
  o.toolTip=tip(self.chr,part,not installed)
  -- No iconTexture/itemForTexture and no item-selection submenu.
 end
end
print('[VLS SolarDirect] direct mechanics material menu READY; no icon')
-- The vanilla overall-condition average treats optional empty parts as zero.
-- Exclude only this uninstalled optional panel, without changing any part data.
local function optionalRating(self, visibleOnly)
 if not self.vehicle then return end
 local panel=self.vehicle:getPartById(F.ID)
 if not panel or panel:getInventoryItem() then return end
 local total,count=0,0
 for index=0,self.vehicle:getPartCount()-1 do
  local part=self.vehicle:getPartByIndex(index)
  if part~=panel and (not visibleOnly or part:getCategory()~='nodisplay') then
   local condition=part:getCondition()
   if not visibleOnly and part:getItemType() and not part:getItemType():isEmpty() and not part:getInventoryItem() then condition=0 end
   total=total+condition;count=count+1
  end
 end
 if count>0 then self.generalCondition=round(total/count,2);self.generalCondRGB=self:getConditionRGB(self.generalCondition) end
end
if not F.ratingHookR8 then
 F.ratingHookR8=true
 local init=ISVehicleMechanics.initParts
 ISVehicleMechanics.initParts=function(self,...)local result=init(self,...);optionalRating(self,true);F.filterSolarMechanics(self);return result end
 local recalc=ISVehicleMechanics.recalculGeneralCondition
 ISVehicleMechanics.recalculGeneralCondition=function(self,...)local result=recalc(self,...);optionalRating(self,false);return result end
end

function F.filterSolarMechanics(self)
 self.vlsSolarEnabled=S.enabled()
 if self.vlsSolarEnabled then return end
 local emptied={}
 for category,entry in pairs(self.vehiclePart or {}) do
  local removed=false
  for i=#entry.parts,1,-1 do
   if F.isPart(entry.parts[i].part) then table.remove(entry.parts,i);removed=true end
  end
  if removed and #entry.parts==0 then emptied[entry.name]=true end
 end
 for _,list in ipairs({self.listbox,self.bodyworklist}) do
  local selected=list.items[list.selected or 0]
  local keep=selected and selected.item
  for i=#list.items,1,-1 do
   local row=list.items[i].item
   if F.isPart(row.part) or row.cat and emptied[row.name] then list:removeItemByIndex(i) end
  end
  list.selected=0
  if keep then for i,row in ipairs(list.items) do if row.item==keep then list.selected=i;break end end end
 end
 self.leftListSelection=self.listbox.selected
 self.rightListSelection=self.bodyworklist.selected
 if self.vlsSolarContextPart and self.context then self.context:setVisible(false) end
 self.vlsSolarContextPart=nil
end
if not F.wholeSwitchMechanicsHook then
 F.wholeSwitchMechanicsHook=true
 local update=ISVehicleMechanics.update
 function ISVehicleMechanics:update(...)
  if self.vehicle and self.vlsSolarEnabled~=S.enabled() then
   local selected={}
   for _,list in ipairs({self.listbox,self.bodyworklist}) do
    local row=list.items[list.selected or 0];selected[list]=row and row.item.part
   end
   self:initParts()
   for list,part in pairs(selected) do
    for i,row in ipairs(list.items) do if row.item.part==part then list.selected=i;break end end
   end
  end
  self.leftListSelection=self.listbox.selected
  self.rightListSelection=self.bodyworklist.selected
  return update(self,...)
 end
 local mouse=ISVehicleMechanics.isMouseOverPart
 function ISVehicleMechanics:isMouseOverPart(x,y,part)
  if F.isPart(part) and not S.enabled() then return false end
  return mouse(self,x,y,part)
 end
 for _,name in ipairs({'onInstallPart','onUninstallPart','onRepairPart'}) do
  local callback=ISVehiclePartMenu[name]
  if callback then ISVehiclePartMenu[name]=function(chr,part,...)
   if F.isPart(part) and not S.enabled() then return end
   return callback(chr,part,...)
  end end
 end
end
