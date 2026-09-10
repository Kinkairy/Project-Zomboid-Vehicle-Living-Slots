#!/usr/bin/env python3
"""Static contract checks for the isolated VLS cabinet-capacity candidate."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OLD = ROOT / "original" / "source" / "server_runtime"
NEW = ROOT / "candidate" / "source" / "server_runtime"

PATCH_FILES = ["VLS_VanPatch.txt", "VLS_StepVanWaterPatch.txt", "VLS_KI5CampersPatch.txt"]
UNCHANGED_FILES = [
    "VLS_ComponentDamage.lua",
    "VLS_ApplianceServer.lua",
    "VLS_Client.lua",
    "VLS_KI5Campers_Config.lua",
]

def read(base: Path, name: str) -> str:
    return (base / name).read_text(encoding="utf-8")

old_config = read(OLD, "VLS_Config.lua")
new_config = read(NEW, "VLS_Config.lua")
assert old_config != new_config
assert new_config.count("VLS.Init = VLS.Init or {}") == 1
assert new_config.count("function VLS.Init.UniversalSlot(vehicle, part)") == 1
init_start = new_config.index("function VLS.Init.UniversalSlot(vehicle, part)")
init_end = new_config.index("function VLS.syncUniversalSlot", init_start)
init_block = new_config[init_start:init_end]
assert init_block.index("VLS.Damage.Init(vehicle)") < init_block.index(
    "VLS.ensureUniversalContainerProfile(part)"
)
for needle in (
    "part:getVehicle() ~= vehicle",
    "vehicle:getPartById(part:getId()) ~= part",
    "not VLS.isUniversalPart(part)",
):
    assert needle in init_block

for name in PATCH_FILES:
    old = read(OLD, name)
    new = read(NEW, name)
    assert old.count("init = VLS.Damage.Init") == 0 or old.count("init = VLS.Damage.Init") == new.count("init = VLS.Init.UniversalSlot")
    assert new.count("init = VLS.Damage.Init") == 0
    assert new.count("init = VLS.Init.UniversalSlot") == old.count("init = VLS.Damage.Init")
    assert old.count("create = VLS.Create.UniversalSlot") == new.count("create = VLS.Create.UniversalSlot")
    assert old.count("update = VLS.Update.UniversalSlot") == new.count("update = VLS.Update.UniversalSlot")

access_start = new_config.index("function VLS.ContainerAccess.UniversalSlot")
access_end = new_config.index("function VLS.ContainerAccess.WeaponLocker", access_start)
access_block = new_config[access_start:access_end]
assert access_block.index("not character") < access_block.index("VLS.ensureUniversalContainerProfile(part)")
assert access_block.index("vehicle:getPartById(part:getId()) ~= part") < access_block.index(
    "VLS.ensureUniversalContainerProfile(part)"
)
assert access_block.rstrip().endswith("return true\nend")

for name in UNCHANGED_FILES:
    assert read(OLD, name) == read(NEW, name), name

print("PASS config_init_contract")
print("PASS 16_living_slot_bindings_retargeted")
print("PASS create_update_bindings_preserved")
print("PASS access_fallback_is_after_identity_checks")
print("PASS damage_and_runtime_support_files_unchanged")
print("RESULT 5/5 static candidate checks passed; no game/runtime/save was touched")
