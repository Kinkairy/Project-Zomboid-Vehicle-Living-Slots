local root=assert(arg[1])
local T=dofile(root..'/tests/test_vls_top_space.lua')
package.loaded.VLS_Pantry=VLSPantry
Events.OnTick={Add=function()end}
local A=require 'VLS_KI5F700_Config'
package.loaded.VLS_VehicleMechanicsIcons=true
package.loaded.VLS_PantryMenu=true
VLSPantry.stationOrder={'VLSPantryCoffee','VLSOverhead1','VLSOverhead2'}
-- Keep the actual B42 mechanics context-menu body for empty-space installs.
local file=assert(io.open(assert(arg[2])..'/client/Vehicles/ISUI/ISVehicleMechanics.lua'))
local source=file:read('*a');file:close()
local first=assert(source:find('function ISVehicleMechanics:doPartContextMenu',1,true))
local last=assert(source:find('\nfunction ',first+10,true))
assert(loadstring(source:sub(first,last-1),'@native.ISVehicleMechanics.doPartContextMenu'))()
require 'VLS_PantryMechanics'
local baseRowOrder=VLSPantry.orderMechanicsRows
require 'VLS_KI5F700_Mechanics'
local eq=T.eq
-- Real engine parts expose category IDs even when headers are localized.
local originalVehicle=T.vehicle
T.vehicle=function(name)
 local car,make=originalVehicle(name)
 return car,function(id)
  local part=make(id);part.getCategory=function(self)return self.category or VLS.CATEGORY_ID end
  return part
 end
end
for _,name in ipairs({'Base.87fordF700bank'})do
 T.test(name..' fourth pair cycles in the same native panel; items and selection preserved',function()
  local car,make=T.vehicle(name)
  car.getScript=function()return {getFullName=function()return name end,getMass=function()return 950 end}end
  local frames,slots,rows={},{},{{item={cat=true,name='Living'}}}
  for i=1,4 do
   frames[i]=make(A.frames[i]);slots[i]=make(A.overhead[i])
   rows[#rows+1]={item={part=frames[i]},height=20};rows[#rows+1]={item={part=slots[i]},height=20}
  end
  local engine=make('Engine');engine.item=T.item('Base.TestEngine');local unrelated={item={part=engine}};rows[#rows+1]=unrelated
  local list={items=rows,selected=8,mouseoverselected=8,scroll=-60}
  function list:removeItemByIndex(i)table.remove(self.items,i)end
  local ui=setmetatable({vehicle=car,listbox=list,leftListSelection=8},{__index=ISVehicleMechanics})
  ui:initParts()
  local function check(part)
   eq(#list.items,6);eq(list.items[5].item.part,part);eq(list.items[6],unrelated)
   eq(list.items[list.selected].item.part,part);eq(list.items[list.mouseoverselected].item.part,part);eq(list.items[ui.leftListSelection].item.part,part)
   eq(list.scroll,-60);eq(ui.generalCondition,100)
   for i,row in ipairs(list.items)do eq(row.index,i);eq(row.itemindex,i)end
  end
  check(frames[4])
  for cycle=1,4 do
   frames[4].item=T.item('Base.VLSTopFrame');ui:recalculGeneralCondition();check(slots[4])
   for _,type in ipairs({'Base.Mov_CoffeeMaker','Base.Mov_Toaster',T.catalog[1].type})do
    local installed=T.item(type);eq(VLS.isInstallationEnabled(slots[4],installed),true)
    slots[4].item=installed;ui:recalculGeneralCondition();check(slots[4]);eq(slots[4].item,installed)
    slots[4].item=nil
   end
   frames[4].item=nil;ui:recalculGeneralCondition();check(frames[4])
  end
  list.selected=6;list.mouseoverselected=6;ui.leftListSelection=6
  for i=1,100 do ui:recalculGeneralCondition()end
  eq(list.items[list.selected],unrelated);eq(#list.items,6)
 end)
end
T.test('F700 row order is scoped; every other profile retains the exact core order and selection',function()
 for name,p in pairs(VLS.vehicleProfiles)do
  local ids={}
  for n,id in ipairs(p.overheadParts or {})do ids[#ids+1]='VLSTopFrame'..n;ids[#ids+1]=id end
  for _,id in ipairs(p.universalParts)do ids[#ids+1]=id end
  ids[#ids+1]=VLS.WEAPON_PART_ID
  for _,id in ipairs(p.waterTankParts or {})do ids[#ids+1]=id end
  ids[#ids+1]=p.auxBatteryPartId or VLS.AUX_BATTERY_PART_ID
  local rows={{item={cat=true}}}
  for i=#ids,1,-1 do local id=ids[i];rows[#rows+1]={item={part={getId=function()return id end}}}end
  local list={items=rows,selected=2};local selected=rows[2];local header=rows[1]
  local panel={vehicle={getScriptName=function()return name end}}
  local expected={items={},selected=2}
  for i,row in ipairs(rows)do expected.items[i]=row end
  baseRowOrder(panel,expected)
  VLSPantry.orderMechanicsRows(panel,list)
  eq(rows[1],header);eq(rows[list.selected],selected)
  if A.matches(panel.vehicle) then
   for i,id in ipairs(ids)do eq(rows[i+1].item.part:getId(),id)end
  else
   for i,row in ipairs(expected.items)do eq(rows[i],row)end
   eq(list.selected,expected.selected)
   -- Also test the adapter entry directly: it must not mutate a non-F700 list.
   local untouched={items={},selected=2,mouseoverselected=3}
   for i,row in ipairs(rows)do untouched.items[i]=row end
   A.orderRows(panel,untouched)
   for i,row in ipairs(rows)do eq(untouched.items[i],row)end
   eq(untouched.selected,2);eq(untouched.mouseoverselected,3)
  end
 end
end)
T.test('fourth station is registered exactly once',function()
 eq(#VLSPantry.stationOrder,4);eq(VLSPantry.stationOrder[4],'VLSOverhead3')
 dofile(root..'/workshop/Contents/mods/VehicleLivingSlotsKI5F700/common/media/lua/client/VLS_KI5F700_Mechanics.lua')
 eq(#VLSPantry.stationOrder,4)
end)
print('F700_NATIVE_UI_PASS')

T.test('SWAT six single rows retain native row identity, number, selection and contents',function()
 local car,make=T.vehicle('Base.87fordF700swat');local profile=VLS.getVehicleProfile(car)
 car.getScript=function()return {getFullName=function()return car.name end,getMass=function()return 3000 end}end
 local header={item={cat=true,name='Living'}};local rows={header};local cache={}
 for _,pair in ipairs(profile.seatPairs)do
  for _,id in ipairs({pair.seat,pair.living})do
   local part=make(id);if id==pair.seat then part.item=T.item('Base.87fordB700RearSeat')end
   local row={item={part=part},height=20};rows[#rows+1]=row;cache[id]=row
  end
 end
 local unrelated={item={part=make('Engine')}};unrelated.item.part.item=T.item('Base.Engine');rows[#rows+1]=unrelated
 local list={items=rows,selected=2,mouseoverselected=2,scroll=-40};function list:removeItemByIndex(i)table.remove(self.items,i)end
 local panel=setmetatable({vehicle=car,listbox=list,leftListSelection=2},{__index=ISVehicleMechanics})
 panel:initParts();eq(#list.items,8);eq(panel.generalCondition,100)
 for i,pair in ipairs(profile.seatPairs)do
  local seat,living=car.parts[pair.seat],car.parts[pair.living]
  list.selected=i+1;list.mouseoverselected=i+1;panel.leftListSelection=i+1
  for cycle=1,3 do for _,state in ipairs({'empty','bed','furniture','seat','legacyConflict'})do
   local fitted=state=='seat' or state=='legacyConflict'
   seat.item=fitted and T.item('USMIL.Seat0') or nil
   living.item=state=='bed' and T.item('Base.Mov_Cot') or (state=='furniture' or state=='legacyConflict') and T.item('Base.Mov_FridgeMini') or nil
   local nativeItem,livingItem=seat.item,living.item
   panel:recalculGeneralCondition();eq(#list.items,8);eq(list.items[1],header);eq(list.items[8],unrelated)
   local chosen=cache[fitted and pair.seat or pair.living]
   eq(list.items[i+1],chosen);eq(list.items[list.selected],chosen)
   eq(list.items[list.mouseoverselected],chosen);eq(list.items[panel.leftListSelection],chosen);eq(list.scroll,-40)
   if fitted then eq(VLS.getMechanicsPartName(seat),'IGUI_VLSF700Seat'..i)
   elseif state=='empty' then eq(VLS.getMechanicsPartName(living),'IGUI_VLSF700Space'..i)end
   eq(seat.item,nativeItem);eq(living.item,livingItem)
   for n,row in ipairs(list.items)do eq(row.index,n);eq(row.itemindex,n)end
  end end
  living.item=nil
 end
 list.selected=8;list.mouseoverselected=8;panel.leftListSelection=8
 for i=1,20 do panel:recalculGeneralCondition()end
 eq(list.items[list.selected],unrelated);eq(#list.items,8)
end)

T.test('real native empty-space menu routes driver-seat installs to real seat only',function()
 local S=VLS.F700Seats
 local car,make=T.vehicle('Base.87fordF700swat');local pair=VLS.getVehicleProfile(car).seatPairs[1]
 local seat,space=make(pair.seat),make(pair.living)
 car.getScript=function()return {getPassengerIndex=function()return 2 end}end
 car.getCharacter=function()return nil end
 car.canInstallPart=function(_,_,part)return not part.blocked end
 local function types(ft)return {get=function()return ft end,size=function()return 1 end,isEmpty=function()return false end,contains=function(_,v)return v==ft end}end
 for _,part in ipairs({seat,space})do
  part.getTable=function(_,op)return op=='install' and {} or nil end
  part.getItemType=function()return types(part==seat and 'USMIL.Seat0' or 'Base.Mov_Cot')end
  part.container.isEmpty=function()return true end
  part.getWindow=function()end;part.isContainer=function()return false end
 end
 local chair=T.item('USMIL.Seat0');local inventory={['USMIL.Seat0']={chair}}
 local chr={getPlayerNum=function()return 0 end,getVehicle=function()end}
 getSpecificPlayer=function()return chr end;getDebug=function()return false end
 local paused=false;UIManager={getSpeedControls=function()return {getCurrentGameSpeed=function()return paused and 0 or 1 end}end}
 JoypadState={players={}};VehicleUtils.getItems=function()return inventory end
 ISVehicleMechanics.getWrench=function()end;ISVehicleMechanics.getScrewdriver=function()end;ISVehicleMechanics.getTirePump=function()end
 getTextOrNull=function()end;getItemName=function(ft)return ft end;getItem=function()return {getNormalTexture=function()return 'seat-icon' end}end
 local menus={};local function menu()
  local m={options={},numOptions=1}
  function m:addOption(name,target,callback,...)
   local o={name=name,target=target,callback=callback,args={...}};self.options[#self.options+1]=o;self.numOptions=self.numOptions+1;return o
  end
  function m:addSubMenu(option,child)menus[#menus+1]=child;option.subOption=#menus end
  function m:getSubMenu(id)return menus[id]end
  function m:getOptionFromName(name)for _,o in ipairs(self.options)do if o.name==name then return o end end end
  function m:setVisible()end
  return m
 end
 ISContextMenu={get=menu,getNew=menu}
 local tooltips={}
 local panel=setmetatable({vehicle=car,chr=chr,playerNum=0,getAbsoluteX=function()return 0 end,getAbsoluteY=function()return 0 end,
  doMenuTooltip=function(_,part,opt,op,ft)tooltips[#tooltips+1]={part=part,ft=ft};opt.notAvailable=part.blocked end},{__index=ISVehicleMechanics})
 local function open()
  panel:doPartContextMenu(space,0,0)
  local install=panel.context:getOptionFromName('IGUI_Install')
  local sub=panel.context:getSubMenu(install.subOption)
  return sub,install
 end
 local sub=open();eq(#sub.options,2)
 local choice=sub:getOptionFromName('USMIL.Seat0');eq(not choice.notAvailable,true)
 local entry=sub:getSubMenu(choice.subOption).options[1]
 eq(entry.callback,ISVehiclePartMenu.onInstallPart);eq(entry.args[1],seat);eq(entry.args[2],chair);eq(entry.itemForTexture,chair)
 eq(tooltips[#tooltips].part,seat);eq(tooltips[#tooltips].ft,'USMIL.Seat0')
 local previous=panel.context;paused=true;panel:doPartContextMenu(space,0,0);eq(panel.context,previous);eq(#sub.options,2);paused=false
 inventory={};sub=open();eq(sub:getOptionFromName('USMIL.Seat0').notAvailable,true)
 inventory={['USMIL.Seat0']={chair}};seat.blocked=true;sub=open();eq(sub:getOptionFromName('USMIL.Seat0').notAvailable,true);seat.blocked=false
 car.getCharacter=function()return {}end;sub=open();eq(sub:getOptionFromName('USMIL.Seat0').notAvailable,true);car.getCharacter=function()end
 space.container.isEmpty=function()return false end;sub=open();eq(sub:getOptionFromName('USMIL.Seat0').notAvailable,true);space.container.isEmpty=function()return true end
 -- Different native requirements must not inherit the living part's disabled menu.
 space.blocked=true;local install;sub,install=open();eq(install.notAvailable,false);eq(not sub:getOptionFromName('USMIL.Seat0').notAvailable,true)
 space.blocked=false;seat.item=chair;sub=open();eq(sub:getOptionFromName('USMIL.Seat0'),nil);seat.item=nil
 car.name='Base.87fordF700bank';sub=open();eq(sub:getOptionFromName('USMIL.Seat0'),nil)
end)
print('F700_SINGLE_ROW_NATIVE_MENU_PASS')

T.test('F700 living category follows suspension in every native category order',function()
 local function permutations(a,n,fn)
  if n>#a then fn(a);return end
  for i=n,#a do a[n],a[i]=a[i],a[n];permutations(a,n+1,fn);a[n],a[i]=a[i],a[n] end
 end
 for _,name in ipairs({'Base.87fordF700bank','Base.87fordF700swat','Base.Van'})do
  permutations({'seat','VLSLiving','engine','gastank','suspension'},1,function(order)
   local car,make=T.vehicle(name);local list={items={},scroll=-71};local living,suspension,rest={},{},{}
   for _,category in ipairs(order)do
    local header={item={cat=true,name='localized-'..category}};list.items[#list.items+1]=header
    local part=make(category..'Part');part.category=category
    local row={item={part=part}};list.items[#list.items+1]=row
    if category=='VLSLiving' then living={header,row}
    elseif category=='suspension' then suspension={header,row} end
    if category~='VLSLiving' then rest[#rest+1]=header;rest[#rest+1]=row end
   end
   list.selected=4;list.mouseoverselected=7
   local panel={vehicle=car,leftListSelection=9};local selected,hovered,saved=list.items[4],list.items[7],list.items[9]
   local expected={};for _,row in ipairs(list.items)do expected[#expected+1]=row end
   if name~='Base.Van' then
    expected={};for _,row in ipairs(rest)do expected[#expected+1]=row;if row==suspension[2]then
     expected[#expected+1]=living[1];expected[#expected+1]=living[2]
    end end
   end
   for cycle=1,3 do
    A.orderCategories(panel,list);eq(#list.items,10);eq(list.scroll,-71)
    for i,row in ipairs(expected)do eq(list.items[i],row)end
    eq(list.items[list.selected],selected);eq(list.items[list.mouseoverselected],hovered);eq(list.items[panel.leftListSelection],saved)
   end
  end)
 end
 -- A model without suspension must retain its original category order.
 local car,make=T.vehicle('Base.87fordF700swat');local part=make('SeatBed')
 local header={item={cat=true}};local row={item={part=part}}
 local list={items={header,row}};A.orderCategories({vehicle=car},list)
 eq(list.items[1],header);eq(list.items[2],row)
end)
print('F700_CATEGORY_ORDER_PASS permutations=360 repeat=3 scope=Bank+SWAT')

T.test('three buses keep fourteen single paired rows and normalized original roof condition',function()
 for _,name in ipairs({'Base.87fordB700school','Base.87fordB700prison','Base.87fordB700military'})do
  local car,make=T.vehicle(name);local profile=VLS.getVehicleProfile(car)
  car.getScript=function()return {getFullName=function()return name end,getMass=function()return 3000 end}end
  local header={item={cat=true}};local rows={header}
  for _,pair in ipairs(profile.seatPairs)do
   for _,id in ipairs({pair.seat,pair.living})do
    local p=make(id);p.item=id==pair.seat and T.item('Base.87fordB700Seat2') or nil
    rows[#rows+1]={item={part=p},height=20}
   end
  end
  local list={items=rows,selected=2,mouseoverselected=2};function list:removeItemByIndex(i)table.remove(self.items,i)end
  local panel=setmetatable({vehicle=car,listbox=list,leftListSelection=2},{__index=ISVehicleMechanics})
  panel:initParts();eq(#list.items,15)
  for i,pair in ipairs(profile.seatPairs)do
   local seat,living=car.parts[pair.seat],car.parts[pair.living]
   eq(list.items[i+1].item.part,seat);eq(VLS.getMechanicsPartName(seat),'IGUI_VLSF700BusSeat'..i)
   seat.item=nil;panel:recalculGeneralCondition()
   eq(#list.items,15);eq(list.items[i+1].item.part,living)
   eq(VLS.getMechanicsPartName(living),'IGUI_VLSF700BusSpace'..i)
   living.item=T.item('Base.Mov_Cot');panel:recalculGeneralCondition()
   eq(#list.items,15);eq(list.items[i+1].item.part,living)
   living.item=nil;seat.item=T.item('Base.87fordB700Seat2');panel:recalculGeneralCondition()
   eq(#list.items,15);eq(list.items[i+1].item.part,seat)
  end
  local can=make('DAMNGasCanOne');can.item=T.item('Base.PetrolCan');can.item.condition=10
  can.item.getConditionMax=function()return 10 end
  eq(VLS.usesNormalizedPartCondition(can),true);eq(VLS.getDisplayPartCondition(can),100)
  can.item.condition=5;eq(VLS.getDisplayPartCondition(can),50)
 end
end)

T.test('Bus battery 3 has its own charge display and follows the existing auxiliary battery',function()
 for _,name in ipairs({'Base.87fordB700school','Base.87fordB700prison','Base.87fordB700military'})do
  local car,make=T.vehicle(name);local first=make(VLS.AUX_BATTERY_PART_ID);local third=make(A.battery3Id)
  third.item=T.item('Base.CarBattery2');third.item.kind='DrainableComboItem'
  third.item.getCurrentUsesFloat=function()return .75 end
  eq(VLS.getMechanicsPartName(third),'IGUI_VehiclePartVLSF700Battery3')
  eq(VLS.mechanicsUIProviders.ki5F700BusBattery3.remaining(third),.75)
  eq(VLS.usesNormalizedPartCondition(third),true)
  local r3={item={part=third}};local r2={item={part=first}}
  local list={items={r3,r2},selected=1,mouseoverselected=1}
  local panel={vehicle=car,leftListSelection=1}
  A.orderRows(panel,list);eq(list.items[1],r2);eq(list.items[2],r3);eq(list.selected,2)
  third.item=nil;eq(VLS.getMechanicsPartName(third),'IGUI_VehiclePartVLSF700Battery3')
 end
end)
