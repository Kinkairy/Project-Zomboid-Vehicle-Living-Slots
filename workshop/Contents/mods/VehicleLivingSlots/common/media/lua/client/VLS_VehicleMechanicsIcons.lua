require "VLS_Config"
require "Vehicles/ISUI/ISVehicleMechanics"
require "Vehicles/ISUI/ISVehiclePartMenu"

local previewTextures = {}

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
    local name = candidate:getDisplayName()
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
        itemMenu = ISContextMenu:getNew(mechanics.context)
        mechanics.context:addSubMenu(option, itemMenu)
        alreadyAdded = {}
    end

    for _, candidate in ipairs(candidates) do
        if not alreadyAdded[candidate] then
            addInstallCandidate(mechanics, part, itemMenu, itemType, candidate)
        end
    end
    return candidates
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

local function applyFurnitureIcons(mechanics, part)
    if not mechanics or not mechanics.context or not VLS.isManagedPart(part)
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

        local itemMenu = option and option.subOption
            and mechanics.context:getSubMenu(option.subOption) or nil
        if itemMenu and candidates then
            for j, candidate in ipairs(candidates) do
                local candidateOption = itemMenu.options[j]
                if candidateOption then
                    local condition = VLS.getItemConditionPercent(candidate)
                    if condition then
                        candidateOption.name = candidate:getDisplayName()
                            .. " (" .. condition .. "%)"
                    end
                end
            end
        end
    end
end

local function getManagedPartDisplayName(part)
    local inventoryItem = part and part:getInventoryItem()
    if inventoryItem and VLS.isUniversalPart(part) then
        return inventoryItem:getDisplayName()
    end
    return getText("IGUI_VehiclePart" .. part:getId())
end

local function drawManagedPartRow(list, y, item)
    local part = item.item.part

    if item.itemindex == list.selected then
        list:drawRect(0, y, list:getWidth(), item.height, 0.1, 1.0, 1.0, 1.0)
    elseif item.itemindex == list.mouseoverselected
            and ((list.parent.context and not list.parent.context:isVisible())
                or not list.parent.context) then
        list:drawRect(0, y, list:getWidth(), item.height, 0.05, 1.0, 1.0, 1.0)
    end

    -- Universal living spaces describe their installed furniture or appliance.
    -- Dedicated water, battery and weapon slots keep their scripted slot name.
    local displayName = getManagedPartDisplayName(part)
    local inventoryItem = part:getInventoryItem()
    local textR, textG, textB = list.parent.partRGB.r,
        list.parent.partRGB.g, list.parent.partRGB.b
    if not inventoryItem then
        textR, textG, textB = 1.0, 0.0, 0.0
    end
    list:drawText(displayName, 20, y, textR, textG, textB,
        list.parent.partRGB.a, UIFont.Small)

    local charge = ""
    if part:getId() == VLS.AUX_BATTERY_PART_ID and inventoryItem then
        charge = ": " .. math.floor(inventoryItem:getCurrentUsesFloat() * 100)
            .. "% " .. getText("IGUI_invpanel_Remaining")
        list:drawText(charge,
            getTextManager():MeasureStringX(UIFont.Small, displayName) + 20,
            y, list.parent.partRGB.r, list.parent.partRGB.g,
            list.parent.partRGB.b, list.parent.partRGB.a, UIFont.Small)
    elseif VLS.isWaterTankPart(part) and inventoryItem then
        local capacity = part:getContainerCapacity()
        local amount = capacity > 0 and math.floor(
            part:getContainerContentAmount() / capacity * 100) or 0
        charge = ": " .. amount .. "% " .. getText("IGUI_invpanel_Remaining")
        list:drawText(charge,
            getTextManager():MeasureStringX(UIFont.Small, displayName) + 20,
            y, list.parent.partRGB.r, list.parent.partRGB.g,
            list.parent.partRGB.b, list.parent.partRGB.a, UIFont.Small)
    elseif inventoryItem
            and VLS.getEquipmentCapability(inventoryItem) == "waterDispenser" then
        local fluid = inventoryItem:getFluidContainer()
        local capacity = fluid and fluid:getCapacity() or 0
        local amount = capacity > 0 and math.floor(
            fluid:getAmount() / capacity * 100) or 0
        charge = ": " .. amount .. "% " .. getText("IGUI_invpanel_Remaining")
        list:drawText(charge,
            getTextManager():MeasureStringX(UIFont.Small, displayName) + 20,
            y, list.parent.partRGB.r, list.parent.partRGB.g,
            list.parent.partRGB.b, list.parent.partRGB.a, UIFont.Small)
    end

    if inventoryItem then
        local condition = VLS.getDisplayPartCondition(part)
        local condRGB = list.parent:getConditionRGB(condition)
        list:drawText(" (" .. condition .. "%)",
            getTextManager():MeasureStringX(UIFont.Small, displayName)
                + getTextManager():MeasureStringX(UIFont.Small, charge) + 22,
            y, condRGB.r, condRGB.g, condRGB.b,
            list.parent.partRGB.a, UIFont.Small)
    end

    return y + list.itemheight
end

if not VLS.mechanicsIconHookApplied then
    VLS.mechanicsIconHookApplied = true
    local vanillaDoPartContextMenu = ISVehicleMechanics.doPartContextMenu

    function ISVehicleMechanics:doPartContextMenu(part, x, y)
        local result = vanillaDoPartContextMenu(self, part, x, y)
        applyFurnitureIcons(self, part)
        return result
    end
end

if not VLS.mechanicsDisplayHookApplied then
    VLS.mechanicsDisplayHookApplied = true

    local vanillaDoDrawItem = ISVehicleMechanics.doDrawItem
    function ISVehicleMechanics:doDrawItem(y, item, alt)
        local part = item and item.item and item.item.part
        if part and VLS.isManagedPart(part) then
            return drawManagedPartRow(self, y, item)
        end
        return vanillaDoDrawItem(self, y, item, alt)
    end

    local vanillaRecalculate = ISVehicleMechanics.recalculGeneralCondition
    function ISVehicleMechanics:recalculGeneralCondition()
        vanillaRecalculate(self)
        if not VLS.isSupportedVehicle(self.vehicle) then
            return
        end

        local delta = 0
        for i = 0, self.vehicle:getPartCount() - 1 do
            local part = self.vehicle:getPartByIndex(i)
            if part:getInventoryItem() and VLS.isManagedPart(part) then
                delta = delta + VLS.getDisplayPartCondition(part) - part:getCondition()
            end
        end
        if delta ~= 0 and self.vehicle:getPartCount() > 0 then
            self.generalCondition = round(
                self.generalCondition + delta / self.vehicle:getPartCount(), 2)
            self.generalCondRGB = self:getConditionRGB(self.generalCondition)
        end
    end

    local vanillaOverlayTooltip = ISVehicleMechanics.renderCarOverlayTooltip
    function ISVehicleMechanics:renderCarOverlayTooltip(partProps, part, carType)
        local result = vanillaOverlayTooltip(self, partProps, part, carType)
        if result and part and part:getInventoryItem() and VLS.isManagedPart(part)
                and self.tooltip then
            self.tooltip:setName(getManagedPartDisplayName(part))
            local rawCondition = part:getCondition()
            local displayCondition = VLS.getDisplayPartCondition(part)
            if self.tooltip.description and rawCondition ~= displayCondition then
                self.tooltip.description = self.tooltip.description:gsub(
                    tostring(rawCondition) .. "%%",
                    tostring(displayCondition) .. "%%", 1)
            end
        end
        return result
    end
end
