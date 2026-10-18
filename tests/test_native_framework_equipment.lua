local root=assert(arg[1])
package.path=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/?.lua;'..package.path
local item={getID=function()return 11 end,capability='cooking'}
local data={vlsNativeEpoch=2}
local vehicle={getId=function()return 7 end}
local part={getVehicle=function()return vehicle end,getInventoryItem=function()return item end,
 getModData=function()return data end,getItemContainer=function()return 'same cargo' end}
vehicle.getPartById=function(_,id)return id=='Slot' and part or nil end
local player={getVehicle=function()return vehicle end}
VLS={isSupportedVehicle=function(v)return v==vehicle end,isManagedPart=function(p)return p==part end,
 getEquipmentCapability=function(i)return i.capability end}
local C=require 'VLS_NativeContext'
local c=assert(C.equipment(player,vehicle,'Slot',11,'cooking',2))
assert(c.item==item and c.part==part and c.container=='same cargo')
assert(not C.equipment(player,vehicle,'Slot',11,'laundryCombo',2))
assert(not C.equipment(player,vehicle,'Slot',12,'cooking',2))
assert(not C.equipment(player,vehicle,'Slot',11,'cooking',1))
assert(not C.equipment({getVehicle=function()return {}end},vehicle,'Slot',11,'cooking',2))
assert(not C.equipment(player,vehicle,'Other',11,'cooking',2))
data.vlsNativeEpoch=3;assert(not C.equipment(player,vehicle,'Slot',11,'cooking',2))
assert(C.equipment(player,vehicle,'Slot',11,'cooking',3))
print('PASS equipment entry shares identity/access/capability; same cargo retained; stale installation refused (mock only)')
