require "VLS_ComponentDamage"
require "VLS_InstallGuard"
require "TimedActions/ISFixVehiclePartAction"
local D=VLS.Damage
if not D.mechanicsHooksApplied then
    D.mechanicsHooksApplied=true
    local function wrap(class,field)
        local original=class.complete
        class.complete=function(self)
            local part=self[field]
            local vehicle=part and part:getVehicle()
            local tracked=not isClient() and vehicle and D.supportsVehicle(vehicle) and D.IsSource(part)
            if tracked then D.Update(vehicle) end
            local ok,result=pcall(original,self)
            -- Even a native error after mutation must not turn maintenance
            -- damage into a new collision at the next scheduled update.
            if tracked then D.RebaseSource(part) end
            if not ok then error(result,0) end
            return result
        end
    end
    wrap(ISInstallVehiclePart,"part")
    wrap(ISUninstallVehiclePart,"part")
    wrap(ISFixVehiclePartAction,"vehiclePart")
end
