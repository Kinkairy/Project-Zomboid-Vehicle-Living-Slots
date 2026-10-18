-- Read native furniture metadata using the engine's own sprite/container creation.
-- This detached object is a metadata probe only: never a world device, network
-- action target, cargo owner, tick/update participant or serialized entity.
local Definition = {}
local cache, failures, zeroObservedAt = {}, {}, {}
local FAILURE_RETRY_MS = 5000
local function clockMs()
    local now = getTimestampMs and getTimestampMs()
    if type(now) == "number" and now == now and now ~= math.huge
            and now ~= -math.huge then return now end
end
local function fail(spriteName, reason)
    failures[spriteName] = { reason = reason, observedAt = clockMs() }
    return nil, reason
end

function Definition.furniture(item)
    if not item or not instanceof(item, "Moveable") then return nil, "not_moveable" end
    local spriteName = item:getWorldSprite()
    if not spriteName or spriteName == "" then return nil, "missing_native_sprite" end
    local cached = cache[spriteName]
    if cached then
        if cached.containerCount ~= 0 then return cached end
        -- Zero storage can be a real table or temporarily incomplete metadata.
        -- Reuse the existing retry bound so early probes cannot freeze a cabinet
        -- at zero capacity after its registered sprite properties become ready.
        local now, observed = clockMs(), zeroObservedAt[spriteName]
        if not now or (observed and now >= observed
                and now - observed < FAILURE_RETRY_MS) then return cached end
        cache[spriteName], zeroObservedAt[spriteName] = nil, nil
    end
    local failure = failures[spriteName]
    if failure then
        local now = clockMs()
        -- Bound failed probes, but recover when sprite definitions become ready.
        -- A backwards clock also permits retry. No usable clock requires an
        -- explicit clearCache (or clock recovery), never an allocation loop each UI tick.
        if not now or (failure.observedAt and now >= failure.observedAt
                and now - failure.observedAt < FAILURE_RETRY_MS) then
            return nil, failure.reason
        end
        failures[spriteName] = nil
    end
    if not IsoObject or not IsoObject.new then return nil, "native_constructor_unavailable" end
    local ok, result, reason = pcall(function()
        if not getSprite then return nil, "native_sprite_lookup_unavailable" end
        local sprite = getSprite(spriteName)
        if not sprite then return nil, "native_sprite_unavailable" end
        local object = IsoObject.new()
        -- The String overload creates a sprite without the registered tile
        -- properties in the tested 42.21 engine. Pass the registered IsoSprite.
        object:setSprite(sprite)
        if not object:getSprite() then return nil, "native_sprite_unavailable" end
        -- Shipped 42.21 placeMoveableInternal uses this native method (L2486).
        object:createContainersFromSpriteProperties()
        local count = object:getContainerCount()
        if type(count) ~= "number" or count < 0 or count == math.huge
                or count ~= math.floor(count) then
            return nil, "invalid_native_container_count"
        end
        if count > 1 then return nil, "requires_multi_container_host" end
        local surface = object:isGenericCraftingSurface()
        if count == 0 then
            if not surface then return nil, "native_sprite_has_no_container" end
            return { nativeDefinition = true, capability = "storage",
                genericCraftSurface = true, capacity = 0, containerCount = 0,
                sourceSprite = spriteName }
        end
        local container = object:getContainerByIndex(0)
        local capacity = container and container:getCapacity()
        if type(capacity) ~= "number" or capacity ~= capacity or capacity < 0
                or capacity == math.huge then return nil, "invalid_native_capacity" end
        local containerType = container:getType()
        if type(containerType) ~= "string" or containerType == "" then
            return nil, "invalid_native_container_type"
        end
        return {
            nativeDefinition = true, capability = "storage",
            genericCraftSurface = surface, containerCount = 1,
            capacity = capacity, containerType = containerType,
            containerOpenSound = container:getOpenSound(),
            containerCloseSound = container:getCloseSound(),
            containerPutSound = container:getPutSound(),
            containerTakeSound = container:getTakeSound(),
            sourceSprite = spriteName,
        }
    end)
    if not ok then
        return fail(spriteName, "native_definition_probe_failed")
    end
    if not result then
        return fail(spriteName, reason)
    end
    cache[spriteName] = result
    if result.containerCount == 0 then zeroObservedAt[spriteName] = clockMs() end
    return result
end

-- Storage still requires exactly one real native container. A plain table
-- may provide a crafting surface without gaining storage. Both use one probe/cache.
function Definition.singleContainer(item)
    local definition, reason = Definition.furniture(item)
    if definition and definition.containerCount == 0 then
        return nil, "native_sprite_has_no_container"
    end
    return definition, reason
end

-- Compatibility entry for the accepted R1/R2 cabinet path; one implementation/cache.
Definition.cabinet = Definition.singleContainer

function Definition.clearCache() cache, failures, zeroObservedAt = {}, {}, {} end
return Definition
