-- Actual client callbacks -> primitive command -> actual server handlers.
-- Engine objects are mocked; this is not a real network or gameplay test.
local root=assert(arg[1])
local base=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/'
package.path=base..'shared/?.lua;'..base..'client/?.lua;'..package.path
-- Load the real server with its existing source fixture first.
dofile(root..'/tests/test_vls_vehicle_power.lua')
local V=VLS
local client=false;isClient=function()return client end
local data={vlsNativeEpoch=4}
-- Real items name their type; heating limits are read from the microwave profile.
local item={getID=function()return 91 end,getCondition=function()return 100 end,capability='cooking',
 getFullType=function()return 'Base.Mov_Microwave' end,getScriptItem=function()return nil end}
local v={getId=function()return 71 end,transmitPartModData=function()end,setNeedPartsUpdate=function()end}
local part={getId=function()return 'Device' end,getVehicle=function()return v end,
 getInventoryItem=function()return item end,getModData=function()return data end,
 getItemContainer=function()return nil end,getCondition=function()return 100 end}
v.getPartById=function(_,id)return id=='Device' and part end
local player={getVehicle=function()return v end,getEmitter=function()return {playSound=function()end}end}
getVehicleById=function(id)return id==71 and v or nil end
V.isSupportedVehicle=function(x)return x==v end;V.isManagedPart=function(x)return x==part end
V.getInstalledPart=function(x,id)return x==v and id=='Device' and part or nil end
V.getEquipmentCapability=function(x)return x.capability end
V.getVehicleProfile=function()return {universalParts={'Device'}}end
V.hasAuxBatteryPower=function()return true end
V.refreshApplianceEnvironment=function()end;V.ensureUniversalContainerProfile=function()end
V.Server.trackVehicle=function()end
local queued={}
sendClientCommand=function(actor,module,command,args)queued[#queued+1]={actor=actor,module=module,command=command,args=args}end
HaloTextHelper={addBadText=function()end};getText=function(k)return k end
closeVLSMicrowaveWindow=function(ui)ui.closed=true end
local f=assert(io.open(base..'client/VLS_Client.lua'));local source=f:read('*a');f:close()
local function between(a,b)
 local first=assert(source:find(a,1,true));local last=assert(source:find(b,first+#a,true));return source:sub(first,last-1)
end
local code=between('local function sendApplianceCommand','-- The vanilla window a VLS heating appliance uses')
 ..between('local function isVLSMicrowaveWindowValid','local function installMicrowaveWindowClientHook')
 ..between('local function onVLSMicrowaveClick','local function openMicrowaveSettings')
 ..'\nreturn newMicrowaveProxy,onVLSMicrowaveClick,isVLSMicrowaveWindowValid\n'
local makeProxy,click,valid=assert(loadstring(code))()
local function window()
 return {character=player,oven=makeProxy(v,part,player),timerKnob={getValue=function()return 5 end},tempKnob={getValue=function()return 90 end}}
end
local ui=window();client=true;click(ui,{internal='OK'});assert(#queued==1)
local old=queued[1];assert(old.args.epoch==4 and old.args.item==91)
-- Exact same item and ID, successful uninstall/install changed epoch.
data.vlsNativeEpoch=5;client=false
assert(not V.Server[old.command](old.actor,old.args));assert(not data.vlsMicrowaveActive)
client=true;assert(not valid(ui,ui.oven));click(ui,{internal='OK'});assert(ui.closed and #queued==1)
ui.oven:sync();assert(#queued==1) -- sync cannot refresh an old binding.
local fresh=window();click(fresh,{internal='OK'});assert(#queued==2 and queued[2].args.epoch==5)
client=false;assert(V.Server[queued[2].command](player,queued[2].args));assert(data.vlsMicrowaveActive)
-- Each mutating production entry rejects absent/stale/malformed generations.
local cases={
 setMicrowaveParams={timer=300,temperature=90},toggleMicrowave={timer=300,temperature=90,active=false},stopMicrowave={},
 toggleLaundry={active=false},setLaundryMode={mode='dryer'}}
for command,extra in pairs(cases)do
 item.capability=command:find('Laundry') and 'laundryCombo' or 'cooking'
 for _,kind in ipairs({'missing','stale','negative','fraction','infinite'})do
  local args={vehicle=71,part='Device',item=91};for k,value in pairs(extra)do args[k]=value end
  if kind=='stale'then args.epoch=4 elseif kind=='negative'then args.epoch=-1 elseif kind=='fraction'then args.epoch=5.5 elseif kind=='infinite'then args.epoch=math.huge end
  local before=data.vlsMicrowaveActive
  assert(not V.Server[command](player,args),command..' accepted '..kind)
  assert(data.vlsMicrowaveActive==before)
 end
 local args={vehicle=71,part='Device',item=91,epoch=5};for k,value in pairs(extra)do args[k]=value end
 assert(V.Server[command](player,args),command..' rejected current generation')
end
print('PASS actual microwave client callback/proxy -> command -> server: stale same-ID reinstall rejected, old sync/window rejected, new binding accepted; all five handlers reject missing/stale/malformed epochs (mock transport)')
