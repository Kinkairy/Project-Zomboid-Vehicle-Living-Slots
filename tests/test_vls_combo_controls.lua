local root,native=assert(arg[1]),assert(arg[2])
local path=root.."/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/"
local Base={}
function Base:derive(name)local c={Type=name};c.__index=c;return setmetatable(c,{__index=self})end
function Base:new()return setmetatable({},{__index=self})end
function Base:getButtonControl(text)return {text=text,target=self}end
function Base:addJoypadContextMenuOption(ctx,text)local o={text=text};ctx[#ctx+1]=o;return o end
ISLootWindowObjectControlHandler=Base
package.loaded["ISUI/LootWindow/ISLootWindowObjectControlHandler"]=true
for _,name in ipairs({"CombinationWasherDryerToggle","CombinationWasherDryerSetMode"})do
 dofile(native.."/client/ISUI/LootWindow/Handlers/"..name..".lua")
end
local data={}
local equipment={getID=function()return 11 end}
local vehicle={kind="BaseVehicle",getId=function()return 7 end}
local part={getId=function()return "SeatBed" end,getModData=function()return data end,
 getInventoryItem=function()return equipment end,getVehicle=function()return vehicle end}
local container={getVehiclePart=function()return part end}
part.getItemContainer=function()return container end
local player={getVehicle=function()return vehicle end}
local core={getGameMode=function()return "Sandbox" end}
getCore=function()return core end
getText=function(key)return key end
instanceof=function(o,t)return o and o.kind==t end
ContainerButtonIcons={clothingwasher="washer-icon",clothingdryer="dryer-icon"}
VLS={getInstalledPart=function(v,id)return v==vehicle and id=="SeatBed" and part or nil end,
 getEquipmentCapability=function()return "laundryCombo" end,
 getLaundryMode=function()return data.vlsLaundryMode or "laundryWasher" end,
 hasAuxBatteryPower=function()return true end,getLaundryDrainPerMinute=function()return .0004 end,
 getInstalledWaterTank=function()return nil end}
local commands={}
local f=assert(io.open(path.."client/VLS_Client.lua"));local source=f:read("*a");f:close()
source=assert(source:match("(local function getLootLaundry.-)%-%- AddHandler updates"))
local env=setmetatable({sendApplianceCommand=function(p,command,args)commands[#commands+1]={command=command,args=args}end},{__index=_G,__newindex=_G})
local load=assert(loadstring(source));setfenv(load,env);load()
local toggle=ISLootWindowObjectControlHandler_VLSLaundryToggle:new()
local mode=ISLootWindowObjectControlHandler_VLSLaundryMode:new()
for _,handler in ipairs({toggle,mode})do handler.object=vehicle;handler.container=container;handler.playerObj=player end
local n=0
local function test(name,fn)fn();n=n+1;print("PASS "..name)end
test("native buttons and joypad use one combo mode from the actual vehicle",function()
 assert(toggle:shouldBeVisible());assert(mode:shouldBeVisible())
 assert(toggle:getControl().text=="ContextMenu_Turn_On")
 assert(mode:getControl().text=="ContextMenu_ComboWasherDryer_SetModeDryer")
 local ctx={};mode:handleJoypadContextMenu(ctx);assert(ctx[1].iconTexture=="washer-icon")
 data.vlsLaundryMode="laundryDryer";data.vlsLaundryActive=true
 assert(toggle:getControl().text=="ContextMenu_Turn_Off")
 assert(mode:getControl().text=="ContextMenu_ComboWasherDryer_SetModeWasher")
 assert(mode:getControl().target==mode);assert(mode.object==vehicle)
end)
test("controls send descriptors without applying a second local simulation",function()
 mode:perform();assert(commands[1].command=="setLaundryMode");assert(commands[1].args.mode=="washer")
 assert(commands[1].args.item==11);assert(data.vlsLaundryMode=="laundryDryer")
 toggle:perform();assert(commands[2].command=="toggleLaundry");assert(commands[2].args.active==false)
 assert(data.vlsLaundryActive==true)
end)
test("native UI errors restore the real vehicle identity",function()
 local nativeHandler=ISLootWindowObjectControlHandler_CombinationWasherDryerSetMode
 local old=nativeHandler.getControl;nativeHandler.getControl=function()error("native UI fault")end
 assert(not pcall(mode.getControl,mode));assert(mode.object==vehicle);nativeHandler.getControl=old
end)
test("unrelated containers, exiting the vehicle and tutorials hide both controls",function()
 mode.container={getVehiclePart=function()return part end};assert(not mode:shouldBeVisible());mode.container=container
 player.getVehicle=function()return nil end;assert(not mode:shouldBeVisible());local before=#commands;mode:perform();assert(#commands==before)
 player.getVehicle=function()return vehicle end;core.getGameMode=function()return "Tutorial" end;assert(not mode:shouldBeVisible())
end)
print("RESULT native combo inventory controls="..n.." failures=0")
