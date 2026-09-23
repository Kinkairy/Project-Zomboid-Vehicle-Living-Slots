local P = require "VLS_Pantry"
require "VLS_PantryMenu"
require "Vehicles/ISUI/ISVehicleMechanics"

-- Reorder the existing native row; no new category, panel or schematic cells.
-- Preserve row identity and native selection/hover indices.
function P.orderMechanicsRows(panel, list)
    if not list or not list.items then return end
    local selected = list.items[list.selected or -1]
    local hovered = list.items[list.mouseoverselected or -1]
    local saved = list.items[panel.leftListSelection or -1]
    local pantry, weapon
    for i, row in ipairs(list.items) do
        local part = row.item and row.item.part
        if part and part:getId() == P.PART_ID then pantry = i end
        if part and part:getId() == "VLSWeaponCabinetSlot" then weapon = i end
    end
    if not pantry or not weapon then return end
    local row = table.remove(list.items, pantry)
    if pantry < weapon then weapon = weapon - 1 end
    table.insert(list.items, weapon, row)
    for i, item in ipairs(list.items) do
        item.itemindex, item.index = i, i
        if item == selected then list.selected = i end
        if item == hovered then list.mouseoverselected = i end
        if item == saved then panel.leftListSelection = i end
    end
end

if not P.mechanicsRowsHookApplied then
    P.mechanicsRowsHookApplied = true
    local nativeInit = ISVehicleMechanics.initParts
    function ISVehicleMechanics:initParts(...)
        local result = nativeInit(self, ...)
        if self.vehicle and VLS.isSupportedVehicle(self.vehicle) then
            P.orderMechanicsRows(self, self.listbox)
        end
        return result
    end
end
