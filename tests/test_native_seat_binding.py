"""Run the real F700 script/part binding fixture without a world or player."""
import argparse,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--game-root',type=Path,required=True)
p.add_argument('--javac',required=True)
p.add_argument('--work-dir',type=Path,required=True)
a=p.parse_args();root=Path(__file__).resolve().parents[1]
a.work_dir.mkdir(parents=True,exist_ok=True)
module=root/'workshop/Contents/mods/VehicleLivingSlotsKI5F700/common/media/lua/shared/VLS_KI5F700_Seats.lua'
source=module.read_text();assert ']====]' not in source
fixture='VehicleScript={new=newVehicleScript}\nmoduleSource=[====['+source+']====]\n'+(root/'tests/test_vls_f700_native_binding.lua').read_text()
script=a.work_dir/'probe.lua';script.write_text(fixture)
(a.work_dir/'stdlib.lua').write_bytes((a.game_root/'java/stdlib.lua').read_bytes())
subprocess.run([a.javac,'-d',str(a.work_dir),str(root/'tests/NativeSeatBindingProbe.java')],check=True)
q=subprocess.run([str(a.game_root/'jre64/bin/java'),'-Duser.home='+str(a.work_dir/'user'),'-cp',str(a.game_root/'java/*')+':'+str(a.work_dir),'NativeSeatBindingProbe',str(script)],cwd=a.work_dir,capture_output=True,text=True,timeout=60)
(a.work_dir/'stdout').write_text(q.stdout);(a.work_dir/'stderr').write_text(q.stderr)
print(q.stdout.strip())
if q.returncode:print(q.stderr[-2500:])
assert q.returncode==0 and 'NATIVE_KAHLUA_BINDING_PASS checks=144' in q.stdout
