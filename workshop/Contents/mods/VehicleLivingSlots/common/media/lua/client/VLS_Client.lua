require "VLS_Config"
require "Entity/ISEntityUI"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/Crafting/ISHandcraftWindow"
-- VLS_DIRECT_ORIGINAL_FIX_20260904_V2: client
require "ISUI/ISWorldObjectContextMenu"
require "ISUI/Fireplace/ISMicrowaveUI"
require "Fluids/ISFluidTransferUI"
require "Definitions/ContainerButtonIcons"
require "ISUI/LootWindow/ISLootWindowContainerControls"
require "ISUI/LootWindow/ISLootWindowObjectControlHandler"
require "Vehicles/ISUI/ISVehicleMenu"
require "Vehicles/ISUI/ISVehicleSeatUI"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISInventoryTransferUtil"
require "Vehicles/TimedActions/ISEnterVehicle"
require "Vehicles/TimedActions/ISSwitchVehicleSeat"
require "VLS_VehicleFluidTransferAction"
require "VLS_FillVehicleWaterTankAction"
require "VLS_VehicleRestAction"
require "RadioCom/ISRadioWindow"
require "RadioCom/ISRadioAction"
require "TimedActions/ISDeviceBatteryAction"

-- BEGIN VLS_CARGO_R6_CLIENT_20260922
-- Integrated in the original VLS_Client.lua; no independent Lua loader/mod ID.
local CargoR6 = VLS.CargoR6

function CargoR6.onInventoryPhase(page, phase)
    if not page or page.onCharacter or (phase ~= "begin" and phase ~= "end")
            or type(page.player) ~= "number" then return end
    local character = getSpecificPlayer(page.player)
    local vehicle = character and character:getVehicle()
    if not CargoR6.applies(vehicle) then return end
    local state = CargoR6.probe(vehicle, character, phase == "begin")
    if not state or phase ~= "end" then return end
    local container, shown = state.part:getItemContainer(), false
    for _, button in ipairs(page.backpacks or {}) do
        if button.inventory == container then shown = true; break end
    end
    local message = "ACCESS_CHECK model=" .. vehicle:getScript():getFullName()
        .. " seat=" .. tostring(vehicle:getSeat(character))
        .. " rawSeats=" .. tostring(state.raw)
        .. " physicalSeats=" .. tostring(state.physical)
        .. " addedVLSSeats=" .. tostring(state.added)
        .. " callbackReached=" .. tostring(state.reached)
        .. " engine=" .. (state.ok and tostring(state.value) or "ERROR")
        .. " trunkButton=" .. tostring(shown)
        .. " multiplayer=" .. tostring(isClient())
    if message ~= state.lastMessage then
        state.lastMessage = message
        print("[VLS Cargo 3.8.11] " .. message)
        if not state.ok then print("[VLS Cargo 3.8.11] ENGINE_ERROR " .. tostring(state.value)) end
    end
end

function CargoR6.safeInventoryPhase(page, phase)
    local ok, err = pcall(CargoR6.onInventoryPhase, page, phase)
    if not ok then CargoR6.logOnce("inventoryError", "DIAGNOSTIC_ERROR " .. tostring(err)) end
end

local function cargoTransferPart(container)
    if not container then return nil end
    local root = container:getOutermostContainer()
    local part = (root and root:getVehiclePart()) or container:getVehiclePart()
    if part and part:getId() == "TruckBed" and CargoR6.applies(part:getVehicle()) then
        return part
    end
    return nil
end

function CargoR6.transferObservation(action, phase, result)
    if (CargoR6.transferLogCount or 0) >= 80 or not action or not action.item then return end
    local srcPart = cargoTransferPart(action.srcContainer)
    local dstPart = cargoTransferPart(action.destContainer)
    local part = srcPart or dstPart
    if not part or not action.character
            or action.character:getVehicle() ~= part:getVehicle() then return end
    local sourceHas = action.srcContainer and action.srcContainer:contains(action.item)
    local destHas = action.destContainer and action.destContainer:contains(action.item)
    local transaction = "not_checked"
    if isClient() and action.transactionId then
        if isItemTransactionRejected and isItemTransactionRejected(action.transactionId) then
            transaction = "rejected"
        elseif isItemTransactionDone and isItemTransactionDone(action.transactionId) then
            transaction = "done"
        else transaction = "pending" end
    end
    local text = "TRANSFER_OBSERVATION phase=" .. phase
        .. " direction=" .. (dstPart and "into_trunk" or "out_of_trunk")
        .. " result=" .. tostring(result) .. " transaction=" .. transaction
        .. " sourceHasItem=" .. tostring(sourceHas) .. " destHasItem=" .. tostring(destHas)
    CargoR6.actionStates = CargoR6.actionStates or setmetatable({}, {__mode = "k"})
    local states = CargoR6.actionStates[action] or {}
    CargoR6.actionStates[action] = states
    if states[phase] ~= text then
        states[phase] = text
        CargoR6.transferLogCount = (CargoR6.transferLogCount or 0) + 1
        print("[VLS Cargo 3.8.11] " .. text)
    end
end

function CargoR6.installClientHooks()
    local ok, err = pcall(CargoR6.installNativeHook)
    if not ok then CargoR6.logOnce("clientBindError", "BIND_ERROR " .. tostring(err)) end
    -- Observe only; never re-run isValid(), change its result, move an item,
    -- invent a transaction, or bypass server validation/checksums.
    local class = ISInventoryTransferAction
    if not class then return end
    if class.isValid ~= CargoR6.isValidWrapper then
        local previous = class.isValid
        CargoR6.isValidWrapper = function(self, ...)
            local result = previous(self, ...)
            pcall(CargoR6.transferObservation, self, "isValid", result)
            return result
        end
        class.isValid = CargoR6.isValidWrapper
    end
    if class.update ~= CargoR6.updateWrapper then
        local previous = class.update
        CargoR6.updateWrapper = function(self, ...)
            local result = previous(self, ...)
            pcall(CargoR6.transferObservation, self, "update", result)
            return result
        end
        class.update = CargoR6.updateWrapper
    end
end
CargoR6.logOnce("clientLoaded", "CLIENT_LOADED build=" .. CargoR6.BUILD
    .. " baseDir=" .. CargoR6.directory())
-- END VLS_CARGO_R6_CLIENT_20260922

-- BEGIN VLS_SEAT_R6_CLIENT_20260922
-- Integrated adapters: native routing / transfer helpers / timed actions own
-- their original behavior. No independent mod and no standalone seat loader.
local SeatR6 = VLS.SeatR6

function SeatR6.log(message)
    if (SeatR6.logCount or 0) >= 100 then return end
    SeatR6.logCount = (SeatR6.logCount or 0) + 1
    print("[VLS Seat R6] " .. message)
end

function SeatR6.chooseRoute(native, character, vehicle, seat, entering)
    if not SeatR6.applies(vehicle) then return native(character, vehicle, seat) end
    if not SeatR6.validSeat(vehicle, seat)
            or (entering and not SeatR6.mayOccupy(vehicle, seat)) then return nil end
    local view = CargoR6.queryViews()
    local filtered = view(vehicle, {
        isSeatOccupied = function(_, candidate)
            if not SeatR6.mayOccupy(vehicle, candidate)
                    or not vehicle:isSeatInstalled(candidate) then return true end
            -- Native auto-route callers dereference the alternative's door.
            -- A doorless bed may be entered manually but is not a safe automatic
            -- enter/exit waypoint. Do not fabricate a door for it.
            local door = vehicle:getPassengerDoor(candidate)
            if not door or not door:getDoor() then return true end
            return vehicle:isSeatOccupied(candidate)
        end,
    })
    local selected = native(character, filtered, seat)
    if selected ~= nil and not SeatR6.mayOccupy(vehicle, selected) then return nil end
    SeatR6.log("ROUTE mode=" .. (entering and "enter" or "exit")
        .. " from=" .. tostring(seat) .. " selected=" .. tostring(selected))
    return selected
end

-- Find the actual part by container seat number, never assume that the index
-- in getAllSeatParts() is the passenger index after VLS appended living slots.
function SeatR6.partForSeat(vehicle, seat)
    for index = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(index)
        if part and part:getItemContainer()
                and part:getContainerSeatNumber() == seat then return part end
    end
    return nil
end

-- Compose a COMPLETE dry plan first. Every per-item fit decision still calls
-- the original transferSeatItems(..., testOnly=true). The tiny views account
-- for reserved capacity and present only the current not-yet-selected item.
-- No real container is mutated. Execution uses only real native transfer actions.
function SeatR6.planMoves(nativeTransfer, character, vehicle, seat)
    if not SeatR6.validSeat(vehicle, seat) or not SeatR6.mayOccupy(vehicle, seat)
            or VLS.getSpaceAssignmentForSeat(vehicle, seat)
            or not vehicle:isSeatInstalled(seat) or vehicle:getCharacter(seat) then
        return nil, "invalid_or_living_source"
    end
    local sourcePart = SeatR6.partForSeat(vehicle, seat)
    local source = sourcePart and sourcePart:getItemContainer()
    if not source then return nil, "missing_source" end
    local desired, remaining = source:getCapacity() * 0.25, source:getContentsWeight()
    local plan = {source=source, entries={}, seat=seat}
    if not vehicle:isSeatHoldingItems(seat) then return plan, "already_clear" end
    -- Some engine versions use a boundary different from weight<=25%; do not
    -- claim a clear seat if the native occupancy query still says it is blocked.
    if remaining <= desired then return nil, "native_seat_still_blocked" end
    local destinations, seen = {}, {}
    local function addDestination(part)
        local container = part and part:getItemContainer()
        if not container or container == source or seen[container] then return end
        seen[container] = true
        destinations[#destinations+1] = {part=part, container=container, reserved=0}
    end
    local trunk = vehicle:getPartById("TruckBed")
    if trunk and vehicle:canAccessContainer(trunk:getIndex(), character) then addDestination(trunk) end
    for offset = 1, vehicle:getMaxPassengers() - 1 do
        local other = (seat + offset) % vehicle:getMaxPassengers()
        if not VLS.getSpaceAssignmentForSeat(vehicle, other)
                and vehicle:isSeatInstalled(other) and not vehicle:getCharacter(other)
                and vehicle:canSwitchSeat(seat, other) then
            addDestination(SeatR6.partForSeat(vehicle, other))
        end
    end
    local items, chosen = source:getItems(), {}
    local view = CargoR6.queryViews()
    for _, destination in ipairs(destinations) do
        local target = destination.container
        for index = 0, items:size() - 1 do
            if remaining <= desired then break end
            local item = items:get(index)
            if not chosen[item] and target:isItemAllowed(item)
                    and target:hasRoomFor(character, item) then
                local oneItem = {size=function() return 1 end,
                    get=function(_, i) return i == 0 and item or nil end}
                local sourceView = view(source, {
                    isEmpty=function() return false end,
                    getContentsWeight=function() return remaining end,
                    getItems=function() return oneItem end,
                })
                local targetView = view(target, {
                    getContentsWeight=function()
                        return target:getContentsWeight() + destination.reserved
                    end,
                })
                local partView = view(sourcePart, {getItemContainer=function() return sourceView end})
                local targetPartView = view(destination.part, {getItemContainer=function() return targetView end})
                local moved = nativeTransfer(character, vehicle, partView, targetPartView, desired, true)
                if type(moved) == "number" and moved > 0 then
                    chosen[item] = true
                    destination.reserved = destination.reserved + moved
                    remaining = remaining - moved
                    plan.entries[#plan.entries+1] = {item=item, target=target}
                end
            end
        end
        if remaining <= desired then break end
    end
    if remaining > desired then return nil, "insufficient_space" end
    return plan, "ready"
end

function SeatR6.moveItems(nativeTransfer, character, vehicle, seat, moveThem, doEnter)
    local plan, reason = SeatR6.planMoves(nativeTransfer, character, vehicle, seat)
    if not plan then
        if moveThem then SeatR6.log("MOVE_REJECT seat=" .. tostring(seat) .. " reason=" .. reason) end
        return false
    end
    if not moveThem then return true end -- UI tests NEVER enqueue an enter/move.
    -- Create all native action objects before touching the queue. Native action
    -- validity/transactions remain in charge if capacity changes while queued.
    local actions = {}
    for _, entry in ipairs(plan.entries) do
        actions[#actions+1] = ISInventoryTransferUtil.newInventoryTransferAction(
            character, entry.item, plan.source, entry.target, 10)
    end
    for _, action in ipairs(actions) do ISTimedActionQueue.add(action) end
    if doEnter then ISVehicleMenu.processEnter(character, vehicle, seat) end
    SeatR6.log("MOVE_QUEUED seat=" .. tostring(seat) .. " items=" .. tostring(#actions)
        .. " enter=" .. tostring(doEnter == true))
    return true
end

function SeatR6.installActionGuards()
    -- Automatic routes instantiate native actions directly. Recheck both at
    -- validation and immediately before mutation. Reattach after a late class
    -- replacement without stacking our wrapper on itself on every game start.
    SeatR6.actionWrappers = SeatR6.actionWrappers or setmetatable({}, {__mode="k"})
    local function wrap(class, key, build)
        if not class or not class[key] then return end
        local state = SeatR6.actionWrappers[class] or {}
        SeatR6.actionWrappers[class] = state
        if class[key] == state[key] then return end
        state[key] = build(class[key])
        class[key] = state[key]
    end
    wrap(ISEnterVehicle, "isValid", function(previous)
        return function(self)
            if not self.started and not SeatR6.mayOccupy(self.vehicle, self.seat) then return false end
            return previous(self)
        end
    end)
    wrap(ISEnterVehicle, "start", function(previous)
        return function(self)
            if SeatR6.applies(self.vehicle) and (not SeatR6.mayOccupy(self.vehicle, self.seat)
                    or not self:isValid()) then
                SeatR6.log("ENTER_BLOCK seat=" .. tostring(self.seat))
                self:forceStop()
                return
            end
            return previous(self)
        end
    end)
    wrap(ISSwitchVehicleSeat, "isValid", function(previous)
        return function(self)
            local vehicle = self.character and self.character:getVehicle()
            return SeatR6.mayOccupy(vehicle, self.seatTo) and previous(self)
        end
    end)
    for _, phase in ipairs({"start", "perform"}) do
        local currentPhase = phase
        wrap(ISSwitchVehicleSeat, phase, function(previous)
            return function(self)
                local vehicle = self.character and self.character:getVehicle()
                if SeatR6.applies(vehicle) and (not SeatR6.mayOccupy(vehicle, self.seatTo)
                        or not self:isValid()) then
                    SeatR6.log("SWITCH_BLOCK phase=" .. currentPhase .. " to=" .. tostring(self.seatTo))
                    self:forceStop()
                    return
                end
                return previous(self)
            end
        end)
    end
end

CargoR6.logOnce("seatsLoaded", "SEAT_ADAPTERS_LOADED routing=native transfer=native_actions")
-- END VLS_SEAT_R6_CLIENT_20260922


print("[VehicleLivingSlots] Client version " .. VLS.VERSION)
print("[VehicleLivingSlots] Countertop context menu fix 1 loaded")

local BED_ICON = getTexture("media/ui/vehicles/vls_vehicle_bed.png")
local SLEEP_ICON = getTexture("media/ui/vehicles/vehicle_sleep.png")
-- RadialMenu has no per-slice draw-size argument. Resizing a shared vanilla
-- Texture mutates every consumer, while splitIcon() selects a different atlas
-- representation. Fixed transparent copies keep the approved appearance and
-- apparent size without touching global vanilla textures.
local WATER_ICON = getTexture("media/ui/vehicles/vls_water_transfer.png")
local TELEVISION_ICON = getTexture("media/ui/vehicles/vls_television.png")
local WATER_FILL_ICON = getTexture(
    "media/ui/vehicles/vls_water_fill.png")
local vanillaMicrowaveOnClick = ISMicrowaveUI.onClick
local vanillaFluidOnButton = ISFluidTransferUI.onButton
local vanillaFluidOnContainerAdd = ISFluidTransferUI.onContainerAdd
local vanillaFluidUpdate = ISFluidTransferUI.update
local vanillaFluidPanelClickedDropBox = ISFluidContainerPanel.clickedDropBox
local pendingBedSleep = {}
local pendingBedRest = {}
local coolingTickCounter = 0
local clientTickCounter = 0

VLS.microwaveWindowClientHooks = VLS.microwaveWindowClientHooks or {}
local MicrowaveWindowHooks = VLS.microwaveWindowClientHooks

-- ItemStatsPacket carries the server-side base display name together with the
-- authoritative food state. Dedicated servers commonly run in English, so
-- restore only the client-local base name for non-custom food shown inside a
-- VLS appliance. Food:getName() continues to add the vanilla localized state
-- prefixes, while player-assigned names remain untouched.
local function getVLSAppliancePart(container)
    if not container then return nil end
    local outermost = container:getOutermostContainer()
    local part = outermost and outermost:getVehiclePart()
        or container:getVehiclePart()
    local vehicle = part and part:getVehicle()
    if not VLS.isSupportedVehicle(vehicle) then return nil end
    if VLS.isFreezerPart(part) then return part end
    if not VLS.isUniversalPart(part) then return nil end
    local capability = VLS.getEquipmentCapability(part:getInventoryItem())
    if capability ~= "cooling" and capability ~= "cooking" then return nil end
    return part
end

local function restoreOfficialVLSFoodName(item)
    if not instanceof(item, "Food") or item:isCustomName() then return false end
    -- Vanilla owns unidentified/poisonous berry and mushroom display names.
    if item.getHerbalistType then
        local herbalistType = item:getHerbalistType()
        if herbalistType and herbalistType ~= "" then return false end
    end
    local officialName = getItemNameFromFullType(item:getFullType())
    if officialName and officialName ~= ""
            and item:getDisplayName() ~= officialName then
        item:setName(officialName)
        return true
    end
    return false
end

-- ItemStatsPacket can change a food name between OnTick and UI rendering
-- without marking the container draw-dirty. Normalize before native grouping,
-- then check only rows the native details renderer can draw. Never run the
-- cooling/environment traversal from a render callback.
VLS.foodNameClientHooks = VLS.foodNameClientHooks or {}
local FoodNameHooks = VLS.foodNameClientHooks

local function isVisibleVLSFoodPane(pane)
    local page = pane and pane.parent
    return page and not page.isCollapsed and page:isReallyVisible()
        and pane:isReallyVisible() and getVLSAppliancePart(pane.inventory)
end

local function restoreVLSFoodRows(pane, doDragged)
    if doDragged and (pane.dragging == nil or not pane.dragStarted) then return end
    local firstRow = math.max(0, math.ceil(-pane:getYScroll() / pane.itemHgt - 1))
    local lastRow = math.floor((pane:getHeight() - pane:getYScroll()) / pane.itemHgt)
    local row = 0
    for _, group in ipairs(pane.itemslist or {}) do
        local count = math.min(#group.items, ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER + 1)
        if pane.collapsed and group.name and pane.collapsed[group.name] then
            count = math.min(count, 1)
        end
        if doDragged then
            -- Selected off-screen rows may be dragged into view.
            if pane.dragging ~= nil and pane.dragStarted then
                for index = 1, count do
                    if pane.selected and pane.selected[row + index] ~= nil then
                        restoreOfficialVLSFoodName(group.items[index])
                    end
                end
            end
        else
            local first = math.max(1, firstRow - row + 1)
            local last = math.min(count, lastRow - row + 1)
            for index = first, last do
                restoreOfficialVLSFoodName(group.items[index])
            end
        end
        row = row + count
        if not doDragged and row > lastRow then break end
    end
end

local function installVLSFoodNameHooks()
    if not ISInventoryPane then return end
    if ISInventoryPane.refreshContainer ~= FoodNameHooks.refreshWrapper then
        local previous = ISInventoryPane.refreshContainer
        FoodNameHooks.refreshWrapper = function(self, ...)
            if isVisibleVLSFoodPane(self) then
                local items = self.inventory:getItems()
                for index = 0, items:size() - 1 do
                    restoreOfficialVLSFoodName(items:get(index))
                end
            end
            return previous(self, ...)
        end
        ISInventoryPane.refreshContainer = FoodNameHooks.refreshWrapper
    end
    if ISInventoryPane.renderdetails ~= FoodNameHooks.renderWrapper then
        local previous = ISInventoryPane.renderdetails
        FoodNameHooks.renderWrapper = function(self, doDragged, ...)
            if isVisibleVLSFoodPane(self) then restoreVLSFoodRows(self, doDragged) end
            return previous(self, doDragged, ...)
        end
        ISInventoryPane.renderdetails = FoodNameHooks.renderWrapper
    end
end

-- The crafting window searches through ISEntityUI, while inventory right-click
-- crafting calls Java HandcraftLogic:findCraftSurface() directly. Adapt both
-- narrow entry points and keep every other vanilla crafting operation intact.
VLS.genericCraftSurfaceClientHooks =
    VLS.genericCraftSurfaceClientHooks or {}
local CraftSurfaceHooks = VLS.genericCraftSurfaceClientHooks

local function makeVLSHandcraftLogicProxy(realLogic)
    local proxy = {}
    local methodCache = {}

    setmetatable(proxy, {
        __index = function(_, key)
            local cached = methodCache[key]
            if cached then return cached end

            local method
            if key == "findCraftSurface" then
                method = function(_, playerObj, radius)
                    local surface = realLogic:findCraftSurface(
                        playerObj, radius)
                    if surface then return surface end
                    return VLS.getVehicleGenericCraftSurface(playerObj)
                end
            else
                method = function(_, ...)
                    local realMethod = realLogic[key]
                    return realMethod(realLogic, ...)
                end
            end

            methodCache[key] = method
            return method
        end,
    })

    return proxy
end

-- A menu query happens before OnNewCraft. Java getUniqueRecipeItems searches
-- world furniture internally, so supplement only its missing AnySurfaceCraft
-- results using the same native validity checks and the installed VLS surface.
local function getVLSContextRecipes(selectedItem, playerObj, recipeList, containers)
    local surface = VLS.getVehicleGenericCraftSurface(playerObj)
    if not surface or not selectedItem or not recipeList then return recipeList end

    local recipes = CraftRecipeManager.queryRecipes("AnySurfaceCraft")
    local logic = HandcraftLogic.new(playerObj, nil, nil)
    logic:setIsoObject(logic:findCraftSurface(playerObj, 2) or surface)
    logic:setContainers(containers)
    local result = nil
    for i = 0, recipes:size() - 1 do
        local recipe = recipes:get(i)
        if recipe:isAnySurfaceCraft()
                and not recipeList:contains(recipe)
                and (not result or not result:contains(recipe))
                and CraftRecipeManager.isValidRecipeForCharacter(
                    recipe, playerObj, nil, containers)
                and CraftRecipeManager.getValidInputScriptForItem(
                    recipe, selectedItem, playerObj)
                and recipe:OnTestItem(selectedItem, playerObj) then
            logic:setRecipeFromContextClick(recipe, selectedItem)
            if logic:canPerformCurrentRecipe() then
                if not result then
                    result = ArrayList.new()
                    result:addAll(recipeList)
                end
                result:add(recipe)
            end
        end
    end
    return result or recipeList
end

-- Both context-menu presentation and execution create HandcraftLogic. Bind the
-- surface at creation for tooltips; only the execution path needs a proxy for
-- the original function's explicit findCraftSurface call. Restore even on error.
local function withVLSHandcraftLogic(callback, useProxy, playerObj, ...)
    local realClass = HandcraftLogic
    HandcraftLogic = setmetatable({
        new = function(character, craftBench, isoObject)
            local logic = realClass.new(character, craftBench, isoObject)
            if character ~= playerObj then return logic end
            local surface
            if not craftBench and not isoObject then
                surface = VLS.getVehicleGenericCraftSurface(character)
                if surface then
                    logic:setIsoObject(logic:findCraftSurface(character, 2) or surface)
                end
            end
            return useProxy and surface and makeVLSHandcraftLogicProxy(logic) or logic
        end,
    }, { __index = realClass })
    local results = { pcall(callback, ...) }
    HandcraftLogic = realClass
    if not results[1] then error(results[2], 0) end
    return unpack(results, 2)
end

local function installGenericCraftSurfaceClientHooks()
    if VLS.installGenericCraftSurfaceActionHooks then
        VLS.installGenericCraftSurfaceActionHooks()
    end

    if ISEntityUI and ISEntityUI.FindCraftSurface
            and ISEntityUI.FindCraftSurface
                ~= CraftSurfaceHooks.findCraftSurfaceWrapper then
        local previousFindCraftSurface = ISEntityUI.FindCraftSurface

        CraftSurfaceHooks.findCraftSurfaceWrapper = function(playerObj, radius)
            local surface = previousFindCraftSurface(playerObj, radius)
            if surface then return surface end
            return VLS.getVehicleGenericCraftSurface(playerObj)
        end

        ISEntityUI.FindCraftSurface =
            CraftSurfaceHooks.findCraftSurfaceWrapper
    end

    -- Vanilla closes every handcraft window whose surface is an IsoObject as
    -- soon as the player is inside any vehicle.  A VLS cabinet deliberately
    -- uses that same vehicle as its real AnySurfaceCraft object, so suppress
    -- only the vanilla proximity branch while the player is still inside the
    -- same supported vehicle and an approved cabinet remains installed.
    -- Outside that narrow case, including cabinet removal or leaving the
    -- vehicle, the original update path remains authoritative.
    if ISHandcraftWindow
            and ISHandcraftWindow.update
            and ISHandcraftWindow.update
                ~= CraftSurfaceHooks.handcraftWindowUpdateWrapper then
        local previousHandcraftWindowUpdate = ISHandcraftWindow.update

        CraftSurfaceHooks.handcraftWindowUpdateWrapper = function(self)
            local surface = self and self.isoObject or nil
            if surface
                    and instanceof(surface, "BaseVehicle")
                    and VLS.isSupportedVehicle(surface) then
                if not VLS.canUseVehicleGenericCraftSurface(
                        self.player, surface) then
                    self:close()
                    return false
                end

                self.isoObject = nil
                local results = { pcall(previousHandcraftWindowUpdate, self) }
                self.isoObject = surface

                if not results[1] then error(results[2], 0) end
                return unpack(results, 2)
            end

            return previousHandcraftWindowUpdate(self)
        end

        ISHandcraftWindow.update =
            CraftSurfaceHooks.handcraftWindowUpdateWrapper
    end

    if ISInventoryPaneContextMenu
            and ISInventoryPaneContextMenu.OnNewCraft
            and ISInventoryPaneContextMenu.OnNewCraft
                ~= CraftSurfaceHooks.onNewCraftWrapper then
        local previousOnNewCraft = ISInventoryPaneContextMenu.OnNewCraft

        CraftSurfaceHooks.onNewCraftWrapper = function(selectedItem, recipe,
                playerNum, all, eatPercentage)
            local playerObj = type(playerNum) == "number"
                and getSpecificPlayer(playerNum) or playerNum
            local isAnySurfaceRecipe = recipe
                and recipe.isAnySurfaceCraft
                and recipe:isAnySurfaceCraft()

            if not isAnySurfaceRecipe
                    or not VLS.getVehicleGenericCraftSurface(playerObj)
                    or not HandcraftLogic
                    or not HandcraftLogic.new then
                return previousOnNewCraft(selectedItem, recipe, playerNum,
                    all, eatPercentage)
            end

            return withVLSHandcraftLogic(previousOnNewCraft, true, playerObj,
                selectedItem, recipe, playerNum, all, eatPercentage)
        end

        ISInventoryPaneContextMenu.OnNewCraft =
            CraftSurfaceHooks.onNewCraftWrapper
    end

    if ISInventoryPaneContextMenu
            and ISInventoryPaneContextMenu.addNewCraftingDynamicalContextMenu
            and ISInventoryPaneContextMenu.addNewCraftingDynamicalContextMenu
                ~= CraftSurfaceHooks.contextRecipesWrapper then
        local previous = ISInventoryPaneContextMenu.addNewCraftingDynamicalContextMenu
        CraftSurfaceHooks.contextRecipesWrapper = function(selectedItem, context,
                recipeList, playerNum, containerList)
            local playerObj = getSpecificPlayer(playerNum)
            if not VLS.getVehicleGenericCraftSurface(playerObj) then
                return previous(selectedItem, context, recipeList, playerNum, containerList)
            end
            local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
            local recipes = getVLSContextRecipes(selectedItem, playerObj, recipeList, containers)
            return withVLSHandcraftLogic(previous, false, playerObj,
                selectedItem, context, recipes, playerNum, containerList)
        end
        ISInventoryPaneContextMenu.addNewCraftingDynamicalContextMenu =
            CraftSurfaceHooks.contextRecipesWrapper
    end
end

installGenericCraftSurfaceClientHooks()

local function getReachableBed(vehicle, playerObj)
    if not vehicle or not playerObj or playerObj:getVehicle() then return nil end

    if playerObj:DistToProper(vehicle) >= 4
            or not vehicle:isInArea("TruckBed", playerObj) then return nil end

    for _, part in ipairs(VLS.getInstalledBedParts(vehicle)) do
        local seat = VLS.getBedSeat(vehicle, part)
        if seat >= 0 and vehicle:isSeatInstalled(seat)
                and not vehicle:isSeatOccupied(seat) then
            return part, seat
        end
    end
    return nil
end

local function resolveVLSInteractionVehicle(playerObj, evaluator)
    if not playerObj or playerObj:getVehicle() or not evaluator then return nil end

    local seen = {}
    local function resolve(candidate)
        if not candidate or seen[candidate] then return nil end
        seen[candidate] = true
        local first, second, third = evaluator(candidate)
        if first ~= nil then
            return candidate, first, second, third
        end
        return nil
    end

    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    local resolved, first, second, third = resolve(vehicle)
    if resolved then return resolved, first, second, third end

    -- Search nearby squares instead of getCell():getVehicles(), whose B42
    -- collection isn't indexable from Lua. The evaluator keeps each feature's
    -- own reach and interaction-area contract.
    local cell = getCell()
    if not cell then return nil end
    local px, py, pz = math.floor(playerObj:getX()), math.floor(playerObj:getY()),
        math.floor(playerObj:getZ())
    for x = px - 2, px + 2 do
        for y = py - 2, py + 2 do
            local square = cell:getGridSquare(x, y, pz)
            local nearby = square and square:getVehicleContainer()
            local matched, value1, value2, value3 = resolve(nearby)
            if matched then return matched, value1, value2, value3 end
        end
    end
    return nil
end

local function getReachableBedVehicle(playerObj)
    local vehicle, part, seat = resolveVLSInteractionVehicle(
        playerObj, function(candidate)
            return getReachableBed(candidate, playerObj)
        end)
    return part and vehicle or nil, part, seat
end

local function enterBed(playerObj, vehicle, sleepAfterEntry)
    local _, seat = getReachableBed(vehicle, playerObj)
    if not seat then return end

    if not vehicle:isStopped() then
        HaloTextHelper.addBadText(playerObj, getText("IGUI_PlayerText_CanNotEnterMovingCar"))
        return
    end

    if sleepAfterEntry then
        pendingBedSleep[playerObj:getPlayerNum()] = {
            vehicle = vehicle,
            ticks = 600,
        }
    else
        pendingBedRest[playerObj:getPlayerNum()] = {
            player = playerObj,
            vehicle = vehicle,
            ticks = 600,
        }
    end
    ISVehicleMenu.onEnter(playerObj, vehicle, seat)
end

local function stopBedRest(playerObj)
    if not playerObj or not playerObj:isResting() then return end
    if ISTimedActionQueue.hasActionType(playerObj, "ISVLSVehicleRestAction") then
        ISTimedActionQueue.clear(playerObj)
    else
        playerObj:setIsResting(false)
        playerObj:setBed(nil)
    end
end

local function prepareToLeaveBed(playerObj)
    if not playerObj then return end
    local playerNum = playerObj:getPlayerNum()
    pendingBedSleep[playerNum] = nil
    pendingBedRest[playerNum] = nil
    stopBedRest(playerObj)
end

local function isBedEntryComplete(playerObj, vehicle)
    return VLS.isUsingBedSeat(playerObj, vehicle)
        and playerObj:GetVariable("bEnteringVehicle") ~= "true"
        and playerObj:GetVariable("bSwitchingSeat") ~= "true"
end

local function processPendingBedSleep()
    for playerNum, pending in pairs(pendingBedSleep) do
        local playerObj = getSpecificPlayer(playerNum)
        if not playerObj then
            pendingBedSleep[playerNum] = nil
        elseif isBedEntryComplete(playerObj, pending.vehicle) then
            pendingBedSleep[playerNum] = nil
            stopBedRest(playerObj)
            ISVehicleMenu.onSleep(playerObj, pending.vehicle)
        else
            pending.ticks = pending.ticks - 1
            if pending.ticks <= 0 then pendingBedSleep[playerNum] = nil end
        end
    end
end

local function processPendingBedRest()
    for playerNum, pending in pairs(pendingBedRest) do
        local playerObj = getSpecificPlayer(playerNum)
        local vehicle = playerObj and playerObj:getVehicle() or nil
        local playerData = playerObj and getPlayerData(playerNum) or nil
        local sleepModal = playerData and playerData.vehicleSleepModal
        if not playerObj or pending.player ~= playerObj or playerObj:isDead()
                or (vehicle and pending.vehicle ~= vehicle)
                or (pending.entered and not vehicle)
                or playerObj:isAsleep() or pendingBedSleep[playerNum]
                or sleepModal then
            pendingBedRest[playerNum] = nil
        elseif vehicle and isBedEntryComplete(playerObj, pending.vehicle) then
            pendingBedRest[playerNum] = nil
            ISTimedActionQueue.add(ISVLSVehicleRestAction:new(playerObj))
        else
            -- Walking to the door / entering / changing seats are asynchronous.
            -- A player still outside the car is not an immediate cancellation.
            if vehicle then pending.entered = true end
            pending.ticks = pending.ticks - 1
            if pending.ticks <= 0 then pendingBedRest[playerNum] = nil end
        end
    end
end

local function processBedState()
    processPendingBedSleep()
    processPendingBedRest()
end

local function getSleepSlice(playerObj, vehicle)
    if isClient() and not getServerOptions():getBoolean("SleepAllowed") then return nil, false end

    local sleepNeeded = not isClient() or getServerOptions():getBoolean("SleepNeeded")
    local stats = playerObj:getStats()
    local isZombies = stats:getNumVisibleZombies() > 0
        or stats:getNumChasingZombies() > 0
        or stats:getNumVeryCloseZombies() > 0

    if sleepNeeded and stats:get(CharacterStat.FATIGUE) <= 0.3 then
        return getText("IGUI_Sleep_NotTiredEnough"), false
    elseif not vehicle:isStopped() then
        return getText("IGUI_PlayerText_CanNotSleepInMovingCar"), false
    elseif sleepNeeded and isZombies then
        return getText("IGUI_Sleep_NotSafe"), false
    elseif sleepNeeded and (playerObj:getHoursSurvived() - playerObj:getLastHourSleeped()) <= 1 then
        return getText("ContextMenu_NoSleepTooEarly"), false
    elseif playerObj:getSleepingTabletEffect() < 2000 then
        if playerObj:getMoodles():getMoodleLevel(MoodleType.PAIN) >= 2
                and stats:get(CharacterStat.FATIGUE) <= 0.85 then
            return getText("ContextMenu_PainNoSleep"), false
        elseif playerObj:getMoodles():getMoodleLevel(MoodleType.PANIC) >= 1 then
            return getText("ContextMenu_PanicNoSleep"), false
        end
    end

    return getText("ContextMenu_Sleep"), true
end

local function sendApplianceCommand(playerObj, command, args)
    if isClient() then
        sendClientCommand(playerObj, VLS.MOD_ID, command, args)
    elseif VLS.Server and VLS.Server[command] then
        VLS.Server[command](playerObj, args)
    end
end

local function newMicrowaveProxy(vehicle, part, playerObj)
    local proxy = {
        vehicle = vehicle,
        part = part,
        playerObj = playerObj,
        isVLSMicrowaveProxy = true,
        itemId = part:getInventoryItem():getID(),
    }
    proxy.power = {
        isPowered = function()
            return VLS.hasAuxBatteryPower(vehicle, VLS.getMicrowaveDrainPerMinute())
        end,
    }

    function proxy:getData()
        return self.part:getModData()
    end

    function proxy:getContainer()
        return self.power
    end

    function proxy:getX() return self.vehicle:getX() end
    function proxy:getY() return self.vehicle:getY() end
    function proxy:getZ() return self.vehicle:getZ() end

    function proxy:getTimer()
        return self.pendingTimer or self:getData().vlsMicrowaveTimer or 0
    end

    function proxy:setTimer(timer)
        self.pendingTimer = math.max(0, math.min(3600, timer or 0))
    end

    function proxy:getMaxTemperature()
        return self.pendingTemperature or self:getData().vlsMicrowaveTemperature or 90
    end

    function proxy:setMaxTemperature(temperature)
        self.pendingTemperature = math.max(50, math.min(130, temperature or 90))
    end

    function proxy:isRunningFor()
        local data = self:getData()
        if not data.vlsMicrowaveActive then return 0 end
        return math.max(0, self:getTimer() - (data.vlsMicrowaveRemaining or 0))
    end

    function proxy:Activated()
        return self:getData().vlsMicrowaveActive == true
    end

    function proxy:sync()
        local item = self.part:getInventoryItem()
        if not item or item:getID() ~= self.itemId
                or self.playerObj:getVehicle() ~= self.vehicle then return end
        sendApplianceCommand(self.playerObj, "setMicrowaveParams", {
            vehicle = self.vehicle:getId(),
            part = self.part:getId(),
            item = self.itemId,
            timer = self:getTimer(),
            temperature = self:getMaxTemperature(),
        })
    end

    return proxy
end

-- ISMicrowaveUI.initialise stores its Close BUTTON in ui.close. Do not call
-- ui:close(), which tries to call that button table instead of a method.
local function closeVLSMicrowaveWindow(ui)
    if not ui then return end
    ui:setVisible(false)
    ui:removeFromUIManager()
    local playerNum = ui.character and ui.character:getPlayerNum() or ui.playerNum
    if playerNum ~= nil and ISMicrowaveUI.instance
            and ISMicrowaveUI.instance[playerNum + 1] == ui then
        ISMicrowaveUI.instance[playerNum + 1] = nil
    end
    local pad = playerNum ~= nil and JoypadState.players[playerNum + 1]
    if pad and pad.focus == ui then setJoypadFocus(playerNum, ui.prevFocus) end
end

-- VLS_MICROWAVE_PAD_BASELINE_FIX1: honour the A/B shortcuts before focused knobs.
-- The generic parent consumes A on the focused knob (or another button).
-- Dispatch the intended button once; forceClick keeps its enabled/visible checks.
local function onVLSMicrowaveJoypadDown(ui, button, joypadData)
    if button == Joypad.AButton then
        -- Re-evaluate power before invoking the SAME callback as the mouse.
        -- Never force-enable the button and never dispatch through the knob.
        if ui.updateButtons then ui:updateButtons() end
        print("[VLS 3.8.8] microwave A received; enabled="
            .. tostring(ui.ok and ui.ok.enable))
        if ui.ok then ui.ok:forceClick() end
        return
    end
    if button == Joypad.BButton then
        if ui.close then ui.close:forceClick() end
        return
    end
    return ISPanelJoypad.onJoypadDown(ui, button, joypadData)
end

local function isVLSMicrowaveWindowValid(ui, proxy)
    local playerObj = ui and ui.character or nil
    local vehicle = proxy and proxy.vehicle or nil
    local part = proxy and proxy.part or nil
    local item = part and part:getInventoryItem() or nil
    return playerObj and vehicle and part
        and playerObj:getVehicle() == vehicle
        and VLS.getInstalledPart(vehicle, part:getId()) == part
        and item and item:getID() == proxy.itemId
        and VLS.getEquipmentCapability(item) == "cooking"
end

local function installMicrowaveWindowClientHook()
    if not ISMicrowaveUI or not ISMicrowaveUI.update
            or ISMicrowaveUI.update == MicrowaveWindowHooks.updateWrapper then
        return
    end

    local previousMicrowaveWindowUpdate = ISMicrowaveUI.update
    MicrowaveWindowHooks.updateWrapper = function(self)
        local proxy = self and self.oven or nil
        if not proxy or proxy.isVLSMicrowaveProxy ~= true then
            return previousMicrowaveWindowUpdate(self)
        end

        if not isVLSMicrowaveWindowValid(self, proxy) then
            closeVLSMicrowaveWindow(self)
            return
        end

        -- Vanilla closes a microwave panel when the player is more than three
        -- tiles from the IsoStove.  A VLS microwave is a vehicle-part proxy,
        -- and a seat in a long camper can legitimately be farther than three
        -- tiles from the vehicle origin.  Preserve the complete vanilla update
        -- while making its distance probe represent the already-validated
        -- same-vehicle interaction for this call only.
        local previousGetX = proxy.getX
        local previousGetY = proxy.getY
        proxy.getX = function() return self.character:getX() end
        proxy.getY = function() return self.character:getY() end
        local results = { pcall(previousMicrowaveWindowUpdate, self) }
        proxy.getX = previousGetX
        proxy.getY = previousGetY

        if not results[1] then error(results[2], 0) end
        return unpack(results, 2)
    end

    ISMicrowaveUI.update = MicrowaveWindowHooks.updateWrapper
end

installMicrowaveWindowClientHook()

local function onVLSMicrowaveClick(ui, button)
    if button.internal == "CLOSE" then
        closeVLSMicrowaveWindow(ui)
        return
    end
    if button.internal ~= "OK" then return end

    local proxy = ui.oven
    if not isVLSMicrowaveWindowValid(ui, proxy) then closeVLSMicrowaveWindow(ui); return end
    if not proxy:Activated() and not proxy:getContainer():isPowered() then
        HaloTextHelper.addBadText(ui.character, getText("ContextMenu_VLSNoAuxPower"))
        return
    end

    ui.character:getEmitter():playSound("ToggleStove")
    local requestedTimer = math.max(60, ui.timerKnob:getValue() * 60)
    proxy.pendingTimer = requestedTimer
    sendApplianceCommand(ui.character, "toggleMicrowave", {
        vehicle = proxy.vehicle:getId(),
        part = proxy.part:getId(),
        item = proxy.itemId,
        -- A start with a zero timer otherwise looks like a dead On button.
        active = not proxy:Activated(),
        timer = requestedTimer,
        temperature = ui.tempKnob:getValue(),
    })
end

local function openMicrowaveSettings(playerObj, vehicle, part)
    if not playerObj or playerObj:getVehicle() ~= vehicle
            or VLS.getInstalledPart(vehicle, part and part:getId()) ~= part
            or VLS.getEquipmentCapability(part:getInventoryItem()) ~= "cooking" then
        return
    end

    local playerNum = playerObj:getPlayerNum()
    local previous = ISMicrowaveUI.instance
        and ISMicrowaveUI.instance[playerNum + 1]
    if previous then
        previous:removeFromUIManager()
        previous:setVisible(false)
        ISMicrowaveUI.instance[playerNum + 1] = nil
    end

    local ui = ISMicrowaveUI:new(0, 0, 430, 280,
        newMicrowaveProxy(vehicle, part, playerObj), playerObj)
    ui:initialise()
    ui.onClick = onVLSMicrowaveClick
    ui.ok.onclick = onVLSMicrowaveClick
    ui.close.onclick = onVLSMicrowaveClick
    ui.onJoypadDown = onVLSMicrowaveJoypadDown
    ui:addToUIManager()
    print("[VLS 3.8.8] microwave window uses direct A/B dispatch")

    if JoypadState.players[playerNum + 1] then
        ui.prevFocus = JoypadState.players[playerNum + 1].focus
        setJoypadFocus(playerNum, ui)
    end
end

local function getLootMicrowave(handler)
    if not handler or not instanceof(handler.object, "BaseVehicle")
            or not handler.container or not handler.playerObj then return nil, nil end
    local part = handler.container:getVehiclePart()
    local vehicle = part and part:getVehicle()
    if vehicle ~= handler.object or handler.playerObj:getVehicle() ~= vehicle
            or VLS.getInstalledPart(vehicle, part and part:getId()) ~= part
            or VLS.getEquipmentCapability(part:getInventoryItem()) ~= "cooking" then
        return nil, nil
    end
    return vehicle, part
end

ISLootWindowObjectControlHandler_VLSMicrowaveSettings =
    ISLootWindowObjectControlHandler:derive(
        "ISLootWindowObjectControlHandler_VLSMicrowaveSettings")
local VLSMicrowaveSettingsHandler =
    ISLootWindowObjectControlHandler_VLSMicrowaveSettings

function VLSMicrowaveSettingsHandler:shouldBeVisible()
    local _, part = getLootMicrowave(self)
    return part ~= nil
end

function VLSMicrowaveSettingsHandler:getControl()
    return self:getButtonControl(getText("ContextMenu_StoveSetting"))
end

function VLSMicrowaveSettingsHandler:handleJoypadContextMenu(context)
    local option = self:addJoypadContextMenuOption(context,
        getText("ContextMenu_StoveSetting"))
    option.iconTexture = ContainerButtonIcons.microwave
end

function VLSMicrowaveSettingsHandler:perform()
    local vehicle, part = getLootMicrowave(self)
    if part then openMicrowaveSettings(self.playerObj, vehicle, part) end
end

function VLSMicrowaveSettingsHandler:new()
    local o = ISLootWindowObjectControlHandler.new(self)
    o.altColor = true
    return o
end

ISLootWindowObjectControlHandler_VLSMicrowaveToggle =
    ISLootWindowObjectControlHandler:derive(
        "ISLootWindowObjectControlHandler_VLSMicrowaveToggle")
local VLSMicrowaveToggleHandler = ISLootWindowObjectControlHandler_VLSMicrowaveToggle

function VLSMicrowaveToggleHandler:shouldBeVisible()
    local _, part = getLootMicrowave(self)
    return part ~= nil
end

local function getMicrowaveToggleText(part)
    return getText(part:getModData().vlsMicrowaveActive
        and "ContextMenu_Turn_Off" or "ContextMenu_Turn_On")
end

function VLSMicrowaveToggleHandler:getControl()
    local _, part = getLootMicrowave(self)
    return self:getButtonControl(getMicrowaveToggleText(part))
end

function VLSMicrowaveToggleHandler:handleJoypadContextMenu(context)
    local _, part = getLootMicrowave(self)
    local option = self:addJoypadContextMenuOption(context,
        getMicrowaveToggleText(part))
    option.iconTexture = ContainerButtonIcons.microwave
end

function VLSMicrowaveToggleHandler:perform()
    local vehicle, part = getLootMicrowave(self)
    if not part then return end
    local data = part:getModData()
    if data.vlsMicrowaveActive then
        sendApplianceCommand(self.playerObj, "stopMicrowave", {
            vehicle = vehicle:getId(),
            part = part:getId(),
            item = part:getInventoryItem():getID(),
        })
        return
    end
    if not VLS.hasAuxBatteryPower(vehicle, VLS.getMicrowaveDrainPerMinute()) then
        HaloTextHelper.addBadText(self.playerObj, getText("ContextMenu_VLSNoAuxPower"))
        return
    end
    sendApplianceCommand(self.playerObj, "toggleMicrowave", {
        vehicle = vehicle:getId(),
        part = part:getId(),
        item = part:getInventoryItem():getID(),
        active = true,
        timer = math.max(60, data.vlsMicrowaveTimer or 0),
        temperature = data.vlsMicrowaveTemperature or 90,
    })
end

function VLSMicrowaveToggleHandler:new()
    local o = ISLootWindowObjectControlHandler.new(self)
    o.altColor = true
    return o
end

-- AddHandler updates an existing handler with the same Type. Register on
-- every client Lua load so reconnect/reload cannot leave stale classes.
ISLootWindowContainerControls.AddHandler(VLSMicrowaveSettingsHandler, true)
ISLootWindowContainerControls.AddHandler(VLSMicrowaveToggleHandler, true)

local function onVLSFluidTransferClick(ui, button)
    if button.internal ~= "TRANSFER" then return vanillaFluidOnButton(ui, button) end
    local source, target = ui.panelLeft.container, ui.panelRight.container
    if not source or not target then return end
    if not source.vlsVehicleFluidEndpoint and not target.vlsVehicleFluidEndpoint then
        return vanillaFluidOnButton(ui, button)
    end
    if ui.disableTransfer then return end
    local request = VLS.makeVehicleFluidTransferRequest(ui.player, source,
        target, ui.info.transferring)
    if not request then return end
    local action = VLSVehicleFluidTransferAction:new(ui.player, request.vehicle,
        request.source.part or "", request.source.item,
        request.target.part or "", request.target.item, request.amount)
    if not action:isValid() then return end
    -- The existing panel already tracks native actions, progress and unlocks
    -- on completion/cancel. No second request/ACK/timeout state machine.
    ui.action = action
    ISTimedActionQueue.add(action)
    ui.slider:setCurrentValue(0)
    ui.disableTransfer = true
    ui.panelLeft:setPanelLocked(true)
    ui.panelRight:setPanelLocked(true)
end

local function refreshVLSFluidPanelEndpoint(ui, panel)
    local endpoint = panel and panel.container
    if not endpoint or not endpoint.vlsVehicleFluidEndpoint then return end
    local oldFluid = endpoint:getFluidContainer()
    if not VLS.refreshVehicleFluidEndpoint(endpoint, ui.player) then return end
    local newFluid = endpoint:getFluidContainer()
    if oldFluid == newFluid then return end

    panel.fluidBar:setContainer(newFluid)
    if panel.containerCopy then FluidContainer.DisposeContainer(panel.containerCopy) end
    panel.containerCopy = newFluid:copy()
end

local function updateVLSFluidTransfer(ui)
    refreshVLSFluidPanelEndpoint(ui, ui.panelLeft)
    refreshVLSFluidPanelEndpoint(ui, ui.panelRight)
    vanillaFluidUpdate(ui)

end

local function refreshVLSFluidEndpointCatalog(ui)
    local playerObj = ui and ui.player
    local vehicle = playerObj and playerObj:getVehicle()
    local list = vehicle and VLS.getInstalledVehicleFluidEndpoints(vehicle) or {}
    local byItemId = {}
    for _, record in ipairs(list) do
        byItemId[record.item:getID()] = record
    end
    ui.vlsVehicleFluidEndpoints = byItemId
    return list, byItemId
end

local function getVLSVehicleFluidRecord(ui, item)
    if not item then return nil end
    local _, byItemId = refreshVLSFluidEndpointCatalog(ui)
    return byItemId[item:getID()]
end

local function resetVLSFluidPanelPreviousOwner(ui, panel)
    if panel == ui.panelLeft then
        ui.fromPreviousOwner = nil
    elseif panel == ui.panelRight then
        ui.toPreviousOwner = nil
    end
end

local function onVLSVehicleFluidEndpointSelected(dropBox, item)
    local panel = dropBox and dropBox.parent
    local ui = panel and panel.parent
    if not ui or not item then return end

    local record = getVLSVehicleFluidRecord(ui, item)
    if not record then return end
    local playerObj = ui.player
    local vehicle = playerObj and playerObj:getVehicle()
    local fluidItem, part
    if vehicle then
        fluidItem, part = VLS.getVehicleFluidItem(
            vehicle, record.part:getId())
    end
    if not fluidItem or not part or fluidItem:getID() ~= item:getID()
            or not fluidItem:getFluidContainer() then return end

    local endpoint = VLSVehicleFluidContainer:new(
        fluidItem:getFluidContainer(), playerObj, vehicle, fluidItem, part)
    if not VLS.isVehicleFluidContainerValid(endpoint, playerObj) then return end

    panel.itemDropBox:setStoredItem(fluidItem)
    panel.container = endpoint
    panel.fluidBar:setContainer(endpoint:getFluidContainer())
    if panel.containerCopy then
        FluidContainer.DisposeContainer(panel.containerCopy)
    end
    panel.containerCopy = endpoint:getFluidContainer():copy()
    resetVLSFluidPanelPreviousOwner(ui, panel)
    vanillaFluidOnContainerAdd(ui, fluidItem, panel)
end

local function panelHasVehicleEndpoint(panel)
    return panel and panel.container
        and panel.container.vlsVehicleFluidEndpoint == true
end

local function onVLSFluidDropBoxMouseDown(dropBox, x, y)
    local panel = dropBox.parent
    local ui = panel and panel.parent
    if not ui or not ui.vlsVehicleFluidEndpoints then
        return vanillaFluidPanelClickedDropBox(dropBox, x, y)
    end

    local otherPanel = panel == ui.panelLeft and ui.panelRight or ui.panelLeft
    local otherItemId = panelHasVehicleEndpoint(otherPanel)
        and otherPanel.container.vlsFluidItemId or nil
    local records, byItemId = refreshVLSFluidEndpointCatalog(ui)

    local vanillaItems = dropBox:getValidItems()
    local validItems = {}
    for _, item in ipairs(vanillaItems) do
        if not byItemId[item:getID()] then table.insert(validItems, item) end
    end

    local playerNum = ui.player:getPlayerNum()
    local pad = JoypadState.players[playerNum + 1]
    local oldFocus = pad and pad.focus or nil
    local context
    if #validItems > 0 then
        local originalGetValidItems = dropBox.getValidItems
        dropBox.getValidItems = function() return validItems end
        local succeeded, result = pcall(
            vanillaFluidPanelClickedDropBox, dropBox, x, y)
        dropBox.getValidItems = originalGetValidItems
        if not succeeded then error(result) end
        context = getPlayerContextMenu(playerNum)
    else
        if #records == 0 then return end
        local contextX = ui:getAbsoluteX() + ui:getWidth()
        local contextY = ui:getAbsoluteY() + panel:getY()
        context = ISContextMenu.get(playerNum, contextX, contextY)
    end

    for index = #records, 1, -1 do
        local record = records[index]
        local fluidItem = record.item
        if fluidItem:getID() ~= otherItemId then
            local amount = fluidItem:getFluidContainer():getAmount() * 1000
            local name = VLS.getPartDisplayName(record.part,
                fluidItem:getDisplayName())
                .. " (" .. round(amount, 2) .. " mL)"
            context:addOptionOnTop(name, dropBox,
                onVLSVehicleFluidEndpointSelected, fluidItem)
        end
    end
    if panel.isLeft then
        local leftX = ui:getAbsoluteX() - context:getWidth()
        context:setSlideGoalX(leftX + 20, leftX)
    end
    context:bringToTop()
    if pad and #context.options > 0 then
        context.origin = oldFocus or ui
        context.mouseOver = 1
        setJoypadFocus(playerNum, context)
    end
end

local function configureVLSFluidPanel(ui, panel)
    if panel.itemDropBox then
        panel.itemDropBox.onMouseDown = onVLSFluidDropBoxMouseDown
    end
end

local function openVehicleFluidTransfer(playerObj, vehicle, fluidItem, part)
    if not playerObj or playerObj:getVehicle() ~= vehicle
            or not part then return end
    local installedItem = VLS.getVehicleFluidItem(vehicle, part:getId())
    if installedItem ~= fluidItem then return end

    local endpoint = VLSVehicleFluidContainer:new(
        fluidItem:getFluidContainer(), playerObj, vehicle, fluidItem, part)
    if not VLS.isVehicleFluidContainerValid(endpoint, playerObj) then return end

    local playerNum = playerObj:getPlayerNum()
    local state = ISFluidTransferUI.players[playerNum]
    local x, y = getMouseX() + 10, getMouseY() + 10
    if state and state.instance then
        state.instance:close()
        if state.x and state.y then x, y = state.x, state.y end
    else
        state = {}
        ISFluidTransferUI.players[playerNum] = state
    end

    local ui = ISFluidTransferUI:new(x, y, 400, 600, playerObj, endpoint)
    ui:initialise()
    ui:instantiate()
    ui.vlsVehicleFluidEndpoints = {}
    refreshVLSFluidEndpointCatalog(ui)
    ui.onButton = onVLSFluidTransferClick
    ui.btnTransfer.onclick = onVLSFluidTransferClick
    ui.update = updateVLSFluidTransfer
    configureVLSFluidPanel(ui, ui.panelLeft)
    configureVLSFluidPanel(ui, ui.panelRight)
    ui:setVisible(true)
    ui:addToUIManager()
    state.instance = ui

    if getJoypadData(playerNum) then
        ui:centerOnScreen(playerNum)
        state.x, state.y = ui.x, ui.y
        setJoypadFocus(playerNum, ui)
    end
end

local locallyCooledFood = {}
local coolingSnapshots = {}
local coolingRequests = {}

local function coolingKey(vehicleId, partId)
    return tostring(vehicleId) .. ":" .. tostring(partId)
end

local function onVLSAuditServerCommand(module, command, args)
    if module ~= VLS.MOD_ID or type(args) ~= "table" then return end
    if command == "fluidTransferResult" then
        onVLSFluidTransferResult(args)
    elseif command == "coolingSnapshot" and type(args.entries) == "table"
            and type(args.sequence) == "number" and type(args.epoch) == "number"
            and type(args.hours) == "number" and args.part then
        local key = coolingKey(args.vehicle, args.part)
        local old = coolingSnapshots[key]
        if old and (args.epoch < old.epoch or (args.epoch == old.epoch
                and args.sequence < old.sequence)) then return end
        if not old or old.epoch ~= args.epoch or old.sequence ~= args.sequence then
            old = { epoch = args.epoch, sequence = args.sequence,
                hours = args.hours, entries = {} }
            coolingSnapshots[key] = old
        end
        old.received = getTimestampMs()
        for _, entry in ipairs(args.entries) do
            if type(entry.id) == "number" and type(entry.age) == "number"
                    and type(entry.freezing) == "number" and type(entry.heat) == "number" then
                old.entries[entry.id] = entry
            end
        end
    end
end

if not VLS.auditServerReplyHook then
    VLS.auditServerReplyHook = true
    Events.OnServerCommand.Add(onVLSAuditServerCommand)
end

local function requestCoolingSnapshot(playerObj, vehicle, partId)
    if not isClient() then return end
    local key = coolingKey(vehicle:getId(), partId)
    local now = getTimestampMs()
    local sample = coolingSnapshots[key]
    if sample and now - sample.received >= 0
            and now - sample.received < 5000 then return end
    local prior = coolingRequests[key]
    if prior and now >= prior and now - prior < 2000 then return end
    coolingRequests[key] = now
    sendApplianceCommand(playerObj, "requestCoolingSnapshot", {
        vehicle = vehicle:getId(), part = partId })
end

local function protectCooledFood(item, currentHours, vehicleId, containerId,
        freezer, seen)
    if not instanceof(item, "Food") then return end
    local itemId = item:getID()
    seen[itemId] = true
    -- Single-player uses the server simulation in this same process.
    if not isClient() then return end
    local snapshot = coolingSnapshots[coolingKey(vehicleId, containerId)]
    local now = getTimestampMs()
    if not snapshot or now < snapshot.received or now - snapshot.received > 15000 then
        locallyCooledFood[itemId] = nil
        return
    end
    local authoritative = snapshot.entries[itemId]
    if not authoritative then return end
    local state = locallyCooledFood[itemId]
    if not state or state.vehicleId ~= vehicleId or state.containerId ~= containerId
            or state.epoch ~= snapshot.epoch or state.sequence ~= snapshot.sequence then
        -- Accept a NEW server snapshot in BOTH directions. Numeric min/max is
        -- not a test for authority. Prediction never becomes the next baseline.
        state = { age = authoritative.age, freezing = authoritative.freezing,
            heat = authoritative.heat, lastHours = snapshot.hours,
            vehicleId = vehicleId, containerId = containerId,
            epoch = snapshot.epoch, sequence = snapshot.sequence }
        locallyCooledFood[itemId] = state
    end
    local elapsed = math.min(1 / 60, math.max(0, currentHours - state.lastHours))
    local age,freezing=VLS.getPoweredFoodProgress(item,state.age,
        state.freezing,elapsed,freezer)
    item:setAge(age)
    VLS.preservePoweredFoodHeat(item, state, freezer and 0.1 or 0.2)
    item:setFreezingTime(freezing)
    item:setLastAged(currentHours)
end



-- The vanilla page can retain its selected container while hidden/collapsed.
-- Keep this gate identical to ISInventoryPage's visible-container contract.
local function getVisibleAppliancePane(page)
    local pane = page and page.inventoryPane
    if not pane or page.isCollapsed or not page:isReallyVisible()
            or not pane:isReallyVisible() then return nil end
    return pane
end

local visibleContainerPasses = setmetatable({}, { __mode = "k" })

local function processVisibleAppliances(refreshedPage)
    local seen, seenContainers, seenEnvironments = {}, {}, {}
    local currentHours = getGameTime():getWorldAgeHours()
    local foundVisibleVLSContainer = false
    local nextCheckTick

    local function retainFoodIds(itemIds)
        for itemId in pairs(itemIds) do seen[itemId] = true end
    end

    local function processPage(page)
        local pane = getVisibleAppliancePane(page)
        local container = pane and pane.inventory
        if not container then return end
        local prior = seenContainers[container]
        if prior then
            if prior.namesChanged and not prior.panes[pane] then
                pane:refreshContainer()
                prior.panes[pane] = true
            end
            return
        end
        local part = getVLSAppliancePart(container)
        if not part then return end
        local vehicle = part:getVehicle()
        local freezer = VLS.isFreezerPart(part)
        local universalPart = part
        if freezer then
            local universalId = VLS.UNIVERSAL_PART_BY_FREEZER[part:getId()]
            universalPart = universalId
                and VLS.getInstalledPart(vehicle, universalId) or nil
        end
        if not universalPart then return end
        foundVisibleVLSContainer = true
        local pass = { panes = { [pane] = true } }
        seenContainers[container] = pass
        local cached = visibleContainerPasses[container]
        -- A real inventory refresh must always inspect its final selection.
        -- Only the periodic fallback can reuse a more recent event-driven pass.
        if not refreshedPage and cached and cached.part == part
                and cached.item == universalPart:getInventoryItem()
                and clientTickCounter - cached.tick < 30 then
            retainFoodIds(cached.itemIds)
            local due = cached.tick + 30
            nextCheckTick = nextCheckTick and math.min(nextCheckTick, due) or due
            return
        end

        if not seenEnvironments[universalPart] then
            VLS.refreshApplianceEnvironment(vehicle, universalPart, false)
            seenEnvironments[universalPart] = true
        end
        local cooling = VLS.getEquipmentCapability(
            universalPart:getInventoryItem()) == "cooling"
            and VLS.hasAuxBatteryPower(vehicle, VLS.getFridgeDrainPerMinute())
        local containerId, vehicleId = part:getId(), vehicle:getId()
        if cooling then
            for playerNum = 0, 3 do
                local playerObj = getSpecificPlayer(playerNum)
                if playerObj and playerObj:getVehicle() == vehicle then
                    requestCoolingSnapshot(playerObj, vehicle, containerId)
                    break
                end
            end
        end
        local itemIds = {}
        local namesChanged = false
        VLS.walkApplianceContainer(container, function(item)
            if restoreOfficialVLSFoodName(item) then namesChanged = true end
            if cooling then
                protectCooledFood(item, currentHours, vehicleId,
                    containerId, freezer, itemIds)
            end
        end)
        retainFoodIds(itemIds)
        visibleContainerPasses[container] = {
            tick = clientTickCounter, part = part,
            item = universalPart:getInventoryItem(), itemIds = itemIds,
        }
        pass.namesChanged = namesChanged
        -- Vanilla refreshContainer groups items by name before the "end" event.
        -- Rebuild that grouping only when a server-supplied base name changed.
        if namesChanged then pane:refreshContainer() end
    end

    if refreshedPage then
        processPage(refreshedPage)
        return
    end
    for playerNum = 0, 3 do processPage(getPlayerLoot(playerNum)) end

    for container in pairs(visibleContainerPasses) do
        if not seenContainers[container] then visibleContainerPasses[container] = nil end
    end
    if not foundVisibleVLSContainer then
        table.wipe(locallyCooledFood)
        table.wipe(coolingSnapshots)
        table.wipe(coolingRequests)
        return
    end
    for itemId in pairs(locallyCooledFood) do
        if not seen[itemId] then locallyCooledFood[itemId] = nil end
    end
    local now = getTimestampMs()
    for key, sample in pairs(coolingSnapshots) do
        if now < sample.received or now - sample.received > 15000 then
            coolingSnapshots[key] = nil
            coolingRequests[key] = nil
        end
    end
    return nextCheckTick
end

local function processClientState()
    clientTickCounter = clientTickCounter + 1
    processBedState()
    coolingTickCounter = coolingTickCounter + 1
    if coolingTickCounter >= 30 then
        coolingTickCounter = 0
        local nextCheckTick = processVisibleAppliances()
        if nextCheckTick then
            -- Do not turn event deduplication into a 60-tick cooling gap.
            coolingTickCounter = math.max(0, 30 - (nextCheckTick - clientTickCounter))
        end
    end
end

local function openTelevisionSettings(playerObj, vehicle, part)
    VLS.syncTelevisionDevice(vehicle, part, false)
    local devicePart = VLS.getTelevisionDevicePart(part)
    if devicePart and VLS.getTelevisionDeviceData(part) then
        ISRadioWindow.activate(playerObj, devicePart)
    end
end

-- The television menu itself is entirely vanilla. Only the power action for
-- VLS's itemless companion device is redirected to the shared auxiliary-
-- battery authority used by the other living appliances.
local function getVLSTelevisionForDevice(devicePart)
    if not devicePart or not instanceof(devicePart, "VehiclePart") then
        return nil
    end
    local vehicle = devicePart:getVehicle()
    local universalId = VLS.UNIVERSAL_PART_BY_FREEZER[devicePart:getId()]
    local part = universalId and VLS.getInstalledPart(vehicle, universalId)
        or nil
    if not part or VLS.getEquipmentCapability(part:getInventoryItem())
            ~= "television"
            or VLS.getTelevisionDevicePart(part) ~= devicePart then
        return nil
    end
    return part
end

-- Television media-action parameters are adapted in shared VLS_Config.lua
-- so client and server resolve the same stable vehicle/part descriptor.
if not VLS.televisionPowerActionHookApplied then
    VLS.televisionPowerActionHookApplied = true
    local vanillaRadioToggleValid = ISRadioAction.isValidToggleOnOff
    local vanillaRadioTogglePerform = ISRadioAction.performToggleOnOff

    function ISRadioAction:isValidToggleOnOff()
        local part = getVLSTelevisionForDevice(self.device)
        if not part then return vanillaRadioToggleValid(self) end
        local data = VLS.getTelevisionDeviceData(part)
        return data ~= nil and (data:getIsTurnedOn()
            or VLS.hasAuxBatteryPower(part:getVehicle(),
                VLS.getTelevisionDrainPerMinute()))
    end

    function ISRadioAction:performToggleOnOff()
        local part = getVLSTelevisionForDevice(self.device)
        if not part then return vanillaRadioTogglePerform(self) end
        if not self:isValidToggleOnOff() then return end
        local data = VLS.getTelevisionDeviceData(part)
        local vehicle = part:getVehicle()

        -- DeviceData:setIsTurnedOn() owns the vanilla client/server state
        -- packet. Present the shared auxiliary battery through the narrowest
        -- possible adapter, invoke the untouched vanilla toggle, then restore
        -- the companion device metadata before the window reads it again.
        data:setIsBatteryPowered(true)
        data:setPower(VLS.getAuxBatteryCharge(vehicle))
        local succeeded, result = pcall(vanillaRadioTogglePerform, self)
        data:setIsBatteryPowered(false)
        data:setHasBattery(false)
        data:setPower(VLS.getAuxBatteryCharge(vehicle))
        if not succeeded then error(result) end
        return result
    end
end

local function addInsideEquipmentSlice(menu, playerObj)
    local vehicle = playerObj and playerObj:getVehicle()
    if not menu or not VLS.isSupportedVehicle(vehicle) then return end

    local televisions = VLS.getInstalledCapabilityParts(vehicle, "television")
    for _, television in ipairs(televisions) do
        VLS.syncTelevisionDevice(vehicle, television, false)
        if VLS.getTelevisionDeviceData(television) then
            menu:addSlice(getText("IGUI_DeviceOptions"), TELEVISION_ICON,
                openTelevisionSettings, playerObj, vehicle, television)
        end
    end

    local fluidItem, fluidPart = VLS.getInstalledWaterTank(vehicle)
    if not fluidItem then
        fluidItem, fluidPart = VLS.getInstalledWaterBottle(vehicle)
    end
    if not fluidItem then return end
    menu:addSlice(getText("Fluid_Transfer_Fluids"), WATER_ICON,
        openVehicleFluidTransfer, playerObj, vehicle, fluidItem, fluidPart)
end

local function getNearbyWaterSource(vehicle, tankPart)
    if not vehicle or not tankPart then return nil end
    local center = vehicle:getAreaCenter(tankPart:getArea())
    if not center then return nil end
    local centerSquare = getCell():getGridSquare(center:getX(), center:getY(),
        vehicle:getZ())
    if not centerSquare then return nil end
    local range = VLS.WATER_TANK_SOURCE_RANGE
    for dy = -range, range do
        for dx = -range, range do
            local square = getCell():getGridSquare(centerSquare:getX() + dx,
                centerSquare:getY() + dy, centerSquare:getZ())
            local objects = square and square:getObjects() or nil
            if objects then
                for index = 0, objects:size() - 1 do
                    local object = objects:get(index)
                    if VLS.getTankWaterSourceAmount(object) > 0
                            and VLS.isWaterSourceNearTank(vehicle, tankPart,
                                object) then
                        return object
                    end
                end
            end
        end
    end
    return nil
end

local function fillVehicleWaterTank(playerObj, vehicle, tankPart, tank,
        source)
    if not VLS.isWaterTankShortcutEnabled() or not playerObj or playerObj:getVehicle() or not source
            or VLS.getInstalledWaterTank(vehicle,
                tankPart:getId()) ~= tank then return end
    if VLS.getWaterTankFillAmount(vehicle, tank, source) <= 0 then return end
    local path = ISPathFindAction:pathToVehicleArea(playerObj,
        vehicle, tankPart:getArea())
    path:setOnFail(function(character)
        HaloTextHelper.addBadText(character,
            getText("IGUI_PlayerText_NoWayToFuelTankInlet"))
    end, playerObj)
    ISTimedActionQueue.add(path)
    ISTimedActionQueue.add(VLSFillVehicleWaterTankAction:new(playerObj,
        tankPart, source))
end

local function getFillableWaterInteraction(vehicle, playerObj)
    if not VLS.isWaterTankShortcutEnabled() then return end
    if not vehicle or vehicle:isEngineStarted() or not vehicle:isStopped()
            or playerObj:DistToProper(vehicle) >= 4 then return nil end
    local tank, part = VLS.getFillableWaterTank(vehicle)
    if not part then return nil end
    if not VLS.isPlayerAtWaterTankInlet(vehicle, part, playerObj) then return nil end
    local fluid = tank and tank:getFluidContainer()
    if not fluid or fluid:getAmount() >= fluid:getCapacity() then return nil end
    local source = getNearbyWaterSource(vehicle, part)
    if not source or VLS.getWaterTankFillAmount(vehicle, tank, source) <= 0 then
        return nil
    end
    return tank, part, source
end

local function addOutsideWaterTankSlice(menu, playerObj)
    if not playerObj or playerObj:getVehicle() then return end
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    local tank, part, source = getFillableWaterInteraction(vehicle, playerObj)
    if not tank then return end
    menu:addSlice(getText("ContextMenu_VLSFillWaterTank"), WATER_FILL_ICON,
        fillVehicleWaterTank, playerObj, vehicle, part, tank, source)
end

local function addBedSlices(menu, playerObj)
    if not menu or not playerObj or playerObj:getVehicle() then return end

    local vehicle = getReachableBedVehicle(playerObj)
    if not vehicle then return end

    menu:addSlice(
        getText("ContextMenu_Rest"), BED_ICON,
        enterBed, playerObj, vehicle, false
    )

    local sleepText, canSleep = getSleepSlice(playerObj, vehicle)
    if sleepText then
        menu:addSlice(
            sleepText, SLEEP_ICON,
            canSleep and enterBed or nil, playerObj, vehicle, true
        )
    end
end

local function addVLSSlices(menu, playerObj)
    if playerObj and playerObj:getVehicle() then
        addInsideEquipmentSlice(menu, playerObj)
    else
        addBedSlices(menu, playerObj)
        addOutsideWaterTankSlice(menu, playerObj)
    end
end

local function showRadialMenuWithVLSSlices(vanillaShowRadialMenu, playerObj)
    local menu = playerObj and getPlayerRadialMenu(playerObj:getPlayerNum())
    if not menu then
        vanillaShowRadialMenu(playerObj)
        return
    end

    local rawAddToUIManager = rawget(menu, "addToUIManager")
    local vanillaAddToUIManager = menu.addToUIManager
    local injected = false
    menu.addToUIManager = function(self, ...)
        if self == menu and not injected then
            injected = true
            local sliceOK, sliceErr = pcall(addVLSSlices, self, playerObj)
            if not sliceOK then
                print("[VehicleLivingSlots] Radial slice error: " .. tostring(sliceErr))
            end
        end
        return vanillaAddToUIManager(self, ...)
    end

    local ok, err = pcall(vanillaShowRadialMenu, playerObj)
    menu.addToUIManager = rawAddToUIManager
    if not ok then error(err) end
end

local function refreshVehicleContainerLabels(page, phase)
    CargoR6.safeInventoryPhase(page, phase)
    if phase == "end" and page then
        processVisibleAppliances(page)
        return
    end
    if phase ~= "buttonsAdded" or not page then return end
    local freezerButtons = {}
    local hasFreezerButtons = false
    for _, button in ipairs(page.backpacks or {}) do
        local container = button.inventory
        local part = container and container:getVehiclePart()
        local vehicle = part and part:getVehicle()
        if VLS.isSupportedVehicle(vehicle) then
            local name
            if VLS.isFreezerPart(part) then
                name = getText("IGUI_ContainerTitle_freezer")
            elseif VLS.isUniversalPart(part) then
                name = VLS.getPartDisplayName(part,
                    getText("IGUI_VehiclePart" .. container:getType()))
            elseif part:getId() == VLS.WEAPON_PART_ID then
                name = getText("IGUI_VehiclePart" .. part:getId())
            end

            if name then
                button.name = name
                button.tooltip = name
                local item = part:getInventoryItem()
                if VLS.isUniversalPart(part)
                        and VLS.ensureUniversalContainerProfile then
                    VLS.ensureUniversalContainerProfile(part)
                end
                local iconType = container:getType()
                if VLS.isFreezerPart(part) then
                    iconType = "freezer"
                elseif VLS.isUniversalPart(part) then
                    local equipmentProfile = VLS.getEquipmentProfile(item)
                    if equipmentProfile and equipmentProfile.containerType then
                        iconType = equipmentProfile.containerType
                    end
                end
                if VLS.getContainerIconOverride then
                    iconType = VLS.getContainerIconOverride(part, iconType)
                        or iconType
                end
                local icon = part:getId() == VLS.WEAPON_PART_ID
                    and item and item:getTex()
                    or ContainerButtonIcons[iconType]
                if icon then button:setImage(icon) end
            end
            if VLS.isFreezerPart(part) then
                local universalId = VLS.UNIVERSAL_PART_BY_FREEZER[part:getId()]
                freezerButtons[universalId] = button
                hasFreezerButtons = true
            end
        end
    end

    if not hasFreezerButtons then return end
    local ordered, inserted = {}, {}
    for _, button in ipairs(page.backpacks or {}) do
        local container = button.inventory
        local part = container and container:getVehiclePart()
        if not (part and VLS.isFreezerPart(part)) then
            table.insert(ordered, button)
            if part and VLS.isUniversalPart(part) then
                local freezer = freezerButtons[part:getId()]
                if freezer then
                    table.insert(ordered, freezer)
                    inserted[freezer] = true
                end
            end
        end
    end
    for _, button in pairs(freezerButtons) do
        if not inserted[button] then table.insert(ordered, button) end
    end
    table.wipe(page.backpacks)
    for _, button in ipairs(ordered) do
        table.insert(page.backpacks, button)
    end
    for index, button in ipairs(page.backpacks) do
        button:setY(((index - 1) * page.buttonSize) - 1)
    end
end

-- Vanilla stops an active microwave when an inventory transfer starts. A
-- vehicle ItemContainer has a VehiclePart parent rather than an IsoStove, so
-- only the VLS microwave must bypass that parent:Activated() call. Everything
-- else still runs through the original transfer action unchanged.
if not VLS.microwaveTransferHookApplied then
    VLS.microwaveTransferHookApplied = true
    local vanillaInventoryTransferStart = ISInventoryTransferAction.start

    local function getVLSMicrowavePart(container)
        if not container or container:getType() ~= "microwave" then return nil end
        local part = container:getVehiclePart()
        local vehicle = part and part:getVehicle()
        if not VLS.isSupportedVehicle(vehicle) or not VLS.isUniversalPart(part)
                or VLS.getInstalledPart(vehicle, part:getId()) ~= part
                or VLS.getEquipmentCapability(part:getInventoryItem())
                    ~= "cooking" then
            return nil
        end
        return part
    end

    function ISInventoryTransferAction:start()
        local changed = {}
        local containers = { self.srcContainer, self.destContainer }
        for index = 1, 2 do
            local container = containers[index]
            local part = container and not changed[container]
                and getVLSMicrowavePart(container) or nil
            if part then
                if part:getModData().vlsMicrowaveActive then
                    sendApplianceCommand(self.character, "stopMicrowave", {
                        vehicle = part:getVehicle():getId(),
                        part = part:getId(),
                        item = part:getInventoryItem():getID(),
                    })
                end
                changed[container] = container:getType()
                container:setType("VLSMicrowave")
            end
        end

        local result = { pcall(vanillaInventoryTransferStart, self) }
        for container, originalType in pairs(changed) do
            container:setType(originalType)
        end
        if not result[1] then error(result[2]) end
        return unpack(result, 2)
    end
end

if not VLS.clientHooksApplied then
    VLS.clientHooksApplied = true

    local vanillaShowRadialMenu = ISVehicleMenu.showRadialMenu
    local vanillaOnEnter = ISVehicleMenu.onEnter
    local vanillaOnSleep = ISVehicleMenu.onSleep
    local vanillaOnSwitchSeat = ISVehicleMenu.onSwitchSeat
    local vanillaOnExit = ISVehicleMenu.onExit
    local vanillaGetBestSwitchSeatExit = ISVehicleMenu.getBestSwitchSeatExit

    ISVehicleMenu.onEnter = function(playerObj, vehicle, seat)
        if vehicle and VLS.isBedSeat(vehicle, seat)
                and not VLS.getInstalledBedPartForSeat(vehicle, seat) then
            return
        end
        return vanillaOnEnter(playerObj, vehicle, seat)
    end

    ISVehicleMenu.onSleep = function(playerObj, vehicle)
        if VLS.isUsingBedSeat(playerObj, vehicle) then
            stopBedRest(playerObj)
        end
        vanillaOnSleep(playerObj, vehicle)
    end

    ISVehicleMenu.showRadialMenu = function(playerObj)
        local vehicle = playerObj and playerObj:getVehicle()
        if vehicle and not VLS.isSupportedVehicle(vehicle) then
            return vanillaShowRadialMenu(playerObj)
        end
        return showRadialMenuWithVLSSlices(vanillaShowRadialMenu, playerObj)
    end

    ISVehicleMenu.onSwitchSeat = function(playerObj, seatTo)
        local vehicle = playerObj and playerObj:getVehicle() or nil
        if vehicle and VLS.isBedSeat(vehicle, seatTo)
                and not VLS.getInstalledBedPartForSeat(vehicle, seatTo) then
            return
        end
        if vehicle and VLS.isUsingBedSeat(playerObj, vehicle)
                and vehicle:getSeat(playerObj) ~= seatTo then
            prepareToLeaveBed(playerObj)
        end
        vanillaOnSwitchSeat(playerObj, seatTo)
    end

    ISVehicleMenu.onExit = function(playerObj, seatFrom)
        local vehicle = playerObj and playerObj:getVehicle() or nil
        if vehicle and VLS.isUsingBedSeat(playerObj, vehicle) then
            prepareToLeaveBed(playerObj)
        end
        vanillaOnExit(playerObj, seatFrom)
    end

    ISVehicleMenu.getBestSwitchSeatExit = function(playerObj, vehicle, seatFrom)
        return SeatR6.chooseRoute(vanillaGetBestSwitchSeatExit,
            playerObj, vehicle, seatFrom, false)
    end
    local vanillaGetBestSwitchSeatEnter = ISVehicleMenu.getBestSwitchSeatEnter
    ISVehicleMenu.getBestSwitchSeatEnter = function(playerObj, vehicle, seat)
        return SeatR6.chooseRoute(vanillaGetBestSwitchSeatEnter,
            playerObj, vehicle, seat, true)
    end
    local vanillaMoveItemsFromSeat = ISVehicleMenu.moveItemsFromSeat
    local vanillaTransferSeatItems = ISVehicleMenu.transferSeatItems
    ISVehicleMenu.moveItemsFromSeat = function(playerObj, vehicle, seat, moveThem, doEnter)
        if not SeatR6.applies(vehicle) then
            return vanillaMoveItemsFromSeat(playerObj, vehicle, seat, moveThem, doEnter)
        end
        return SeatR6.moveItems(vanillaTransferSeatItems,
            playerObj, vehicle, seat, moveThem, doEnter)
    end

    Events.OnTick.Add(processClientState)
    Events.OnRefreshInventoryWindowContainers.Add(refreshVehicleContainerLabels)
end

if not VLS.bedQualityHookApplied then
    VLS.bedQualityHookApplied = true
    local vanillaGetBedQuality = ISWorldObjectContextMenu.getBedQuality

    ISWorldObjectContextMenu.getBedQuality = function(playerObj, bed)
        local vanillaQuality = vanillaGetBedQuality(playerObj, bed)
        local vehicleQuality = VLS.getVehicleBedQuality(playerObj)
        if not vehicleQuality then return vanillaQuality end
        if vanillaQuality and string.find(vanillaQuality, "Pillow", 1, true) then
            return vehicleQuality .. "Pillow"
        end
        return vehicleQuality
    end
end

if not VLS.bedSeatUIHookApplied then
    VLS.bedSeatUIHookApplied = true
    local vanillaIsSeatInstalled = ISVehicleSeatUI.isSeatInstalled
    local vanillaPrerender = ISVehicleSeatUI.prerender

    function ISVehicleSeatUI:isSeatInstalled(seat)
        -- The vanilla prerender uses this method only to decide whether to draw
        -- the red "seat removed" status.  A living-slot appliance occupies the
        -- slot, but it must not become a seat that the player can enter.
        if self.vlsDisplayInstalledSeat == seat then return true end
        if self.vehicle and VLS.isBedSeat(self.vehicle, seat) then
            return VLS.getInstalledBedPartForSeat(self.vehicle, seat) ~= nil
        end
        return vanillaIsSeatInstalled(self, seat)
    end

    function ISVehicleSeatUI:prerender()
        local seat = self.joyfocus and (self.joypadSeat - 1) or self.mouseOverSeat
        local installed = seat ~= nil and self.vehicle
            and VLS.getInstalledUniversalPartForSeat(self.vehicle, seat) or nil
        self.vlsDisplayInstalledSeat = installed and seat or nil
        local result = { pcall(vanillaPrerender, self) }
        self.vlsDisplayInstalledSeat = nil
        if not result[1] then error(result[2]) end

        if not self.vehicle or self.mouseOverExit then return end
        seat = self.joyfocus and (self.joypadSeat - 1) or self.mouseOverSeat
        if seat == nil then return end
        local displayName = VLS.getSeatEquipmentDisplayName(self.vehicle, seat)
        if not displayName then return end

        local height = getTextManager():getFontHeight(UIFont.Medium)
        local background = self.backgroundColor or { r = 0, g = 0, b = 0 }
        self:drawRect(1, 1, self:getWidth() - 2, height + 5, 1,
            background.r, background.g, background.b)
        self:drawTextCentre(displayName, self:getWidth() / 2, 6,
            1, 1, 1, 1, UIFont.Medium)
    end
end

-- Reload-sensitive adapters share one idempotent installer. This keeps the
-- global event surface small while still rebinding after the game recreates
-- UI classes during startup or player creation.
VLS.clientRuntimeHookRefresh = VLS.clientRuntimeHookRefresh or {}
local RuntimeHookRefresh = VLS.clientRuntimeHookRefresh

local function installVLSRuntimeHooks()
    CargoR6.installClientHooks()
    SeatR6.installActionGuards()
    installVLSFoodNameHooks()
    installGenericCraftSurfaceClientHooks()
    installMicrowaveWindowClientHook()
    if VLS.installTelevisionDeviceActionHooks then
        VLS.installTelevisionDeviceActionHooks()
    end
end

if RuntimeHookRefresh.onGameStart and Events.OnGameStart.Remove then
    Events.OnGameStart.Remove(RuntimeHookRefresh.onGameStart)
end
if RuntimeHookRefresh.onCreatePlayer and Events.OnCreatePlayer.Remove then
    Events.OnCreatePlayer.Remove(RuntimeHookRefresh.onCreatePlayer)
end
RuntimeHookRefresh.onGameStart = installVLSRuntimeHooks
RuntimeHookRefresh.onCreatePlayer = installVLSRuntimeHooks
Events.OnGameStart.Add(RuntimeHookRefresh.onGameStart)
Events.OnCreatePlayer.Add(RuntimeHookRefresh.onCreatePlayer)
installVLSRuntimeHooks()

print("[VLS 3.8.8] client loaded; current commands only")
