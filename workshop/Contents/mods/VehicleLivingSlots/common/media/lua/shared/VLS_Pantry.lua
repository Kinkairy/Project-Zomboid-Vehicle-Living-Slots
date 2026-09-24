local VLS = require "VLS_Config"
require "VLS_InstallGuard"

VLSPantry = VLSPantry or {}
local P = VLSPantry
P.VERSION = "3.9"
-- Keep the first test slot ID so saved appliances stay installed.
P.PART_ID = "VLSPantryCoffee"
P.slots = { VLSPantryCoffee = {} }
P.devices = {
    ["Base.Mov_CoffeeMaker"] = { itemType = "Base.Mov_CoffeeMaker", sprite = "appliances_cooking_01_56", entity = "Base.Coffee_Machine" },
    ["Base.Mov_Toaster"] = { itemType = "Base.Mov_Toaster", sprite = "appliances_cooking_01_32", entity = "Base.Toaster" },
}
P.choices = {
    coffeeMug = { itemType = "Base.Mov_CoffeeMaker", recipe = "Base.MakeCoffeeMug" },
    coffeeCup = { itemType = "Base.Mov_CoffeeMaker", recipe = "Base.MakeCoffeeTeacup" },
    toast = { itemType = "Base.Mov_Toaster", recipe = "Base.MakeToast" },
}
P.choiceOrder = { "coffeeMug", "coffeeCup", "toast" }
P.sprites = {}
for i = 56, 59 do P.sprites["appliances_cooking_01_" .. i] = "Base.Mov_CoffeeMaker" end
for i = 32, 33 do P.sprites["appliances_cooking_01_" .. i] = "Base.Mov_Toaster" end

function P.resolveType(item)
    if not item then return nil end
    local fullType = item:getFullType()
    if fullType == "Base.Mov_CoffeeMaker" or fullType == "Base.Mov_Toaster" then return fullType end
    if instanceof(item, "Moveable") then
        local sprite = item:getWorldSprite()
        return sprite and P.sprites[(sprite:gsub("^ct_oac_", ""))] or nil
    end
end

function P.isPart(part)
    return part ~= nil and P.slots[part:getId()] ~= nil
        and VLS.isSupportedVehicle(part:getVehicle())
        and part:getVehicle():getPartById(part:getId()) == part
end

function P.accepts(part, item)
    local itemType = P.resolveType(item)
    return P.isPart(part) and itemType ~= nil
end

function P.canInstall(part, item)
    return part and part:getId() == P.PART_ID and P.accepts(part, item)
        and VLS.isInstallationEnabled(part, item)
end

function P.CreateEmpty(vehicle, part)
    -- Only a newly created pantry slot is initialized; existing installed items
    -- are restored by the engine's vehicle-part save/load implementation.
    if P.isPart(part) then part:setInventoryItem(nil) end
end

function P.reason(character, vehicle, partId, itemId)
    if not character or not vehicle or character:getVehicle() ~= vehicle
            or not VLS.isSupportedVehicle(vehicle) then return "ContextMenu_VLSPantryInside" end
    local part = vehicle:getPartById(partId)
    local item = part and part:getInventoryItem()
    if not P.accepts(part, item) or (itemId ~= nil and item:getID() ~= itemId) then
        return "ContextMenu_VLSPantryMissing"
    end
    if item:getCondition() <= 0 then return "ContextMenu_VLSPantryBroken" end
    if not VLS.hasAuxBatteryPower(vehicle, VLS.getSmallApplianceDrainPerUse()) then return "ContextMenu_VLSNoAuxPower" end
end

function P.carriedContainers(character)
    local result = ArrayList.new()
    local inventory = character:getInventory()
    result:add(inventory)
    VLS.walkApplianceContainer(inventory, function(item)
        if instanceof(item, "InventoryContainer") then
            local bag = item:getInventory()
            if bag and not result:contains(bag) then result:add(bag) end
        end
    end)
    return result
end

function P.recipe(choice)
    local definition = P.choices[choice]
    return definition and ScriptManager.instance:getCraftRecipe(definition.recipe) or nil
end

-- The Java HandcraftLogic facade insists on a world CraftBench for these
-- recipes. Use the same native recipe-data validator and executor, substituting
-- only the independently checked installed vehicle part for that world bench.
-- Recipe tags, definitions, inputs, outputs and callbacks are never rewritten.
function P.canCraft(character, logic, recipe)
    if not logic or not recipe or logic:getRecipeData():getRecipe() ~= recipe then return false end
    local containers = logic:getContainers()
    if not logic:isContainersAccessible(containers)
            or not CraftRecipeManager.isValidRecipeForCharacter(recipe, character, nil, containers) then return false end
    local inputs = nil
    if not logic:isManualSelectInputs() then inputs = logic:getAllItems() end
    return logic:getRecipeData():canPerform(character, logic:getSourceResources(), inputs, true, containers)
end

function P.choiceForRecipe(recipe, partId, item)
    for choice, def in pairs(P.choices) do
        if P.slots[partId] and def.itemType == P.resolveType(item) and recipe == P.recipe(choice) then return choice end
    end
end

function P.newLogic(character, choice)
    local recipe = P.recipe(choice)
    if not recipe then return nil end
    local logic = HandcraftLogic.new(character, nil, nil)
    logic:setManualSelectInputs(false)
    logic:setContainers(P.carriedContainers(character))
    logic:setRecipe(recipe)
    logic:setTargetVariableInputRatio(1)
    return logic, recipe
end

if not P.installHooksApplied then
    P.installHooksApplied = true
    local resolve = VLS.resolveEquipmentType
    function VLS.resolveEquipmentType(item) return P.resolveType(item) or resolve(item) end
    local getProfile = VLS.getEquipmentProfileByType
    function VLS.getEquipmentProfileByType(fullType)
        for _, slot in pairs(P.devices) do
            if fullType == slot.itemType then
                return { capability = "pantry", previewSprite = slot.sprite }
            end
        end
        return getProfile(fullType)
    end
    local allowed = VLS.isAllowedItem
    function VLS.isAllowedItem(part, item)
        if part and P.slots[part:getId()] then return P.canInstall(part, item) end
        return allowed(part, item)
    end
    VLS.allowedItems[P.PART_ID] = { ["Base.Mov_CoffeeMaker"] = true, ["Base.Mov_Toaster"] = true }
    VLS.installationOptionProviders.pantry = function(part)
        if P.isPart(part) then return "EnableSmallAppliances" end
    end
    VLS.mechanicsDisplayProviders.pantry = P.isPart
end

return P
