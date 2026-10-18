"""Static contract: only VLS universal containers have no synthetic trunk sounds."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]/'workshop/Contents'
universal=weapon=0
for p in root.glob('mods/*/common/media/scripts/*'):
 if not p.is_file(): continue
 s=p.read_text()
 for m in re.finditer(r'\bcontainer\s*\{',s):
  depth=1;i=m.end()
  while depth and i<len(s): depth+=(s[i]=='{')-(s[i]=='}');i+=1
  block=s[m.start():i]
  if 'test = VLS.ContainerAccess.UniversalSlot' in block:
   universal+=1
   assert not re.search(r'soundMap\s*=',block),str(p)
  if 'test = VLS.ContainerAccess.WeaponLocker' in block:
   weapon+=1
   for key in ['ContainerPut','ContainerTake']:
    assert 'soundMap = '+key+' VehicleTrunkTransferItem,' in block,str(p)
assert universal==35,universal
assert weapon==4,weapon
print('PASS 35 universal containers have no script sound fallback; 4 weapon containers retain both original maps')
