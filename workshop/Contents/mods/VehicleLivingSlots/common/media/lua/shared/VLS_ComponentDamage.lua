require "VLS_Config"
require "VLS_RoofCargo"

VLS = VLS or {}
VLS.Damage = VLS.Damage or {}

local D = VLS.Damage
local samples = setmetatable({}, { __mode = "k" })
local FRONT = { "EngineDoor", "Windshield", "HeadlightLeft", "HeadlightRight" }
local REAR = { "TruckBed", "TrailerTrunk", "DoorRear", "TrunkDoor", "WindshieldRear" }
local STATE_KEY = "VLSComponentDamage"
local DAMAGE_SCALE = { front = 0.0, rear = 0.0, rack = 0.80 }
local SOURCE_IDS = {}
for _, id in ipairs(FRONT) do SOURCE_IDS[id] = true end
for _, id in ipairs(REAR) do SOURCE_IDS[id] = true end
local isEligible

local function itemId(item)
    return item and item.getID and item:getID() or nil
end

local function condition(part)
    return part and part:getCondition() or 0
end

local function isProtected(vehicle)
    local driver = vehicle:getDriverRegardlessOfTow()
    return driver and driver:isGodMod()
end

local function sampleSources(state, vehicle, ids)
    local greatest = 0
    for _, id in ipairs(ids) do
        local part = vehicle:getPartById(id)
        local item = part and part:getInventoryItem()
        local old = state[id]
        local currentId = itemId(item)
        local currentCondition = condition(part)

        if old and old.itemID and currentId and old.itemID == currentId and currentCondition < old.condition then
            greatest = math.max(greatest, old.condition - currentCondition)
        end
        state[id] = { itemID = currentId, condition = currentCondition }
    end
    return greatest
end

function D.supportsVehicle(vehicle)
    local script = vehicle and vehicle:getScript()
    return script and (VLS.vehicleProfiles and VLS.vehicleProfiles[script:getFullName()]
        or VLSRoofCargo.vehicleScripts[script:getFullName()]) ~= nil
end

function D.Init(vehicle)
    if not D.supportsVehicle(vehicle) or (isClient and isClient()) then
        return nil
    end
    local state = samples[vehicle]
    if state then
        return state
    end

    state = { targets = setmetatable({}, { __mode = "k" }) }
    for _, id in ipairs(FRONT) do
        local part = vehicle:getPartById(id)
        state[id] = { itemID = itemId(part and part:getInventoryItem()), condition = condition(part) }
    end
    for _, id in ipairs(REAR) do
        local part = vehicle:getPartById(id)
        state[id] = { itemID = itemId(part and part:getInventoryItem()), condition = condition(part) }
    end
    for index = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(index)
        if isEligible(part) then
            state.targets[part] = itemId(part:getInventoryItem())
        end
    end
    samples[vehicle] = state
    return state
end

function D.IsSource(part)
    return part and SOURCE_IDS[part:getId()] or false
end

-- Mechanics completion may call this after a source part is installed or repaired.
function D.RebaseSource(part)
    if (isClient and isClient()) or not D.IsSource(part) then return end
    local vehicle = part and part:getVehicle()
    if not vehicle then
        return
    end
    local state = D.Init(vehicle)
    if not state then
        return
    end
    state[part:getId()] = {
        itemID = itemId(part:getInventoryItem()),
        condition = condition(part),
    }
end

local function region(part)
    local id = part:getId()
    if id:find("^VLSRoofHeadlight") then
        return "front"
    end
    if VLSRoofCargo and id == VLSRoofCargo.fixedId then
        return "rack"
    end

    if not (VLSRoofCargo and VLSRoofCargo.allowed[part:getId()]) then return "rear" end
    local scriptPart = part:getScriptPart()
    local model = scriptPart and scriptPart:getModel(0)
    local offset = model and model:getOffset()
    if offset and offset:z() ~= 0 then
        return offset:z() > 0 and "front" or "rear"
    end
    return "rear"
end

isEligible = function(part)
    if not part or not part:getInventoryItem() then
        return false
    end
    if VLSRoofCargo and VLSRoofCargo.isPart(part) then
        if part:getId() == VLSRoofCargo.fixedId then return true end
        -- Mounted cargo is not a structural collision target. Return before
        -- the managed-part fallback, including for the original Torch lights.
        if VLSRoofCargo.allowed[part:getId()] then return false end
    end
    return VLS.isManagedPart and VLS.isManagedPart(part)
end

local function apply(vehicle, part, loss)
    local item = part:getInventoryItem()
    local modData = part:getModData()
    local saved = modData[STATE_KEY] or {}
    modData[STATE_KEY] = saved

    local currentId = itemId(item)
    if saved.itemID ~= currentId then
        saved.itemID = currentId
        saved.remainder = 0
    end

    local raw = loss * item:getConditionMax() / 100 + (saved.remainder or 0)
    local amount = math.floor(raw + 0.000000001)
    saved.remainder = math.max(0, raw - amount)
    if amount < 1 then
        return
    end

    part:damage(amount)
    vehicle:transmitPartItem(part)
    return true
end

function D.Update(vehicle)
    if isClient and isClient() then
        return
    end

    local state = D.Init(vehicle)
    if not state then
        return
    end
    local frontLoss = sampleSources(state, vehicle, FRONT)
    local rearLoss = sampleSources(state, vehicle, REAR)
    local guarded = isProtected(vehicle)
    local changed = false
    for index = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(index)
        if isEligible(part) then
            local currentId = itemId(part:getInventoryItem())
            if state.targets[part] ~= currentId then
                -- A target installed during this update starts after this impact.
                state.targets[part] = currentId
                if not guarded then
                    local saved = part:getModData()[STATE_KEY] or {}
                    part:getModData()[STATE_KEY] = saved
                    saved.itemID = currentId
                    saved.remainder = 0
                end
            elseif not guarded then
                local zone = region(part)
                local sourceLoss = zone == "front" and frontLoss
                    or (zone == "rack" and math.max(frontLoss, rearLoss) or rearLoss)
                local loss = sourceLoss * (DAMAGE_SCALE[zone] or 0)
                if loss > 0 then
                    if apply(vehicle, part, loss) then changed = true end
                end
            end
        elseif part then
            state.targets[part] = nil
        end
    end
    if changed then
        vehicle:updatePartStats()
        vehicle:updateBulletStats()
    end
end

-- Native vehicle callbacks resolve this candidate namespace at script load.
require "VLS_BodyArmor"

return D
