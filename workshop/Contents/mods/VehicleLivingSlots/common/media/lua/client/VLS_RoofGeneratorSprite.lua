-- Retired sprite adapter. Keep this filename in the existing eight-file upgrade
-- contract so an upgrade replaces old drawing code without orphaned callbacks.
if isServer() then return end
local previous = VLSRoofGeneratorSprite
if previous then
    if previous.render then Events.OnPostRender.Remove(previous.render) end
    if previous.reset then Events.OnGameStart.Remove(previous.reset) end
end
VLSRoofGeneratorSprite = nil
print("[VLS Roof Cargo 0.13-cargo.2] native 3D part models; sprite renderer retired")
