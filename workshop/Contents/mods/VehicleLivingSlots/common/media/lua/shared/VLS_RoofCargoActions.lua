require "VLS_InstallGuard"
require "VLS_RoofCargo"
require "VLS_BodyArmor"
require "TimedActions/ISFixVehiclePartAction"
require "Vehicles/TimedActions/ISRemoveBurntVehicle"
local R=VLSRoofCargo
local nativeInstallNew=ISInstallVehiclePart.new
local nativeUninstallNew=ISUninstallVehiclePart.new
local nativeFixNew=ISFixVehiclePartAction.new
local nativeIsActionPart=R.isActionPart

-- Any fabricated VLS part that actually exists on the vehicle is actionable.
function R.isActionPart(part)
    return (part and R.fabricationSpec(part)~=nil) or nativeIsActionPart(part)
end

local function torchIn(character)
    for _,entry in ipairs(R.inventoryEntries(character)) do
        local item=entry.item
        if item:getFullType()=="Base.BlowTorch" and item:getCurrentUses()>0 then return item end
    end
end
-- Native repair UI moves the selected inputs to carried inventory first.
-- Revalidate at completion because FixingManager itself does not reject shortages.
local function repairInputsReady(action)
    local fixing,fixer=action.fixing,action.fixer
    if not fixing or not fixer then return false end
    local required=fixing:getRequiredItems(action.character,fixer,action.item)
    if not required then return false end
    for i=0,required:size()-1 do
        if not action.character:getInventory():contains(required:get(i)) then return false end
    end
    local skills=fixer:getFixerSkills()
    if skills then
        for i=0,skills:size()-1 do
            local skill=skills:get(i)
            if action.character:getPerkLevel(Perks.FromString(skill:getSkillName()))
                    <skill:getSkillLevel() then return false end
        end
    end
    return true
end
local function startWelding(action)
    action:setActionAnim("BlowTorch")
    action:setOverrideHandModels(torchIn(action.character),nil)
    action.weldSound=action.character:playSound("BlowTorch")
end
local function updateWelding(action)
    action.character:faceThisObject(action.vehicle or action.vehiclePart:getVehicle())
    if action.weldSound and not action.character:getEmitter():isPlaying(action.weldSound) then
        action.weldSound=action.character:playSound("BlowTorch")
    end
    action.character:setMetabolicTarget(Metabolics.HeavyWork)
end
local function stopWelding(action)
    if action.weldSound then
        action.character:getEmitter():stopSound(action.weldSound)
        action.weldSound=nil
    end
end

VLSRoofInstallAction=ISInstallVehiclePart:derive("VLSRoofInstallAction")
function VLSRoofInstallAction:isValid()
    local item=self.item and self.character:getInventory():getItemById(self.item:getID())
    local fixed=R.fabricationSpec(self.part)~=nil
    if not item or not R.validateInstall(self.character,self.part,item,fixed) then return false end
    if R.fabricationSpec(self.part) then return true end
    return ISInstallVehiclePart.isValid(self)
end
function VLSRoofInstallAction:start()
    ISInstallVehiclePart.start(self)
    if R.fabricationSpec(self.part) then startWelding(self) end
end
function VLSRoofInstallAction:update()
    ISInstallVehiclePart.update(self)
    if R.fabricationSpec(self.part) then updateWelding(self) end
end
function VLSRoofInstallAction:stop()
    stopWelding(self)
    ISInstallVehiclePart.stop(self)
end
function VLSRoofInstallAction:perform()
    stopWelding(self)
    ISInstallVehiclePart.perform(self)
end
function VLSRoofInstallAction:complete()
    if isClient() or not self:isValid() then return false end
    if R.fabricationSpec(self.part) then
        self.item:setJobDelta(0)
        return R.installFixed(self.character,self.part)
    end
    return ISInstallVehiclePart.complete(self)
end

VLSRoofUninstallAction=ISUninstallVehiclePart:derive("VLSRoofUninstallAction")
function VLSRoofUninstallAction:isValid()
    local item=self.part and self.part:getInventoryItem()
    return item and item:getID()==self.expectedItemId
        and R.UninstallTest(self.vehicle,self.part,self.character)
        and ISUninstallVehiclePart.isValid(self)
end
function VLSRoofUninstallAction:complete()
    if isClient() or not self:isValid() then return false end
    return ISUninstallVehiclePart.complete(self)
end

-- Keep the stock FixingManager/ISFixVehiclePartAction calculations and menu.
-- This derived action only gives permanent welded VLS parts the rack welding
-- animation, positional validation and post-repair visual refresh.
VLSRoofFixAction=ISFixVehiclePartAction:derive("VLSRoofFixAction")
function VLSRoofFixAction:isValid()
    local spec=R.fabricationSpec(self.vehiclePart)
    return spec and self.vehiclePart:getInventoryItem()==self.item
        and self.item:getFullType()==spec.itemType
        and self.item:getCondition()<self.item:getConditionMax()
        and R.atVehicle(self.character,self.vehiclePart)
        and repairInputsReady(self)
        and ISFixVehiclePartAction.isValid(self)
end
function VLSRoofFixAction:start()
    ISFixVehiclePartAction.start(self)
    startWelding(self)
end
function VLSRoofFixAction:update()
    ISFixVehiclePartAction.update(self)
    updateWelding(self)
end
function VLSRoofFixAction:stop()
    stopWelding(self)
    ISFixVehiclePartAction.stop(self)
end
function VLSRoofFixAction:perform()
    stopWelding(self)
    ISFixVehiclePartAction.perform(self)
end
function VLSRoofFixAction:complete()
    if isClient() or not self:isValid() then return false end
    local spec=R.fabricationSpec(self.vehiclePart)
    local result=ISFixVehiclePartAction.complete(self)
    if result and spec and spec.onRepaired then
        spec.onRepaired(self.vehiclePart:getVehicle(),self.vehiclePart)
    end
    return result
end

-- Reuse the stock burnt-vehicle cutting timed action shell, never its stock
-- completion (which would delete the whole vehicle).
VLSRoofDismantleAction=ISRemoveBurntVehicle:derive("VLSRoofDismantleAction")
function VLSRoofDismantleAction:isValid()
    local installed=self.part and self.part:getInventoryItem()
    return installed and installed:getID()==self.expectedItemId
        and R.canDismantle(self.character,self.part,true)
        and ISRemoveBurntVehicle.isValid(self)
end
function VLSRoofDismantleAction:update()
    ISRemoveBurntVehicle.update(self)
    self.item:setJobType(getText("ContextMenu_Disassemble"))
end
function VLSRoofDismantleAction:complete()
    if isClient() or not self:isValid() then return false end
    local spec=R.fabricationSpec(self.part)
    if not spec then return false end
    self.part:setInventoryItem(nil)
    self.vehicle:transmitPartItem(self.part)
    local torch=self.character:getPrimaryHandItem()
    for i=1,10 do torch:Use(false,false,true) end
    local xp=5
    for _,entry in ipairs(spec.salvage) do
        for i=1,entry[2] do
            if self:checkAddItem(entry[1],entry[3]) then xp=xp+1 end
        end
    end
    addXp(self.character,Perks.MetalWelding,xp)
    if spec.onDestroyed then spec.onDestroyed(self.vehicle,self.part) end
    return true
end
function VLSRoofDismantleAction:new(character,part)
    local action=ISRemoveBurntVehicle.new(self,character,part:getVehicle())
    action.part=part
    action.expectedItemId=part:getInventoryItem():getID()
    return action
end

if not R.actionsRegistered then
    R.actionsRegistered=true
    function ISInstallVehiclePart:new(character,part,item,maxTimeInit)
        local actionClass=R.isActionPart(part) and VLSRoofInstallAction or self
        local action=nativeInstallNew(actionClass,character,part,item,maxTimeInit)
        if R.isActionPart(part) and R.fabricationSpec(part) then
            action.jobType=part:getId()==R.fixedId and getText("IGUI_VLSRoofWeldInstall") or getText("IGUI_Install")
        end
        return action
    end
    function ISUninstallVehiclePart:new(character,part,workTime)
        local actionClass=R.isActionPart(part) and VLSRoofUninstallAction or self
        local action=nativeUninstallNew(actionClass,character,part,workTime)
        if R.isActionPart(part) then
            local item=part:getInventoryItem()
            action.expectedItemId=item and item:getID() or -1
        end
        return action
    end
    function ISFixVehiclePartAction:new(character,vehiclePart,fixingNum,fixerNum)
        local actionClass=R.fabricationSpec(vehiclePart) and VLSRoofFixAction or self
        return nativeFixNew(actionClass,character,vehiclePart,fixingNum,fixerNum)
    end
end
