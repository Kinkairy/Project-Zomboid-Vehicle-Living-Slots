#!/usr/bin/env python3
"""Expand the self-contained delta bundle to eight complete candidate files.

Writes only this handoff directory's files/. Does not modify workshop/, use the
network, deploy, restart, back up or migrate a save. Requires Python 3 and Git.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile
import sys

HERE = Path(__file__).resolve().parent

def digest(data):
    return hashlib.sha256(data).hexdigest()

def safe_path(root, relative):
    rel = Path(relative)
    path = (root / rel).resolve()
    if rel.is_absolute() or '..' in rel.parts or root not in path.parents:
        raise ValueError('Invalid bundle path: ' + relative)
    return path

def main():
    spec = json.loads((HERE / 'manifest.json').read_text(encoding='utf-8'))
    if spec.get('schema') != 1 or len(spec.get('files', [])) != 8:
        raise ValueError('Unsupported or incomplete manifest')
    patch = HERE / 'changes.patch'
    # Git checkouts may convert text line endings. Normalize text inputs only.
    patch_bytes = patch.read_bytes().replace(b'\r\n', b'\n')
    if digest(patch_bytes) != spec['patch_sha256']:
        raise ValueError('Patch checksum mismatch')
    payload = []
    with tempfile.TemporaryDirectory(prefix='vls-batch-') as tmp:
        stage = Path(tmp).resolve()
        staged_patch = stage / 'changes.patch'
        staged_patch.write_bytes(patch_bytes)
        for entry in spec['files']:
            source = safe_path((HERE / 'baseline').resolve(), entry['path'])
            data = source.read_bytes().replace(b'\r\n', b'\n')
            if digest(data) != entry['before_sha256']:
                raise ValueError('Baseline checksum mismatch: ' + entry['path'])
            target = safe_path(stage, entry['path'])
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        for arguments in [['--check'], []]:
            subprocess.run(['git', 'apply', *arguments, str(staged_patch)],
                           cwd=stage, check=True, capture_output=True)
        for entry in spec['files']:
            data = safe_path(stage, entry['path']).read_bytes()
            if digest(data) != entry['after_sha256']:
                raise ValueError('Candidate checksum mismatch: ' + entry['path'])
            output = safe_path((HERE / 'files').resolve(), entry['path'])
            if output.exists() and output.read_bytes().replace(b'\r\n', b'\n') != data:
                raise ValueError('Existing output differs; not overwritten: ' + str(output))
            payload.append((output, data, entry['path']))
    for output, data, relative in payload:
        output.parent.mkdir(parents=True, exist_ok=True)
        if not output.exists():
            output.write_bytes(data)
        if output.read_bytes().replace(b'\r\n', b'\n') != data:
            raise OSError('Output verification failed: ' + relative)
        print('VERIFIED ' + relative)
    print('READY 8/8 complete candidate files in handoff files/; project workshop/ unchanged.')
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        print('ERROR ' + str(exc), file=sys.stderr)
        sys.exit(2)
