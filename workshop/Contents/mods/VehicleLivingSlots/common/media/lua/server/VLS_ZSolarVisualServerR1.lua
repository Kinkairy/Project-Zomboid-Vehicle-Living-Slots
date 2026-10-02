if isClient() then return end
local S = require "VLS_ZSolarVisualR1"
local function integer(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
        and value == math.floor(value)
end
local function command(module, name, character, args)
    if module ~= "VLSSolarVisualR1" or name ~= "setExpanded" then return end
    if type(args) ~= "table" or not integer(args.vehicle) or not integer(args.rack)
            or type(args.expanded) ~= "boolean" then return end
    local vehicle = getVehicleById(args.vehicle)
    if vehicle then S.setExpanded(character, vehicle, args.rack, args.expanded) end
end
if S.commandHandler then Events.OnClientCommand.Remove(S.commandHandler) end
S.commandHandler = command
Events.OnClientCommand.Add(command)
print("[VLS SolarVisual] server solar-visual-r1 READY visual-only")

print("[VLS SolarVisual] server rackfix1 additive-rack/menu READY")

-- Keep authoritative visual membership consistent with rack installation.
-- No per-pose packets: the existing expanded/item-ID command remains unchanged.
if S.authorityTickHandler then Events.OnTick.Remove(S.authorityTickHandler) end
S.authorityTickHandler = S.refreshAuthority
Events.OnTick.Add(S.authorityTickHandler)
print("[VLS SolarVisual] server persistent-r3 logical-model sync READY")
