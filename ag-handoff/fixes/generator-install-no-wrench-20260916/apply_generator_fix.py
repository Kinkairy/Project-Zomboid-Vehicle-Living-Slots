#!/usr/bin/env python3
"""Apply the narrow VLS roof-generator install fix to a SOURCE checkout.

Default: validate and print the diff without writing. --apply writes three
verified source files. Does not deploy, start/stop games, or change saves.
Python 3.9+, standard library only. Supports the reviewed source blob hashes;
refuses unknown source revisions rather than overwriting newer work.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

PREFIX = "workshop/Contents/mods/VehicleLivingSlots/common/media/"
EXPECTED = {
    PREFIX + "scripts/VLS_VehicleRoofAdapters.txt": "a4c4b5aea8dd30bca41fb4b265f9c9e6d4645600",
    PREFIX + "scripts/VLS_StepVanRoofRackAdjustment.txt": "7b4b26309b5ce97d03a033576762703159e57ecb",
    PREFIX + "lua/shared/VLS_RoofCargo.lua": "856ed3d50f367a3a9f2ad980120e03fba038cceb",
}
OLD_ITEMS = """                items
                {
                    1 { tags = base:wrench, count = 1, keep = true, equip = primary, }
                }
"""
NEW_ITEMS = """                /* The generator occupies both hands; no install tool is required. */
"""
OLD_SERVER = """    if isServer() then return part:getVehicle()==vehicle and R.serverCargoToolsReady(chr,part) end
"""
NEW_SERVER = """    if isServer() then
        if not chr or chr:isDead() or part:getVehicle()~=vehicle then return false end
        -- Only installation is tool-free. UninstallTest still checks the wrench.
        if part:getId()=="VLSRoofGenerator" then return true end
        return R.serverCargoToolsReady(chr,part)
    end
"""
OLD_COMMENT = "-- All current cargo tables require one kept wrench; legacy retrieval needs none."
NEW_COMMENT = "-- Cargo removal still needs a wrench; generator installation skips it below."


def git_blob_sha(text: str) -> str:
    raw = text.encode("utf-8")
    return hashlib.sha1(b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw).hexdigest()


def once(text: str, old: str, new: str) -> str:
    count = text.count(old)
    if count != 1:
        raise ValueError(f"Expected exactly one match, found {count}: {old[:100]!r}")
    return text.replace(old, new, 1)


def block_span(text: str, header: str) -> tuple[int, int]:
    """Return a unique script block. Ignore braces in comments and strings."""
    hits = list(re.finditer(r"(?m)^\s*" + re.escape(header) + r"\s*\{", text))
    if len(hits) != 1:
        raise ValueError(f"Expected exactly one {header!r} block, found {len(hits)}")
    start = text.index("{", hits[0].start())
    token = re.compile(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\{|\}', re.S)
    depth = 0
    for match in token.finditer(text, start):
        if match.group() == "{":
            depth += 1
        elif match.group() == "}":
            depth -= 1
            if depth == 0:
                return start, match.end()
    raise ValueError(f"Unclosed block {header!r}")


def patch_script(text: str, template: str, reverse: bool = False) -> str:
    tbegin, tend = block_span(text, "template vehicle " + template)
    body = text[tbegin:tend]
    begin, end = block_span(body, "part VLSRoofGenerator")
    part = body[begin:end]
    ibegin, iend = block_span(part, "table install")
    install = part[ibegin:iend]
    old, new = (NEW_ITEMS, OLD_ITEMS) if reverse else (OLD_ITEMS, NEW_ITEMS)
    install = once(install, old, new)
    # Keep the generator types, rack prerequisite, models, skill and duration.
    updated_part = part[:ibegin] + install + part[iend:]
    ubegin, uend = block_span(part, "table uninstall")
    vbegin, vend = block_span(updated_part, "table uninstall")
    if part[ubegin:uend] != updated_part[vbegin:vend]:
        raise ValueError("Generator uninstall table changed unexpectedly")
    updated_body = body[:begin] + updated_part + body[end:]
    return text[:tbegin] + updated_body + text[tend:]


def patch_lua(text: str, reverse: bool = False) -> str:
    a = text.index("function R.InstallTest(vehicle,part,chr)\n")
    b = text.index("function R.UninstallTest(vehicle,part,chr)\n", a)
    body = text[a:b]
    old, new = (NEW_SERVER, OLD_SERVER) if reverse else (OLD_SERVER, NEW_SERVER)
    body = once(body, old, new)
    updated = text[:a] + body + text[b:]
    old, new = (NEW_COMMENT, OLD_COMMENT) if reverse else (OLD_COMMENT, NEW_COMMENT)
    return once(updated, old, new)


def transform(path: str, text: str, reverse: bool = False) -> str:
    if path.endswith(".lua"):
        return patch_lua(text, reverse)
    template = "VLSRoofReusableParts" if path.endswith("VLS_VehicleRoofAdapters.txt") else "VLSRoofCargoTemplate"
    return patch_script(text, template, reverse)


def prepare(root: Path) -> list[tuple[Path, bytes, bytes, str]]:
    changes = []
    for rel, expected in EXPECTED.items():
        path = root / rel
        if path.is_symlink() or root not in path.resolve().parents:
            raise ValueError(f"Refusing symlink/outside-source path: {rel}")
        before = path.read_bytes()
        bom = before.startswith(b"\xef\xbb\xbf")
        decoded = before.decode("utf-8-sig")
        eol = "\r\n" if "\r\n" in decoded else "\n"
        text = decoded.replace("\r\n", "\n")
        if git_blob_sha(text) == expected:
            after_text = transform(rel, text)
        else:
            try:
                original = transform(rel, text, reverse=True)
            except ValueError:
                original = None
            if original is not None and git_blob_sha(original) == expected:
                print(f"ALREADY APPLIED: {rel}")
                continue
            raise ValueError(f"Unknown source content: {rel}\n"
                             f"Expected base blob {expected}, got {git_blob_sha(text)}.\n"
                             "No source files have been written. Review the newer source manually.")
        # Ensure the operation is lossless outside this exact edit.
        if transform(rel, after_text, reverse=True) != text:
            raise ValueError(f"Round-trip verification failed: {rel}")
        diff = "".join(difflib.unified_diff(text.splitlines(True), after_text.splitlines(True),
                                         fromfile="a/" + rel, tofile="b/" + rel))
        after = (b"\xef\xbb\xbf" if bom else b"") + after_text.replace("\n", eol).encode("utf-8")
        changes.append((path, before, after, diff))
    return changes


def write_changes(changes: list[tuple[Path, bytes, bytes, str]]) -> None:
    """Stage all writes and check for concurrent edits before replacing anything."""
    staged = []
    written = []
    try:
        for path, before, after, _ in changes:
            fd, tmp = tempfile.mkstemp(prefix=".vls-generator-", dir=path.parent)
            staged.append((path, Path(tmp)))
            with os.fdopen(fd, "wb") as out:
                out.write(after)
            os.chmod(tmp, path.stat().st_mode & 0o777)
        for path, before, _, _ in changes:
            if path.read_bytes() != before:
                raise ValueError(f"Concurrent edit detected: {path}")
        for path, tmp in staged:
            os.replace(tmp, path)
            written.append(path)
        for path, _, after, _ in changes:
            if path.read_bytes() != after:
                raise OSError(f"Read-back verification failed: {path}")
    except Exception:
        if written:
            print("WRITE DID NOT COMPLETE; inspect these already-written source files:", file=sys.stderr)
            for path in written:
                print(f"  {path}", file=sys.stderr)
        raise
    finally:
        for _, tmp in staged:
            tmp.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="VLS public SOURCE repository root")
    parser.add_argument("--apply", action="store_true", help="write the verified three-file source fix")
    args = parser.parse_args()
    root = args.repo.resolve()
    try:
        result = subprocess.run(["git", "-C", str(root), "rev-parse", "--show-toplevel"],
                                capture_output=True, text=True, check=True)
        if Path(result.stdout.strip()).resolve() != root:
            raise ValueError("--repo must identify the source repository root, not a runtime mod folder")
        changes = prepare(root)  # Validate every target before any writes.
        for _, _, _, diff in changes:
            print(diff, end="")
        if not changes:
            print("All three source changes are already applied. No writes.")
        elif args.apply:
            write_changes(changes)
            print(f"APPLIED: {len(changes)} source files; read-back verified.")
            print("Not deployed or game-tested. No Workshop, server, client or save operation performed.")
        else:
            print(f"CHECK ONLY: {len(changes)} files would change. Add --apply to write the source fix.")
        return 0
    except (OSError, UnicodeError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"STOP: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
