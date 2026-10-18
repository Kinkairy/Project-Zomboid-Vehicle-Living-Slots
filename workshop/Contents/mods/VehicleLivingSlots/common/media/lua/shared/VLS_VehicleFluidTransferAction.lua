require "VLS_Config"
local NativeContext = require "VLS_NativeContext"
require "Fluids/ISFluidContainer"
require "Fluids/ISFluidUtil"
require "Fluids/ISFluidTransferAction"

local constructingEndpoints

local function integer(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
        and value == math.floor(value)
end


VLSVehicleFluidContainer = ISFluidContainer:derive("VLSVehicleFluidContainer")

function VLSVehicleFluidContainer:new(fluidObject, character, vehicle, fluidItem, part, installationEpoch)
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
    local context = NativeContext.fluid(character, vehicle, part:getId(),
        fluidItem:getID(), installationEpoch)
    o.vlsInstallationEpoch = context and context.installationEpoch or installationEpoch
    return o
end

function VLSVehicleFluidContainer:copy()
    -- Copy the pinned identity, even if it is stale. Looking up the current item
    -- here would let a closed generation silently acquire a replacement FC.
    local o = ISFluidContainer.new(VLSVehicleFluidContainer, self:getFluidObject())
    o.Type = "ISFluidContainer"
    o.vlsVehicleFluidEndpoint = true
    o.vlsPlayerNum, o.vlsCharacter = self.vlsPlayerNum, self.vlsCharacter
    o.vlsVehicleId, o.vlsFluidPartId = self.vlsVehicleId, self.vlsFluidPartId
    o.vlsFluidItemId, o.vlsInstallationEpoch = self.vlsFluidItemId, self.vlsInstallationEpoch
    return o
end

local function resolveVehicleContainer(container, character)
    if not container or not container.vlsVehicleFluidEndpoint
            or container.Type ~= "ISFluidContainer"
            or not integer(container.vlsVehicleId) or not integer(container.vlsFluidItemId)
            or not integer(container.vlsInstallationEpoch)
            or container.vlsInstallationEpoch < 0 then return nil end
    local playerObj = character or container.vlsCharacter or getSpecificPlayer(container.vlsPlayerNum)
    local vehicle = playerObj and playerObj:getVehicle()
    if not vehicle or vehicle:getId() ~= container.vlsVehicleId then return nil end
    return NativeContext.fluid(playerObj, vehicle, container.vlsFluidPartId,
        container.vlsFluidItemId, container.vlsInstallationEpoch)
end

function VLS.isVehicleFluidContainerValid(container, character)
    local context = resolveVehicleContainer(container, character)
    return context ~= nil and context.fluidContainer == container:getFluidContainer()
        and container:getOwner() == context.item
end

-- A synchronized replica may change wrappers within the same installation.
-- Epoch comparison happens before rebinding, including same-item reinstall.
function VLS.refreshVehicleFluidEndpoint(container, character)
    local context = resolveVehicleContainer(container, character)
    if not context then return false end
    if container:getFluidContainer() ~= context.fluidContainer then
        container:initFromObject(context.fluidContainer)
    end
    return VLS.isVehicleFluidContainerValid(container, character)
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
            epoch = endpoint.vlsInstallationEpoch,
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
    if transferAmount ~= transferAmount or transferAmount == math.huge
            or transferAmount <= 0
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

local function resolveEndpoint(character, vehicle, partId, itemId, epoch)
    if type(partId) ~= "string" or not integer(itemId) then return end
    local item, part
    if partId ~= "" then
        if not integer(epoch) or epoch < 0 then return end
        local context = NativeContext.fluid(character, vehicle, partId, itemId, epoch)
        if not context then return end
        item, part = context.item, context.part
    else
        if epoch ~= -1 then return end
        local inventory = character:getInventory()
        item = inventory and inventory:getItemWithIDRecursiv(itemId)
    end
    if not item or item:getID() ~= itemId or not item:getFluidContainer()
            or item:getFluidContainer():getOwner() ~= item then return end
    local endpoint = part and VLSVehicleFluidContainer:new(item:getFluidContainer(),
        character, vehicle, item, part, epoch) or ISFluidContainer:new(item:getFluidContainer())
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
    if not ok then print("[VLS 3.8.8] installed fluid sync failed: " .. tostring(err)) end
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
        vehicle, self.sourcePartId, self.sourceItemId, self.sourceEpoch)
    local target, targetItem, targetPart = resolveEndpoint(self.character,
        vehicle, self.targetPartId, self.targetItemId, self.targetEpoch)
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

function VLSVehicleFluidTransferAction:isValidStart()
    return self:isValid()
end

function VLSVehicleFluidTransferAction:start()
    if not self:isValid() then
        if self.action then self:forceStop() end
        return
    end
    return ISFluidTransferAction.start(self)
end

function VLSVehicleFluidTransferAction:stop()
    self.vlsFinished = true
    return ISFluidTransferAction.stop(self)
end

function VLSVehicleFluidTransferAction:forceCancel()
    self.vlsFinished = true
    return ISFluidTransferAction.forceCancel(self)
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
        sourceItemId, targetPartId, targetItemId, amount, sourceEpoch, targetEpoch)
    -- Original seven-argument calls bind the current generation at first local
    -- construction. Keep legacy reverse/bottle/vehicle branches compatible.
    -- A server W0 reconstruction must carry the already-captured tank epoch.
    local vehicle = character and character:getVehicle()
    local sourceContext = vehicle and NativeContext.identity(vehicle, sourcePartId, sourceItemId)
    local legacy = sourceEpoch == nil and targetEpoch == nil
    local missingW0Epoch = isServer() and sourceEpoch == nil and targetPartId == ""
        and sourceContext and VLS.isWaterTankPart(sourceContext.part)
    if legacy and not missingW0Epoch then
        sourceEpoch = sourcePartId == "" and -1 or sourceContext and sourceContext.installationEpoch
        local targetContext = vehicle and NativeContext.identity(vehicle, targetPartId, targetItemId)
        targetEpoch = targetPartId == "" and -1 or targetContext and targetContext.installationEpoch
    end
    -- This small identity shell exists before invoking the original constructor.
    local identity = setmetatable({ character=character, vehicleId=vehicleId,
        sourcePartId=sourcePartId, sourceItemId=sourceItemId,
        targetPartId=targetPartId, targetItemId=targetItemId, amount=amount,
        sourceEpoch=sourceEpoch, targetEpoch=targetEpoch }, {__index=self})
    local source, target = identity:resolveEndpoints()
    if not source then
        identity.maxTime = 1
        return identity -- invalid/stale network packet: isValid rejects it
    end
    -- The native constructor owns timing (including instant-action settings).
    constructingEndpoints = {}
    if source.vlsVehicleFluidEndpoint then constructingEndpoints[source:getFluidContainer()] = source end
    if target.vlsVehicleFluidEndpoint then constructingEndpoints[target:getFluidContainer()] = target end
    local ok, action = pcall(ISFluidTransferAction.new, self, character,
        source, source:getFluidObject(), target, target:getFluidObject(), amount)
    constructingEndpoints = nil
    if not ok then error(action) end
    for key, value in pairs(identity) do action[key] = value end
    action.source, action.target = source, target
    return action
end
