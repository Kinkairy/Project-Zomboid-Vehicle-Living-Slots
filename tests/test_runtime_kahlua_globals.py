"""Runtime Lua must not call globals the game's Kahlua environment lacks.

The 42.21 game environment has no global next(); a VLS load-time call to it
stopped every VLS module on the test server (2026-10-17). Offline runners may
provide such globals for test code, so this static check guards runtime code.
"""
import re
import sys
from pathlib import Path

MISSING = ("next",)
root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1])
call = re.compile(r"(?<![\w.:])(%s)\s*\(" % "|".join(MISSING))
failures = []
for path in sorted((root / "workshop").rglob("*.lua")):
    for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        code = re.sub(r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'", "", line).split("--", 1)[0]
        if call.search(code):
            failures.append("%s:%d: %s" % (path.relative_to(root), number, line.strip()))
for failure in failures:
    print("FAIL", failure)
print("RESULT runtime Lua files scanned, forbidden calls=%d" % len(failures))
sys.exit(1 if failures else 0)
