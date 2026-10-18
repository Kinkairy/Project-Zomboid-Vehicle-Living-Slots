-- Real VLS_RoofLights.lua with mocked 42.21 VehiclePart/VehicleLight semantics:
-- installed roof lamps share one native light. No rendered-light claim.
local root = assert(arg[1])
local subject = root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/VLS_RoofLights.lua"
local harness = dofile(root.."/tests/roof_light_sharing_harness.lua")
local cases = 0
harness(nil, function() dofile(subject) end, function(line) cases = cases + 1; print("PASS "..line) end)
assert(cases == 10, "expected 10 roof-light sharing cases, ran "..cases)
print("RESULT roof-light sharing cases="..cases.." failures=0")
