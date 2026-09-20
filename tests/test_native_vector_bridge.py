"""Execute coordinate adapters with the installed game Kahlua and real Vector2.
World/vehicle fixtures are isolated; this does not claim in-game acceptance.
"""
from pathlib import Path
import argparse, subprocess, shutil
parser=argparse.ArgumentParser()
parser.add_argument("--game-root",type=Path,required=True)
parser.add_argument("--javac",type=Path,required=True)
parser.add_argument("--work-dir",type=Path,required=True)
args=parser.parse_args()
args.work_dir.mkdir(parents=True,exist_ok=True)
tests=Path(__file__).resolve().parent
mod_root=tests.parents[1]/"mods/vehicle-living-slots"
if not mod_root.is_dir():mod_root=tests.parent  # standalone public source layout
base=mod_root/"workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared"
prefix='VLS={}\nVLSRoofCargo={vehicleScripts={["Base.StepVan"]=true}}\nISTakeFuel={new=function()end,derive=function(self)return setmetatable({},{__index=self})end}\nrequire=function()return VLS end\nlocal square={isFree=function()return true end}\ngetCell=function()return {getGridSquare=function(_,x,y,z)\n assert(x==10 and y==-3 and z==0,"wrong service square")\n return square\nend}end\nlocal part={getArea=function()return "TruckBed"end,getInventoryItem=function()\n return {getID=function()return 1 end,getFullType=function()return "Base.PetrolCan"end,getFluidContainer=function()return {}end}\nend}\nlocal vehicle={getAreaCenter=function()return nativeCenter end,getZ=function()return .25 end,\n getPartById=function()return part end,getScript=function()return {getFullName=function()return "Base.StepVan"end}end}\nassert(nativeCenter.x==nil and nativeCenter.y==nil)\nassert(nativeCenter:getX()==10.75 and nativeCenter:getY()==-2.25)\n'
suffix='assert(G.serviceSquare(vehicle,part)==square)\nassert(F.source(vehicle,1,-1,-1):getSquare()==square)\nvehicle.getAreaCenter=function()return nil end\nassert(G.serviceSquare(vehicle,part)==nil)\nassert(F.source(vehicle,1,-1,-1):getSquare()==nil)\nreturn "NATIVE_VECTOR_FIXED_4_CASES"\n'
code=prefix+"\nlocal G=(function()\n"+(base/"VLS_Generator.lua").read_text()+"\nend)()\nlocal F=(function()\n"+(base/"VLS_RoofFuel.lua").read_text()+"\nend)()\n"+suffix
script=args.work_dir/"native-vector.lua";script.write_text(code)
shutil.copyfile(args.game_root/"stdlib.lua",args.work_dir/"stdlib.lua")
subprocess.run([str(args.javac),"-d",str(args.work_dir),str(tests/"NativeVectorProbe.java")],check=True)
subprocess.run([str(args.game_root/"jre64/bin/java"),"-Duser.home="+str(args.work_dir),"-cp",str(args.game_root/"java/*")+":"+str(args.work_dir),"NativeVectorProbe",str(script)],cwd=args.work_dir,check=True)
