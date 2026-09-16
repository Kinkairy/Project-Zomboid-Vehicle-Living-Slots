-- Run with Lua 5.1+: lua tools/test_vls_regressions.lua [repository root]
-- Mocks test Lua contracts, not Project Zomboid's Java engine or gameplay.
local root=arg[1] or "."
local base=root.."/workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media/lua/"
local n,failed=0,0
local function test(name,fn)
    n=n+1
    local ok,err=pcall(fn)
    if ok then print("PASS "..name) else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local noop=function() end
local V={FREEZER_PART_BY_UNIVERSAL={},UNIVERSAL_PART_BY_FREEZER={},allowedItems={},equipmentProfiles={},sleepingBagTypes={},WATER_TANK_PART_IDS={},vehicleProfiles={},mechanicsDisplayProviders={},getAuxBatteryPart=noop,getPartDisplayName=noop}
package.loaded.VLS_Config=V
package.loaded.VLS_Propane=V
V.MOD_ID="VehicleLivingSlots"
local adapter=dofile(base.."shared/VLS_KI5Campers_Config.lua")
package.loaded.VLS_KI5Campers_Config=adapter
local file=assert(io.open(root.."/workshop/Contents/mods/VehicleLivingSlotsKI5Campers/42.20/mod.info"));local info=file:read("*a");file:close()
test("adapter runtime version matches mod.info",function() eq(V.KI5_VERSION,info:match("modversion=([^\r\n]+)")) end)
test("profile registration remains 2/3/3/4 slots",function()
    eq(#V.vehicleProfiles["Base.Trailer87Scamp13"].universalParts,2)
    eq(#V.vehicleProfiles["Base.Trailer87Scamp16"].universalParts,3)
    eq(#V.vehicleProfiles["Base.Trailer61Bambi16"].universalParts,3)
    eq(#V.vehicleProfiles["Base.Trailer54FlyingCloud22"].universalParts,4)
end)
-- Reject malformed commands BEFORE Java-like lookup or any state mutation.
isClient=function() return false end
local commandHook
Events={OnClientCommand={Add=function(fn) commandHook=fn end}}
instanceof=function(item,name) return name=="DrainableComboItem" and item.drainable end
local calls=0
local charge,gas=0.25,10000
local torch={drainable=true,getFullType=function() return "Base.BlowTorch" end,getMaxUses=function() return 10 end,getCurrentUsesFloat=function() return charge end,setCurrentUsesFloat=function(_,v) charge=v end,syncItemFields=noop}
local propane={getID=function() return 77 end,getCurrentUses=function() return gas end,setCurrentUses=function(_,v) gas=v end,syncItemFields=noop}
local part={getId=function() return "DAMNPropaneTankOne" end,getArea=function() return "Tank" end}
local stopped,atArea,supported,inVehicle,distance=true,true,true,false,1
local vehicle={isStopped=function() return stopped end,isInArea=function() return atArea end,transmitPartUsedDelta=noop}
getVehicleById=function(id) calls=calls+1; assert(type(id)=="number" and id==id and id==math.floor(id) and math.abs(id)<math.huge,"invalid Java vehicle ID"); if id==42 then return vehicle end end
local inventory={getItemWithIDRecursiv=function(_,id) assert(type(id)=="number" and id==id and id==math.floor(id) and math.abs(id)<math.huge,"invalid Java item ID"); if id==7 then return torch end end}
local player={getVehicle=function() return inVehicle and vehicle or nil end,getInventory=function() return inventory end,DistToProper=function() return distance end}
V.isSupportedVehicle=function() return supported end
V.getInstalledPropaneSource=function(_,pid) if pid=="DAMNPropaneTankOne" then return propane,part end end
dofile(root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/server/VLS_PropaneServer.lua")
local function valid() return {vehicle=42,part="DAMNPropaneTankOne",torch=7,tank=77} end
local invalid={false,true,1,"invalid",{}, {vehicle={},part="DAMNPropaneTankOne",torch=7}, {vehicle=42,part={},torch=7}}
for _,field in ipairs({"vehicle","torch"}) do
    for _,value in ipairs({true,{},"42",0/0,math.huge,-math.huge,1.5}) do
        local p=valid();p[field]=value;invalid[#invalid+1]=p
    end
end
local missing=valid();missing.torch=nil;invalid[#invalid+1]=missing
local empty=valid();empty.part="";invalid[#invalid+1]=empty
for i,args in ipairs(invalid) do
    test("invalid refill packet "..i.." has no lookup/debit",function()
        calls=0;charge=0.25;gas=10000
        eq(V.PropaneServer.refillBlowTorch(player,args),false)
        eq(calls,0);eq(charge,0.25);eq(gas,10000)
    end)
end
test("nil refill packet rejected",function() eq(V.PropaneServer.refillBlowTorch(player,nil),false) end)
test("dispatcher rejects malformed refill without throwing",function() commandHook("VehicleLivingSlots","refillBlowTorch",player,false) end)
test("valid refill preserves original 70:1 conversion",function()
    charge=0.25;gas=10000;eq(V.PropaneServer.refillBlowTorch(player,valid()),true);eq(charge,1);eq(gas,9475)
end)
test("full torch does not consume propane",function() eq(V.PropaneServer.refillBlowTorch(player,valid()),false);eq(gas,9475) end)
test("limited propane still partially refills",function() charge=0;gas=70;eq(V.PropaneServer.refillBlowTorch(player,valid()),true);eq(charge,0.1);eq(gas,0) end)
for _,condition in ipairs({"moving","inside","far","wrong area","unsupported","missing torch","unknown vehicle"}) do
    test(condition.." rejected",function()
        stopped=true;inVehicle=false;distance=1;atArea=true;supported=true;charge=0;gas=10000
        local args=valid()
        if condition=="moving" then stopped=false elseif condition=="inside" then inVehicle=true elseif condition=="far" then distance=5 elseif condition=="wrong area" then atArea=false elseif condition=="unsupported" then supported=false elseif condition=="missing torch" then args.torch=999 elseif condition=="unknown vehicle" then args.vehicle=999 end
        eq(V.PropaneServer.refillBlowTorch(player,args),false);eq(charge,0);eq(gas,10000)
    end)
end
-- Seat renderer temporarily changes shared Java script offsets; always unwind.
local offsets={}
local function vector(x,y,z)
    local a={[0]=x,[1]=y,[2]=z}
    a.get=function(self,i) return self[i] end;a.set=function(self,X,Y,Z) self[0]=X;self[1]=Y;self[2]=Z end
    return a
end
local passengers={}
for i,id in ipairs({"SideB","FrontL","FrontR"}) do
    local v=vector(i,0,i*2);offsets[i]=v
    passengers[i]={getId=function() return id end,getPositionById=function() return {getOffset=function() return v end} end}
end
local script={getPassengerCount=function() return #passengers end,getPassenger=function(_,i) return passengers[i+1] end,getExtents=function() return {z=function() return 5 end} end}
local drawError,hitError=false,false
local drawCount=0
ISVehicleSeatUI={render=function() drawCount=drawCount+1;if drawError then error("draw fault") end end,useSeat=noop}
package.loaded["Vehicles/ISUI/ISVehicleSeatUI"]=true
SeatOffsetX={};SeatOffsetY={}
local panel={height=500,width=300,getWidth=function(self) return self.width end,getHeight=function(self) return self.height end,getMouseX=function() if hitError then error("hit fault") end;return -100 end,getMouseY=function() return -100 end,vehicle={getScriptName=function() return "Base.Trailer54FlyingCloud22" end,getScript=function() return script end,getMaxPassengers=function() return #passengers end}}
dofile(base.."client/VLS_KI5Campers_SeatUI.lua")
local function unchanged() for i,v in ipairs(offsets) do eq(v:get(0),i);eq(v:get(1),0);eq(v:get(2),i*2) end end
test("normal seat rendering restores offsets",function() ISVehicleSeatUI.render(panel);unchanged() end)
test("drawing exception restores offsets and propagates",function() drawError=true;local ok=pcall(ISVehicleSeatUI.render,panel);drawError=false;eq(ok,false);unchanged() end)
test("hit-test exception restores offsets and propagates",function() hitError=true;local ok=pcall(ISVehicleSeatUI.render,panel);hitError=false;eq(ok,false);unchanged() end)
test("repeated rendering never accumulates offsets",function() for i=1,10 do ISVehicleSeatUI.render(panel) end;unchanged() end)
print(string.format("RESULT tests=%d failures=%d",n,failed))
if failed>0 then os.exit(1) end
