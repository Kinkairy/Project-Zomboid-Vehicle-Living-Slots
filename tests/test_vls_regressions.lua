-- Run with Lua 5.1+: lua ../../tests/vehicle-living-slots/test_vls_regressions.lua [repository root]
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
local function read(path)
    local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
test("outside water fill keeps its endpoint sync helper",function()
    local source=read(root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/server/VLS_ApplianceServer.lua")
    local definition=assert(source:find("local function syncFluidTransferEndpoint(vehicle, item, part)",1,true))
    local call=assert(source:find("syncFluidTransferEndpoint(vehicle, tank, part)",1,true))
    assert(definition<call)
    assert(source:find("VLS.syncVehicleWaterTank(vehicle, part)",definition,true))
    assert(source:find("vehicle:transmitPartItem(part)",definition,true))
end)
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
test("new Shasta profiles retain battery, dual water and three slots",function()
 for _,name in ipairs({"Trailer61Airflyte","Trailer61Astrodome"})do
  local p=V.vehicleProfiles["Base."..name]
  eq(#p.universalParts,3);eq(#p.spacePassengers,3);eq(p.auxBatteryPartId,"Battery")
  eq(#p.waterTankParts,2);eq(#p.propaneTankParts,2)
 end
end)
-- Refill action network/ownership cases are in test_vehicle_propane.lua.
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
