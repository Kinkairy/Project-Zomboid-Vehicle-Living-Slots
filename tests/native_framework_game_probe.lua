-- Optional read-only metadata/constructor probe for the designated 42.21 test
-- environment. Call VLSNativeFrameworkProbe.inspect(installedMoveableItem).
-- Does not install/remove furniture, edit a save, start a recipe, or deploy code.
VLSNativeFrameworkProbe = {}
function VLSNativeFrameworkProbe.inspect(item)
    local Definition = require 'VLS_NativeDefinition'
    Definition.clearCache()
    local definition, reason = Definition.cabinet(item)
    if not definition then return { passed = false, reason = reason } end
    return {
        passed = true,
        sourceSprite = definition.sourceSprite,
        capacity = definition.capacity,
        containerType = definition.containerType,
        genericCraftSurface = definition.genericCraftSurface,
        nativeContainerMetadataOnly = true,
        worldLifecycleProven = false,
        multiplayerProven = false,
    }
end
return VLSNativeFrameworkProbe
