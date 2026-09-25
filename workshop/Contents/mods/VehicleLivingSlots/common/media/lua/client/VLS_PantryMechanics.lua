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
    -- Group paired native construction/storage rows in slot order, before living rows.
    local reordered=false
    local start=1
    while start<=#list.items do
        if list.items[start].item and list.items[start].item.cat then start=start+1 end
        local finish=start
        while finish<=#list.items and not (list.items[finish].item and list.items[finish].item.cat) do finish=finish+1 end
        local cursor=start
        for slot=1,3 do
            for _,id in ipairs({"VLSTopFrame"..slot,VLS.OVERHEAD_PART_IDS[slot]}) do
                for i=cursor,finish-1 do
                    local part=list.items[i].item and list.items[i].item.part
                    if part and part:getId()==id then
                        if i~=cursor then table.insert(list.items,cursor,table.remove(list.items,i));reordered=true end
                        cursor=cursor+1;break
                    end
                end
            end
        end
        start=finish
    end
    if not reordered then return end
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
