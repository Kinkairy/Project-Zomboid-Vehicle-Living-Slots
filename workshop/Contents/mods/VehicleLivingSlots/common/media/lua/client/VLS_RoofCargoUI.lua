require "VLS_Config"
require "VLS_RoofCargo"
require "Definitions/ContainerButtonIcons"
require "VLS_VehicleMechanicsIcons"
local R=VLSRoofCargo
if not VLS.registerMechanicsUIProvider then
    print("[VLS Roof UI] shared presentation API missing; launch local test with -modfolders mods,workshop,steam")
    return
end
ContainerButtonIcons.VLSFixedRoofRack=getTexture("media/ui/VLS_RoofRack.png")
ContainerButtonIcons.VLSRoofSmallChest=VLS.getMechanicsPreviewTexture("Base.Mov_SmallChest")
    or getTexture("media/textures/Item_CashBox.png")
local function itemName(part,item)
    if R.lamps[part:getId()] then return getText("IGUI_VehiclePart"..part:getId()) end
    if part:getId()=="VLSRoofSmallChest" then return Translator.getMoveableDisplayName("Small Chest") end
    return getItemName(item:getFullType())
end
function R.displayName(part)
    local item=part:getInventoryItem()
    return item and itemName(part,item) or getText("IGUI_VehiclePart"..part:getId())
end
VLS.registerMechanicsUIProvider("roofCargo", {
    matches=R.isPart,
    name=R.displayName,
    itemName=itemName,
    hidden=function(part) return R.legacy[part:getId()] and not part:getInventoryItem() end,
})
print("[VLS Roof UI] registered shared native presentation")
