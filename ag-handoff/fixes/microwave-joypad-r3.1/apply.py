#!/usr/bin/env python3
"""Generate/apply ONLY the microwave A/B dispatch fix in an existing strict-R3 source."""
import argparse
import hashlib
from pathlib import Path
import sys

REL = 'workshop/Contents/mods/VehicleLivingSlots/common/media/lua/client/VLS_Client.lua'
OLD = "-- The native microwave handler calls the parent (which forceClicks A/B)\n-- and then calls onClick again. Use the parent's one-dispatch path only.\nlocal function onVLSMicrowaveJoypadDown(ui, button, joypadData)\n    return ISPanelJoypad.onJoypadDown(ui, button, joypadData)\nend"
NEW = '-- VLS_MICROWAVE_PAD_R31: honour the A/B shortcuts before focused knobs.\n-- The generic parent consumes A on the focused knob (or another button).\n-- Dispatch the intended button once; forceClick keeps its enabled/visible checks.\nlocal function onVLSMicrowaveJoypadDown(ui, button, joypadData)\n    if button == Joypad.AButton then\n        if ui.ok then ui.ok:forceClick() end\n        return\n    end\n    if button == Joypad.BButton then\n        if ui.close then ui.close:forceClick() end\n        return\n    end\n    return ISPanelJoypad.onJoypadDown(ui, button, joypadData)\nend'


def fixed_source(text):
    if 'print("[VLS strict-r3] client loaded; current commands only")' not in text:
        raise ValueError("Expected the strict-R3 client. Do not apply to an older protocol build.")
    if text.count(NEW) == 1 and OLD not in text:
        return text, False
    if text.count(OLD) != 1 or 'VLS_MICROWAVE_PAD_R31' in text:
        raise ValueError("The handler differs from R3; review changes.patch instead of overwriting unrelated edits.")
    return text.replace(OLD, NEW, 1), True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path.cwd(), help='Project source root, not a running game directory')
    parser.add_argument('--write', action='store_true', help='Apply the single handler edit after generating the complete file')
    args = parser.parse_args()
    root = args.repo.resolve()
    source = (root / REL).resolve()
    if root not in source.parents:
        raise ValueError('Source escapes selected repository')
    before = source.read_bytes()
    text = before.decode('utf-8')
    # Compare as LF; retain the target file newline convention and all other content.
    crlf = b'\r\n' in before
    updated, changed = fixed_source(text.replace('\r\n', '\n'))
    after = updated.replace('\n', '\r\n').encode() if crlf else updated.encode()
    generated = Path(__file__).resolve().parent / 'files' / REL
    generated.parent.mkdir(parents=True, exist_ok=True)
    generated.write_bytes(after)
    if changed and args.write:
        if source.read_bytes() != before:
            raise ValueError('Source changed during operation; nothing applied to it')
        source.write_bytes(after)
        if source.read_bytes() != after:
            raise OSError('Write verification failed')
    print(('UPDATED' if args.write else 'GENERATED_ONLY') if changed else 'ALREADY_FIXED')
    print('full_file=' + str(generated))
    print('sha256=' + hashlib.sha256(after).hexdigest())
    print('Only the client handler is changed; no server, save, restart or Workshop operation.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, UnicodeError) as exc:
        print('ERROR: ' + str(exc), file=sys.stderr)
        raise SystemExit(2)
