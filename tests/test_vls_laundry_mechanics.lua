local root=assert(arg[1])
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(media.."shared/VLS_Config.lua")
package.loaded.VLS_Config=V
package.loaded["Vehicles/ISUI/ISVehicleMechanics"]=true
package.loaded["Vehicles/ISUI/ISVehiclePartMenu"]=true
V.mechanicsDisplayHookApplied=true
V.usesNormalizedPartCondition=function()return true end
V.getItemConditionPercent=function()return 100 end
V.isInstallationEnabled=function()return true end
function instanceof(item,kind)return item and item.kind==kind end
getText=function(key)return key end
getItemNameFromFullType=function(ft)return "native-item:"..ft end
getTexture=function(sprite)return {splitIcon=function()return "preview:"..sprite end}end
Translator={getMoveableDisplayName=function(name)return name end}
ISVehiclePartMenu={onInstallPart=function()end}
local function menu(root)
 local m={options={},numOptions=1,root=root}
 function m:addOption(name,chr,callback,part,item)
  local option={name=name,callback=callback,item=item,id=self.numOptions}
  self.options[#self.options+1]=option;self.numOptions=self.numOptions+1
  return option
 end
 function m:addSubMenu(option,child)
  local base=self.root or self
  base.submenus=base.submenus or {}
  local id=#base.submenus+1;base.submenus[id]=child
  option.subOption=id
 end
 function m:getSubMenu(id)return (self.root or self).submenus[id]end
 function m:getOptionFromName(name)
  for _,option in ipairs(self.options)do if option.name==name then return option end end
 end
 function m:calcHeight()end
 function m:calcWidth()return 100 end
 function m:setWidth()end
 return m
end
ISContextMenu={getNew=function(_,parent)return menu(parent.root or parent)end}
local itemTypes={"Base.Mov_TrailerFridge","Base.Mov_BlueComboWasherDryer"}
local list={size=function()return #itemTypes end,get=function(_,i)return itemTypes[i+1]end}
local part={getInventoryItem=function()return nil end,getItemType=function()return list end,
 getId=function()return "SeatBed" end}
local function item(ft,sprite)
 return {kind="Moveable",getFullType=function()return ft end,
 getWorldSprite=function()return sprite end,getScriptItem=function()return nil end,
 getDisplayName=function()return ft end}
end
local fridge=item("Base.Mov_TrailerFridge","location_trailer_02_10")
local combo=item("Base.Mov_BlueComboWasherDryer","appliances_laundry_01_2")
local typeToItem={
 ["Base.Mov_TrailerFridge"]={fridge},
 ["Base.Mov_BlueComboWasherDryer"]={combo},
}
VehicleUtils={getItems=function()return typeToItem end}
ISVehicleMechanics={doMenuTooltip=function()end}
function ISVehicleMechanics:doPartContextMenu()
 local root=menu();local install=menu(root)
 root.submenus={install}
 local option=root:addOption("IGUI_Install")
 option.subOption=1
 for _,ft in ipairs(itemTypes)do
  local row=install:addOption(ft)
  local candidates=typeToItem[ft]
  if candidates then
   local child=menu(root);install:addSubMenu(row,child)
   for _,candidate in ipairs(candidates)do
    local entry=child:addOption(candidate:getDisplayName(),nil,
        ISVehiclePartMenu.onInstallPart,part,candidate)
    entry.itemForTexture=candidate
   end
  else row.notAvailable=true end
 end
 self.context=root
end
dofile(media.."client/VLS_VehicleMechanicsIcons.lua")
local mechanics=setmetatable({playerNum=0,chr={}}, {__index=ISVehicleMechanics})
mechanics:doPartContextMenu(part)
local install=mechanics.context:getSubMenu(1)
assert(#install.options==2,#install.options)
local names={"Base.Mov_TrailerFridge","native-item:Base.Mov_BlueComboWasherDryer"}
local expected={fridge,combo}
for i,row in ipairs(install.options)do
 assert(row.name==names[i],row.name)
 assert(row.subOption)
 local child=mechanics.context:getSubMenu(row.subOption)
 assert(#child.options==1)
 assert(child.options[1].itemForTexture==expected[i])
 assert(child.options[1].callback==ISVehiclePartMenu.onInstallPart)
 assert(type(child.options[1].iconTexture)=="string")
 assert(child.options[1].iconTexture:find("preview:",1,true)==1)
end
print("RESULT mechanics trailer-fridge icon and native combo candidates=2 failures=0")

assert(V.getMechanicsItemName(part,combo)=="native-item:Base.Mov_BlueComboWasherDryer")
assert(combo:getDisplayName()=="Base.Mov_BlueComboWasherDryer") -- display-only, no item mutation
combo.isCustomName=function()return true end
assert(V.getMechanicsItemName(part,combo)==combo:getDisplayName())
print("PASS native item name used; custom name preserved")
