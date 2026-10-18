require "VLS_Config"
require "TimedActions/ISRestAction"
local Context = require "VLS_NativeContext"

ISVLSVehicleRestAction = ISRestAction:derive("ISVLSVehicleRestAction")

function ISVLSVehicleRestAction:isValid()
    local vehicle = self.character and self.character:getVehicle()
    if not vehicle or vehicle:getId() ~= self.vehicleId
            or type(self.installationEpoch) ~= "number" or self.installationEpoch < 0
            or self.installationEpoch ~= math.floor(self.installationEpoch) then return false end
    local identity = Context.resolve(self.character,vehicle,self.partId,
        self.installedItemId,self.installationEpoch)
    return identity ~= nil and VLS.isUsingBedSeat(self.character,vehicle)
        and VLS.getBedSeat(vehicle,identity.part) == vehicle:getSeat(self.character)
        and VLS.getInstalledBedPartForSeat(vehicle,vehicle:getSeat(self.character)) == identity.part
end

function ISVLSVehicleRestAction:waitToStart()
    return false
end

function ISVLSVehicleRestAction:start()
    if not self:isValid() then return self:forceStop() end
    -- The native action already accepts an absent furniture object here.
    return ISRestAction.start(self)
end

local function hasWaitingAction(action)
    if isServer() or not ISTimedActionQueue then return false end
    local queue = ISTimedActionQueue.queues[action.character]
    return queue and queue.queue and queue.queue[1] == action
        and queue.queue[2] ~= nil
end

function ISVLSVehicleRestAction:update()
    if not self:isValid() then
        if isServer() then return self.netAction:forceComplete() end
        return self:forceStop()
    end
    -- Vanilla furniture rest no longer monopolizes the action queue after the
    -- character is seated. A vehicle bed has no IsoObject seat to hand back to
    -- vanilla, so keep its rest action only while it is the sole queued action.
    -- Any ordinary vanilla action queued by the player completes this adapter
    -- first and then starts through the untouched official queue.
    if hasWaitingAction(self) then
        self:forceComplete()
        return
    end
    ISRestAction.update(self)
end

function ISVLSVehicleRestAction:serverStart()
    if not self:isValid() then return self.netAction:forceComplete() end
    self.character:setIsResting(true)
    emulateAnimEvent(self.netAction, 100, "update", nil)
end

function ISVLSVehicleRestAction:new(character, vehicleId, partId, installedItemId, installationEpoch)
    local action = ISRestAction.new(self, character, nil, false)
    action.vehicleId, action.partId = vehicleId, partId
    action.installedItemId, action.installationEpoch = installedItemId, installationEpoch
    action.useProgressBar = false
    return action
end
