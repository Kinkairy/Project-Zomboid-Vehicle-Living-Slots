require "VLS_Config"
require "Fluids/ISFluidContainer"
require "Fluids/ISFluidUtil"
require "Fluids/ISFluidTransferAction"

local constructingEndpoints

VLSVehicleFluidContainer = ISFluidContainer:derive("VLSVehicleFluidContainer")

function VLSVehicleFluidContainer:new(fluidObject, character, vehicle, fluidItem, part)
    local o = ISFluidContainer.new(self, fluidObject)
    -- ISFluidUtil accepts only the vanilla public container contract. Keep
    -- that contract while carrying narrowly scoped vehicle identity data.
    o.Type = "ISFluidContainer"
    o.vlsVehicleFluidEndpoint = true
    o.vlsPlayerNum = character:getPlayerNum()
    o.vlsCharacter = character
    o.vlsVehicleId = vehicle:getId()
    o.vlsFluidItemId = fluidItem:getID()
    o.vlsFluidPartId = part:getId()
    return o
end

function VLSVehicleFluidContainer:copy()
    local playerObj = self.vlsCharacter or getSpecificPlayer(self.vlsPlayerNum)
    local vehicle = playerObj and playerObj:getVehicle()
    local fluidItem, part
    if vehicle then
        fluidItem, part = VLS.getVehicleFluidItem(vehicle, self.vlsFluidPartId)
    end
    if not fluidItem then
        return ISFluidContainer.new(ISFluidContainer, self:getFluidObject())
    end
    return VLSVehicleFluidContainer:new(self:getFluidObject(), playerObj,
        vehicle, fluidItem, part)
end

function VLS.isVehicleFluidContainerValid(container, character)
    if not container or not container.vlsVehicleFluidEndpoint then return false end
    local playerObj = character or container.vlsCharacter or getSpecificPlayer(container.vlsPlayerNum)
    local vehicle = playerObj and playerObj:getVehicle()
    if not VLS.isSupportedVehicle(vehicle)
            or vehicle:getId() ~= container.vlsVehicleId then return false end

    local fluidItem = VLS.getVehicleFluidItem(vehicle, container.vlsFluidPartId)
    return fluidItem ~= nil
        and fluidItem:getID() == container.vlsFluidItemId
        and fluidItem:getFluidContainer() == container:getFluidContainer()
end

-- transmitPartItem() may replace the client-side InventoryItem wrapper while
-- preserving the installed bottle ID. Rebind the scoped endpoint before the
-- vanilla panel validates it so the original transfer UI stays open and keeps
-- displaying the synchronized amounts.
function VLS.refreshVehicleFluidEndpoint(container, character)
    if not container or not container.vlsVehicleFluidEndpoint then return false end
    local playerObj = character or container.vlsCharacter or getSpecificPlayer(container.vlsPlayerNum)
    local vehicle = playerObj and playerObj:getVehicle()
    if not VLS.isSupportedVehicle(vehicle)
            or vehicle:getId() ~= container.vlsVehicleId then return false end

    local fluidItem = VLS.getVehicleFluidItem(vehicle, container.vlsFluidPartId)
    if not fluidItem or fluidItem:getID() ~= container.vlsFluidItemId
            or not fluidItem:getFluidContainer() then return false end
    if container:getFluidContainer() ~= fluidItem:getFluidContainer() then
        container:initFromObject(fluidItem:getFluidContainer())
    end
    return true
end

if not VLS.vehicleFluidValidationHookApplied then
    VLS.vehicleFluidValidationHookApplied = true
    VLS.vanillaValidateFluidContainer = ISFluidUtil.validateContainer
    ISFluidUtil.validateContainer = function(container)
        -- Native server constructor rebuilds plain wrappers. Supply actor-aware
        -- validation only during this exact constructor call, then discard.
        if constructingEndpoints and container then
            local endpoint = constructingEndpoints[container:getFluidContainer()]
            if endpoint then return endpoint:isValid() end
        end
        if container and container.vlsVehicleFluidEndpoint then
            return VLS.isVehicleFluidContainerValid(container)
        end
        return VLS.vanillaValidateFluidContainer(container)
    end
end

local function describeFluidEndpoint(character, endpoint)
    if not endpoint then return nil end
    if endpoint.vlsVehicleFluidEndpoint then
        if not VLS.isVehicleFluidContainerValid(endpoint, character) then return nil end
        return {
            kind = "vehicle",
            part = endpoint.vlsFluidPartId,
            item = endpoint.vlsFluidItemId,
        }, endpoint.vlsVehicleId
    end

    if not ISFluidUtil.validateContainer(endpoint) then return nil end
    local item = endpoint:getOwner()
    if not item or not instanceof(item, "InventoryItem") then return nil end
    local inventory = character and character:getInventory()
    if not inventory or inventory:getItemWithIDRecursiv(item:getID()) ~= item then
        return nil
    end
    return { kind = "inventory", item = item:getID() }, nil
end

function VLS.makeVehicleFluidTransferRequest(character, source, target, amount)
    local sourceDescriptor, sourceVehicle = describeFluidEndpoint(character, source)
    local targetDescriptor, targetVehicle = describeFluidEndpoint(character, target)
    if not sourceDescriptor or not targetDescriptor then return nil end
    local vehicleId = sourceVehicle or targetVehicle
    if not vehicleId or (sourceVehicle and targetVehicle
            and sourceVehicle ~= targetVehicle) then return nil end

    local transferAmount = math.max(0, tonumber(amount) or 0)
    if transferAmount <= 0
            or not FluidContainer.CanTransfer(source:getFluidContainer(),
                target:getFluidContainer()) then return nil end

    return {
        vehicle = vehicleId,
        source = sourceDescriptor,
        target = targetDescriptor,
        amount = transferAmount,
    }
end

-- Never trust a serialized installed InventoryItem/FluidContainer owner. Resolve
-- primitive IDs independently on each peer and validate the current ownership.
local function integer(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
        and value == math.floor(value)
end

local function resolveEndpoint(character, vehicle, partId, itemId)
    if type(partId) ~= "string" or not integer(itemId) then return end
    local item, part
    if partId ~= "" then
        item, part = VLS.getVehicleFluidItem(vehicle, partId)
    else
        item = character:getInventory():getItemWithIDRecursiv(itemId)
    end
    if not item or item:getID() ~= itemId or not item:getFluidContainer() then return end
    local endpoint = part and VLSVehicleFluidContainer:new(item:getFluidContainer(),
        character, vehicle, item, part) or ISFluidContainer:new(item:getFluidContainer())
    return endpoint, item, part
end

function VLSVehicleFluidContainer:isValid()
    return VLS.isVehicleFluidContainerValid(self, self.vlsCharacter)
end

function VLSVehicleFluidContainer:sync()
    if isClient() then return end
    local vehicle = self.vlsCharacter and self.vlsCharacter:getVehicle()
    if not vehicle or not self:isValid() then return end
    local item, part = VLS.getVehicleFluidItem(vehicle, self.vlsFluidPartId)
    local ok, err = pcall(function()
    item:syncItemFields()
    if VLS.isWaterTankPart(part) then
        VLS.syncVehicleWaterTank(vehicle, part)
        vehicle:transmitPartModData(part)
    end
    vehicle:transmitPartItem(part)
    end)
    if not ok then print("[VLS 3.8.6] installed fluid sync failed: " .. tostring(err)) end
end

VLSVehicleFluidTransferAction = ISFluidTransferAction:derive("VLSVehicleFluidTransferAction")

function VLSVehicleFluidTransferAction:resolveEndpoints()
    if not self.character or not integer(self.vehicleId)
            or type(self.amount) ~= "number" or self.amount ~= self.amount
            or self.amount <= 0 or self.amount == math.huge
            or (self.sourcePartId == "" and self.targetPartId == "") then return end
    local vehicle = self.character:getVehicle()
    if not vehicle or vehicle:getId() ~= self.vehicleId
            or not VLS.isSupportedVehicle(vehicle) then return end
    local source, sourceItem, sourcePart = resolveEndpoint(self.character,
        vehicle, self.sourcePartId, self.sourceItemId)
    local target, targetItem, targetPart = resolveEndpoint(self.character,
        vehicle, self.targetPartId, self.targetItemId)
    if not source or not target or sourceItem == targetItem then return end
    return source, target, vehicle, sourcePart, targetPart
end

function VLSVehicleFluidTransferAction:isValid()
    if self.vlsFinished then return false end
    local source, target, vehicle, _, targetPart = self:resolveEndpoints()
    if not source or not self.source or not self.target then return false end
    -- Item replacement with the same ID is allowed only for the client replica.
    if isClient() then
        self.source, self.target = source, target
    elseif source:getFluidContainer() ~= self.source:getFluidContainer()
            or target:getFluidContainer() ~= self.target:getFluidContainer() then return false end
    if not source:getFluidContainer():canPlayerEmpty() then return false end
    if VLS.isWaterTankPart(targetPart) then
        return VLS.isPureWaterFluid(source:getFluidContainer())
            and VLS.getWaterPurificationCapacity(vehicle) > 0
            and VLS.canAcceptNormalizedWater(target:getFluidContainer(), 0.0001)
    end
    return ISFluidTransferAction.isValid(self)
end

function VLSVehicleFluidTransferAction:update()
    if not self:isValid() then self:forceStop(); return end
    if isClient() then return ISFluidTransferAction.update(self) end
    if not VLS.Server.runVehicleFluidAction(self, ISFluidTransferAction.update) then
        self:forceStop()
    end
end

function VLSVehicleFluidTransferAction:complete()
    if isClient() or not self:isValid() then return false end
    self.vlsFinished = true
    return VLS.Server.runVehicleFluidAction(self, ISFluidTransferAction.complete)
end

function VLSVehicleFluidTransferAction:new(character, vehicleId, sourcePartId,
        sourceItemId, targetPartId, targetItemId, amount)
    -- This small identity shell exists before invoking the original constructor.
    local identity = setmetatable({ character=character, vehicleId=vehicleId,
        sourcePartId=sourcePartId, sourceItemId=sourceItemId,
        targetPartId=targetPartId, targetItemId=targetItemId, amount=amount }, {__index=self})
    local source, target = identity:resolveEndpoints()
    if not source then
        identity.maxTime = 1
        return identity -- invalid/stale network packet: isValid rejects it
    end
    -- The native constructor owns timing (including instant-action settings).
    constructingEndpoints = { [source:getFluidContainer()]=source,
        [target:getFluidContainer()]=target }
    local ok, action = pcall(ISFluidTransferAction.new, self, character,
        source, source:getFluidObject(), target, target:getFluidObject(), amount)
    constructingEndpoints = nil
    if not ok then error(action) end
    for key, value in pairs(identity) do action[key] = value end
    action.source, action.target = source, target
    return action
end
