#!/usr/bin/env python3
"""Generate KI5 adapter UI locales from one reviewed catalog (default: check only)."""
import argparse
import json
from pathlib import Path


def generate(repo, write=False):
    catalog = json.loads((repo / 'translations/ki5-campers-ui.json').read_text(encoding='utf-8'))
    assert catalog['schema'] == 1
    languages = ('EN', 'CN', 'CH')
    assert catalog['languages'] == list(languages)
    entries = catalog['entries']
    for key, texts in entries.items():
        assert key.startswith('IGUI_') and set(texts) == set(languages)
        assert all(isinstance(v, str) and v.strip() for v in texts.values())
    root = repo / 'workshop/Contents/mods/VehicleLivingSlotsKI5Campers'
    for language in languages:
        path = root / ('common/media/lua/shared/Translate/' + language + '/IG_UI.json')
        expected = (json.dumps({k: v[language] for k, v in entries.items()}, ensure_ascii=False, indent=4) + '\n').encode('utf-8')
        if write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
        if path.read_bytes() != expected:
            raise ValueError('Catalog/runtime mismatch: ' + str(path))
    return len(entries)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    print('KI5_UI_CATALOG_OK: %d keys x 3 locales' % generate(args.repo, args.write))
