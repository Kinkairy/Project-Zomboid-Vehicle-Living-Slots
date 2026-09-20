#!/usr/bin/env python3
"""Generate/check all VLS runtime locales from the reviewed canonical catalog."""
import argparse,json
from pathlib import Path

def build(root,write=False):
    doc=json.loads((root/'translations/catalog.json').read_text())
    groups={}
    for row in doc['entries']:
        assert row['reviewed'] is True,row['key']
        for template in row.get('runtime_groups',[row['runtime_group']]):
            for locale in doc['languages']:
                group=template.replace('{LOCALE}',locale)
                groups.setdefault(group,{})[row['key']]=row[locale.lower()]
    for group,expected in groups.items():
        path=root/group
        current=json.loads(path.read_text(encoding='utf-8-sig')) if path.exists() else None
        if current!=expected:
            if not write:raise ValueError('Catalog/runtime mismatch: '+group)
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_text(json.dumps(expected,ensure_ascii=False,indent=2)+'\n')
    metadata=json.loads((root/'translations/workshop-description.json').read_text())
    assert metadata['reviewed'] is True
    expected='description='+'[hr]'.join(metadata['descriptions'][key] for key in ('CN','CH','EN'))
    path=root/'workshop/workshop.txt';lines=path.read_text().splitlines()
    actual=[line for line in lines if line.startswith('description=')]
    if actual!=[expected]:
        if not write:raise ValueError('Workshop description differs from reviewed catalog')
        path.write_text('\n'.join(expected if line.startswith('description=') else line for line in lines)+'\n')
    return len(doc['entries']),len(groups)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--write',action='store_true')
    a=p.parse_args();print('VLS_TRANSLATIONS_OK keys=%d files=%d'%build(a.repo,a.write))
