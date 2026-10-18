-- Shared vehicle-host boundary. No recipe, appliance or inventory simulation.
-- Resolve existing native objects every time; never persist userdata or clone cargo.
local Context = {}

local function integer(n)
    return type(n) == "number" and n == n and n ~= math.huge
        and n ~= -math.huge and n == math.floor(n)
end

-- Intrinsic identity only: callers retain their eligibility and access policy.
-- This entry supports roof-only hosts without granting interior eligibility.
function Context.partIdentity(vehicle, partId, installedItemId, installationEpoch)
    if not vehicle then return nil, "missing_host" end
    if type(partId) ~= "string" or partId == "" then return nil, "invalid_part" end
    local part = vehicle:getPartById(partId)
    if not part or part:getVehicle() ~= vehicle then return nil, "foreign_part" end
    local item = part:getInventoryItem()
    if not item then return nil, "uninstalled" end
    local epoch = part:getModData().vlsNativeEpoch or 0
    if not integer(epoch) or epoch < 0 or epoch >= 2147483647 then
        return nil, "invalid_identity"
    end
    if (installedItemId ~= nil and item:getID() ~= installedItemId)
            or (installationEpoch ~= nil and epoch ~= installationEpoch) then
        return nil, "installation_changed"
    end
    return { vehicle = vehicle, part = part, item = item,
        container = part:getItemContainer(), vehicleId = vehicle:getId(),
        partId = partId, installedItemId = item:getID(), installationEpoch = epoch }
end

-- Existing interior-managed policy remains unchanged for established callers.
function Context.identity(vehicle, partId, installedItemId, installationEpoch)
    if not vehicle or not VLS.isSupportedVehicle(vehicle) then return nil, "unsupported_host" end
    if type(partId) ~= "string" or partId == "" then return nil, "invalid_part" end
    local part = vehicle:getPartById(partId)
    if not part or part:getVehicle() ~= vehicle or not VLS.isManagedPart(part) then
        return nil, "unmanaged_part"
    end
    return Context.partIdentity(vehicle, partId, installedItemId, installationEpoch)
end

-- Capture once for a locally-created action. Network reconstruction must carry
-- the supplied primitive; the server never upgrades a missing generation.
function Context.creationEpoch(vehicle, partId, installedItemId, installationEpoch, resolver)
    if installationEpoch ~= nil then return installationEpoch end
    if isServer and isServer() then return -1 end
    local context = (resolver or Context.identity)(vehicle, partId, installedItemId)
    return context and context.installationEpoch or -1
end

function Context.resolve(player, vehicle, partId, installedItemId, installationEpoch)
    if not player or not vehicle or player:getVehicle() ~= vehicle then
        return nil, "outside_host"
    end
    local context, reason = Context.identity(vehicle, partId, installedItemId, installationEpoch)
    if context then context.player = player end
    return context, reason
end

-- Device entries share host/part/item identity and the existing inside policy.
-- Capability is checked after identity; this never grants an installation option.
function Context.equipment(player, vehicle, partId, installedItemId, capability, installationEpoch)
    local context, reason = Context.resolve(player, vehicle, partId,
        installedItemId, installationEpoch)
    if not context then return nil, reason end
    if capability and VLS.getEquipmentCapability(context.item) ~= capability then
        return nil, "wrong_capability"
    end
    return context
end

-- Container access policy remains distinct from installation policy. In
-- particular, removing a support must not prevent recovering existing cargo.
-- Installation allowlists/frame checks remain in VLS.isInstallationEnabled.
function Context.containerAccess(player, vehicle, part)
    if not part then return nil, "invalid_part" end
    local context, reason = Context.resolve(player, vehicle, part:getId())
    if not context then return nil, reason end
    if context.part ~= part or not VLS.isUniversalPart(part) then
        return nil, "invalid_part"
    end
    local storage, metadataReason = VLS.isStorageEquipment(context.item)
    if not storage then
        return nil, metadataReason and "native_metadata_unavailable" or "not_storage"
    end
    return context
end

function Context.token(context)
    if not context or type(context.partId) ~= "string" or context.partId == ""
            or not integer(context.vehicleId)
            or not integer(context.installedItemId)
            or not integer(context.installationEpoch) then return nil end
    return { vehicleId = context.vehicleId, partId = context.partId,
        installedItemId = context.installedItemId, installationEpoch = context.installationEpoch }
end

function Context.restore(player, token)
    if type(token) ~= "table" or not integer(token.vehicleId)
            or not integer(token.installedItemId) or not integer(token.installationEpoch) then
        return nil, "invalid_identity"
    end
    local context, reason = Context.resolve(player, getVehicleById(token.vehicleId),
        token.partId, token.installedItemId, token.installationEpoch)
    if not context then return nil, reason end
    if context.installationEpoch ~= token.installationEpoch then return nil, "installation_changed" end
    return context
end

-- Bind the resource's own installation, not a consumer's cabinet token. This
-- returns the existing owner's real FC and never creates a fluid/container copy.
function Context.fluid(player, vehicle, partId, installedItemId, installationEpoch)
    local context, reason = Context.resolve(player, vehicle, partId,
        installedItemId, installationEpoch)
    if not context then return nil, reason end
    local item, part = VLS.getVehicleFluidItem(vehicle, partId)
    if item ~= context.item or part ~= context.part then return nil, "not_fluid_endpoint" end
    local fluid = item:getFluidContainer()
    if not fluid or fluid:getOwner() ~= item then return nil, "invalid_fluid_owner" end
    context.fluidContainer = fluid
    return context
end

function Context.cabinet(player, vehicle, partId, installedItemId)
    vehicle = vehicle or (player and player:getVehicle())
    if not vehicle then return nil, "outside_host" end
    if not partId then
        local part = VLS.getInstalledGenericCraftSurfacePart(vehicle)
        partId = part and part:getId()
    end
    local context, reason = Context.resolve(player, vehicle, partId, installedItemId)
    if not context then return nil, reason end
    if not VLS.isGenericCraftSurfaceEquipment(context.item) then
        return nil, "not_crafting_surface"
    end
    -- BaseVehicle is the actual native IsoObject accepted by existing VLS.
    -- It supplies mobile spatial identity, not a counterfeit cabinet entity.
    context.surface = vehicle
    return context
end

function Context.storage(context)
    if not context then return nil end
    local current = Context.restore(context.player, Context.token(context))
    return current and current.container or nil
end

function Context.power(context)
    if not context then return nil end
    local current = Context.restore(context.player, Context.token(context))
    return current and VLS.VehiclePower.snapshot(current.vehicle) or nil
end

function Context.water(context)
    if not context then return nil end
    local current = Context.restore(context.player, Context.token(context))
    if not current then return nil end
    -- Return the original FluidContainer. Native fluid actions own transfers.
    local item, part = VLS.getInstalledWaterTank(current.vehicle)
    return item and item:getFluidContainer() or nil, part
end

function Context.installationChanged(vehicle, part)
    if isClient and isClient() then return false end
    if not vehicle or not part or part:getVehicle() ~= vehicle then return false end
    local data = part:getModData()
    local epoch = data.vlsNativeEpoch or 0
    if not integer(epoch) or epoch < 0 or epoch >= 2147483647 then return false end
    data.vlsNativeEpoch = epoch + 1
    vehicle:transmitPartModData(part)
    return true
end

-- This module intentionally does not own a second saved inventory, energy store,
-- water store, entity tick loop or network command. VehiclePart/installed item
-- save and replication remain authoritative. World-appliance hosting is pending.
return Context
