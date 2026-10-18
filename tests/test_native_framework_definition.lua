local root=assert(arg[1]);package.path=root..'/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/?.lua;'..package.path
local now=1000
getTimestampMs=function()return now end
local registeredSprite={registered=true}
getSprite=function(name)assert(name=='original_sprite');return registeredSprite end
local calls=0;local n=0;local count=1;local surface=true;local capacity=42
local function test(name,fn)fn();n=n+1;print('PASS '..name)end
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
instanceof=function(i,k)return i and i.moveable and k=='Moveable'end
local item={moveable=true,getWorldSprite=function()return 'original_sprite'end}
local container={getCapacity=function()return capacity end,getType=function()return 'original_container'end,
 getOpenSound=function()return 'original_open'end,getCloseSound=function()return nil end,
 getPutSound=function()return 'original_put'end,getTakeSound=function()return 'original_take'end}
IsoObject={new=function()
 calls=calls+1
 return {setSprite=function(self,s)assert(s==registeredSprite,"must pass registered IsoSprite object, not String");self.sprite=s end,getSprite=function(self)return self.sprite end,
 createContainersFromSpriteProperties=function()end,getContainerCount=function()return count end,
 getContainerByIndex=function(_,i)eq(i,0);return container end,isGenericCraftingSurface=function()return surface end}
end}
local D=require 'VLS_NativeDefinition'
test('capacity type sounds and surface come from native methods',function()
 local d=assert(D.cabinet(item));eq(d.capacity,42);eq(d.containerType,'original_container');eq(d.genericCraftSurface,true)
 eq(d.containerOpenSound,'original_open');eq(d.containerCloseSound,nil)
end)
test('metadata cache does not retain an object or cargo container',function()
 local d=D.cabinet(item);eq(calls,1)
 for _,v in pairs(d)do assert(type(v)~='table' and type(v)~='userdata')end
end)
test('native non-surface never gains a surface from VLS label',function()
 D.clearCache();surface=false;eq(D.cabinet(item).genericCraftSurface,false);surface=true
end)
test('zero native containers has its own diagnostic',function()
 D.clearCache();count=0;local d,r=D.cabinet(item);eq(d,nil);eq(r,'native_sprite_has_no_container');count=1
end)
test('zero count retries after bounded delay when native properties become ready',function()
 D.clearCache();count=0;local before=calls;eq(D.cabinet(item),nil);eq(calls,before+1)
 count=1;now=now+4999;eq(D.cabinet(item),nil);eq(calls,before+1)
 now=now+1;eq(D.cabinet(item).capacity,42);eq(calls,before+2)
end)
test('missing registered sprite can recover without manual cache reset',function()
 D.clearCache();local lookup=getSprite;getSprite=function()return nil end
 local d,r=D.cabinet(item);eq(d,nil);eq(r,'native_sprite_unavailable')
 getSprite=lookup;now=now+5000;assert(D.cabinet(item))
end)
test('multiple containers rejected rather than silently discarded',function()
 D.clearCache();count=2;local d,r=D.cabinet(item);eq(d,nil);eq(r,'requires_multi_container_host');count=1
end)
test('native exceptions do not create fallback fabricated definition',function()
 D.clearCache();local old=IsoObject.new;IsoObject.new=function()error('engine unavailable')end
 local d,r=D.cabinet(item);eq(d,nil);eq(r,'native_definition_probe_failed');IsoObject.new=old
end)
test('failed probe is cached within retry interval and explicit reset works',function()
 D.clearCache();local old=IsoObject.new;local failures=0
 IsoObject.new=function()failures=failures+1;error('engine unavailable')end
 for i=1,50 do eq(D.cabinet(item),nil) end
 eq(failures,1);D.clearCache();eq(D.cabinet(item),nil);eq(failures,2);IsoObject.new=old;D.clearCache()
end)
test('backwards clock permits one retry then throttles again',function()
 D.clearCache();count=0;now=100000;eq(D.cabinet(item),nil);local before=calls
 now=90000;eq(D.cabinet(item),nil);eq(calls,before+1)
 eq(D.cabinet(item),nil);eq(calls,before+1);count=1
end)
test('no clock does not create a per-frame retry loop',function()
 D.clearCache();count=0;local clock=getTimestampMs;getTimestampMs=nil
 eq(D.cabinet(item),nil);local before=calls
 for i=1,25 do eq(D.cabinet(item),nil)end;eq(calls,before)
 count=1;getTimestampMs=clock;assert(D.cabinet(item))
end)
test('invalid native container count is not labeled multi-container',function()
 D.clearCache();count=0/0;local d,r=D.cabinet(item);eq(d,nil);eq(r,'invalid_native_container_count');count=1
end)
test('registered object overload is required by mock negative control',function()
 local obj=IsoObject.new();local ok=pcall(function()obj:setSprite('original_sprite')end);eq(ok,false)
 obj:setSprite(registeredSprite);eq(obj:getSprite(),registeredSprite)
end)
test('no arbitrary nonmoveable item accepted',function()eq(D.cabinet({}),nil)end)
print('TOTAL '..n..' metadata stub tests; real native probe pending')
