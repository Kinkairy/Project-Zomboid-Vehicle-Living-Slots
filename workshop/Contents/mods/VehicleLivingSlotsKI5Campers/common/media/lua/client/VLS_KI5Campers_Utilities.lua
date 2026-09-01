local VLS = require "VLS_KI5Campers_Config"
require "Definitions/ContainerButtonIcons"
require "ISUI/ISInventoryPaneContextMenu"
require "Vehicles/ISUI/ISVehicleMenu"
require "Vehicles/ISUI/ISVehicleMechanics"
require "Vehicles/TimedActions/ISPathFindAction"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

local ADAPTER_MOD_ID = "VehicleLivingSlotsKI5Campers"

local function getPropaneCondition(part)
    local item = part and part:getInventoryItem()
    return item and VLS.getItemConditionPercent(item) or 0
end

local function drawPropanePartRow(list, y, item)
    local part = item.item.part
    if item.itemindex == list.selected then
        list:drawRect(0, y, list:getWidth(), item.height, 0.1, 1, 1, 1)
    elseif item.itemindex == list.mouseoverselected
            and ((list.parent.context and not list.parent.context:isVisible())
                or not list.parent.context) then
        list:drawRect(0, y, list:getWidth(), item.height, 0.05, 1, 1, 1)
    end

    local displayName = getText("IGUI_VehiclePart" .. part:getId())
    local installed = part:getInventoryItem()
    local r, g, b = list.parent.partRGB.r, list.parent.partRGB.g,
        list.parent.partRGB.b
    if not installed then r, g, b = 1, 0, 0 end
    list:drawText(displayName, 20, y, r, g, b, list.parent.partRGB.a,
        UIFont.Small)
    if installed then
        local remaining = math.floor(installed:getCurrentUsesFloat() * 100)
        local charge = ": " .. remaining .. "% "
            .. getText("IGUI_invpanel_Remaining")
        list:drawText(charge,
            getTextManager():MeasureStringX(UIFont.Small, displayName) + 20,
            y, list.parent.partRGB.r, list.parent.partRGB.g,
            list.parent.partRGB.b, list.parent.partRGB.a, UIFont.Small)
        local condition = getPropaneCondition(part)
        local color = list.parent:getConditionRGB(condition)
        list:drawText(" (" .. condition .. "%)",
            getTextManager():MeasureStringX(UIFont.Small, displayName)
                + getTextManager():MeasureStringX(UIFont.Small, charge) + 22,
            y, color.r, color.g, color.b, list.parent.partRGB.a, UIFont.Small)
    end
    return y + list.itemheight
end

local function normalizePropaneInstallOptions(mechanics, menu)
    if not menu then return end
    for _, option in ipairs(menu.options or {}) do
        local candidate = option.itemForTexture
        if candidate and candidate:getFullType() == "Base.PropaneTank" then
            option.name = candidate:getDisplayName() .. " ("
                .. tostring(VLS.getItemConditionPercent(candidate)) .. "%)"
        end
        if option.subOption then
            normalizePropaneInstallOptions(mechanics,
                mechanics.context:getSubMenu(option.subOption))
        end
    end
end

if not VLS.camperUtilityMechanicsHookApplied then
    VLS.camperUtilityMechanicsHookApplied = true

    local previousDoPartContextMenu = ISVehicleMechanics.doPartContextMenu
    function ISVehicleMechanics:doPartContextMenu(part, x, y)
        local result = previousDoPartContextMenu(self, part, x, y)
        if VLS.isPropaneTankPart(part) then
            normalizePropaneInstallOptions(self, self.context)
        end
        return result
    end

    local previousDoDrawItem = ISVehicleMechanics.doDrawItem
    function ISVehicleMechanics:doDrawItem(y, item, alt)
        local part = item and item.item and item.item.part
        if part and VLS.isPropaneTankPart(part) then
            return drawPropanePartRow(self, y, item)
        end
        return previousDoDrawItem(self, y, item, alt)
    end

    local previousRecalculate = ISVehicleMechanics.recalculGeneralCondition
    function ISVehicleMechanics:recalculGeneralCondition()
        previousRecalculate(self)
        if not self.vehicle then return end
        local delta = 0
        for index = 0, self.vehicle:getPartCount() - 1 do
            local part = self.vehicle:getPartByIndex(index)
            if part:getInventoryItem() and VLS.isPropaneTankPart(part) then
                delta = delta + getPropaneCondition(part) - part:getCondition()
            end
        end
        if delta ~= 0 and self.vehicle:getPartCount() > 0 then
            self.generalCondition = round(
                self.generalCondition + delta / self.vehicle:getPartCount(), 2)
            self.generalCondRGB = self:getConditionRGB(self.generalCondition)
        end
    end

    local previousOverlayTooltip = ISVehicleMechanics.renderCarOverlayTooltip
    function ISVehicleMechanics:renderCarOverlayTooltip(partProps, part, carType)
        local result = previousOverlayTooltip(self, partProps, part, carType)
        if result and part and part:getInventoryItem()
                and VLS.isPropaneTankPart(part) and self.tooltip then
            local raw = part:getCondition()
            local normalized = getPropaneCondition(part)
            if self.tooltip.description and raw ~= normalized then
                self.tooltip.description = self.tooltip.description:gsub(
                    tostring(raw) .. "%%", tostring(normalized) .. "%%", 1)
            end
        end
        return result
    end
end

local function refreshCamperContainerIcons(page, phase)
    if phase ~= "buttonsAdded" or not page then return end
    for _, button in ipairs(page.backpacks or {}) do
        local container = button.inventory
        local part = container and container:getVehiclePart()
        local iconType = part and VLS.getContainerIconOverride(part,
            container:getType()) or nil
        local icon = iconType and ContainerButtonIcons[iconType] or nil
        if icon then button:setImage(icon) end
    end
end

if not VLS.camperContainerIconHookApplied then
    VLS.camperContainerIconHookApplied = true
    Events.OnRefreshInventoryWindowContainers.Add(refreshCamperContainerIcons)
end

local function resolveInventoryItem(entry)
    if instanceof(entry, "InventoryItem") then return entry end
    return entry and entry.items and entry.items[1] or nil
end

local function findSelectedBlowTorch(items)
    for _, entry in ipairs(items or {}) do
        local item = resolveInventoryItem(entry)
        if item and item:getFullType() == "Base.BlowTorch"
                and instanceof(item, "DrainableComboItem")
                and item:getCurrentUsesFloat() < 1 then
            return item
        end
    end
    return nil
end

local function findNearbyPropaneSource(playerObj)
    if not playerObj or playerObj:getVehicle() then return nil end
    local seen = {}
    local function resolve(vehicle)
        if not vehicle or seen[vehicle] or not VLS.isSupportedVehicle(vehicle)
                or playerObj:DistToProper(vehicle) >= 4 then return nil end
        seen[vehicle] = true
        local source, part = VLS.getInstalledPropaneSource(vehicle)
        return source and vehicle or nil, source, part
    end

    local vehicle, source, part = resolve(
        ISVehicleMenu.getVehicleToInteractWith(playerObj))
    if vehicle then return vehicle, source, part end

    local cell = getCell()
    if not cell then return nil end
    local px, py, pz = math.floor(playerObj:getX()),
        math.floor(playerObj:getY()), math.floor(playerObj:getZ())
    for x = px - 2, px + 2 do
        for y = py - 2, py + 2 do
            local square = cell:getGridSquare(x, y, pz)
            vehicle, source, part = resolve(
                square and square:getVehicleContainer() or nil)
            if vehicle then return vehicle, source, part end
        end
    end
    return nil
end

VLSRefillBlowTorchFromVehicleAction = ISBaseTimedAction:derive(
    "VLSRefillBlowTorchFromVehicleAction")

function VLSRefillBlowTorchFromVehicleAction:isValid()
    local inventory = self.character and self.character:getInventory()
    local torch = inventory and inventory:getItemWithIDRecursiv(self.torchId)
    local source, part = VLS.getInstalledPropaneSource(self.vehicle, self.partId)
    return torch and torch:getFullType() == "Base.BlowTorch"
        and torch:getCurrentUsesFloat() < 1 and source and part
        and not self.character:getVehicle() and self.vehicle:isStopped()
        and self.character:DistToProper(self.vehicle) < 4
        and self.vehicle:isInArea(part:getArea(), self.character)
end

function VLSRefillBlowTorchFromVehicleAction:update()
    self.character:faceThisObject(self.vehicle)
    self.character:setMetabolicTarget(Metabolics.LightWork)
    local torch = self.character:getInventory():getItemWithIDRecursiv(self.torchId)
    if torch then torch:setJobDelta(self:getJobDelta()) end
end

function VLSRefillBlowTorchFromVehicleAction:start()
    self:setActionAnim("Welding")
    self:setOverrideHandModels("Base.CraftingWeldingTorch",
        "Base.CraftingWeldingPipe")
    self.sound = self.character:playSound("CraftWelding")
end

function VLSRefillBlowTorchFromVehicleAction:stop()
    local torch = self.character:getInventory():getItemWithIDRecursiv(self.torchId)
    if torch then torch:setJobDelta(0) end
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

local function submitRefill(character, vehicle, partId, torchId)
    local args = { vehicle = vehicle:getId(), part = partId, torch = torchId }
    if isClient() then
        sendClientCommand(character, ADAPTER_MOD_ID, "refillBlowTorch", args)
    elseif VLS.KI5Server and VLS.KI5Server.refillBlowTorch then
        VLS.KI5Server.refillBlowTorch(character, args)
    end
end

function VLSRefillBlowTorchFromVehicleAction:perform()
    local torch = self.character:getInventory():getItemWithIDRecursiv(self.torchId)
    if torch then torch:setJobDelta(0) end
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    submitRefill(self.character, self.vehicle, self.partId, self.torchId)
    ISBaseTimedAction.perform(self)
end

function VLSRefillBlowTorchFromVehicleAction:new(character, vehicle, part,
        torch)
    local o = ISBaseTimedAction.new(self, character)
    o.vehicle = vehicle
    o.partId = part:getId()
    o.torchId = torch:getID()
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 50
    o.jobType = getText("Recipe_RefillBlowTorch")
    return o
end

local function queueVehicleRefill(playerObj, vehicle, part, torch)
    local path = ISPathFindAction:pathToVehicleArea(playerObj, vehicle,
        part:getArea())
    path:setOnFail(function(character)
        HaloTextHelper.addBadText(character,
            getText("IGUI_PlayerText_NoWayToFuelTankInlet"))
    end, playerObj)
    ISTimedActionQueue.add(path)
    ISTimedActionQueue.add(VLSRefillBlowTorchFromVehicleAction:new(
        playerObj, vehicle, part, torch))
end

local function addVehiclePropaneRefillOption(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    local torch = findSelectedBlowTorch(items)
    if not torch then return end
    local vehicle, _, part = findNearbyPropaneSource(playerObj)
    if not part then return end
    context:addOption(getText("Recipe_RefillBlowTorch"), playerObj,
        queueVehicleRefill, vehicle, part, torch)
end

if not VLS.camperPropaneRefillMenuApplied then
    VLS.camperPropaneRefillMenuApplied = true
    Events.OnFillInventoryObjectContextMenu.Add(addVehiclePropaneRefillOption)
end
