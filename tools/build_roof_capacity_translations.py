"""Generate only the reviewed rack capacity UI keys; keep other keys byte-stable."""
from pathlib import Path
import argparse, json, re

def build(root, check=False):
    root=Path(root)
    catalog=json.loads((root/'translations/vls-roof-capacity-ui.json').read_text(encoding='utf-8'))
    base=root/'workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/Translate'
    for group, entries in catalog['groups'].items():
        for lang in catalog['languages']:
            path=base/lang/group
            text=path.read_text(encoding='utf-8')
            values=json.loads(text)
            for key, row in entries.items():
                assert key in values and row[lang].strip(), key
                if check:
                    assert values[key]==row[lang], str(path)+': '+key
                else:
                    pattern=r'("'+re.escape(key)+r'"\s*:\s*)"(?:[^"\\]|\\.)*"'
                    text,n=re.subn(pattern,lambda m:m[1]+json.dumps(row[lang],ensure_ascii=False),text)
                    assert n==1, key
            if not check: path.write_text(text,encoding='utf-8')
    print('ROOF_CAPACITY_UI_OK: 2 keys x 3 locales')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument('--check',action='store_true')
    a=p.parse_args();build(a.repo,a.check)
