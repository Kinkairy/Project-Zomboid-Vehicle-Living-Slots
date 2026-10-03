local VLS = require "VLS_Config"
if VLS.F700Adapter then return VLS.F700Adapter end
local P = require "VLS_Pantry"
-- An optional registration layer over the shared Mobile Living API.
assert(VLS.VERSION == "3.11", "Mobile Living: KI5 F700 requires VLS 3.11")
local A = {VERSION = "0.1.2", models = {
    ["Base.87fordF700bank"] = true,
    ["Base.87fordF700swat"] = true,
}}
A.buses = { ["Base.87fordB700school"]=true, ["Base.87fordB700prison"]=true, ["Base.87fordB700military"]=true }
for name in pairs(A.buses) do A.models[name]=true end
function A.isBus(vehicle) return vehicle and A.buses[vehicle:getScriptName()]==true or false end
VLS.F700Adapter = A
A.battery3Id = "VLSF700Battery3"
A.busBatteries = {VLS.AUX_BATTERY_PART_ID, A.battery3Id}
A.frames = {"VLSTopFrame1", "VLSTopFrame2", "VLSTopFrame3", "VLSTopFrame4"}
A.overhead = {"VLSPantryCoffee", "VLSOverhead1", "VLSOverhead2", "VLSOverhead3"}
A.living = {"SeatBed", "VLSLargeVanSlot2", "VLSLargeVanSlot3", "VLSLargeVanSlot4",
    "VLSLargeVanSlot5", "VLSF700Slot6", "VLSF700Slot7"}
A.passengers = {"Bed", "SpaceCenter", "SpaceRight", "VLSLargeVanSpace4",
    "VLSLargeVanSpace5", "VLSF700Space6", "VLSF700Space7"}
A.names = {"IGUI_VLSLargeVanFrontLeftSpace", "IGUI_VLSLargeVanFrontRightSpace",
    "IGUI_VLSLargeVanMiddleLeftSpace", "IGUI_VLSLargeVanMiddleRightSpace",
    "IGUI_VLSF700RearLeftSpace", "IGUI_VLSF700RearRightSpace", "IGUI_VLSF700RearCenterSpace"}
function A.matches(vehicle)
    return vehicle and A.models[vehicle:getScriptName()] == true or false
end
function A.frameIndex(part)
    if not part or not A.matches(part:getVehicle()) then return nil end
    for i, id in ipairs(A.frames) do if part:getId() == id then return i end end
end
local function copy(source)
    local result = {}; for key, value in pairs(source) do result[key] = value end
    return result
end
for i = 8, 14 do A.living[i]="VLSF700Slot"..i end
for i = 6, 14 do
    local freezer = "VLSF700Freezer" .. i
    VLS.FREEZER_PART_BY_UNIVERSAL[A.living[i]] = freezer
    VLS.UNIVERSAL_PART_BY_FREEZER[freezer] = A.living[i]
    VLS.allowedItems[A.living[i]] = copy(VLS.allowedItems.SeatBed)
end
VLS.allowedItems[A.battery3Id] = copy(VLS.allowedItems[VLS.AUX_BATTERY_PART_ID])
VLS.allowedItems.VLSOverhead3 = copy(VLS.allowedItems.VLSOverhead2)
P.slots.VLSOverhead3 = {}
for i=2,4 do VLS.WATER_TANK_PART_IDS["VLSF700WaterTank"..i]=true end
for name in pairs(A.models) do
    local assignments, living, seatPairs = {}, {}, {}
    local bus=A.buses[name]==true
    local conversion = bus or name == "Base.87fordF700swat"
    for i = 1, bus and 14 or conversion and 6 or 7 do
        local id = A.living[i]
        living[i] = id
        local nativeIndex=bus and i or i+1
        local prefix=bus and "IGUI_VLSF700Bus" or "IGUI_VLSF700"
        if conversion then seatPairs[i] = {seat = "SeatP"..nativeIndex, living = id, passenger = "P"..nativeIndex, nameKey = prefix.."Seat"..i} end
        assignments[i] = {part = id, passenger = conversion and "P"..nativeIndex or A.passengers[i], nameKey = conversion and (prefix.."Space"..i) or A.names[i]}
    end
    VLS.vehicleProfiles[name] = {
        kind = "ki5F700", universalParts = living, seatPairs = seatPairs, overheadParts = copy(A.overhead),
        spacePassengers = assignments, bedPassenger = bus and "P1" or conversion and "P2" or "Bed", rearArea = "TruckBed",
        driverOnly = bus,
        auxBatteryParts = bus and copy(A.busBatteries) or nil,
        waterTankParts = bus and {"VLSLargeVanWaterTank", "VLSF700WaterTank2", "VLSF700WaterTank3", "VLSF700WaterTank4"}
            or {"VLSLargeVanWaterTank", "VLSF700WaterTank2"},
        topFrameScale = 1, topFrameReduction = 40.625,
    }
end
-- Keep the main module's three-position arrays and all existing profiles intact.
local baseIndex, baseFrame = VLS.getOverheadIndex, VLS.getTopFramePart
function VLS.getOverheadIndex(part)
    if part and A.matches(part:getVehicle()) then
        for i, id in ipairs(A.overhead) do if part:getId() == id then return i end end
        return nil
    end
    return baseIndex(part)
end
function VLS.getTopFramePart(part)
    if part and A.matches(part:getVehicle()) then
        local i = VLS.getOverheadIndex(part)
        return i and part:getVehicle():getPartById(A.frames[i]) or nil
    end
    return baseFrame(part)
end
local baseName = VLS.getPartDisplayName
function VLS.getPartDisplayName(part, fallback)
    if part and A.matches(part:getVehicle()) and not part:getInventoryItem() then
        local assignment = VLS.getSpaceAssignmentForPart(part:getVehicle(), part)
        if assignment then return getText(assignment.nameKey) end
    end
    return baseName(part, fallback)
end
print("[VehicleLivingSlotsKI5F700] Adapter 0.1.2 on Workshop VLS 3.11: Bank living=7; SWAT pairs=6 tanks=2; Bus variants=3 pairs=14 tanks=4; overhead=4")
return A
