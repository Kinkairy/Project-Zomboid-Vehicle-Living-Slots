local root=assert(arg[1])
package.loaded["Entity/TimedActions/ISHandcraftAction"]=true
package.loaded["TimedActions/ISDeviceBatteryAction"]=true
package.loaded["Vehicles/Vehicles"]=true
local V=dofile(root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/VLS_Config.lua")
local client=true
function isClient() return client end
function instanceof(o,k)return o and o.kind==k end
local function device(name,media)
 local d={DeviceName=name,MediaType=media,IsTelevision=true,IsTwoWay=false,
  TransmitRange=0,MicRange=0,BaseVolumeRange=15,IsPortable=false,
  MinChannelRange=200,MaxChannelRange=100000,IsBatteryPowered=false,
  HasBattery=false,IsHighTier=media==1,UseDelta=0,Channel=200,
  DeviceVolume=.5,Power=1,IsTurnedOn=false,
  DevicePresets={getPresets=function()return {size=function()return 1 end}end}}
 for _,field in ipairs({'DeviceName','MediaType','IsTelevision','IsTwoWay','TransmitRange','MicRange','BaseVolumeRange','IsPortable','MinChannelRange','MaxChannelRange','IsBatteryPowered','HasBattery','IsHighTier','UseDelta','Channel','DeviceVolume','Power','IsTurnedOn','DevicePresets'}) do
  d['get'..field]=function(self)return self[field]end
  d['set'..field]=function(self,v)self[field]=v end
 end
 d.setChannelRaw=d.setChannel;d.setDeviceVolumeRaw=d.setDeviceVolume;d.setTurnedOnRaw=d.setIsTurnedOn
 d.cloneDevicePresets=function(self,p)self.DevicePresets=p end
 return d
end
local source=device('Wide Screen TV',1);local replica=device('Antique TV',-1)
local item={kind='Radio',getID=function()return 2 end,getDeviceData=function()return source end}
local marker={vlsTelevisionItemId=2}
local slot={getInventoryItem=function()return item end}
local companion={getDeviceData=function()return replica end,getModData=function()return marker end}
local sends=0
local vehicle={transmitPartItem=function()sends=sends+1 end,transmitPartModData=function()sends=sends+1 end}
V.isUniversalPart=function(p)return p==slot end
V.getEquipmentCapability=function(i)return i and 'television' end
V.getTelevisionDevicePart=function()return companion end
V.getAuxBatteryCharge=function()return 1 end
local station,volume,presets=12345,.7,replica.DevicePresets
replica.Channel=station;replica.DeviceVolume=volume;replica.IsTurnedOn=true
assert(V.syncTelevisionDevice(vehicle,slot,true))
assert(replica.DeviceName=='Wide Screen TV');assert(replica.MediaType==1);assert(replica.IsHighTier)
assert(replica.Channel==station and replica.DeviceVolume==volume and replica.DevicePresets==presets and replica.IsTurnedOn)
assert(sends==0)
assert(not V.syncTelevisionDevice(vehicle,slot,true))
print('PASS replicated item marker cannot conceal stale TV metadata; settings retained; second sync is idempotent')
source=device('Antique TV',-1);marker.vlsTelevisionItemId=2
assert(V.syncTelevisionDevice(vehicle,slot,false));assert(replica.MediaType==-1 and not replica.IsHighTier)
assert(replica.Channel==station and replica.DevicePresets==presets)
print('PASS replacing media-capable television with antique clears media capability')
client=false;source=device('Wide Screen TV',1);marker.vlsTelevisionItemId=1
assert(V.syncTelevisionDevice(vehicle,slot,true));assert(sends==2)
assert(replica.Channel==source.Channel and replica.DevicePresets==source.DevicePresets)
assert(not V.syncTelevisionDevice(vehicle,slot,true))
print('PASS new server installation still copies original station/volume/presets once')
client=true;item=nil
assert(V.syncTelevisionDevice(vehicle,slot,true));assert(marker.vlsTelevisionItemId==-1);assert(not replica.IsTurnedOn)
print('PASS removal still deactivates signal device')
