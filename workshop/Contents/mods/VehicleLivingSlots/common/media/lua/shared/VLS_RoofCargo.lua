require "VLS_Config"
-- Isolated roof parts. No world scan, global item override, or client command.
VLSRoofCargo = VLSRoofCargo or {}
local R = VLSRoofCargo
R.fixedId = "VLSFixedRoofRack"
R.fixedType = "Base.VLSFixedRoofRack"
-- Registered permanent fittings share the rack's material transaction and actions.
R.fabricatedParts = R.fabricatedParts or {}
-- Material tiers apply only to the exact supported scripts below. They do not
-- read cargo capacity, translated vehicle names or installed item condition.
-- Paint/job variants in one body family use the same construction cost.
function R.fabricationScale(vehicle)
    local script=vehicle and vehicle:getScript()
    local name=script and script:getFullName()
    if not name or not R.vehicleScripts[name] then return 1 end
    if name=="Base.SUV" or name:find("^Base%.PickUpVan") then return 0.5 end
    if name:find("^Base%.Van") then return 0.75 end
    return 1 -- StepVan and unclassified future scripts keep the full recipe.
end
local function sizedRecipe(spec,scale)
    -- Never mutate shared recipe tables: opening an SUV menu must not reduce
    -- the recipe subsequently used by a StepVan or another player's action.
    local result={}
    for key,value in pairs(spec) do result[key]=value end
    result.materials={}
    result.uses={}
    result.salvage={}
    for fullType,count in pairs(spec.materials) do
        result.materials[fullType]=math.ceil(count*scale)
    end
    for fullType,count in pairs(spec.uses) do
        result.uses[fullType]=math.ceil(count*scale)
    end
    -- Keep the existing salvage success parameters; cap each material by its
    -- scaled construction input. Consumables and the tarp remain unrecoverable.
    for index,entry in ipairs(spec.salvage) do
        result.salvage[index]={entry[1],math.min(math.ceil(entry[2]*scale),
            result.materials["Base."..entry[1]] or 0),entry[3]}
    end
    return result
end
function R.fabricationSpec(part)
    if not part then return nil end
    local spec
    if part:getId()==R.fixedId then
        spec=R.rackRecipe
    else
        spec=R.fabricatedParts[part:getId()]
        if not spec or not spec.accepts(part) then return nil end
    end
    if spec and spec.scaleWithVehicle then
        return sizedRecipe(spec,R.fabricationScale(part:getVehicle()))
    end
    return spec
end
R.vehicleScripts = {["Base.StepVan"]=true, ["Base.StepVanAirportCatering"]=true, ["Base.StepVanMail"]=true, ["Base.StepVan_Blacksmith"]=true, ["Base.StepVan_Butchers"]=true, ["Base.StepVan_Cereal"]=true, ["Base.StepVan_Citr8"]=true, ["Base.StepVan_CompleteRepairShop"]=true, ["Base.StepVan_Florist"]=true, ["Base.StepVan_Genuine_Beer"]=true, ["Base.StepVan_Glass"]=true, ["Base.StepVan_Heralds"]=true, ["Base.StepVan_HuangsLaundry"]=true, ["Base.StepVan_Jorgensen"]=true, ["Base.StepVan_LouisvilleMotorShop"]=true, ["Base.StepVan_LouisvilleSWAT"]=true, ["Base.StepVan_MarineBites"]=true, ["Base.StepVan_Masonry"]=true, ["Base.StepVan_Mechanic"]=true, ["Base.StepVan_MobileLibrary"]=true, ["Base.StepVan_Plonkies"]=true, ["Base.StepVan_Propane"]=true, ["Base.StepVan_RandisPlants"]=true, ["Base.StepVan_Scarlet"]=true, ["Base.StepVan_SmartKut"]=true, ["Base.StepVan_SouthEasternHosp"]=true, ["Base.StepVan_SouthEasternPaint"]=true, ["Base.StepVan_USL"]=true, ["Base.StepVan_Zippee"]=true, ["Base.Van"]=true, ["Base.VanBeckmans"]=true, ["Base.VanBrewsterHarbin"]=true, ["Base.VanBuilder"]=true, ["Base.VanCarpenter"]=true, ["Base.VanCoastToCoast"]=true, ["Base.VanDeerValley"]=true, ["Base.VanFossoil"]=true, ["Base.VanGardenGods"]=true, ["Base.VanGardener"]=true, ["Base.VanGreenes"]=true, ["Base.VanJohnMcCoy"]=true, ["Base.VanJonesFabrication"]=true, ["Base.VanKerrHomes"]=true, ["Base.VanKnobCreekGas"]=true, ["Base.VanKnoxCom"]=true, ["Base.VanKorshunovs"]=true, ["Base.VanLouisvilleLandscaping"]=true, ["Base.VanMail"]=true, ["Base.VanMccoy"]=true, ["Base.VanMechanic"]=true, ["Base.VanMeltingPointMetal"]=true, ["Base.VanMetalheads"]=true, ["Base.VanMetalworker"]=true, ["Base.VanMicheles"]=true, ["Base.VanMobileMechanics"]=true, ["Base.VanMooreMechanics"]=true, ["Base.VanOldMill"]=true, ["Base.VanOvoFarm"]=true, ["Base.VanPennSHam"]=true, ["Base.VanPlattAuto"]=true, ["Base.VanPluggedInElectrics"]=true, ["Base.VanRiversideFabrication"]=true, ["Base.VanRosewoodworking"]=true, ["Base.VanSchwabSheetMetal"]=true, ["Base.VanSeats"]=true, ["Base.VanSeatsAirportShuttle"]=true, ["Base.VanSeats_Creature"]=true, ["Base.VanSeats_LadyDelighter"]=true, ["Base.VanSeats_Mural"]=true, ["Base.VanSeats_Prison"]=true, ["Base.VanSeats_Space"]=true, ["Base.VanSeats_Trippy"]=true, ["Base.VanSeats_Valkyrie"]=true, ["Base.VanSpiffo"]=true, ["Base.VanTreyBaines"]=true, ["Base.VanUncloggers"]=true, ["Base.VanUtility"]=true, ["Base.VanWPCarpentry"]=true, ["Base.Van_Blacksmith"]=true, ["Base.Van_BugWipers"]=true, ["Base.Van_Charlemange_Beer"]=true, ["Base.Van_CraftSupplies"]=true, ["Base.Van_Glass"]=true, ["Base.Van_HeritageTailors"]=true, ["Base.Van_KnoxDisti"]=true, ["Base.Van_Leather"]=true, ["Base.Van_LectroMax"]=true, ["Base.Van_Locksmith"]=true, ["Base.Van_Masonry"]=true, ["Base.Van_MassGenFac"]=true, ["Base.Van_Perfick_Potato"]=true, ["Base.Van_Transit"]=true, ["Base.Van_VoltMojo"]=true, ["Base.SUV"]=true, ["Base.PickUpVan"]=true, ["Base.PickUpVanBrickingIt"]=true, ["Base.PickUpVanBuilder"]=true, ["Base.PickUpVanCallowayLandscaping"]=true, ["Base.PickUpVanHeltonMetalWorking"]=true, ["Base.PickUpVanKimbleKonstruction"]=true, ["Base.PickUpVanMarchRidgeConstruction"]=true, ["Base.PickUpVanMccoy"]=true, ["Base.PickUpVanMetalworker"]=true, ["Base.PickUpVanWeldingbyCamille"]=true, ["Base.PickUpVanYingsWood"]=true, ["Base.PickUpVan_Camo"]=true}
R.rackCapacities = {["Base.StepVan"]=400, ["Base.StepVanAirportCatering"]=400, ["Base.StepVanMail"]=400, ["Base.StepVan_Blacksmith"]=400, ["Base.StepVan_Butchers"]=400, ["Base.StepVan_Cereal"]=400, ["Base.StepVan_Citr8"]=400, ["Base.StepVan_CompleteRepairShop"]=400, ["Base.StepVan_Florist"]=400, ["Base.StepVan_Genuine_Beer"]=400, ["Base.StepVan_Glass"]=400, ["Base.StepVan_Heralds"]=400, ["Base.StepVan_HuangsLaundry"]=400, ["Base.StepVan_Jorgensen"]=400, ["Base.StepVan_LouisvilleMotorShop"]=400, ["Base.StepVan_LouisvilleSWAT"]=400, ["Base.StepVan_MarineBites"]=400, ["Base.StepVan_Masonry"]=400, ["Base.StepVan_Mechanic"]=400, ["Base.StepVan_MobileLibrary"]=400, ["Base.StepVan_Plonkies"]=400, ["Base.StepVan_Propane"]=400, ["Base.StepVan_RandisPlants"]=400, ["Base.StepVan_Scarlet"]=400, ["Base.StepVan_SmartKut"]=400, ["Base.StepVan_SouthEasternHosp"]=400, ["Base.StepVan_SouthEasternPaint"]=400, ["Base.StepVan_USL"]=400, ["Base.StepVan_Zippee"]=400, ["Base.Van"]=300, ["Base.VanBeckmans"]=300, ["Base.VanBrewsterHarbin"]=300, ["Base.VanBuilder"]=300, ["Base.VanCarpenter"]=300, ["Base.VanCoastToCoast"]=300, ["Base.VanDeerValley"]=300, ["Base.VanFossoil"]=300, ["Base.VanGardenGods"]=300, ["Base.VanGardener"]=300, ["Base.VanGreenes"]=300, ["Base.VanJohnMcCoy"]=300, ["Base.VanJonesFabrication"]=300, ["Base.VanKerrHomes"]=300, ["Base.VanKnobCreekGas"]=300, ["Base.VanKnoxCom"]=300, ["Base.VanKorshunovs"]=300, ["Base.VanLouisvilleLandscaping"]=300, ["Base.VanMail"]=300, ["Base.VanMccoy"]=300, ["Base.VanMechanic"]=300, ["Base.VanMeltingPointMetal"]=300, ["Base.VanMetalheads"]=300, ["Base.VanMetalworker"]=300, ["Base.VanMicheles"]=300, ["Base.VanMobileMechanics"]=300, ["Base.VanMooreMechanics"]=300, ["Base.VanOldMill"]=300, ["Base.VanOvoFarm"]=300, ["Base.VanPennSHam"]=300, ["Base.VanPlattAuto"]=300, ["Base.VanPluggedInElectrics"]=300, ["Base.VanRiversideFabrication"]=300, ["Base.VanRosewoodworking"]=300, ["Base.VanSchwabSheetMetal"]=300, ["Base.VanSeats"]=300, ["Base.VanSeatsAirportShuttle"]=300, ["Base.VanSeats_Creature"]=300, ["Base.VanSeats_LadyDelighter"]=300, ["Base.VanSeats_Mural"]=300, ["Base.VanSeats_Prison"]=300, ["Base.VanSeats_Space"]=300, ["Base.VanSeats_Trippy"]=300, ["Base.VanSeats_Valkyrie"]=300, ["Base.VanSpiffo"]=300, ["Base.VanTreyBaines"]=300, ["Base.VanUncloggers"]=300, ["Base.VanUtility"]=300, ["Base.VanWPCarpentry"]=300, ["Base.Van_Blacksmith"]=300, ["Base.Van_BugWipers"]=300, ["Base.Van_Charlemange_Beer"]=300, ["Base.Van_CraftSupplies"]=300, ["Base.Van_Glass"]=300, ["Base.Van_HeritageTailors"]=300, ["Base.Van_KnoxDisti"]=300, ["Base.Van_Leather"]=300, ["Base.Van_LectroMax"]=300, ["Base.Van_Locksmith"]=300, ["Base.Van_Masonry"]=300, ["Base.Van_MassGenFac"]=300, ["Base.Van_Perfick_Potato"]=300, ["Base.Van_Transit"]=300, ["Base.Van_VoltMojo"]=300, ["Base.SUV"]=250, ["Base.PickUpVan"]=250, ["Base.PickUpVanBrickingIt"]=250, ["Base.PickUpVanBuilder"]=250, ["Base.PickUpVanCallowayLandscaping"]=250, ["Base.PickUpVanHeltonMetalWorking"]=250, ["Base.PickUpVanKimbleKonstruction"]=250, ["Base.PickUpVanMarchRidgeConstruction"]=250, ["Base.PickUpVanMccoy"]=250, ["Base.PickUpVanMetalworker"]=250, ["Base.PickUpVanWeldingbyCamille"]=250, ["Base.PickUpVanYingsWood"]=250, ["Base.PickUpVan_Camo"]=250}
if VLS then
    VLS.equipmentProfiles["Base.Mov_SmallChest"]={capability="roofCargo",
        previewSprite="furniture_storage_02_28",moveableName="Small Chest"}
    -- One Small Chest family, all four orientations. Never match translated names.
    for sprite = 28, 31 do
        VLS.supportedMoveableSprites["furniture_storage_02_" .. sprite] = "Base.Mov_SmallChest"
    end
end

R.legacy = {VLSLowRoofRack=true, VLSRoofMattress=true}
R.allowed = {
    VLSRoofGenerator={ ["Base.Generator"]=true, ["Base.Generator_Old"]=true,
        ["Base.Generator_Yellow"]=true, ["Base.Generator_Blue"]=true },
    VLSRoofSmallChest={ ["Base.Mov_SmallChest"]=true },
    VLSRoofTent={ ["Base.CampingTentKit2_Packed"]=true },
}
for i=1,3 do R.allowed["VLSRoofPetrol"..i]={["Base.PetrolCan"]=true,["Base.JerryCan"]=true} end
function R.SyncPetrolVisual(vehicle,part)
    local index=part:getId():match("^VLSRoofPetrol([123])$")
    if not index then return end
    local item=part:getInventoryItem()
    local kind=item and item:getFullType()
    part:setModelVisible("PetrolCan"..index,kind=="Base.PetrolCan")
    part:setModelVisible("JerryCan"..index,kind=="Base.JerryCan")
end
function R.UninstallPetrolComplete(vehicle,part,item)
    Vehicles.UninstallComplete.Default(vehicle,part,item)
    R.SyncPetrolVisual(vehicle,part)
end
for i=1,2 do
    R.allowed["VLSRoofPropane"..i]={["Base.PropaneTank"]=true}
    R.allowed["VLSRoofSpare"..i]={} -- allowed types belong to the native script part list
end
R.lamps = {}
for i=1,4 do
    local id="VLSRoofHeadlight"..i
    R.lamps[id]=i
    R.allowed[id]={["Base.Torch"]=true}
end
function R.nextLamp(vehicle)
    for i=1,4 do
        local part=vehicle:getPartById("VLSRoofHeadlight"..i)
        if part and not part:getInventoryItem() then return part end
    end
end
function R.lampOrderReady(part)
    return not R.lamps[part:getId()] or R.nextLamp(part:getVehicle())==part
end
function R.isSpare(part)
    return part and (part:getId()=="VLSRoofSpare1" or part:getId()=="VLSRoofSpare2")
end
-- Spare types come only from the native part itemType list (9 vanilla tyres).

R.materials = { ["Base.MetalBar"]=10, ["Base.SmallSheetMetal"]=4,
    ["Base.Screws"]=4, ["Base.Tarp"]=1 }
R.uses = { ["Base.BlowTorch"]=10, ["Base.WeldingRods"]=4 }
R.rackRecipe={itemType=R.fixedType,materials=R.materials,uses=R.uses,scaleWithVehicle=true,
    salvage={{"MetalBar",10,15},{"SmallSheetMetal",4,15},{"Screws",4,25}}}

function R.isPart(part)
    if not part then return false end
    local vehicle=part:getVehicle()
    return vehicle and vehicle:getScript()
        and R.vehicleScripts[vehicle:getScript():getFullName()]==true
        and (part:getId()==R.fixedId or R.allowed[part:getId()]~=nil
            or R.legacy[part:getId()]==true)
end
function R.isActionPart(part)
    return R.isPart(part) or (part and part:getId()~=R.fixedId and R.fabricationSpec(part)~=nil)
end
VLS.installationOptionProviders.roofCargo = function(part)
    if R.isPart(part) then return "EnableRoofRack" end
end
function R.fixed(vehicle)
    local part=vehicle and vehicle:getPartById(R.fixedId)
    local item=part and part:getInventoryItem()
    return item and item:getFullType()==R.fixedType
end
function R.empty(part)
    local c=part and part:getItemContainer()
    return not c or c:isEmpty()
end
function R.atVehicle(chr,part)
    local v=part and part:getVehicle()
    return chr and not chr:isDead() and not chr:getVehicle() and v
        and not v:isRemovedFromWorld() and v:isStopped()
        and v:isInArea(part:getArea(),chr)
end
function R.inventoryEntries(chr)
    local result,seen,itemsSeen={},{},{}
    local function visit(container)
        if seen[container] then return end
        seen[container]=true
        local list=container:getItems()
        for i=0,list:size()-1 do
            local item=list:get(i)
            if not itemsSeen[item] then
                itemsSeen[item]=true
                result[#result+1]={item=item,container=container}
                if instanceof(item,"InventoryContainer") then visit(item:getInventory()) end
            end
        end
    end
    visit(chr:getInventory())
    return result
end
function R.materialStatus(chr,spec)
    spec=spec or R.rackRecipe
    local status={counts={},mask=false,wrench=false}
    for _,entry in ipairs(R.inventoryEntries(chr)) do
        local item=entry.item
        local ft=item:getFullType()
        if item:hasTag(ItemTag.WELDING_MASK) then status.mask=true end
        if item:hasTag(ItemTag.WRENCH) then status.wrench=true end
        if spec.materials[ft] then status.counts[ft]=(status.counts[ft] or 0)+1 end
        if spec.uses[ft] and instanceof(item,"DrainableComboItem") then
            local step=item:getUseDelta()
            local count=step>0 and math.floor((item:getCurrentUsesFloat()+0.000001)/step) or 0
            status.counts[ft]=(status.counts[ft] or 0)+count
        end
    end
    return status
end
-- Action-local material plan, recomputed on the authoritative server at commit.
-- Only visit inventory containers; never include floor/vehicle/neighbour items.
function R.plan(chr,spec)
    spec=spec or R.rackRecipe
    if not chr or chr:isDead() then return nil,"character" end
    if chr:getPerkLevel(Perks.MetalWelding)<(spec.metalWelding or 5)
            or chr:getPerkLevel(Perks.Mechanics)<(spec.mechanics or 1) then return nil,"skills" end
    if spec.toolsReady and not spec.toolsReady(chr) then return nil,"tools" end
    local need,uses={},{}
    for k,v in pairs(spec.materials) do need[k]=v end
    for k,v in pairs(spec.uses) do uses[k]=v end
    local plan={remove={},drain={}}
    local mask,wrench=false,false
    for _,entry in ipairs(R.inventoryEntries(chr)) do
        local item,container=entry.item,entry.container
        local ft=item:getFullType()
        if item:hasTag(ItemTag.WELDING_MASK) then mask=true end
        if item:hasTag(ItemTag.WRENCH) then wrench=true end
        if need[ft] and need[ft]>0 then
            plan.remove[#plan.remove+1]={item=item,container=container}
            need[ft]=need[ft]-1
        elseif uses[ft] and uses[ft]>0
                and instanceof(item,"DrainableComboItem") then
            local delta=item:getCurrentUsesFloat()
            local step=item:getUseDelta()
            local available=step>0 and math.floor((delta+0.000001)/step) or 0
            local take=math.min(available,uses[ft])
            if take>0 then
                plan.drain[#plan.drain+1]={item=item,container=container,
                    before=delta,after=math.max(0,delta-take*step),
                    removeEmpty=ft=="Base.WeldingRods"}
                uses[ft]=uses[ft]-take
                if ft=="Base.BlowTorch" then plan.torch=plan.torch or item end
            end
        end
    end
    for k,v in pairs(need) do if v>0 then return nil,k end end
    for k,v in pairs(uses) do if v>0 then return nil,k end end
    if not mask then return nil,"mask" end
    if not wrench then return nil,"wrench" end
    return plan
end
function R.legacyEmpty(vehicle)
    for id in pairs(R.legacy) do
        local part=vehicle:getPartById(id)
        if part and part:getInventoryItem() then return false end
    end
    return true
end
function R.validateInstall(chr,part,item,position)
    if not VLS.isInstallationEnabled(part) then return false end
    if not R.isActionPart(part) or part:getInventoryItem() then return false end
    if position and not R.atVehicle(chr,part) then return false end
    local spec=R.fabricationSpec(part)
    if spec then
        return (part:getId()~=R.fixedId or R.legacyEmpty(part:getVehicle()))
            and R.empty(part) and (not spec.canInstall or spec.canInstall(chr,part))
            and R.plan(chr,spec)~=nil
    end
    if not R.lampOrderReady(part) then return false end
    local types=R.allowed[part:getId()]
    if not types or not R.fixed(part:getVehicle()) or not item then return false end
    local accepted
    if R.isSpare(part) then
        local nativeTypes=part:getItemType()
        accepted=nativeTypes and nativeTypes:contains(item:getFullType())
    else
        accepted=types[(VLS and VLS.resolveEquipmentType(item)) or item:getFullType()]
    end
    -- Match the native mechanics inventory filter again at action validation.
    if part:getId()=="VLSRoofSmallChest" and item:getCondition()<=0 then return false end
    return accepted and chr:getInventory():contains(item)
end
-- Dedicated servers have no ISVehicleMechanics or inventory-page globals.
function R.NeverInstall() return false end
function R.InstallTest(vehicle,part,chr)
    if not VLS.isInstallationEnabled(part) then return false end
    if not R.isActionPart(part) or part:getInventoryItem() then return false end
    local spec=R.fabricationSpec(part)
    if spec then
        return (part:getId()~=R.fixedId or R.legacyEmpty(vehicle))
            and R.empty(part) and (not spec.canInstall or spec.canInstall(chr,part))
            and R.plan(chr,spec)~=nil
    end
    if not R.allowed[part:getId()] or not R.fixed(vehicle) or not R.lampOrderReady(part) then return false end
    if isServer() then
        if not chr or chr:isDead() or part:getVehicle()~=vehicle then return false end
        -- Roof attachments use native actions without a carried tool.
        return true
    end
    return Vehicles.InstallTest.Default(vehicle,part,chr)
end
function R.UninstallTest(vehicle,part,chr)
    if part and part:getId()=="VLSRoofGenerator" and part:getInventoryItem() then
        local state=part:getInventoryItem():getModData().vlsGenerator
        if state and state.dock then
            local object=VLS.Generator and VLS.Generator.object(vehicle)
            if not object or object:isConnected() or object:isActivated() then return false end
        end
    end
    if not R.isActionPart(part) or R.fabricationSpec(part) or not R.empty(part) then return false end
    if not part:getInventoryItem() or part:getVehicle()~=vehicle then return false end
    if isServer() then return chr ~= nil and not chr:isDead() end
    return Vehicles.UninstallTest.Default(vehicle,part,chr)
end
-- Disassembly is independent of installation switches and never returns a rack.
function R.dismantleTools(chr)
    local torch,mask
    for _,entry in ipairs(R.inventoryEntries(chr)) do
        local item=entry.item
        if (item:hasTag(ItemTag.BLOW_TORCH) or item:getFullType()=="Base.BlowTorch")
                and (not torch or item:getCurrentUses()>torch:getCurrentUses()) then torch=item end
        if item:hasTag(ItemTag.WELDING_MASK) then mask=mask or item end
    end
    return torch,mask
end
function R.canDismantle(chr,part,position)
    local spec=R.fabricationSpec(part)
    if not R.isActionPart(part) or not spec or not part:getInventoryItem()
            or part:getInventoryItem():getFullType()~=spec.itemType
            or not R.empty(part) then return false end
    if position and not R.atVehicle(chr,part) then return false end
    local vehicle=part:getVehicle()
    if part:getId()==R.fixedId then
        for id in pairs(R.allowed) do
            local cargo=vehicle:getPartById(id)
            if cargo and (cargo:getInventoryItem() or not R.empty(cargo)) then return false end
        end
        if not R.legacyEmpty(vehicle) then return false end
    end
    if spec.canDismantle and not spec.canDismantle(chr,part) then return false end
    local torch,mask=R.dismantleTools(chr)
    return torch~=nil and torch:getCurrentUses()>=10 and mask~=nil
end
function R.Access(vehicle,part,chr)
    if not R.isPart(part) or not R.fixed(vehicle) or not part:getInventoryItem() then return false end
    R.syncFixedRackCapacity(vehicle,part)
    return not chr:getVehicle() and vehicle:isInArea(part:getArea(),chr)
end
function R.Create(vehicle,part)
    part:setInventoryItem(nil)
end
-- Use absolute per-body capacities, never repeatedly add to saved values.
-- Refresh the existing item and storage in place, including previously fitted
-- racks. No item/container replacement, cargo removal or global vehicle scan.
function R.syncFixedRackCapacity(vehicle,part)
    if not vehicle or not part or part:getVehicle()~=vehicle
            or part:getId()~=R.fixedId or not R.isPart(part)
            or vehicle:getPartById(R.fixedId)~=part then return false end
    local item=part:getInventoryItem()
    if not item or item:getFullType()~=R.fixedType then return false end
    local capacity=R.rackCapacities[vehicle:getScript():getFullName()]
    if not capacity then return false end
    local itemChanged=item:getMaxCapacity()~=capacity
    if itemChanged then item:setMaxCapacity(capacity) end
    local changed=itemChanged
    if part:getContainerCapacity()~=capacity then
        part:setContainerCapacity(capacity)
        changed=true
    end
    local container=part:getItemContainer()
    if container and container:getCapacity()~=capacity then
        container:setCapacity(capacity)
        changed=true
    end
    -- The two peers derive container capacity locally from the same table.
    -- Only a changed installed item needs the existing item synchronization.
    if itemChanged and not isClient() then vehicle:transmitPartItem(part) end
    return changed
end
-- The 0.12 script allowed native/debug installation of a MetalBar instead
-- of the fabricated rack. Repair that exact invalid installed sentinel on
-- authority only. Preserve the existing storage object and all its contents.
function R.InitFixedRack(vehicle,part)
    R.syncFixedRackCapacity(vehicle,part)
    if VLS.Damage then VLS.Damage.Init(vehicle) end
    if isClient() or not R.isPart(part) or part:getId()~=R.fixedId
            or part:getVehicle()~=vehicle then return false end
    local old=part:getInventoryItem()
    if not old or old:getFullType()~="Base.MetalBar" then return false end
    local fixed=instanceItem(R.fixedType)
    if not fixed then return false end
    local maximum=old:getConditionMax()
    local condition=maximum>0 and math.floor(old:getCondition()*100/maximum+0.5) or 0
    local container=part:getItemContainer()
    fixed:setCondition(condition)
    part:setInventoryItem(fixed,part:getMechanicSkillInstaller())
    if part:getInventoryItem()~=fixed or part:getItemContainer()~=container then
        part:setInventoryItem(old,part:getMechanicSkillInstaller())
        error("VLS roof fixed-rack recovery failed")
    end
    vehicle:transmitPartItem(part)
    print("[VLS roof] repaired MetalBar rack placeholder vehicle="..tostring(vehicle:getId()))
    return true
end

-- Retire old preview slots without deleting their real saved items.
-- Native ItemContainer.hasRoomFor accepts nil character for vehicle storage.
function R.InitLegacy(vehicle,part)
    if isClient() or not R.isPart(part) or not R.legacy[part:getId()]
            or part:getVehicle()~=vehicle or not R.fixed(vehicle) then return false end
    local item=part:getInventoryItem()
    local expected=part:getId()=="VLSLowRoofRack" and "Base.MetalBar" or "Base.Mattress"
    if not item or item:getFullType()~=expected then return false end
    local rack=vehicle:getPartById(R.fixedId)
    local storage=rack and rack:getItemContainer()
    if not storage or not storage:hasRoomFor(nil,item) then return false end
    local ok=pcall(function()
        part:setInventoryItem(nil)
        storage:AddItem(item)
        if not storage:contains(item) or part:getInventoryItem() then error("legacy transfer failed") end
    end)
    if not ok then
        if storage:contains(item) then storage:DoRemoveItem(item) end
        part:setInventoryItem(item,part:getMechanicSkillInstaller())
        if part:getInventoryItem()~=item or storage:contains(item) then error("legacy rollback failed") end
        return false
    end
    vehicle:transmitPartItem(part)
    sendAddItemToContainer(storage,item)
    print("[VLS roof] retired preview item returned to rack: "..part:getId())
    return true
end

function R.InstallComplete(vehicle,part)
    if part:getId()=="VLSRoofSmallChest" then
        local item=part:getInventoryItem()
        item:setMaxCapacity(10)
        part:doInventoryItemStats(item,part:getMechanicSkillInstaller())
    end
    Vehicles.InstallComplete.Default(vehicle,part)
    R.SyncPetrolVisual(vehicle,part)
end
function R.installFixed(chr,part)
    if isClient() or not R.validateInstall(chr,part,nil,true) then return false end
    local spec=R.fabricationSpec(part)
    local plan=R.plan(chr,spec)
    if not spec or not plan then return false end
    local fixed=instanceItem(spec.itemType)
    if not fixed then return false end
    if part:getId()==R.fixedId then
        fixed:setMaxCapacity(R.rackCapacities[part:getVehicle():getScript():getFullName()])
    end
    -- Optional per-part state transaction, constructed before material debit.
    local transaction=spec.prepareInstall and spec.prepareInstall(chr,part,fixed) or nil
    if spec.prepareInstall and not transaction then return false end
    local removed,drained={},{}
    local primary,secondary=chr:getPrimaryHandItem(),chr:getSecondaryHandItem()
    local function remove(entry)
        if not entry.container:contains(entry.item) then error("material moved") end
        removed[#removed+1]=entry
        chr:removeFromHands(entry.item)
        entry.container:DoRemoveItem(entry.item)
        if entry.container:contains(entry.item) then error("material removal failed") end
    end
    local ok,err=pcall(function()
        -- No yield between authoritative validation, debit and part assignment.
        for _,entry in ipairs(plan.remove) do remove(entry) end
        for _,entry in ipairs(plan.drain) do
            drained[#drained+1]=entry
            entry.item:setUsedDelta(entry.after)
            if entry.removeEmpty and entry.after<=0 then remove(entry) end
        end
        part:setInventoryItem(fixed,chr:getPerkLevel(Perks.Mechanics))
        if part:getInventoryItem()~=fixed then error("rack assignment failed") end
        if transaction then transaction.commit() end
    end)
    if not ok then
        if part:getInventoryItem()==fixed then part:setInventoryItem(nil) end
        if transaction then transaction.rollback() end
        for _,entry in ipairs(drained) do entry.item:setUsedDelta(entry.before) end
        for _,entry in ipairs(removed) do
            if not entry.container:contains(entry.item) then entry.container:AddItem(entry.item) end
            if not entry.container:contains(entry.item) then error("VLS roof rollback failed") end
        end
        chr:setPrimaryHandItem(primary);chr:setSecondaryHandItem(secondary)
        print("[VLS roof] installation rolled back: "..tostring(err))
        return false
    end
    -- Commit already complete. A notification failure must never refund a committed rack.
    local sent=pcall(function()
        for _,entry in ipairs(removed) do sendRemoveItemFromContainer(entry.container,entry.item) end
        for _,entry in ipairs(drained) do
            if entry.container:contains(entry.item) then syncItemFields(chr,entry.item) end
        end
        part:getVehicle():transmitPartItem(part)
        addXp(chr,Perks.MetalWelding,25)
    end)
    if not sent then print("[VLS roof] committed; inventory/part notification failed") end
    if spec.onInstalled then spec.onInstalled(part:getVehicle(),part) end
    print("[VLS welding] installed "..part:getId())
    return true
end

function R.UpdateFixedRack(vehicle,part)
    R.syncFixedRackCapacity(vehicle,part)
    if VLS.Damage then VLS.Damage.Update(vehicle) end
end
