require "Vehicles/VehicleDistributions"
require "VLS_Config"

local emptySeat = VehicleDistributions and VehicleDistributions.EmptySeat
if emptySeat then
    for _, distribution in pairs(VehicleDistributions) do
        if type(distribution) == "table"
                and (distribution.TruckBed or distribution.GloveBox or distribution.SeatFrontLeft) then
            distribution.SeatBed = emptySeat
            distribution.VLSUniversalFreezer = emptySeat
            distribution.VLSLargeVanSlot2 = emptySeat
            distribution.VLSLargeVanSlot3 = emptySeat
            distribution.VLSLargeVanFreezer2 = emptySeat
            distribution.VLSLargeVanFreezer3 = emptySeat
            distribution.VLSLargeVanSlot4 = emptySeat
            distribution.VLSLargeVanSlot5 = emptySeat
            distribution.VLSLargeVanFreezer4 = emptySeat
            distribution.VLSLargeVanFreezer5 = emptySeat
            distribution.VLSWeaponCabinetSlot = emptySeat
        end
    end
end
