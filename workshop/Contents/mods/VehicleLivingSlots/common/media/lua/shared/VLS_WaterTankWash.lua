require "VLS_Config"
require "TimedActions/ISWashYourself"
require "TimedActions/ISWashClothing"

-- Native shared timed actions serialize constructor fields, not a fake world sink.
-- Resolve the installed tank independently on client/server. Never add an IsoObject
-- to the world, create free water, or override the global native wash actions.
VLS.TankWash = VLS.TankWash or {}
local W = VLS.TankWash

local function integer(value)
    return type(value)=="number" and value==value and math.abs(value)<math.huge
        and value==math.floor(value)
end

function W.resolve(character, vehicleId, partId, tankId, requirePosition)
    if not character or character:isDead() or character:getVehicle()
            or not integer(vehicleId) or not integer(tankId)
            or type(partId)~="string" or partId=="" then return nil end
    local vehicle=getVehicleById(vehicleId)
    if not vehicle or vehicle:isRemovedFromWorld() or not vehicle:isStopped()
            or not VLS.isSupportedVehicle(vehicle) then return nil end
    local tank,part=VLS.getInstalledWaterTank(vehicle,partId)
    if not tank or not part or part:getId()~=partId or tank:getID()~=tankId then return nil end
    if requirePosition and not VLS.isPlayerAtWaterTankInlet(vehicle,part,character) then return nil end
    local fluid=tank:getFluidContainer()
    if not fluid or not VLS.isPureWaterFluid(fluid) or not fluid:canPlayerEmpty() then return nil end
    return vehicle,part,tank,fluid
end

function W.clothingAmounts(item)
    local blood,dirt=0,0
    if instanceof(item,"Clothing") or instanceof(item,"InventoryContainer") then
        local covered=BloodClothingType.getCoveredParts(item:getBloodClothingType())
        if covered then
            for i=0,covered:size()-1 do blood=blood+item:getBlood(covered:get(i)) end
        end
        dirt=math.max(0,item:getDirtiness())
    else blood=math.max(0,item:getBloodLevel()) end
    return blood,dirt
end

function W.isWashable(item)
    if not item then return false end
    local blood,dirt=W.clothingAmounts(item)
    return blood+dirt>0 or item:getItemAfterCleaning()~=nil
end

local function refreshClothing(action)
    local inventory=action.character and action.character:getInventory()
    local item=action.item and inventory and inventory:getItemWithIDRecursiv(action.item:getID())
    if not item or not W.isWashable(item) then return false end
    action.item=item
    action.bloodAmount,action.dirtAmount=W.clothingAmounts(item)
    action.soaps=inventory:getSoapList(nil,true)
    action.noSoap=ISWashClothing.GetSoapRemaining(action.soaps)<=0
    return true
end

-- This adapter exists only inside this action. Native completion consumes a
-- previously debited budget; it can never debit a second tank or overdraw water.
local function sinkFor(action,budget)
    local sink={used=0}
    function sink:getFluidAmount()
        if budget then return budget end
        local _,_,_,fluid=W.resolve(action.character,action.vehicleId,action.partId,action.tankId,false)
        return fluid and math.max(0,math.floor(fluid:getAmount())) or 0
    end
    function sink:useFluid(amount)
        assert(budget and amount>=0 and self.used+amount<=budget+0.0001,"VLS wash budget exceeded")
        self.used=self.used+amount
        return amount
    end
    function sink:transmitModData() end -- tank is synchronized by the authoritative completion
    return sink
end

local function resolveAction(action)
    return W.resolve(action.character,action.vehicleId,action.partId,action.tankId,true)
end

local function syncTank(vehicle,part,tank)
    VLS.syncVehicleWaterTank(vehicle,part)
    tank:syncItemFields()
    vehicle:transmitPartModData(part)
    vehicle:transmitPartItem(part)
end

local function completeWash(action,nativeComplete,body)
    if isClient() or action.vlsCommitted then return false end
    local vehicle,part,tank,fluid=resolveAction(action)
    if not vehicle then return false end
    if not body and (not refreshClothing(action)
            or action.item:getContainer()~=action.character:getInventory()) then return false end
    local required=body and math.min(ISWashYourself.GetRequiredWater(action.character),
        math.floor(fluid:getAmount())) or ISWashClothing.GetRequiredWater(action.item)
    if required<=0 or required>fluid:getAmount() then return false end
    -- No yield between identity/availability checks and debit. Competing players
    -- see the updated real amount. Cancelled actions never enter this function.
    local before=fluid:getAmount()
    fluid:removeFluid(required)
    if math.abs(before-fluid:getAmount()-required)>0.0001 then
        syncTank(vehicle,part,tank)
        print("[VLS 3.8.3] wash rejected: native water debit mismatch")
        return false
    end
    action.vlsCommitted=true
    if body then action.soaps=action.character:getInventory():getSoapList(nil,false) end
    local oldSink=action.sink
    action.sink=sinkFor(action,required)
    local ok,result=pcall(nativeComplete,action)
    action.sink=oldSink
    syncTank(vehicle,part,tank)
    -- Do not refund after partial native cleaning/soap effects on an exception:
    -- that would turn a failing third-party hook into unlimited free washing.
    if not ok then print("[VLS 3.8.3] native wash failed after water debit: "..tostring(result));return false end
    return result==true
end

VLSWashYourselfFromTank=ISWashYourself:derive("VLSWashYourselfFromTank")
function VLSWashYourselfFromTank:isValid()
    local vehicle,_,_,fluid=resolveAction(self)
    return not self.vlsCommitted and vehicle~=nil and fluid:getAmount()>=1
        and ISWashYourself.GetRequiredWater(self.character)>0
end
function VLSWashYourselfFromTank:update()
    local vehicle=resolveAction(self)
    if vehicle then self.character:faceThisObject(vehicle) end
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end
function VLSWashYourselfFromTank:getDuration()
    self.soaps=self.character:getInventory():getSoapList(nil,false)
    self.sink=sinkFor(self)
    return ISWashYourself.getDuration(self)
end
function VLSWashYourselfFromTank:complete()
    return completeWash(self,ISWashYourself.complete,true)
end
function VLSWashYourselfFromTank:new(character,vehicleId,partId,tankId)
    local o=ISBaseTimedAction.new(self,character)
    o.vehicleId=vehicleId;o.partId=partId;o.tankId=tankId
    o.forceProgressBar=true
    o.maxTime=o:getDuration()
    return o
end

VLSWashClothingFromTank=ISWashClothing:derive("VLSWashClothingFromTank")
function VLSWashClothingFromTank:isValid()
    local vehicle,_,_,fluid=resolveAction(self)
    if self.vlsCommitted or not vehicle or not refreshClothing(self) then return false end
    if not isClient() and self.item:getContainer()~=self.character:getInventory() then return false end
    return fluid:getAmount()>=ISWashClothing.GetRequiredWater(self.item)
end
function VLSWashClothingFromTank:update()
    local vehicle=resolveAction(self)
    if vehicle then self.character:faceThisObject(vehicle) end
    self.item:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end
function VLSWashClothingFromTank:getDuration()
    if not refreshClothing(self) then return 0 end
    return ISWashClothing.getDuration(self)
end
function VLSWashClothingFromTank:complete()
    return completeWash(self,ISWashClothing.complete,false)
end
function VLSWashClothingFromTank:new(character,vehicleId,partId,tankId,item)
    local o=ISBaseTimedAction.new(self,character)
    o.vehicleId=vehicleId;o.partId=partId;o.tankId=tankId;o.item=item
    o.sink=sinkFor(o)
    o.forceProgressBar=true
    o.maxTime=o:getDuration()
    return o
end
return W
