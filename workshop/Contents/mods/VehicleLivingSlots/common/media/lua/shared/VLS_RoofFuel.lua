-- Installed petrol cans keep their native FluidContainer, capacity and contents.
local VLS = require "VLS_Config"
require "VLS_RoofCargo"
require "TimedActions/ISTakeFuel"
local F = {}
VLS.RoofFuel = F
function F.enabled()
    local settings = SandboxVars and SandboxVars.VehicleLivingSlots
    return not settings or settings.EnableRoofPetrolShortcut ~= false
end
function F.getPart(vehicle, id)
    if not vehicle or not VLSRoofCargo.vehicleScripts[vehicle:getScript():getFullName()]
            or type(id) ~= "string" or not id:match("^VLSRoofPetrol[123]$") then return nil end
    local part = vehicle:getPartById(id)
    local item = part and part:getInventoryItem()
    if item and (item:getFullType() == "Base.PetrolCan" or item:getFullType() == "Base.JerryCan")
            and item:getFluidContainer() then
        return part, item, item:getFluidContainer()
    end
end
function F.canReach(player, vehicle, part)
    return F.enabled() and player and not player:isDead() and not player:getVehicle()
        and vehicle and vehicle:isStopped() and part
        and math.floor(player:getZ()) == math.floor(vehicle:getZ())
        and player:DistToProper(vehicle) < 4
        and vehicle:isInArea(part:getArea(), player)
end
function F.isPetrol(fluid)
    -- Same acceptance predicate as vanilla vehicle refuelling.
    return fluid and fluid:contains(Fluid.Petrol) and fluid:getAmount() > 0
end
-- The native pump action owns inventory limits, timing, animations, progress
-- and adding petrol to the portable container. This endpoint only debits the
-- same installed native FluidContainers; it holds no duplicate fuel store.
function F.source(vehicle, roofId1, roofId2, roofId3)
    local source = {vlsRoofVehicle=vehicle, ids={roofId1, roofId2, roofId3}}
    function source:getServicePart()
        for i=1,3 do
            local part, item = F.getPart(vehicle, "VLSRoofPetrol"..i)
            if item and item:getID() == self.ids[i] then return part end
        end
    end
    function source:getSquare()
        local part = self:getServicePart()
        local center = part and vehicle:getAreaCenter(part:getArea())
        return center and getCell():getGridSquare(math.floor(center:getX()), math.floor(center:getY()), math.floor(vehicle:getZ()))
    end
    function source:each(callback)
        if not F.enabled() then return end
        for i=1,3 do
            local part, item, fluid = F.getPart(vehicle, "VLSRoofPetrol"..i)
            if item and item:getID()==self.ids[i] and F.isPetrol(fluid) and fluid:canPlayerEmpty() then
                callback(part, item, fluid)
            end
        end
    end
    function source:getPipedFuelAmount()
        local amount=0
        self:each(function(_, _, fluid) amount=amount+fluid:getAmount() end)
        return amount
    end
    function source:setPipedFuelAmount(value)
        if isClient() then return end
        -- B42.20 ISTakeFuel uses subtraction for progress but addition for its
        -- fractional completion tail. Both writes are withdrawals here.
        local current=self:getPipedFuelAmount()
        local remaining=math.abs(value-current)
        -- Native integer progress includes a rounding epsilon. Do not debit
        -- more than the portable can can accept; completion writes after fill.
        if value < current and self.targetItem then
            remaining=math.min(remaining,self.targetItem:getFluidContainer():getFreeCapacity())
        end
        self:each(function(part, item, fluid)
            local amount=math.min(remaining, fluid:getAmount())
            if amount>0 then
                fluid:adjustAmount(fluid:getAmount()-amount)
                remaining=remaining-amount
                item:syncItemFields()
                vehicle:transmitPartItem(part)
            end
        end)
    end
    return source
end
function F.capture(vehicle)
    local ids={}
    for i=1,3 do
        local _,item=F.getPart(vehicle,"VLSRoofPetrol"..i)
        ids[i]=item and item:getID() or -1
    end
    return F.source(vehicle,ids[1],ids[2],ids[3])
end
local nativeNew = ISTakeFuel.new
VLSRoofFuelAction = ISTakeFuel:derive("VLSRoofFuelAction")
function VLSRoofFuelAction:isValid()
    local player,vehicle=self.character,self.vehicle
    local fluid=self.petrolCan and self.petrolCan:getFluidContainer()
    return F.canReach(player, vehicle, self.fuelStation:getServicePart())
        and fluid and player:getInventory():contains(self.petrolCan,true)
        and (fluid:isEmpty() or fluid:contains(Fluid.Petrol))
        and not fluid:isInputLocked() and fluid:getFreeCapacity()>0
        and self.fuelStation:getSquare() ~= nil and ISTakeFuel.isValid(self) or false
end
-- Keep native pump effects; adapt only the vehicle service-area facing.
function VLSRoofFuelAction:faceServiceArea()
    local part = self.fuelStation:getServicePart()
    local facing = part and self.vehicle:getAreaFacingPosition(part:getArea(), Vector2.new())
    if facing then self.character:faceLocationF(facing:getX(), facing:getY()) end
end
function VLSRoofFuelAction:waitToStart()
    self:faceServiceArea()
    return self.character:shouldBeTurning()
end
function VLSRoofFuelAction:update()
    ISTakeFuel.update(self)
    self:faceServiceArea()
end
-- The queued action may start after another container has already been filled.
function VLSRoofFuelAction:refresh()
    local fresh=nativeNew(VLSRoofFuelAction,self.character,self.fuelStation,self.petrolCan)
    for _,key in ipairs({"square","amount","itemStart","itemTarget","maxTime"}) do self[key]=fresh[key] end
end
function VLSRoofFuelAction:start()
    self:refresh()
    return ISTakeFuel.start(self)
end
function VLSRoofFuelAction:serverStart()
    self:refresh()
    return ISTakeFuel.serverStart(self)
end
function VLSRoofFuelAction:limitToSource()
    if not self:isValid() then return false end
    local fluid=self.petrolCan:getFluidContainer()
    -- Another player may have drawn fuel since this action started.
    self.itemTarget=math.min(self.itemTarget,fluid:getAmount()+self.fuelStation:getPipedFuelAmount(),
        fluid:getAmount()+fluid:getFreeCapacity())
    self.amount=self.itemTarget-self.itemStart
    return true
end
function VLSRoofFuelAction:updateUse(delta)
    if not self:limitToSource() then return end
    local fluid=self.petrolCan:getFluidContainer()
    local before, available=fluid:getAmount(),self.fuelStation:getPipedFuelAmount()
    ISTakeFuel.updateUse(self,delta)
    -- Pump rounding can request 1 L from a finite 0.9995 L remainder. Keep
    -- native progress, but cap its credited volume to actual installed debit.
    local withdrawn=math.max(0,available-self.fuelStation:getPipedFuelAmount())
    if fluid:getAmount()-before > withdrawn+0.000001 then
        fluid:adjustAmount(before+withdrawn)
        self.petrolCan:syncItemFields()
        sendItemStats(self.petrolCan)
    end
end
function VLSRoofFuelAction:complete()
    if isClient() or self.vlsCompleted then return false end
    if not self:limitToSource() then return false end
    self.vlsCompleted=true
    return ISTakeFuel.complete(self)
end
-- Explicit primitive identities survive native NetTimedAction reconstruction.
function VLSRoofFuelAction:new(character, vehicle, petrolCan, roofId1, roofId2, roofId3)
    local source=F.source(vehicle,roofId1,roofId2,roofId3)
    source.targetItem=petrolCan
    local o=nativeNew(self,character,source,petrolCan)
    o.vehicle,o.petrolCan=vehicle,petrolCan
    o.roofId1,o.roofId2,o.roofId3=roofId1,roofId2,roofId3
    return o
end
-- Keep the original onTakeFuelNew callback, including walking, transferring,
-- equipping, Fill All sequencing and returning containers to their bags.
ISTakeFuel.new = function(self, character, fuelStation, petrolCan)
    if type(fuelStation)=="table" and fuelStation.vlsRoofVehicle then
        local ids=fuelStation.ids
        return VLSRoofFuelAction:new(character,fuelStation.vlsRoofVehicle,petrolCan,ids[1],ids[2],ids[3])
    end
    return nativeNew(self,character,fuelStation,petrolCan)
end
return F
