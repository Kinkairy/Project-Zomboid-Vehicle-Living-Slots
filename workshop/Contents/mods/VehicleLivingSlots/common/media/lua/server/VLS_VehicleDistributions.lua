require "Vehicles/VehicleDistributions"
require "VLS_Config"

local function copy(source)
    local result={}
    for key,value in pairs(source) do result[key]=value end
    return result
end
local function emptySlots(distribution,profile)
    if type(distribution)~="table" then return distribution end
    local result=copy(distribution)
    for _,id in ipairs(profile.universalParts or {}) do
        result[id]=VehicleDistributions.EmptySeat
        local freezer=VLS.FREEZER_PART_BY_UNIVERSAL[id]
        if freezer then result[freezer]=VehicleDistributions.EmptySeat end
    end
    if profile.kind=="mediumVan" or profile.kind=="largeVan" then
        result[VLS.WEAPON_PART_ID]=VehicleDistributions.EmptySeat
    end
    return result
end
if VehicleDistributions and VehicleDistributions.EmptySeat then
    for _,mapping in ipairs(VehicleDistributions) do
        for scriptName,profile in pairs(VLS.vehicleProfiles) do
            local name=scriptName:gsub("^Base%.","")
            local selection=mapping[name]
            if type(selection)=="table" then
                local isolated=copy(selection)
                isolated.Normal=emptySlots(selection.Normal,profile)
                if selection.Specific then
                    isolated.Specific={}
                    for i,distribution in ipairs(selection.Specific) do
                        isolated.Specific[i]=emptySlots(distribution,profile)
                    end
                end
                mapping[name]=isolated
            end
        end
    end
end
