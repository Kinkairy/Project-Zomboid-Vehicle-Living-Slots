local root=assert(arg[1])
local T=dofile(root.."/tests/test_vls_top_space.lua")
local eq,checks=T.eq,0
local function check(a,b)eq(a,b);checks=checks+1 end
package.loaded.VLS_Pantry=VLSPantry
local tick
Events.OnTick={Add=function(fn)tick=fn end}
local A=require "VLS_KI5F700_Config"
local model=arg[3] or "Base.87fordF700swat"
local bus=A.buses[model]==true
local first=bus and 1 or 2
local count=bus and 14 or 6
local chairType=bus and "Base.87fordB700Seat2" or "USMIL.Seat0"
local profile=VLS.vehicleProfiles[model]
check(#profile.seatPairs,count);check(#profile.universalParts,count)
local function newScript()
    local s={parts={}}
    function s:getPartById(id)return self.parts[id]end
    function s:getModule()return nil end
    function s:setModule()end
    function s:copyPartsFrom(source,id)
        self.parts[id]={seat=source.parts[id].seat,id=id,itemType=source.parts[id].itemType}
    end
    function s:Load(_,text)
        for id,body in text:gmatch("part (%w+) (%b{})")do
            self.parts[id].seat=-1
            if body:find("itemType = ,",1,true)then self.parts[id].itemType="" end
        end
    end
    function s:Loaded()end
    function s:getPassengerIndex(id)return tonumber(id:match("P(%d+)")) or -1 end
    return s
end
VehicleScript={new=newScript}
local script=newScript()
for i,pair in ipairs(profile.seatPairs)do
    script.parts[pair.seat]={seat=i+first-1,id=pair.seat,itemType=chairType};script.parts[pair.living]={seat=i+first-1,id=pair.living,itemType="Base.Mov_Cot"}
end
local S=require "VLS_KI5F700_Seats"
local callbacks=0
VLS.PartComplete.UniversalSlot=function(_,part)callbacks=callbacks+1;VLS.ensureUniversalContainerProfile(part)end
local function noop()end
local function vehicle()
    local v,make=T.vehicle(model)
    v.characters={};v.getScript=function()return script end
    v.getCharacter=function(self,seat)return self.characters[seat]end
    v.isRemovedFromWorld=function()return false end
    v.getMechanicalID=function()return 1 end;v.transmitPartItem=noop;v.transmitPartCondition=noop
    v.canInstallPart=function(_,_,part)return not part.item end
    v.canUninstallPart=function(_,_,part)return S.canRemove(part)end
    local inv={items={}}
    function inv:contains(i)return self.items[i]==true end
    function inv:containsID(id)for i in pairs(self.items)do if i:getID()==id then return true end end;return false end
    function inv:DoRemoveItem(i)assert(self.items[i]);self.items[i]=nil end
    function inv:AddItem(i)assert(not self.items[i]);self.items[i]=true end
    function inv:hasRoomFor()return true end
    local chr={getInventory=function()return inv end,isMechanicsCheat=function()return false end,
        isTimedActionInstant=function()return false end,getPerkLevel=function()return 10 end,removeFromHands=noop,
        addMechanicsItem=noop,sendObjectChange=noop,getCurrentSquare=function()return {}end}
    for _,pair in ipairs(profile.seatPairs)do
        for _,id in ipairs({pair.seat,pair.living})do
            local part=make(id);part.definition=script.parts[id]
            part.container.isEmpty=function(self)return self.weight==0 end
            function part:getScriptPart()return self.definition end
            function part:setScriptPart(def)self.definition=def end
            function part:getContainerSeatNumber()return self.definition.seat end
            local native=id==pair.seat
            local ft=native and chairType or "Base.Mov_Cot"
            function part:getItemType()
                local ft=self.definition.itemType
                return {isEmpty=function()return false end,size=function()return 1 end,
                    contains=function(_,t)return t==ft end,get=function()return ft end}
            end
            function part:getTable()return {skills={},requireEmpty=true,complete=native and S.completeSeat or S.completeLiving}end
            if native then part.item=T.item(ft)end
        end
    end
    S.sync(v)
    return v,chr,inv
end
local v,chr,inv=vehicle();local other=vehicle()
for i,pair in ipairs(profile.seatPairs)do
    local seat,space=v.parts[pair.seat],v.parts[pair.living]
    local original=seat.item;local bed=T.item("Base.Mov_Cot");inv.items[bed]=true
    local installBed=ISInstallVehiclePart:new(chr,space,bed,200)
    check(installBed:isValid(),false);check(installBed:complete(),false);check(inv.items[bed],true)
    local removeSeat=ISUninstallVehiclePart:new(chr,seat,200)
    v.characters[i+first-1]={};check(removeSeat:isValid(),false);check(removeSeat:complete(),false);v.characters[i+first-1]=nil
    seat.container.weight=1;check(removeSeat:complete(),false);seat.container.weight=0
    check(removeSeat:complete(),true);check(inv.items[original],true)
    local installSeat=ISInstallVehiclePart:new(chr,seat,original,200)
    check(installSeat:isValid(),true);check(installBed:isValid(),true)
    -- Both actions were queued while empty. Bed wins; seat must keep its input.
    check(installBed:complete(),true);check(space.item,bed);check(inv.items[bed],nil)
    check(installSeat:isValid(),false);check(installSeat:complete(),false);check(inv.items[original],true)
    check(seat:getContainerSeatNumber(),-1);check(space:getContainerSeatNumber(),i+first-1)
    check(VLS.getInstalledBedPartForSeat(v,i+first-1),space)
    check(other.parts[pair.seat]:getContainerSeatNumber(),i+first-1)
    local removeBed=ISUninstallVehiclePart:new(chr,space,200)
    v.characters[i+first-1]={};check(removeBed:complete(),false);v.characters[i+first-1]=nil
    space.container.weight=1;check(removeBed:complete(),false);space.container.weight=0
    check(removeBed:complete(),true);check(inv.items[bed],true)
    check(installSeat:complete(),true);check(seat.item,original);check(inv.items[original],nil)
    check(installBed:complete(),false);check(inv.items[bed],true)
    check(VLS.getSpaceAssignmentForSeat(v,i+first-1),nil)
    check(seat:getContainerSeatNumber(),i+first-1);check(space:getContainerSeatNumber(),-1)
    -- Reload restores definitions without changing either exact inventory item.
    seat:setScriptPart(script.parts[pair.seat]);space:setScriptPart(script.parts[pair.living]);S.initSeat(v)
    check(space:getContainerSeatNumber(),-1);check(seat.item,original)
    check(script.parts[pair.seat].seat,i+first-1);check(script.parts[pair.living].seat,i+first-1)
end
check(callbacks,count*2)
local pair=profile.seatPairs[1];local seat,space=v.parts[pair.seat],v.parts[pair.living]
local function remove(part)check(ISUninstallVehiclePart:new(chr,part,200):complete(),true)end
local original=seat.item;remove(seat)
-- Reject wrong native items at the final transaction boundary, including cheat mode.
local wrong=T.item("Base.Mov_FridgeMini");inv.items[wrong]=true
chr.isMechanicsCheat=function()return true end
check(ISInstallVehiclePart:new(chr,seat,wrong,200):isValid(),false)
check(ISInstallVehiclePart:new(chr,seat,wrong,200):complete(),false);check(inv.items[wrong],true)
chr.isMechanicsCheat=function()return false end
-- Furniture blocks original seats and keeps the VLS non-sittable classification.
check(ISInstallVehiclePart:new(chr,space,wrong,200):complete(),true)
check(VLS.getInstalledBedPartForSeat(v,first),nil)
check(ISInstallVehiclePart:new(chr,seat,original,200):complete(),false)
space.container.weight=1;check(ISUninstallVehiclePart:new(chr,space,200):complete(),false);space.container.weight=0
remove(space)
-- Contents arriving in the other empty part block installation without consumption.
space.container.weight=1;check(ISInstallVehiclePart:new(chr,seat,original,200):complete(),false);space.container.weight=0
check(ISInstallVehiclePart:new(chr,seat,original,200):complete(),true)
-- Failure paths still use native item return, never a synthetic second item.
remove(seat);VehicleUtils.calculateInstallationSuccess=function()return 0,0 end
check(ISInstallVehiclePart:new(chr,seat,original,200):complete(),true)
check(seat.item,nil);check(inv.items[original],true)
-- New SWAT chairs are real driver chairs; no inventory/old-save conversion exists.
VehicleUtils.calculateInstallationSuccess=function()return 100,0 end
-- Addon scope never enrolls Bank or a future bus in paired seat rules.
for _,name in ipairs({"Base.87fordF700bank","Base.87fordF700box"})do
    local car,make=T.vehicle(name);local part=make("SeatP2")
    part.item=T.item("Base.87fordB700RearSeat");local old=part.item
    S.sync(car);check(part.item,old);check(S.pair(part),nil);check(S.canInstall(part,nil),true)
end
-- Exercise the native repair missing-item decision, which bypasses install
-- recipes. This branch is transcribed from B42.20 VehiclePart.repair; its
-- getItemType/Loaded behavior is separately checked with real Java objects.
local generated=0
local function repairPart(car,part)
    local types=part:getItemType()
    if not part:getInventoryItem() and types and not types:isEmpty() then
        local ft=types:get(0)
        if ft and ft~="" then
            generated=generated+1;part:setInventoryItem(T.item(ft))
            if part:getId()==S.pair(part).seat then S.initSeat(car) else S.initLiving(car,part) end
        end
    end
    part:setCondition(100)
    if part:getInventoryItem() then part:getInventoryItem():setCondition(100) end
end
local function repairAll(car,reverse)
    for n=1,#car.order do
        repairPart(car,car.order[reverse and (#car.order-n+1) or n])
    end
end
VehicleUtils.createPartInventoryItem=function(part)
    local item=T.item(part:getItemType():get(0));part:setInventoryItem(item);return item
end
local repairCases=0
for _,reverse in ipairs({false,true})do
    local car,player,inventory=vehicle()
    -- Simulate native seat creation followed by addvehicle's full repair.
    for _,p in ipairs(profile.seatPairs)do
        local native,living=car.parts[p.seat],car.parts[p.living]
        native.item=nil;living.item=nil;native:setScriptPart(script.parts[p.seat]);living:setScriptPart(script.parts[p.living])
    end
    -- BaseVehicle.createPhysics calls all create callbacks, then all init
    -- callbacks; AddVehicleCommand calls repair only after addToWorld returns.
    for _,p in ipairs(profile.seatPairs)do Vehicles.Create.Default(car,car.parts[p.seat])end
    for n=1,#car.order do
        local part=car.order[reverse and (#car.order-n+1) or n]
        if part:getId()==S.pair(part).seat then S.initSeat(car) else S.initLiving(car,part) end
    end
    for repeated=1,3 do repairAll(car,reverse)end
    for i,p in ipairs(profile.seatPairs)do
        local native,living=car.parts[p.seat],car.parts[p.living];local chair=native.item
        check(chair:getFullType(),chairType);check(living.item,nil)
        check(living:getItemType():get(0),"");check(native:getItemType():get(0),chairType)
        check(ISUninstallVehiclePart:new(player,native,200):complete(),true)
        check(native.item,nil);check(living.item,nil);check(inventory.items[chair],true)
        check(VLS.getPartDisplayName(living),profile.spacePassengers[i].nameKey)
        check(native:getItemType():get(0),chairType);check(living:getItemType():get(0),"Base.Mov_Cot")
        local bed=T.item("Base.Mov_Cot");inventory.items[bed]=true
        check(ISInstallVehiclePart:new(player,living,bed,200):complete(),true)
        for repeated=1,3 do repairAll(car,reverse)end
        check(native.item,nil);check(living.item,bed);check(native:getItemType():get(0),"")
        -- Single-part repair must also respect the installed opposite.
        repairPart(car,native);check(native.item,nil);check(living.item,bed)
        check(ISUninstallVehiclePart:new(player,living,200):complete(),true)
        check(native.item,nil);check(living.item,nil);check(inventory.items[bed],true)
        check(ISInstallVehiclePart:new(player,native,chair,200):complete(),true)
        repairPart(car,living);check(native.item,chair);check(living.item,nil)
        -- Re-stream/replication restores script definitions; init must restore
        -- blocking without serializing or changing shared canonical metadata.
        native:setScriptPart(script.parts[p.seat]);living:setScriptPart(script.parts[p.living]);S.initLiving(car,living)
        repairAll(car,reverse);check(living.item,nil);check(native.item,chair)
        check(script.parts[p.seat].itemType,chairType);check(script.parts[p.living].itemType,"Base.Mov_Cot")
        repairCases=repairCases+1
    end
    -- If both parts are empty, whichever repair visits first wins. The init
    -- callback blocks the opposite before the next repair in the same loop.
    for _,p in ipairs(profile.seatPairs)do car.parts[p.seat].item=nil;car.parts[p.living].item=nil end
    S.initSeat(car);repairAll(car,reverse)
    for _,p in ipairs(profile.seatPairs)do
        local native,living=car.parts[p.seat],car.parts[p.living]
        check((native.item~=nil)~=(living.item~=nil),true)
        local installed=native.item or living.item
        for repeated=1,3 do repairAll(car,reverse)end
        check(native.item or living.item,installed)
    end
end
check(repairCases,count*2)
print("F700_REPAIR_EXCLUSION_PASS cases="..repairCases.." six pairs; both repair orders; create/repair/remove/equip/repair/reload")
print("F700_SIX_PAIRS_PASS checks="..checks.." native install/uninstall bodies; mocked engine")
