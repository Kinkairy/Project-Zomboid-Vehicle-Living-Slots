-- lua5.1 tools/test_roof_capacity.lua [repo root]
-- Loads actual VLS Lua and scripts. Native engine objects below are mocks.
local root=arg[1] or "."
local base=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/"
local n,fail=0,0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn)
    n=n+1
    local ok,e=pcall(fn)
    if ok then print("PASS "..name) else fail=fail+1;print("FAIL "..name..": "..tostring(e)) end
end
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
VLS={equipmentProfiles={},supportedMoveableSprites={},installationOptionProviders={}}
package.loaded.VLS_Config=VLS
local client=false
isClient=function() return client end
isServer=function() return not client end
local damageUpdates=0
VLS.Damage={Init=function() end,Update=function() damageUpdates=damageUpdates+1 end}
dofile(base.."lua/shared/VLS_RoofCargo.lua")
local R=VLSRoofCargo
local function target(name)
    if name:find("^Base%.StepVan") then return 400 end
    if name:find("^Base%.Van") then return 300 end
    if name=="Base.SUV" or name:find("^Base%.PickUpVan") then return 250 end
    error("Unhandled family: "..name)
end
local function fixture(name,cap)
    local cargo={id=123,condition=42};local writes=0
    local storage={cap=cap,cargo=cargo}
    function storage:getCapacity() return self.cap end
    function storage:setCapacity(v) self.cap=v;writes=writes+1 end
    function storage:isEmpty() return false end
    local item={cap=cap,health=61}
    function item:getFullType() return R.fixedType end
    function item:getMaxCapacity() return self.cap end
    function item:setMaxCapacity(v) self.cap=v;writes=writes+1 end
    local v={name=name,sent=0}
    function v:getScript() return {getFullName=function() return self.name end} end
    function v:getPartById(id) if id==R.fixedId then return self.rack end end
    function v:transmitPartItem(p) eq(p,self.rack);self.sent=self.sent+1 end
    function v:isInArea() return true end
    local p={vehicle=v,id=R.fixedId,item=item,storage=storage,cap=cap};v.rack=p
    function p:getId() return self.id end
    function p:getVehicle() return self.vehicle end
    function p:getInventoryItem() return self.item end
    function p:getItemContainer() return self.storage end
    function p:getContainerCapacity() return self.cap end
    function p:setContainerCapacity(v) self.cap=v;writes=writes+1 end
    function p:getArea() return "TruckBed" end
    -- Capacity refresh is forbidden from replacing either persistent object.
    function p:setInventoryItem() error("must not replace/remove installed rack") end
    function p:setItemContainer() error("must not replace/clear cargo container") end
    return v,p,item,storage,cargo,function() return writes end
end
local variants=0
for name in pairs(R.vehicleScripts) do
    variants=variants+1
    test(name.." +100; installed rack/cargo identity; repeat safe",function()
        client=false
        local expected=target(name);eq(R.rackCapacities[name],expected)
        local v,p,item,storage,cargo,writes=fixture(name,expected-100)
        R.InitFixedRack(v,p)
        eq(item.cap,expected);eq(p.cap,expected);eq(storage.cap,expected)
        eq(p.item,item);eq(p.storage,storage);eq(storage.cargo,cargo)
        eq(item.health,61);eq(cargo.condition,42);eq(v.sent,1)
        local count=writes()
        for i=1,20 do R.UpdateFixedRack(v,p);R.InitFixedRack(v,p) end
        eq(item.cap,expected);eq(storage.cap,expected);eq(v.sent,1);eq(writes(),count)
    end)
end
test("106 supported scripts and no extra capacity keys",function()
    eq(variants,106);local count=0
    for name in pairs(R.rackCapacities) do assert(R.vehicleScripts[name]);count=count+1 end
    eq(count,variants)
end)
test("client first access restores real container without outbound packets",function()
    client=true;local v,p,item,storage=fixture("Base.SUV",150)
    assert(R.Access(v,p,{getVehicle=function() return nil end}))
    eq(item.cap,250);eq(storage.cap,250);eq(p.cap,250);eq(v.sent,0);client=false
end)
test("update fixes previously loaded rack without reinstallation",function()
    local v,p,item,storage=fixture("Base.Van",200)
    local before=damageUpdates;R.UpdateFixedRack(v,p)
    eq(damageUpdates,before+1);eq(storage.cap,300);eq(item.cap,300)
end)
test("new native container/default 400 still respects small vehicle maximum",function()
    local v,p,item,storage=fixture("Base.SUV",400)
    R.InitFixedRack(v,p);eq(storage.cap,250);eq(item.cap,250)
end)
test("repaired/native stat refresh cannot leave stale container capacity",function()
    local v,p,item,storage=fixture("Base.StepVan",400)
    p.cap=300;storage.cap=300
    assert(R.syncFixedRackCapacity(v,p));eq(storage.cap,400);eq(p.cap,400);eq(v.sent,0)
end)
test("zero-condition racks stay installed and retain capacity/cargo",function()
    local v,p,item,storage,cargo=fixture("Base.SUV",150);item.health=0
    R.InitFixedRack(v,p);eq(item.health,0);eq(storage.cap,250);eq(storage.cargo,cargo)
end)
for _,case in ipairs({"empty","wrong item","wrong part","unsupported","wrong vehicle","stale part"}) do
    test("capacity refresh rejects "..case,function()
        local v,p,item,storage,cargo,writes=fixture("Base.SUV",150);local owner=v
        if case=="empty" then p.item=nil
        elseif case=="wrong item" then item.getFullType=function() return "Base.MetalBar" end
        elseif case=="wrong part" then p.id="VLSRoofSmallChest"
        elseif case=="unsupported" then v.name="Base.UnregisteredSUV"
        elseif case=="wrong vehicle" then owner={}
        elseif case=="stale part" then v.rack={} end
        eq(R.syncFixedRackCapacity(owner,p),false);eq(writes(),0);eq(storage.cargo,cargo)
    end)
end
test("missing container does not spawn a new one",function()
    local v,p,item=fixture("Base.Van",200);p.storage=nil
    R.syncFixedRackCapacity(v,p);eq(item.cap,300);eq(p.storage,nil)
end)
test("material scales still use 50/75/100 percent",function()
    local s=fixture("Base.SUV",150);local v=fixture("Base.Van",200);local t=fixture("Base.StepVan",300)
    eq(R.fabricationScale(s),0.5);eq(R.fabricationScale(v),0.75);eq(R.fabricationScale(t),1)
    eq(R.rackRecipe.materials["Base.MetalBar"],10)
end)
local function extract(text,marker)
    local a,b=text:find(marker);assert(a,marker);local depth=1;local p=b+1
    while depth>0 do local c=text:sub(p,p);assert(c~="","unclosed block");if c=="{" then depth=depth+1 elseif c=="}" then depth=depth-1 end;p=p+1 end
    return text:sub(a,p-1)
end
test("all native template capacities agree with Lua targets; small chests unchanged",function()
    local step=read(base.."scripts/VLS_StepVanRoofRackAdjustment.txt")
    local ad=read(base.."scripts/VLS_VehicleRoofAdapters.txt")
    for family,expected in pairs({VLSRoofReusableParts=400,VLSVanRoof=300,VLSSUVRoof=250,VLSPickUpVanRoof=250}) do
        local tpl=extract(ad,"template vehicle "..family.."%s*{")
        local rack=extract(tpl,"part VLSFixedRoofRack%s*{")
        eq(tonumber(rack:match("capacity%s*=%s*(%d+)")),expected)
        assert(rack:find("conditionAffectsCapacity%s*=%s*false"))
    end
    eq(tonumber(extract(step,"part VLSFixedRoofRack%s*{"):match("capacity%s*=%s*(%d+)")),400)
    for _,text in ipairs({step,ad}) do
        eq(tonumber(extract(text,"part VLSRoofSmallChest%s*{"):match("capacity%s*=%s*(%d+)")),10)
    end
    assert(read(base.."scripts/VLS_RoofRackItem.txt"):find("MaxCapacity%s*=%s*400"))
end)
print(string.format("RESULT roof-capacity tests=%d failures=%d variants=%d (mocked native objects)",n,fail,variants))
if fail>0 then os.exit(1) end
