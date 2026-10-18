-- Actual original rest action and actual VLS menu/pending/action glue.
-- Actor, seating, animation and networking objects are mocks.
local root,native=assert(arg[1]),assert(arg[2]);local b=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/'
package.path=b..'shared/?.lua;'..native..'/shared/?.lua;'..package.path
loadstring=loadstring or load;unpack=unpack or table.unpack
ISBaseObject={};function ISBaseObject:derive(name)local c={Type=name};c.__index=c;return setmetatable(c,{__index=self})end
package.loaded.ISBaseObject=true
local noop=function()end;local server=false;isServer=function()return server end;isClient=function()return not server end
local f;local queued={};local enters,sleeps,resets=0,0,0
ISTimedActionQueue={queues={},add=function(a)queued[#queued+1]=a end,hasActionType=function()return false end,
 getTimedActionQueue=function()return {resetQueue=function()resets=resets+1 end,onCompleted=noop}end}
ISLogSystem={logAction=noop};SeatingManager={getInstance=function()return {getTilePositionCount=function()return 0 end}end}
CharacterStat={ENDURANCE=1};sendServerCommand=noop;emulateAnimEvent=noop
getSpecificPlayer=function()return f.c end;getPlayerData=function()return {}end
VLS={isSupportedVehicle=function(v)return v==f.v end,isManagedPart=function(p)return p==f.p end,
 isUsingBedSeat=function(c,v)return c.inside==v and c.seat==2 end,getInstalledBedPart=function()return f.p end,getInstalledBedPartForSeat=function(v,seat)return seat==2 and f.p or nil end,
 getBedSeat=function(v,p)return p==f.p and 2 or -1 end}
package.loaded.VLS_Config=true
local Context=require 'VLS_NativeContext';require 'VLS_VehicleRestAction'
local function fixture()
 local x={};local v,p,it,c={},{},{},{};x.v=v;x.p=p;x.it=it;x.c=c;x.data={vlsNativeEpoch=4}
 v.getId=function()return 17 end;v.getPartById=function(_,id)return id=='Bed' and p end;v.getSeat=function(_,who)return who.seat end;v.isStopped=function()return true end
 p.getVehicle=function()return v end;p.getId=function()return 'Bed' end;p.getInventoryItem=function()return it end;p.getModData=function()return x.data end;p.getItemContainer=function()return nil end
 it.getID=function()return 33 end
 c.getVehicle=function(self)return self.inside end;c.getPlayerNum=function()return 0 end;c.isDead=function()return false end;c.isAsleep=function()return false end
 c.GetVariable=function()return 'false' end;c.isResting=function(self)return self.resting end;c.setIsResting=function(self,r)self.resting=r end;c.setBed=function(self,bed)self.bed=bed end
 c.setVariable=noop;c.setIsFarming=noop;c.getStats=function()return {get=function()return .5 end}end
 f=x;queued={};return x
end
local function read(p)local h=assert(io.open(p));local s=h:read('*a');h:close();return s end
local function cut(s,a,z)local i=assert(s:find(a,1,true));local j=assert(s:find(z,i+#a,true));return s:sub(i,j-1)end
local src=read(b..'client/VLS_Client.lua')
ISVehicleMenu={onEnter=function()enters=enters+1 end,onSleep=function()sleeps=sleeps+1 end}
HaloTextHelper={addBadText=noop};getText=function(s)return s end
local make=assert(loadstring('return function(NativeContext,getReachableBed,getReachableBedVehicle,getSleepSlice) local pendingBedSleep,pendingBedRest={},{}\n'..
 cut(src,'local function enterBed','local function processBedState')..cut(src,'local function addBedSlices','local function addVLSSlices')..
 '\nreturn addBedSlices,processPendingBedRest,processPendingBedSleep,pendingBedRest,pendingBedSleep end'))
local function binding()
 return make()(Context,function()return f.p,2 end,function()return f.v,f.p,2 end,function()return 'Sleep',true end)
end
local function menu(add)
 local m={rows={}};function m:addSlice(label,icon,callback,...)self.rows[#self.rows+1]={callback=callback,args={...}}end;add(m,f.c);return m
end
local function click(m,i)local r=m.rows[i or 1];r.callback(unpack(r.args))end
local n=0;local function test(name,fn)fn();n=n+1;print('PASS '..name)end
local function eq(a,b)if a~=b then error(tostring(a)..' != '..tostring(b))end end
local roundtrip=dofile(root..'/tests/net_action_roundtrip.lua')
local function enterRest()
 local add,rest= binding();local m=menu(add);click(m);f.c.inside=f.v;f.c.seat=2;rest();return queued[1]
end
for _,index in ipairs({1,2})do test('stale menu rejects same-ID reinstallation '..index,function()
 fixture();local add=binding();local m=menu(add);local old=enters;f.data.vlsNativeEpoch=5;click(m,index);eq(enters,old);eq(#queued,0)
end)end
for _,index in ipairs({1,2})do test('pending entry rejects replaced generation '..index,function()
 fixture();local add,rest,sleep=binding();click(menu(add),index);f.data.vlsNativeEpoch=5;f.c.inside=f.v;f.c.seat=2
 local old=sleeps;rest();sleep();eq(#queued,0);eq(sleeps,old)
end)end
test('current pending binding survives walking and queues exact primitive token',function()
 fixture();local add,rest=binding();click(menu(add));rest();eq(#queued,0);f.c.inside=f.v;f.c.seat=2;rest();eq(#queued,1)
 local a=queued[1];eq(a.installationEpoch,4);eq(a.partId,'Bed');eq(a.installedItemId,33)
 server=true;local remote=roundtrip(ISVLSVehicleRestAction,b..'shared/VLS_VehicleRestAction.lua',a);eq(remote:isValid(),true);server=false
end)
test('same installation but wrong seat does not begin pending rest',function()
 fixture();local add,rest=binding();click(menu(add));f.c.inside=f.v;f.c.seat=1;rest();eq(#queued,0)
end)
test('native start and cleanup retained without nil furniture server start',function()
 fixture();local a=enterRest();eq(a:isValid(),true);a:start();eq(f.c.resting,true)
 server=true;a.netAction={forceComplete=function()error('unexpected cancel')end};a:serverStart();eq(f.c.resting,true);a:complete();eq(f.c.resting,false)
 eq(a.stop,ISRestAction.stop);eq(a.complete,ISRestAction.complete);eq(a.serverStop,ISRestAction.serverStop);server=false
end)
test('old rest direct serverStart/update rejects then native cleanup runs',function()
 fixture();local a=enterRest();f.data.vlsNativeEpoch=5;server=true;local stopped=0;a.netAction={forceComplete=function()stopped=stopped+1 end}
 a:serverStart();a:update();eq(stopped,2);eq(f.c.resting,nil);a:complete();eq(f.c.resting,false);server=false
end)
test('old client action stops through native queue cleanup',function()
 fixture();local a=enterRest();local old=resets;a.action={forceStop=function()a:stop()end};f.data.vlsNativeEpoch=5;a:update();eq(resets,old+1);eq(f.c.resting,false)
end)
test('current sleep still delegates original sleep callback once',function()
 fixture();local add,rest,sleep=binding();local old=sleeps;click(menu(add),2);f.c.inside=f.v;f.c.seat=2;sleep();sleep();eq(sleeps,old+1)
end)
test('server constructor missing identity cannot adopt current bed',function()
 fixture();f.c.inside=f.v;f.c.seat=2;server=true;local a=ISVLSVehicleRestAction:new(f.c);eq(a:isValid(),false);server=false
end)
print('RESULT bed identity tests='..n..' failures=0; mocked engine/seat/network; not live gameplay')
