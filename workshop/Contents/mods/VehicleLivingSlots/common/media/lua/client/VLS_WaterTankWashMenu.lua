require "VLS_WaterTankWash"
require "Vehicles/ISUI/ISVehicleMenu"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISTimedActionQueue"
local W=VLS.TankWash

-- Bounded nearby lookup; the inlet-side/floor gate is shared with the server.
function W.nearby(character)
    if not character or character:isDead() or character:getVehicle() then return nil end
    local seen={}
    local function resolve(vehicle)
        if not vehicle or seen[vehicle] then return nil end
        seen[vehicle]=true
        for _,partId in ipairs(VLS.getWaterTankPartIds(vehicle)) do
            local tank=VLS.getInstalledWaterTank(vehicle,partId)
            if tank then
                local v,p,t,f=W.resolve(character,vehicle:getId(),partId,tank:getID(),true)
                if v and f:getAmount()>=1 then return v,p,t,f end
            end
        end
    end
    local v,p,t,f=resolve(ISVehicleMenu.getVehicleToInteractWith(character))
    if v then return v,p,t,f end
    local square=character:getSquare();local cell=getCell()
    if not square or not cell then return nil end
    for x=square:getX()-2,square:getX()+2 do
        for y=square:getY()-2,square:getY()+2 do
            local near=cell:getGridSquare(x,y,square:getZ())
            v,p,t,f=resolve(near and near:getVehicleContainer())
            if v then return v,p,t,f end
        end
    end
end

function W.queueBody(character,vehicleId,partId,tankId)
    if not W.resolve(character,vehicleId,partId,tankId,true) then return end
    ISTimedActionQueue.add(VLSWashYourselfFromTank:new(character,vehicleId,partId,tankId))
end
function W.queueClothes(character,vehicleId,partId,tankId,items)
    if not W.resolve(character,vehicleId,partId,tankId,true) then return end
    for _,item in ipairs(items) do
        if W.isWashable(item) then
            ISInventoryPaneContextMenu.transferIfNeeded(character,item)
            ISTimedActionQueue.add(VLSWashClothingFromTank:new(character,vehicleId,partId,tankId,item))
        end
    end
end

local function inventoryClothes(character)
    local result,seen={},{}
    local function visit(container)
        if seen[container] then return end
        seen[container]=true
        local items=container:getItems()
        for i=0,items:size()-1 do
            local item=items:get(i)
            if W.isWashable(item) then result[#result+1]=item end
            if instanceof(item,"InventoryContainer") then visit(item:getInventory()) end
        end
    end
    visit(character:getInventory())
    return result
end

local function addWorldMenu(playerNum,context,worldobjects,test)
    if test then return end
    local character=getSpecificPlayer(playerNum)
    local vehicle,part,tank,fluid=W.nearby(character)
    if not vehicle then return end
    local root=context:addOption(getText("IGUI_VLSTankWash"),nil,nil)
    local menu=ISContextMenu:getNew(context);context:addSubMenu(root,menu)
    local id,partId,tankId=vehicle:getId(),part:getId(),tank:getID()
    local body=menu:addOption(getText("IGUI_VLSTankWashBody"),character,W.queueBody,id,partId,tankId)
    body.notAvailable=ISWashYourself.GetRequiredWater(character)<=0
    local items=inventoryClothes(character)
    if #items>0 then
        local all=menu:addOption(getText("IGUI_VLSTankWashAll"),character,W.queueClothes,id,partId,tankId,items)
        all.notAvailable=fluid:getAmount()<ISWashClothing.GetRequiredWater(items[1])
        for _,item in ipairs(items) do
            local option=menu:addOption(item:getName(),character,W.queueClothes,id,partId,tankId,{item})
            option.notAvailable=fluid:getAmount()<ISWashClothing.GetRequiredWater(item)
        end
    end
end
local function addInventoryMenu(playerNum,context,entries)
    local character=getSpecificPlayer(playerNum)
    local vehicle,part,tank,fluid=W.nearby(character)
    if not vehicle then return end
    local items,seen={},{}
    local function add(item)
        if item and not seen[item] and W.isWashable(item)
                and character:getInventory():getItemWithIDRecursiv(item:getID())==item then
            seen[item]=true;items[#items+1]=item
        end
    end
    for _,entry in ipairs(entries or {}) do
        if instanceof(entry,"InventoryItem") then add(entry)
        elseif entry.items then for _,item in ipairs(entry.items) do add(item) end end
    end
    if #items==0 then return end
    local option=context:addOption(getText("IGUI_VLSTankWashSelected"),character,W.queueClothes,
        vehicle:getId(),part:getId(),tank:getID(),items)
    option.notAvailable=fluid:getAmount()<ISWashClothing.GetRequiredWater(items[1])
end
if not W.menuInstalled then
    W.menuInstalled=true
    Events.OnFillWorldObjectContextMenu.Add(addWorldMenu)
    Events.OnFillInventoryObjectContextMenu.Add(addInventoryMenu)
end
