"""Verify the complete 3.8.3 runtime, identities and translation parity offline."""
from pathlib import Path
import argparse, hashlib, json, re

def verify(root):
    root=Path(root)
    spec=json.loads((root/'release-3.8.3.json').read_text(encoding='utf-8'))
    assert spec['version']=='3.8.3' and spec['workshop_item']=='3791192579'
    base=root/'workshop/Contents/mods'
    expected=spec['files'];actual={}
    for p in base.rglob('*'):
        assert not p.is_symlink(), str(p)
        if p.is_file(): actual[p.relative_to(base).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    assert actual==expected, 'Runtime hash/file set mismatch: '+str(sorted(k for k in set(actual)|set(expected) if actual.get(k)!=expected.get(k)))
    assert len(actual)==197 and len({k.casefold() for k in actual})==197
    for mod in ('VehicleLivingSlots','VehicleLivingSlotsKI5Campers'):
        for entry in ('mod.info','42.20/mod.info'):
            text=(base/mod/entry).read_text(encoding='utf-8-sig')
            assert re.search(r'^id='+mod+r'\s*$',text,re.M)
            assert re.search(r'^modversion=3\.8\.3\s*$',text,re.M)
        trans=base/mod/'common/media/lua/shared/Translate'
        en={p.name for p in (trans/'EN').glob('*.json')}
        for lang in ('CN','CH'): assert {p.name for p in (trans/lang).glob('*.json')}==en
        for group in en:
            tables={lang:json.loads((trans/lang/group).read_text(encoding='utf-8-sig')) for lang in ('EN','CN','CH')}
            for lang,t in tables.items():
                assert t.keys()==tables['EN'].keys(), f'{mod}/{lang}/{group}: key parity'
                for key,text in t.items():
                    assert isinstance(text,str) and text.strip(), key
                    assert sorted(re.findall(r'%\d+|%[sdif]',text))==sorted(re.findall(r'%\d+|%[sdif]',tables['EN'][key])), key
    print('RELEASE_3.8.3_OK | runtime_files=197 | all hashes, IDs, versions and locale keys/placeholders agree')
    return spec
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[1])
    verify(parser.parse_args().repo)
