require "VLS_Config"
require "Vehicles/ISUI/ISCarMechanicsOverlay"
require "Vehicles/ISUI/ISVehicleMechanics"

-- Extend the original Build 42 mechanics-overlay registries. The official
-- panel continues to own drawing, condition tinting, flashing, hit testing,
-- tooltips, and part selection.
-- The original schematic does not draw arbitrary interior containers. VLS
-- therefore registers only its two mechanical parts. The masks reuse the
-- matching original battery/tank pixels, with only placement, tank rotation,
-- and short schematic connectors added. The original panel still owns tinting,
-- flashing, hover, and selection for each added part independently.
local PARTS = {
    [VLS.AUX_BATTERY_PART_ID] = {
        img = "vls_aux_battery",
        vehicles = {
            suv_ = { x = 6, y = 281, x2 = 52, y2 = 315 },
            truck_ = { x = 6, y = 281, x2 = 52, y2 = 315 },
            van_ = { x = 6, y = 281, x2 = 52, y2 = 315 },
        },
    },
    [VLS.LARGE_VAN_WATER_TANK_PART_ID] = {
        img = "vls_water_tank",
        vehicles = {
            van_ = { x = 208, y = 264, x2 = 260, y2 = 344 },
        },
    },
}

local GUIDES = {
    [VLS.AUX_BATTERY_PART_ID] = "vls_aux_battery_guide",
    [VLS.LARGE_VAN_WATER_TANK_PART_ID] = "vls_water_tank_guide",
}

local registeredParts = VLS.mechanicsOverlayParts or {}
local registeredGuides = VLS.mechanicsOverlayGuides or {}
VLS.mechanicsOverlayParts = registeredParts
VLS.mechanicsOverlayGuides = registeredGuides

local function applyMechanicsOverlayPart(partId, spec)
    local part = ISCarMechanicsOverlay.PartList[partId] or {}
    part.img = spec.img
    part.vehicles = part.vehicles or {}
    for prefix, coords in pairs(spec.vehicles or {}) do
        part.vehicles[prefix] = coords
    end
    ISCarMechanicsOverlay.PartList[partId] = part
end

function VLS.registerMechanicsOverlay(parts, guides)
    for partId, spec in pairs(parts or {}) do
        registeredParts[partId] = spec
        applyMechanicsOverlayPart(partId, spec)
        if guides and guides[partId] then
            registeredGuides[partId] = {
                image = guides[partId], vehicles = spec.vehicles or {},
            }
        end
    end
end

local function registerVLSMechanicsOverlay()
    for partId, spec in pairs(registeredParts) do
        applyMechanicsOverlayPart(partId, spec)
    end
end

VLS.registerMechanicsOverlay(PARTS, GUIDES)

local function getOverlayProperties(vehicle)
    local overlayName = vehicle:getScriptName()
    if vehicle:getScript():getCarMechanicsOverlay() then
        overlayName = vehicle:getScript():getCarMechanicsOverlay()
    end
    return ISCarMechanicsOverlay.CarList[overlayName]
end

local function drawVLSMechanicsGuides(panel)
    if not panel.vehicle or not VLS.isSupportedVehicle(panel.vehicle) then return end
    local props = getOverlayProperties(panel.vehicle)
    if not props then return end
    for partId, guide in pairs(registeredGuides) do
        if guide.vehicles[props.imgPrefix]
                and panel.vehicle:getPartById(partId) then
            local texture = getTexture(
                "media/ui/vehicles/mechanic overlay/" ..
                props.imgPrefix .. guide.image .. ".png"
            )
            if texture then
                panel:drawTextureScaledUniform(
                    texture, props.x, props.y, 1, 1, 1, 1, 1
                )
            end
        end
    end
end

-- Vanilla has no registry for additional untinted base assemblies. Draw only
-- the VLS static guides first, then delegate once to the complete original
-- renderer. It continues to own the family base, condition tint, flashing,
-- tooltips, hit testing, and selection.
if not VLS.mechanicsOverlayGuideHookApplied then
    VLS.mechanicsOverlayGuideHookApplied = true
    local originalRenderCarOverlay = ISVehicleMechanics.renderCarOverlay
    function ISVehicleMechanics:renderCarOverlay()
        drawVLSMechanicsGuides(self)
        originalRenderCarOverlay(self)
    end
end

if not VLS.mechanicsOverlayEventHookApplied then
    VLS.mechanicsOverlayEventHookApplied = true
    Events.OnGameStart.Add(registerVLSMechanicsOverlay)
end
