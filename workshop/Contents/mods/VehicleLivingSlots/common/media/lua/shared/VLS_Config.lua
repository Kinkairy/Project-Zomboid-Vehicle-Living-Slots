require "Entity/TimedActions/ISHandcraftAction"
require "TimedActions/ISDeviceBatteryAction"

-- VLS_DIRECT_ORIGINAL_FIX_20260904_V2: shared
VLS = VLS or {}

VLS.MOD_ID = "VehicleLivingSlots"
VLS.VERSION = "3.9"
VLS.BUILD_ID = "release-3.9-feedback-fixes-test"
VLS.CATEGORY_ID = "VLSLiving"
VLS.OVERHEAD_CATEGORY_ID = VLS.CATEGORY_ID
VLS.TOP_FRAME_PART_IDS = {"VLSTopFrame1", "VLSTopFrame2", "VLSTopFrame3"}
VLS.TOP_FRAME_ITEM_TYPE = "Base.VLSTopFrame"
VLS.OVERHEAD_PART_IDS = {"VLSPantryCoffee", "VLSOverhead1", "VLSOverhead2"}
VLS.UNIVERSAL_PART_ID = "SeatBed"
VLS.BED_PART_ID = VLS.UNIVERSAL_PART_ID
VLS.BED_PASSENGER_ID = "Bed"
VLS.LARGE_VAN_CENTER_PASSENGER_ID = "SpaceCenter"
VLS.LARGE_VAN_RIGHT_PASSENGER_ID = "SpaceRight"
VLS.BED_AREA_ID = "TruckBed"
VLS.WEAPON_PART_ID = "VLSWeaponCabinetSlot"
VLS.AUX_BATTERY_PART_ID = "VLSAuxBatterySlot"
VLS.FREEZER_PART_ID = "VLSUniversalFreezer"
VLS.LARGE_VAN_SLOT_2_ID = "VLSLargeVanSlot2"
VLS.LARGE_VAN_SLOT_3_ID = "VLSLargeVanSlot3"
VLS.LARGE_VAN_SLOT_4_ID = "VLSLargeVanSlot4"
VLS.LARGE_VAN_SLOT_5_ID = "VLSLargeVanSlot5"
VLS.LARGE_VAN_FREEZER_2_ID = "VLSLargeVanFreezer2"
VLS.LARGE_VAN_FREEZER_3_ID = "VLSLargeVanFreezer3"
VLS.LARGE_VAN_FREEZER_4_ID = "VLSLargeVanFreezer4"
VLS.LARGE_VAN_FREEZER_5_ID = "VLSLargeVanFreezer5"
VLS.LARGE_VAN_WATER_TANK_PART_ID = "VLSLargeVanWaterTank"
VLS.LARGE_VAN_SPACE_4_PASSENGER_ID = "VLSLargeVanSpace4"
VLS.LARGE_VAN_SPACE_5_PASSENGER_ID = "VLSLargeVanSpace5"
VLS.LARGE_VAN_WATER_TANK_DEFAULT_ITEM = "Base.NormalGasTank2"
VLS.LARGE_VAN_WATER_TANK_ITEMS = {
    ["Base.SmallGasTank2"] = true,
    ["Base.NormalGasTank2"] = true,
    ["Base.BigGasTank2"] = true,
}
VLS.WATER_TANK_SOURCE_RANGE = 4
VLS.WATER_TANK_PLAYER_AREA_SCALE = 1.30
VLS.WATER_TANK_PLAYER_MIN_HALF_EXTENT = 0.85
VLS.APPLIANCE_CONTAINER_MAX_DEPTH = 8
VLS.APPLIANCE_CONTAINER_MAX_ITEMS = 512
VLS.WATER_TANK_PART_IDS = {
    [VLS.LARGE_VAN_WATER_TANK_PART_ID] = true,
}
VLS.FREEZER_PART_BY_UNIVERSAL = {
    [VLS.UNIVERSAL_PART_ID] = VLS.FREEZER_PART_ID,
    [VLS.LARGE_VAN_SLOT_2_ID] = VLS.LARGE_VAN_FREEZER_2_ID,
    [VLS.LARGE_VAN_SLOT_3_ID] = VLS.LARGE_VAN_FREEZER_3_ID,
    [VLS.LARGE_VAN_SLOT_4_ID] = VLS.LARGE_VAN_FREEZER_4_ID,
    [VLS.LARGE_VAN_SLOT_5_ID] = VLS.LARGE_VAN_FREEZER_5_ID,
}
VLS.UNIVERSAL_PART_BY_FREEZER = {}
for universalId, freezerId in pairs(VLS.FREEZER_PART_BY_UNIVERSAL) do
    VLS.UNIVERSAL_PART_BY_FREEZER[freezerId] = universalId
end
-- Water entering a large-van tank is normalized to clean water immediately.
VLS.WEAPON_CAPACITY = 40
VLS.CABINET_CAPACITY = 10
VLS.COUNTER_CAPACITY = 50
VLS.MICROWAVE_CAPACITY = 5
VLS.FRIDGE_CAPACITY = 20
VLS.FREEZER_CAPACITY = 5
-- The fridge is a continuous load. The microwave retains its separate,
-- intermittent-use balance because it drains only while active.
VLS.APPLIANCE_DRAIN_DISPLAY_SCALE = 1000
VLS.FRIDGE_POWER_CONSUMPTION = 0.04
VLS.MICROWAVE_POWER_CONSUMPTION = 0.4
VLS.WATER_PURIFICATION_POWER_CONSUMPTION = 0.4
VLS.TELEVISION_POWER_CONSUMPTION = 0.4
VLS.COMBO_POWER_CONSUMPTION = 0.4
VLS.SMALL_APPLIANCE_POWER_CONSUMPTION = 0.2
VLS.COMBO_WATER_PER_CYCLE = 5.0
VLS.LAUNDRY_CYCLE_MINUTES = 90
VLS.Create = VLS.Create or {}
VLS.Init = VLS.Init or {}
VLS.PartComplete = VLS.PartComplete or {}
VLS.Update = VLS.Update or {}
VLS.UninstallTest = VLS.UninstallTest or {}

VLS.vehicleProfiles = {}

-- RC2.0 scheme 1 uses only explicitly inspected, intact B42.20.4 scripts.
VLS.smallVehicleScriptNames = {
    "SUV",
    "PickUpVan", "PickUpVanBrickingIt", "PickUpVanBuilder",
    "PickUpVanCallowayLandscaping", "PickUpVanHeltonMetalWorking",
    "PickUpVanKimbleKonstruction", "PickUpVanMarchRidgeConstruction",
    "PickUpVanMccoy", "PickUpVanMetalworker",
    "PickUpVanWeldingbyCamille", "PickUpVanYingsWood", "PickUpVan_Camo",
}

for _, scriptName in ipairs(VLS.smallVehicleScriptNames) do
    VLS.vehicleProfiles["Base." .. scriptName] = {
        kind = "smallVan",
        universalParts = { VLS.UNIVERSAL_PART_ID },
        bedPassenger = VLS.BED_PASSENGER_ID,
        spacePassengers = {
            { part = VLS.UNIVERSAL_PART_ID, passenger = VLS.BED_PASSENGER_ID },
        },
        rearArea = VLS.BED_AREA_ID,
    }
end

VLS.mediumVanScriptNames = {
    "Van", "VanBeckmans", "VanBrewsterHarbin",
    "VanBuilder", "VanCarpenter", "VanCoastToCoast", "VanDeerValley",
    "VanFossoil", "VanGardenGods", "VanGardener", "VanGreenes",
    "VanJohnMcCoy", "VanJonesFabrication", "VanKerrHomes",
    "VanKnobCreekGas", "VanKnoxCom", "VanKorshunovs",
    "VanLouisvilleLandscaping", "VanMail", "VanMccoy", "VanMechanic",
    "VanMeltingPointMetal", "VanMetalheads", "VanMetalworker",
    "VanMicheles", "VanMobileMechanics", "VanMooreMechanics",
    "VanOldMill", "VanOvoFarm", "VanPennSHam", "VanPlattAuto",
    "VanPluggedInElectrics", "VanRiversideFabrication",
    "VanRosewoodworking", "VanSchwabSheetMetal",
    "VanSpiffo", "VanTreyBaines", "VanUncloggers", "VanUtility",
    "VanWPCarpentry", "Van_Blacksmith", "Van_BugWipers",
    "Van_Charlemange_Beer", "Van_CraftSupplies", "Van_Glass",
    "Van_HeritageTailors", "Van_KnoxDisti", "Van_Leather",
    "Van_LectroMax", "Van_Locksmith", "Van_Masonry", "Van_MassGenFac",
    "Van_Perfick_Potato", "Van_Transit", "Van_VoltMojo",
}

for _, scriptName in ipairs(VLS.mediumVanScriptNames) do
    VLS.vehicleProfiles["Base." .. scriptName] = {
        kind = "mediumVan",
        universalParts = {
            VLS.UNIVERSAL_PART_ID,
            VLS.LARGE_VAN_SLOT_2_ID,
            VLS.LARGE_VAN_SLOT_3_ID,
        },
        bedPassenger = VLS.BED_PASSENGER_ID,
        spacePassengers = {
            { part = VLS.UNIVERSAL_PART_ID, passenger = VLS.BED_PASSENGER_ID },
            { part = VLS.LARGE_VAN_SLOT_2_ID,
                passenger = VLS.LARGE_VAN_CENTER_PASSENGER_ID },
            { part = VLS.LARGE_VAN_SLOT_3_ID,
                passenger = VLS.LARGE_VAN_RIGHT_PASSENGER_ID },
        },
        rearArea = "TruckBed",
    }
end

-- Exact B42.20.4 intact Step Vans are the large-van class.
VLS.stepVanScriptNames = {
    "StepVan",
    "StepVan_Blacksmith",
    "StepVan_Butchers",
    "StepVan_Cereal",
    "StepVan_Citr8",
    "StepVan_CompleteRepairShop",
    "StepVan_Florist",
    "StepVan_Genuine_Beer",
    "StepVan_Glass",
    "StepVan_Heralds",
    "StepVan_HuangsLaundry",
    "StepVan_Jorgensen",
    "StepVan_LouisvilleMotorShop",
    "StepVan_LouisvilleSWAT",
    "StepVan_MarineBites",
    "StepVan_Masonry",
    "StepVan_Mechanic",
    "StepVan_MobileLibrary",
    "StepVan_Plonkies",
    "StepVan_Propane",
    "StepVan_RandisPlants",
    "StepVan_Scarlet",
    "StepVan_SmartKut",
    "StepVan_SouthEasternHosp",
    "StepVan_SouthEasternPaint",
    "StepVan_USL",
    "StepVan_Zippee",
    "StepVanAirportCatering",
    "StepVanMail",
}

for _, scriptName in ipairs(VLS.stepVanScriptNames) do
    VLS.vehicleProfiles["Base." .. scriptName] = {
        kind = "largeVan",
        universalParts = {
            VLS.UNIVERSAL_PART_ID,
            VLS.LARGE_VAN_SLOT_2_ID,
            VLS.LARGE_VAN_SLOT_3_ID,
            VLS.LARGE_VAN_SLOT_4_ID,
            VLS.LARGE_VAN_SLOT_5_ID,
        },
        bedPassenger = VLS.BED_PASSENGER_ID,
        spacePassengers = {
            { part = VLS.UNIVERSAL_PART_ID, passenger = VLS.BED_PASSENGER_ID },
            { part = VLS.LARGE_VAN_SLOT_2_ID,
                passenger = VLS.LARGE_VAN_CENTER_PASSENGER_ID },
            { part = VLS.LARGE_VAN_SLOT_3_ID,
                passenger = VLS.LARGE_VAN_RIGHT_PASSENGER_ID },
            { part = VLS.LARGE_VAN_SLOT_4_ID,
                passenger = VLS.LARGE_VAN_SPACE_4_PASSENGER_ID },
            { part = VLS.LARGE_VAN_SLOT_5_ID,
                passenger = VLS.LARGE_VAN_SPACE_5_PASSENGER_ID },
        },
        rearArea = "TruckBed",
        waterTankParts = { VLS.LARGE_VAN_WATER_TANK_PART_ID },
    }
end

for _, profile in pairs(VLS.vehicleProfiles) do
    local count = profile.kind == "largeVan" and 3
        or profile.kind == "mediumVan" and 2 or 1
    profile.overheadParts = {}
    for index = 1, count do
        profile.overheadParts[index] = VLS.OVERHEAD_PART_IDS[index]
    end
end

VLS.equipmentProfiles = {
    ["Base.Mov_Cot"] = {
        capability = "bed",
        sleepQuality = "goodBed",
        previewSprite = "furniture_bedding_01_56",
    },
    ["Base.Mattress"] = {
        capability = "bed",
        sleepQuality = "goodBed",
        previewSprite = "carpentry_02_76",
    },
    ["Base.Mov_GreenWallLocker"] = {
        capability = "weaponStorage",
        capacity = VLS.WEAPON_CAPACITY,
        previewSprite = "furniture_storage_02_8",
        containerType = "locker",
        containerOpenSound = "LockerMetalLargeOpen",
        containerCloseSound = "LockerMetalLargeClose",
        containerPutSound = "LockerMetalLargeTransferItem",
        containerTakeSound = "LockerMetalLargeTransferItem",
    },
    ["Base.Mov_SmallPineCabinet"] = {
        capability = "storage",
        genericCraftSurface = true,
        capacity = VLS.CABINET_CAPACITY,
        previewSprite = "furniture_storage_01_48",
        containerType = "sidetable",
        containerOpenSound = "DrawerWoodOpen",
        containerCloseSound = "DrawerWoodClose",
        containerPutSound = "DrawerWoodTransferItem",
        containerTakeSound = "DrawerWoodTransferItem",
    },
    ["Base.Mov_Microwave"] = {
        capability = "cooking",
        previewSprite = "appliances_cooking_01_24",
        capacity = VLS.MICROWAVE_CAPACITY,
        containerType = "microwave",
        containerOpenSound = "MicrowaveDoorOpen",
        containerCloseSound = "MicrowaveDoorClose",
        containerPutSound = "MicrowaveTransferItem",
        containerTakeSound = "MicrowaveTransferItem",
    },
    ["Base.Mov_Microwave2"] = {
        capability = "cooking",
        previewSprite = "appliances_cooking_01_28",
        capacity = VLS.MICROWAVE_CAPACITY,
        containerType = "microwave",
        containerOpenSound = "MicrowaveDoorOpen",
        containerCloseSound = "MicrowaveDoorClose",
        containerPutSound = "MicrowaveTransferItem",
        containerTakeSound = "MicrowaveTransferItem",
    },
    ["Base.Mov_FridgeMini"] = {
        capability = "cooling",
        previewSprite = "appliances_refrigeration_01_25",
        capacity = VLS.FRIDGE_CAPACITY,
        containerType = "fridge",
        containerOpenSound = "OpenFridge",
        containerCloseSound = "CloseFridge",
        containerPutSound = "PutItemInFridge",
        containerTakeSound = "PutItemInFridge",
    },
    ["Base.Mov_TrailerFridge"] = {
        capability = "cooling",
        previewSprite = "location_trailer_02_10",
        capacity = VLS.FRIDGE_CAPACITY,
        containerType = "fridge",
        containerOpenSound = "OpenFridge",
        containerCloseSound = "CloseFridge",
        containerPutSound = "PutItemInFridge",
        containerTakeSound = "PutItemInFridge",
    },
    ["Base.WaterDispenserBottle"] = {
        capability = "waterDispenser",
    },
    ["Base.TvAntique"] = {
        capability = "television",
        previewSprite = "appliances_television_01_8",
    },
    ["Base.TvBlack"] = {
        capability = "television",
        previewSprite = "appliances_television_01_4",
    },
    ["Base.TvWideScreen"] = {
        capability = "television",
        previewSprite = "appliances_television_01_0",
    },
}

-- The vanilla blue combo is a real Base moveable item. Keep its native item
-- type and ordinary vehicle-part install transaction; only its vehicle
-- container and wash/dry modes need a vehicle adapter.
VLS.equipmentProfiles["Base.Mov_BlueComboWasherDryer"] = {
    capability = "laundryCombo",
    previewSprite = "appliances_laundry_01_0",
    capacity = 20,
    containerType = "clothingwasher",
    containerOpenSound = "WashingMachineOpen",
    containerCloseSound = "WashingMachineClose",
    containerPutSound = "WashingMachineTransferItem",
    containerTakeSound = "WashingMachineTransferItem",
}

-- B42's ordinary floor-mounted kitchen counters.  The matching wall/upper
-- cabinet rows are deliberately excluded because the small van has room only
-- for lower furniture.
local lowerCounterFamilies = {
    { "Modern", 0, "DoorWoodMediumOpen", "DoorWoodMediumClose", "DoorWoodMediumTransferItem" },
    { "Wooden", 8, "DoorWoodMediumOpen", "DoorWoodMediumClose", "DoorWoodMediumTransferItem" },
    { "Steel", 32, "DoorMetalSmallOpen", "DoorMetalSmallClose", "DoorMetalSmallTransferItem" },
    { "Birch", 40, "DoorWoodMediumOpen", "DoorWoodMediumClose", "DoorWoodMediumTransferItem" },
    { "Oak", 48, "DoorWoodMediumOpen", "DoorWoodMediumClose", "DoorWoodMediumTransferItem" },
    { "Dark", 56, "DoorWoodMediumOpen", "DoorWoodMediumClose", "DoorWoodMediumTransferItem" },
    { "Green", 64, "DoorWoodMediumOpen", "DoorWoodMediumClose", "DoorWoodMediumTransferItem" },
    { "White", 72, "DoorWoodMediumOpen", "DoorWoodMediumClose", "DoorWoodMediumTransferItem" },
}

for _, family in ipairs(lowerCounterFamilies) do
    local name, sprite = family[1], family[2]
    local openSound, closeSound, transferSound = family[3], family[4], family[5]
    VLS.equipmentProfiles["Base.Mov_" .. name .. "Counter"] = {
        capability = "storage",
        genericCraftSurface = true,
        capacity = VLS.COUNTER_CAPACITY,
        previewSprite = "fixtures_counters_01_" .. (sprite + 5),
        containerType = "counter",
        containerOpenSound = openSound,
        containerCloseSound = closeSound,
        containerPutSound = transferSound,
        containerTakeSound = transferSound,
    }
end

VLS.sleepingBagTypes = {
    ["Base.SleepingBag_RedPlaid"] = true,
    ["Base.SleepingBag_BluePlaid"] = true,
    ["Base.SleepingBag_Green"] = true,
    ["Base.SleepingBag_GreenPlaid"] = true,
    ["Base.SleepingBag_Camo"] = true,
    ["Base.SleepingBag_Cheap_Green"] = true,
    ["Base.SleepingBag_Cheap_Blue"] = true,
    ["Base.SleepingBag_Cheap_Green2"] = true,
    ["Base.SleepingBag_Spiffo"] = true,
    ["Base.SleepingBag_HighQuality_Brown"] = true,
    ["Base.SleepingBag_Hide"] = true,
}

VLS.supportedMoveableSprites = {
    ["carpentry_02_76"] = "Base.Mattress",
    ["appliances_cooking_01_24"] = "Base.Mov_Microwave",
    ["appliances_cooking_01_25"] = "Base.Mov_Microwave",
    ["appliances_cooking_01_26"] = "Base.Mov_Microwave",
    ["appliances_cooking_01_27"] = "Base.Mov_Microwave",
    ["appliances_cooking_01_28"] = "Base.Mov_Microwave2",
    ["appliances_cooking_01_29"] = "Base.Mov_Microwave2",
    ["appliances_cooking_01_30"] = "Base.Mov_Microwave2",
    ["appliances_cooking_01_31"] = "Base.Mov_Microwave2",
    ["appliances_refrigeration_01_24"] = "Base.Mov_FridgeMini",
    ["appliances_refrigeration_01_25"] = "Base.Mov_FridgeMini",
    ["appliances_refrigeration_01_26"] = "Base.Mov_FridgeMini",
    ["appliances_refrigeration_01_27"] = "Base.Mov_FridgeMini",
    ["location_trailer_02_10"] = "Base.Mov_TrailerFridge",
    ["location_trailer_02_11"] = "Base.Mov_TrailerFridge",
    ["location_trailer_02_16"] = "Base.Mov_TrailerFridge",
    ["location_trailer_02_17"] = "Base.Mov_TrailerFridge",
    ["furniture_storage_01_48"] = "Base.Mov_SmallPineCabinet",
    ["furniture_storage_01_49"] = "Base.Mov_SmallPineCabinet",
    ["furniture_storage_01_50"] = "Base.Mov_SmallPineCabinet",
    ["furniture_storage_01_51"] = "Base.Mov_SmallPineCabinet",
    ["furniture_storage_02_8"] = "Base.Mov_GreenWallLocker",
    ["furniture_storage_02_9"] = "Base.Mov_GreenWallLocker",
    ["furniture_storage_02_10"] = "Base.Mov_GreenWallLocker",
    ["furniture_storage_02_11"] = "Base.Mov_GreenWallLocker",
}

for spriteIndex = 0, 3 do
    VLS.supportedMoveableSprites["appliances_laundry_01_" .. spriteIndex] =
        "Base.Mov_BlueComboWasherDryer"
end

for _, family in ipairs(lowerCounterFamilies) do
    local name, sprite = family[1], family[2]
    -- Each counter family alternates corner and straight sprites.  Only the
    -- four straight orientations belong in the small-van universal slot.
    for offset = 1, 7, 2 do
        VLS.supportedMoveableSprites["fixtures_counters_01_" .. (sprite + offset)] =
            "Base.Mov_" .. name .. "Counter"
    end
end

VLS.allowedItems = {
    [VLS.UNIVERSAL_PART_ID] = {},
    [VLS.LARGE_VAN_SLOT_2_ID] = {},
    [VLS.LARGE_VAN_SLOT_3_ID] = {},
    [VLS.LARGE_VAN_SLOT_4_ID] = {},
    [VLS.LARGE_VAN_SLOT_5_ID] = {},
    [VLS.WEAPON_PART_ID] = {
        ["Base.Mov_GreenWallLocker"] = true,
    },
    [VLS.AUX_BATTERY_PART_ID] = {
        ["Base.CarBattery1"] = true,
        ["Base.CarBattery2"] = true,
        ["Base.CarBattery3"] = true,
    },
}

local generalSlotIds = {
    VLS.UNIVERSAL_PART_ID,
    VLS.LARGE_VAN_SLOT_2_ID,
    VLS.LARGE_VAN_SLOT_3_ID,
    VLS.LARGE_VAN_SLOT_4_ID,
    VLS.LARGE_VAN_SLOT_5_ID,
}

for fullType, profile in pairs(VLS.equipmentProfiles) do
    if profile.capability ~= "weaponStorage" then
        for _, partId in ipairs(generalSlotIds) do
            VLS.allowedItems[partId][fullType] = true
        end
    end
end
for fullType in pairs(VLS.sleepingBagTypes) do
    for _, partId in ipairs(generalSlotIds) do
        VLS.allowedItems[partId][fullType] = true
    end
end


-- Overhead storage shares the accepted furniture transaction/container adapter,
-- but its item allowlist and installation positions remain separate.
local overheadCatalog = require "VLS_OverheadCatalog"
for _, id in ipairs(VLS.OVERHEAD_PART_IDS) do VLS.allowedItems[id] = {} end
for _, entry in ipairs(overheadCatalog) do
    local sound = entry.metal and "DoorMetalSmall" or "DoorWoodMedium"
    VLS.equipmentProfiles[entry.type] = {
        capability = "storage", overhead = true, capacity = 50,
        overheadInstallable = entry.installable,
        containerType = "overhead", previewSprite = entry.sprites[1],
        moveableName = entry.name,
        containerOpenSound = sound .. "Open", containerCloseSound = sound .. "Close",
        containerPutSound = sound .. "TransferItem", containerTakeSound = sound .. "TransferItem",
    }
    for _, sprite in ipairs(entry.sprites) do
        VLS.supportedMoveableSprites[sprite] = entry.type
    end
    for _, id in ipairs(VLS.OVERHEAD_PART_IDS) do
        VLS.allowedItems[id][entry.type] = true
    end
end

function VLS.getOverheadIndex(part)
    if not part then return nil end
    for index,id in ipairs(VLS.OVERHEAD_PART_IDS) do
        if part:getId()==id then return index end
    end
end

function VLS.getTopFramePart(cupboard)
    local index=VLS.getOverheadIndex(cupboard)
    return index and cupboard:getVehicle():getPartById(VLS.TOP_FRAME_PART_IDS[index]) or nil
end
function VLS.isTopFramePart(part)
    local profile=part and VLS.getVehicleProfile(part:getVehicle())
    local index=part and tonumber(part:getId():match("^VLSTopFrame([1-3])$"))
    return profile and index and index<=#profile.overheadParts or false
end
function VLS.hasTopFrame(cupboard)
    local part=VLS.getTopFramePart(cupboard)
    local item=part and part:getInventoryItem()
    return item and item:getFullType()==VLS.TOP_FRAME_ITEM_TYPE and item:getCondition()>0 or false
end
function VLS.isOverheadPart(part)
    local profile = part and VLS.getVehicleProfile(part:getVehicle())
    for _, id in ipairs(profile and profile.overheadParts or {}) do
        if part:getId() == id then return true end
    end
    return false
end

function VLS.getVehicleProfile(vehicle)
    if not vehicle then return nil end
    return VLS.vehicleProfiles[vehicle:getScriptName()]
end

function VLS.isSupportedVehicle(vehicle)
    return VLS.getVehicleProfile(vehicle) ~= nil
end

function VLS.isMediumVan(vehicle)
    local profile = VLS.getVehicleProfile(vehicle)
    return profile ~= nil and profile.kind == "mediumVan"
end

function VLS.isLargeVan(vehicle)
    local profile = VLS.getVehicleProfile(vehicle)
    return profile ~= nil and profile.kind == "largeVan"
end

function VLS.isMediumOrLargeVan(vehicle)
    return VLS.isMediumVan(vehicle) or VLS.isLargeVan(vehicle)
end

function VLS.getWaterTankPartIds(vehicle)
    local profile = VLS.getVehicleProfile(vehicle)
    return profile and profile.waterTankParts or {}
end

function VLS.hasWaterTankCapability(vehicle)
    return #VLS.getWaterTankPartIds(vehicle) > 0
end

local function isProfileWaterTankPartId(vehicle, partId)
    for _, profilePartId in ipairs(VLS.getWaterTankPartIds(vehicle)) do
        if profilePartId == partId then return true end
    end
    return false
end

function VLS.isWaterTankPart(part)
    return part ~= nil
        and isProfileWaterTankPartId(part:getVehicle(), part:getId())
end

function VLS.isUniversalPart(part)
    if not part then return false end
    if VLS.isOverheadPart(part) then return true end
    local profile = VLS.getVehicleProfile(part:getVehicle())
    if not profile then return false end
    for _, partId in ipairs(profile.universalParts) do
        if part:getId() == partId then return true end
    end
    return false
end

function VLS.getEquipmentProfileByType(fullType)
    if VLS.sleepingBagTypes[fullType] then
        return { capability = "bed", sleepQuality = "averageBed" }
    end
    return VLS.equipmentProfiles[fullType]
end

function VLS.resolveEquipmentType(item)
    if not item then return nil end

    local fullType = item:getFullType()
    if VLS.getEquipmentProfileByType(fullType) then return fullType end

    local scriptItem = item:getScriptItem()
    local scriptType = scriptItem and scriptItem:getFullName() or nil
    if scriptType and VLS.getEquipmentProfileByType(scriptType) then
        return scriptType
    end

    if not instanceof(item, "Moveable") then return nil end
    local sprite = item:getWorldSprite()
    if not sprite then return nil end
    sprite = sprite:gsub("^ct_oac_", "")
    return VLS.supportedMoveableSprites[sprite]
end

function VLS.getEquipmentProfile(item)
    local itemType = VLS.resolveEquipmentType(item)
    return itemType and VLS.getEquipmentProfileByType(itemType) or nil
end

function VLS.getEquipmentCapability(item)
    local profile = VLS.getEquipmentProfile(item)
    return profile and profile.capability or nil
end

-- A vehicle provides a vanilla generic handcraft surface only when one of the
-- approved lower cabinets/counters is actually installed in one of that same
-- supported vehicle's universal living slots.
function VLS.isGenericCraftSurfaceEquipment(item)
    local profile = VLS.getEquipmentProfile(item)
    return profile ~= nil and profile.genericCraftSurface == true
end

function VLS.getInstalledGenericCraftSurfacePart(vehicle)
    local vehicleProfile = vehicle and VLS.getVehicleProfile(vehicle) or nil
    if not vehicleProfile then return nil end

    for _, partId in ipairs(vehicleProfile.universalParts or {}) do
        local part = VLS.getInstalledPart(vehicle, partId)
        if part and VLS.isGenericCraftSurfaceEquipment(
                part:getInventoryItem()) then
            return part
        end
    end

    return nil
end

function VLS.hasGenericCraftSurface(vehicle)
    return VLS.getInstalledGenericCraftSurfacePart(vehicle) ~= nil
end

function VLS.getVehicleGenericCraftSurface(playerObj)
    local vehicle = playerObj and playerObj:getVehicle() or nil
    if vehicle and VLS.hasGenericCraftSurface(vehicle) then
        return vehicle
    end
    return nil
end

function VLS.canUseVehicleGenericCraftSurface(playerObj, vehicle)
    return playerObj ~= nil
        and vehicle ~= nil
        and playerObj:getVehicle() == vehicle
        and VLS.isSupportedVehicle(vehicle)
        and VLS.hasGenericCraftSurface(vehicle)
end

function VLS.isBedEquipment(item)
    return VLS.getEquipmentCapability(item) == "bed"
end

function VLS.isStorageEquipment(item)
    local profile = VLS.getEquipmentProfile(item)
    return profile ~= nil and profile.capacity ~= nil and profile.capacity > 0
end

function VLS.isManagedPart(part)
    return VLS.isUniversalPart(part)
        or (part and part:getId() == VLS.WEAPON_PART_ID
            and VLS.isSupportedVehicle(part:getVehicle()))
        or (part and part:getId() == VLS.AUX_BATTERY_PART_ID
            and VLS.isSupportedVehicle(part:getVehicle()))
        or VLS.isFreezerPart(part)
        or VLS.isWaterTankPart(part)
end

-- Installation policy only. Existing equipment recognition, use, storage and
-- removal deliberately keep their original contracts when an option changes.
VLS.installationOptions = {
    bed = "EnableBeds", storage = "EnableCabinets",
    weaponStorage = "EnableWeaponCabinets", cooking = "EnableMicrowaves",
    cooling = "EnableFridges", waterDispenser = "EnableWaterDispensers",
    television = "EnableTelevisions",
    laundryCombo = "EnableComboWasherDryers",
}
VLS.installationOptionProviders = VLS.installationOptionProviders or {}
function VLS.getInstallationOption(part, itemOrType)
    if not part then return nil end
    for _, provider in pairs(VLS.installationOptionProviders) do
        local option = provider(part, itemOrType)
        if option then return option end
    end
    if not VLS.isSupportedVehicle(part:getVehicle()) then return nil end
    -- Auxiliary batteries are essential power infrastructure, always installable.
    if part:getId() == VLS.AUX_BATTERY_PART_ID then return nil end
    if VLS.isWaterTankPart(part) then return "EnableWaterTanks" end
    if not VLS.isUniversalPart(part) and part:getId() ~= VLS.WEAPON_PART_ID then
        return nil
    end
    local profile
    if type(itemOrType) == "string" then
        profile = VLS.getEquipmentProfileByType(itemOrType)
    elseif itemOrType then
        profile = VLS.getEquipmentProfile(itemOrType)
    end
    return profile and VLS.installationOptions[profile.capability] or nil
end
function VLS.isWaterTankShortcutEnabled()
    local settings = SandboxVars and SandboxVars.VehicleLivingSlots
    return not settings or settings.EnableWaterTankShortcut ~= false
end

function VLS.isInstallationEnabled(part, itemOrType)
    if VLS.isOverheadPart(part) then
        if not VLS.hasTopFrame(part) then return false end
        local profile = type(itemOrType) == "string"
            and VLS.getEquipmentProfileByType(itemOrType) or VLS.getEquipmentProfile(itemOrType)
        if profile and profile.overheadInstallable == false then return false end
    end
    local option = VLS.getInstallationOption(part, itemOrType)
    local settings = SandboxVars and SandboxVars.VehicleLivingSlots
    if option and settings and settings[option] == false then return false end
    return true
end

function VLS.isAllowedItem(part, item)
    if not part or not item or not VLS.isSupportedVehicle(part:getVehicle()) then
        return false
    end
    local allowed = VLS.allowedItems[part:getId()]
    if not allowed then return false end
    if part:getId():find("^VLSOverhead") and not VLS.isOverheadPart(part) then return false end
    local itemType = item:getFullType()
    if not allowed[itemType] then itemType = VLS.resolveEquipmentType(item) end
    if allowed[itemType] ~= true then return false end
    if part:getId() == VLS.AUX_BATTERY_PART_ID then
        return instanceof(item, "DrainableComboItem")
    end
    local profile = VLS.getEquipmentProfile(item)
    if part:getId() == VLS.WEAPON_PART_ID then
        return profile and profile.capability == "weaponStorage"
    end
    return profile ~= nil and profile.capability ~= "weaponStorage"
end

function VLS.getInstalledPart(vehicle, partId)
    if not VLS.isSupportedVehicle(vehicle) then return nil end
    local part = vehicle:getPartById(partId)
    if not part or not part:getInventoryItem() then return nil end
    if not VLS.isAllowedItem(part, part:getInventoryItem()) then return nil end
    return part
end

function VLS.getInstalledBedPart(vehicle)
    local profile = VLS.getVehicleProfile(vehicle)
    if not profile then return nil end
    for _, partId in ipairs(profile.universalParts) do
        local part = VLS.getInstalledPart(vehicle, partId)
        if part and VLS.isBedEquipment(part:getInventoryItem()) then return part end
    end
    return nil
end

function VLS.getInstalledBedParts(vehicle)
    local result = {}
    local profile = VLS.getVehicleProfile(vehicle)
    if not profile then return result end
    for _, partId in ipairs(profile.universalParts) do
        local part = VLS.getInstalledPart(vehicle, partId)
        if part and VLS.isBedEquipment(part:getInventoryItem()) then
            table.insert(result, part)
        end
    end
    return result
end

function VLS.getFirstInstalledUniversalPart(vehicle)
    local profile = VLS.getVehicleProfile(vehicle)
    if not profile then return nil end
    for _, partId in ipairs(profile.universalParts) do
        local part = VLS.getInstalledPart(vehicle, partId)
        if part then return part end
    end
    return nil
end

function VLS.getEquipmentDisplayName(item)
    if not item then return nil end
    if VLS.resolveEquipmentType(item) == "Base.Mov_BlueComboWasherDryer"
            and not (item.isCustomName and item:isCustomName()) then
        return getItemNameFromFullType("Base.Mov_BlueComboWasherDryer")
    end
    return item:getDisplayName()
end

function VLS.getPartDisplayName(part, fallback)
    local item = part and part:getInventoryItem()
    if item and VLS.isManagedPart(part) then
        if VLS.isWaterTankPart(part) then
            return getText("IGUI_VehiclePartVLSLargeVanWaterTank")
        end
        return VLS.getEquipmentDisplayName(item)
    end
    if VLS.isOverheadPart(part) then return getText("IGUI_VehiclePartVLSOverhead1") end
    if part and VLS.isUniversalPart(part) then
        local vehicle = part:getVehicle()
        local profile = VLS.getVehicleProfile(vehicle)
        local partId = part:getId()
        if profile and profile.kind == "smallVan" then
            return getText("IGUI_VLSSmallVanRearLivingArea")
        end
        if profile and profile.kind == "mediumVan" then
            if partId == VLS.UNIVERSAL_PART_ID then
                return getText("IGUI_VLSLargeVanLeftLivingArea")
            elseif partId == VLS.LARGE_VAN_SLOT_2_ID then
                return getText("IGUI_VLSLargeVanCenterLivingArea")
            elseif partId == VLS.LARGE_VAN_SLOT_3_ID then
                return getText("IGUI_VLSLargeVanRightLivingArea")
            end
        end
        if profile and profile.kind == "largeVan" then
            local names = {
                [VLS.UNIVERSAL_PART_ID] = "IGUI_VLSLargeVanFrontLeftSpace",
                [VLS.LARGE_VAN_SLOT_2_ID] = "IGUI_VLSLargeVanFrontRightSpace",
                [VLS.LARGE_VAN_SLOT_3_ID] = "IGUI_VLSLargeVanMiddleLeftSpace",
                [VLS.LARGE_VAN_SLOT_4_ID] = "IGUI_VLSLargeVanMiddleRightSpace",
                [VLS.LARGE_VAN_SLOT_5_ID] = "IGUI_VLSLargeVanRearSpace",
            }
            return getText(names[partId] or "IGUI_VLSLargeVanLivingSpace")
        end
    end
    return fallback
end

function VLS.getSeatEquipmentDisplayName(vehicle, seat)
    if not VLS.isBedSeat(vehicle, seat) then return nil end
    local part = VLS.getUniversalPartForSeat(vehicle, seat)
    local item = part and part:getInventoryItem()
    return item and item:getDisplayName() or VLS.getPartDisplayName(part, nil)
end

local CONTAINER_PROFILE_VERSION = 2

local function applyContainerProfile(container, profile, fallbackType)
    if not container then return false end
    local changed = false
    local capacity = profile and profile.capacity or 0
    if container:getCapacity() ~= capacity then
        container:setCapacity(capacity)
        changed = true
    end
    local containerType = profile and profile.containerType or fallbackType
    local openSound = profile and profile.containerOpenSound or "VehicleTrunkOpen"
    local closeSound = profile and profile.containerCloseSound or "VehicleTrunkClose"
    local putSound = profile and profile.containerPutSound or "VehicleTrunkTransferItem"
    local takeSound = profile and profile.containerTakeSound or "VehicleTrunkTransferItem"
    if container:getType() ~= containerType then
        container:setType(containerType)
        changed = true
    end
    if container:getOpenSound() ~= openSound then
        container:setOpenSound(openSound)
        changed = true
    end
    if container:getCloseSound() ~= closeSound then
        container:setCloseSound(closeSound)
        changed = true
    end
    if container:getPutSound() ~= putSound then
        container:setPutSound(putSound)
        changed = true
    end
    if container:getTakeSound() ~= takeSound then
        container:setTakeSound(takeSound)
        changed = true
    end
    return changed
end

-- Appliance inventories may contain bags inside bags. Keep every client and
-- server traversal on the same bounded, cycle-safe implementation so a bad or
-- unusually deep item graph cannot turn a visible refrigerator into an
-- unbounded per-tick scan.
function VLS.walkApplianceContainer(container, visitor, state)
    state = state or {
        visited = {},
        items = 0,
        maxDepth = VLS.APPLIANCE_CONTAINER_MAX_DEPTH,
        maxItems = VLS.APPLIANCE_CONTAINER_MAX_ITEMS,
    }
    if not container or state.visited[container]
            or (state.depth or 0) > state.maxDepth
            or state.items >= state.maxItems then
        return state
    end

    state.visited[container] = true
    local items = container:getItems()
    if not items then return state end
    local parentDepth = state.depth or 0
    for index = 0, items:size() - 1 do
        if state.items >= state.maxItems then break end
        local item = items:get(index)
        state.items = state.items + 1
        visitor(item, state)
        if instanceof(item, "InventoryContainer") then
            state.depth = parentDepth + 1
            VLS.walkApplianceContainer(item:getInventory(), visitor, state)
            state.depth = parentDepth
        end
    end
    return state
end

function VLS.getInstalledCapabilityPart(vehicle, capability)
    local profile = VLS.getVehicleProfile(vehicle)
    if not profile then return nil end
    for _, partId in ipairs(profile.universalParts) do
        local part = VLS.getInstalledPart(vehicle, partId)
        if part and VLS.getEquipmentCapability(part:getInventoryItem()) == capability then
            return part
        end
    end
    return nil
end

function VLS.getInstalledCapabilityParts(vehicle, capability)
    local result = {}
    local profile = VLS.getVehicleProfile(vehicle)
    if not profile then return result end
    for _, partId in ipairs(profile.universalParts) do
        local part = VLS.getInstalledPart(vehicle, partId)
        if part and VLS.getEquipmentCapability(part:getInventoryItem()) == capability then
            table.insert(result, part)
        end
    end
    return result
end

function VLS.isFreezerPart(part)
    return part ~= nil and VLS.UNIVERSAL_PART_BY_FREEZER[part:getId()] ~= nil
        and VLS.isSupportedVehicle(part:getVehicle())
end

function VLS.getFreezerPartForUniversal(vehicle, universalPartId)
    local freezerId = VLS.FREEZER_PART_BY_UNIVERSAL[universalPartId]
    return freezerId and vehicle and vehicle:getPartById(freezerId) or nil
end

function VLS.ensureUniversalContainerProfile(part)
    if not VLS.isUniversalPart(part) then return nil end
    local container = part:getItemContainer()
    if not container then return nil end
    local profile = VLS.getEquipmentProfile(part:getInventoryItem())
    if profile and profile.capability == "laundryCombo"
            and VLS.getLaundryMode(part) == "laundryDryer" then
        local dryerProfile = {}
        for key, value in pairs(profile) do dryerProfile[key] = value end
        dryerProfile.containerType = "clothingdryer"
        profile = dryerProfile
    end
    local changed = applyContainerProfile(container,
        profile and profile.capacity and profile or nil,
        VLS.UNIVERSAL_PART_ID)
    return profile, changed
end

-- Restore the installed equipment profile for this living-slot part while
-- preserving the vehicle-wide damage baseline initialization.  This must be
-- a per-part callback: VLS.Damage.Init caches by vehicle and may return after
-- the first living slot has initialized.
function VLS.Init.UniversalSlot(vehicle, part)
    if not vehicle or not part
            or part:getVehicle() ~= vehicle
            or vehicle:getPartById(part:getId()) ~= part
            or not VLS.isUniversalPart(part) then
        return
    end

    if VLS.Damage and VLS.Damage.Init then
        VLS.Damage.Init(vehicle)
    end

    VLS.ensureUniversalContainerProfile(part)
end

function VLS.syncUniversalSlot(part)
    if not VLS.isUniversalPart(part) then return false end
    local container = part:getItemContainer()
    if not container then return false end
    local item = part:getInventoryItem()
    local profile = VLS.getEquipmentProfile(item)
    local capability = profile and profile.capability
    local vehicle = part:getVehicle()
    local data = part:getModData()
    local itemId = item and item:getID() or -1
    local itemChanged = data.vlsEquipmentItemId ~= itemId
    local profileChanged = data.vlsContainerProfileVersion
        ~= CONTAINER_PROFILE_VERSION

    if itemChanged then data.vlsLaundryMode = nil end

    -- Part modData and the installed item can arrive before the client-side
    -- ItemContainer fields. Reapply the desired profile on every lifecycle
    -- pass; applyContainerProfile itself writes only fields that differ.
    local _, containerChanged = VLS.ensureUniversalContainerProfile(part)
    data.vlsContainerProfileVersion = CONTAINER_PROFILE_VERSION

    if (itemChanged or profileChanged)
            and (capability == "cooking" or capability == "cooling")
            and vehicle and vehicle.setNeedPartsUpdate then
        vehicle:setNeedPartsUpdate(true)
    end
    if itemChanged then
        data.vlsEquipmentItemId = itemId
        data.vlsLaundryActive = false
        data.vlsLaundryPaused = false
        data.vlsLaundryRemaining = 0
        data.vlsLaundryItemId = nil
        data.vlsLaundryWaterBudget = nil
        data.vlsLaundryWaterSpent = nil
        data.vlsLaundryMode = nil
        data.vlsMicrowaveActive = false
        data.vlsMicrowaveTimer = 0
        data.vlsMicrowaveRemaining = 0
        data.vlsMicrowaveLastHours = nil
        data.vlsMicrowaveClockItemId = nil
        data.vlsMicrowaveTemperature = 90
        container:setCustomTemperature(1.0)
        container:setAgeFactor(1.0)
    end
    return itemChanged or profileChanged or containerChanged
end

local function syncOneFreezerSlot(vehicle, universalPartId)
    local freezerId = VLS.FREEZER_PART_BY_UNIVERSAL[universalPartId]
    if not freezerId then return false end
    local freezer = vehicle:getPartById(freezerId)
    local container = freezer and freezer:getItemContainer()
    if not container then return false end
    local fridge = VLS.getInstalledPart(vehicle, universalPartId)
    if fridge and VLS.getEquipmentCapability(fridge:getInventoryItem()) ~= "cooling" then
        fridge = nil
    end
    local containerProfile = fridge and {
        capacity = VLS.FREEZER_CAPACITY,
        containerType = "freezer",
        containerOpenSound = "OpenFridge",
        containerCloseSound = "CloseFridge",
        containerPutSound = "PutItemInFridge",
        containerTakeSound = "PutItemInFridge",
    } or nil
    local data = freezer:getModData()
    local item = fridge and fridge:getInventoryItem()
    local itemId = item and item:getID() or -1
    local stateChanged = data.vlsEquipmentItemId ~= itemId
        or data.vlsContainerProfileVersion ~= CONTAINER_PROFILE_VERSION

    -- Keep the hidden freezer container's runtime profile in sync even when
    -- replicated modData already says the correct appliance is installed.
    local containerChanged = applyContainerProfile(
        container, containerProfile, freezerId)
    data.vlsEquipmentItemId = itemId
    data.vlsContainerProfileVersion = CONTAINER_PROFILE_VERSION

    if stateChanged and not containerProfile then
        container:setCustomTemperature(1.0)
        container:setAgeFactor(1.0)
    end
    return stateChanged or containerChanged
end

function VLS.syncFreezerSlot(vehicle, universalPartId)
    if not VLS.isSupportedVehicle(vehicle) then return false end
    if universalPartId then
        return syncOneFreezerSlot(vehicle, universalPartId)
    end
    local changed = false
    local profile = VLS.getVehicleProfile(vehicle)
    for _, partId in ipairs(profile.universalParts) do
        if syncOneFreezerSlot(vehicle, partId) then changed = true end
    end
    return changed
end

local function ensureTelevisionPresets(deviceData)
    if not deviceData then return false end
    local presetData = deviceData:getDevicePresets()
    local presets = presetData and presetData:getPresets()
    if presets and presets:size() > 0 then return false end

    -- Vanilla vehicle radios generate their station list on creation. Installed
    -- televisions need the same step after their original device metadata has
    -- been copied into the vehicle part.
    deviceData:generatePresets()
    presetData = deviceData:getDevicePresets()
    presets = presetData and presetData:getPresets()
    if not presets or presets:size() <= 0 then return false end
    local channel = deviceData:getChannel()
    if channel < deviceData:getMinChannelRange()
            or channel > deviceData:getMaxChannelRange() then
        deviceData:setRandomChannel()
    end
    return true
end

function VLS.getTelevisionDevicePart(part)
    if not VLS.isUniversalPart(part) then return nil end
    return VLS.getFreezerPartForUniversal(part:getVehicle(), part:getId())
end

function VLS.getTelevisionDeviceData(part)
    local item = part and part:getInventoryItem()
    if VLS.getEquipmentCapability(item) ~= "television" then return nil end
    local devicePart = VLS.getTelevisionDevicePart(part)
    local deviceData = devicePart and devicePart:getDeviceData()
    if not deviceData or not deviceData:getIsTelevision() then return nil end
    return deviceData
end

local function copyTelevisionMetadata(target, source, preserveSettings)
    target:setDeviceName(source:getDeviceName())
    target:setIsTwoWay(source:getIsTwoWay())
    target:setTransmitRange(source:getTransmitRange())
    target:setMicRange(source:getMicRange())
    target:setBaseVolumeRange(source:getBaseVolumeRange())
    target:setIsPortable(false)
    target:setIsTelevision(source:getIsTelevision())
    target:setMinChannelRange(source:getMinChannelRange())
    target:setMaxChannelRange(source:getMaxChannelRange())
    -- Keep the television's original grid-powered presentation. Auxiliary
    -- battery availability is adapted below the vanilla radio window.
    target:setIsBatteryPowered(false)
    target:setHasBattery(false)
    target:setIsHighTier(source:getIsHighTier())
    -- Auxiliary-battery drain is centralized in VLS_ApplianceServer. The
    -- hidden signal device only mirrors charge for vanilla validity/UI logic.
    target:setUseDelta(0)
    target:setMediaType(source:getMediaType())
    if not preserveSettings then
        target:setChannelRaw(source:getChannel())
        target:setDeviceVolumeRaw(source:getDeviceVolume())
        target:cloneDevicePresets(source:getDevicePresets())
    end
end

local function televisionMetadataMatches(target, source)
    return target:getDeviceName() == source:getDeviceName()
        and target:getMediaType() == source:getMediaType()
        and target:getIsTwoWay() == source:getIsTwoWay()
        and target:getTransmitRange() == source:getTransmitRange()
        and target:getMicRange() == source:getMicRange()
        and target:getBaseVolumeRange() == source:getBaseVolumeRange()
        and not target:getIsPortable()
        and target:getIsTelevision() == source:getIsTelevision()
        and target:getMinChannelRange() == source:getMinChannelRange()
        and target:getMaxChannelRange() == source:getMaxChannelRange()
        and target:getIsHighTier() == source:getIsHighTier()
end

function VLS.syncTelevisionDevice(vehicle, part, _refreshMetadata)
    if not VLS.isUniversalPart(part) then return false end
    local item = part:getInventoryItem()
    local television = VLS.getEquipmentCapability(item) == "television"
        and instanceof(item, "Radio")
    local source = television and item:getDeviceData() or nil
    television = television and source and source:getIsTelevision()
    local devicePart = VLS.getTelevisionDevicePart(part)
    if not devicePart then return false end
    local deviceData = devicePart:getDeviceData()
    local data = devicePart:getModData()

    if not television then
        local changed = false
        if deviceData and deviceData:getIsTurnedOn() then
            deviceData:setTurnedOnRaw(false)
            changed = true
        end
        if data.vlsTelevisionItemId ~= -1 then
            data.vlsTelevisionItemId = -1
            changed = true
        end
        if changed and not isClient() then
            vehicle:transmitPartItem(devicePart)
            vehicle:transmitPartModData(devicePart)
        end
        return changed
    end

    if not deviceData then deviceData = devicePart:createSignalDevice() end
    if not deviceData then return false end

    local itemId = item:getID()
    local changed = false
    if data.vlsTelevisionItemId ~= itemId or not deviceData:getIsTelevision() then
        copyTelevisionMetadata(deviceData, source)
        data.vlsTelevisionItemId = itemId
        changed = true
    elseif not televisionMetadataMatches(deviceData, source) then
        -- Part modData may arrive with the new item ID while the hidden
        -- signal device still describes the old TV. Its metadata is not
        -- carried by transmitPartItem; compare the actual local device.
        -- Preserve live station, volume and presets during this repair.
        copyTelevisionMetadata(deviceData, source, true)
        changed = true
    end
    if ensureTelevisionPresets(deviceData) then changed = true end

    local power = VLS.getAuxBatteryCharge(vehicle)
    if deviceData:getIsBatteryPowered() then
        deviceData:setIsBatteryPowered(false)
        deviceData:setHasBattery(false)
        changed = true
    end
    if math.abs(deviceData:getPower() - power) > 0.000001 then
        deviceData:setPower(power)
        changed = true
    end
    if power <= 0 and deviceData:getIsTurnedOn() then
        deviceData:setTurnedOnRaw(false)
        changed = true
    end
    if changed and not isClient() then
        vehicle:transmitPartItem(devicePart)
        vehicle:transmitPartModData(devicePart)
    end
    return changed
end

function VLS.copyTelevisionStateToItem(part, item)
    if not VLS.isUniversalPart(part)
            or VLS.getEquipmentCapability(item) ~= "television"
            or not instanceof(item, "Radio") then
        return false
    end
    local source = VLS.getTelevisionDeviceData(part)
    local target = item:getDeviceData()
    if not source or not target then return false end

    target:setChannelRaw(source:getChannel())
    target:setDeviceVolumeRaw(source:getDeviceVolume())
    target:cloneDevicePresets(source:getDevicePresets())
    target:setTurnedOnRaw(false)
    return true
end

local VLS_TELEVISION_ACTION_PREFIX = "VLS_TV_DEVICE:"

function VLS.getTelevisionPartForDevicePart(devicePart)
    if not devicePart or not instanceof(devicePart, "VehiclePart") then
        return nil
    end
    local vehicle = devicePart:getVehicle()
    if not VLS.isSupportedVehicle(vehicle) then return nil end
    local universalId = VLS.UNIVERSAL_PART_BY_FREEZER[devicePart:getId()]
    local part = universalId and VLS.getInstalledPart(vehicle, universalId)
        or nil
    if not part
            or VLS.getEquipmentCapability(part:getInventoryItem())
                ~= "television"
            or VLS.getTelevisionDevicePart(part) ~= devicePart then
        return nil
    end
    return part
end

function VLS.getTelevisionDeviceActionParameter(devicePart)
    local part = VLS.getTelevisionPartForDevicePart(devicePart)
    local vehicle = part and part:getVehicle() or nil
    if not vehicle then return nil end
    return VLS_TELEVISION_ACTION_PREFIX
        .. tostring(vehicle:getId()) .. ":" .. devicePart:getId()
end

function VLS.resolveTelevisionDeviceActionParameter(character, parameter)
    if type(parameter) ~= "string"
            or string.sub(parameter, 1, #VLS_TELEVISION_ACTION_PREFIX)
                ~= VLS_TELEVISION_ACTION_PREFIX then
        return nil, false
    end

    local vehicleText, devicePartId = string.match(parameter,
        "^VLS_TV_DEVICE:(%d+):(.+)$")
    local vehicleId = tonumber(vehicleText)
    local vehicle = character and character:getVehicle() or nil
    if not vehicleId or not vehicle or vehicle:getId() ~= vehicleId
            or not VLS.isSupportedVehicle(vehicle) then
        return nil, true
    end

    local devicePart = vehicle:getPartById(devicePartId)
    local televisionPart = VLS.getTelevisionPartForDevicePart(devicePart)
    local deviceData = televisionPart
        and VLS.getTelevisionDeviceData(televisionPart) or nil
    return deviceData, true
end

VLS.televisionDeviceActionHooks = VLS.televisionDeviceActionHooks or {}

function VLS.installTelevisionDeviceActionHooks()
    if not ISDeviceBatteryAction then return end
    local hooks = VLS.televisionDeviceActionHooks

    if ISDeviceBatteryAction.getDeviceDataParameter
            ~= hooks.getDeviceDataParameterWrapper then
        local previous = ISDeviceBatteryAction.getDeviceDataParameter
        hooks.getDeviceDataParameterWrapper = function(self, character,
                device, deviceType)
            if deviceType == "VehiclePart" then
                local parameter =
                    VLS.getTelevisionDeviceActionParameter(device)
                if parameter then return parameter end
            end
            return previous(self, character, device, deviceType)
        end
        ISDeviceBatteryAction.getDeviceDataParameter =
            hooks.getDeviceDataParameterWrapper
    end

    if ISDeviceBatteryAction.getDeviceDataFromParameter
            ~= hooks.getDeviceDataFromParameterWrapper then
        local previous = ISDeviceBatteryAction.getDeviceDataFromParameter
        hooks.getDeviceDataFromParameterWrapper = function(self, character,
                parameter)
            local deviceData, handled =
                VLS.resolveTelevisionDeviceActionParameter(
                    character, parameter)
            if handled then return deviceData end
            return previous(self, character, parameter)
        end
        ISDeviceBatteryAction.getDeviceDataFromParameter =
            hooks.getDeviceDataFromParameterWrapper
    end
end

VLS.installTelevisionDeviceActionHooks()

function VLS.Create.UniversalSlot(vehicle, part)
    VLS.syncUniversalSlot(part)
    VLS.syncFreezerSlot(vehicle, part and part:getId())
    VLS.syncTelevisionDevice(vehicle, part, false)
    VLS.refreshApplianceEnvironment(vehicle, part, true, true)
    if VLS.Server and VLS.Server.trackVehicle then
        VLS.Server.trackVehicle(vehicle)
    end
end

function VLS.PartComplete.UniversalSlot(vehicle, part)
    VLS.syncUniversalSlot(part)
    VLS.syncFreezerSlot(vehicle, part and part:getId())
    VLS.syncTelevisionDevice(vehicle, part, true)
    VLS.refreshApplianceEnvironment(vehicle, part, true, true)
    if VLS.Server and VLS.Server.trackVehicle then
        VLS.Server.trackVehicle(vehicle)
    end
end

function VLS.Update.UniversalSlot(vehicle, part, elapsedMinutes)
    if VLS.Damage then VLS.Damage.Update(vehicle) end
    local changed = VLS.syncUniversalSlot(part)
    if VLS.syncFreezerSlot(vehicle, part and part:getId()) then changed = true end
    if VLS.syncTelevisionDevice(vehicle, part, false) then changed = true end
    if VLS.Server and VLS.Server.updateAppliance then
        VLS.Server.updateAppliance(vehicle, part, elapsedMinutes or 0, changed, true)
    else
        VLS.refreshApplianceEnvironment(vehicle, part, changed, true)
    end
end

function VLS.Create.UniversalFreezer(vehicle, part)
    VLS.syncFreezerSlot(vehicle,
        part and VLS.UNIVERSAL_PART_BY_FREEZER[part:getId()])
end

function VLS.Update.UniversalFreezer(vehicle, part)
    VLS.syncFreezerSlot(vehicle,
        part and VLS.UNIVERSAL_PART_BY_FREEZER[part:getId()])
end

function VLS.syncWeaponLocker(part)
    if not part or part:getId() ~= VLS.WEAPON_PART_ID then return end
    local container = part:getItemContainer()
    if not container then return end
    local item = part:getInventoryItem()
    local profile = item and VLS.isAllowedItem(part, item)
        and VLS.getEquipmentProfile(item) or nil
    applyContainerProfile(container, profile, VLS.WEAPON_PART_ID)
end

function VLS.Create.WeaponLocker(vehicle, part)
    VLS.syncWeaponLocker(part)
end

function VLS.PartComplete.WeaponLocker(vehicle, part)
    VLS.syncWeaponLocker(part)
end

function VLS.Update.WeaponLocker(vehicle, part)
    VLS.syncWeaponLocker(part)
end

function VLS.getItemConditionPercent(item)
    if not item then return nil end
    local maxCondition = item:getConditionMax()
    if not maxCondition or maxCondition <= 0 then return nil end
    return math.max(0, math.min(100,
        math.floor(item:getCondition() * 100 / maxCondition + 0.5)))
end

-- Display-only extensions must not turn transport cargo into living-system parts.
VLS.mechanicsDisplayProviders = VLS.mechanicsDisplayProviders or {}
function VLS.usesNormalizedPartCondition(part)
    if VLS.isManagedPart(part) or VLS.isTopFramePart(part) then return true end
    for _, test in pairs(VLS.mechanicsDisplayProviders) do
        if test(part) then return true end
    end
    return false
end

function VLS.getDisplayPartCondition(part)
    if not VLS.usesNormalizedPartCondition(part) or not part:getInventoryItem() then
        return part and part:getCondition() or 0
    end
    return VLS.getItemConditionPercent(part:getInventoryItem()) or part:getCondition()
end

function VLS.getSpaceAssignmentForPart(vehicle, partOrId)
    local profile = VLS.getVehicleProfile(vehicle)
    if not profile then return nil end
    local partId = type(partOrId) == "string" and partOrId
        or (partOrId and partOrId:getId())
    if not partId then return nil end
    for _, assignment in ipairs(profile.spacePassengers or {}) do
        if assignment.part == partId then return assignment end
    end
    return nil
end

function VLS.getSpaceAssignmentForSeat(vehicle, seat)
    local profile = VLS.getVehicleProfile(vehicle)
    if not profile then return nil end
    local script = vehicle:getScript()
    if not script then return nil end
    for _, assignment in ipairs(profile.spacePassengers or {}) do
        local passengerSeat = script:getPassengerIndex(assignment.passenger)
        if passengerSeat >= 0 and passengerSeat == seat then return assignment end
    end
    return nil
end

function VLS.getUniversalPartForSeat(vehicle, seat)
    local assignment = VLS.getSpaceAssignmentForSeat(vehicle, seat)
    return assignment and vehicle:getPartById(assignment.part) or nil
end

function VLS.getInstalledUniversalPartForSeat(vehicle, seat)
    local assignment = VLS.getSpaceAssignmentForSeat(vehicle, seat)
    return assignment and VLS.getInstalledPart(vehicle, assignment.part) or nil
end

function VLS.getInstalledBedPartForSeat(vehicle, seat)
    local part = VLS.getInstalledUniversalPartForSeat(vehicle, seat)
    return part and VLS.isBedEquipment(part:getInventoryItem()) and part or nil
end

function VLS.getBedSeat(vehicle, bedPart)
    local profile = VLS.getVehicleProfile(vehicle)
    if not profile then return -1 end
    local script = vehicle:getScript()
    if not script then return -1 end
    bedPart = bedPart or VLS.getInstalledBedPart(vehicle)
    local assignment = bedPart and VLS.getSpaceAssignmentForPart(vehicle, bedPart)
        or (profile.spacePassengers and profile.spacePassengers[1])
    return assignment and script:getPassengerIndex(assignment.passenger) or -1
end

function VLS.isBedSeat(vehicle, seat)
    return VLS.getSpaceAssignmentForSeat(vehicle, seat) ~= nil
end

function VLS.isUsingBedSeat(playerObj, vehicle)
    if not playerObj or not vehicle or playerObj:getVehicle() ~= vehicle then return false end
    local seat = vehicle:getSeat(playerObj)
    return seat >= 0 and VLS.getInstalledBedPartForSeat(vehicle, seat) ~= nil
end

function VLS.getVehicleBedQuality(playerObj)
    local vehicle = playerObj and playerObj:getVehicle()
    if not vehicle or not VLS.isUsingBedSeat(playerObj, vehicle) then return nil end
    local part = VLS.getInstalledBedPartForSeat(vehicle, vehicle:getSeat(playerObj))
    local profile = part and VLS.getEquipmentProfile(part:getInventoryItem())
    return profile and profile.sleepQuality or nil
end

function VLS.getFridgeAgeFactor()
    local value = SandboxVars and SandboxVars.FridgeFactor or 3
    local factors = { 0.4, 0.3, 0.2, 0.1, 0.03, 0.0 }
    return factors[value] or 0.2
end

function VLS.getFoodRotSpeed()
    local value = SandboxVars and SandboxVars.FoodRotSpeed or 3
    return ({ 1.7, 1.4, 1.0, 0.7, 0.4 })[value] or 1.0
end

-- B42.20 Food.updateFreezing/updateAge constants, verified against the pinned
-- game class. Vehicle containers lack the world-object power endpoint those
-- native methods require. This single pure bridge serves authoritative updates
-- and bounded client projection; client predictions never update their baseline.
function VLS.getPoweredFoodProgress(item,age,freezing,hours,freezer)
    if freezer and item:canBeFrozen() then
        freezing=math.min(100,freezing+hours/4*100)
    elseif freezing>0 then
        freezing=math.max(0,freezing-hours/3*100)
    end
    local factor=freezing>=100 and 0 or VLS.getFridgeAgeFactor()
    return age+hours*VLS.getFoodRotSpeed()/24*factor,freezing
end

-- Preserve the temperature trajectory a Food item has already reached while a
-- VLS refrigerator/freezer is genuinely powered. This rejects a stale item
-- synchronization that jumps heat upward, but does not snap newly inserted hot
-- food directly to the refrigerator target.
function VLS.preservePoweredFoodHeat(item, state, targetHeat)
    if not item or not state or not instanceof(item, "Food") then
        return false
    end

    local currentHeat = tonumber(item:getHeat()) or 1.0
    local target = tonumber(targetHeat) or 1.0
    local previousHeat = tonumber(state.heat)

    if previousHeat == nil then
        state.heat = currentHeat
        state.targetHeat = target
        return false
    end

    local epsilon = 0.0001
    local correctedHeat = currentHeat

    if previousHeat > target + epsilon then
        -- Normal powered cooling is monotonic toward the target.
        if currentHeat > previousHeat + epsilon then
            correctedHeat = previousHeat
        end
    elseif previousHeat < target - epsilon then
        -- Food moved from a freezer to a fridge may warm, but not beyond the
        -- currently powered container's target.
        if currentHeat > target + epsilon then
            correctedHeat = target
        end
    elseif currentHeat > target + epsilon then
        correctedHeat = target
    end

    local changed = math.abs(correctedHeat - currentHeat) > epsilon
    if changed then item:setHeat(correctedHeat) end

    state.heat = correctedHeat
    state.targetHeat = target
    return changed
end

local function getApplianceBalanceOption(optionName, fallback, maximum)
    local options = SandboxVars and SandboxVars.VehicleLivingSlots
    local value = options and tonumber(options[optionName]) or fallback
    if not value or value ~= value then return fallback end
    return math.max(0.01, math.min(value, maximum))
end

function VLS.getFridgePowerConsumption()
    return getApplianceBalanceOption("FridgePowerConsumption",
        VLS.FRIDGE_POWER_CONSUMPTION, 100)
end

function VLS.getMicrowavePowerConsumption()
    return getApplianceBalanceOption("MicrowavePowerConsumption",
        VLS.MICROWAVE_POWER_CONSUMPTION, 100)
end

function VLS.getWaterPurificationPowerConsumption()
    return getApplianceBalanceOption("WaterPurificationPowerConsumption",
        VLS.WATER_PURIFICATION_POWER_CONSUMPTION, 100)
end

function VLS.getTelevisionPowerConsumption()
    return getApplianceBalanceOption("TelevisionPowerConsumption",
        VLS.TELEVISION_POWER_CONSUMPTION, 100)
end

function VLS.getComboWaterPerCycle()
    return getApplianceBalanceOption("ComboWaterPerCycle",
        VLS.COMBO_WATER_PER_CYCLE, 100)
end

-- Retain the existing wash option key so saved settings carry forward.
-- Washing and drying now use one user-visible power setting.
function VLS.getComboPowerConsumption()
    return getApplianceBalanceOption("ComboWashPowerConsumption",
        VLS.COMBO_POWER_CONSUMPTION, 100)
end

function VLS.getComboWashPowerConsumption()
    return VLS.getComboPowerConsumption()
end

function VLS.getComboDryPowerConsumption()
    return VLS.getComboPowerConsumption()
end

function VLS.getLaundryMode(part)
    local data = part and part:getModData()
    return data and data.vlsLaundryMode == "laundryDryer"
        and "laundryDryer" or "laundryWasher"
end

-- Shared vehicle power adapter. All auxiliary-battery consumers use this
-- boundary; device code supplies a rate and units (minutes, crafts or liters).
-- Existing public VLS helpers below remain small compatibility delegates.
VLS.VehiclePower = VLS.VehiclePower or {}
local VehiclePower = VLS.VehiclePower

local function finitePower(value)
    return type(value) == "number" and value == value
        and value >= 0 and value < math.huge
end

function VehiclePower.rate(displayValue)
    if not finitePower(displayValue) then return 0 end
    return displayValue / VLS.APPLIANCE_DRAIN_DISPLAY_SCALE
end

function VLS.getSmallApplianceDrainPerUse()
    return VehiclePower.rate(getApplianceBalanceOption("SmallAppliancePowerConsumption",
        VLS.SMALL_APPLIANCE_POWER_CONSUMPTION, 100))
end

function VLS.getLaundryDrainPerMinute(mode)
    return VehiclePower.rate(VLS.getComboPowerConsumption())
end

function VLS.getFridgeDrainPerMinute()
    return VehiclePower.rate(VLS.getFridgePowerConsumption())
end

function VLS.getMicrowaveDrainPerMinute()
    return VehiclePower.rate(VLS.getMicrowavePowerConsumption())
end

function VLS.getWaterPurificationDrainPerLiter()
    return VehiclePower.rate(VLS.getWaterPurificationPowerConsumption())
end

function VLS.getTelevisionDrainPerMinute()
    return VehiclePower.rate(VLS.getTelevisionPowerConsumption())
end

function VLS.getAuxBatteryPart(vehicle)
    return VLS.getInstalledPart(vehicle, VLS.AUX_BATTERY_PART_ID)
end

function VehiclePower.snapshot(vehicle)
    local part = VLS.getAuxBatteryPart(vehicle)
    local item = part and part:getInventoryItem()
    if not item then return nil end
    return { vehicle = vehicle, part = part, item = item,
        charge = item:getCurrentUsesFloat() }
end

local function writePower(snapshot, charge, deferSync)
    if isClient and isClient() then return false end
    if not snapshot or not finitePower(charge)
            or VLS.getAuxBatteryPart(snapshot.vehicle) ~= snapshot.part
            or snapshot.part:getInventoryItem() ~= snapshot.item then return false end
    charge = math.min(1, charge)
    if snapshot.item:getCurrentUsesFloat() ~= charge then
        snapshot.item:setUsedDelta(charge)
        if not deferSync then VehiclePower.sync(snapshot.vehicle, snapshot.part) end
    end
    return true
end

function VehiclePower.sync(vehicle, part)
    if isClient and isClient() then return end
    part = part or VLS.getAuxBatteryPart(vehicle)
    if part then vehicle:transmitPartUsedDelta(part) end
end

function VehiclePower.restore(snapshot, deferSync)
    return snapshot == nil or writePower(snapshot, snapshot.charge, deferSync)
end

function VehiclePower.charge(vehicle)
    local state = VehiclePower.snapshot(vehicle)
    return state and state.charge or 0
end

function VehiclePower.has(vehicle, required)
    required = required == nil and 0.0001 or required
    local state = VehiclePower.snapshot(vehicle)
    return finitePower(required) and state ~= nil and state.charge >= required
end

function VehiclePower.capacity(vehicle, rate)
    if not finitePower(rate) then return 0 end
    local state = VehiclePower.snapshot(vehicle)
    if not state then return 0 end
    return rate == 0 and math.huge or math.max(0, state.charge) / rate
end

function VehiclePower.consume(vehicle, amount)
    if not finitePower(amount) then return false end
    local state = VehiclePower.snapshot(vehicle)
    if not state then return false end
    -- Preserve established continuous-device behavior: an exhausted battery
    -- reaches zero and the caller stops the device on this false result.
    local sufficient = state.charge >= amount
    if not writePower(state, math.max(0, state.charge - amount)) then return false end
    return sufficient
end

function VehiclePower.reserve(vehicle, amount)
    if not finitePower(amount) or (isClient and isClient()) then return nil end
    if amount == 0 then return { cost = 0 } end
    local state = VehiclePower.snapshot(vehicle)
    if not state or state.charge < amount then return nil end
    if not writePower(state, state.charge - amount, true) then return nil end
    state.cost = amount
    return state
end

function VehiclePower.settle(reservation, used)
    if not reservation or reservation.settled or not finitePower(used)
            or used > reservation.cost + 0.000000001 then return false end
    used = math.min(used, reservation.cost)
    if reservation.cost == 0 then reservation.settled = true; return true end
    local charge = reservation.item:getCurrentUsesFloat()
    if not writePower(reservation, charge + reservation.cost - used, true) then return false end
    reservation.settled = true
    return true
end

function VLS.getAuxBatteryCharge(vehicle)
    return VehiclePower.charge(vehicle)
end

function VLS.hasAuxBatteryPower(vehicle, required)
    return VehiclePower.has(vehicle, required)
end

function VLS.consumeAuxBattery(vehicle, amount)
    return VehiclePower.consume(vehicle, amount)
end

function VLS.getWaterPurificationCapacity(vehicle)
    return VehiclePower.capacity(vehicle, VLS.getWaterPurificationDrainPerLiter())
end

function VLS.getInstalledWaterBottlePart(vehicle)
    return VLS.getInstalledCapabilityPart(vehicle, "waterDispenser")
end

function VLS.getInstalledWaterBottle(vehicle)
    local part = VLS.getInstalledWaterBottlePart(vehicle)
    local item = part and part:getInventoryItem()
    if not item or item:getFullType() ~= "Base.WaterDispenserBottle" then return nil end
    return item, part
end

function VLS.getInstalledVehicleFluidEndpoints(vehicle)
    local result, seen = {}, {}
    if not VLS.isSupportedVehicle(vehicle) then return result end

    for _, partId in ipairs(VLS.getWaterTankPartIds(vehicle)) do
        local item, part = VLS.getInstalledWaterTank(vehicle, partId)
        local itemId = item and item:getID()
        if itemId and part and not seen[itemId] then
            seen[itemId] = true
            table.insert(result, { item = item, part = part })
        end
    end

    for _, bottlePart in ipairs(
            VLS.getInstalledCapabilityParts(vehicle, "waterDispenser")) do
        local bottle = bottlePart:getInventoryItem()
        local bottleId = bottle and bottle:getID()
        if bottle and bottle:getFullType() == "Base.WaterDispenserBottle"
                and bottle:getFluidContainer() and bottleId
                and not seen[bottleId] then
            seen[bottleId] = true
            table.insert(result, { item = bottle, part = bottlePart })
        end
    end
    return result
end

function VLS.getInstalledWaterTank(vehicle, preferredPartId)
    if not VLS.hasWaterTankCapability(vehicle) then return nil end
    local fallbackItem, fallbackPart
    for _, partId in ipairs(VLS.getWaterTankPartIds(vehicle)) do
        if not preferredPartId or preferredPartId == partId then
            local part = vehicle:getPartById(partId)
            local item = part and part:getInventoryItem()
            if item and VLS.LARGE_VAN_WATER_TANK_ITEMS[item:getFullType()]
                    and item:getFluidContainer() then
                if preferredPartId or item:getFluidContainer():getAmount() > 0 then
                    return item, part
                end
                fallbackItem, fallbackPart = fallbackItem or item,
                    fallbackPart or part
            end
        end
    end
    return fallbackItem, fallbackPart
end


function VLS.getFillableWaterTank(vehicle)
    for _, partId in ipairs(VLS.getWaterTankPartIds(vehicle)) do
        local item, part = VLS.getInstalledWaterTank(vehicle, partId)
        local fluid = item and item:getFluidContainer()
        if fluid and fluid:getAmount() + 0.0001 < fluid:getCapacity() then
            return item, part
        end
    end
    return nil
end

function VLS.getVehicleFluidItem(vehicle, partId)
    if partId and isProfileWaterTankPartId(vehicle, partId) then
        return VLS.getInstalledWaterTank(vehicle, partId)
    end
    if partId then
        local part = vehicle and vehicle:getPartById(partId)
        local item = part and part:getInventoryItem()
        if part and VLS.isUniversalPart(part)
                and item and item:getFullType() == "Base.WaterDispenserBottle"
                and item:getFluidContainer()
                and VLS.getEquipmentCapability(item) == "waterDispenser" then
            return item, part
        end
        return nil
    end
    local bottle, part = VLS.getInstalledWaterBottle(vehicle)
    return bottle, part
end

function VLS.getVehicleFluidPartId(vehicle)
    local tank, tankPart = VLS.getInstalledWaterTank(vehicle)
    if tank then return tankPart:getId() end
    local bottle, bottlePart = VLS.getInstalledWaterBottle(vehicle)
    return bottle and bottlePart:getId() or nil
end

function VLS.getWaterPurificationCost(amount)
    return math.max(0, tonumber(amount) or 0)
        * VLS.getWaterPurificationDrainPerLiter()
end

function VLS.isPureWaterFluid(fluidContainer)
    if not fluidContainer or fluidContainer:getAmount() <= 0 then return false end
    local primary = fluidContainer:getPrimaryFluid()
    local fluidType = primary and primary:getFluidTypeString() or nil
    if fluidType ~= "Base.Water" and fluidType ~= "Water"
            and fluidType ~= "Base.TaintedWater" and fluidType ~= "TaintedWater" then
        return false
    end
    return fluidContainer:getPrimaryFluidAmount() + 0.0001
        >= fluidContainer:getAmount()
end

-- IsoObject:getFluidAmount() also reports rain puddles on ordinary floor
-- sprites. These are not stable tank intake endpoints in multiplayer; do not
-- let a wet road win the scan before a real river, tap, or water container.
function VLS.getTankWaterSourceAmount(source)
    if not source or not source.getFluidAmount or not source:getSquare()
            or source:getObjectIndex() < 0 then return 0 end
    local fluid = source:getFluidContainer()
    if fluid and fluid:getAmount() > 0 then
        if not VLS.isPureWaterFluid(fluid) then return 0 end
    else
        local props = source:getProperties()
        if props and props:has(IsoFlagType.solidfloor)
                and not props:has(IsoFlagType.water)
                and not props:has(IsoFlagType.waterPiped) then
            -- B42.20.4 isWaterInfinite() is private Java, not a Lua API.
            -- Keep scripted infinite sources (e.g. wells) through the public
            -- WATER_AMOUNT property; vanilla getFluidAmount owns availability.
            local scriptedWater = props:has(IsoPropertyType.WATER_AMOUNT)
                and tonumber(props:get(IsoPropertyType.WATER_AMOUNT)) or 0
            if scriptedWater < 9999 then return 0 end
        end
    end
    return math.max(0, source:getFluidAmount())
end

function VLS.canAcceptNormalizedWater(target, amount)
    if not target or amount <= 0 then return false end
    local preview = FluidContainer.CreateContainer()
    preview:setCapacity(amount)
    preview:addFluid(Fluid.Water, amount)
    local accepted = FluidContainer.CanTransfer(preview, target)
    FluidContainer.DisposeContainer(preview)
    return accepted
end

function VLS.getWaterTankFillAmount(vehicle, tank, source)
    local target = tank and tank:getFluidContainer()
    if not target then return 0 end
    local amount = math.max(0, math.min(VLS.getTankWaterSourceAmount(source),
        target:getCapacity() - target:getAmount(),
        VLS.getWaterPurificationCapacity(vehicle)))
    return VLS.canAcceptNormalizedWater(target, amount) and amount or 0
end

-- Preserve the script-defined GasTank center and vehicle-local orientation.
-- Script areas are only 0.4725 tiles wide on the supported vehicles, so a
-- percentage-only expansion adds less than a tenth of a tile per edge. Keep
-- the original area valid, then provide a minimum outward interaction band for
-- the water entry. The original vehicle area is never mutated.
function VLS.isPlayerAtWaterTankInlet(vehicle, part, playerObj)
    if not vehicle or not part or not playerObj or not part:getArea() then
        return false
    end
    -- Compare loaded grid floors, not the vehicle's floating physics height:
    -- suspension/bounce can put the vehicle origin slightly below ground level.
    local playerSquare = playerObj:getSquare()
    local vehicleSquare = vehicle:getSquare()
    if not playerSquare or not vehicleSquare
            or playerSquare:getZ() ~= vehicleSquare:getZ() then
        return false
    end
    local areaId = part:getArea()
    if vehicle:isInArea(areaId, playerObj) then return true end

    local script = vehicle:getScript()
    local area = script and script:getAreaById(areaId) or nil
    if not area or not Vector3f then return false end
    local localPos = vehicle:getLocalPos(playerObj:getX(), playerObj:getY(),
        vehicle:getZ(), Vector3f.new())
    if not localPos then return false end

    local halfW = math.max(area:getW() * VLS.WATER_TANK_PLAYER_AREA_SCALE / 2,
        VLS.WATER_TANK_PLAYER_MIN_HALF_EXTENT)
    local halfH = math.max(area:getH() * VLS.WATER_TANK_PLAYER_AREA_SCALE / 2,
        VLS.WATER_TANK_PLAYER_MIN_HALF_EXTENT)
    local insideBand = localPos:x() >= area:getX() - halfW
        and localPos:x() < area:getX() + halfW
        and localPos:z() >= area:getY() - halfH
        and localPos:z() < area:getY() + halfH
    if not insideBand then return false end

    -- Only expand away from the vehicle centre. This keeps the inlet-side
    -- requirement while allowing the player to stand a little farther out.
    local offsetX = localPos:x() - area:getX()
    local offsetY = localPos:z() - area:getY()
    return offsetX * area:getX() + offsetY * area:getY() >= 0
end

-- Keep one shared source-side gate for the menu, timed action, and server.
-- The source must be close to the GasTank inlet and on the inlet-facing side
-- of the vehicle; player positioning uses the separate outward inlet band.
function VLS.isWaterSourceNearTank(vehicle, part, source)
    if not vehicle or not part or not source or not source.getSquare then
        return false
    end
    local center = vehicle:getAreaCenter(part:getArea())
    local square = source:getSquare()
    if not center or not square then return false end
    local range = VLS.WATER_TANK_SOURCE_RANGE
    local inletX, inletY = center:getX(), center:getY()
    local cx, cy = math.floor(inletX), math.floor(inletY)
    local cz = math.floor(vehicle:getZ())
    if square:getZ() ~= cz
            or math.abs(square:getX() - cx) > range
            or math.abs(square:getY() - cy) > range then
        return false
    end

    local outwardX, outwardY = inletX - vehicle:getX(), inletY - vehicle:getY()
    local outwardLengthSquared = outwardX * outwardX + outwardY * outwardY
    if outwardLengthSquared < 0.0001 then return false end

    local sourceX = square:getX() + 0.5
    local sourceY = square:getY() + 0.5
    return (sourceX - inletX) * outwardX
        + (sourceY - inletY) * outwardY >= -0.0001
end

local function addWaterTankFluidComponent(item, capacity)
    if not item then return nil end
    local fluid = item:getFluidContainer()
    if not fluid and GameEntityFactory and ComponentType then
        fluid = ComponentType.FluidContainer:CreateComponent()
        fluid:setCapacity(capacity)
        GameEntityFactory.AddComponent(item, true, fluid)
        fluid = item:getFluidContainer()
    end
    if fluid then
        fluid:setCapacity(capacity)
        if fluid:getAmount() > capacity then fluid:adjustAmount(capacity) end
    end
    return fluid
end

function VLS.syncVehicleWaterTank(vehicle, part)
    if not VLS.isWaterTankPart(part) or part:getVehicle() ~= vehicle then
        return nil
    end
    local item = part:getInventoryItem()
    if not item or not VLS.LARGE_VAN_WATER_TANK_ITEMS[item:getFullType()] then
        return nil
    end
    local fluid = addWaterTankFluidComponent(item, part:getContainerCapacity())
    if not fluid then return nil end
    part:setContainerContentAmount(fluid:getAmount())
    if item.syncItemFields then item:syncItemFields() end
    return item, fluid
end

function VLS.Create.VehicleWaterTank(vehicle, part)
    if not part:getInventoryItem() and VLS.isInstallationEnabled(part)
            and VehicleUtils and VehicleUtils.createPartInventoryItem then
        VehicleUtils.createPartInventoryItem(part)
        part:setContainerContentAmount(0)
    end
    VLS.syncVehicleWaterTank(vehicle, part)
end

function VLS.Update.VehicleWaterTank(vehicle, part)
    VLS.syncVehicleWaterTank(vehicle, part)
end

function VLS.PartComplete.VehicleWaterTankInstalled(vehicle, part)
    part:setContainerContentAmount(0)
    VLS.syncVehicleWaterTank(vehicle, part)
end

function VLS.PartComplete.VehicleWaterTankUninstalled(vehicle, part, item)
    if item and item:getFluidContainer() and GameEntityFactory then
        GameEntityFactory.RemoveComponentType(item, ComponentType.FluidContainer)
        if item.syncItemFields then item:syncItemFields() end
    end
    part:setContainerContentAmount(0)
    vehicle:transmitPartModData(part)
end

local function setContainerEnvironment(container, temperature, ageFactor,
        processItems, force)
    if not container then return false end
    local changed = force == true
    if math.abs(container:getCustomTemperature() - temperature) > 0.000001 then
        container:setCustomTemperature(temperature)
        changed = true
    end
    if math.abs(container:getAgeFactor() - ageFactor) > 0.000001 then
        container:setAgeFactor(ageFactor)
        changed = true
    end
    if changed and processItems then container:addItemsToProcessItems() end
    return changed
end

local function refreshOneApplianceEnvironment(vehicle, part, force, slotsSynced)
    local partId = part:getId()
    local anyChanged = false
    local partForce = force == true
    if not slotsSynced then
        if VLS.syncUniversalSlot(part) then partForce = true end
        if VLS.syncFreezerSlot(vehicle, partId) then partForce = true end
    end
    local container = part:getItemContainer()
    local capability = VLS.getEquipmentCapability(part:getInventoryItem())
    local required = 0.0001
    if capability == "cooking" and part:getModData().vlsMicrowaveActive then
        required = VLS.getMicrowaveDrainPerMinute()
    elseif capability == "cooling" then
        required = VLS.getFridgeDrainPerMinute()
    end
    local powered = VLS.hasAuxBatteryPower(vehicle, required)
    if capability == "cooking" then
        local data = part:getModData()
        if data.vlsMicrowaveActive and powered then
            local temperature = math.max(50, math.min(130,
                data.vlsMicrowaveTemperature or 90))
            if setContainerEnvironment(container,
                    1.0 + temperature / 100, 1.0, true, partForce) then
                anyChanged = true
            end
        else
            if setContainerEnvironment(container, 1.0, 1.0,
                    false, partForce) then anyChanged = true end
        end
    elseif capability == "cooling" then
        if setContainerEnvironment(container,
                powered and 0.2 or 1.0,
                powered and VLS.getFridgeAgeFactor() or 1.0,
                powered, partForce) then anyChanged = true end
        local freezer = VLS.getFreezerPartForUniversal(vehicle, partId)
        local freezerContainer = freezer and freezer:getItemContainer()
        if freezerContainer then
            if setContainerEnvironment(freezerContainer,
                    powered and 0.1 or 1.0,
                    powered and 0.0 or 1.0,
                    powered, partForce) then anyChanged = true end
        end
    else
        if setContainerEnvironment(container, 1.0, 1.0,
                false, partForce) then anyChanged = true end
        local freezer = VLS.getFreezerPartForUniversal(vehicle, partId)
        local freezerContainer = freezer and freezer:getItemContainer()
        if freezerContainer then
            if setContainerEnvironment(freezerContainer, 1.0, 1.0,
                    false, partForce) then anyChanged = true end
        end
    end
    return anyChanged
end

function VLS.refreshApplianceEnvironment(vehicle, onlyPart, force, slotsSynced)
    local profile = VLS.getVehicleProfile(vehicle)
    if not profile then return false end
    if onlyPart then
        if onlyPart:getVehicle() ~= vehicle then return false end
        -- Validate profile membership without looking up every sibling part.
        for _, partId in ipairs(profile.universalParts) do
            if partId == onlyPart:getId() then
                if vehicle:getPartById(partId) ~= onlyPart then return false end
                return refreshOneApplianceEnvironment(
                    vehicle, onlyPart, force, slotsSynced)
            end
        end
        return false
    end
    local anyChanged = false
    for _, partId in ipairs(profile.universalParts) do
        local part = vehicle:getPartById(partId)
        if part and refreshOneApplianceEnvironment(vehicle, part, force, false) then
            anyChanged = true
        end
    end
    return anyChanged
end

function VLS.canUninstallManagedPart(part)
    if not part or not VLS.isManagedPart(part) then return true end
    local vehicle = part:getVehicle()

    if VLS.isUniversalPart(part) then
        local capability = VLS.getEquipmentCapability(part:getInventoryItem())
        if capability == "cooking" and part:getModData().vlsMicrowaveActive then
            return false
        end
        if capability == "laundryCombo"
                and part:getModData().vlsLaundryActive then
            return false
        end
        if capability == "cooling" then
            local freezer = VLS.getFreezerPartForUniversal(vehicle, part:getId())
            if freezer and freezer:getContainerContentAmount() > 0 then
                return false
            end
        end
        if capability == "bed" then
            local seat = VLS.getBedSeat(vehicle, part)
            if seat >= 0 and vehicle:getCharacter(seat) then return false end
        end
    elseif part:getId() == VLS.AUX_BATTERY_PART_ID then
        for _, microwave in ipairs(VLS.getInstalledCapabilityParts(vehicle,
                "cooking")) do
            if microwave:getModData().vlsMicrowaveActive then return false end
        end
    end
    return true
end

function VLS.UninstallTest.UniversalSlot(vehicle, part, character)
    if not VLS.canUninstallManagedPart(part) then return false end
    return Vehicles.UninstallTest.Default(vehicle, part, character)
end

VLS.ContainerAccess = VLS.ContainerAccess or {}

function VLS.ContainerAccess.UniversalSlot(vehicle, part, character)
    if not part or not VLS.isStorageEquipment(part:getInventoryItem()) then return false end
    if not character or character:getVehicle() ~= vehicle then return false end
    if not vehicle or part:getVehicle() ~= vehicle
            or vehicle:getPartById(part:getId()) ~= part
            or not VLS.isUniversalPart(part) then
        return false
    end
    VLS.ensureUniversalContainerProfile(part)
    return true
end

function VLS.ContainerAccess.WeaponLocker(vehicle, part, character)
    VLS.syncWeaponLocker(part)
    if not part or not VLS.isAllowedItem(part, part:getInventoryItem()) then return false end
    local truckBed = vehicle and vehicle:getPartById("TruckBed")
    return truckBed ~= nil
        and character ~= nil
        and vehicle:canAccessContainer(truckBed:getIndex(), character)
end

function VLS.ContainerAccess.UniversalFreezer(vehicle, part, character)
    local universalId = part and VLS.UNIVERSAL_PART_BY_FREEZER[part:getId()]
    local fridge = universalId and VLS.getInstalledPart(vehicle, universalId)
    if not fridge
            or VLS.getEquipmentCapability(fridge:getInventoryItem()) ~= "cooling" then
        return false
    end
    return character ~= nil and character:getVehicle() == vehicle
end


-- Revalidate queued/running AnySurfaceCraft actions that use a VLS vehicle as
-- their real IsoObject. Leaving the vehicle or removing the final approved
-- cabinet prevents the queued action from producing output or consuming input.
VLS.genericCraftSurfaceActionHooks =
    VLS.genericCraftSurfaceActionHooks or {}

function VLS.installGenericCraftSurfaceActionHooks()
    local hooks = VLS.genericCraftSurfaceActionHooks

    local function isVLSVehicleSurfaceAction(action)
        return action ~= nil
            and action.craftRecipe ~= nil
            and action.craftRecipe:isAnySurfaceCraft()
            and action.isoObject ~= nil
            and instanceof(action.isoObject, "BaseVehicle")
            and VLS.isSupportedVehicle(action.isoObject)
    end

    local function isStillValid(action)
        if not isVLSVehicleSurfaceAction(action) then return true end
        return VLS.canUseVehicleGenericCraftSurface(
            action.character, action.isoObject)
    end

    if ISHandcraftAction
            and ISHandcraftAction.isValid
            and ISHandcraftAction.isValid ~= hooks.isValidWrapper then
        local previousIsValid = ISHandcraftAction.isValid

        hooks.isValidWrapper = function(self)
            if not isStillValid(self) then return false end
            return previousIsValid(self)
        end

        ISHandcraftAction.isValid = hooks.isValidWrapper
    end

    if ISHandcraftAction
            and ISHandcraftAction.performRecipe
            and ISHandcraftAction.performRecipe
                ~= hooks.performRecipeWrapper then
        local previousPerformRecipe = ISHandcraftAction.performRecipe

        hooks.performRecipeWrapper = function(self)
            if not isStillValid(self) then return end
            return previousPerformRecipe(self)
        end

        ISHandcraftAction.performRecipe = hooks.performRecipeWrapper
    end
end

VLS.installGenericCraftSurfaceActionHooks()

-- BEGIN VLS_NATIVE_CARGO_3811
-- Hook the original inside-access callback, not a list of vehicle names.
-- Vehicle scripts keep their existing container.test; outside-only cargo stays
-- outside-only. No script Load/rebinding, real seat count, or item mutation.
require "Vehicles/Vehicles"
VLS.CargoR6 = VLS.CargoR6 or {}
local CargoR6 = VLS.CargoR6
CargoR6.BUILD = "native-cargo-3.8.11-20260922"
CargoR6.calls = CargoR6.calls or setmetatable({}, {__mode = "k"})
CargoR6.states = CargoR6.states or setmetatable({}, {__mode = "k"})
CargoR6.logged = CargoR6.logged or {}

function CargoR6.logOnce(key, message)
    if CargoR6.logged[key] == message then return end
    CargoR6.logged[key] = message
    print("[VLS Cargo 3.8.11] " .. message)
end

function CargoR6.directory()
    local ok, result = pcall(function()
        local info = getModInfoByID and getModInfoByID("VehicleLivingSlots")
        return info and info:getDir() or "unresolved"
    end)
    return ok and tostring(result) or "unresolved"
end

function CargoR6.applies(vehicle)
    local profile = vehicle and VLS.getVehicleProfile(vehicle)
    return profile ~= nil and profile.spacePassengers ~= nil
        and #profile.spacePassengers > 0
end

function CargoR6.layout(vehicle)
    local raw = vehicle:getMaxPassengers()
    if not CargoR6.applies(vehicle) then return raw, raw, 0 end
    local script = vehicle:getScript()
    if not script or raw ~= script:getPassengerCount() then return raw, raw, 0 end
    local physical, added = 0, 0
    for seat = 0, raw - 1 do
        if VLS.getSpaceAssignmentForSeat(vehicle, seat) then
            added = added + 1
        else
            physical = physical + 1
        end
    end
    return raw, physical, added
end

function CargoR6.passengerCount(vehicle, character)
    local raw, physical, added = CargoR6.layout(vehicle)
    if physical < 1 or added == 0 or not character
            or character:getVehicle() ~= vehicle then return raw end
    local seat = vehicle:getSeat(character)
    if type(seat) ~= "number" or seat < 0 or seat >= raw
            or seat ~= math.floor(seat) then return raw end
    if VLS.getSpaceAssignmentForSeat(vehicle, seat)
            and not VLS.getInstalledBedPartForSeat(vehicle, seat) then return raw end
    return physical
end

-- Query-only adapters also used by the unchanged seat-routing/moving fix.
-- Rebind Java methods to their real receiver; unwrap view arguments at the
-- Java boundary. Never change global Java methods or real script objects.
function CargoR6.queryViews()
    local realByView = {}
    local function unwrap(value) return realByView[value] or value end
    local function view(real, overrides)
        local proxy, methods = {}, {}
        realByView[proxy] = real
        return setmetatable(proxy, {
            __index = function(_, key)
                if overrides and overrides[key] ~= nil then return overrides[key] end
                if methods[key] then return methods[key] end
                if type(key) ~= "string" or not (key:match("^get")
                        or key:match("^is") or key:match("^has")
                        or key:match("^can")) then
                    error("VLS query view refuses non-query member: " .. tostring(key), 2)
                end
                local method = real[key]
                if method == nil then return nil end
                local bound = function(_, ...)
                    local n, args = select("#", ...), {...}
                    for i = 1, n do args[i] = unwrap(args[i]) end
                    return method(real, unpack(args, 1, n))
                end
                methods[key] = bound
                return bound
            end,
            __newindex = function() error("VLS query view is read-only", 2) end,
        })
    end
    return view
end

function CargoR6.nativeInside(native, vehicle, part, character)
    if not vehicle or not character or not CargoR6.applies(vehicle) then
        return native(vehicle, part, character)
    end
    CargoR6.calls[vehicle] = (CargoR6.calls[vehicle] or 0) + 1
    -- Native code owns exterior access, doors, ranges and non-VLS containers.
    if character:getVehicle() ~= vehicle or not part
            or part:getVehicle() ~= vehicle
            or vehicle:getPartById(part:getId()) ~= part then
        return native(vehicle, part, character)
    end
    local raw = vehicle:getMaxPassengers()
    local count = CargoR6.passengerCount(vehicle, character)
    if count == raw then return native(vehicle, part, character) end
    local seat = vehicle:getSeat(character)
    local living = VLS.getSpaceAssignmentForSeat(vehicle, seat) ~= nil
    local areaOverride = nil
    local view = CargoR6.queryViews()
    local vehicleView = view(vehicle, {
        getMaxPassengers = function() return count end,
        getPassengerArea = function(_, index)
            if index == seat and areaOverride ~= nil then return areaOverride end
            return vehicle:getPassengerArea(index)
        end,
    })
    local characterView = view(character, {
        getVehicle = function()
            local actual = character:getVehicle()
            return actual == vehicle and vehicleView or actual
        end,
    })
    -- Every original seat keeps its actual index and area. In particular a
    -- four-seat SUV/PickUpVan never masquerades as a two-seat cargo van.
    local result = native(vehicleView, part, characterView)
    if result or not living then return result end
    -- A legitimate bed in the cargo area uses an EXISTING original passenger
    -- area's inside-access semantics. Ask the original function; do not invent
    -- a SeatRear string or grant access when the original denies every area.
    -- getSeat, real position, installed parts and all real state remain intact.
    for original = 0, raw - 1 do
        if not VLS.getSpaceAssignmentForSeat(vehicle, original) then
            areaOverride = vehicle:getPassengerArea(original)
            if areaOverride ~= nil then
                result = native(vehicleView, part, characterView)
                if result then return result end
            end
        end
    end
    return result
end

function CargoR6.installNativeHook()
    local access = Vehicles and Vehicles.ContainerAccess
    if not access or not access.TruckBedOpenInside then return false end
    -- Install during shared loading, before world container queries are cached.
    -- A later wrapper in the same table is not wrapped repeatedly or replaced.
    if CargoR6.nativeTable == access then return true end
    local native = access.TruckBedOpenInside
    local wrapper = function(vehicle, part, character)
        return CargoR6.nativeInside(native, vehicle, part, character)
    end
    CargoR6.nativeTable, CargoR6.nativeWrapper = access, wrapper
    access.TruckBedOpenInside = wrapper
    CargoR6.logOnce("nativeHook", "NATIVE_CALLBACK_WRAPPED name=TruckBedOpenInside"
        .. " scripts_rebound=0 model_whitelist=none")
    return true
end

function CargoR6.probe(vehicle, character)
    if not CargoR6.applies(vehicle) or not character then return nil end
    local part = vehicle:getPartById("TruckBed")
    if not part or not part:getItemContainer() then return nil end
    local state = CargoR6.states[vehicle]
    if not state then state = {}; CargoR6.states[vehicle] = state end
    local before = CargoR6.calls[vehicle] or 0
    local ok, value = pcall(function()
        return vehicle:canAccessContainer(part:getIndex(), character)
    end)
    state.ok, state.value = ok, value
    state.reached = (CargoR6.calls[vehicle] or 0) > before
    state.raw, state.physical, state.added = CargoR6.layout(vehicle)
    state.part = part
    -- Diagnostic only: false may be the correct original outside-only policy.
    -- Never rewrite a vehicle script to make this probe reach our callback.
    return state
end

CargoR6.installNativeHook()
if not CargoR6.nativeEventsRegistered then
    CargoR6.nativeEventsRegistered = true
    for _, eventName in ipairs({"OnGameBoot", "OnInitGlobalModData",
            "OnInitWorld", "OnServerStarted"}) do
        local event = Events and Events[eventName]
        if event and event.Add then event.Add(CargoR6.installNativeHook) end
    end
end
CargoR6.logOnce("sharedLoaded", "SHARED_LOADED build=" .. CargoR6.BUILD
    .. " baseDir=" .. CargoR6.directory())
-- END VLS_NATIVE_CARGO_3811

-- BEGIN VLS_SEAT_R6_SHARED_20260922
VLS.SeatR6 = VLS.SeatR6 or {}
local SeatR6 = VLS.SeatR6
SeatR6.targets = {}
for _, names in ipairs({VLS.smallVehicleScriptNames or {},
        VLS.mediumVanScriptNames or {}, VLS.stepVanScriptNames or {}}) do
    for _, name in ipairs(names) do SeatR6.targets["Base." .. name] = true end
end
function SeatR6.applies(vehicle)
    local script = vehicle and vehicle:getScript()
    return script ~= nil and SeatR6.targets[script:getFullName()] == true
        and VLS.isSupportedVehicle(vehicle)
end
function SeatR6.validSeat(vehicle, seat)
    return vehicle ~= nil and type(seat) == "number"
        and seat == math.floor(seat) and seat >= 0
        and seat < vehicle:getMaxPassengers()
end
function SeatR6.mayOccupy(vehicle, seat)
    if not SeatR6.applies(vehicle) then return true end
    if not SeatR6.validSeat(vehicle, seat) then return false end
    return VLS.getSpaceAssignmentForSeat(vehicle, seat) == nil
        or VLS.getInstalledBedPartForSeat(vehicle, seat) ~= nil
end
-- END VLS_SEAT_R6_SHARED_20260922


return VLS
