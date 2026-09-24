from pathlib import Path
from lupa.lua51 import LuaRuntime
import sys
n=Path(sys.argv[2])/'client'
r=Path(sys.argv[1])/'workshop/Contents/mods/VehicleLivingSlots/common/media/lua/client/VLS_Client.lua'
def native(name,start,end):
 s=(n/name).read_text();return s[s.index(start):s.index(end,s.index(start))]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
function noop() end
function getText(x) return x end
function instanceof(o,k) return o and o.kind==k end
function getSoundManager() return {playUISound=noop} end
function isClient() return true end
function table.wipe(t) for k in pairs(t) do t[k]=nil end end
ISInventoryPage={};ISButton={};ISMouseDrag={};ISHandCraftPanel={};ISBuildPanel={}
ContainerButtonIcons={fridge='fridge',freezer='freezer',clothingwasher='washer'}
function ISButton:new(x,y,w,h,text,target,onclick,onmousedown)
 local b=setmetatable({x=x,y=y,width=w,height=h,target=target,onclick=onclick,onmousedown=onmousedown,onClickArgs={},sounds={},enable=true},{__index=self});return b
end
function ISButton:setX(v) self.x=v end
function ISButton:setY(v) self.y=v end
function ISButton:getBottom() return self.y+self.height end
function ISButton:setImage(v) self.image=v end
function ISButton:getIsVisible() return true end
for _,k in ipairs({'initialise','forceImageSize','setBackgroundRGBA','setBackgroundColorMouseOverRGBA','setBorderRGBA','setTextureRGBA','setOnMouseOverFunction','setOnMouseOutFunction','setSound'}) do ISButton[k]=noop end
vehicle={parts={}};player={getVehicle=function() return vehicle end,getJoypadBind=function() return -1 end}
function getSpecificPlayer() return player end
function vehicle:getPartCount() return #self.parts end
function vehicle:getPartByIndex(i) return self.parts[i+1] end
function vehicle:canAccessContainer() return true end
function ISInventoryPage.GetFloorContainer() return nil end
function makePart(id,typ,freezer)
 local part={id=id,item={id=id},freezer=freezer};local c={id=id,typ=typ}
 part.c=c;c.part=part
 function part:getId() return self.id end
 function part:getVehicle() return vehicle end
 function part:getInventoryItem() return self.item end
 function part:getItemContainer() return self.c end
 function c:getVehiclePart() return self.part end
 function c:getType() return self.typ end
 function c:getParent() return vehicle end
 function c:getEffectiveCapacity() return 20 end
 function c:isExplored() return true end
 function c:getItems() return {size=function() return 0 end} end
 table.insert(vehicle.parts,part);return part
end
local f=makePart('slot1','fridge');local w=makePart('slot2','clothingwasher');local z=makePart('freezer1','freezer',true)
VLS={UNIVERSAL_PART_BY_FREEZER={freezer1='slot1'},isSupportedVehicle=function(v) return v==vehicle end,isFreezerPart=function(p) return p.freezer end,isUniversalPart=function(p) return not p.freezer end,getPartDisplayName=function(p) return p.id end,getEquipmentProfile=function() return nil end}
CargoR6={safeInventoryPhase=noop};processVisibleAppliances=noop
""")
for filename,start,end in [
('ISUI/ISButton.lua','function ISButton:onMouseUp(','function ISButton:onMouseUpOutside('),
('ISUI/ISInventoryPage.lua','function ISInventoryPage:selectContainer(','function ISInventoryPage:setNewContainer('),
('ISUI/ISInventoryPage.lua','function ISInventoryPage:onBackpackClick(','function ISInventoryPage:onBackpackRightMouseDown('),
('ISUI/ISInventoryPage.lua','function ISInventoryPage:addContainerButton(','function ISInventoryPage:checkExplored('),
('ISUI/ISInventoryPage.lua','function ISInventoryPage:refreshBackpacks()','ISInventoryPage.onRenameContainer =')]:
 lua.execute(native(filename,start,end))
s=r.read_text();a=s.index('local function onReorderedContainerMouseUp(') if 'local function onReorderedContainerMouseUp(' in s else s.index('local function refreshVehicleContainerLabels(');b=s.index('-- Vanilla stops an active microwave',a)
lua.execute(s[a:b]+'\n refreshVLS=refreshVehicleContainerLabels')
lua.execute("""
function triggerEvent(event,page,phase) if reorder then refreshVLS(page,phase) end end
function ISInventoryPage:checkExplored() end
ISInventoryPage.titleBarHeight=function() return 20 end
ISInventoryPage.refreshWeight=noop;ISInventoryPage.updateItemCount=noop
ISInventoryPage.playContainerOpenCloseSounds=noop
function ISInventoryPage:dropItemsInContainer() return false end
function makePage()
 local panel={removeChild=noop,addChild=function(self,b) b.parent=self end,setHeight=noop,setY=noop,setScrollHeight=noop}
 local inv={inventory=vehicle.parts[1].c,hideButtons=noop,bringToTop=noop,refreshContainer=noop,height=300,y=0}
 local page=setmetatable({backpacks={},buttonPool={},player=0,buttonSize=32,inventoryPane=inv,containerButtonPanel=panel,resizeWidget={bringToTop=noop},resizeWidget2={bringToTop=noop}},{__index=ISInventoryPage})
 panel.parent=page;page:refreshBackpacks();return page
end
for _,r in ipairs({false,true}) do
 reorder=r
 for _,id in ipairs({'freezer1','slot2','slot1'}) do
  local page=makePage();local button
  for _,b in ipairs(page.backpacks) do if b.inventory.id==id then button=b end end
  local label=button.name;local image=button.image;button.pressed=true
  button:onMouseUp(1,1)
  print('reorder='..tostring(r)..' click='..id..' label='..tostring(label)..' icon='..tostring(image)..' result='..page.inventoryPane.inventory.id)
  assert(page.inventoryPane.inventory.id==id)
 end
end
reorder=true
local page=makePage()
for index=1,30 do
 local id=index%2==0 and 'slot2' or 'freezer1';local b
 for _,v in ipairs(page.backpacks) do if v.inventory.id==id then b=v end end
 b.pressed=true;b:onMouseUp(1,1);assert(page.inventoryPane.inventory.id==id)
end
print('PASS 30 alternating native mouse clicks retain selected container')
local b=page.backpacks[2];local old=page.inventoryPane.inventory;local dropped
page.dropItemsInContainer=function(_,button) dropped=button.inventory;return true end
ISMouseDrag.dragging={};b.pressed=false;local target=b.inventory;b:onMouseUp(1,1)
assert(dropped==target);assert(page.inventoryPane.inventory==old);assert(b.onclick==ISInventoryPage.onBackpackClick)
ISMouseDrag.dragging=nil
print('PASS native drag/drop receives intended container without extra selection')
page.dropItemsInContainer=function()error('drop fault')end
b.pressed=true;assert(not pcall(b.onMouseUp,b,1,1));assert(b.onclick==ISInventoryPage.onBackpackClick)
print('PASS callback restored after native handler error')
page.dropItemsInContainer=function()return false end
b=page.backpacks[2];target=b.inventory;b.onclick(page,b);assert(page.inventoryPane.inventory==target)
print('PASS direct native callback retains keyboard/joypad activation')
""")
