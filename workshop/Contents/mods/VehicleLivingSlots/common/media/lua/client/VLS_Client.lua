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
require "VLS_VehicleFluidTransferAction"
require "VLS_FillVehicleWaterTankAction"
require "VLS_VehicleRestAction"
require "RadioCom/ISRadioWindow"
require "RadioCom/ISRadioAction"
require "TimedActions/ISDeviceBatteryAction"

print("[VehicleLivingSlots] Client version " .. VLS.VERSION)

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

local function restoreOfficialVLSFoodNames(container)
    if not getVLSAppliancePart(container) then return end
    VLS.walkApplianceContainer(container, function(item)
        if instanceof(item, "Food") and not item:isCustomName() then
            local officialName = getItemNameFromFullType(item:getFullType())
            if officialName and officialName ~= ""
                    and item:getDisplayName() ~= officialName then
                item:setName(officialName)
            end
        end
    end)
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

            local realHandcraftLogicClass = HandcraftLogic
            HandcraftLogic = {
                new = function(character, craftBench, isoObject)
                    local realLogic = realHandcraftLogicClass.new(
                        character, craftBench, isoObject)
                    return makeVLSHandcraftLogicProxy(realLogic)
                end,
            }

            local results = { pcall(previousOnNewCraft,
                selectedItem, recipe, playerNum, all, eatPercentage) }
            HandcraftLogic = realHandcraftLogicClass

            if not results[1] then error(results[2], 0) end
            return unpack(results, 2)
        end

        ISInventoryPaneContextMenu.OnNewCraft =
            CraftSurfaceHooks.onNewCraftWrapper
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

        if not playerObj or not vehicle or pending.vehicle ~= vehicle
                or not VLS.isUsingBedSeat(playerObj, vehicle)
                or playerObj:isAsleep() or pendingBedSleep[playerNum]
                or sleepModal then
            pendingBedRest[playerNum] = nil
        elseif isBedEntryComplete(playerObj, vehicle) then
            pendingBedRest[playerNum] = nil
            ISTimedActionQueue.add(ISVLSVehicleRestAction:new(playerObj))
        else
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
        local data = self:getData()
        data.vlsMicrowaveTimer = self:getTimer()
        data.vlsMicrowaveTemperature = self:getMaxTemperature()
        sendApplianceCommand(self.playerObj, "setMicrowaveParams", {
            vehicle = self.vehicle:getId(),
            part = self.part:getId(),
            timer = data.vlsMicrowaveTimer,
            temperature = data.vlsMicrowaveTemperature,
        })
    end

    return proxy
end

local function isVLSMicrowaveWindowValid(ui, proxy)
    local playerObj = ui and ui.character or nil
    local vehicle = proxy and proxy.vehicle or nil
    local part = proxy and proxy.part or nil
    local item = part and part:getInventoryItem() or nil
    return playerObj and vehicle and part
        and playerObj:getVehicle() == vehicle
        and VLS.getInstalledPart(vehicle, part:getId()) == part
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
            self:close()
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
        local result = vanillaMicrowaveOnClick(ui, button)
        local playerNum = ui.character and ui.character:getPlayerNum()
        if playerNum and ISMicrowaveUI.instance
                and ISMicrowaveUI.instance[playerNum + 1] == ui then
            ISMicrowaveUI.instance[playerNum + 1] = nil
        end
        return result
    end
    if button.internal ~= "OK" then return end

    local proxy = ui.oven
    if not proxy:Activated() and not proxy:getContainer():isPowered() then
        HaloTextHelper.addBadText(ui.character, getText("ContextMenu_VLSNoAuxPower"))
        return
    end

    ui.character:getEmitter():playSound("ToggleStove")
    sendApplianceCommand(ui.character, "toggleMicrowave", {
        vehicle = proxy.vehicle:getId(),
        part = proxy.part:getId(),
        timer = ui.timerKnob:getValue() * 60,
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
    ui:addToUIManager()

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
    if button.internal ~= "TRANSFER" then
        return vanillaFluidOnButton(ui, button)
    end
    local leftFluid = ui.panelLeft:getContainer()
    local rightFluid = ui.panelRight:getContainer()
    if ui.disableTransfer or not leftFluid or not rightFluid
            or not FluidContainer.CanTransfer(leftFluid, rightFluid) then return end

    local leftIsVehicle = ui.panelLeft.container.vlsVehicleFluidEndpoint == true
    local rightIsVehicle = ui.panelRight.container.vlsVehicleFluidEndpoint == true
    if not leftIsVehicle and not rightIsVehicle then
        -- Two carried containers are a wholly vanilla operation.
        return vanillaFluidOnButton(ui, button)
    end

    local args = VLS.makeVehicleFluidTransferRequest(ui.player,
        ui.panelLeft.container, ui.panelRight.container, ui.info.transferring)
    if not args then return end

    local amounts = {}
    for _, panel in ipairs({ ui.panelLeft, ui.panelRight }) do
        local endpoint = panel.container
        if endpoint and endpoint.vlsVehicleFluidEndpoint then
            amounts[endpoint.vlsFluidPartId] =
                endpoint:getFluidContainer():getAmount()
        end
    end
    ui.vlsVehicleRequest = { amounts = amounts }
    -- Installed vehicle endpoints are not vanilla serializable fluid owners.
    -- Only this boundary uses the shared authoritative server adapter.  Do
    -- not manufacture a second action merely to draw a progress bar.
    sendApplianceCommand(ui.player, "transferWater", args)
    ui.slider:setCurrentValue(0)
    ui.disableTransfer = true
    ui.disableSwap = true
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
    local request = ui.vlsVehicleRequest
    if not request then return end

    local changed = false
    for _, panel in ipairs({ ui.panelLeft, ui.panelRight }) do
        local endpoint = panel.container
        local previous = endpoint and endpoint.vlsVehicleFluidEndpoint
            and request.amounts[endpoint.vlsFluidPartId] or nil
        if previous ~= nil and math.abs(
                endpoint:getFluidContainer():getAmount() - previous) > 0.00001 then
            changed = true
            break
        end
    end
    if changed then
        ui.vlsVehicleRequest = nil
        return
    end

    -- Prevent duplicate submissions until an authoritative installed-endpoint
    -- amount is synchronized. Closing the vanilla panel remains available.
    ui.disableTransfer = true
    ui.disableSwap = true
    ui.btnTransfer:setEnable(false)
    ui.btnSwap:setEnable(false)
    ui.panelLeft:setPanelLocked(true)
    ui.panelRight:setPanelLocked(true)
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

local function protectCooledFood(item, currentHours, vehicleId, containerId,
        freezer, seen)
    if not instanceof(item, "Food") then return end

    local itemId = item:getID()
    seen[itemId] = true
    local state = locallyCooledFood[itemId]
    if not state or state.vehicleId ~= vehicleId
            or state.containerId ~= containerId
            or currentHours < state.lastHours then
        state = {
            age = item:getAge(),
            freezing = item:getFreezingTime(),
            heat = item:getHeat(),
            lastHours = currentHours,
            vehicleId = vehicleId,
            containerId = containerId,
        }
        locallyCooledFood[itemId] = state
    end

    local elapsedHours = math.max(0, currentHours - state.lastHours)
    -- Accept only a lower authoritative age. B42's local unpowered-vehicle
    -- update may raise the visible age between server synchronizations.
    state.age = math.min(state.age, item:getAge())
    if freezer and item:canBeFrozen() then
        -- Accept a newer authoritative server value, but never the lower value
        -- produced locally by B42's unpowered-vehicle thaw check.
        state.freezing = math.max(state.freezing, item:getFreezingTime())
        state.freezing = math.min(100,
            state.freezing + elapsedHours / 4 * 100)
    elseif state.freezing > 0 then
        state.freezing = math.max(0,
            state.freezing - elapsedHours / 3 * 100)
    end
    state.lastHours = currentHours

    -- B42's Food.updateAge sees every vehicle ItemContainer as unpowered and
    -- otherwise immediately undoes the server-owned refrigeration state while
    -- the inventory is visible.  Restore only these two VLS containers; the
    -- server remains authoritative for age, freezing and battery consumption.
    local ageFactor = state.freezing >= 100 and 0 or VLS.getFridgeAgeFactor()
    state.age = state.age + elapsedHours * VLS.getFoodRotSpeed()
        / 24 * ageFactor
    item:setAge(state.age)
    VLS.preservePoweredFoodHeat(item, state, freezer and 0.1 or 0.2)
    item:setFreezingTime(state.freezing)
    item:setLastAged(currentHours)
end

local function processVisibleAppliances()
    local seen = {}
    local seenContainers = {}
    local currentHours = getGameTime():getWorldAgeHours()
    local foundVisibleVLSContainer = false

    local function processContainer(container)
        if not container or seenContainers[container] then return end
        seenContainers[container] = true
        local part = getVLSAppliancePart(container)
        if not part then return end
        foundVisibleVLSContainer = true

        local vehicle = part:getVehicle()
        local freezer = VLS.isFreezerPart(part)
        local universalPart = part
        if freezer then
            local universalId = VLS.UNIVERSAL_PART_BY_FREEZER[part:getId()]
            universalPart = universalId
                and VLS.getInstalledPart(vehicle, universalId) or nil
        end
        if not universalPart then return end

        VLS.refreshApplianceEnvironment(vehicle, universalPart, false)
        local cooling = VLS.getEquipmentCapability(
            universalPart:getInventoryItem()) == "cooling"
            and VLS.hasAuxBatteryPower(vehicle,
                VLS.getFridgeDrainPerMinute())
        local containerId = part:getId()
        VLS.walkApplianceContainer(container, function(item)
            if instanceof(item, "Food") and not item:isCustomName() then
                local officialName = getItemNameFromFullType(item:getFullType())
                if officialName and officialName ~= ""
                        and item:getDisplayName() ~= officialName then
                    item:setName(officialName)
                end
            end
            if cooling then
                protectCooledFood(item, currentHours, vehicle:getId(),
                    containerId, freezer, seen)
            end
        end)
    end

    for playerNum = 0, 3 do
        local loot = getPlayerLoot(playerNum)
        local pane = loot and loot.inventoryPane or nil
        processContainer(pane and pane.inventory or nil)
    end

    if not foundVisibleVLSContainer then
        table.wipe(locallyCooledFood)
        return
    end
    for itemId in pairs(locallyCooledFood) do
        if not seen[itemId] then locallyCooledFood[itemId] = nil end
    end
end

local function processClientState()
    processBedState()
    coolingTickCounter = coolingTickCounter + 1
    if coolingTickCounter >= 30 then
        coolingTickCounter = 0
        processVisibleAppliances()
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
    if not playerObj or playerObj:getVehicle() or not source
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

    local vanillaAddToUIManager = ISRadialMenu.addToUIManager
    local injected = false
    ISRadialMenu.addToUIManager = function(self, ...)
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
    ISRadialMenu.addToUIManager = vanillaAddToUIManager
    if not ok then error(err) end
end

local function refreshVehicleContainerLabels(page, phase)
    if phase ~= "buttonsAdded" or not page then return end
    local freezerButtons = {}
    local hasFreezerButtons = false
    for _, button in ipairs(page.backpacks or {}) do
        local container = button.inventory
        local part = container and container:getVehiclePart()
        local vehicle = part and part:getVehicle()
        if VLS.isSupportedVehicle(vehicle) then
            restoreOfficialVLSFoodNames(container)
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
        if not vehicle or not VLS.getSpaceAssignmentForSeat(vehicle, seatFrom) then
            return vanillaGetBestSwitchSeatExit(playerObj, vehicle, seatFrom)
        end

        -- Only added living-space seats need this fallback. Front-cab exits stay
        -- entirely under the original vehicle-menu implementation.
        for seatTo = 0, vehicle:getMaxPassengers() - 1 do
            if seatTo ~= seatFrom
                    and not VLS.getSpaceAssignmentForSeat(vehicle, seatTo)
                    and vehicle:canSwitchSeat(seatFrom, seatTo)
                    and not vehicle:isSeatOccupied(seatTo)
                    and not vehicle:isExitBlocked(playerObj, seatTo) then
                return seatTo
            end
        end
        return nil
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
