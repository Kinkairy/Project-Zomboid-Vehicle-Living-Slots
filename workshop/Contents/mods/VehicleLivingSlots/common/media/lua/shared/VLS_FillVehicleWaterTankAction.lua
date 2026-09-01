require "Vehicles/TimedActions/ISRefuelFromGasPump"
require "VLS_Config"

VLSFillVehicleWaterTankAction = ISRefuelFromGasPump:derive(
    "VLSFillVehicleWaterTankAction")

local function getSourceAmount(source)
    if not source or not source.getFluidAmount then return 0 end
    return math.max(0, source:getFluidAmount())
end

local function getAvailableAmount(vehicle, tank, source)
    local fluid = tank and tank:getFluidContainer()
    if not fluid then return 0 end
    return math.max(0, math.min(getSourceAmount(source),
        fluid:getCapacity() - fluid:getAmount(),
        VLS.getWaterPurificationCapacity(vehicle)))
end

local WaterSourceAdapter = {}
WaterSourceAdapter.__index = WaterSourceAdapter

function WaterSourceAdapter:new(character, vehicle, part, source, amount)
    local litresPerUnit = Vehicles.JerryCanLitres / 8
    return setmetatable({
        character = character,
        vehicle = vehicle,
        part = part,
        source = source,
        available = amount,
        transferred = 0,
        litresPerUnit = litresPerUnit,
        initialUnits = amount / litresPerUnit,
    }, self)
end

function WaterSourceAdapter:getPipedFuelAmount()
    return self.initialUnits
end

function WaterSourceAdapter:transferTo(target)
    if isClient() or not VLS.Server
            or not VLS.Server.transferWaterTankFillStep then return end
    target = math.max(0, math.min(self.available, target or 0))
    local amount = target - self.transferred
    if amount <= 0 then return end
    local moved = VLS.Server.transferWaterTankFillStep(self.character,
        self.part, self.source, amount)
    self.transferred = self.transferred + math.max(0, tonumber(moved) or 0)
end

function WaterSourceAdapter:setPipedFuelAmount(units)
    local target = (self.initialUnits - (tonumber(units) or self.initialUnits))
        * self.litresPerUnit
    self:transferTo(target)
end

function VLSFillVehicleWaterTankAction:isValid()
    if not self.character or self.character:getVehicle()
            or not self.vehicle or not self.vehicle:isStopped()
            or not self.source or not self.source:getSquare() then return false end
    local tank, part = VLS.getInstalledWaterTank(self.vehicle,
        self.part and self.part:getId())
    if tank ~= self.tank or part ~= self.part then return false end
    if not VLS.isPlayerAtWaterTankInlet(self.vehicle, part, self.character) then
        return false
    end
    return VLS.isWaterSourceNearTank(self.vehicle, part, self.source)
end

VLSFillVehicleWaterTankAction.waitToStart = ISRefuelFromGasPump.waitToStart
VLSFillVehicleWaterTankAction.update = ISRefuelFromGasPump.update
VLSFillVehicleWaterTankAction.start = ISRefuelFromGasPump.start
VLSFillVehicleWaterTankAction.serverStop = ISRefuelFromGasPump.serverStop

function VLSFillVehicleWaterTankAction:complete()
    self.fuelStation:transferTo(self.fuelStation.available)
    return ISRefuelFromGasPump.complete(self)
end

VLSFillVehicleWaterTankAction.stop = ISRefuelFromGasPump.stop
VLSFillVehicleWaterTankAction.perform = ISRefuelFromGasPump.perform
VLSFillVehicleWaterTankAction.getDuration = ISRefuelFromGasPump.getDuration

function VLSFillVehicleWaterTankAction:new(character, part, source)
    local o = ISBaseTimedAction.new(self, character)
    o.part = part
    o.vehicle = part and part:getVehicle() or nil
    o.source = source
    o.tank = o.vehicle and VLS.getInstalledWaterTank(o.vehicle,
        part and part:getId()) or nil
    local amount = getAvailableAmount(o.vehicle, o.tank, source)
    o.fuelStation = WaterSourceAdapter:new(character, o.vehicle, part,
        source, amount)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end
