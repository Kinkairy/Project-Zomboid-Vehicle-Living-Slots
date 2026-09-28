local A = require "VLS_KI5F700_Config"
require "VLS_KI5F700_Frames"
require "VLS_KI5F700_Power"
local S = require "VLS_KI5F700_Seats"
local P = require "VLS_Pantry"
require "VLS_PantryMechanics"
require "VLS_VehicleMechanicsIcons"
if A.mechanicsApplied then return A end
A.mechanicsApplied = true
-- PantryMenu owns this registry; add only this module's unique fourth station.
P.stationOrder[#P.stationOrder + 1] = A.overhead[4]

-- Core 3.9's private renderer recognizes suffixes 1..3. Keep that function
-- unchanged; the registered display provider and this module own pair #4.
local frameId, cupboardId = A.frames[4], A.overhead[4]
local function fourth(part)
    return part and A.matches(part:getVehicle())
        and (part:getId() == frameId or part:getId() == cupboardId)
end
VLS.registerMechanicsUIProvider("ki5F700FourthFrame", {
    matches=function(part) return part and part:getId() == frameId and A.matches(part:getVehicle()) end,
    name=function() return getText("IGUI_VehiclePartVLSTopFrame4") end,
})
VLS.registerMechanicsUIProvider("ki5F700NativeSeat", {
    matches=function(part) local pair=S.pair(part);return pair and part:getId()==pair.seat or false end,
    name=function(part) return getText(S.pair(part).nameKey) end,
})
-- Provider registration opts these original KI5 parts into the core's
-- normalized item-condition display (condition / conditionMax * 100).
VLS.registerMechanicsUIProvider("ki5F700BusRoof", {
    matches=function(part)
        if not part or not A.isBus(part:getVehicle()) then return false end
        local id=part:getId()
        return id=="DAMNGasCanOne" or id=="DAMNGasCanTwo" or id=="DAMNGenerator"
    end,
})
VLS.registerMechanicsUIProvider("ki5F700BusBattery3", {
    matches=function(part) return part and part:getId()==A.battery3Id and A.isBus(part:getVehicle()) end,
    remaining=function(part) return part:getInventoryItem():getCurrentUsesFloat() end,
})
local function reindex(panel, list, field, selected, hovered, saved)
    local indices = {}
    for i, row in ipairs(list.items) do row.itemindex, row.index = i, i; indices[row] = i end
    list.count = #list.items
    if selected then list.selected = indices[selected] or -1 end
    if hovered then list.mouseoverselected = indices[hovered] or -1 end
    if saved then panel[field] = indices[saved] or -1 end
end
-- One visible row per rear position, backed by the two existing real parts.
-- Cache both native rows so a completed action swaps presentation without
-- changing part IDs, inventory objects, containers or the saved vehicle.
function A.refreshSeatRows(panel, list, field)
    local profile=VLS.getVehicleProfile(panel.vehicle)
    if not list or not list.items or not profile or #(profile.seatPairs or {})==0 then return end
    local cache=list.vlsF700SeatRows or {};list.vlsF700SeatRows=cache
    local selected,hovered,saved=list.items[list.selected or -1],
        list.items[list.mouseoverselected or -1],list.items[panel[field] or -1]
    for _,row in ipairs(list.items) do
        local part=row.item and row.item.part
        if S.pair(part) then cache[part:getId()]=row end
    end
    local replacements={}
    for _,pair in ipairs(profile.seatPairs) do
        local seat=panel.vehicle:getPartById(pair.seat)
        local chosen=cache[seat and seat:getInventoryItem() and pair.seat or pair.living]
        if chosen then
            chosen.item.name=VLS.getMechanicsPartName(chosen.item.part)
            if cache[pair.seat] then replacements[cache[pair.seat]]=chosen end
            if cache[pair.living] then replacements[cache[pair.living]]=chosen end
        end
    end
    local seen={}
    for i=#list.items,1,-1 do
        local row=list.items[i]
        local replacement=replacements[row]
        if replacement then
            if seen[replacement] then table.remove(list.items,i)
            else list.items[i]=replacement;seen[replacement]=true end
        end
    end
    reindex(panel,list,field,replacements[selected] or selected,
        replacements[hovered] or hovered,replacements[saved] or saved)
end

-- Empty paired spaces offer the native seat alongside living equipment. Every
-- tooltip and action targets the REAL seat part, retaining native requirements
-- and the existing server-side mutual-exclusion/last-moment item guards.
local baseMenu=ISVehicleMechanics.doPartContextMenu
function ISVehicleMechanics:doPartContextMenu(part,...)
    local pair=S.pair(part)
    local previous=self.context
    if pair then self.context=nil end
    local result=baseMenu(self,part,...)
    if pair and not self.context then self.context=previous;return result end
    if not pair or part:getId()~=pair.living or part:getInventoryItem() then return result end
    local seat=part:getVehicle():getPartById(pair.seat)
    if not seat or seat:getInventoryItem() or not self.context then return result end
    local install=self.context:getOptionFromName(getText("IGUI_Install"))
    -- No native menu means speed/player restrictions prevented opening it.
    if not install then return result end
    local allowed=ISVehicleMechanics.cheat or seat:getVehicle():canInstallPart(self.chr,seat)
    local menu=install.subOption and self.context:getSubMenu(install.subOption)
    if not menu then
        menu=ISContextMenu:getNew(self.context);self.context:addSubMenu(install,menu)
    end
    local inventory=VehicleUtils.getItems(self.chr:getPlayerNum())
    local types=seat:getItemType()
    for i=0,types:size()-1 do
        local itemType=types:get(i)
        local scriptItem=getItem(itemType)
        local option=menu:addOption(getItemName(itemType),self.chr,nil)
        option.iconTexture=scriptItem and scriptItem:getNormalTexture()
        self:doMenuTooltip(seat,option,"install",itemType)
        local enabled=allowed and S.canInstall(seat,itemType)
        if enabled then install.notAvailable=false end
        option.notAvailable=option.notAvailable or not enabled or not inventory[itemType]
        if inventory[itemType] then
            local items=ISContextMenu:getNew(menu);self.context:addSubMenu(option,items)
            for _,item in ipairs(inventory[itemType]) do
                local entry=items:addOption(item:getDisplayName().." ("..item:getCondition().."%)",
                    self.chr,ISVehiclePartMenu.onInstallPart,seat,item)
                entry.itemForTexture=item
                self:doMenuTooltip(seat,entry,"install",itemType)
                entry.notAvailable=entry.notAvailable or not enabled or not S.canInstall(seat,item)
            end
        end
    end
    return result
end

local function snapshot(panel, list, field)
    if not list or not list.items then return nil end
    local rows = list.vlsF700FourthRows or {}; list.vlsF700FourthRows = rows
    local state = {rows=rows, selected=list.items[list.selected or -1],
        hovered=list.items[list.mouseoverselected or -1], saved=list.items[panel[field] or -1]}
    for i, row in ipairs(list.items) do
        local part=row.item and row.item.part
        if fourth(part) then rows[part:getId()]=row;state.index=state.index or i end
    end
    for _, id in ipairs({frameId,cupboardId}) do
        local row=list.vlsTopRows and list.vlsTopRows[id]
        if row and fourth(row.item.part) then rows[id]=row end
    end
    return state
end
function A.refreshFourth(panel, list, field, before)
    if not A.matches(panel.vehicle) then return end
    local current=snapshot(panel,list,field); if not current then return end
    local state=before or current
    for id,row in pairs(current.rows) do state.rows[id]=row end
    local cupboard=panel.vehicle:getPartById(cupboardId)
    local fitted=VLS.hasTopFrame(cupboard) or (cupboard and cupboard:getInventoryItem())
    local row=state.rows[fitted and cupboardId or frameId]
    if not row then return end
    local index=current.index or state.index
    if not index then return end -- this list does not own the fourth position
    for i=#list.items,1,-1 do
        local part=list.items[i].item and list.items[i].item.part
        if fourth(part) then table.remove(list.items,i) end
    end
    table.insert(list.items,math.min(index,#list.items+1),row)
    row.item.name=VLS.getMechanicsPartName(row.item.part)
    local function replacement(selected)
        return selected and fourth(selected.item and selected.item.part) and row or selected
    end
    reindex(panel,list,field,replacement(state.selected),replacement(state.hovered),replacement(state.saved))
end

-- This optional module orders only its own F700 family. Native
-- categories, unrelated rows and original item/row identities are retained.
function A.orderRows(panel, list)
    if not A.matches(panel.vehicle) or not list or not list.items then return end
    local profile=VLS.getVehicleProfile(panel.vehicle)
    if not profile then return end
    local selected, hovered, saved=list.items[list.selected or -1],
        list.items[list.mouseoverselected or -1],list.items[panel.leftListSelection or -1]
    local ranks, nextRank={},0
    local function add(id) if id and not ranks[id] then nextRank=nextRank+1;ranks[id]=nextRank end end
    local overhead=profile.overheadParts or {}
    for i,id in ipairs(overhead) do add("VLSTopFrame"..i);add(id) end
    local seats={};for _,pair in ipairs(profile.seatPairs or {}) do seats[pair.living]=pair.seat end
    for _,id in ipairs(profile.universalParts or {}) do add(seats[id]);add(id) end
    add(VLS.WEAPON_PART_ID)
    for _,id in ipairs(profile.waterTankParts or {}) do add(id) end
    for _,id in ipairs(profile.auxBatteryParts or {profile.auxBatteryPartId or VLS.AUX_BATTERY_PART_ID}) do add(id) end
    local indices,rows={},{}
    local function flush()
        table.sort(rows,function(a,b) return ranks[a.item.part:getId()]<ranks[b.item.part:getId()] end)
        for i,index in ipairs(indices) do list.items[index]=rows[i] end
        indices,rows={},{}
    end
    for i,row in ipairs(list.items) do
        local part=row.item and row.item.part
        if row.item and row.item.cat then flush()
        elseif part and ranks[part:getId()] then indices[#indices+1]=i;rows[#rows+1]=row end
    end
    flush();reindex(panel,list,"leftListSelection",selected,hovered,saved)
end
-- Native initParts iterates categories with pairs(), so living equipment can
-- precede the engine/fuel groups. Move the complete category after suspension;
-- use part category IDs, not translated headers, and keep the native row objects.
function A.orderCategories(panel,list)
    if not A.matches(panel.vehicle) or not list or not list.items then return end
    local groups,current={},nil
    local living,suspension
    for _,row in ipairs(list.items) do
        if not current or (row.item and row.item.cat) then
            current={};groups[#groups+1]=current
        end
        current[#current+1]=row
        local part=row.item and row.item.part
        if part then
            local category=part:getCategory()
            if category==VLS.CATEGORY_ID then living=current
            elseif category=="suspension" then suspension=current end
        end
    end
    if not living or not suspension or living==suspension then return end
    local selected,hovered,saved=list.items[list.selected or -1],
        list.items[list.mouseoverselected or -1],list.items[panel.leftListSelection or -1]
    for i,group in ipairs(groups) do if group==living then table.remove(groups,i);break end end
    for i,group in ipairs(groups) do if group==suspension then table.insert(groups,i+1,living);break end end
    local index=0
    for _,group in ipairs(groups) do for _,row in ipairs(group) do
        index=index+1;list.items[index]=row
    end end
    reindex(panel,list,"leftListSelection",selected,hovered,saved)
end
local baseOrder=P.orderMechanicsRows
function P.orderMechanicsRows(panel,list)
    baseOrder(panel,list);A.orderRows(panel,list)
end
local function finish(panel,left,right)
    A.refreshFourth(panel,panel.listbox,"leftListSelection",left)
    A.refreshFourth(panel,panel.bodyworklist,"rightListSelection",right)
    A.refreshSeatRows(panel,panel.listbox,"leftListSelection")
    A.refreshSeatRows(panel,panel.bodyworklist,"rightListSelection")
    A.orderRows(panel,panel.listbox)
    A.orderCategories(panel,panel.listbox)
end
local baseInit=ISVehicleMechanics.initParts
function ISVehicleMechanics:initParts(...)
    if self.listbox then self.listbox.vlsF700FourthRows=nil;self.listbox.vlsF700SeatRows=nil end
    if self.bodyworklist then self.bodyworklist.vlsF700FourthRows=nil;self.bodyworklist.vlsF700SeatRows=nil end
    local result=baseInit(self,...)
    if A.matches(self.vehicle) then finish(self) end
    return result
end
local baseRecalculate=ISVehicleMechanics.recalculGeneralCondition
function ISVehicleMechanics:recalculGeneralCondition(...)
    if not A.matches(self.vehicle) then return baseRecalculate(self,...) end
    local left=snapshot(self,self.listbox,"leftListSelection")
    local right=snapshot(self,self.bodyworklist,"rightListSelection")
    local result=baseRecalculate(self,...)
    -- Apply the same 3.9 condition contract to all four local frame positions.
    local count,total=0,0
    for i=0,self.vehicle:getPartCount()-1 do
        local part=self.vehicle:getPartByIndex(i)
        local item=part:getInventoryItem()
        local frame=A.frameIndex(part)
        local overhead=VLS.isOverheadPart(part)
        local pair=S.pair(part)
        local inactive=pair and not item and (part:getId()==pair.living
            or self.vehicle:getPartById(pair.living):getInventoryItem()~=nil)
        local hidden=false
        for _,provider in pairs(VLS.mechanicsUIProviders) do
            if provider.matches(part) and provider.hidden and provider.hidden(part) then hidden=true;break end
        end
        if not (inactive or (hidden and not frame) or ((frame or overhead) and not item)) then
            count=count+1
            local types=part:getItemType()
            total=total+(item and VLS.getDisplayPartCondition(part)
                or (types and not types:isEmpty()) and 0 or part:getCondition())
        end
    end
    if count>0 then self.generalCondition=round(total/count,2);self.generalCondRGB=self:getConditionRGB(self.generalCondition) end
    finish(self,left,right)
    return result
end
return A
