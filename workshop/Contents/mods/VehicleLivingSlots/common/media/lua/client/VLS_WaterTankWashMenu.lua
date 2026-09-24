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
    container:copyFluidsFrom(fluid)
    GameEntityFactory.AddComponent(proxy,true,container)
    W.menuProxies[proxy]={vehicle=vehicle:getId(),part=part:getId(),tank=tank:getID(),clean=not fluid:contains(Fluid.TaintedWater)}
    return proxy
end

-- Keep native callbacks (including cached references) and their queue/bag/mask
-- handling. Adapt only constructors for objects registered by this module.
-- Parameter names/order are part of NetTimedAction's multiplayer wire contract.
local function installNativeConstructors()
    if W.nativeConstructorsInstalled then return end
    W.nativeConstructorsInstalled=true
    local takeWaterNew=ISTakeWaterAction.new
    function ISTakeWaterAction:new(character, item, waterObject, waterTaintedCL)
        local info=proxyInfo(waterObject)
        if not info then return takeWaterNew(self,character,item,waterObject,waterTaintedCL) end
        return VLSTakeWaterFromTank:new(character,info.vehicle,info.part,info.tank,item)
    end
    local washYourselfNew=ISWashYourself.new
    function ISWashYourself:new(character, sink)
        local info=proxyInfo(sink)
        if not info then return washYourselfNew(self,character,sink) end
        return VLSWashYourselfFromTank:new(character,info.vehicle,info.part,info.tank)
    end
    local washClothingNew=ISWashClothing.new
    function ISWashClothing:new(character, sink, item, bloodAmount, dirtAmount, noSoap)
        local info=proxyInfo(sink)
        if not info then return washClothingNew(self,character,sink,item,bloodAmount,dirtAmount,noSoap) end
        return VLSWashClothingFromTank:new(character,info.vehicle,info.part,info.tank,item)
    end
    local cleanBandageNew=ISCleanBandage.new
    function ISCleanBandage:new(character, item, waterObject, recipe)
        local info=proxyInfo(waterObject)
        if not info then return cleanBandageNew(self,character,item,waterObject,recipe) end
        return VLSCleanBandageFromTank:new(character,info.vehicle,info.part,info.tank,item,recipe)
    end
end

local contextProxy=setmetatable({}, {__mode="k"})

-- VLS_TANK_PROXY_TAINT_FIX_20260919
-- The transient tank proxy is attached to the player's outdoor floor square so
-- vanilla B42 water menus can be reused. During rain, IsoObject:isTaintedWater()
-- may classify that proxy from world/rain state even though its FluidContainer
-- contains clean vehicle-tank water. Keep the real tank authoritative and remove
-- only the false vanilla "Tainted Water" tooltip from menu entries bound to this
-- proxy.
local function clearProxyTaintedWaterTooltip(menu,proxy,seen)
    local info=proxyInfo(proxy)
    if not info or not info.clean or not menu or seen[menu] then return end
    seen[menu]=true
    local taintedText=getText("Tooltip_item_TaintedWater")
    for _,option in ipairs(menu.options or {}) do
        local direct=option.target==proxy
        if not direct then
            for i=1,10 do
                if option["param"..i]==proxy then
                    direct=true
                    break
                end
            end
        end
        if direct and option.toolTip and option.toolTip.description
                and taintedText and string.find(option.toolTip.description,
                    taintedText,1,true) then
            local text=option.toolTip.description
            local first,last=string.find(text,taintedText,1,true)
            option.toolTip.description=string.sub(text,1,first-1)..string.sub(text,last+1)
        end
        if option.subOption and menu.getSubMenu then
            clearProxyTaintedWaterTooltip(
                menu:getSubMenu(option.subOption),proxy,seen)
        end
    end
end



-- Inject the temporary vehicle-tank adapter into the exact vanilla fetch table
-- before vanilla world-object menu generation runs. Vanilla then
-- creates Wash / Drink / Fill and every nested wash option itself.
local function addTankToNativeFetch(playerNum,context,worldobjects,test)
    local character=getSpecificPlayer(playerNum)
    local vehicle,part,tank,fluid=W.nearby(character)
    if not vehicle then return end
    if test then return ISWorldObjectContextMenu.setTest() end

    installNativeConstructors()
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
    clearProxyTaintedWaterTooltip(context,proxy,{})
    contextProxy[context]=nil
end

if not W.menuInstalled then
    W.menuInstalled=true
    Events.OnPreFillWorldObjectContextMenu.Add(addTankToNativeFetch)
    Events.OnFillWorldObjectContextMenu.Add(renameTankNativeRoot)
end
