-- Run inside the bundled game's initialized LuaManager. The harness supplies moduleSource.
local profile={seatPairs={}}
local ids={"SeatBed","VLSLargeVanSlot2","VLSLargeVanSlot3","VLSLargeVanSlot4","VLSLargeVanSlot5","VLSF700Slot6"}
local rows={"vehicle Fixture { passenger FrontLeft {} passenger FrontRight {}"}
for i,id in ipairs(ids) do
    local passenger="P"..(i+1)
    profile.seatPairs[i]={seat="Seat"..passenger,living=id,passenger=passenger}
    rows[#rows+1]="passenger "..passenger.." {}"
    for _,part in ipairs({"Seat"..passenger,id}) do
        rows[#rows+1]="part "..part.." { category = VLSLiving, itemType = Base.TestSeat, specificItem = false, container { seat = "..passenger..", capacity = 20, } table install { time = 200, } }"
    end
end
rows[#rows+1]="}"
local script=VehicleScript.new();script:Load("Fixture",table.concat(rows,"\n"));script:Loaded()
VLS={getVehicleProfile=function()return profile end,canUninstallManagedPart=function()return true end,
    isInstallationEnabled=function()return true end,getSpaceAssignmentForSeat=function()return {}end}
isClient=function()return false end
local function driverSeat()return {getFullType=function()return "USMIL.Seat0" end}end
local tick
Events={OnTick={Add=function(fn)tick=fn end}}
ISUninstallVehiclePart={complete=function()return true end}
require=function(name) if name=="VLS_Config" then return VLS else return {} end end
local S=assert(loadstring(moduleSource))()
local function vehicle()
    local v={parts={},getScript=function()return script end,getCharacter=function()return nil end,isRemovedFromWorld=function()return false end}
    function v:getPartById(id)return self.parts[id]end
    for _,pair in ipairs(profile.seatPairs) do
        for _,id in ipairs({pair.seat,pair.living}) do
            local actual=VehiclePart.new(nil);actual:setScriptPart(script:getPartById(id));actual:setCategory("VLSLiving")
            local p={actual=actual,item=id==pair.seat and driverSeat() or nil}
            function p:getId()return id end
            function p:getVehicle()return v end
            function p:getInventoryItem()return self.item end
            function p:getScriptPart()return actual:getScriptPart()end
            function p:setScriptPart(def)actual:setScriptPart(def)end
            function p:getContainerSeatNumber()return actual:getContainerSeatNumber()end
            function p:getItemType()return actual:getItemType()end
            v.parts[id]=p
        end
    end
    return v
end
local first,second=vehicle(),vehicle()
local checks=0
local function eq(a,b)assert(a==b,tostring(a).." ~= "..tostring(b));checks=checks+1 end
S.sync(first);S.sync(second)
for i,pair in ipairs(profile.seatPairs) do
    local seat,living=first.parts[pair.seat],first.parts[pair.living]
    eq(seat:getContainerSeatNumber(),i+1);eq(living:getContainerSeatNumber(),-1)
    eq(seat:getItemType():get(0),"Base.TestSeat");eq(living:getItemType():get(0),"")
    eq(VLS.getSpaceAssignmentForSeat(first,i+1),nil)
    seat.item=nil;living.item={};S.completeSeat(first)
    eq(seat:getContainerSeatNumber(),-1);eq(living:getContainerSeatNumber(),i+1)
    eq(seat:getItemType():get(0),"");eq(living:getItemType():get(0),"Base.TestSeat")
    eq(second.parts[pair.seat]:getContainerSeatNumber(),i+1)
    eq(second.parts[pair.living]:getContainerSeatNumber(),-1)
    -- A fresh streamed/loaded vehicle starts with canonical definitions again.
    seat:setScriptPart(script:getPartById(pair.seat));living:setScriptPart(script:getPartById(pair.living));S.initSeat(first)
    eq(seat:getContainerSeatNumber(),-1);eq(living:getContainerSeatNumber(),i+1)
    living.item=nil;seat.item=driverSeat();tick()
    eq(seat:getContainerSeatNumber(),i+1);eq(living:getContainerSeatNumber(),-1)
    eq(seat.actual:getCategory(),"VLSLiving");eq(living.actual:getCategory(),"VLSLiving")
    eq(tonumber(living.actual:getTable("install").time),200)
    local probe=VehiclePart.new(nil);probe:setScriptPart(script:getPartById(pair.living))
    eq(probe:getContainerSeatNumber(),i+1) -- shared prototype never changed
    eq(probe:getItemType():get(0),"Base.TestSeat")
    seat.item=nil;S.completeSeat(first)
    eq(seat:getItemType():get(0),"Base.TestSeat");eq(living:getItemType():get(0),"Base.TestSeat")
    eq(second.parts[pair.seat]:getItemType():get(0),"Base.TestSeat")
    eq(second.parts[pair.living]:getItemType():get(0),"")
end
return "NATIVE_KAHLUA_BINDING_PASS checks="..checks.." six pairs; independent vehicles; init/replication restoration; metadata preserved"
