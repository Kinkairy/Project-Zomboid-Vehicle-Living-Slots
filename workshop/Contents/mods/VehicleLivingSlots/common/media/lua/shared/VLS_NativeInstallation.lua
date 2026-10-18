-- Installation policy only. Native vehicle actions own time, skills, success,
-- inventory movement and callbacks. Accessing existing equipment is a separate policy.
local Context = require "VLS_NativeContext"
local Installation = {}
function Installation.bind(VLS)
    local policy = {}
    function policy.canInstall(part, item)
        if not VLS.isInstallationEnabled(part, item) then return false end
        local allowed = part and VLS.allowedItems[part:getId()]
        return not allowed or VLS.isAllowedItem(part, item) and true or false
    end
    function policy.canUninstall(part)
        return VLS.canUninstallManagedPart(part)
    end
    -- Observe successful original transactions, never replace their eligibility.
    function policy.captureIdentity(part)
        if not part then return nil end
        local tracked = VLS.isManagedPart and VLS.isManagedPart(part)
            or VLS.isPropaneTankPart and VLS.isPropaneTankPart(part)
        local id = part:getId()
        if not tracked and VLSRoofCargo and VLSRoofCargo.vehicleScripts
                and id:match("^VLSRoofPetrol[123]$") then
            local vehicle = part:getVehicle()
            local script = vehicle and vehicle:getScript()
            tracked = script and VLSRoofCargo.vehicleScripts[script:getFullName()]
        end
        if not tracked then
            -- Resolve registered roof endpoints even while they are empty. KI5
            -- retains its original part IDs; observe both native uninstall and
            -- reinstall through the same shared generation boundary.
            local fuel = VLS.RoofFuel
            if fuel and fuel.resolvePart then
                for index = 1, 3 do
                    if fuel.resolvePart(part:getVehicle(), "VLSRoofPetrol"..index) == part then
                        tracked = true
                        break
                    end
                end
            end
        end
        if not tracked then return nil end
        return {vehicle=part:getVehicle(), item=part:getInventoryItem(),
            epoch=part:getModData().vlsNativeEpoch or 0}
    end
    function policy.finishIdentity(part, before)
        if not before or part:getVehicle() ~= before.vehicle
                or part:getInventoryItem() == before.item then return end
        -- Existing managed-part callbacks already bump their epoch. Do not
        -- double count them or overwrite another callback's identity change.
        if (part:getModData().vlsNativeEpoch or 0) == before.epoch then
            Context.installationChanged(before.vehicle, part)
        end
    end
    function policy.observeCompletion(action, nativeComplete)
        local before = policy.captureIdentity(action.part)
        local ok, result = pcall(nativeComplete, action)
        -- Native completion may commit the authoritative part/inventory change
        -- before a callback or notification throws. Reconcile on both paths.
        local observed, observationError = pcall(policy.finishIdentity, action.part, before)
        -- Never replace an original transaction error with an observer failure.
        if not ok then error(result, 0) end
        if not observed then error(observationError, 0) end
        return result
    end
    VLS.NativeInstallation = policy
    return policy
end
return Installation
