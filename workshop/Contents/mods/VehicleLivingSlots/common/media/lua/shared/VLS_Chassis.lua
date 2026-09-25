-- RC3.9 top-space candidate: apply a fixed fraction to unmodified total mass.
-- Every peer derives it from script mass, installed parts and actual cargo.
-- Never feed an already discounted vehicle:getMass() back into the formula.
require "VLS_RoofCargo"
VLS.Chassis=VLS.Chassis or {}
local C=VLS.Chassis
local R=VLSRoofCargo
C.ID="VLSImprovedChassis"
C.TYPE="Base.VLSImprovedChassis"
C.TOP_ID="VLSTopFrame1"
C.TOP_IDS={"VLSTopFrame1","VLSTopFrame2","VLSTopFrame3"}
C.TOP_COUNT={SUV=1,PickUpVan=1,Van=2,StepVan=3}
local function topIndex(part)
    return part and tonumber(part:getId():match("^VLSTopFrame([1-3])$"))
end
C.TOP_TYPE="Base.VLSTopFrame"
C.ITEM_WEIGHT=0
-- Calibration uses the agreed stock body + full rack/living/top cargo values.
-- Keep these rates fixed as cargo is loaded/unloaded. They are not recomputed
-- from a vehicle's discounted mass or from currently installed storage capacity.
-- Split the previously agreed total budget by rack/living versus top capacity.
-- Both fittings use one undiscounted total and one mass update, never compound.
C.REDUCTION_RATE={
    StepVan=(650*650/800)/(1160+800),
    Van=(450*450/600)/(816+600),
    VanSeats=450/(816+600), -- no overhead slots: preserve the accepted rate.
    SUV=(250*300/400)/(1000+400),
    PickUpVan=(250*300/400)/(1104+400),
}
-- Keep the calibrated reduction PER FRAME unchanged when slot counts change.
C.TOP_RATE={
    StepVan=3*40.625/(1160+800),
    Van=2*37.5/(816+600),
    SUV=31.25/(1000+400),
    PickUpVan=31.25/(1104+400),
}
local function expectedType(part)
    return topIndex(part) and C.TOP_TYPE or C.TYPE
end
local function installedItem(part)
    local item=part and part:getInventoryItem()
    if item and item:getFullType()==expectedType(part) then return item end
    return nil
end
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
    if not script then return false end
    local id=part:getId()
    if vehicle:getPartById(id)~=part then return false end
    if id==C.ID then return R.vehicleScripts[script:getFullName()]==true end
    return topIndex(part) and topIndex(part)<=C.topCount(vehicle) or false
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

function C.topCount(vehicle)
    local family=C.family(vehicle)
    if family then
        return R.vehicleScripts[vehicle:getScript():getFullName()] and (C.TOP_COUNT[family] or 0) or 0
    end
    local profile=VLS.getVehicleProfile(vehicle)
    return profile and profile.kind=="ki5Camper" and #(profile.overheadParts or {}) or 0
end

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
    local family=C.family(vehicle)
    local chassisRate=family and C.REDUCTION_RATE[family] or 0
    local topRate=(family and C.TOP_RATE[family] or 0)/(C.TOP_COUNT[family] or 1)
    local count=C.topCount(vehicle)
    if not family then
        local profile=VLS.getVehicleProfile(vehicle)
        if not profile or profile.kind~="ki5Camper" or count==0 then return nil end
        -- The same per-position budget, calibrated to this trailer's native
        -- body plus full living cupboards and top cupboards; no rack/chassis bonus.
        topRate=profile.topFrameReduction/(base+50*(#profile.universalParts+count))
    end
    if not finite(chassisRate) then return nil end
    local chassis=vehicle:getPartById(C.ID)
    local activeRate=installedItem(chassis) and chassisRate or 0
    for i=1,C.topCount(vehicle) do
        if installedItem(vehicle:getPartById(C.TOP_IDS[i])) then activeRate=activeRate+topRate end
    end
    local rate=activeRate
    if previewPart and not installedItem(previewPart) then
        rate=rate+(topIndex(previewPart) and topRate or chassisRate)
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
        net=previewPart and total*(topIndex(previewPart) and topRate or chassisRate) or reduction,
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
    return parked(chr,part) and (topIndex(part) or C.hasJack(chr)) and not installedItem(part)
        and C.preview(part)~=nil
end

function C.canDismantle(chr,part)
    if not parked(chr,part) then return false end
    local index=topIndex(part)
    if not index then return C.hasJack(chr) end
    local cupboard=part:getVehicle():getPartById(VLS.OVERHEAD_PART_IDS[index])
    return not cupboard or (not cupboard:getInventoryItem() and R.empty(cupboard))
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
    local item=installedItem(part)
    local t=targets(vehicle)
    if not t then return false end
    local current=vehicle:getInitialMass()
    if not acceptedInitial(current,t,part) then
        warn(vehicle,part,current,t)
        return false
    end

    local chassisItem=installedItem(vehicle:getPartById(C.ID))
    local itemChanged=false
    local identity={tostring(chassisItem and chassisItem:getID() or -1)}
    for i=1,C.topCount(vehicle) do
        local frameItem=installedItem(vehicle:getPartById(C.TOP_IDS[i]))
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
            assert(part:getInventoryItem()==fixed,"chassis item assignment failed")
            registered[part]=true
            C.sync(vehicle,part)
            local t=targets(vehicle)
            assert(t and same(vehicle:getInitialMass(),t.target),"chassis mass application failed")
            assert(same(fixed:getWeight(),0),"unexpected chassis item weight")
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
    local equipment=index and vehicle:getPartById(VLS.OVERHEAD_PART_IDS[index])
    if host() and not part:getInventoryItem() and equipment and equipment:getInventoryItem() then
        local frame=instanceItem(C.TOP_TYPE)
        if frame then part:setInventoryItem(frame);vehicle:transmitPartItem(part) end
    end
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

local function frameTooltip(chr,part,line)
    if not part:getInventoryItem() then return end
    local cupboard=part:getVehicle():getPartById(VLS.OVERHEAD_PART_IDS[topIndex(part)])
    if cupboard and (cupboard:getInventoryItem() or not R.empty(cupboard)) then
        line(getText("Tooltip_vehicle_requireUnistalled",VLS.getMechanicsPartName(cupboard)),false)
    end
end
for _,id in ipairs(C.TOP_IDS) do
    R.fabricatedParts[id]={
        accepts=C.isPart,itemType=C.TOP_TYPE,scaleWithVehicle=true,
        materials={["Base.MetalPipe"]=4,["Base.SmallSheetMetal"]=2,["Base.Screws"]=8},
        uses={["Base.BlowTorch"]=6,["Base.WeldingRods"]=2},
        salvage={{"MetalPipe",2,15},{"SmallSheetMetal",1,15},{"Screws",4,25}},
        mechanics=2,metalWelding=3,
        canInstall=C.canInstall,canDismantle=C.canDismantle,prepareInstall=C.prepareInstall,
        onInstalled=C.installed,onDestroyed=C.destroyed,extraTooltip=frameTooltip,
    }
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
if not C.tickRegistered then C.tickRegistered=true;Events.OnTick.Add(onTick) end
return C
