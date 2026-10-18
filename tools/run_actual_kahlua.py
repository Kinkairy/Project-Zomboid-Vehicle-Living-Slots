"""Run texlua-style VLS tests inside the installed 42.21 Kahlua VM.

Each test is bundled with a virtual file system holding the repository's text
files and original-game files, so dofile/require/io.open work without a host
Lua. Original-game files a test asks for are pulled from the installed game on
demand and the test is rerun. Engine objects remain the tests' own mocks.

usage: run_actual_kahlua.py REPO NATIVE OUT [test ...]
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

GAME = Path(os.environ.get("VLS_GAME_ROOT", "/home/aiops/private-state/pz-vls-test-3.8.6-20260919/server"))
WORKSHOP = GAME / "steamapps/workshop/content/108600"
PROBE = Path(os.environ.get("VLS_PROBE_DIR", "/home/aiops/tmp/vls-framework-claude-20261017/results/codex-20261018-tools/probe"))
TEXT = (".lua", ".txt", ".info", ".json")
# Third-party inputs some tests take as extra arguments.
EXTRA = {
    "test_vls_seat_layout": ("/ki5", WORKSHOP / "3110911330/mods/87fordB700/42.20/media/scripts/vehicles"),
}

repo, native, out = (Path(a).resolve() for a in sys.argv[1:4])
SPECIAL = {"test_vls_f700_native_binding"}
names = sys.argv[4:] or sorted(p.stem for p in (repo / "tests").glob("test_*.lua") if p.stem not in SPECIAL)
out.mkdir(parents=True, exist_ok=True)
(out / "stdlib.lua").write_bytes((GAME / "java/stdlib.lua").read_bytes())

base = {}
for p in repo.rglob("*"):
    if p.is_file() and p.suffix in TEXT and ".git" not in p.parts:
        base["/candidate/" + p.relative_to(repo).as_posix()] = p.read_text(encoding="utf-8", errors="replace")
for p in native.rglob("*"):
    if p.is_file() and p.suffix in TEXT:
        base["/native/" + p.relative_to(native).as_posix()] = p.read_text(encoding="utf-8", errors="replace")

mods = sorted(p.name for p in (repo / "workshop/Contents/mods").iterdir() if p.is_dir())
paths = ["/candidate/workshop/Contents/mods/%s/common/media/lua/%s/?.lua" % (m, d)
         for m in mods for d in ("shared", "client", "server")]
paths += ["/native/%s/?.lua" % d for d in ("shared", "client", "server")]

LOADER = r'''
local function norm(path)
    path=string.gsub(path,"\\","/")
    path=string.gsub(path,"/%./","/")
    path=string.gsub(path,"//+","/")
    return path
end
io={open=function(path)
    local s=files[norm(path)]
    if not s then return nil,"missing "..tostring(path) end
    return {read=function()return s end,lines=function()return string.gmatch(s,"[^\n]*")end,close=function()end}
end,write=function(...)print(...)end}
-- The bare probe VM lacks globals the game's LuaManager provides.
next=next or function(t,k)
    local found=k==nil
    for key,value in pairs(t) do
        if found then return key,value end
        if rawequal(key,k) then found=true end
    end
    return nil
end
printed={}
print=function(...)
    local parts={}
    for i=1,select("#",...) do parts[#parts+1]=tostring(select(i,...)) end
    printed[#printed+1]=table.concat(parts," ")
    if #printed>10000 then table.remove(printed,1) end
end
os=os or {}
os.exit=function(code)
    if code~=nil and code~=0 and code~=true then
        error("os.exit("..tostring(code)..") output:\n"..table.concat(printed,"\n"))
    end
end
os.getenv=os.getenv or function()return nil end
function loadfile(path)return assert(loadstring(assert(files[norm(path)],"missing file "..norm(path)),"@"..path))end
function dofile(path)return loadfile(path)()end
function require(name)
    if package.loaded[name]~=nil then return package.loaded[name] end
    if package.preload[name] then local v=package.preload[name](name);package.loaded[name]=v==nil and true or v;return package.loaded[name] end
    local file=string.gsub(name,"%.","/")
    for pattern in string.gmatch(package.path,"[^;]+") do
        local p=norm(string.gsub(pattern,"%?",file))
        if files[p] then local v=assert(loadstring(files[p],"@"..p))();package.loaded[name]=v==nil and true or v;return package.loaded[name] end
    end
    error("missing module "..name)
end
'''


def bundle(name, files, args):
    native_arg = "/native/server/Vehicles/Vehicles.lua" if name == "test_native_cargo_3811" else "/native"
    lines = ["arg={[0]=%s}" % ",".join(json.dumps(a) for a in ["test", "/candidate", native_arg] + args),
             'package={loaded={},preload={},path=%s}' % json.dumps(";".join(paths)),
             "table.unpack=table.unpack or unpack;load=load or loadstring", "files={}"]
    for key, text in files.items():
        assert "]=====]" not in text, key
        lines.append("files[" + json.dumps(key) + "]=[=====[" + text + "]=====]")
    lines.append(LOADER)
    body = (repo / "tests" / (name + ".lua")).read_text(encoding="utf-8")
    # A function wrapper (not pcall) tolerates a trailing `return` and keeps error frames.
    lines.append("(function()\n-- BEGIN TEST\n" + body + "\nend)()\nfixtureTranscript=table.concat(printed,\"\\n\")\nsuitePassed=true\n")
    return "\n".join(lines)


def game_file(rel):
    for root in (GAME / "media" / "lua", GAME / "media"):
        p = root / rel
        if p.is_file():
            return p
    return None


cp = ":".join([str(GAME / "java/projectzomboid.jar"), str(GAME / "java") + "/*", str(PROBE)])
results = []
for name in names:
    files = dict(base)
    args = []
    if name == "test_native_cargo_3811":
        files["/native/server/Vehicles/Vehicles.lua"] = (GAME / "media/lua/server/Vehicles/Vehicles.lua").read_text()
    if name == "test_vls_ki5_overlay":
        files["/overlay-fixture.lua"] = Path(os.environ.get("VLS_OVERLAY_FIXTURE", str(out.parent / "overlay-fixture.lua"))).read_text()
        args.extend(["/overlay-fixture.lua", "trace"])
    if name in EXTRA:
        key, folder = EXTRA[name]
        args.append(key)
        for p in folder.rglob("*"):
            if p.is_file() and p.suffix in TEXT:
                files[key + "/" + p.relative_to(folder).as_posix()] = p.read_text(encoding="utf-8", errors="replace")
    added = []
    for _ in range(40):
        target = out / ("actual-vm-" + name + ".lua")
        target.write_text(bundle(name, files, args), encoding="utf-8")
        q = subprocess.run([str(GAME / "jre64/bin/java"), "-cp", cp, "NativeFrameworkProbe", str(target), "lua-only"],
                           cwd=out, capture_output=True, text=True, timeout=600)
        (out / (name + ".stdout")).write_text(q.stdout, encoding="utf-8")
        (out / (name + ".stderr")).write_text(q.stderr, encoding="utf-8")
        err = "\n".join(l for l in q.stderr.splitlines() if not l.startswith("WARNING"))
        ok = q.returncode == 0 and "PASS actual Kahlua fixture" in q.stdout
        if ok:
            break
        m = re.search(r"missing (?:file )?/native/([\w./-]+)", err) or re.search(r"missing module ([\w./]+)", err)
        if not m:
            break
        rel = m.group(1)
        if "/" not in rel or not rel.endswith(TEXT):
            rel = next((d + "/" + rel.replace(".", "/") + ".lua" for d in ("shared", "client", "server")
                        if game_file(d + "/" + rel.replace(".", "/") + ".lua")), rel)
        src = game_file(rel)
        if not src or "/native/" + rel in files:
            break
        files["/native/" + rel] = src.read_text(encoding="utf-8", errors="replace")
        added.append(rel)
    msg = re.search(r"AssertionError: \[false, (.*?)(?:, se\.krka|, java\.lang|\]$)", err, re.S)
    row = {"test": name, "pass": ok, "native_added": added,
           "error": "" if ok else re.sub(r"\s+", " ", msg.group(1) if msg else err)[:400]}
    results.append(row)
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else " :: " + row["error"][:240]), flush=True)
(out / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
print("TOTAL", len(results), "PASS", sum(r["pass"] for r in results))

sys.exit(0 if all(row["pass"] for row in results) else 1)
