-- lua5.1 tests/test_vls_material_tiers.lua [repo root]
-- Actual VLS Lua, mocked PZ objects. Not a Java engine or multiplayer playtest.
local root=arg[1] or "."
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/"
local passed,failed=0,0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<0.000001,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed=passed+1; print("PASS "..name)
    else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end
end
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local noop=function() end
local client=false
isClient=function() return client end
isServer=function() return not client end
ItemTag={WELDING_MASK="mask",WRENCH="wrench",BLOW_TORCH="torch"}
Perks={MetalWelding="welding",Mechanics="mechanics"}
VLS={equipmentProfiles={},supportedMoveableSprites={},installationOptionProviders={},
    isInstallationEnabled=function() return true end}
package.loaded.VLS_Config=VLS
Events={OnTick={Add=noop}}
Vehicles={InstallComplete={Default=noop}}
local nextId=0
local function item(ft,drainable,tag)
    nextId=nextId+1
    local o={ft=ft,id=nextId,drainable=drainable,delta=1,condition=100,tag=tag}
    function o:getFullType() return self.ft end
    function o:getID() return self.id end
    function o:hasTag(t) return self.tag==t end
    function o:getCurrentUsesFloat() return self.delta end
    function o:getUseDelta() return 0.01 end
    function o:getCurrentUses() return math.floor(self.delta/0.01+0.000001) end
    function o:setUsedDelta(v) self.delta=v end
    function o:Use() self.delta=math.max(0,self.delta-0.01) end
    function o:getCondition() return self.condition end
    function o:getConditionMax() return 100 end
    function o:setMaxCapacity(v) self.capacity=v end
    function o:setJobDelta(v) self.jobDelta=v end
    return o
end
instanceof=function(o,kind) return kind=="DrainableComboItem" and o.drainable or false end
instanceItem=function(ft) return item(ft) end
sendRemoveItemFromContainer=noop; syncItemFields=noop; addXp=noop
local function inventory()
    local o={items={}}
    function o:getItems()
        return {size=function() return #self.items end,get=function(_,i) return self.items[i+1] end}
    end
    function o:contains(it) for _,v in ipairs(self.items) do if v==it then return true end end;return false end
    function o:AddItem(it) self.items[#self.items+1]=it end
    function o:DoRemoveItem(it) for i,v in ipairs(self.items) do if v==it then table.remove(self.items,i);return end end end
    function o:getItemById(id) for _,v in ipairs(self.items) do if v.id==id then return v end end end
    function o:isEmpty() return #self.items==0 end
    return o
end
local function character(spec)
    local c={inv=inventory(),welding=5,mechanics=1}
    function c:getInventory() return self.inv end
    function c:isDead() return false end
    function c:getVehicle() return nil end
    function c:getPerkLevel(p) return self[p] or 0 end
    function c:getPrimaryHandItem() return self.primary end
    function c:getSecondaryHandItem() return self.secondary end
    function c:setPrimaryHandItem(v) self.primary=v end
    function c:setSecondaryHandItem(v) self.secondary=v end
    function c:removeFromHands(v) if self.primary==v then self.primary=nil end;if self.secondary==v then self.secondary=nil end end
    for ft,n in pairs(spec.materials) do for i=1,n do c.inv:AddItem(item(ft)) end end
    c.torch=item("Base.BlowTorch",true,"torch");c.rods=item("Base.WeldingRods",true)
    c.mask=item("Base.WeldingMask",false,"mask");c.wrench=item("Base.Wrench",false,"wrench")
    for _,v in ipairs({c.torch,c.rods,c.mask,c.wrench}) do c.inv:AddItem(v) end
    c.primary=c.torch
    return c
end
local function part(name,id)
    local v={name=name,parts={}}
    function v:getScript() return {getFullName=function() return self.name end} end
    function v:getPartById(pid) return self.parts[pid] end
    function v:isRemovedFromWorld() return false end
    function v:isStopped() return true end
    function v:isInArea() return true end
    function v:transmitPartItem() end
    local p={id=id,vehicle=v,storage=inventory()};v.parts[id]=p
    function p:getId() return self.id end
    function p:getVehicle() return self.vehicle end
    function p:getInventoryItem() return self.installed end
    function p:setInventoryItem(it) self.installed=it end
    function p:getItemContainer() return self.storage end
    function p:getArea() return "Area" end
    function p:getScriptPart() return nil end
    function p:setModelVisible() end
    return p
end

dofile(media.."lua/shared/VLS_RoofCargo.lua")
local R=VLSRoofCargo
package.loaded.VLS_RoofCargo=R
local A=dofile(media.."lua/shared/VLS_BodyArmor.lua")
package.loaded.VLS_BodyArmor=A
-- Mock only native action shells; keep all VLS checks/completions unchanged.
local function actionClass()
    local c={isValid=function() return true end,new=function(self) return setmetatable({},{__index=self}) end}
    function c:derive() return setmetatable({},{__index=self}) end
    return c
end
ISInstallVehiclePart=actionClass();ISUninstallVehiclePart=actionClass()
ISFixVehiclePartAction=actionClass();ISRemoveBurntVehicle=actionClass()
for _,name in ipairs({"VLS_InstallGuard","TimedActions/ISFixVehiclePartAction","Vehicles/TimedActions/ISRemoveBurntVehicle"}) do package.loaded[name]=true end
dofile(media.."lua/shared/VLS_RoofCargoActions.lua")
package.loaded.VLS_RoofCargoActions=true
-- Load the real mechanics menu, including its local recipeTooltip.
ISVehicleMechanics={ghs="OK",bhs="NO",doPartContextMenu=noop}
ISInventoryPaneContextMenu={onFix=noop}
ISWorldObjectContextMenu={addToolTip=function() return {} end}
ISVehiclePartMenu={}
UIManager={getSpeedControls=function() return {getCurrentGameSpeed=function() return 1 end} end}
JoypadState={players={}}
getText=function(s) return s end
getItemName=function(s) return s end
getItemDisplayName=getItemName
for _,name in ipairs({"Vehicles/ISUI/ISVehicleMechanics","Vehicles/ISUI/ISVehiclePartMenu"}) do package.loaded[name]=true end
dofile(media.."lua/client/VLS_RoofCargoMenu.lua")
local function menu(chr,p)
    local ctx={options={}}
    function ctx:removeOptionByName() end
    function ctx:setVisible() end
    function ctx:addOption(text,...) local op={name=text};self.options[#self.options+1]=op;return op end
    ISVehicleMechanics.doPartContextMenu({chr=chr,playerNum=0,context=ctx},p,0,0)
    return assert(ctx.options[#ctx.options])
end
local ids={R.fixedId,"VLSArmorWindshield","VLSArmorWindowFrontLeft","VLSBumperFront","VLSBumperRear"}
local expected={
    ["Base.StepVan"]={1,{10,4,4,1,10,4},{2,1,2,0,10,1},{6,2,4,0,10,2}},
    ["Base.Van"]={0.75,{8,3,3,1,8,3},{2,1,2,0,8,1},{5,2,3,0,8,2}},
    ["Base.VanSeats"]={0.75,{8,3,3,1,8,3},{2,1,2,0,8,1},{5,2,3,0,8,2}},
    ["Base.SUV"]={0.5,{5,2,2,1,5,2},{1,1,1,0,5,1},{3,1,2,0,5,1}},
    ["Base.PickUpVan"]={0.5,{5,2,2,1,5,2},{1,1,1,0,5,1},{3,1,2,0,5,1}},
}
local fields={"Base.MetalBar","Base.SmallSheetMetal","Base.Screws","Base.Tarp","Base.BlowTorch","Base.WeldingRods"}
for name,values in pairs(expected) do
    for _,id in ipairs(ids) do
        local want=values[id==R.fixedId and 2 or (id:find("Bumper") and 4 or 3)]
        test(name.." "..id.." recipe/menu/authoritative debit",function()
            local p=part(name,id);local spec=R.fabricationSpec(p);local chr=character(spec)
            eq(R.fabricationScale(p.vehicle),values[1])
            local op=menu(chr,p);eq(op.notAvailable,false)
            for i,ft in ipairs(fields) do
                eq(spec.materials[ft] or spec.uses[ft] or 0,want[i])
                if want[i]>0 then
                    local held=spec.materials[ft] or 100
                    assert(op.toolTip.description:find(ft.." "..held.."/"..want[i],1,true))
                end
            end
            for _,entry in ipairs(spec.salvage) do eq(entry[2],spec.materials["Base."..entry[1]]) end
            local a=setmetatable({character=chr,part=p,vehicle=p.vehicle,item=chr.inv.items[1]},{__index=VLSRoofInstallAction})
            assert(a:complete());eq(p.installed.ft,spec.itemType)
            local counts=R.materialStatus(chr,spec).counts
            for ft in pairs(spec.materials) do eq(counts[ft] or 0,0) end
            near(chr.torch.delta,1-spec.uses["Base.BlowTorch"]*0.01)
            near(chr.rods.delta,1-spec.uses["Base.WeldingRods"]*0.01)
            assert(chr.inv:contains(chr.mask) and chr.inv:contains(chr.wrench))
            if id==R.fixedId then eq(p.installed.capacity,R.rackCapacities[name]) end
            eq(a:complete(),false) -- installed part cannot be fabricated twice
        end)
        test(name.." "..id.." real dismantle uses reduced salvage cap",function()
            local p=part(name,id);local spec=R.fabricationSpec(p);local chr=character(spec)
            p.installed=item(spec.itemType);local expectedId=p.installed.id
            local got={}
            local a=setmetatable({character=chr,part=p,vehicle=p.vehicle,expectedItemId=expectedId,
                checkAddItem=function(_,ft,parameter)
                    got[ft]=(got[ft] or 0)+1
                    eq(parameter,ft=="Screws" and 25 or 15)
                    return true -- highest possible return, not guaranteed gameplay yield
                end},{__index=VLSRoofDismantleAction})
            assert(a:complete());eq(p.installed,nil)
            for _,entry in ipairs(spec.salvage) do eq(got[entry[1]],entry[2]) end
            near(chr.torch.delta,0.9) -- dismantling cost was NOT changed
            eq(a:complete(),false)
        end)
    end
end
-- Coverage is taken from the actual adapter file, not a guessed variant count.
local adapter=read(media.."scripts/VLS_ZBodyArmorVehicles.txt")
local variants=0
for name,family in adapter:gmatch("vehicle%s+([%w_]+)%s*{%s*template=VLSBodyArmor([%w_]+)") do
    variants=variants+1
    test("registered variant "..name.." follows "..family,function()
        local p=part("Base."..name,R.fixedId)
        assert(R.vehicleScripts["Base."..name])
        local want=family=="StepVan" and 1 or ((family=="Van" or family=="VanSeats") and 0.75 or 0.5)
        eq(R.fabricationScale(p.vehicle),want)
        local bars=R.fabricationSpec(p).materials["Base.MetalBar"]
        eq(bars,math.ceil(10*want))
    end)
end
test("all roof scripts covered by armor adapter coverage",function()
    local count=0;for name in pairs(R.vehicleScripts) do count=count+1;assert(adapter:find("vehicle "..name:sub(6).." {",1,true)) end
    eq(count,variants)
end)
for _,ft in ipairs(fields) do
    test("missing input "..ft.." rejected with no debit",function()
        local p=part("Base.SUV",R.fixedId);local spec=R.fabricationSpec(p);local chr=character(spec)
        if spec.materials[ft] then
            for _,it in ipairs(chr.inv.items) do if it.ft==ft then chr.inv:DoRemoveItem(it);break end end
        else
            local it=ft=="Base.BlowTorch" and chr.torch or chr.rods;it.delta=(spec.uses[ft]-1)*0.01
        end
        local oldCount=#chr.inv.items;local oldTorch=chr.torch.delta;local oldRods=chr.rods.delta
        eq(menu(chr,p).notAvailable,true);eq(R.installFixed(chr,p),false)
        eq(#chr.inv.items,oldCount);near(chr.torch.delta,oldTorch);near(chr.rods.delta,oldRods);eq(p.installed,nil)
    end)
end
test("completion rechecks changed inventory",function()
    local p=part("Base.SUV",R.fixedId);local spec=R.fabricationSpec(p);local chr=character(spec)
    assert(R.InstallTest(p.vehicle,p,chr));chr.inv:DoRemoveItem(chr.inv.items[1])
    eq(R.installFixed(chr,p),false);eq(p.installed,nil);near(chr.torch.delta,1)
end)
for _,condition in ipairs({"mask","wrench","welding","mechanics"}) do
    test("existing requirement "..condition.." preserved",function()
        local p=part("Base.SUV",R.fixedId);local spec=R.fabricationSpec(p);local chr=character(spec)
        if condition=="mask" or condition=="wrench" then chr.inv:DoRemoveItem(chr[condition]) else chr[condition]=0 end
        eq(R.installFixed(chr,p),false);eq(p.installed,nil)
    end)
end
test("source recipe tables never shrink or leak between cars",function()
    for i=1,20 do
        local s=R.fabricationSpec(part("Base.SUV",R.fixedId));s.materials["Base.MetalBar"]=0;s.salvage[1][2]=0
        local l=R.fabricationSpec(part("Base.StepVan",R.fixedId));eq(l.materials["Base.MetalBar"],10);eq(l.salvage[1][2],10)
    end
    eq(R.materials["Base.MetalBar"],10);eq(R.uses["Base.BlowTorch"],10)
    eq(R.fabricatedParts.VLSBumperFront.materials["Base.MetalBar"],6)
end)
test("construction costs independent of capacity and condition",function()
    local old=R.rackCapacities["Base.SUV"];R.rackCapacities["Base.SUV"]=999
    local p=part("Base.SUV",R.fixedId);p.installed=item(R.fixedType);p.installed.condition=0
    local amount=R.fabricationSpec(p).materials["Base.MetalBar"];R.rackCapacities["Base.SUV"]=old;eq(amount,5)
end)
test("client and server select identical recipe",function()
    local p=part("Base.Van",R.fixedId);client=true;local c=R.fabricationSpec(p);client=false;local s=R.fabricationSpec(p)
    for _,group in ipairs({"materials","uses"}) do for k,v in pairs(c[group]) do eq(v,s[group][k]) end end
end)
test("unknown similarly named vehicle not granted small-vehicle discount",function()
    eq(R.fabricationScale(part("Base.VanUnregistered",R.fixedId).vehicle),1)
    eq(R.fabricationScale(part("Other.SUV",R.fixedId).vehicle),1)
    eq(R.fabricationScale(nil),1)
end)
test("unrelated registered fabrication untouched",function()
    local custom={accepts=function() return true end,itemType="Other.Part",materials={},uses={},salvage={}}
    R.fabricatedParts.OtherPart=custom;eq(R.fabricationSpec(part("Base.SUV","OtherPart")),custom);R.fabricatedParts.OtherPart=nil
    eq(R.fabricationSpec(part("Base.SUV","Battery")),nil)
end)
for _,health in ipairs({0,100}) do
    test("dismantling allowed at condition "..health.." but blocked by cargo",function()
        local p=part("Base.SUV",R.fixedId);p.installed=item(R.fixedType);p.installed.condition=health
        local chr=character(R.fabricationSpec(p));assert(R.canDismantle(chr,p,true))
        p.storage:AddItem(item("Base.Nails"));eq(R.canDismantle(chr,p,true),false)
    end)
end
test("rack cargo attachment blocks dismantling",function()
    local p=part("Base.SUV",R.fixedId);p.installed=item(R.fixedType);local chr=character(R.fabricationSpec(p))
    local cargo=part("Base.SUV","VLSRoofGenerator");cargo.installed=item("Base.Generator");p.vehicle.parts[cargo.id]=cargo
    eq(R.canDismantle(chr,p,true),false)
end)
print(string.format("RESULT tests=%d passed=%d failures=%d adapter_variants=%d",passed+failed,passed,failed,variants))
if failed>0 then os.exit(1) end
