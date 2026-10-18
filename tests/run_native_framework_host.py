"""Run bounded Lua glue checks. Requires texlua; does not install or run the game."""
from pathlib import Path
import shutil, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
lua=shutil.which('texlua')
if not lua: raise SystemExit('BLOCKED: texlua unavailable; no game acceptance claimed')
for name in ['test_native_framework_context.lua','test_native_framework_definition.lua','test_native_framework_storage.lua']:
    subprocess.run([lua,str(root/'tests'/name),str(root)],check=True)
