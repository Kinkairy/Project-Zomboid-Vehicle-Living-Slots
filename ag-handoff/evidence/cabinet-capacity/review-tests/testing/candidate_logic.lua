-- Design candidate used only by offline tests; NOT installed as a game patch.
-- Runtime lifecycle order and transfer gate order must still be checked in PZ.
ReviewCandidate={}
function ReviewCandidate.Init(vehicle,part)
    if not vehicle or not part or part:getVehicle()~=vehicle
            or vehicle:getPartById(part:getId())~=part or not VLS.isUniversalPart(part) then return end
    if VLS.Damage and VLS.Damage.Init then VLS.Damage.Init(vehicle) end
    -- Crucially this is outside Damage.Init's per-vehicle cache/early return.
    VLS.ensureUniversalContainerProfile(part)
end
function ReviewCandidate.Access(vehicle,part,character)
    if not VLS.ContainerAccess.UniversalSlot(vehicle,part,character) then return false end
    if not vehicle or part:getVehicle()~=vehicle
            or vehicle:getPartById(part:getId())~=part or not VLS.isUniversalPart(part) then return false end
    -- Do not reset appliance timers via syncUniversalSlot merely to repair profile.
    VLS.ensureUniversalContainerProfile(part)
    return true
end
