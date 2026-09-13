require "VLS_RoofCargoActions"
require "Vehicles/ISUI/ISVehicleMechanics"
require "Vehicles/ISUI/ISVehiclePartMenu"
local R=VLSRoofCargo
local function install(chr,part)
    if not R.InstallTest(part:getVehicle(),part,chr) then return end
    for _,entry in ipairs(R.inventoryEntries(chr)) do
        if entry.item:getFullType()=="Base.MetalBar" then
            ISVehiclePartMenu.onInstallPart(chr,part,entry.item)
            return
        end
    end
end
local function requirementTooltip()
    local tip=ISWorldObjectContextMenu.addToolTip()
    tip.description=""
    local function line(text,ok)
        tip.description=tip.description..(ok and ISVehicleMechanics.ghs or ISVehicleMechanics.bhs).." "..text.." <LINE> "
    end
    return tip,line
end
local function recipeTooltip(chr,part)
    local spec=R.fabricationSpec(part)
    local status=R.materialStatus(chr,spec)
    local tip,line=requirementTooltip()
    for _,ft in ipairs({"Base.MetalBar","Base.SmallSheetMetal","Base.Screws","Base.Tarp","Base.BlowTorch","Base.WeldingRods"}) do
        local required=spec.materials[ft] or spec.uses[ft]
        if required then
        local count=status.counts[ft] or 0
        line(getItemName(ft).." "..count.."/"..required,
            count>=required)
        end
    end
    line(getItemName("Base.WeldingMask").." "..(status.mask and 1 or 0).."/1",status.mask)
    line(getItemName("Base.Wrench").." "..(status.wrench and 1 or 0).."/1",status.wrench)
    line(getText("IGUI_perks_MetalWelding").." "..chr:getPerkLevel(Perks.MetalWelding).."/5",chr:getPerkLevel(Perks.MetalWelding)>=5)
    line(getText("IGUI_perks_Mechanics").." "..chr:getPerkLevel(Perks.Mechanics).."/1",chr:getPerkLevel(Perks.Mechanics)>=1)
    if part:getId()==R.fixedId then
    for id,fullType in pairs({VLSLowRoofRack="Base.MetalBar",VLSRoofMattress="Base.Mattress"}) do
        local legacy=part:getVehicle():getPartById(id)
        if legacy and legacy:getInventoryItem() then
            line(getText("Tooltip_vehicle_requireUnistalled",getItemName(fullType)),false)
        end
    end
    end
    return tip
end
local function dismantle(chr,part)
    if not R.canDismantle(chr,part,false) then return end
    local torch,mask=R.dismantleTools(chr)
    ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(chr,part:getVehicle(),part:getArea()))
    ISWorldObjectContextMenu.equip(chr,chr:getPrimaryHandItem(),function(item) return item==torch end,true)
    ISInventoryPaneContextMenu.wearItem(mask,chr:getPlayerNum())
    ISTimedActionQueue.add(VLSRoofDismantleAction:new(chr,part))
end
local function dismantleTooltip(chr,part)
    local tip,line=requirementTooltip()
    local torch,mask=R.dismantleTools(chr)
    line(getItemName("Base.BlowTorch").." "..(torch and torch:getCurrentUses() or 0).."/10",torch~=nil and torch:getCurrentUses()>=10)
    line(getItemName("Base.WeldingMask").." "..(mask and 1 or 0).."/1",mask~=nil)
    if not R.empty(part) then line(getText("ContextMenu_ContainerNotEmpty"),false) end
    if part:getId()==R.fixedId then
    for id in pairs(R.allowed) do
        local cargo=part:getVehicle():getPartById(id)
        if cargo and cargo:getInventoryItem() then
            line(getText("Tooltip_vehicle_requireUnistalled",VLS.getMechanicsPartName(cargo)),false)
        end
    end
    for id in pairs(R.legacy) do
        local cargo=part:getVehicle():getPartById(id)
        if cargo and cargo:getInventoryItem() then
            line(getText("Tooltip_vehicle_requireUnistalled",VLS.getMechanicsPartName(cargo)),false)
        end
    end
    end
    return tip
end
if not R.menuRegistered then
    R.menuRegistered=true
    local nativeOnFix=ISInventoryPaneContextMenu.onFix
    function ISInventoryPaneContextMenu.onFix(item,player,fixingNum,fixerNum,part)
        if R.isPart(part) and part:getId()==R.fixedId then
            local chr=getSpecificPlayer(player)
            if chr:getVehicle() then return end
            local fixing=FixingManager.getFixes(item):get(fixingNum)
            local fixer=fixing:getFixers():get(fixerNum)
            if not fixing:getRequiredItems(chr,fixer,item) then return end
            ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(chr,part:getVehicle(),part:getArea()))
        end
        return nativeOnFix(item,player,fixingNum,fixerNum,part)
    end
    local original=ISVehicleMechanics.doPartContextMenu
    function ISVehicleMechanics:doPartContextMenu(part,x,y)
        if UIManager.getSpeedControls():getCurrentGameSpeed()==0 then return end
        if self.chr:getVehicle() then return original(self,part,x,y) end
        original(self,part,x,y)
        if not R.isActionPart(part) or not self.context then return end
        if R.legacy[part:getId()] then
            self.context:removeOptionByName(getText("IGUI_Install"))
        elseif R.fabricationSpec(part) and part:getInventoryItem() then
            self.context:removeOptionByName(getText("IGUI_Uninstall"))
            local option=self.context:addOption(getText("ContextMenu_Disassemble"),self.chr,dismantle,part)
            option.notAvailable=not R.canDismantle(self.chr,part,false)
            option.toolTip=dismantleTooltip(self.chr,part)
        elseif R.fabricationSpec(part) and not part:getInventoryItem() then
            self.context:removeOptionByName(getText("IGUI_Install"))
            local option=self.context:addOption(getText("IGUI_Install"),self.chr,install,part)
            option.notAvailable=not R.InstallTest(part:getVehicle(),part,self.chr)
            option.toolTip=recipeTooltip(self.chr,part)
        end
    end
end
