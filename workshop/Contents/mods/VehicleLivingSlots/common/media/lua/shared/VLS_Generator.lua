-- Parked building power only. Interior appliances keep their battery circuit.
-- The installed item owns stored fuel/condition; while grounded, the one native
-- IsoGenerator owns running state, fuel use, wear, sound and world electricity.
local VLS = require "VLS_Config"
require "VLS_RoofCargo"
local G = VLS.Generator or {}
VLS.Generator = G
G.PART = "VLSRoofGenerator"
G.MAX_FUEL = 10 -- verified B42.20 IsoGenerator.getMaxFuel(), litres
G.active = G.active or {}
G.grounded = G.grounded or {}
function G.enabled()
    local settings = SandboxVars and SandboxVars.VehicleLivingSlots
    return not settings or settings.EnableRoofGeneratorShortcut ~= false
end
function G.getPart(vehicle)
    if not vehicle or not VLSRoofCargo.vehicleScripts[vehicle:getScript():getFullName()] then return nil end
    local part = vehicle:getPartById(G.PART)
    local item = part and part:getInventoryItem()
    if not item or not VLSRoofCargo.allowed[G.PART][item:getFullType()] then return nil end
    return part, item
end
function G.state(item)
    local md = item:getModData()
    md.vlsGenerator = md.vlsGenerator or {}
    return md.vlsGenerator
end
function G.fuel(item) return math.max(0, math.min(G.MAX_FUEL, tonumber(item:getModData().fuel) or 0)) end
function G.object(vehicle)
    local _, item = G.getPart(vehicle)
    local dock = item and G.state(item).dock
    if not dock then return nil end
    local square = getCell():getGridSquare(dock.x, dock.y, dock.z)
    local objects = square and square:getSpecialObjects()
    if objects then
        for i=0,objects:size()-1 do
            local object = objects:get(i)
            if instanceof(object, "IsoGenerator") and object:getModData().vlsMountedGenerator == item:getID() then
                return object
            end
        end
    end
end
function G.isRunning(vehicle)
    local object=G.object(vehicle)
    return object and object:isActivated() or false
end
function G.sync(vehicle, part, item)
    item:syncItemFields()
    vehicle:transmitPartItem(part)
    vehicle:transmitPartCondition(part)
end
function G.getFuel(vehicle)
    local _,item = G.getPart(vehicle)
    if not item then return 0 end
    local object = G.object(vehicle)
    return object and object:getFuel() or G.fuel(item)
end
function G.hasMoved(vehicle,dock)
    return not vehicle:isStopped() or math.abs(vehicle:getX()-dock.vx)>0.05
        or math.abs(vehicle:getY()-dock.vy)>0.05 or math.floor(vehicle:getZ())~=dock.z
end
-- Use the native vehicle service area so original walkAdj can reach the object.
function G.serviceSquare(vehicle, part)
    local center = vehicle:getAreaCenter(part:getArea())
    if not center then return nil end
    local square = getCell():getGridSquare(math.floor(center:getX()), math.floor(center:getY()), math.floor(vehicle:getZ()))
    return square and square:isFree(false) and square or nil
end
function G.disconnect(vehicle)
    local part,item = G.getPart(vehicle)
    if not item then return false end
    local state,object = G.state(item),G.object(vehicle)
    if object then
        item:getModData().fuel = object:getFuel()
        item:setCondition(object:getCondition())
        part:setCondition(item:getCondition())
        object:setActivated(false) -- native removal of surrounding electricity
        object:setConnected(false)
        object:remove()
        G.grounded[object]=nil
    end
    state.dock=nil
    G.active[vehicle]=nil
    G.sync(vehicle,part,item)
    return true
end
function G.materialize(vehicle, square)
    local part,item=G.getPart(vehicle)
    if not G.enabled() or not item or not vehicle:isStopped() or not square or G.state(item).dock then return false end
    local state=G.state(item)
    -- Native constructor owns world registration, item fuel/condition and range.
    local object=IsoGenerator.new(item,getCell(),square)
    object:getModData().vlsMountedGenerator=item:getID()
    object:setDoRender(false)
    state.dock={x=square:getX(),y=square:getY(),z=square:getZ(),vx=vehicle:getX(),vy=vehicle:getY(),serviceArea=part:getArea()}
    state.lastCondition=item:getCondition()
    object:setConnected(false)
    object:transmitModData()
    object:sync()
    G.active[vehicle]=true
    G.grounded[object]={vehicle=vehicle,item=item}
    G.sync(vehicle,part,item)
    return true
end
function G.update(vehicle)
    local part,item=G.getPart(vehicle)
    if not item or not vehicle:getSquare() then G.active[vehicle]=nil;return end
    local state=G.state(item)
    if not G.enabled() then
        if state.dock then G.disconnect(vehicle) else G.active[vehicle]=nil end
        return
    end
    if not state.dock then
        if vehicle:isStopped() then G.materialize(vehicle, G.serviceSquare(vehicle, part)) end
        return
    end
    if G.hasMoved(vehicle,state.dock) then G.disconnect(vehicle);return end
    local object=G.object(vehicle)
    if object then
        -- Migrate the previous rear projection without losing fuel/condition.
        if state.dock.serviceArea ~= part:getArea() then
            local square = G.serviceSquare(vehicle, part)
            if square then
                local connected, running = object:isConnected(), object:isActivated()
                G.disconnect(vehicle)
                if G.materialize(vehicle, square) then
                    object = G.object(vehicle)
                    object:setConnected(connected)
                    object:setActivated(running and connected)
                    object:sync()
                end
            end
            return
        end
        G.grounded[object]={vehicle=vehicle,item=item}
        local fuel,condition=object:getFuel(),object:getCondition()
        -- Forward vehicle collision damage, but retain native generator repairs.
        if state.lastCondition and item:getCondition()~=state.lastCondition then
            object:setCondition(item:getCondition());condition=object:getCondition()
        end
        local changed=G.fuel(item)~=fuel or item:getCondition()~=condition
        state.lastCondition=condition
        if changed then
            item:getModData().fuel=fuel;item:setCondition(condition);part:setCondition(condition)
            G.sync(vehicle,part,item)
        end
    else
        -- Never recreate a missing world object using a stale fuel snapshot.
        local square=getCell():getGridSquare(state.dock.x,state.dock.y,state.dock.z)
        if square then
            item:getModData().fuel=0
            state.dock=nil;G.sync(vehicle,part,item)
        end
    end
end
return G
