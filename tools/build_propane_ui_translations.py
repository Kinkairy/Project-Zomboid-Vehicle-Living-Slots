"""Generate/check only the propane-owned key; preserve all unrelated UI text."""
import argparse
import json
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    spec = json.loads((args.repo / "translations/vls-propane-ui.json").read_text(encoding="utf-8"))
    for lang in spec["languages"]:
        path = args.repo / "workshop/Contents/mods" / spec["mod"] / spec["output"].format(language=lang)
        current = json.loads(path.read_text(encoding="utf-8"))
        for key, row in spec["entries"].items():
            assert set(row) == set(spec["languages"]) and all(row.values()), key
            if args.check:
                assert current.get(key) == row[lang], f"{lang}:{key}"
            else:
                current[key] = row[lang]
        if not args.check:
            path.write_text(json.dumps(current, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("PROPANE_TRANSLATIONS_OK")

if __name__ == "__main__":
    main()
