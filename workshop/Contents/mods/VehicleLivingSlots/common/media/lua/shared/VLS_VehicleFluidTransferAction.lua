require "VLS_Config"
require "Fluids/ISFluidContainer"
require "Fluids/ISFluidUtil"

VLSVehicleFluidContainer = ISFluidContainer:derive("VLSVehicleFluidContainer")

function VLSVehicleFluidContainer:new(fluidObject, character, vehicle, fluidItem, part)
    local o = ISFluidContainer.new(self, fluidObject)
    -- ISFluidUtil accepts only the vanilla public container contract. Keep
    -- that contract while carrying narrowly scoped vehicle identity data.
    o.Type = "ISFluidContainer"
    o.vlsVehicleFluidEndpoint = true
    o.vlsPlayerNum = character:getPlayerNum()
    o.vlsVehicleId = vehicle:getId()
    o.vlsFluidItemId = fluidItem:getID()
    o.vlsFluidPartId = part:getId()
    return o
end

function VLSVehicleFluidContainer:copy()
    local playerObj = getSpecificPlayer(self.vlsPlayerNum)
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
    local playerObj = character or getSpecificPlayer(container.vlsPlayerNum)
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
    local playerObj = character or getSpecificPlayer(container.vlsPlayerNum)
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
