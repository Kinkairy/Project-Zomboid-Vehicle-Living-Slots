local A = require "VLS_KI5F700_Config"
local F = require "VLS_RoofFuel"
local G = require "VLS_Generator"
require "Vehicles/TimedActions/ISUninstallVehiclePart"
if VLS.F700Roof then return VLS.F700Roof end
local R = {}; VLS.F700Roof = R
-- Map the original KI5 parts to the existing service endpoints. Fuel, timed
-- actions, generator ownership and synchronization remain owned by the core.
local petrol = {VLSRoofPetrol1="DAMNGasCanOne", VLSRoofPetrol2="DAMNGasCanTwo"}
local baseFuel,baseGenerator = F.getPart,G.getPart
function F.getPart(vehicle,id)
    if not A.isBus(vehicle) then return baseFuel(vehicle,id) end
    local part=petrol[id] and vehicle:getPartById(petrol[id])
    local item=part and part:getInventoryItem()
    if item and (item:getFullType()=="Base.PetrolCan" or item:getFullType()=="Base.JerryCan")
            and item:getFluidContainer() then return part,item,item:getFluidContainer() end
end
function G.getPart(vehicle)
    if not A.isBus(vehicle) then return baseGenerator(vehicle) end
    local part=vehicle:getPartById("DAMNGenerator")
    local item=part and part:getInventoryItem()
    if item and VLSRoofCargo.allowed[G.PART][item:getFullType()] then return part,item end
end
function R.isGenerator(part)
    return part and part:getId()=="DAMNGenerator" and A.isBus(part:getVehicle())
end
function R.canRemove(vehicle,part)
    if not R.isGenerator(part) or part:getVehicle()~=vehicle or not part:getInventoryItem() then return false end
    local state=part:getInventoryItem():getModData().vlsGenerator
    if state and state.dock then
        local object=G.object(vehicle)
        if not object or object:isConnected() or object:isActivated() then return false end
    end
    return true
end
function R.uninstallTest(vehicle,part,chr)
    return R.canRemove(vehicle,part) and Vehicles.UninstallTest.Default(vehicle,part,chr)
end
-- The native action clears the item before its completion callback. Release
-- the common generator object while the same original item is still mounted.
local complete=ISUninstallVehiclePart.complete
function ISUninstallVehiclePart:complete()
    if R.isGenerator(self.part) then
        if not R.canRemove(self.vehicle,self.part) then return false end
        if not G.disconnect(self.vehicle) then return false end
    end
    return complete(self)
end
return R
