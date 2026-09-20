-- Native crafting owns duration, animation, recipe, output and fuel calculation.
-- Only installed-input identity, reachability and vehicle replication live here.
local VLS = require "VLS_Propane"
require "Entity/TimedActions/ISHandcraftAction"

VLSRefillBlowTorchFromVehicleAction = ISHandcraftAction:derive(
    "VLSRefillBlowTorchFromVehicleAction")

local function integer(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
        and value == math.floor(value)
end

function VLSRefillBlowTorchFromVehicleAction:resolveInputs(requirePosition)
    if not integer(self.vehicleId) or not integer(self.torchId)
            or not integer(self.tankId) or type(self.partId) ~= "string"
            or not self.character or self.character:getVehicle() then return end
    local vehicle = getVehicleById(self.vehicleId)
    -- The installed tank resolver owns eligibility; an interior profile is not required.
    if not vehicle or not vehicle:isStopped()
            or self.character:DistToProper(vehicle) >= 4 then return end
    local tank, part = VLS.getInstalledPropaneSource(vehicle, self.partId, self.tankId)
    if not tank or not part then return end
    if requirePosition ~= false and not vehicle:isInArea(part:getArea(), self.character) then return end
    local torch = self.character:getInventory():getItemWithIDRecursiv(self.torchId)
    if not torch or torch:getFullType() ~= "Base.BlowTorch"
            or not instanceof(torch, "DrainableComboItem")
            or torch:getCurrentUsesFloat() >= 1 then return end
    return torch, tank, part, vehicle
end

function VLSRefillBlowTorchFromVehicleAction:isValid()
    return not self.vlsFinished and ISHandcraftAction.isValid(self)
        and self:resolveInputs() ~= nil
end

function VLSRefillBlowTorchFromVehicleAction:bindInstalledInput(requirePosition)
    local torch, tank = self:resolveInputs(requirePosition)
    if not torch or not self.logic then return false end
    self.logic:setManualSelectInputs(true)
    self.logic:clearManualInputs()
    -- setManualInputsFor rejects installed items with no inventory/world owner.
    -- offerInputItem is the native entity-input API; it still checks the recipe.
    local data = self.logic:getRecipeData()
    local inputs = self.craftRecipe:getInputs()
    if not data or inputs:size() ~= 2
            or not data:offerInputItem(inputs:get(0), torch)
            or not data:offerInputItem(inputs:get(1), tank)
            or not self.logic:canPerformCurrentRecipe() then return false end
    self.items = data:getAllInputItems()
    return true
end

function VLSRefillBlowTorchFromVehicleAction:start()
    if not self:isValid() then self:forceStop(); return end
    ISHandcraftAction.start(self)
    self:clearItemsProgressBar(false)
    if not self:bindInstalledInput() then self:forceStop(); return end
    -- Native serverStart has no client animation action. Keep presentation here.
    self:clearItemsProgressBar(true)
    self:setOverrideHandModels(self.logic:getModelHandOne(), self.logic:getModelHandTwo())
end

function VLSRefillBlowTorchFromVehicleAction:serverStart()
    -- The action request can precede the final walking-position update in MP.
    -- Bind real inputs while still nearby; strict service-area validation remains
    -- mandatory in isValid()/complete() before the native recipe can spend fuel.
    if not self.vlsFinished and ISHandcraftAction.isValid(self) and self:resolveInputs(false) then
        ISHandcraftAction.serverStart(self)
        if self:bindInstalledInput(false) then return end
    end
    -- Native server actions have netAction, not the client's animation action.
    -- forceComplete still schedules complete(), so reject crafting permanently.
    self.vlsFinished = true
    self.netAction:forceComplete()
end

function VLSRefillBlowTorchFromVehicleAction:complete()
    if self.vlsFinished or not self.logic or not self:isValid() then
        self.vlsFinished = true
        return true
    end
    return ISHandcraftAction.complete(self)
end

function VLSRefillBlowTorchFromVehicleAction:faceServiceArea()
    local _, _, part, vehicle = self:resolveInputs()
    local facing = part and vehicle:getAreaFacingPosition(part:getArea(), Vector2.new())
    if facing then self.character:faceLocationF(facing:getX(), facing:getY()) end
end

function VLSRefillBlowTorchFromVehicleAction:waitToStart()
    self:faceServiceArea()
    return self.character:shouldBeTurning()
end

function VLSRefillBlowTorchFromVehicleAction:update()
    ISHandcraftAction.update(self)
    self:faceServiceArea()
end

function VLSRefillBlowTorchFromVehicleAction:performRecipe()
    if not self:isValid() or not self.logic then return end
    local torch, tank, part, vehicle = self:resolveInputs()
    if not self.items or self.items:get(0) ~= torch or self.items:get(1) ~= tank then return end
    self.vlsFinished = true
    ISHandcraftAction.performRecipe(self)
    -- Native OnCreate syncs the real torch/tank. Installed item transport also
    -- needs the vehicle part route (same item, never moved into a fake bag).
    vehicle:transmitPartUsedDelta(part)
end

function VLSRefillBlowTorchFromVehicleAction:new(character, vehicleId, partId, torchId, tankId)
    local recipe = ScriptManager.instance:getCraftRecipe("Base.RefillBlowTorch")
    local containers = ArrayList.new()
    containers:add(character:getInventory())
    local o = ISHandcraftAction.new(self, character, recipe, containers,
        nil, nil, {}, nil, nil, 1, 0)
    -- Java convertToPZNetTable requires a real table (false and nil both fail).
    -- Native start must not validate an empty manual-input set before we bind
    -- the installed tank through the native entity-input API below.
    o.manualInputs = nil
    -- Names match constructor parameters: native NetTimedAction serializes these.
    o.vehicleId, o.partId, o.torchId, o.tankId = vehicleId, partId, torchId, tankId
    o.stopOnWalk, o.stopOnRun = true, true
    return o
end
