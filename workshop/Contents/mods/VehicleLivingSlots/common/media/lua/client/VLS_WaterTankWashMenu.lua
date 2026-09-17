require "VLS_WaterTankWash"
require "Vehicles/ISUI/ISVehicleMenu"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISInventoryTransferUtil"
local W=VLS.TankWash

W.menuProxies=W.menuProxies or setmetatable({}, {__mode="k"})

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

local function proxyInfo(sink)
    return sink and W.menuProxies[sink] or nil
end
W.proxyInfo=proxyInfo

local function makeProxy(character,vehicle,part,tank,fluid)
    local square=character:getSquare()
    local floor=square and square:getFloor() or nil
    local sprite=floor and floor:getSprite() or nil
    if not sprite or not sprite:getName() then return nil end
    local proxy=IsoObject.new(getCell())
    proxy:setSquare(square)
    -- Vanilla water-source menu generation unconditionally resolves the source
    -- sprite texture. Reuse the current floor sprite on this transient proxy so
    -- the native menu sees a complete IsoObject without adding anything to world.
    proxy:setSprite(sprite)
    local container=ComponentType.FluidContainer:CreateComponent()
    container:setCapacity(math.max(1,fluid:getCapacity(),fluid:getAmount()))
    container:setCanPlayerEmpty(true)
    container:addFluid(FluidType.Water,fluid:getAmount())
    GameEntityFactory.AddComponent(proxy,true,container)
    W.menuProxies[proxy]={vehicle=vehicle:getId(),part=part:getId(),tank=tank:getID()}
    return proxy
end

function W.queueBody(character,vehicleId,partId,tankId)
    if not W.resolve(character,vehicleId,partId,tankId,true) then return end
    ISTimedActionQueue.add(VLSWashYourselfFromTank:new(character,vehicleId,partId,tankId))
end

function W.queueClothes(character,vehicleId,partId,tankId,items)
    if not W.resolve(character,vehicleId,partId,tankId,true) then return end
    for _,item in ipairs(items or {}) do
        if W.isWashable(item) then
            ISInventoryPaneContextMenu.transferIfNeeded(character,item)
            ISTimedActionQueue.add(VLSWashClothingFromTank:new(character,vehicleId,partId,tankId,item))
        end
    end
end

local function queueDrink(playerNum,info)
    local character=getSpecificPlayer(playerNum)
    if not character or not W.resolve(character,info.vehicle,info.part,info.tank,true) then return end
    ISTimedActionQueue.add(VLSTakeWaterFromTank:new(character,info.vehicle,info.part,info.tank,nil))
end

local function queueTakeWater(playerNum,info,waterContainerList,waterContainer)
    local character=getSpecificPlayer(playerNum)
    if not character or not W.resolve(character,info.vehicle,info.part,info.tank,true) then return end
    if not waterContainerList or #waterContainerList==0 then waterContainerList={waterContainer} end
    local playerInv=character:getInventory()
    for _,item in ipairs(waterContainerList) do
        if item and item:getFluidContainer() then
            local original=item:getContainer()
            local returnToContainer=original and original:isInCharacterInventory(character) and original or nil
            ISWorldObjectContextMenu.transferIfNeeded(character,item)
            ISTimedActionQueue.add(VLSTakeWaterFromTank:new(character,info.vehicle,info.part,info.tank,item))
            if returnToContainer and returnToContainer~=playerInv then
                ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(
                    character,item,playerInv,returnToContainer))
            end
        end
    end
end

local function installNativeCallbacks()
    if W.nativeCallbacksInstalled then return end
    W.nativeCallbacksInstalled=true
    W.nativeOnWashYourself=ISWorldObjectContextMenu.onWashYourself
    W.nativeOnWashClothing=ISWorldObjectContextMenu.onWashClothing
    W.nativeOnDrink=ISWorldObjectContextMenu.onDrink
    W.nativeOnTakeWater=ISWorldObjectContextMenu.onTakeWater
    W.nativeCleanBandageNew=ISCleanBandage.new

    ISWorldObjectContextMenu.onWashYourself=function(playerObj,sink,soapList)
        local info=proxyInfo(sink)
        if not info then return W.nativeOnWashYourself(playerObj,sink,soapList) end
        return W.queueBody(playerObj,info.vehicle,info.part,info.tank)
    end
    ISWorldObjectContextMenu.onWashClothing=function(playerObj,sink,soapList,washList,singleClothing)
        local info=proxyInfo(sink)
        if not info then return W.nativeOnWashClothing(playerObj,sink,soapList,washList,singleClothing) end
        local items=washList
        if not items then items={singleClothing} end
        return W.queueClothes(playerObj,info.vehicle,info.part,info.tank,items)
    end
    ISWorldObjectContextMenu.onDrink=function(worldobjects,waterObject,playerNum)
        local info=proxyInfo(waterObject)
        if not info then return W.nativeOnDrink(worldobjects,waterObject,playerNum) end
        return queueDrink(playerNum,info)
    end
    ISWorldObjectContextMenu.onTakeWater=function(worldobjects,waterObject,waterContainerList,waterContainer,playerNum)
        local info=proxyInfo(waterObject)
        if not info then
            return W.nativeOnTakeWater(worldobjects,waterObject,waterContainerList,waterContainer,playerNum)
        end
        return queueTakeWater(playerNum,info,waterContainerList,waterContainer)
    end
    ISCleanBandage.new=function(self,character,item,waterObject,recipe)
        local info=proxyInfo(waterObject)
        if not info then return W.nativeCleanBandageNew(self,character,item,waterObject,recipe) end
        return VLSCleanBandageFromTank:new(character,info.vehicle,info.part,info.tank,item,recipe)
    end
end

local contextProxy=setmetatable({}, {__mode="k"})

-- Inject the temporary vehicle-tank adapter into the exact vanilla fetch table
-- before vanilla world-object menu generation runs. Vanilla then
-- creates Wash / Drink / Fill and every nested wash option itself.
local function addTankToNativeFetch(playerNum,context,worldobjects,test)
    local character=getSpecificPlayer(playerNum)
    local vehicle,part,tank,fluid=W.nearby(character)
    if not vehicle then return end
    if test then return ISWorldObjectContextMenu.setTest() end

    installNativeCallbacks()
    local fetch=ISWorldObjectContextMenu.fetchVars
    if not fetch then return end
    fetch.storeWater=fetch.storeWater or {}
    local proxy=makeProxy(character,vehicle,part,tank,fluid)
    if not proxy then return end
    table.insert(fetch.storeWater,proxy)
    -- createMenu() returns early when c==0. The injected native water source is
    -- itself a valid menu source, so count it when the clicked square had none.
    fetch.c=(fetch.c or 0)+1
    contextProxy[context]=proxy
end

local function optionReferences(menu,proxy,seen)
    if not menu or seen[menu] then return false end
    seen[menu]=true
    for _,option in ipairs(menu.options or {}) do
        if option.target==proxy then return true end
        for i=1,10 do
            if option["param"..i]==proxy then return true end
        end
        if option.subOption and menu.getSubMenu then
            local sub=menu:getSubMenu(option.subOption)
            if optionReferences(sub,proxy,seen) then return true end
        end
    end
    return false
end

-- The entire submenu is vanilla. Only rename the native root that actually
-- contains this tank proxy, so nearby lakes/sinks keep their original names.
local function renameTankNativeRoot(playerNum,context,worldobjects,test)
    if test then return end
    local proxy=contextProxy[context]
    if not proxy then return end
    for _,option in ipairs(context.options or {}) do
        if option.subOption and context.getSubMenu then
            local sub=context:getSubMenu(option.subOption)
            if optionReferences(sub,proxy,{}) then
                option.name=getText("IGUI_VLSTankSource")
                break
            end
        end
    end
    contextProxy[context]=nil
end

if not W.menuInstalled then
    W.menuInstalled=true
    Events.OnPreFillWorldObjectContextMenu.Add(addTankToNativeFetch)
    Events.OnFillWorldObjectContextMenu.Add(renameTankNativeRoot)
end
