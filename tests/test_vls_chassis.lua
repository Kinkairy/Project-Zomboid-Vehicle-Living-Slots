-- lua5.1 ../../tests/vehicle-living-slots/test_vls_material_tiers.lua [repo root]
-- Actual VLS Lua, mocked PZ objects. Not a Java engine or multiplayer playtest.
local root=arg[1] or "."
package.path=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/?.lua;"..package.path
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
local ticks={}
Events={OnTick={Add=function(fn) ticks[#ticks+1]=fn end}}
Vehicles={InstallComplete={Default=noop}}
local nextId=0
local function item(ft,drainable,tag)
    nextId=nextId+1
    local o={ft=ft,id=nextId,drainable=drainable,delta=1,condition=100,tag=tag}
    function o:getFullType() return self.ft end
    function o:getWeight() return self.weight or (self.ft=="Base.VLSImprovedChassis" and 10 or 1) end
    function o:getActualWeight() return self:getWeight() end
    function o:setWeight(v) self.weight=v end
    function o:setActualWeight(v) self.actualWeight=v end
    function o:setCustomWeight(v) self.customWeight=v end
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
    function p:getArea() return "Engine" end
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

local C=VLS.Chassis
local function setup(name,base,cargo)
    local p=part(name or "Base.StepVan",C.ID)
    local v=p.vehicle
    local stock=name and (name:find("^Base.VanSeats") and 916 or name:find("^Base.Van") and 816 or name:find("^Base.SUV") and 1000 or name:find("^Base.PickUpVan") and 1104)
    v.scriptMass=base or stock or 1160;v.initial=v.scriptMass;v.cargo=cargo or 1440
    v.controller={};v.localPhysics=true;v.engine=false;v.removed=false;v.stopped=true
    function v:getScript() return {getFullName=function() return self.name end,getMass=function() return self.scriptMass end} end
    function v:getInitialMass() return self.initial end
    function v:setInitialMass(n) self.initial=n;self.massWrites=(self.massWrites or 0)+1 end
    function v:getMass() return self.mass end
    function v:getController() return self.controller end
    function v:isLocalPhysicSim() return self.localPhysics end
    function v:isEngineRunning() return self.engine end
    function v:isRemovedFromWorld() return self.removed end
    function v:isStopped() return self.stopped end
    function v:transmitPartModData(part) self.lastData=part:getModData()[C.KEY];self.transmits=(self.transmits or 0)+1 end
    function v:updateTotalMass()
        if self.throwMass then self.throwMass=false;error("native mass failure") end
        self.mass=self.initial+self.cargo+(p.installed and p.installed:getWeight() or 0)
        self.recalculations=(self.recalculations or 0)+1
    end
    function p:getItemContainer() return nil end -- chassis is not storage
    p.md={}
    function p:getModData() return self.md end
    function p:setInventoryItem(it) self.installed=it;v:updateTotalMass() end
    v:updateTotalMass()
    local spec=R.fabricationSpec(p)
    local chr=character(spec or R.rackRecipe);chr.mechanics=5
    chr.jack=item("Base.Jack");chr.inv:AddItem(chr.jack)
    C.init(v,p)
    return p,v,chr
end
local function install(p,c)
    local a=setmetatable({character=c,part=p,vehicle=p.vehicle,item=c.inv.items[1]}, {__index=VLSRoofInstallAction})
    return a:complete()
end
local function dismantle(p,c)
    local a=setmetatable({character=c,part=p,vehicle=p.vehicle,expectedItemId=p.installed.id,
        checkAddItem=function() return false end},{__index=VLSRoofDismantleAction})
    return a:complete()
end
local function copy(t) local v={};for k,x in pairs(t) do v[k]=x end;return v end
local count=0
for name in pairs(R.vehicleScripts) do
    count=count+1
    test("install exact net discount; remove restores original: "..name,function()
        local p,v,c=setup(name)
        local want=name:find("^Base.StepVan") and 500 or (name:find("^Base.Van") and 300 or 200)
        local base,mass=v.initial,v.mass
        local stored=item("Base.Nails");p.storage:AddItem(stored)
        local inventoryRef=p.storage
        assert(install(p,c));eq(p.installed.ft,C.TYPE)
        eq(v.mass,mass-want);eq(v.initial,base-want-C.ITEM_WEIGHT)
        eq(p.storage,inventoryRef);eq(p.storage.items[1],stored)
        -- This slot itself has no runtime container. Existing containers do not block install.
        p.storage:DoRemoveItem(stored)
        assert(dismantle(p,c));eq(v.initial,base);eq(v.mass,mass);eq(p.installed,nil)
    end)
end
test("all supported variants checked",function() eq(count,106) end)
test("recipe sizes and Engine group match 106 native entries",function()
    local script=read(media.."scripts/VLS_ZChassisVehicles.txt")
    local n=0;for name in script:gmatch("vehicle%s+([%w_]+)%s*{%s*template%s*=%s*VLSChassisUpgrade") do n=n+1;assert(R.vehicleScripts["Base."..name]) end
    eq(n,106);assert(script:find("category = engine,",1,true));assert(script:find("area = Engine,",1,true))
    assert(not script:find("mass =",1,true));assert(not script:find("wheel ",1,true))
    local specs={{"Base.StepVan",12,6,8,20,6},{"Base.Van",9,5,6,15,5},{"Base.SUV",6,3,4,10,3}}
    for _,x in ipairs(specs) do
        local p=setup(x[1]);local s=R.fabricationSpec(p)
        eq(s.materials["Base.MetalBar"],x[2]);eq(s.materials["Base.SmallSheetMetal"],x[3]);eq(s.materials["Base.Screws"],x[4])
        eq(s.uses["Base.BlowTorch"],x[5]);eq(s.uses["Base.WeldingRods"],x[6])
    end
end)
test("missing slot or unsupported model has no discount",function()
    local p,v,c=setup("Base.NotSupported");eq(C.isPart(p),false);eq(C.preview(p),nil);eq(C.sync(v,p),false)
    p,v,c=setup();v.parts[C.ID]=nil;eq(C.isPart(p),false);eq(install(p,c),false)
end)
test("another unmodified car of same model stays untouched",function()
    local p,v,c=setup();local p2,v2,c2=setup();assert(install(p,c));eq(v2.mass,2600);eq(v2.initial,1160)
end)
test("real inventory weight is not capped/discounted",function()
    local p,v,c=setup();assert(install(p,c));eq(v.mass,2100)
    v.cargo=v.cargo+100;v:updateTotalMass();eq(v.mass,2200)
    v.cargo=v.cargo+1500;v:updateTotalMass();eq(v.mass,3700)
end)
test("floor limits actual discount, preview reports actual net",function()
    local p,v,c=setup("Base.StepVan",700,1000);eq(C.preview(p).net,200);assert(install(p,c));eq(v.initial,500);eq(v.mass,1500)
end)
test("too light for a net improvement consumes nothing",function()
    local p,v,c=setup("Base.StepVan",500,1000);eq(C.preview(p),nil);eq(install(p,c),false);eq(v.initial,500)
end)
for _,why in ipairs({"jack","brokenjack","mechanics","welding","engine","moving","removed","position","dead","inside"}) do
 test("install requirement revalidated without debit: "..why,function()
    local p,v,c=setup();local before=#c.inv.items
    if why=="jack" then c.inv:DoRemoveItem(c.jack);before=before-1
    elseif why=="brokenjack" then c.jack.condition=0
    elseif why=="mechanics" then c.mechanics=4
    elseif why=="welding" then c.welding=4
    elseif why=="engine" then v.engine=true
    elseif why=="moving" then v.stopped=false
    elseif why=="removed" then v.removed=true
    elseif why=="position" then v.isInArea=function() return false end
    elseif why=="dead" then c.isDead=function() return true end
    elseif why=="inside" then c.getVehicle=function() return v end end
    eq(install(p,c),false);eq(#c.inv.items,before);eq(p.installed,nil);eq(p.md[C.KEY],nil);eq(v.mass,2600)
 end)
end
for _,ft in ipairs({"Base.MetalBar","Base.SmallSheetMetal","Base.Screws","Base.BlowTorch","Base.WeldingRods"}) do
 test("shortage rejects exact input: "..ft,function()
    local p,v,c=setup()
    for _,it in ipairs(c.inv.items) do if it.ft==ft then c.inv:DoRemoveItem(it);break end end
    local before=#c.inv.items;eq(install(p,c),false);eq(#c.inv.items,before);eq(v.mass,2600)
 end)
end
test("one action cannot debit twice",function()
    local p,v,c=setup();assert(install(p,c));local n=#c.inv.items;eq(install(p,c),false);eq(#c.inv.items,n);eq(v.mass,2100)
end)
test("two players cannot upgrade twice",function()
    local p,v,c=setup();local spec=R.fabricationSpec(p);local c2=character(spec);c2.mechanics=5;c2.inv:AddItem(item("Base.Jack"))
    assert(install(p,c));local n=#c2.inv.items;eq(install(p,c2),false);eq(#c2.inv.items,n)
end)
test("menu includes jack, engine state, net discount, accurate projected weight",function()
    local p,v,c=setup();local op=menu(c,p);eq(op.notAvailable,false)
    assert(op.toolTip.description:find("Base.Jack 1/1",1,true));assert(op.toolTip.description:find("/5",1,true))
    c.inv:DoRemoveItem(c.jack);eq(menu(c,p).notAvailable,true)
end)
test("repeated init and tick cannot compound discount",function()
    local p,v,c=setup();assert(install(p,c));local recalc=v.recalculations
    for i=1,120 do C.init(v,p);C.update(v,p);for _,fn in ipairs(ticks) do fn() end end
    eq(v.mass,2100);eq(v.initial,660);eq(v.recalculations,recalc)
end)
test("streamed chassis part with nil vehicle owner is retired safely",function()
    local p,v,c=setup();assert(install(p,c));p.vehicle=nil
    eq(C.isPart(p),false)
    for i=1,30 do
        for _,fn in ipairs(ticks) do
            local ok,err=pcall(fn);assert(ok,err)
        end
    end
end)
test("spawn/load resets initial mass AFTER init; next tick repairs it",function()
    local p,v,c=setup();assert(install(p,c));C.init(v,p)
    v.initial=1160;v:updateTotalMass();eq(v.mass,2600)
    for i=1,30 do for _,fn in ipairs(ticks) do fn() end end
    eq(v.initial,660);eq(v.mass,2100)
end)
test("rejoin uses persisted baseline rather than subtracting again",function()
    local p,v,c=setup();assert(install(p,c))
    local new,nv,nc=setup();new.installed=p.installed;new.md[C.KEY]={legacy=true};nv:updateTotalMass()
    C.init(nv,new);eq(nv.mass,2100);eq(nv.initial,660)
end)
test("physics owner/controller change refreshes native mass",function()
    local p,v,c=setup();assert(install(p,c));local n=v.recalculations
    v.localPhysics=false;C.sync(v,p);eq(v.recalculations,n+1)
    v.localPhysics=true;C.sync(v,p);eq(v.recalculations,n+2)
    v.controller={};C.sync(v,p);eq(v.recalculations,n+3)
end)
local function captureWarnings(fn)
    local original=print;local lines={}
    print=function(message) lines[#lines+1]=message end
    local ok,err=pcall(fn);print=original;assert(ok,err)
    return lines
end
test("foreign mass on an unmodified car is silent and preserved",function()
    local p,v=setup("Base.StepVanMail");v.initial=777
    local lines=captureWarnings(function() for i=1,120 do C.sync(v,p) end end)
    eq(#lines,0);eq(v.initial,777)
end)
test("installed conflict reports once per model even across streaming reload",function()
    local p,v,c=setup("Base.StepVanMail");assert(install(p,c));v.initial=777
    local p2,v2,c2=setup("Base.StepVanMail");assert(install(p2,c2));v2.initial=778
    local lines=captureWarnings(function()
        for i=1,120 do C.sync(v,p);C.init(v2,p2) end
    end)
    eq(#lines,1);assert(lines[1]:find("Base.StepVanMail",1,true))
    assert(lines[1]:find("777",1,true));eq(v.initial,777);eq(v2.initial,778)
end)
test("foreign mass change not fought by background updater",function()
    local p,v,c=setup();assert(install(p,c));v.initial=777;v:updateTotalMass();local n=v.massWrites
    for i=1,5 do eq(C.sync(v,p),false) end;eq(v.initial,777);eq(v.massWrites,n);eq(C.preview(p),nil)
end)
test("changed script baseline derives proportional mass",function()
    local p,v,c=setup();assert(install(p,c));v.scriptMass=1200;v.initial=1200
    eq(C.sync(v,p),true);eq(v.initial,683)
end)
test("installed item derives reduction without legacy metadata",function()
    local p,v,c=setup();p:setInventoryItem(item(C.TYPE));eq(C.sync(v,p),true);eq(v.initial,660)
end)
test("replacement item identity recalculates without compounding",function()
    local p,v,c=setup();assert(install(p,c));p:setInventoryItem(item(C.TYPE));C.sync(v,p);eq(v.initial,660);eq(v.mass,2100)
end)
test("debug removal restores original mass",function()
    local p,v,c=setup();assert(install(p,c));p:setInventoryItem(nil);C.sync(v,p);eq(v.initial,1160);eq(v.mass,2600)
end)
test("reinstall after dismantling cannot compound",function()
    local p,v,c=setup();assert(install(p,c));assert(dismantle(p,c));local baseline=v.scriptMass
    local c2=character(R.fabricationSpec(p));c2.mechanics=5;c2.inv:AddItem(item("Base.Jack"))
    assert(install(p,c2));eq(v.scriptMass,baseline);eq(v.mass,2100)
end)
test("client uses replicated part state, never deducts materials",function()
    local p,v,c=setup();assert(install(p,c));local state={legacy=true};local installed=p.installed
    local p2,v2,c2=setup();client=true;p2.installed=installed;p2.md[C.KEY]=state;v2:updateTotalMass()
    C.init(v2,p2);eq(v2.mass,2100);eq(install(p2,c2),false);eq(v2.transmits,nil);client=false
end)
test("moddata-before-item packet ordering does not give free discount",function()
    local p,v,c=setup();assert(install(p,c));local p2,v2,c2=setup();client=true
    p2.md[C.KEY]={legacy=true};C.sync(v2,p2);eq(v2.mass,2600)
    p2:setInventoryItem(p.installed);C.sync(v2,p2);eq(v2.mass,2100);client=false
end)
test("item-before-moddata activates derived mass immediately",function()
    local p,v,c=setup();assert(install(p,c));local p2,v2,c2=setup();client=true
    p2:setInventoryItem(p.installed);C.sync(v2,p2);eq(v2.mass,2100)
    p2.md[C.KEY]={legacy=true};C.sync(v2,p2);eq(v2.mass,2100);client=false
end)
test("rollback refunds inputs and restores metadata/mass on application error",function()
    local p,v,c=setup();local count=#c.inv.items
    local original=v.setInitialMass
    function v:setInitialMass(n) original(self,n);if n==660 then self.throwMass=true end end
    eq(install(p,c),false);eq(p.installed,nil);eq(p.md[C.KEY],nil);eq(v.initial,1160);eq(v.mass,2600)
    eq(#c.inv.items,count);near(c.torch.delta,1);near(c.rods.delta,1)
end)
test("unrelated original material recipes retain skill 1",function()
    local p=part("Base.StepVan",R.fixedId);local spec=R.fabricationSpec(p);local c=character(spec);eq(c.mechanics,1);assert(R.plan(c,spec))
end)
print(string.format("RESULT chassis tests=%d passed=%d failures=%d (mocked engine; no live deployment)",passed+failed,passed,failed))
if failed>0 then os.exit(1) end

if failed>0 then os.exit(1) end
