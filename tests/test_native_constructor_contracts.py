"""Actual game Kahlua + NetTimedAction argument capture. Not live gameplay."""
import argparse, pathlib, subprocess, shutil
p=argparse.ArgumentParser()
p.add_argument('--mod-root',type=pathlib.Path,required=True)
p.add_argument('--game-root',type=pathlib.Path,required=True)
p.add_argument('--work-dir',type=pathlib.Path,required=True)
p.add_argument('--javac',default='javac')
p.add_argument('--compiler-classpath')
p.add_argument('--java-system')
p.add_argument('--old-menu',type=pathlib.Path)
a=p.parse_args();a.work_dir.mkdir(parents=True,exist_ok=True)
source=pathlib.Path(__file__).resolve().parent
runtime=a.mod_root/'workshop/Contents/mods/VehicleLivingSlots/common/media/lua'
fixture=r"""
ISBaseTimedAction={}
function ISBaseTimedAction:derive(name) local c={Type=name};setmetatable(c,self);self.__index=self;return c end
function ISBaseTimedAction:new(character) local o={character=character};setmetatable(o,self);self.__index=self;return o end
function ISBaseTimedAction:isUsingTimeout()return true end
VLSPantry={uiSources={}}
local recipe={isCanWalk=function()return false end,getTimedActionScript=function()end}
function VLSPantry.recipe(choice)if choice=="toast" then return recipe end end
function VLSPantry.carriedContainers()return {} end
function require(name)if name=="VLS_Pantry" then return VLSPantry elseif name=="VLS_Config" then return {} end end
function log()end
DebugType={CraftLogic=1};CharacterTrait={ALL_THUMBS=1}
"""
native=(a.game_root/'media/lua/shared/Entity/TimedActions/ISHandcraftAction.lua').read_text()
fixture+='\ndo\n'+native+'\nend\nfunction ISHandcraftAction:getDuration()return 10 end\n'
action=(runtime/'shared/VLS_PantryCraftAction.lua').read_text().removesuffix('return VLSPantryCraftAction\n')
fixture+='\ndo\n'+action+'\nend\n'
menu=(a.old_menu or runtime/'client/VLS_PantryMenu.lua').read_text()
start=menu.index('    local nativeNew = ISHandcraftAction.new')
end=menu.index('\nend\n\nlocal function addPantrySlices',start)
fixture+='\ndo\nlocal P=VLSPantry\n'+menu[start:end]+'\nend\n'
fixture+=r"""
local character={hasTrait=function()return false end,isWearingAwkwardGloves=function()return false end}
ordinaryAction=ISHandcraftAction:new(character,recipe,{},"original-world-object","original-bench",{},nil,nil,0.5,0.25)
for _,value in ipairs({false,{}})do
 local a=VLSPantryCraftAction:new(character,17,"VLSPantryCoffee",43,"toast",value,nil,nil)
 assert(value and a.manualInputs or not value and a.manualInputs==nil)
end
pantryAction=VLSPantryCraftAction:new(character,17,"VLSPantryCoffee",43,"toast",nil,nil,nil)
HandcraftLogic={new=function()return {ping=function()return "engine-logic" end}end}
local originalConstructor=HandcraftLogic.new
local originalMeta=getmetatable(pantryAction)
pantryAction:withNativeLogic(function(action)
 assert(action==pantryAction)
 assert(HandcraftLogic.new==originalConstructor)
 action.logic=HandcraftLogic.new()
 assert(action.logic:ping()=="engine-logic")
 assert(HandcraftLogic.new():ping()=="engine-logic")
 action.nativeState=42
end)
assert(getmetatable(pantryAction)==originalMeta and pantryAction.nativeState==42)
local previousLogic=pantryAction.logic
local ok=pcall(function()pantryAction:withNativeLogic(function(action)
 assert(action==pantryAction and HandcraftLogic.new==originalConstructor)
 error("injected native failure")
end)end)
assert(not ok and getmetatable(pantryAction)==originalMeta)
assert(pantryAction.logic==previousLogic and HandcraftLogic.new==originalConstructor)
print("PASS actual Kahlua action-local interception and failure restoration")
"""
(a.work_dir/'probe.lua').write_text(fixture)
shutil.copyfile(next(a.game_root.rglob('stdlib.lua')),a.work_dir/'stdlib.lua')
java=str(a.game_root/'jre64/bin/java')
compile=([java,'-cp',a.compiler_classpath,'com.sun.tools.javac.Main'] if a.compiler_classpath else [a.javac])
if a.java_system:compile+=['--system',a.java_system]
subprocess.run(compile+['-d',str(a.work_dir),str(source/'NativeConstructorProbe.java')],check=True)
result=subprocess.run([java,'-Duser.home='+str(a.work_dir),'-cp',str(a.game_root/'java/projectzomboid.jar')+':'+str(a.work_dir),'NativeConstructorProbe',str(a.work_dir/'probe.lua')],cwd=a.work_dir,text=True,capture_output=True)
print(result.stdout,end='');print(result.stderr,end='')
if a.old_menu:
 assert result.returncode!=0 and 'ordinaryAction lost craftRecipe' in result.stderr,'Old constructor did not reproduce the expected serialization regression'
 print('PASS old constructor reproduces missing craftRecipe in real NetTimedAction')
else:result.check_returncode()
