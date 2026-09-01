require "VLS_Config"
require "Vehicles/TimedActions/ISInstallVehiclePart"
require "Vehicles/TimedActions/ISUninstallVehiclePart"

local function isVLSTelevision(part, item)
    return VLS.isUniversalPart(part)
        and VLS.isAllowedItem(part, item)
        and VLS.getEquipmentCapability(item) == "television"
        and instanceof(item, "Radio")
        and item:getDeviceData() ~= nil
end

-- Vanilla vehicle-part installation creates DeviceData on the destination for
-- every Radio item. A television is a Radio in B42, so using the vanilla
-- completion unchanged makes the rear television appear as an extra speaker
-- in the untouched front-seat radial menu. These two actions retain vanilla
-- mechanics success, failure, XP, inventory, sound and transmission behavior,
-- but keep television DeviceData exclusively on VLS's itemless companion part.
VLSTelevisionInstallVehiclePart =
    ISInstallVehiclePart:derive("VLSTelevisionInstallVehiclePart")

function VLSTelevisionInstallVehiclePart:complete()
    if self.item == nil then return false end
    if not self.vehicle then
        print("no such vehicle id=", self.vehicle)
        return false
    end
    if not self.part then
        print("no such part ", self.part)
        return false
    end

    self.item:setJobDelta(0)
    self.character:removeFromHands(self.item)
    self.character:getInventory():DoRemoveItem(self.item)
    sendRemoveItemFromContainer(self.character:getInventory(), self.item)

    local perksTable = VehicleUtils.getPerksTableForChr(
        self.part:getTable("install").skills, self.character)
    local keyvalues = self.part:getTable("install")
    local success, failure = VehicleUtils.calculateInstallationSuccess(
        keyvalues.skills, self.character, perksTable)
    if not instanceof(self.item, "InventoryItem") then
        print("item is nil")
        return false
    end

    if ZombRand(100) < success then
        self.part:setInventoryItem(self.item,
            self.character:getPerkLevel(Perks.Mechanics))
        local tbl = self.part:getTable("install")
        if tbl and tbl.complete then
            VehicleUtils.callLua(tbl.complete, self.vehicle, self.part)
        end
        self.vehicle:transmitPartItem(self.part)
        self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE,
            { success = true })
        self.character:addMechanicsItem(
            self.item:getID() .. self.vehicle:getMechanicalID() .. "1",
            self.part, getGameTime():getCalender():getTimeInMillis())
    elseif ZombRand(100) < failure then
        self.item:setCondition(self.item:getCondition() - ZombRand(5, 10))
        self.character:getInventory():AddItem(self.item)
        sendAddItemToContainer(self.character:getInventory(), self.item)
        playServerSound("PZ_MetalSnap", self.character:getCurrentSquare())
        self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE,
            { success = false })
        addXp(self.character, Perks.Mechanics, 1)
    else
        self.character:getInventory():AddItem(self.item)
        sendAddItemToContainer(self.character:getInventory(), self.item)
        self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE,
            { success = false })
        addXp(self.character, Perks.Mechanics, 1)
    end
    return true
end

VLSTelevisionUninstallVehiclePart =
    ISUninstallVehiclePart:derive("VLSTelevisionUninstallVehiclePart")

function VLSTelevisionUninstallVehiclePart:complete()
    if not self.vehicle then
        print("no such vehicle id=", self.vehicle)
        return false
    end
    if not self.part then
        print("no such part " .. tostring(self.part))
        return false
    end

    local perksTable = VehicleUtils.getPerksTableForChr(
        self.part:getTable("install").skills, self.character)
    local keyvalues = self.part:getTable("install")
    local success, failure = VehicleUtils.calculateInstallationSuccess(
        keyvalues.skills, self.character, perksTable)
    local item = self.part:getInventoryItem()
    if not item then
        print("part already uninstalled ", self.part)
        return false
    end

    -- Copy the live companion state back to the portable TV. Never create or
    -- read DeviceData on the universal living-space part.
    VLS.copyTelevisionStateToItem(self.part, item)

    if ZombRand(100) < success then
        item:setItemCapacity(self.part:getContainerContentAmount())
        self.part:setInventoryItem(nil)
        local tbl = self.part:getTable("uninstall")
        if tbl and tbl.complete then
            VehicleUtils.callLua(tbl.complete, self.vehicle, self.part, item)
        end
        self.vehicle:transmitPartItem(self.part)
        if self.character:getInventory():hasRoomFor(self.character, item) then
            self.character:getInventory():AddItem(item)
            sendAddItemToContainer(self.character:getInventory(), item)
        else
            local square = self.character:getCurrentSquare()
            local dropX, dropY, dropZ = ISTransferAction.GetDropItemOffset(
                self.character, square, item)
            self.character:getCurrentSquare():AddWorldInventoryItem(
                item, dropX, dropY, dropZ)
            if not isServer() then ISInventoryPage.renderDirty = true end
        end
        self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE,
            { success = true })
        self.character:addMechanicsItem(
            item:getID() .. self.vehicle:getMechanicalID() .. "0",
            self.part, getGameTime():getCalender():getTimeInMillis())
    elseif ZombRand(failure) < 100 then
        self.part:setCondition(self.part:getCondition() - ZombRand(5, 10))
        self.vehicle:transmitPartCondition(self.part)
        playServerSound("PZ_MetalSnap", self.character:getCurrentSquare())
        self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE,
            { success = false })
        addXp(self.character, Perks.Mechanics, 1)
    end
    return true
end

if not VLS.installGuardApplied then
    VLS.installGuardApplied = true

    local vanillaIsValid = ISInstallVehiclePart.isValid
    function ISInstallVehiclePart:isValid()
        -- Only the furniture and battery slots have VLS-specific item rules.
        -- The large-van water tank deliberately uses the original gas-tank
        -- itemType/mechanic-type matcher, so the vanilla action must remain
        -- authoritative for it.
        local allowed = self.part and VLS.allowedItems[self.part:getId()]
        if allowed and not VLS.isAllowedItem(self.part, self.item) then
            return false
        end
        return vanillaIsValid(self)
    end

    local vanillaInstallNew = ISInstallVehiclePart.new
    function ISInstallVehiclePart:new(character, part, item, maxTimeInit)
        if isVLSTelevision(part, item) then
            return vanillaInstallNew(VLSTelevisionInstallVehiclePart,
                character, part, item, maxTimeInit)
        end
        return vanillaInstallNew(self, character, part, item, maxTimeInit)
    end

    local vanillaUninstallIsValid = ISUninstallVehiclePart.isValid
    function ISUninstallVehiclePart:isValid()
        if not VLS.canUninstallManagedPart(self.part) then return false end
        return vanillaUninstallIsValid(self)
    end

    local vanillaUninstallNew = ISUninstallVehiclePart.new
    function ISUninstallVehiclePart:new(character, part, workTime)
        local item = part and part:getInventoryItem() or nil
        if isVLSTelevision(part, item) then
            return vanillaUninstallNew(VLSTelevisionUninstallVehiclePart,
                character, part, workTime)
        end
        return vanillaUninstallNew(self, character, part, workTime)
    end

end
