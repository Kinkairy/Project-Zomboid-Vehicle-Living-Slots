#!/usr/bin/env python3
"""Verify the reviewed candidate against the unchanged published baseline."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath


def fingerprint(files):
    return hashlib.sha256("".join(digest + "  " + path + "\n"
        for path, digest in sorted(files.items())).encode()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def safe_path(name):
    path = PurePosixPath(name)
    require(not path.is_absolute() and ".." not in path.parts
        and str(path) == name and "\\" not in name, "Invalid manifest path: " + name)
    return path


def read_manifest(root, name):
    safe_path(name)
    path = root / name
    require(not path.is_symlink(), "Manifest is a symlink: " + name)
    return path.read_bytes()


def validate(root, candidate_name="candidate-f700-0.1.0.json"):
    candidate = json.loads(read_manifest(root, candidate_name))
    require(candidate["schema"] == 1, "Unsupported candidate schema")
    require(candidate["status"] in ("source-candidate-not-deployed", "released"), "Unexpected candidate status")
    raw = read_manifest(root, candidate["published_manifest"])
    require(hashlib.sha256(raw).hexdigest() == candidate["published_manifest_sha256"],
        "Published manifest identity changed")
    published = json.loads(raw)
    require(fingerprint(published["files"]) == published["runtime_sha256"]
        == candidate["published_runtime_sha256"], "Published fingerprint mismatch")
    require(len(published["files"]) == published["file_count"], "Published file count mismatch")
    core = dict(published["files"])
    for path, change in candidate["core_overrides"].items():
        safe_path(path)
        require(path.startswith("VehicleLivingSlots/") and path in core,
            "Override outside the published core: " + path)
        require(core[path] == change["before"], "Override baseline mismatch: " + path)
        require(change["before"] != change["after"], "Redundant override: " + path)
        core[path] = change["after"]
    for path, change in candidate.get("adapter_overrides", {}).items():
        safe_path(path)
        require(path.startswith("VehicleLivingSlotsKI5Campers/") and path in core,
            "Override outside the published adapter: " + path)
        require(core[path] == change["before"], "Adapter override baseline mismatch: " + path)
        require(change["before"] != change["after"], "Redundant adapter override: " + path)
        core[path] = change["after"]
    addon = json.loads(read_manifest(root, candidate["addon_manifest"]))
    require(addon["mod_id"] == "VehicleLivingSlotsKI5F700", "Unexpected addon identity")
    require(fingerprint(addon["files"]) == addon["runtime_sha256"]
        == candidate["addon_runtime_sha256"], "Addon fingerprint mismatch")
    require(addon["files"] and all(path.startswith(addon["mod_id"] + "/")
        for path in addon["files"]), "Addon file outside its module")
    require(not (set(core) & set(addon["files"])), "Addon overlaps the published core")
    expected = dict(core)
    expected.update(addon["files"])
    require(len(expected) == candidate["file_count"], "Candidate file count mismatch")
    require(fingerprint(expected) == candidate["runtime_sha256"], "Candidate fingerprint mismatch")
    for path, digest in expected.items():
        safe_path(path)
        require(len(digest) == 64 and all(c in "0123456789abcdef" for c in digest),
            "Invalid SHA256: " + path)
    folder = root / "workshop/Contents/mods"
    actual = {}
    for path in folder.rglob("*"):
        require(not path.is_symlink(), "Runtime symlink: " + str(path.relative_to(folder)))
        if path.is_file():
            actual[path.relative_to(folder).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    changed = sorted(p for p in set(actual) & set(expected) if actual[p] != expected[p])
    require(not (missing or extra or changed),
        "Runtime mismatch: " + json.dumps({"missing": missing, "extra": extra, "changed": changed}))
    return {"files": core, "runtime_sha256": fingerprint(core)}, candidate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--candidate", default="candidate-f700-0.1.0.json")
    parser.add_argument("--core-manifest-output", type=Path,
        help="Export the verified core hashes for downstream boundary tests")
    args = parser.parse_args()
    core, candidate = validate(args.repo, args.candidate)
    if args.core_manifest_output:
        args.core_manifest_output.write_text(json.dumps(core, indent=2) + "\n")
    print("CANDIDATE_RUNTIME_PASS files=%d core_overrides=%d fingerprint=%s" % (
        candidate["file_count"], len(candidate["core_overrides"]), candidate["runtime_sha256"]))


if __name__ == "__main__":
    main()
