-- Living/top space policy on the real VLS_Config with mocked engine objects.
-- Owner rule 2026-10-17: a furniture family installs only in the space its
-- vanilla size allows; equipment already installed stays usable where it is.
local root=assert(arg[1])
local media=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(media.."shared/VLS_Config.lua")
package.loaded.VLS_Config=V
local S=assert(V.NativeSpace)
local Catalog=dofile(media.."shared/VLS_SpaceCatalog.lua")
function instanceof(item,kind)return item and item.kind==kind end
local n=0
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
local function eq(a,b,msg)assert(a==b,(msg or "")..": "..tostring(a).." != "..tostring(b))end

local function vehicle(scriptName,frames)
    local v={parts={}}
    function v:getScriptName()return scriptName end
    function v:getPartById(id)return self.parts[id]end
    local function part(id,item)
        local p={item=item,data={}}
        function p:getId()return id end
        function p:getVehicle()return v end
        function p:getInventoryItem()return self.item end
        function p:getModData()return self.data end
        v.parts[id]=p
        return p
    end
    for i=1,frames or 0 do
        part(V.TOP_FRAME_PART_IDS[i],{kind="Normal",getFullType=function()return V.TOP_FRAME_ITEM_TYPE end,
            getCondition=function()return 100 end})
    end
    return v,part
end
local function item(fullType,sprite)
    return {kind="Moveable",getFullType=function()return fullType end,
        getScriptItem=function()return nil end,getWorldSprite=function()return sprite end}
end

test("catalog spaces follow the owner examples",function()
    eq(S.ofType("Base.Mov_Microwave"),"top","microwave")
    eq(S.ofType("Base.Mov_Microwave2"),"top","chrome microwave")
    eq(S.ofType("Base.Mov_FridgeMini"),"top","mini fridge")
    eq(S.ofType("Base.Mov_TrailerFridge"),"top","trailer fridge")
    eq(S.ofType("Base.Mov_BlueComboWasherDryer"),"living","combo")
    eq(S.ofType("Base.Mov_ModernCounter"),"living","counter")
    eq(S.ofType("Base.TvAntique"),"living","floor TV")
    eq(S.ofType("Base.TvWideScreen"),"top","tabletop TV")
    eq(S.ofType("Base.Mov_Cot"),nil,"beds keep their slots")
    eq(S.ofType("Base.WaterDispenserBottle"),nil,"plain items keep their slots")
end)

test("generated furniture families register vanilla-backed storage profiles",function()
    local living,top=0,0
    for fullType,entry in pairs(Catalog.furniture)do
        local profile=assert(V.equipmentProfiles[fullType],fullType)
        if profile.native then
            eq(profile.capability,"storage",fullType)
            eq(profile.overhead==true,entry.space=="top",fullType.." overhead flag")
            eq(V.usesNativeContainer(profile),true,fullType)
        end
        for _,sprite in ipairs(entry.sprites)do
            assert(V.supportedMoveableSprites[sprite],sprite)
        end
        if entry.space=="living" then living=living+1 else top=top+1 end
    end
    assert(living>0 and top>0)
end)

test("living slots reject top-space equipment and keep living equipment",function()
    local v,part=vehicle("Base.StepVan")
    local slot=part(V.UNIVERSAL_PART_ID)
    eq(S.ofPart(slot),"living")
    for _,t in ipairs({"Base.Mov_Microwave","Base.Mov_FridgeMini","Base.Mov_TrailerFridge","Base.Mov_SmallPineCabinet","Base.TvWideScreen"})do
        eq(V.isInstallationEnabled(slot,t),false,"living rejects "..t)
    end
    for _,t in ipairs({"Base.Mov_Cot","Base.Mov_BlueComboWasherDryer","Base.Mov_ModernCounter","Base.TvAntique","Base.WaterDispenserBottle"})do
        eq(V.isInstallationEnabled(slot,t),true,"living accepts "..t)
    end
    for fullType,entry in pairs(Catalog.furniture)do
        eq(V.isInstallationEnabled(slot,fullType),entry.space=="living",fullType)
    end
end)

test("top slots accept top-space equipment once the frame is installed",function()
    local v,part=vehicle("Base.StepVan",1)
    local slot=part(V.OVERHEAD_PART_IDS[1])
    eq(S.ofPart(slot),"top")
    for _,t in ipairs({"Base.Mov_Microwave","Base.Mov_FridgeMini","Base.Mov_TrailerFridge","Base.TvWideScreen"})do
        eq(V.isInstallationEnabled(slot,t),true,"top accepts "..t)
        eq(V.allowedItems[slot:getId()][t],true,"top recognises "..t)
    end
    for _,t in ipairs({"Base.Mov_BlueComboWasherDryer","Base.Mov_ModernCounter","Base.TvAntique"})do
        eq(V.isInstallationEnabled(slot,t),false,"top rejects "..t)
    end
    v.parts[V.TOP_FRAME_PART_IDS[1]]=nil
    eq(V.isInstallationEnabled(slot,"Base.Mov_Microwave"),false,"no frame, no top install")
end)

test("a microwave already in a living slot stays recognised and usable",function()
    local v,part=vehicle("Base.StepVan")
    local slot=part(V.UNIVERSAL_PART_ID,item("Base.Mov_Microwave","appliances_cooking_01_24"))
    eq(V.isAllowedItem(slot,slot:getInventoryItem()),true,"recognised")
    eq(V.getInstalledPart(v,V.UNIVERSAL_PART_ID),slot,"installed lookup")
    eq(V.getEquipmentCapability(slot:getInventoryItem()),"cooking","capability")
    eq(V.getInstalledCapabilityPart(v,"cooking"),slot,"appliance lookup")
    eq(V.isInstallationEnabled(slot,"Base.Mov_Microwave"),false,"cannot be reinstalled there")
end)

test("equipment slots include top slots and each top slot has a companion",function()
    local v=vehicle("Base.StepVan")
    local ids=S.equipmentPartIds(v)
    local profile=V.getVehicleProfile(v)
    eq(#ids,#profile.universalParts+#profile.overheadParts,"living + top")
    for _,id in ipairs(profile.overheadParts)do
        local companion=assert(V.FREEZER_PART_BY_UNIVERSAL[id],id)
        eq(V.UNIVERSAL_PART_BY_FREEZER[companion],id,"reverse map")
    end
end)

test("install menu keeps only what the player can install in that space",function()
    getText=function(key)return key end
    local function menu()
        local m={options={},numOptions=1,optionPool={},height=0}
        function m:addOption(name)local o={name=name,id=self.numOptions};self.options[self.numOptions]=o;self.numOptions=self.numOptions+1;return o end
        function m:calcHeight()self.height=#self.options end
        return m
    end
    local root=menu();local install=menu()
    root.getOptionFromName=function(self,name)for _,o in ipairs(self.options)do if o.name==name then return o end end end
    root.getSubMenu=function()return install end
    local opt=root:addOption("IGUI_Install");opt.subOption=1
    local held=install:addOption("held");held.subOption=2
    install:addOption("missing").notAvailable=true
    install:addOption("missing too").notAvailable=true
    local disabled=install:addOption("held but disabled");disabled.subOption=3;disabled.notAvailable=true
    local v,part=vehicle("Base.StepVan")
    local slot=part(V.UNIVERSAL_PART_ID)
    -- Exercise the exact client filter on the real Config objects.
    local f=assert(io.open(media.."client/VLS_VehicleMechanicsIcons.lua"));local src=f:read("*a");f:close()
    local a=assert(src:find("local function keepInstallable",1,true))
    local b=assert(src:find("local function normalizeMenu",a,true))
    local keep=assert(loadstring(src:sub(a,b-1).."\nreturn keepInstallable"))()
    keep({context=root},slot)
    eq(#install.options,2,"two remain");eq(install.numOptions,3,"numOptions")
    eq(install.options[1],held);eq(install.options[2],disabled);eq(held.id,1);eq(disabled.id,2)
    eq(#install.optionPool,2,"removed options pooled");eq(install.height,2,"height recalculated")
    -- Nothing installable: one disabled hint.
    install.options={};install.numOptions=1;install:addOption("missing").notAvailable=true
    keep({context=root},slot)
    eq(#install.options,1);eq(install.options[1].name,"IGUI_VLS_NoInstallableItem");eq(install.options[1].notAvailable,true)
end)

print("RESULT native space tests="..n.." failures=0")
