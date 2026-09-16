"""Generate/check the washing-owned EN/CN/CH keys; retain unrelated native UI."""
import argparse
import json
from pathlib import Path

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--check',action='store_true')
    p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[1])
    a=p.parse_args()
    s=json.loads((a.repo/'translations/vls-wash-ui.json').read_text(encoding='utf-8'))
    for lang in s['languages']:
        path=a.repo/'workshop/Contents/mods'/s['mod']/s['output'].format(language=lang)
        current=json.loads(path.read_text(encoding='utf-8-sig'))
        for key,row in s['entries'].items():
            assert set(row)==set(s['languages']) and all(row.values()), key
            if a.check:assert current.get(key)==row[lang], f'{lang}:{key}'
            else:current[key]=row[lang]
        if not a.check:path.write_text(json.dumps(current,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('WASH_TRANSLATIONS_OK')
if __name__=='__main__':main()
