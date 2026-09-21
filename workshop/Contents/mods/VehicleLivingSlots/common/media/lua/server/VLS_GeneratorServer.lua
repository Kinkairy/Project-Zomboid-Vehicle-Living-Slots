if isClient() then return end
local G=require "VLS_Generator"
require "VLS_GeneratorOwnership"
local lastScan=0
-- Streaming guard: an IsoObject may still have an object index and square
-- after the square's chunk has already been detached. Removing it in that
-- state calls IsoGridSquare.RemoveTileObject() with square.chunk == nil.
local function objectHasLoadedChunk(object)
    if not object or object:getObjectIndex()==-1 then return false end
    local square=object:getSquare()
    return square~=nil and square:getChunk()~=nil
end
local function scan()
    local cell=getCell()
    local vehicles=cell and cell:getVehicles()
    if not vehicles then return end
    -- B42.20 IsoCell.getVehicles() returns java.util.Set, not a List.
    local iterator=vehicles:iterator()
    while iterator:hasNext() do
        local vehicle=iterator:next()
        local _,item=G.getPart(vehicle)
        if item then G.active[vehicle]=true end
    end
end
-- Defer ownership until vehicles in the cell have loaded. An unresolved saved
-- adapter cannot power the world; an orphan never becomes another inventory item.
local function squareLoaded(square)
    local objects=square:getSpecialObjects()
    for i=objects:size()-1,0,-1 do
        local object=objects:get(i)
        if instanceof(object,"IsoGenerator") and object:getModData().vlsMountedGenerator then
            local data=object:getModData()
            if data.vlsResumeRunning==nil then data.vlsResumeRunning=object:isActivated() end
            object:setActivated(false)
            G.pending=G.pending or {};G.pending[object]=getTimestampMs()
        end
    end
end
local function pendingTick()
    if not G.pending then return end
    local now=getTimestampMs()
    for object,started in pairs(G.pending)do
        if object:getObjectIndex()==-1 then G.pending[object]=nil
        else
            local found=false
            for vehicle in pairs(G.active)do
                local _,item=G.getPart(vehicle)
                if item and G.object(vehicle)==object then
                    found=true
                    local state=G.state(item)
                    local resume=object:getModData().vlsResumeRunning
                    object:getModData().vlsResumeRunning=nil
                    if not G.enabled() or G.hasMoved(vehicle,state.dock) then G.disconnect(vehicle)
                    else
                        object:setActivated(resume==true and object:isConnected() and object:getFuel()>0 and object:getCondition()>0)
                        object:sync();G.update(vehicle)
                    end
                    G.pending[object]=nil;break
                end
            end
            if not found and now-started>5000 then
                if objectHasLoadedChunk(object) then object:remove() end
                G.pending[object]=nil
            end
        end
    end
end
local function tick()
    local stamp=getTimestampMs()
    if stamp<lastScan or stamp-lastScan>=1000 or lastScan==0 then scan();lastScan=stamp end
    for object,lease in pairs(G.grounded)do
        local vehicle=lease and lease.vehicle
        local vehicleSquare=vehicle and vehicle:getSquare()
        if not vehicleSquare then
            -- Normal streaming unload: preserve dock + saved world generator.
            -- Only drop transient runtime references; LoadGridsquare reacquires it.
            G.grounded[object]=nil
            if vehicle then G.active[vehicle]=nil end
        else
            local _,item=G.getPart(vehicle)
            if item~=lease.item then
                lease.item:getModData().fuel=object:getFuel()
                lease.item:setCondition(object:getCondition())
                G.state(lease.item).dock=nil
                if objectHasLoadedChunk(object) then
                    object:setActivated(false);object:setConnected(false);object:remove()
                end
                lease.item:syncItemFields()
                G.grounded[object]=nil
            elseif not objectHasLoadedChunk(object) then
                -- The generator square is already leaving the engine. Calling
                -- remove() here can reach PathfindNative with square.chunk == nil.
                G.grounded[object]=nil
            end
        end
    end
    pendingTick()
    for vehicle in pairs(G.active)do G.update(vehicle)end
end
if VLS.generatorServerTick then Events.OnTick.Remove(VLS.generatorServerTick) end
if VLS.generatorSquareLoaded then Events.LoadGridsquare.Remove(VLS.generatorSquareLoaded) end
VLS.generatorServerTick,VLS.generatorSquareLoaded=tick,squareLoaded
Events.OnTick.Add(tick)
Events.LoadGridsquare.Add(squareLoaded)
