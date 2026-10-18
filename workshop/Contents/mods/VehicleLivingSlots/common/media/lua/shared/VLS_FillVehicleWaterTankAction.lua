require "Vehicles/TimedActions/ISRefuelFromGasPump"
require "VLS_Config"
local Context = require "VLS_NativeContext"

VLSFillVehicleWaterTankAction = ISRefuelFromGasPump:derive(
    "VLSFillVehicleWaterTankAction")

local WaterSourceAdapter = {}
WaterSourceAdapter.__index = WaterSourceAdapter

function WaterSourceAdapter:new(character, vehicle, part, source, amount, itemId, installationEpoch)
    local litresPerUnit = Vehicles.JerryCanLitres / 8
    return setmetatable({
        character = character,
        vehicle = vehicle,
        part = part,
        source = source,
        itemId = itemId,
        installationEpoch = installationEpoch,
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
        self.part, self.source, amount, self.itemId, self.installationEpoch)
    self.transferred = self.transferred + math.max(0, tonumber(moved) or 0)
end

function WaterSourceAdapter:setPipedFuelAmount(units)
    local target = (self.initialUnits - (tonumber(units) or self.initialUnits))
        * self.litresPerUnit
    self:transferTo(target)
end

local function validBinding(self, settling)
    if self.vlsFinished or self.vlsSettled or (self.vlsCancelled and not settling)
            or type(self.installationEpoch) ~= "number"
            or self.installationEpoch < 0
            or self.installationEpoch ~= math.floor(self.installationEpoch) then return false end
    if not VLS.isWaterTankShortcutEnabled() or not self.character or self.character:getVehicle()
            or not self.vehicle or not self.vehicle:isStopped()
            or not self.source or not self.source:getSquare() then return false end
    local tank, part = VLS.getInstalledWaterTank(self.vehicle,
        self.part and self.part:getId())
    local context = Context.identity(self.vehicle, self.part and self.part:getId(),
        self.tank and self.tank:getID(), self.installationEpoch)
    if not context or context.item ~= self.tank or context.part ~= self.part
            or tank ~= self.tank or part ~= self.part then return false end
    if not VLS.isPlayerAtWaterTankInlet(self.vehicle, part, self.character) then
        return false
    end
    return VLS.isWaterSourceNearTank(self.vehicle, part, self.source)
end

function VLSFillVehicleWaterTankAction:isValid()
    return validBinding(self)
        and VLS.getWaterTankFillAmount(self.vehicle, self.tank, self.source) > 0
end

VLSFillVehicleWaterTankAction.waitToStart = ISRefuelFromGasPump.waitToStart
function VLSFillVehicleWaterTankAction:update()
    if validBinding(self) then return ISRefuelFromGasPump.update(self) end
end
VLSFillVehicleWaterTankAction.start = ISRefuelFromGasPump.start
function VLSFillVehicleWaterTankAction:serverStop()
    if not validBinding(self, true) then return end
    local ok, result = pcall(ISRefuelFromGasPump.serverStop, self)
    self.vlsCancelled = true
    self.vlsSettled = true
    if not ok then error(result) end
    return result
end

function VLSFillVehicleWaterTankAction:complete()
    if self.vlsCompleting or not validBinding(self) then return false end
    self.vlsCompleting = true
    local ok, result = pcall(function()
        self.fuelStation:transferTo(self.fuelStation.available)
        return ISRefuelFromGasPump.complete(self)
    end)
    self.vlsCompleting = false
    self.vlsFinished = true
    if not ok then error(result) end
    return result
end

function VLSFillVehicleWaterTankAction:stop()
    self.vlsCancelled = true
    return ISRefuelFromGasPump.stop(self)
end
function VLSFillVehicleWaterTankAction:forceCancel()
    self.vlsCancelled = true
    self.vlsSettled = true
    return ISBaseTimedAction.forceCancel(self)
end
VLSFillVehicleWaterTankAction.perform = ISRefuelFromGasPump.perform
VLSFillVehicleWaterTankAction.getDuration = ISRefuelFromGasPump.getDuration

function VLSFillVehicleWaterTankAction:new(character, part, source, installationEpoch)
    local o = ISBaseTimedAction.new(self, character)
    o.part = part
    o.vehicle = part and part:getVehicle() or nil
    o.source = source
    o.tank = o.vehicle and VLS.getInstalledWaterTank(o.vehicle,
        part and part:getId()) or nil
    o.installationEpoch = Context.creationEpoch(o.vehicle, part and part:getId(),
        o.tank and o.tank:getID(), installationEpoch)
    local amount = VLS.getWaterTankFillAmount(o.vehicle, o.tank, source)
    o.fuelStation = WaterSourceAdapter:new(character, o.vehicle, part,
        source, amount, o.tank and o.tank:getID(), o.installationEpoch)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end
