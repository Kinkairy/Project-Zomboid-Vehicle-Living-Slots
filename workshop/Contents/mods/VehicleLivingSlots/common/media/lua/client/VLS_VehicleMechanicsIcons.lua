require "VLS_Config"
require "Vehicles/ISUI/ISVehicleMechanics"
require "Vehicles/ISUI/ISVehiclePartMenu"

local previewTextures = {}
VLS.mechanicsUIProviders = VLS.mechanicsUIProviders or {}
function VLS.registerMechanicsUIProvider(id, provider)
    VLS.mechanicsUIProviders[id] = provider
    VLS.mechanicsDisplayProviders[id] = provider.matches
end
local function providerFor(part)
    for _, provider in pairs(VLS.mechanicsUIProviders) do
        if provider.matches(part) then return provider end
    end
end
function VLS.getMechanicsItemName(part, item)
    local provider = providerFor(part)
    if provider and provider.itemName then return provider.itemName(part, item) end
    return VLS.getEquipmentDisplayName(item)
end
function VLS.getMechanicsPartName(part)
    local provider = providerFor(part)
    if provider and provider.name then return provider.name(part) end
    if VLS.isUniversalPart(part) then
        return VLS.getPartDisplayName(part)
    end
    return getText("IGUI_VehiclePart" .. part:getId())
end
local function hidden(part)
    if VLS.isTopFramePart and VLS.isTopFramePart(part) then
        local index=part:getId():match("([1-3])$")
        local cupboard=part:getVehicle():getPartById(VLS.OVERHEAD_PART_IDS[tonumber(index)])
        -- Keep an occupied old test cupboard reachable; no automatic item loss.
        return VLS.hasTopFrame(cupboard) or (cupboard and cupboard:getInventoryItem()~=nil) or false
    end
    if VLS.isOverheadPart and VLS.isOverheadPart(part) then
        return not part:getInventoryItem() and not VLS.hasTopFrame(part)
    end
    local provider = providerFor(part)
    return provider and provider.hidden and provider.hidden(part) or false
end
local function remaining(part)
    local item = part:getInventoryItem()
    if not item then return nil end
    local provider = providerFor(part)
    if provider and provider.remaining then return provider.remaining(part) end
    if part:getId() == VLS.AUX_BATTERY_PART_ID then
        return item:getCurrentUsesFloat()
    elseif VLS.isWaterTankPart(part) then
        local capacity = part:getContainerCapacity()
        return capacity > 0 and part:getContainerContentAmount()/capacity or 0
    elseif VLS.getEquipmentCapability(item) == "waterDispenser" then
        local fluid = item:getFluidContainer()
        return fluid and fluid:getCapacity() > 0 and fluid:getAmount()/fluid:getCapacity() or 0
    end
end

local function getCanonicalCandidates(typeToItem, itemType)
    local candidates = {}
    local seen = {}

    local function addCandidate(item)
        if not item or seen[item] then return end
        if VLS.resolveEquipmentType(item) ~= itemType then return end
        seen[item] = true
        table.insert(candidates, item)
    end

    for _, item in ipairs(typeToItem[itemType] or {}) do
        addCandidate(item)
    end
    for _, items in pairs(typeToItem) do
        for _, item in ipairs(items) do addCandidate(item) end
    end
    return candidates
end

local function addInstallCandidate(mechanics, part, itemMenu, itemType, candidate)
    local condition = VLS.getItemConditionPercent(candidate)
    local name = VLS.getMechanicsItemName(part, candidate)
    if condition then name = name .. " (" .. condition .. "%)" end
    local itemOption = itemMenu:addOption(name, mechanics.chr,
        ISVehiclePartMenu.onInstallPart, part, candidate)
    itemOption.itemForTexture = candidate
    mechanics:doMenuTooltip(part, itemOption, "install", itemType)
end

local function attachCanonicalCandidates(mechanics, part, installMenu, typeToItem,
        itemType, option)
    if not option then return nil end
    local candidates = getCanonicalCandidates(typeToItem, itemType)
    if #candidates == 0 then return nil end

    option.notAvailable = false
    local itemMenu = option.subOption
        and mechanics.context:getSubMenu(option.subOption) or nil
    local vanillaCandidates = typeToItem[itemType] or {}
    local alreadyAdded = {}
    for _, item in ipairs(vanillaCandidates) do alreadyAdded[item] = true end

    if not itemMenu then
        itemMenu = ISContextMenu:getNew(installMenu)
        installMenu:addSubMenu(option, itemMenu)
        alreadyAdded = {}
    end

    for _, candidate in ipairs(candidates) do
        if not alreadyAdded[candidate] then
            addInstallCandidate(mechanics, part, itemMenu, itemType, candidate)
        end
    end
    return candidates
end

-- The native tooltip only counts literal/script types. Canonical moveables
-- added to the menu above must use the same resolver in the requirement line.
-- Keep the native tool/recipe/key/skill/success tooltip unchanged. Do not mutate
-- VehicleUtils.getItems, inventory objects, item types, sprites or ModData.
if not VLS.smallChestTooltipHookApplied then
    VLS.smallChestTooltipHookApplied = true
    local originalTooltip = ISVehicleMechanics.doMenuTooltip
    function ISVehicleMechanics:doMenuTooltip(part, option, operation, itemType)
        local roof = VLSRoofCargo
        local overhead = VLS.isOverheadPart and VLS.isOverheadPart(part)
            and VLS.getEquipmentProfileByType(itemType)
        local chest = itemType == "Base.Mov_SmallChest"
            and part and part:getId() == "VLSRoofSmallChest"
            and roof and roof.isPart(part)
        if operation ~= "install" or not (chest or (overhead and overhead.overhead)) then
            return originalTooltip(self, part, option, operation, itemType)
        end
        -- nil omits only the native item's own 0/1 line, not tool requirements.
        local result = originalTooltip(self, part, option, operation, nil)
        local tooltip = option and option.toolTip
        if tooltip and tooltip.description then
            local typeToItem = VehicleUtils.getItems(self.playerNum)
            local available = #getCanonicalCandidates(typeToItem, itemType) > 0
            local line = " " .. (available and ISVehicleMechanics.ghs or ISVehicleMechanics.bhs)
                .. (overhead and Translator.getMoveableDisplayName(overhead.moveableName)
                    or getItemDisplayName(itemType)) .. (available and " 1/1" or " 0/1") .. " <LINE>"
            local header = getText("Tooltip_craft_Needs") .. " : <LINE>"
            if tooltip.description:sub(1, #header) == header then
                tooltip.description = header .. line .. tooltip.description:sub(#header + 1)
            else
                tooltip.description = tooltip.description .. line
            end
        end
        return result
    end
    print("[VLS chest-r1] four-orientation small chest menu/tooltip adapter loaded")
end

local function getPreviewTexture(itemType)
    if previewTextures[itemType] then return previewTextures[itemType] end

    local profile = VLS.getEquipmentProfileByType(itemType)
    local sprite = profile and profile.previewSprite or nil
    local ok, texture = false, nil
    if sprite then
        ok, texture = pcall(function()
            local worldTexture = getTexture(sprite)
            return worldTexture and worldTexture:splitIcon() or nil
        end)
    end
    if ok and texture then
        previewTextures[itemType] = texture
        return texture
    end

    return nil
end

VLS.getMechanicsPreviewTexture = getPreviewTexture

local function applyFurnitureIcons(mechanics, part)
    if not mechanics or not mechanics.context or not VLS.usesNormalizedPartCondition(part)
            or part:getInventoryItem() or not part:getItemType() then
        return
    end

    local installOption = mechanics.context:getOptionFromName(getText("IGUI_Install"))
    if not installOption or not installOption.subOption then return end

    local installMenu = mechanics.context:getSubMenu(installOption.subOption)
    if not installMenu then return end

    local typeToItem = VehicleUtils.getItems(mechanics.playerNum)
    for i = 0, part:getItemType():size() - 1 do
        local itemType = part:getItemType():get(i)
        local option = installMenu.options[i + 1]
        local candidates = attachCanonicalCandidates(mechanics, part, installMenu,
            typeToItem, itemType, option) or typeToItem[itemType]
        local iconItem = candidates and candidates[1] or nil
        local profile = VLS.getEquipmentProfileByType(itemType)
        if option and profile and profile.moveableName then
            option.name = Translator.getMoveableDisplayName(profile.moveableName)
        end
        if option and profile and profile.capability == "laundryCombo" then
            option.name = getItemNameFromFullType("Base.Mov_BlueComboWasherDryer")
        end
        if option and profile and profile.previewSprite then
            local texture = getPreviewTexture(itemType)
            if texture then
                option.itemForTexture = nil
                option.iconTexture = texture
            elseif iconItem then
                option.iconTexture = nil
                option.itemForTexture = iconItem
            end
        elseif option and iconItem then
            option.iconTexture = nil
            option.itemForTexture = iconItem
        end
        -- These moveables have a default inventory icon. Keep their native
        -- install candidates and callbacks, but draw the known world preview
        -- in each item submenu as well as the parent row.
        if option and (itemType == "Base.Mov_TrailerFridge"
                or (profile and profile.capability == "laundryCombo")) then
            local texture = getPreviewTexture(itemType)
            local itemMenu = option.subOption
                and mechanics.context:getSubMenu(option.subOption) or nil
            if texture and itemMenu then
                for _, itemOption in ipairs(itemMenu.options or {}) do
                    if itemOption.itemForTexture and VLS.resolveEquipmentType(
                            itemOption.itemForTexture) == itemType then
                        itemOption.iconTexture = texture
                    end
                end
            end
        end
        if option and not VLS.isInstallationEnabled(part, itemType) then
            option.notAvailable = true
        end

    end

end
local function normalizeMenu(mechanics, part, menu)
    if not menu then return end
    for _, option in ipairs(menu.options or {}) do
        local item = option.itemForTexture
        if item then
            local name = VLS.getMechanicsItemName(part, item)
            local condition = VLS.getItemConditionPercent(item)
            option.name = condition and (name.." ("..condition.."%)") or name
            if not part:getInventoryItem() and not VLS.isInstallationEnabled(part, item) then
                option.notAvailable = true
            end
        end
        if option.subOption then
            normalizeMenu(mechanics, part, mechanics.context:getSubMenu(option.subOption))
        end
    end
end

-- A cached read-only view supplies display values to the ORIGINAL renderer.
-- Never pass the view to Java APIs, actions, selection or networking.
local function displayPart(part)
    if VLS.isOverheadPart(part) and not part:getInventoryItem() then
        local frame=VLS.getTopFramePart(part)
        if frame and frame:getInventoryItem() then return frame end
    end
    return part
end
local function displayRow(row, part)
    local view = row.vlsMechanicsDisplayRow
    if not view or view.realPart ~= part then
        local proxy = {getCondition=function() return VLS.getDisplayPartCondition(part) end,
            getInventoryItem=function() return part:getInventoryItem() end}
        setmetatable(proxy, {__index=function(t,key)
            local value=part[key]
            if type(value)=="function" then
                local bound=function(_,...) return value(part,...) end
                rawset(t,key,bound);return bound
            end
            return value
        end})
        view=setmetatable({item=setmetatable({part=proxy},{__index=row.item}),realPart=part},{__index=row})
        row.vlsMechanicsDisplayRow=view
    end
    local name=VLS.getMechanicsPartName(part)
    local fraction=remaining(part)
    if fraction then
        name=name..": "..math.floor(fraction*100).."% "..getText("IGUI_invpanel_Remaining")
    end
    view.item.name=name
    return view
end
-- The renderer uses row.itemindex; input uses list.items[list.selected].
-- Reindex after filtering and retain the selected ROW, never its stale number.
local function refreshListRows(panel, list, savedField)
    if not list or not list.items then return end
    -- Retain the native row for both halves of each top position. Only one is
    -- visible; installation/removal must be able to restore its paired row.
    local topRows = list.vlsTopRows or {}
    list.vlsTopRows = topRows
    local present = {}
    for _, row in ipairs(list.items) do
        local part = row.item and row.item.part
        if part then
            present[part:getId()] = true
            if VLS.isTopFramePart(part) or VLS.isOverheadPart(part) then
                topRows[part:getId()] = row
            end
        end
    end
    local selected = list.items[list.selected or -1]
    local hovered = list.items[list.mouseoverselected or -1]
    local saved = list.items[panel[savedField] or -1]
    for i = #list.items, 1, -1 do
        local row = list.items[i]
        local part = row.item and row.item.part
        if part and (VLS.usesNormalizedPartCondition(part)
                or (VLS.isTopFramePart and VLS.isTopFramePart(part))) then
            if hidden(part) then
                local pairedId
                if VLS.isTopFramePart(part) then
                    pairedId = VLS.OVERHEAD_PART_IDS[tonumber(part:getId():match("([1-3])$"))]
                elseif VLS.isOverheadPart(part) then
                    pairedId = "VLSTopFrame" .. VLS.getOverheadIndex(part)
                end
                local paired = pairedId and topRows[pairedId]
                if paired and not present[pairedId] and not hidden(paired.item.part) then
                    -- Swap native rows in place, retaining this slot's position
                    -- and selection. No full panel rebuild on each update.
                    list.items[i] = paired
                    paired.item.name = VLS.getMechanicsPartName(paired.item.part)
                    present[pairedId] = true
                    if selected == row then selected = paired end
                    if hovered == row then hovered = paired end
                    if saved == row then saved = paired end
                else
                    list:removeItemByIndex(i)
                end
                present[part:getId()] = nil
            else row.item.name = VLS.getMechanicsPartName(part) end
        end
    end
    local selectionIndex, hoverIndex, savedIndex = -1, -1, -1
    for i, row in ipairs(list.items) do
        row.itemindex, row.index = i, i
        if row == selected then selectionIndex = i end
        if row == hovered then hoverIndex = i end
        if row == saved then savedIndex = i end
    end
    list.count = #list.items
    if selected then list.selected = selectionIndex
    elseif (list.selected or -1) > #list.items then list.selected = -1 end
    if hovered then list.mouseoverselected = hoverIndex end
    if saved then panel[savedField] = savedIndex
    elseif (panel[savedField] or -1) > #list.items then panel[savedField] = -1 end
end

local function refreshRows(panel)
    refreshListRows(panel, panel.listbox, "leftListSelection")
    refreshListRows(panel, panel.bodyworklist, "rightListSelection")
end

if not VLS.mechanicsIconHookApplied then
    VLS.mechanicsIconHookApplied=true
    local original=ISVehicleMechanics.doPartContextMenu
    function ISVehicleMechanics:doPartContextMenu(part,...)
        local provider=part and providerFor(part)
        if provider and provider.prepare then provider.prepare(part) end
        local result=original(self,part,...)
        if part and (VLS.usesNormalizedPartCondition(part)
                or (VLS.isTopFramePart and VLS.isTopFramePart(part))) then
            applyFurnitureIcons(self,part)
            normalizeMenu(self,part,self.context)
        end
        return result
    end
end
if not VLS.mechanicsDisplayHookApplied then
    VLS.mechanicsDisplayHookApplied=true
    local draw=ISVehicleMechanics.doDrawItem
    function ISVehicleMechanics:doDrawItem(y,row,alt)
        local part=row and row.item and row.item.part
        if part and (VLS.usesNormalizedPartCondition(part)
                or (VLS.isTopFramePart and VLS.isTopFramePart(part))) then
            if hidden(part) then return y end
            return draw(self,y,displayRow(row,part),alt)
        end
        return draw(self,y,row,alt)
    end
    local init=ISVehicleMechanics.initParts
    function ISVehicleMechanics:initParts(...)
        if self.listbox then self.listbox.vlsTopRows = nil end
        if self.bodyworklist then self.bodyworklist.vlsTopRows = nil end
        local result=init(self,...)
        refreshRows(self)
        local profile=VLS.getVehicleProfile and VLS.getVehicleProfile(self.vehicle)
        if profile and profile.overheadParts then self:recalculGeneralCondition() end
        return result
    end
    local recalculate=ISVehicleMechanics.recalculGeneralCondition
    function ISVehicleMechanics:recalculGeneralCondition(...)
        local result=recalculate(self,...)
        if not self.vehicle or not VLS.isSupportedVehicle(self.vehicle) then return result end
        local count=self.vehicle:getPartCount()
        local delta,removed=0,0
        local hasOverhead,exactTotal=false,0
        for i=0,count-1 do
            local part=self.vehicle:getPartByIndex(i)
            local overhead=VLS.isOverheadPart and VLS.isOverheadPart(part)
            local installed=part:getInventoryItem()
            local frame=VLS.isTopFramePart and VLS.isTopFramePart(part)
            hasOverhead=hasOverhead or overhead
            if (hidden(part) and not frame) or ((overhead or frame) and not installed) then
                removed=removed+1
            elseif installed then
                local condition=VLS.getDisplayPartCondition(part)
                delta=delta+condition-part:getCondition()
                exactTotal=exactTotal+condition
            else
                local types=part:getItemType()
                exactTotal=exactTotal+((types and not types:isEmpty()) and 0 or part:getCondition())
            end
        end
        if count>removed and (delta~=0 or removed>0 or hasOverhead) then
            self.generalCondition=round((hasOverhead and exactTotal
                or self.generalCondition*count+delta)/(count-removed),2)
            self.generalCondRGB=self:getConditionRGB(self.generalCondition)
        end
        refreshRows(self)
        return result
    end
    local detail=ISVehicleMechanics.renderPartDetail
    if detail then
        function ISVehicleMechanics:renderPartDetail(part,...)
            return detail(self,displayPart(part),...)
        end
    end
    local overlay=ISVehicleMechanics.renderCarOverlayTooltip
    function ISVehicleMechanics:renderCarOverlayTooltip(partProps,part,carType)
        local result=overlay(self,partProps,part,carType)
        if result and part and part:getInventoryItem() and VLS.usesNormalizedPartCondition(part) and self.tooltip then
            self.tooltip:setName(VLS.getMechanicsPartName(part))
            local raw,percent=part:getCondition(),VLS.getDisplayPartCondition(part)
            if self.tooltip.description and raw~=percent then
                self.tooltip.description=self.tooltip.description:gsub(tostring(raw).."%%",tostring(percent).."%%",1)
            end
        end
        return result
    end
    print("[VLS mechanics] native renderer with shared presentation adapter v1")
end

print("[VLS strict-r3] mechanics loaded")
