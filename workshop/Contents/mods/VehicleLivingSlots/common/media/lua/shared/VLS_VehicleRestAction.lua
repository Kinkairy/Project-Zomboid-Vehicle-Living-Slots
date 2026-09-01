require "VLS_Config"
require "TimedActions/ISRestAction"

ISVLSVehicleRestAction = ISRestAction:derive("ISVLSVehicleRestAction")

function ISVLSVehicleRestAction:isValid()
    local vehicle = self.character and self.character:getVehicle()
    return vehicle ~= nil
        and VLS.isUsingBedSeat(self.character, vehicle)
        and VLS.getInstalledBedPart(vehicle) ~= nil
end

function ISVLSVehicleRestAction:waitToStart()
    return false
end

function ISVLSVehicleRestAction:start()
    self.character:setVariable("ExerciseStarted", false)
    self.character:setVariable("ExerciseEnded", true)
    self.character:setIsResting(true)
    self.character:setBed(nil)
end

local function hasWaitingAction(action)
    if isServer() or not ISTimedActionQueue then return false end
    local queue = ISTimedActionQueue.queues[action.character]
    return queue and queue.queue and queue.queue[1] == action
        and queue.queue[2] ~= nil
end

function ISVLSVehicleRestAction:update()
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
    self.character:setIsResting(true)
    emulateAnimEvent(self.netAction, 100, "update", nil)
end

function ISVLSVehicleRestAction:new(character)
    local action = ISRestAction.new(self, character, nil, false)
    action.useProgressBar = false
    return action
end
