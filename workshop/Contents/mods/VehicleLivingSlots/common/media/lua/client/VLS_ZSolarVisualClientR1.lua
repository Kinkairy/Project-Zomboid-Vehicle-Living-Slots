local S = require "VLS_ZSolarVisualR1"
require "Vehicles/ISUI/ISVehicleMenu"
require "Vehicles/ISUI/ISVehicleMechanics"

S.solarRadials = S.solarRadials or setmetatable({}, {__mode = "k"})
local function label(part)
    return getText("IGUI_VehiclePartVLSSolarPanel")
end
local function request(character, vehicle, rackId, desired)
    if not S.canShowControl(character, vehicle) then return end
    -- Match native vehicle sleep: a menu opened before movement gets a halo
    -- warning instead of performing the now-invalid operation.
    if not S.isStopped(vehicle) then
        HaloTextHelper.addBadText(character, getText("ContextMenu_VLSPantryPark"))
        return
    end
    if not S.canControl(character, vehicle, desired) then return end
    local part = S.part(vehicle)
    if part:getInventoryItem():getID() ~= rackId then return end
    if isClient() then
        sendClientCommand(character, "VLSSolarVisualR1", "setExpanded", {
            vehicle = vehicle:getId(), rack = rackId, expanded = desired})
    else
        S.setExpanded(character, vehicle, rackId, desired)
    end
end
-- No exterior or fixed-rack mechanics solar controls. Installation lives in Other.
if S.worldHandler then Events.OnFillWorldObjectContextMenu.Remove(S.worldHandler) end
S.worldHandler = nil
if not S.menuHooks then
    S.menuHooks = true
    local radial = ISVehicleMenu.showRadialMenu
    function ISVehicleMenu.showRadialMenu(character)
        local menu = character and getPlayerRadialMenu(character:getPlayerNum())
        if not menu then return radial(character) end
        S.solarRadials[menu] = {character=character, enabled=S.enabled()}
        local raw = rawget(menu, "addToUIManager")
        local add = menu.addToUIManager
        local injected = false
        menu.addToUIManager = function(self, ...)
            if self == menu and not injected then
                injected = true
                local vehicle = character:getVehicle()
                local part = S.part(vehicle)
                if part and S.canShowControl(character, vehicle) and S.enabled() then
                    S.diagnose(vehicle, "radial")
                    local stopped = S.isStopped(vehicle)
                    -- Same addSlice(reason, icon, nil, ...) pattern as native sleep.
                    local record = S.solarRadials[menu]
                    menu:addSlice(stopped and label(part) or getText("ContextMenu_VLSPantryPark"),
                        getTexture("media/ui/VLSSolarVisualR1.png"),
                        stopped and request or nil, character, vehicle,
                        part:getInventoryItem():getID(), not S.expanded(part))
                    record.slice = menu.slices[#menu.slices]
                end
            end
            return add(self, ...)
        end
        local ok, result = pcall(radial, character)
        menu.addToUIManager = raw
        if not ok then error(result, 0) end
        return result
    end
end
if S.tickHandler then Events.OnTick.Remove(S.tickHandler) end
S.tickHandler = function()
    S.refresh()
    local enabled = S.enabled()
    for menu, record in pairs(S.solarRadials) do
        if record.enabled ~= enabled then
            record.enabled = enabled
            if menu:isReallyVisible() then
                -- Rebuild the public native slice arrays, preserving every
                -- unrelated command and joypad focus. Native show toggles shut.
                local slices = {}
                for _, slice in ipairs(menu.slices) do
                    if slice ~= record.slice then table.insert(slices, slice) end
                end
                menu:clear()
                for _, slice in ipairs(slices) do
                    local c = slice.command
                    menu:addSlice(slice.text, slice.texture,c[1],c[2],c[3],c[4],c[5],c[6],c[7])
                end
                record.slice = nil
                local character = record.character
                local vehicle = character:getVehicle()
                local part = S.part(vehicle)
                if enabled and part and S.canShowControl(character,vehicle) then
                    local stopped = S.isStopped(vehicle)
                    menu:addSlice(stopped and label(part) or getText("ContextMenu_VLSPantryPark"),
                        getTexture("media/ui/VLSSolarVisualR1.png"),stopped and request or nil,
                        character,vehicle,part:getInventoryItem():getID(),not S.expanded(part))
                    record.slice = menu.slices[#menu.slices]
                end
            end
        end
    end
end
Events.OnTick.Add(S.tickHandler)
print("[VLS SolarVisual] client solar-visual-r1 READY visual-only")

print("[VLS SolarVisual] client rackfix1 additive-rack/menu READY")

print("[VLS SolarVisual] client " .. tostring(S.BEHAVIOR or S.REVISION)
    .. " READY 25 fixed clips / " .. tostring(S.DURATION_MS) .. "ms")
