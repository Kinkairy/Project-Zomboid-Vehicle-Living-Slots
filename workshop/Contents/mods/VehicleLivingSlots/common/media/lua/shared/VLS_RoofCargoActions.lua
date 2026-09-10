require "VLS_InstallGuard"
require "VLS_RoofCargo"
require "TimedActions/ISFixVehiclePartAction"
require "Vehicles/TimedActions/ISRemoveBurntVehicle"
local R=VLSRoofCargo
local nativeInstallNew=ISInstallVehiclePart.new
local nativeUninstallNew=ISUninstallVehiclePart.new
local nativeFixNew=ISFixVehiclePartAction.new

local function torchIn(character)
    for _,entry in ipairs(R.inventoryEntries(character)) do
        local item=entry.item
        if item:getFullType()=="Base.BlowTorch" and item:getCurrentUses()>0 then return item end
    end
end
-- Native UI transfers all repair inputs to the player inventory before queueing.
-- Revalidate at completion: FixingManager.fixItem itself does not reject shortages.
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
    -- Native mechanics owns optional cargo approach, including no-walk cheat mode.
    local fixed=self.part and self.part:getId()==R.fixedId
    if not item or not R.validateInstall(self.character,self.part,item,fixed) then return false end
    if self.part:getId()==R.fixedId then return true end
    return ISInstallVehiclePart.isValid(self)
end
function VLSRoofInstallAction:start()
    ISInstallVehiclePart.start(self)
    if self.part:getId()==R.fixedId then startWelding(self) end
end
function VLSRoofInstallAction:update()
    ISInstallVehiclePart.update(self)
    if self.part:getId()==R.fixedId then updateWelding(self) end
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
    if self.part:getId()==R.fixedId then
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

VLSRoofFixAction=ISFixVehiclePartAction:derive("VLSRoofFixAction")
function VLSRoofFixAction:isValid()
    return R.isPart(self.vehiclePart) and self.vehiclePart:getInventoryItem()==self.item
        and self.item:getFullType()==R.fixedType
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
    return ISFixVehiclePartAction.complete(self)
end

-- Reuse the original cutting action and salvage rolls, never its completion:
-- that completion deletes the entire vehicle and yields whole-car materials.
VLSRoofDismantleAction=ISRemoveBurntVehicle:derive("VLSRoofDismantleAction")
function VLSRoofDismantleAction:isValid()
    local rack=self.part and self.part:getInventoryItem()
    return rack and rack:getID()==self.expectedItemId
        and R.canDismantle(self.character,self.part,true)
        and ISRemoveBurntVehicle.isValid(self)
end
function VLSRoofDismantleAction:update()
    ISRemoveBurntVehicle.update(self)
    self.item:setJobType(getText("ContextMenu_Disassemble"))
end
function VLSRoofDismantleAction:complete()
    if isClient() or not self:isValid() then return false end
    -- No yield: remove the exact empty rack once, then native fuel and salvage.
    self.part:setInventoryItem(nil)
    self.vehicle:transmitPartItem(self.part)
    local torch=self.character:getPrimaryHandItem()
    for i=1,10 do torch:Use(false,false,true) end
    local xp=5
    for _,entry in ipairs({{"MetalBar",10,15},{"SmallSheetMetal",4,15},{"Screws",4,25}}) do
        for i=1,entry[2] do
            if self:checkAddItem(entry[1],entry[3]) then xp=xp+1 end
        end
    end
    addXp(self.character,Perks.MetalWelding,xp)
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
        local actionClass=R.isPart(part) and VLSRoofInstallAction or self
        local action=nativeInstallNew(actionClass,character,part,item,maxTimeInit)
        if R.isPart(part) and part:getId()==R.fixedId then
            action.jobType=getText("IGUI_VLSRoofWeldInstall")
        end
        return action
    end
    -- NetTimedAction serializes constructor parameters by matching action field names.
    function ISUninstallVehiclePart:new(character,part,workTime)
        local actionClass=R.isPart(part) and VLSRoofUninstallAction or self
        local action=nativeUninstallNew(actionClass,character,part,workTime)
        if R.isPart(part) then
            local item=part:getInventoryItem()
            action.expectedItemId=item and item:getID() or -1
        end
        return action
    end
    function ISFixVehiclePartAction:new(character,vehiclePart,fixingNum,fixerNum)
        local actionClass=R.isPart(vehiclePart) and vehiclePart:getId()==R.fixedId and VLSRoofFixAction or self
        return nativeFixNew(actionClass,character,vehiclePart,fixingNum,fixerNum)
    end
end
