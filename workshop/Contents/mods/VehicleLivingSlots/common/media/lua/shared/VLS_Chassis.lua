-- VLS 3.8.6: inherited accepted chassis behavior: fitted chassis replacement. Each peer derives a
-- percentage-based mass reduction from the current vehicle-script baseline;
-- no replicated part modData is required to activate vehicle physics.
require "VLS_RoofCargo"
VLS.Chassis=VLS.Chassis or {}
local C=VLS.Chassis
local R=VLSRoofCargo
C.ID="VLSImprovedChassis"
C.TYPE="Base.VLSImprovedChassis"
C.KEY="VLSChassis384" -- legacy test1 record; ignored for activation.
C.ITEM_WEIGHT=0
C.LEGACY_ITEM_WEIGHT=10
C.MIN_BASE=500
-- Percentages are calibrated so stock B42.20 vehicles keep the already
-- accepted test2 reduction, while different script masses scale proportionally.
C.REDUCTION_RATE={
    StepVan=500/1160,
    Van=300/816,
    VanSeats=300/916,
    SUV=200/1000,
    PickUpVan=200/1104,
}
-- Accept test1/test2 fixed targets only for one-way migration. New targets are
-- always derived from REDUCTION_RATE.
C.LEGACY_REDUCTION={StepVan=500,Van=300,VanSeats=300,SUV=200,PickUpVan=200}
local registered=setmetatable({}, {__mode="k"})
local cache=setmetatable({}, {__mode="k"})
local warnedScripts={}
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function same(a,b) return finite(a) and finite(b) and math.abs(a-b)<0.01 end
local function host() return not isClient() end

function C.isPart(part)
    if not part then return false end
    local vehicle=part:getVehicle()
    if not vehicle then return false end
    local script=vehicle:getScript()
    return part:getId()==C.ID and vehicle:getPartById(C.ID)==part
        and script and R.vehicleScripts[script:getFullName()]==true
end

function C.family(vehicle)
    local name=vehicle:getScript():getFullName()
    if name:find("^Base%.StepVan") then return "StepVan" end
    if name:find("^Base%.VanSeats") then return "VanSeats" end
    if name:find("^Base%.Van") then return "Van" end
    if name:find("^Base%.SUV") then return "SUV" end
    if name:find("^Base%.PickUpVan") then return "PickUpVan" end
    return nil
end

local function targets(vehicle)
    local script=vehicle and vehicle:getScript()
    local base=script and script:getMass()
    if not finite(base) or base<=0 then return nil end
    local family=C.family(vehicle)
    local rate=family and C.REDUCTION_RATE[family]
    local legacyReduction=family and C.LEGACY_REDUCTION[family]
    if not finite(rate) or rate<=0 or rate>=1 or not finite(legacyReduction) then return nil end
    local reduction=math.floor(base*rate+0.5)
    local target=math.max(C.MIN_BASE,base-reduction)
    local legacyFixed=math.max(C.MIN_BASE,base-legacyReduction)
    local legacyItem=math.max(C.MIN_BASE,base-legacyReduction-C.LEGACY_ITEM_WEIGHT)
    return {base=base,target=target,legacyFixed=legacyFixed,legacyItem=legacyItem,net=base-target,rate=rate}
end

local function acceptedInitial(current,t)
    return same(current,t.base) or same(current,t.target)
        or same(current,t.legacyFixed) or same(current,t.legacyItem)
end

local function installedItem(part)
    local item=part and part:getInventoryItem()
    if item and item:getFullType()==C.TYPE then return item end
    return nil
end

local function normalizeItem(item)
    if not item then return false end
    local changed=not same(item:getWeight(),C.ITEM_WEIGHT)
    if changed then
        item:setCustomWeight(true)
        item:setWeight(C.ITEM_WEIGHT)
        item:setActualWeight(C.ITEM_WEIGHT)
    end
    return changed
end

function C.preview(part)
    if not C.isPart(part) then return nil end
    local vehicle=part:getVehicle()
    local t=targets(vehicle)
    if not t or t.net<=0 then return nil end
    local current=vehicle:getInitialMass()
    if not acceptedInitial(current,t) then return nil end
    return t
end

function C.hasJack(chr)
    for _,entry in ipairs(R.inventoryEntries(chr)) do
        if entry.item:getFullType()=="Base.Jack" and entry.item:getCondition()>0 then return true end
    end
    return false
end

local function parked(chr,part)
    local v=part and part:getVehicle()
    return C.isPart(part) and chr and not chr:isDead() and not chr:getVehicle()
        and not v:isRemovedFromWorld() and v:isStopped() and not v:isEngineRunning()
end

function C.canInstall(chr,part)
    return parked(chr,part) and C.hasJack(chr) and not installedItem(part)
        and C.preview(part)~=nil
end

function C.canDismantle(chr,part)
    return parked(chr,part) and C.hasJack(chr)
end

local function warn(vehicle,part,current,t)
    -- Unmodified vehicles need no chassis warning. One diagnostic per model
    -- per session also avoids repeats when streamed vehicle objects are replaced.
    if not installedItem(part) then return end
    local name=vehicle:getScript():getFullName()
    if warnedScripts[name] then return end
    warnedScripts[name]=true
    print("[VLS chassis] "..name..": unexpected initial mass "..tostring(current)
        .." (script "..tostring(t.base).."); chassis adjustment skipped")
end

function C.sync(vehicle,part)
    if not C.isPart(part) or part:getVehicle()~=vehicle then return false end
    registered[part]=true
    local t=targets(vehicle)
    if not t then return false end
    local current=vehicle:getInitialMass()
    if not acceptedInitial(current,t) then
        warn(vehicle,part,current,t)
        return false
    end

    local item=installedItem(part)
    local itemChanged=normalizeItem(item)
    local target=item and t.target or t.base
    local old=cache[part]
    local controller=vehicle:getController()
    local localPhysics=vehicle:isLocalPhysicSim()
    local id=item and item:getID() or -1
    local needsPhysicsRefresh=not old or old.id~=id or old.controller~=controller
        or old.localPhysics~=localPhysics or old.target~=target

    if not same(current,target) then
        vehicle:setInitialMass(target)
        itemChanged=true
    end
    if itemChanged or needsPhysicsRefresh then
        vehicle:updateTotalMass()
        cache[part]={id=id,controller=controller,localPhysics=localPhysics,target=target}
        return true
    end
    return false
end

function C.prepareInstall(chr,part,fixed)
    if not host() or not C.canInstall(chr,part) or not R.atVehicle(chr,part)
            or part:getInventoryItem() or fixed:getFullType()~=C.TYPE then return nil end
    local weight=fixed:getWeight()
    if not same(weight,C.ITEM_WEIGHT) and not same(weight,C.LEGACY_ITEM_WEIGHT) then return nil end
    local vehicle=part:getVehicle()
    local initial=vehicle:getInitialMass()
    local oldWeight=weight
    local oldActual=fixed:getActualWeight()
    return {
        commit=function()
            assert(part:getInventoryItem()==fixed,"chassis item assignment failed")
            registered[part]=true
            C.sync(vehicle,part)
            local t=targets(vehicle)
            assert(t and same(vehicle:getInitialMass(),t.target),"chassis mass application failed")
            assert(same(fixed:getWeight(),0),"chassis item weight migration failed")
        end,
        rollback=function()
            cache[part]=nil
            fixed:setCustomWeight(true)
            fixed:setWeight(oldWeight)
            fixed:setActualWeight(oldActual)
            vehicle:setInitialMass(initial)
            vehicle:updateTotalMass()
        end,
    }
end

function C.installed(vehicle,part)
    C.sync(vehicle,part)
    if host() then vehicle:transmitPartItem(part) end
end

function C.destroyed(vehicle,part)
    C.sync(vehicle,part)
end

function C.init(vehicle,part)
    if C.isPart(part) then registered[part]=true;C.sync(vehicle,part) end
end

function C.create(vehicle,part)
    if not part:getInventoryItem() then part:setInventoryItem(nil) end
    C.init(vehicle,part)
end

function C.update(vehicle,part) C.sync(vehicle,part) end

local function extraTooltip(chr,part,line)
    -- Keep the mechanics tooltip in the same concise requirement style as
    -- vanilla: only the extra physical tool belongs here.
    line(getItemName("Base.Jack").." "..(C.hasJack(chr) and 1 or 0).."/1",C.hasJack(chr))
end

R.fabricatedParts[C.ID]={
    accepts=C.isPart,itemType=C.TYPE,scaleWithVehicle=true,
    materials={["Base.MetalBar"]=12,["Base.SmallSheetMetal"]=6,["Base.Screws"]=8},
    uses={["Base.BlowTorch"]=20,["Base.WeldingRods"]=6},
    salvage={{"MetalBar",6,15},{"SmallSheetMetal",3,15},{"Screws",4,25}},
    mechanics=5,metalWelding=5,toolsReady=C.hasJack,
    canInstall=C.canInstall,canDismantle=C.canDismantle,prepareInstall=C.prepareInstall,
    onInstalled=C.installed,onDestroyed=C.destroyed,extraTooltip=extraTooltip,
}

local ticks=0
local function onTick()
    ticks=ticks+1
    if ticks%30~=0 then return end
    for part in pairs(registered) do
        local vehicle=part:getVehicle()
        if not vehicle or not C.isPart(part) or vehicle:isRemovedFromWorld() then
            registered[part]=nil
            cache[part]=nil
        else
            C.sync(vehicle,part)
        end
    end
end
if not C.tickRegistered then C.tickRegistered=true;Events.OnTick.Add(onTick) end
return C
