-- Bus-only battery-bank adapter. Consumers, costs, native battery writes and
-- transaction rules remain in VLS.VehiclePower; this layer composes two cells.
local A = require "VLS_KI5F700_Config"
if VLS.F700Power then return VLS.F700Power end
local P = {}; VLS.F700Power = P
local Power = VLS.VehiclePower
local base = {}
for _,name in ipairs({"snapshot","restore","consume","reserve","settle","sync","charge"}) do base[name]=Power[name] end
local scoped = setmetatable({}, {__mode="k"})
local function finite(n) return type(n)=="number" and n==n and n>=0 and n<math.huge end
local function host() return not (isClient and isClient()) end
local function bus(vehicle) return A.isBus(vehicle) and not scoped[vehicle] end
local function withPart(part, fn, ...)
    local vehicle=part:getVehicle()
    local previous=scoped[vehicle];scoped[vehicle]=part
    local ok,value=pcall(fn,...)
    scoped[vehicle]=previous
    if not ok then error(value) end
    return value
end
local getAux=VLS.getAuxBatteryPart
function VLS.getAuxBatteryPart(vehicle)
    local part=scoped[vehicle]
    if part then
        return VLS.getInstalledPart(vehicle,part:getId())==part and part or nil
    end
    return getAux(vehicle)
end
local managed,allowed=VLS.isManagedPart,VLS.isAllowedItem
local function third(part)
    return part and part:getId()==A.battery3Id and A.isBus(part:getVehicle())
end
function VLS.isManagedPart(part)
    return third(part) or managed(part)
end
function VLS.isAllowedItem(part,item)
    if part and part:getId()==A.battery3Id then
        return third(part) and item and VLS.allowedItems[A.battery3Id][item:getFullType()]==true
            and instanceof(item,"DrainableComboItem") or false
    end
    return allowed(part,item)
end
local uninstall=VLS.canUninstallManagedPart
function VLS.canUninstallManagedPart(part)
    if third(part) then
        -- The common battery guard examines the vehicle's active appliances;
        -- use its actual primary auxiliary part to keep exactly that rule.
        return uninstall(part:getVehicle():getPartById(VLS.AUX_BATTERY_PART_ID))
    end
    return uninstall(part)
end
function P.uninstallTest(vehicle,part,character)
    return VLS.canUninstallManagedPart(part) and Vehicles.UninstallTest.Battery(vehicle,part,character)
end

function Power.snapshot(vehicle)
    if not bus(vehicle) then return base.snapshot(vehicle) end
    local state={vehicle=vehicle,charge=0,cells={}}
    for _,id in ipairs(A.busBatteries) do
        local part=VLS.getInstalledPart(vehicle,id)
        if part then
            local cell=withPart(part,base.snapshot,vehicle)
            if cell then
                if not finite(cell.charge) then return nil end
                state.cells[#state.cells+1]=cell
                state.charge=state.charge+cell.charge
                state.part=state.part or part
            end
        end
    end
    return #state.cells>0 and state or nil
end
local function valid(cells)
    for _,cell in ipairs(cells) do
        if VLS.getInstalledPart(cell.vehicle,cell.part:getId())~=cell.part
                or cell.part:getInventoryItem()~=cell.item then return false end
    end
    return true
end
function Power.sync(vehicle,part)
    if not bus(vehicle) then return base.sync(vehicle,part) end
    for _,id in ipairs(A.busBatteries) do
        local cell=vehicle:getPartById(id)
        if cell then base.sync(vehicle,cell) end
    end
end
function Power.restore(state,deferSync)
    if not state or not state.cells then return base.restore(state,deferSync) end
    if not host() or not valid(state.cells) then return false end
    for _,cell in ipairs(state.cells) do
        if not withPart(cell.part,base.restore,cell,true) then return false end
    end
    if not deferSync then Power.sync(state.vehicle) end
    return true
end
function Power.reserve(vehicle,amount)
    if not bus(vehicle) then return base.reserve(vehicle,amount) end
    if not host() or not finite(amount) then return nil end
    if amount==0 then return base.reserve(vehicle,0) end
    local state=Power.snapshot(vehicle)
    if not state or state.charge<amount then return nil end
    local group={vehicle=vehicle,cost=amount,reservations={}}
    local remaining=amount
    local ok,complete=pcall(function()
        for _,cell in ipairs(state.cells) do
            local take=math.min(cell.charge,remaining)
            if take>0 then
                local reservation=withPart(cell.part,base.reserve,vehicle,take)
                if not reservation then return false end
                group.reservations[#group.reservations+1]=reservation
                remaining=remaining-take
            end
        end
        return true
    end)
    if not ok or not complete then
        Power.restore(state,true)
        if not ok then error(complete) end
        return nil
    end
    return group
end
function Power.settle(group,used)
    if not group or not group.reservations then return base.settle(group,used) end
    if not host() or group.settled or not finite(used) or used>group.cost+0.000000001
            or not valid(group.reservations) then return false end
    local remaining=math.min(used,group.cost)
    for _,cell in ipairs(group.reservations) do
        local take=math.min(cell.cost,remaining)
        if not withPart(cell.part,base.settle,cell,take) then return false end
        remaining=remaining-take
    end
    group.settled=true
    return true
end
function Power.consume(vehicle,amount)
    if not bus(vehicle) then return base.consume(vehicle,amount) end
    if not host() or not finite(amount) then return false end
    local state=Power.snapshot(vehicle)
    if not state then return false end
    local take=math.min(state.charge,amount)
    local group=Power.reserve(vehicle,take)
    if not group or not Power.settle(group,take) then
        Power.restore(state,false)
        return false
    end
    Power.sync(vehicle)
    return state.charge>=amount
end
-- Native television DeviceData stores a single normalized charge (0..1).
-- Restrict normalization to that common synchronization call; appliance energy
-- budgets and water transactions still see both batteries' full stored energy.
local televisionSync=VLS.syncTelevisionDevice
local television=setmetatable({}, {__mode="k"})
function Power.charge(vehicle)
    local charge=base.charge(vehicle)
    return television[vehicle] and A.isBus(vehicle) and math.min(1,charge) or charge
end
function VLS.syncTelevisionDevice(vehicle,part,refresh)
    if not A.isBus(vehicle) then return televisionSync(vehicle,part,refresh) end
    local previous=television[vehicle];television[vehicle]=true
    local ok,result=pcall(televisionSync,vehicle,part,refresh)
    television[vehicle]=previous
    if not ok then error(result) end
    return result
end
return P
