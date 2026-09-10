#!/usr/bin/env python3
"""Apply the four-file RC3.8 cabinet fix. No backup/rollback, networking or restart.

Default is a preflight check. --write updates only recognized pre-fix files.
Already-fixed files are skipped, including mixed old/fixed directories.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent


def digest(data):
    return hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()


def within(root, relative):
    rel = Path(relative)
    path = (root / rel).resolve()
    if rel.is_absolute() or ".." in rel.parts or root not in path.parents:
        raise ValueError("Path outside selected root: " + relative)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mods-root", required=True, type=Path,
                        help="Directory containing VehicleLivingSlots and its KI5 adapter")
    parser.add_argument("--base-only", action="store_true",
                        help="Apply only the three base-mod files; do not touch KI5")
    parser.add_argument("--write", action="store_true",
                        help="Write after all selected files pass preflight")
    args = parser.parse_args()
    target_root = args.mods_root.resolve()
    if not target_root.is_dir():
        raise ValueError("Target mods directory does not exist: " + str(target_root))
    payload_root = (HERE / "files/workshop/Contents/mods").resolve()
    manifest = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schema") != 1:
        raise ValueError("Unsupported manifest schema")
    pending, errors, selected = [], [], 0
    for entry in manifest["files"]:
        relative = entry["path"]
        if args.base_only and relative.startswith("VehicleLivingSlotsKI5Campers/"):
            continue
        selected += 1
        source = within(payload_root, relative)
        target = within(target_root, relative)
        if not source.is_file() or not target.is_file():
            errors.append("Missing payload or target: " + relative)
            continue
        after = source.read_bytes()
        if digest(after) != entry["after_sha256"]:
            errors.append("Payload hash mismatch: " + relative)
            continue
        before = target.read_bytes()
        current = digest(before)
        if current == entry["after_sha256"]:
            print("ALREADY_FIXED " + relative)
        elif current == entry["before_sha256"]:
            pending.append((target, before, after, relative))
            print("READY " + relative)
        else:
            errors.append("Different source; do not overwrite: " + relative + " sha256=" + current)
    if errors:
        for error in errors:
            print("ERROR " + error, file=sys.stderr)
        print("PREFLIGHT_FAILED no files written", file=sys.stderr)
        return 2
    if not args.write:
        print("CHECK_OK selected=%d needs_update=%d no files written" % (selected, len(pending)))
        return 0
    written = 0
    for target, before, after, relative in pending:
        if target.read_bytes() != before:
            raise RuntimeError("File changed after preflight: " + relative)
        # Preserve target permissions/ownership. This is a source-file updater,
        # not a transaction/rollback system; do not edit the same files concurrently.
        count = target.write_bytes(after)
        if count != len(after) or target.read_bytes() != after:
            raise OSError("Write verification failed: " + relative)
        written += 1
        print("UPDATED " + relative)
    print("FILES_FIXED written=%d skipped=%d; game process was not changed or restarted" %
          (written, selected - written))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, RuntimeError) as exc:
        print("ERROR " + str(exc), file=sys.stderr)
        sys.exit(2)
