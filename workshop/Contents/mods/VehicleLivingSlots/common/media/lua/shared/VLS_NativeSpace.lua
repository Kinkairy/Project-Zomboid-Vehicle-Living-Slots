-- Shared living/top space boundary. The space rule itself lives only in
-- tools/generate_space_catalog.py; this module reads its generated catalog.
-- Installation is the only place a space is enforced: equipment already in a
-- slot keeps being recognised, used and removable wherever it was installed.
local Catalog = require "VLS_SpaceCatalog"

local Space = { LIVING = "living", TOP = "top" }

function Space.ofType(fullType)
    local entry = fullType and Catalog.furniture[fullType]
    if entry then return entry.space end
    return fullType and Catalog.spaces[fullType] or nil
end

local LAUNDRY_MODES = {
    both = { "laundryWasher", "laundryDryer" },
    washer = { "laundryWasher" },
    dryer = { "laundryDryer" },
}

-- Appliance profile from the vanilla tile data; the shared executor of its
-- capability runs it. Laundry machines share the combo machine's sounds.
local function applianceProfile(VLS, entry)
    local sounds = entry.sounds or {}
    if entry.capability == "laundryCombo" and not entry.sounds then
        local combo = VLS.equipmentProfiles["Base.Mov_BlueComboWasherDryer"]
        sounds = { open = combo.containerOpenSound, close = combo.containerCloseSound,
            put = combo.containerPutSound, take = combo.containerTakeSound }
    end
    return {
        capability = entry.capability, capacity = entry.capacity,
        containerType = entry.container,
        containerOpenSound = sounds.open, containerCloseSound = sounds.close,
        containerPutSound = sounds.put, containerTakeSound = sounds.take,
        -- Sounds the vanilla tile does not name stay unset, as on the tile.
        -- (The game's Kahlua environment has no global next().)
        nativeDefinition = not (sounds.open or sounds.close or sounds.put or sounds.take) or nil,
        freezerCapacity = entry.freezer, freezerOnly = entry.freezerOnly or nil,
        laundryModes = entry.laundry and LAUNDRY_MODES[entry.laundry] or nil,
        cookingWindow = entry.window,
        previewSprite = entry.sprites[1], moveableName = entry.name,
    }
end

function Space.bind(VLS)
    -- Newly supported vanilla furniture. Storage and crafting surfaces come
    -- from the original furniture definition; appliances from its tile data.
    for fullType, entry in pairs(Catalog.furniture) do
        if not VLS.equipmentProfiles[fullType] then
            VLS.equipmentProfiles[fullType] = entry.capability and applianceProfile(VLS, entry) or {
                capability = "storage", native = true,
                genericCraftSurface = entry.surface or nil,
                overhead = entry.space == Space.TOP or nil,
                previewSprite = entry.sprites[1], moveableName = entry.name,
            }
        end
        for _, sprite in ipairs(entry.sprites) do
            if not VLS.supportedMoveableSprites[sprite] then
                VLS.supportedMoveableSprites[sprite] = fullType
            end
        end
    end

    function Space.ofItem(itemOrType)
        if type(itemOrType) == "string" then return Space.ofType(itemOrType) end
        return itemOrType and Space.ofType(VLS.resolveEquipmentType(itemOrType)) or nil
    end

    function Space.ofPart(part)
        if not part then return nil end
        if VLS.isOverheadPart(part) then return Space.TOP end
        local profile = VLS.getVehicleProfile(part:getVehicle())
        for _, id in ipairs(profile and profile.universalParts or {}) do
            if part:getId() == id then return Space.LIVING end
        end
        return nil
    end

    -- Unclassified equipment (beds, water dispenser, batteries) keeps its slots.
    function Space.allows(part, itemOrType)
        local slot = Space.ofPart(part)
        local item = Space.ofItem(itemOrType)
        return slot == nil or item == nil or slot == item
    end

    -- Every equipment slot of a vehicle: living slots first, then top slots.
    function Space.equipmentPartIds(vehicle)
        local profile = VLS.getVehicleProfile(vehicle)
        local ids = {}
        for _, id in ipairs(profile and profile.universalParts or {}) do ids[#ids + 1] = id end
        for _, id in ipairs(profile and profile.overheadParts or {}) do ids[#ids + 1] = id end
        return ids
    end

    -- Recognition (not installation) lists for every living and top slot.
    function Space.allow(livingIds, topIds)
        for fullType, profile in pairs(VLS.equipmentProfiles) do
            local space = Space.ofType(fullType)
            local ids = space == Space.TOP and topIds or space == Space.LIVING and livingIds
            if ids and profile.capability ~= "weaponStorage" then
                for _, id in ipairs(ids) do
                    VLS.allowedItems[id] = VLS.allowedItems[id] or {}
                    VLS.allowedItems[id][fullType] = true
                end
            end
        end
    end

    VLS.NativeSpace = Space
    return Space
end

return Space
