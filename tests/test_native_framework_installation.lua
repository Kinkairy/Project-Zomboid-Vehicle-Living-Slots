local root=assert(arg[1])
package.path=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/?.lua;'..package.path
local enabled,allowed,removable=true,true,true
local V={allowedItems={SeatBed=true}}
V.isInstallationEnabled=function()return enabled end
V.isAllowedItem=function()return allowed end
V.canUninstallManagedPart=function()return removable end
local P=require('VLS_NativeInstallation').bind(V)
local part={getId=function()return 'SeatBed' end}
assert(P.canInstall(part,{}));allowed=false;assert(not P.canInstall(part,{}))
assert(P.canInstall({getId=function()return 'UnrelatedPart' end},{}))
enabled=false;assert(not P.canInstall(part,{}));enabled=true;allowed=true
removable=false;assert(not P.canUninstall(part));removable=true;assert(P.canUninstall(part))
-- The actual wrapper must delegate to original methods, with a second policy
-- check at completion after a queued item/policy changes.
V.isUniversalPart=function()return false end
VLS=V;package.loaded.VLS_Config=V
local calls={valid=0,complete=0,uninstall=0}
ISInstallVehiclePart={isValid=function()calls.valid=calls.valid+1;return true end,
 complete=function(self)calls.complete=calls.complete+1;if self.mutate then return self.mutate(self) end;return 'native' end}
ISUninstallVehiclePart={complete=function(self)return self.mutate(self)end,isValid=function()calls.uninstall=calls.uninstall+1;return true end,
 new=function(self,c,p,t)return {part=p} end,
 derive=function(self)return setmetatable({},{__index=self}) end}
package.loaded['Vehicles/TimedActions/ISInstallVehiclePart']=true
package.loaded['Vehicles/TimedActions/ISUninstallVehiclePart']=true
require 'VLS_InstallGuard'
local a={part=part,item={}}
assert(ISInstallVehiclePart.isValid(a));assert(calls.valid==1)
allowed=false;assert(not ISInstallVehiclePart.complete(a));assert(calls.complete==0)
allowed=true;assert(ISInstallVehiclePart.complete(a)=='native');assert(calls.complete==1)
assert(ISUninstallVehiclePart.isValid(a));assert(calls.uninstall==1)
removable=false;assert(not ISUninstallVehiclePart.isValid(a));assert(calls.uninstall==1)
print('PASS shared installation policy and native delegation; queued-policy recheck; no native game acceptance')

-- Actual global native-action wrappers observe only real successful changes.
isClient=function()return false end
V.isManagedPart=function(p)return p.managed end
V.isPropaneTankPart=function(p)return p.propane end
local vehicle={sent=0,transmitPartModData=function(self)self.sent=self.sent+1 end}
local tracked={item=nil,data={},propane=true,getId=function()return "DAMNPropaneTankOne"end}
tracked.getVehicle=function()return vehicle end
tracked.getInventoryItem=function(self)return self.item end
tracked.getModData=function(self)return self.data end
local sameItem={}
local function install(self)self.part.item=sameItem;return true end
local function uninstall(self)self.part.item=nil;return true end
allowed=true;enabled=true;removable=true
assert(ISInstallVehiclePart.complete({part=tracked,item=sameItem,mutate=install}))
assert(tracked.data.vlsNativeEpoch==1)
assert(ISUninstallVehiclePart.complete({part=tracked,mutate=uninstall}))
assert(tracked.data.vlsNativeEpoch==2)
assert(ISInstallVehiclePart.complete({part=tracked,item=sameItem,mutate=install}))
assert(tracked.data.vlsNativeEpoch==3)
-- Existing callback already increments: observer must not increment twice.
assert(ISUninstallVehiclePart.complete({part=tracked,mutate=function(self)
 self.part.item=nil;self.part.data.vlsNativeEpoch=4;return true end}))
assert(tracked.data.vlsNativeEpoch==4)
assert(ISInstallVehiclePart.complete({part=tracked,item=sameItem,mutate=function()return false end})==false)
assert(tracked.data.vlsNativeEpoch==4)
-- Roof-only membership is recognized without any interior profile grant.
VLSRoofCargo={vehicleScripts={["Base.VanSeats"]=true}}
vehicle.getScript=function()return {getFullName=function()return "Base.VanSeats"end}end
tracked.propane=false;tracked.getId=function()return "VLSRoofPetrol1"end
assert(ISInstallVehiclePart.complete({part=tracked,item=sameItem,mutate=install}))
assert(tracked.data.vlsNativeEpoch==5)
tracked.getId=function()return "UnrelatedPart"end
assert(ISUninstallVehiclePart.complete({part=tracked,mutate=uninstall}))
assert(tracked.data.vlsNativeEpoch==5)
print('PASS actual native transaction wrappers advance managed/propane/roof identities once; no unrelated-part enrollment')
