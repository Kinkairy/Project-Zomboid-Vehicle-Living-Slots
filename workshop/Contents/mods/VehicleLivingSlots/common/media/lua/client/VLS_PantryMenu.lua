local P = require "VLS_Pantry"
require "VLS_PantryCraftAction"
require "VLS_Client"
require "VLS_VehicleMechanicsIcons"
require "ISUI/Crafting/ISHandcraftWindow"
require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"

P.uiSources = P.uiSources or setmetatable({}, { __mode = "k" })
P.stationOrder = { "VLSPantryCoffee", "VLSOverhead1", "VLSOverhead2" }

VLS.registerMechanicsUIProvider("pantry", {
    matches = P.isPart,
    name = function(part)
        local name = getText("IGUI_VehiclePartVLSOverhead1")
        local item = part:getInventoryItem()
        return item and item:getDisplayName() or name
    end,
})

-- Detached native workbench for the original crafting UI only. It never enters
-- the world, owns inventory, acquires network ownership, or enters an action.
local function uiSource(character, vehicle, partId)
    local item = vehicle:getPartById(partId):getInventoryItem()
    local spec = P.devices[P.resolveType(item)]
    local script = ScriptManager.instance:getGameEntityScript(spec.entity)
    local definition = script and script:getComponentScriptFor(ComponentType.CraftBench)
    if not definition then return nil end
    local object = IsoObject.new()
    -- The occupant may be more than three tiles from a long vehicle's origin.
    -- World-workbench range is local to this authorized occupant, not its origin.
    object:setSquare(character:getSquare())
    object:setSprite(spec.sprite)
    local bench = ComponentType.CraftBench:CreateComponentFromScript(definition)
    GameEntityFactory.AddComponent(object, bench)
    local scriptInfo = ComponentType.Script:CreateComponent()
    scriptInfo:setOriginalScript(script)
    GameEntityFactory.AddComponent(object, scriptInfo)
    local source = { object = object, bench = bench, vehicle = vehicle,
        partId = partId, itemId = item:getID(), character = character }
    P.uiSources[object] = source
    return source
end

-- Only an explicit appliance entry receives a detached workbench.
local function installedPart(character, requestedId)
    if not requestedId then return nil end
    local vehicle = character and character:getVehicle()
    if not vehicle or not VLS.isSupportedVehicle(vehicle) then return nil end
    for _, id in ipairs(P.stationOrder) do
        if id == requestedId and not P.reason(character, vehicle, id) then
            return vehicle, id
        end
    end
end

function P.openAppliance(character, vehicle, partId)
    local reason = P.reason(character, vehicle, partId)
    if reason then
        HaloTextHelper.addBadText(character, getText(reason))
        return
    end
    -- Radial is only a shortcut to the same native-window adapter as right-click.
    return ISEntityUI.OpenHandcraftWindow(character, nil, nil, true, nil, nil, partId)
end

if not P.uiHooksApplied then
    P.uiHooksApplied = true
    local nativeOpen = ISEntityUI.OpenHandcraftWindow
    function ISEntityUI.OpenHandcraftWindow(character, object, query, ignoreSurface,
            recipe, itemString, requestedId)
        local vehicle, partId = installedPart(character, requestedId)
        if not vehicle or (object and object ~= vehicle) then
            return nativeOpen(character, object, query, ignoreSurface, recipe, itemString)
        end
        local source = uiSource(character, vehicle, partId)
        if not source then
            HaloTextHelper.addBadText(character, getText("ContextMenu_VLSPantryMenuUnavailable"))
            return
        end
        local tag = source.bench:getRecipeTagQuery()
        local ok, result = pcall(nativeOpen, character, source.object, tag,
            true, recipe, itemString)
        local window = ok and ISEntityUI.GetWindowInstance(character:getPlayerNum(), "HandcraftWindow")
        local panel = window and window.handCraftPanel
        local bound = panel and panel.isoObject == source.object
            and panel.craftBench == source.bench and panel.logic:getCraftBench() == source.bench
        if not bound then
            if window and window.isoObject == source.object then window:close() end
            P.uiSources[source.object] = nil
            HaloTextHelper.addBadText(character, getText("ContextMenu_VLSPantryMenuUnavailable"))
        end
        print("[VLS Pantry " .. P.VERSION .. "] open part=" .. partId
            .. " benchBound=" .. tostring(not not bound) .. " query=" .. tostring(tag))
        if not ok then error(result, 0) end
        return result
    end

    local nativePanel = ISHandCraftPanel.new
    function ISHandCraftPanel:new(x, y, width, height, player, craftBench, isoObject, recipeQuery)
        local source = P.uiSources[isoObject]
        if source and source.character == player then
            craftBench = source.bench
            recipeQuery = craftBench:getRecipeTagQuery()
        end
        return nativePanel(self, x, y, width, height, player, craftBench, isoObject, recipeQuery)
    end

    local nativeContainers = ISHandCraftPanel.updateContainers
    function ISHandCraftPanel:updateContainers(force)
        local source = P.uiSources[self.isoObject]
        if not source then
            return nativeContainers(self, force)
        end
        local getContainers = ISInventoryPaneContextMenu.getContainers
        ISInventoryPaneContextMenu.getContainers = function(character)
            if character == self.player then return P.carriedContainers(character) end
            return getContainers(character)
        end
        local ok, result = pcall(nativeContainers, self, force)
        ISInventoryPaneContextMenu.getContainers = getContainers
        if not ok then error(result, 0) end
        return result
    end

    local nativeUpdate = ISHandcraftWindow.update
    function ISHandcraftWindow:update()
        local source = P.uiSources[self.isoObject]
        if not source then return nativeUpdate(self) end
        ISCollapsableWindow.update(self)
        if P.reason(self.player, source.vehicle, source.partId, source.itemId) then
            self:close()
            return false
        end
        source.object:setSquare(self.player:getSquare())
        self.isoObjectInProximity = true
        return true
    end

    local nativePrerender = ISHandcraftWindow.prerender
    function ISHandcraftWindow:prerender()
        nativePrerender(self)
        local source = P.uiSources[self.isoObject]
        local part = source and source.vehicle:getPartById(source.partId)
        local item = part and part:getInventoryItem()
        if item and self.windowHeader and self.windowHeader.title then
            self.windowHeader.title.name = item:getDisplayName()
        end
    end

    local nativeClose = ISHandcraftWindow.close
    function ISHandcraftWindow:close()
        local source = P.uiSources[self.isoObject]
        local result = nativeClose(self)
        if source then P.uiSources[source.object] = nil end
        return result
    end

    local nativeNew = ISHandcraftAction.new
    -- NetTimedAction reads constructor parameter names from action fields.
    -- Keep the vanilla signature exact, including names used only in MP.
    function ISHandcraftAction:new(character, craftRecipe, containers, isoObject, craftBench,
            manualInputs, items, recipeItem, variableInputRatio, eatPercentage)
        local source = P.uiSources[isoObject]
        if not source then
            return nativeNew(self, character, craftRecipe, containers, isoObject, craftBench,
                manualInputs, items, recipeItem, variableInputRatio, eatPercentage)
        end
        local part = source.vehicle:getPartById(source.partId)
        local choice = P.choiceForRecipe(craftRecipe, source.partId, part and part:getInventoryItem())
        return VLSPantryCraftAction:new(character, source.vehicle:getId(), source.partId,
            source.itemId, choice or "", manualInputs, items, recipeItem)
    end
end

local function addPantrySlices(menu, character)
    local vehicle = character and character:getVehicle()
    if not vehicle or not VLS.isSupportedVehicle(vehicle) then return end
    for _, partId in ipairs(P.stationOrder) do
        local part = vehicle:getPartById(partId)
        local item = part and part:getInventoryItem()
        if P.accepts(part, item) then
            local reason = P.reason(character, vehicle, partId)
            local text = item:getDisplayName()
            if reason then text = text .. "\n" .. getText(reason) end
            local icon = getTexture("media/ui/VLS_SmallAppliances.png")
                or getTexture("Item_ElectronicsScrap")
            menu:addSlice(text, icon, not reason and P.openAppliance or nil,
                character, vehicle, partId)
        end
    end
end

if not P.radialHookApplied then
    P.radialHookApplied = true
    local previous = ISVehicleMenu.showRadialMenu
    function ISVehicleMenu.showRadialMenu(character)
        local menu = character and getPlayerRadialMenu(character:getPlayerNum())
        if not menu then return previous(character) end
        local raw = rawget(menu, "addToUIManager")
        local add = menu.addToUIManager
        local injected = false
        menu.addToUIManager = function(self, ...)
            if self == menu and not injected then
                injected = true
                addPantrySlices(menu, character)
            end
            return add(self, ...)
        end
        local ok, result = pcall(previous, character)
        menu.addToUIManager = raw
        if not ok then error(result, 0) end
        return result
    end
end
