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
            line(getItemName(ft).." "..count.."/"..required,count>=required)
        end
    end
    line(getItemName("Base.WeldingMask").." "..(status.mask and 1 or 0).."/1",status.mask)
    line(getItemName("Base.Wrench").." "..(status.wrench and 1 or 0).."/1",status.wrench)
    local welding,mechanics=spec.metalWelding or 5,spec.mechanics or 1
    line(getText("IGUI_perks_MetalWelding").." "..chr:getPerkLevel(Perks.MetalWelding).."/"..welding,chr:getPerkLevel(Perks.MetalWelding)>=welding)
    line(getText("IGUI_perks_Mechanics").." "..chr:getPerkLevel(Perks.Mechanics).."/"..mechanics,chr:getPerkLevel(Perks.Mechanics)>=mechanics)
    if spec.extraTooltip then spec.extraTooltip(chr,part,line) end
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
-- Match vanilla ISVehicleMechanics:doMenuTooltip presentation.  Keep the
-- custom dismantle semantics, but render the hover panel with the same
-- ISToolTip header, red/green requirement markers and stock requirement text.
local function dismantleTooltip(chr,part)
    local tooltip=ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip.description=getText("Tooltip_craft_Needs").." : <LINE>"

    local torch,mask=R.dismantleTools(chr)
    local torchUses=torch and torch:getCurrentUses() or 0
    local torchOK=torch~=nil and torchUses>=10
    tooltip.description=tooltip.description.." "
        ..(torchOK and ISVehicleMechanics.ghs or ISVehicleMechanics.bhs)
        ..getItemDisplayName("Base.BlowTorch").." "..torchUses.."/10 <LINE>"
    tooltip.description=tooltip.description.." "
        ..(mask and ISVehicleMechanics.ghs or ISVehicleMechanics.bhs)
        ..getItemDisplayName("Base.WeldingMask").." "..(mask and 1 or 0).."/1 <LINE>"

    if not R.empty(part) then
        tooltip.description=tooltip.description.." "..ISVehicleMechanics.bhs.." "
            ..getText("Tooltip_vehicle_needempty",VLS.getMechanicsPartName(part)).." <LINE> "
    end

    if part:getId()==R.fixedId then
        local vehicle=part:getVehicle()
        for id in pairs(R.allowed) do
            local cargo=vehicle:getPartById(id)
            if cargo and (cargo:getInventoryItem() or not R.empty(cargo)) then
                tooltip.description=tooltip.description.." "..ISVehicleMechanics.bhs.." "
                    ..getText("Tooltip_vehicle_requireUnistalled",VLS.getMechanicsPartName(cargo)).." <LINE>"
            end
        end
        for id in pairs(R.legacy) do
            local cargo=vehicle:getPartById(id)
            if cargo and cargo:getInventoryItem() then
                tooltip.description=tooltip.description.." "..ISVehicleMechanics.bhs.." "
                    ..getText("Tooltip_vehicle_requireUnistalled",VLS.getMechanicsPartName(cargo)).." <LINE>"
            end
        end
    end

    local spec=R.fabricationSpec(part)
    if spec and spec.extraTooltip then
        spec.extraTooltip(chr,part,function(text,ok)
            tooltip.description=tooltip.description.." "..(ok and ISVehicleMechanics.ghs or ISVehicleMechanics.bhs).." "..text.." <LINE>"
        end)
    end
    return tooltip
end
local function showNativeContext(mechanics)
    local context=mechanics and mechanics.context
    if not context then return end
    context:setVisible(true)
    local joypad=JoypadState.players[mechanics.playerNum+1]
    if joypad then
        context.mouseOver=1
        context.origin=mechanics
        joypad.focus=context
        updateJoypadFocus(joypad)
    end
end
if not R.menuRegistered then
    R.menuRegistered=true
    local nativeOnFix=ISInventoryPaneContextMenu.onFix
    function ISInventoryPaneContextMenu.onFix(item,player,fixingNum,fixerNum,part)
        if R.fabricationSpec(part) then
            local chr=getSpecificPlayer(player)
            if chr:getVehicle() then return end
            local fixes=FixingManager.getFixes(item)
            local fixing=fixes and fixes:get(fixingNum) or nil
            local fixer=fixing and fixing:getFixers():get(fixerNum) or nil
            if not fixing or not fixer or not fixing:getRequiredItems(chr,fixer,item) then return end
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
            return
        end
        local spec=R.fabricationSpec(part)
        if spec and part:getInventoryItem() then
            -- Preserve the stock Repair submenu exactly when the part is damaged.
            -- A 100% vanilla part is not repairable, so remove Repair at full condition.
            local item=part:getInventoryItem()
            if item:getCondition()>=item:getConditionMax() then
                self.context:removeOptionByName(getText("ContextMenu_Repair"))
            end
            self.context:removeOptionByName(getText("IGUI_Uninstall"))
            local option=self.context:addOption(getText("ContextMenu_Disassemble"),self.chr,dismantle,part)
            option.notAvailable=not R.canDismantle(self.chr,part,false)
            option.toolTip=dismantleTooltip(self.chr,part)
            showNativeContext(self)
        elseif spec and not part:getInventoryItem() then
            self.context:removeOptionByName(getText("IGUI_Install"))
            local option=self.context:addOption(getText("IGUI_Install"),self.chr,install,part)
            option.notAvailable=not R.InstallTest(part:getVehicle(),part,self.chr)
            option.toolTip=recipeTooltip(self.chr,part)
            showNativeContext(self)
        end
    end
end
