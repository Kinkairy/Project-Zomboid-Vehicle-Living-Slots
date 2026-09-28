-- Isolated four-frame lifecycle, pinned to the Workshop 3.9 mass contract.
-- The core exposes no generic frame-count/target API; this adapter owns its
-- guarded calculation while reusing the native VLS fabrication transaction.
local A = require "VLS_KI5F700_Config"
require "VLS_Chassis"
if VLS.F700Frames then return VLS.F700Frames end
local C, R = {}, VLSRoofCargo
VLS.F700Frames = C
C.TOP_TYPE, C.ITEM_WEIGHT = "Base.VLSTopFrame", 0
local topIndex = A.frameIndex
local function expectedType() return C.TOP_TYPE end
local function installedItem(part)
    local item = part and part:getInventoryItem()
    return item and item:getFullType() == C.TOP_TYPE and item or nil
end
local registered=setmetatable({}, {__mode="k"})
local cache=setmetatable({}, {__mode="k"})
local warnedScripts={}
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function same(a,b) return finite(a) and finite(b) and math.abs(a-b)<0.01 end
local function host() return not isClient() end

function C.isPart(part)
    local index = A.frameIndex(part)
    return index and part:getVehicle():getPartById(part:getId()) == part or false
end
function C.topCount(vehicle) return A.matches(vehicle) and 4 or 0 end

-- Match native BaseVehicle.updateTotalMass: container capacity-weight plus
-- installed item weight. Do not recurse into bags: native capacity-weight owns
-- that calculation; use the actual installed item weight.
local function payloadMass(vehicle)
    local total=0
    for index=0,vehicle:getPartCount()-1 do
        local part=vehicle:getPartByIndex(index)
        local container=part:getItemContainer()
        if container then
            local weight=container:getCapacityWeight()
            if not finite(weight) or weight<0 then return nil end
            total=total+weight
        end
        local item=part:getInventoryItem()
        if item then
            local weight=item:getWeight()
            if not finite(weight) or weight<0 then return nil end
            total=total+weight
        end
    end
    return total
end

local function targets(vehicle, previewPart)
    local script=vehicle and vehicle:getScript()
    local base=script and script:getMass()
    if not finite(base) or base<=0 then return nil end
    if not A.matches(vehicle) then return nil end
    local topRate=40.625/(base+50*(#VLS.getVehicleProfile(vehicle).universalParts+4))
    local activeRate=0
    for i=1,4 do
        if installedItem(vehicle:getPartById(A.frames[i])) then activeRate=activeRate+topRate end
    end
    local rate=activeRate
    if previewPart and not installedItem(previewPart) then
        rate=rate+topRate
    end
    if not finite(rate) or rate<0 or rate>=1 then return nil end
    local payload=payloadMass(vehicle)
    if not payload then return nil end
    local total=base+payload
    -- Retain precision in the initial-mass offset; native updateTotalMass owns
    -- rounding the final total. The offset may be negative when overloaded,
    -- but the resulting physical total remains positive for every valid rate.
    local reduction=total*rate
    local target=base-reduction
    return {base=base,target=target,payload=payload,total=total,
        projected=math.floor(total-reduction+0.5),
        activeTarget=base-total*activeRate,
        net=previewPart and total*topRate or reduction,
        rate=rate}
end

local function acceptedInitial(current,t,part)
    local previous=part and cache[part:getVehicle()]
    return same(current,t.base) or same(current,t.target) or same(current,t.activeTarget)
        or (previous and same(previous.base,t.base) and same(current,previous.target))
end

function C.preview(part)
    if not C.isPart(part) then return nil end
    local vehicle=part:getVehicle()
    local t=targets(vehicle,part)
    if not t or t.net<=0 then return nil end
    local current=vehicle:getInitialMass()
    if not acceptedInitial(current,t,part) then return nil end
    return t
end

local function parked(chr,part)
    local v=part and part:getVehicle()
    return C.isPart(part) and chr and not chr:isDead() and not chr:getVehicle()
        and not v:isRemovedFromWorld() and v:isStopped() and not v:isEngineRunning()
end

function C.canInstall(chr,part)
    return parked(chr,part) and not installedItem(part)
        and C.preview(part)~=nil
end

function C.canDismantle(chr,part)
    if not parked(chr,part) then return false end
    local index=topIndex(part)
    if not index then return false end
    local cupboard=part:getVehicle():getPartById(A.overhead[index])
    return not cupboard or (not cupboard:getInventoryItem() and R.empty(cupboard))
end

local function warn(vehicle,part,current,t)
    -- Unmodified vehicles need no frame warning. One diagnostic per model
    -- per session also avoids repeats when streamed vehicle objects are replaced.
    if not installedItem(part) then return end
    local name=vehicle:getScript():getFullName()
    if warnedScripts[name] then return end
    warnedScripts[name]=true
    print("[VLS F700 frames] "..name..": unexpected initial mass "..tostring(current)
        .." (script "..tostring(t.base).."); top-frame adjustment skipped")
end

function C.sync(vehicle,part)
    if not C.isPart(part) or part:getVehicle()~=vehicle then return false end
    registered[part]=true
    local t=targets(vehicle)
    if not t then return false end
    local current=vehicle:getInitialMass()
    if not acceptedInitial(current,t,part) then
        warn(vehicle,part,current,t)
        return false
    end

    local itemChanged=false
    local identity={}
    for i=1,C.topCount(vehicle) do
        local frameItem=installedItem(vehicle:getPartById(A.frames[i]))
        identity[#identity+1]=tostring(frameItem and frameItem:getID() or -1)
    end
    local target=t.target
    local old=cache[vehicle]
    local controller=vehicle:getController()
    local localPhysics=vehicle:isLocalPhysicSim()
    local id=table.concat(identity,":")
    local needsPhysicsRefresh=not old or old.id~=id or old.controller~=controller
        or old.localPhysics~=localPhysics or old.target~=target

    if not same(current,target) then
        vehicle:setInitialMass(target)
        itemChanged=true
    end
    if itemChanged or needsPhysicsRefresh then
        vehicle:updateTotalMass()
        cache[vehicle]={id=id,controller=controller,localPhysics=localPhysics,target=target,base=t.base}
        return true
    end
    return false
end

function C.prepareInstall(chr,part,fixed)
    if not host() or not C.canInstall(chr,part) or not R.atVehicle(chr,part)
            or part:getInventoryItem() or fixed:getFullType()~=expectedType(part) then return nil end
    local weight=fixed:getWeight()
    if not same(weight,C.ITEM_WEIGHT) then return nil end
    local vehicle=part:getVehicle()
    local initial=vehicle:getInitialMass()
    return {
        commit=function()
            assert(part:getInventoryItem()==fixed,"frame item assignment failed")
            registered[part]=true
            C.sync(vehicle,part)
            local t=targets(vehicle)
            assert(t and same(vehicle:getInitialMass(),t.target),"frame mass application failed")
            assert(same(fixed:getWeight(),0),"unexpected frame item weight")
        end,
        rollback=function()
            cache[vehicle]=nil
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
    -- Native create runs only for a newly introduced part. An already fitted
    -- cupboard/appliance is retained in-place and receives its supporting frame.
    -- All top positions follow this same rule; normal installs still consume materials.
    local index=topIndex(part)
    local equipment=index and vehicle:getPartById(A.overhead[index])
    if host() and not part:getInventoryItem() and equipment and equipment:getInventoryItem() then
        local frame=instanceItem(C.TOP_TYPE)
        if frame then part:setInventoryItem(frame);vehicle:transmitPartItem(part) end
    end
    C.init(vehicle,part)
end

function C.update(vehicle,part) C.sync(vehicle,part) end

local function frameTooltip(chr,part,line)
    if not part:getInventoryItem() then return end
    local cupboard=part:getVehicle():getPartById(A.overhead[topIndex(part)])
    if cupboard and (cupboard:getInventoryItem() or not R.empty(cupboard)) then
        line(getText("Tooltip_vehicle_requireUnistalled",VLS.getMechanicsPartName(cupboard)),false)
    end
end
local spec = {
    accepts=C.isPart,itemType=C.TOP_TYPE,
    materials={["Base.MetalPipe"]=4,["Base.SmallSheetMetal"]=2,["Base.Screws"]=8},
    uses={["Base.BlowTorch"]=6,["Base.WeldingRods"]=2},
    salvage={{"MetalPipe",2,15},{"SmallSheetMetal",1,15},{"Screws",4,25}},
    mechanics=2,metalWelding=3,
    canInstall=C.canInstall,canDismantle=C.canDismantle,prepareInstall=C.prepareInstall,
    onInstalled=C.installed,onDestroyed=C.destroyed,extraTooltip=frameTooltip,
}
-- Core recipes remain untouched, including KI5 Campers' material scaling.
local baseSpec=R.fabricationSpec
function R.fabricationSpec(part)
    if C.isPart(part) then return spec end
    return baseSpec(part)
end
local ticks=0
local function onTick()
    ticks=ticks+1
    if ticks%30~=0 then return end
    for part in pairs(registered) do
        local vehicle=part:getVehicle()
        if not vehicle or not C.isPart(part) or vehicle:isRemovedFromWorld() then
            registered[part]=nil
            if vehicle then cache[vehicle]=nil end
        else
            C.sync(vehicle,part)
        end
    end
end
Events.OnTick.Add(onTick)
return C
