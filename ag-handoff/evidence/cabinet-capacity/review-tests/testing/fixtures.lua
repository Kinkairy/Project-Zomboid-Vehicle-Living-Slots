-- Only API objects are mocked. Mod functions are read from the supplied evidence.
-- Initial capacity=20 is an injected condition, NOT a captured engine reload.
local clientMode = false
function isClient() return clientMode end
function ReviewSetClient(value) clientMode=value end
function isServer() return not clientMode end
function instanceof(value, name) return type(value)=='table' and value.class==name end
function getText(text) return text end
ContainerButtonIcons={}
VLSRoofCargo={isPart=function() return false end, allowed={}}
function require(name)
    if name=='VLS_Config' then return VLS end
    if name=='VLS_RoofCargo' then return VLSRoofCargo end
    if name=='Entity/TimedActions/ISHandcraftAction' or name=='TimedActions/ISDeviceBatteryAction' then return {} end
    error('Unexpected require: '..name)
end
Events={}
for _,name in ipairs({'OnClientCommand','EveryOneMinute'}) do
    local e={callbacks={}}
    e.Add=function(fn) e.callbacks[#e.callbacks+1]=fn end
    Events[name]=e
end
ReviewVehicles={}
function getVehicleById(id) return ReviewVehicles[id] end
function getGameTime() return {getWorldAgeHours=function() return 300 end} end
function ReviewMinute()
    for _,fn in ipairs(Events.EveryOneMinute.callbacks) do fn() end
end
local sequence=100
function ReviewFixture(types, scriptName)
    sequence=sequence+1
    local v={id=sequence,scriptName=scriptName or 'Base.Van',parts={},byId={},needUpdate=false}
    function v:getId() return self.id end
    function v:getScriptName() return self.scriptName end
    function v:getPartById(id) return self.byId[id] end
    function v:getPartCount() return #self.parts end
    function v:getPartByIndex(i) return self.parts[i+1] end
    function v:getDriverRegardlessOfTow() return nil end
    function v:setNeedPartsUpdate(value) self.needUpdate=value end
    function v:getSquare() return {} end
    function v:transmitPartItem() error('Unexpected item publication in this fixture') end
    function v:transmitPartModData() error('Unexpected modData publication in this fixture') end
    local profile=assert(VLS.getVehicleProfile(v),'Missing vehicle profile')
    for i,fullType in ipairs(types) do
        local c={capacity=20,writes=0,type='SeatBed',customTemperature=1,ageFactor=1,contents={{id=40000+i,weight=21}}}
        function c:getCapacity() return self.capacity end -- no occupied seats or traits in these tests
        function c:setCapacity(value) self.capacity=value;self.writes=self.writes+1 end
        function c:getCustomTemperature() return self.customTemperature end
        function c:setCustomTemperature(value) self.customTemperature=value end
        function c:getAgeFactor() return self.ageFactor end
        function c:setAgeFactor(value) self.ageFactor=value end
        function c:getCapacityWeight() local w=0;for _,x in ipairs(self.contents) do w=w+x.weight end;return w end
        for _,field in ipairs({'Type','OpenSound','CloseSound','PutSound','TakeSound'}) do
            local key=field:sub(1,1):lower()..field:sub(2)
            c['get'..field]=function(self) return self[key] end
            c['set'..field]=function(self,value) self[key]=value end
        end
        local item={id=1000+i,fullType=fullType,class='Moveable',condition=80}
        function item:getID() return self.id end
        function item:getFullType() return self.fullType end
        function item:getDisplayName() return self.fullType end
        function item:getCondition() return self.condition end
        function item:getConditionMax() return 100 end
        local p={id=profile.universalParts[i],vehicle=v,item=item,container=c,condition=80,data={vlsEquipmentItemId=item.id,vlsContainerProfileVersion=2,vlsMicrowaveActive=false}}
        function p:getVehicle() return self.vehicle end
        function p:getId() return self.id end
        function p:getInventoryItem() return self.item end
        function p:getItemContainer() return self.container end
        function p:getModData() return self.data end
        function p:getCondition() return self.condition end
        function c:getVehiclePart() return p end
        v.parts[#v.parts+1]=p;v.byId[p.id]=p
    end
    local chr={vehicle=v}
    function chr:getVehicle() return self.vehicle end
    ReviewVehicles[v.id]=v
    return v,chr
end
function ReviewEq(a,b,label)
    if a~=b then error((label or 'assertion')..': '..tostring(a)..' ~= '..tostring(b)) end
end
function ReviewCase(name,fn)
    fn()
    print('PASS '..name)
end
print('OFFLINE ONLY; interpreter='.._VERSION..'; mocked Java objects; no game, no network, no live save')
