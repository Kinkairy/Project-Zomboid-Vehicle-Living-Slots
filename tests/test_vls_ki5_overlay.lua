-- Native renderer/hit-test integration with real KI5 registry and texture inventory.
local root,native=assert(arg[1]),assert(arg[2])
local fixture=dofile(assert(arg[3],'pass the real texture/registry fixture'))
local T=dofile(root..'/tests/test_vls_top_space.lua');local eq=T.eq
package.loaded.VLS_Pantry=VLSPantry;package.loaded.VLS_Propane=true
local A=require 'VLS_KI5F700_Config'
local mods=root..'/workshop/Contents/mods/'
local campers=dofile(mods..'VehicleLivingSlotsKI5Campers/common/media/lua/shared/VLS_KI5Campers_Config.lua')
package.loaded.VLS_KI5Campers_Config=campers
ISCarMechanicsOverlay={CarList={},PartList={}}
package.loaded['Vehicles/ISUI/ISCarMechanicsOverlay']=true
package.loaded['Vehicles/ISUI/ISVehicleMechanics']=true
local starts={};Events.OnGameStart={Add=function(fn)starts[#starts+1]=fn end}
UIManager={getMillisSinceLastRender=function()return 33.3 end};getDebug=function()return false end
ISVehicleMechanics.alphaOverlay=0.5
local f=assert(io.open(native..'/client/Vehicles/ISUI/ISVehicleMechanics.lua'));local source=f:read('*a');f:close()
for _,method in ipairs({'renderCarOverlay','isMouseOverPart'})do
 local first=assert(source:find('function ISVehicleMechanics:'..method,1,true))
 local last=assert(source:find('\nfunction ',first+10,true))
 assert(loadstring(source:sub(first,last-1),'@native.'..method))()
end
-- Use the installed game wrapper, including its Texture argument and line width.
-- The Java boundary below records draw commands and validates the native types.
ISUIElement = {}
ISUITextureGetter = {instanceof=function() return false end}
local function loadNativeMethod(file, signature)
 local handle=assert(io.open(native..'/client/ISUI/'..file))
 local code=handle:read('*a');handle:close()
 local first=assert(code:find(signature,1,true))
 local last=code:find('\nfunction ',first+10,true) or (#code+1)
 assert(loadstring(code:sub(first,last-1),'@native.'..file))()
end
loadNativeMethod('ISUIElement.lua','function ISUIElement:drawLine(')
loadNativeMethod('ISUITextureGetter.lua','function ISUITextureGetter.checkGetTexture(')
assert(loadstring(fixture.registries.damn,'@native.DAMN_MechOverlay'))()
package.loaded.DAMN_MechOverlay=true
assert(loadstring(fixture.registries.f700,'@native.87fordB700MechanicsOverlay'))()
assert(loadstring(fixture.registries.campers,'@native.KI5campers_CarMechanicsOverlay'))()
-- Include an ordinary VLS van for both draw delegation and registry isolation.
ISCarMechanicsOverlay.CarList['Base.StepVan']={imgPrefix='van_',x=10,y=0}
local textures,missing={},{}
getTexture=function(name)
 if not fixture.textures[name] then missing[name]=true;return nil end
 if not textures[name]then
  local meta=fixture.textures[name]
  textures[name]={name=name,getWidth=function()return meta.w end,getHeight=function()return meta.h end}
 end
 return textures[name]
end
dofile(mods..'VehicleLivingSlots/common/media/lua/client/VLS_VehicleMechanicsOverlay.lua')
package.loaded.VLS_VehicleMechanicsOverlay=true
local coreRender=ISVehicleMechanics.renderCarOverlay
local nativeMissing={}
for _,props in pairs(ISCarMechanicsOverlay.CarList)do
 local stem='media/ui/vehicles/mechanic overlay/'..props.imgPrefix
 if not fixture.textures[stem..'base.png'] then nativeMissing[stem..'base.png']=true end
 for _,spec in pairs(ISCarMechanicsOverlay.PartList)do
  if spec.vehicles and spec.vehicles[props.imgPrefix] and spec.img then
   local path=stem..spec.img..'.png'
   if not fixture.textures[path] then nativeMissing[path]=true end
  end
 end
end
local oldTank=ISCarMechanicsOverlay.PartList.VLSLargeVanWaterTank.vehicles.van_
local oldBattery=ISCarMechanicsOverlay.PartList.VLSAuxBatterySlot.vehicles.van_
local oldFuel=ISCarMechanicsOverlay.PartList.GasTank.vehicles['87fordF700bank_']
local order=arg[5]=='campers-first' and {'VehicleLivingSlotsKI5Campers','VehicleLivingSlotsKI5F700'}
 or {'VehicleLivingSlotsKI5F700','VehicleLivingSlotsKI5Campers'}
for _,mod in ipairs(order)do
 local file=mod=='VehicleLivingSlotsKI5F700' and 'VLS_KI5F700_Overlay.lua' or 'VLS_KI5Campers_Overlay.lua'
 dofile(mods..mod..'/common/media/lua/client/'..file)
end
for cycle=1,2 do for _,fn in ipairs(starts)do fn()end end
eq(ISCarMechanicsOverlay.PartList.VLSLargeVanWaterTank.vehicles.van_,oldTank)
eq(ISCarMechanicsOverlay.PartList.VLSAuxBatterySlot.vehicles.van_,oldBattery)
eq(VLS.mechanicsOverlayGuides.VLSLargeVanWaterTank.vehicles.van_,oldTank)
eq(ISCarMechanicsOverlay.PartList.GasTank.vehicles['87fordF700bank_'],oldFuel)
eq(VLS.mechanicsOverlayGuides.VLSLargeVanWaterTank.vehicles['87fordB700_'],nil)
local busRects={
 {'VLSLargeVanWaterTank',13,482,42,30},{'VLSF700WaterTank2',228,482,42,30},
 {'VLSF700WaterTank3',13,567,42,30},{'VLSF700WaterTank4',228,567,42,30},
 {'VLSAuxBatterySlot',228,103,42,31},{'VLSF700Battery3',78,527,42,31},
 {'GasTank',13,527,42,30},{'DAMNWindshieldRearArmor',144,526,43,38},
}
local vanRects={
 {'VLSLargeVanWaterTank',8,268,52,80},{'VLSF700WaterTank2',223,268,52,80},
 {'VLSAuxBatterySlot',120,527,46,34},
}
local camperRects={{'VLSKI5CamperWaterTank1',223,384,52,80},{'VLSKI5CamperWaterTank2',223,484,52,80}}
local variants={
 {'Base.87fordF700bank','87fordF700bank_',vanRects},
 {'Base.87fordF700swat','87fordF700swat_',vanRects},
 {'Base.87fordB700school','87fordB700_',busRects},
 {'Base.87fordB700prison','87fordB700_',busRects},
 {'Base.87fordB700military','87fordB700_',busRects},
 {'Base.Trailer87Scamp13','Trailer87Scamp13_',camperRects},
 {'Base.Trailer87Scamp16','Trailer87Scamp16_',camperRects},
 {'Base.Trailer61Bambi16','Trailer61Bambi16_',camperRects},
 {'Base.Trailer54FlyingCloud22','Trailer54FlyingCloud22_',camperRects},
 {'Base.Trailer61Airflyte','Trailer61shastaAirflyte_',camperRects},
 {'Base.Trailer61Astrodome','Trailer61shastaAstrodome_',camperRects},
}
local function panelFor(name,parts)
 local vehicle,make=T.vehicle(name)
 vehicle.getScript=function()return {getCarMechanicsOverlay=function()return nil end}end
 local panel=setmetatable({vehicle=vehicle,draws={},lines={},borders={},tips={},commands={}},{__index=ISVehicleMechanics})
 for _,rect in ipairs(parts)do
  local p=make(rect[1]);p.item=T.item('Base.Test');p.getTable=function()return {}end
 end
 panel.getConditionRGB=function(_,n)return {r=n==0 and 1 or 0,g=n==0 and 0 or 1,b=0}end
 panel.isMouseOver=function()return true end
 panel.renderCarOverlayTooltip=function(self,spec,part)
  self.tips[part:getId()]=true;return false
 end
 panel.drawTextureScaledUniform=function(self,tex,x,y,scale,a,r,g,b)
  if tex then self.draws[#self.draws+1]={tex.name,0,0,tex:getWidth(),tex:getHeight(),x,y,tex:getWidth()*scale,tex:getHeight()*scale,a,r,g,b,'full'};self.commands[#self.commands+1]={'DRAW',self.draws[#self.draws]}end
 end
 panel.drawSubTexture=function(self,tex,sx,sy,sw,sh,x,y,w,h,a,r,g,b)
  assert(tex and sx>=0 and sy>=0 and sx+sw<=tex:getWidth() and sy+sh<=tex:getHeight(),'invalid crop')
  self.draws[#self.draws+1]={tex.name,sx,sy,sw,sh,x,y,w,h,a,r,g,b,'crop'};self.commands[#self.commands+1]={'DRAW',self.draws[#self.draws]}
 end
 panel.drawLine=ISUIElement.drawLine
 panel.javaObject={DrawLine=function(_,texture,x,y,x2,y2,thickness,r,g,b,a)
  assert(texture==nil,'expected argument of type Texture, got '..type(texture))
  for _,value in ipairs({x,y,x2,y2,thickness,r,g,b,a})do assert(type(value)=='number')end
  eq(thickness,1);eq(a,1);eq(r,0.65);eq(g,0.65);eq(b,0.65)
  panel.lines[#panel.lines+1]={x,y,x2,y2,a,r,g,b}
  panel.commands[#panel.commands+1]={'LINE',panel.lines[#panel.lines]}
 end}
 panel.drawRectBorder=function(self,x,y,w,h,a,r,g,b)self.borders[#self.borders+1]={x,y,w,h,a,r,g,b};self.commands[#self.commands+1]={'BORDER',self.borders[#self.borders]}end
 return panel
end
local function clear(panel)panel.draws={};panel.lines={};panel.borders={};panel.tips={};panel.commands={}end
local count=0
for _,entry in ipairs(variants)do
 local name,prefix,rects=entry[1],entry[2],entry[3]
 local panel=panelFor(name,rects)
 -- Render all unmodified native parts too; catches clipping of unrelated art.
 for id,spec in pairs(ISCarMechanicsOverlay.PartList)do
  if spec.vehicles and spec.vehicles[prefix] and not panel.vehicle.parts[id] then
   local _,make=T.vehicle(name);local part=make(id);part.vehicle=panel.vehicle;part.item=T.item('Base.Test')
   part.getTable=function()return {}end
   panel.vehicle.parts[id]=part;panel.vehicle.order[#panel.vehicle.order+1]=part
  end
 end
 panel:renderCarOverlay()
 for _,c in ipairs(rects)do
  local part=panel.vehicle.parts[c[1]]
  local hit=ISCarMechanicsOverlay.PartList[c[1]].vehicles[prefix]
  eq(hit.x,c[2]);eq(hit.y,c[3]);eq(hit.x2,c[2]+c[4]);eq(hit.y2,c[3]+c[5])
  eq(panel:isMouseOverPart(hit.x+1,hit.y+1,part),true)
  eq(panel:isMouseOverPart(hit.x2-1,hit.y2-1,part),true)
  eq(panel:isMouseOverPart(hit.x-1,hit.y+1,part),false)
  eq(panel:isMouseOverPart(hit.x2+1,hit.y+1,part),false)
  eq(panel.tips[c[1]],true)
  local mask,guide
  for _,d in ipairs(panel.draws)do
   if d[6]==hit.x and d[7]==hit.y and d[8]==c[4] and d[9]==c[5] then
    if d[11]==0 and d[12]==1 then mask=d end
    if d[11]==1 and d[12]==1 then guide=d end
   end
  end
  assert(mask and guide,'guide/condition not at hit bounds: '..name..' '..c[1])
  for _,other in ipairs(rects)do if other~=c then
   assert(hit.x2<=other[2] or hit.x>=other[2]+other[4] or hit.y2<=other[3] or hit.y>=other[3]+other[5],'overlapping components')
  end end
  count=count+1
 end
 if prefix=='87fordB700_' then
  -- Old fuel and rear-armor centers must no longer select those parts.
  eq(panel:isMouseOverPart(68,550,panel.vehicle.parts.GasTank),false)
  eq(panel:isMouseOverPart(130,545,panel.vehicle.parts.DAMNWindshieldRearArmor),false)
 end
 if arg[4] then
  print('MODEL\t'..name..'\t'..prefix)
  for _,command in ipairs(panel.commands)do print(command[1]..'\t'..table.concat(command[2],'\t'))end
  for _,c in ipairs(rects)do print('HIT\t'..table.concat(c,'\t'))end
 end
 -- Missing/damaged component retains its own native flashing color and alpha.
 for _,c in ipairs(rects)do
  panel.vehicle.parts[c[1]].item=nil;panel.vehicle.parts[c[1]].condition=0
 end
 clear(panel);panel:renderCarOverlay()
 for _,c in ipairs(rects)do
  local seen=false
  for _,d in ipairs(panel.draws)do
   if d[6]==c[2] and d[7]==c[3] and d[11]==1 and d[12]==0 then
    eq(d[10],ISVehicleMechanics.alphaOverlay);seen=true
   end
  end
  assert(seen,'missing component did not flash: '..name..' '..c[1])
 end
 assert(#panel.lines>0,'no native connector calls: '..name)
 -- A Java drawing failure must also restore the temporary texture hook.
 local line=panel.javaObject.DrawLine
 local textureDraw=panel.drawTextureScaledUniform
 panel.javaObject.DrawLine=function()error('native line fault')end
 eq(pcall(panel.renderCarOverlay,panel),false)
 eq(panel.drawTextureScaledUniform,textureDraw)
 panel.javaObject.DrawLine=line
 clear(panel);panel:renderCarOverlay()
 -- Restore temporary draw hook on either native draw or crop failure.
 local oldCrop=panel.drawSubTexture
 panel.drawSubTexture=function()error('crop fault')end
 local oldDraw=panel.drawTextureScaledUniform
 eq(pcall(panel.renderCarOverlay,panel),false);eq(panel.drawTextureScaledUniform,oldDraw)
 panel.drawSubTexture=oldCrop
 panel.drawTextureScaledUniform=function()error('native fault')end
 local failed=panel.drawTextureScaledUniform
 eq(pcall(panel.renderCarOverlay,panel),false);eq(panel.drawTextureScaledUniform,failed)
 panel.drawTextureScaledUniform=oldDraw
end
local function trace(panel,render)
 clear(panel);ISVehicleMechanics.alphaOverlay=0.5;ISVehicleMechanics.alphaOverlayInc=true
 render(panel);local parts={}
 for _,d in ipairs(panel.draws)do parts[#parts+1]=table.concat(d,'|')end
 return table.concat(parts,'\n')
end
local step=panelFor('Base.StepVan',{{'VLSLargeVanWaterTank'},{'VLSAuxBatterySlot'}})
eq(trace(step,coreRender),trace(step,ISVehicleMechanics.renderCarOverlay))
-- Do not depend on any invented or absent per-Bus VLS image.
for path in pairs(missing)do assert(nativeMissing[path],'new missing texture requested: '..path)end
print('KI5_OVERLAY_PASS models='..#variants..' parts='..count..' native draw/hits crops guides missing-flash core passthrough hook restoration real texture inventory')
