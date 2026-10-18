-- VLS-312-PARKED-CABIN-20261018: withdrawn; only remove old test curtains.
-- Concealment is TODO. Never change player invisibility or create new barriers.
local VLS = require "VLS_Config"
local C = VLS.NativeCabinOcclusion or { edges = {} }
VLS.NativeCabinOcclusion = C

-- A native reload must stop callbacks from the already-loaded failed candidate.
if Events then
    local function off(name, callback)
        if callback and Events[name] then Events[name].Remove(callback) end
    end
    off("OnTick", C.tick)
    off("OnObjectAdded", C.hide)
    off("LoadGridsquare", C.loadSquare)
    off("OnSave", C.clear)
    off("OnGameExit", C.clear)
end
C.failed = true -- Also stops a previously captured C.tick reference.
C.disabled = true
C.edges = C.edges or {}
C.plan, C.createCurtain, C.update, C.tick, C.hide = nil, nil, nil, nil, nil

local marker = "vlsParkedCabinOcclusion"
function C.loadSquare(square)
    if isClient() or not square or not square:getChunk() then return 0 end
    local removed = 0
    local objects = square:getSpecialObjects()
    for i = objects:size() - 1, 0, -1 do
        local object = objects:get(i)
        if object:hasModData() and object:getModData()[marker] == true
                and object:getObjectIndex() >= 0 then
            square:transmitRemoveItemFromSquare(object)
            removed = removed + 1
        end
    end
    return removed
end

function C.clear()
    local removed = 0
    for id, entry in pairs(C.edges) do
        removed = removed + C.loadSquare(entry.square)
        C.edges[id] = nil
    end
    return removed
end

local removed = C.clear()
-- Saved objects in unloaded chunks are cleaned when their square loads.
-- Clients receive the ordinary server removal packet; they never remove maps.
if not isClient() and Events and Events.LoadGridsquare then
    Events.LoadGridsquare.Add(C.loadSquare)
end
print("[VLS cabin withdrawal] disabled=true removed=" .. removed)
return C
