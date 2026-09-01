local VLS = require "VLS_KI5Campers_Config"
require "Vehicles/ISUI/ISVehicleSeatUI"

local KI5_CAMPERS = {
    ["Base.Trailer87Scamp13"] = true,
    ["Base.Trailer87Scamp16"] = true,
    ["Base.Trailer61Bambi16"] = true,
    ["Base.Trailer54FlyingCloud22"] = true,
}

local FLYING_CLOUD = "Base.Trailer54FlyingCloud22"
local FLYING_NATIVE_RENDER_SHIFT = {
    SideB = 0.40,
    FrontL = 0.71,
    FrontR = 0.40,
}
local LIVING_PASSENGER_PREFIX = "VLSKI5Space"
local FAKE_PASSENGER = "DAMNFakeSeat"
local SEAT_WIDTH = 41
local SEAT_HEIGHT = 59

local function isLivingPassenger(passenger)
    if not passenger then return false end
    local id = passenger:getId()
    return id and string.sub(id, 1, #LIVING_PASSENGER_PREFIX) ==
        LIVING_PASSENGER_PREFIX
end

local function getPassengerById(script, passengerId)
    for index = 0, script:getPassengerCount() - 1 do
        local passenger = script:getPassenger(index)
        if passenger and passenger:getId() == passengerId then
            return passenger
        end
    end
    return nil
end

local function shiftFlyingCloudNativePositions(script)
    local saved = {}
    for passengerId, deltaZ in pairs(FLYING_NATIVE_RENDER_SHIFT) do
        local passenger = getPassengerById(script, passengerId)
        local position = passenger and passenger:getPositionById("inside") or nil
        local offset = position and position:getOffset() or nil
        if offset then
            local x, y, z = offset:get(0), offset:get(1), offset:get(2)
            saved[#saved + 1] = { offset = offset, x = x, y = y, z = z }
            offset:set(x, y, z + deltaZ)
        end
    end
    return saved
end

local function restorePositions(saved)
    for index = #saved, 1, -1 do
        local entry = saved[index]
        entry.offset:set(entry.x, entry.y, entry.z)
    end
end

local function preferNativeSeatHit(panel, script, scriptName)
    local vehicle = panel.vehicle
    local extents = script:getExtents()
    local scale = panel.height * 0.7 / extents:z()
    local offsetX = SeatOffsetX[scriptName] or 0.0
    local offsetY = SeatOffsetY[scriptName] or 0.0
    local mouseX, mouseY = panel:getMouseX(), panel:getMouseY()
    local preferredSeat = nil

    for seat = 0, vehicle:getMaxPassengers() - 1 do
        local passenger = script:getPassenger(seat)
        local passengerId = passenger and passenger:getId() or nil
        if passengerId and passengerId ~= FAKE_PASSENGER and
                not isLivingPassenger(passenger) then
            local position = passenger:getPositionById("inside")
            local offset = position and position:getOffset() or nil
            if offset then
                local x = panel:getWidth() / 2 - offset:get(0) * scale -
                    SEAT_WIDTH / 2 + offsetX
                local y = panel:getHeight() / 2 - offset:get(2) * scale -
                    SEAT_HEIGHT / 2 + offsetY
                if mouseX >= x and mouseX < x + SEAT_WIDTH and
                        mouseY >= y and mouseY < y + SEAT_HEIGHT then
                    preferredSeat = seat
                end
            end
        end
    end

    if preferredSeat ~= nil then panel.mouseOverSeat = preferredSeat end
end

local function safeValue(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local function diagnosticText(value)
    if value == nil then return "nil" end
    return tostring(value)
end

local function logNativeEntryState(panel, seat)
    local vehicle = panel.vehicle
    local script = vehicle and vehicle:getScript() or nil
    local passenger = script and script:getPassenger(seat) or nil
    if not passenger or isLivingPassenger(passenger)
            or passenger:getId() == FAKE_PASSENGER then
        return
    end

    local outside = passenger:getPositionById("outside")
    local doorPart = safeValue(function() return vehicle:getPassengerDoor(seat) end)
    local door = doorPart and safeValue(function() return doorPart:getDoor() end) or nil
    local doorItem = doorPart and
        safeValue(function() return doorPart:getInventoryItem() end) or nil
    local character = panel.character
    local blockMovement = nil
    local enterBlocked = nil
    local doorOpen = nil
    local doorLocked = nil
    if character then
        blockMovement = safeValue(function() return character:isBlockMovement() end)
        enterBlocked = safeValue(function()
            return vehicle:isEnterBlocked(character, seat)
        end)
    end
    if door then
        doorOpen = safeValue(function() return door:isOpen() end)
        doorLocked = safeValue(function() return door:isLocked() end)
    end

    print(string.format(
        "[VLS-KI5-ENTRY] script=%s seat=%s passenger=%s installed=%s " ..
        "occupied=%s blockMovement=%s outside=%s enterBlocked=%s " ..
        "doorPart=%s doorInstalled=%s doorOpen=%s doorLocked=%s",
        diagnosticText(vehicle:getScriptName()), diagnosticText(seat),
        diagnosticText(passenger:getId()),
        diagnosticText(safeValue(function() return vehicle:isSeatInstalled(seat) end)),
        diagnosticText(safeValue(function() return vehicle:isSeatOccupied(seat) end)),
        diagnosticText(blockMovement),
        diagnosticText(outside ~= nil),
        diagnosticText(enterBlocked),
        diagnosticText(doorPart and doorPart:getId() or nil),
        diagnosticText(doorItem ~= nil),
        diagnosticText(doorOpen), diagnosticText(doorLocked)
    ))
end

if not VLS.ki5CampersSeatUIHookApplied then
    VLS.ki5CampersSeatUIHookApplied = true
    local vanillaRender = ISVehicleSeatUI.render

    function ISVehicleSeatUI:render()
        local vehicle = self.vehicle
        local scriptName = vehicle and vehicle:getScriptName() or nil
        if not scriptName or not KI5_CAMPERS[scriptName] then
            return vanillaRender(self)
        end

        local script = vehicle:getScript()
        local savedPositions = scriptName == FLYING_CLOUD and
            shiftFlyingCloudNativePositions(script) or {}

        local ok, err = pcall(vanillaRender, self)
        if ok then preferNativeSeatHit(self, script, scriptName) end
        restorePositions(savedPositions)
        if not ok then error(err) end
    end
end

if not VLS.ki5CampersUseSeatDiagnosticApplied then
    VLS.ki5CampersUseSeatDiagnosticApplied = true
    local originalUseSeat = ISVehicleSeatUI.useSeat

    function ISVehicleSeatUI:useSeat(seat)
        local vehicle = self.vehicle
        local scriptName = vehicle and vehicle:getScriptName() or nil
        if scriptName and KI5_CAMPERS[scriptName] then
            logNativeEntryState(self, seat)
        end
        return originalUseSeat(self, seat)
    end
end
