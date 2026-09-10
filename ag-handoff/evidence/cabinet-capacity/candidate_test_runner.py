#!/usr/bin/env python3
"""Run the supplied VLS review fixtures against the isolated candidate source."""
from pathlib import Path
import ctypes as C
import ctypes.util
import sys

HERE = Path(__file__).resolve().parent
ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "candidate"
RUNTIME = ROOT / "source" / "server_runtime"
libname = ctypes.util.find_library("lua5.4") or ctypes.util.find_library("lua-5.4")
if not libname:
    raise SystemExit("Requires a local Lua 5.4 shared library; none found.")
lib = C.CDLL(libname)
lib.luaL_newstate.restype = C.c_void_p
lib.luaL_openlibs.argtypes = [C.c_void_p]
lib.luaL_loadbufferx.argtypes = [C.c_void_p, C.c_char_p, C.c_size_t, C.c_char_p, C.c_char_p]
lib.luaL_loadbufferx.restype = C.c_int
lib.lua_pcallk.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_longlong, C.c_void_p]
lib.lua_pcallk.restype = C.c_int
lib.lua_tolstring.argtypes = [C.c_void_p, C.c_int, C.POINTER(C.c_size_t)]
lib.lua_tolstring.restype = C.c_char_p
lib.lua_settop.argtypes = [C.c_void_p, C.c_int]
lib.lua_close.argtypes = [C.c_void_p]
L = lib.luaL_newstate()
if not L:
    raise SystemExit("Unable to initialize Lua state")
lib.luaL_openlibs(L)

def run(text: str, label: str) -> None:
    data = text.encode("utf-8")
    code = lib.luaL_loadbufferx(L, data, len(data), label.encode(), b"t")
    if code == 0:
        code = lib.lua_pcallk(L, 0, 0, 0, 0, None)
    if code:
        error = lib.lua_tolstring(L, -1, None)
        raise RuntimeError(f"{label}: {error.decode() if error else code}")
    lib.lua_settop(L, 0)

try:
    run((HERE / "review-tests" / "testing" / "fixtures.lua").read_text(), "fixtures")
    for filename in ["VLS_Config.lua", "VLS_KI5Campers_Config.lua", "VLS_ComponentDamage.lua", "VLS_ApplianceServer.lua"]:
        run((RUNTIME / filename).read_text(), filename)
    client = (RUNTIME / "VLS_Client.lua").read_text()
    start = client.index("local function refreshVehicleContainerLabels(")
    stop = client.index("-- Vanilla stops an active microwave", start)
    run(client[start:stop] + "\nReviewClientRefresh = refreshVehicleContainerLabels\n", "exact client refresh excerpt")
    run((HERE / "candidate_cases.lua").read_text(), "candidate cases")
finally:
    lib.lua_close(L)
