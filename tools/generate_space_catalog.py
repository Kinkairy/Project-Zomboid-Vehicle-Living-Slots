"""Generate the VLS space catalog and slot item lists from vanilla data.

This is the only place the space rule lives. It reads the installed game's
tile properties and moveable item scripts, decides for every furniture family
whether it fits the living space, the top space, or neither, and writes:

  * shared/VLS_SpaceCatalog.lua  - canonical type -> space (+ data for newly
    supported storage/work-surface families);
  * every living / top slot `itemType` list in the shipped vehicle scripts.

usage: generate_space_catalog.py MEDIA_DIR REPO_ROOT [--check]
  --check  fail (exit 1) when the generated files differ from the repository.
"""
import hashlib
import re
import struct
import sys
from collections import OrderedDict
from pathlib import Path

LIVING, TOP = "living", "top"
# Appliances VLS runs with one shared executor per kind (heating, cooling,
# laundry). Their parameters are the vanilla tile properties.
LAUNDRY = {"IsoCombinationWasherDryer": "both", "IsoClothingWasher": "washer",
           "IsoClothingDryer": "dryer"}
SOUNDS = (("open", "ContainerOpenSound"), ("close", "ContainerCloseSound"),
          ("put", "ContainerPutSound"), ("take", "ContainerTakeSound"))


def appliance(props):
    """Executor kind and vanilla parameters, or None for plain furniture."""
    kind, box = props.get("IsoType"), props.get("container")
    if kind == "IsoStove" and box in ("stove", "microwave"):
        return {"capability": "cooking", "window": "microwave" if box == "microwave" else "oven",
                "container": box}
    if kind in LAUNDRY:
        return {"capability": "laundryCombo", "laundry": LAUNDRY[kind], "container": box}
    if "IsFridge" in props or "Freezer" in props:
        freezer_only = "IsFridge" not in props
        freezer = int(props.get("FreezerCapacity", "0") or 0)
        if freezer_only or "NoFreezer" in props:
            freezer = 0
        return {"capability": "cooling", "freezerOnly": freezer_only, "freezer": freezer,
                "container": "freezer" if freezer_only else box or "fridge"}
    return None


# Other vanilla appliance / fire objects have no VLS executor; they are not
# opened as plain storage.
APPLIANCE_ISOTYPES = {"IsoStove", "IsoBarbecue", "IsoFireplace", "IsoTelevision", "IsoRadio",
                      "IsoCombinationWasherDryer", "IsoClothingDryer", "IsoClothingWasher",
                      "IsoGenerator", "IsoLightSwitch", "IsoMannequin"}
APPLIANCE_CONTAINERS = {"fridge", "freezer", "stove", "microwave", "clothingwasher",
                        "clothingdryer", "clothingdryerbasic", "woodstove", "barbecue",
                        "fireplace", "toaster", "composter"}
# Household and workshop furniture only; shop/business/public fittings and
# bins, troughs or boxes are not living-space furniture.
FURNITURE_SHEETS = ("appliances_", "carpentry_", "constructedobjects_", "crafted_", "fixtures_",
                    "furniture_", "location_trailer_")
NOT_FURNITURE = re.compile(r"Garbage|Bin\b|Trough|Dog House|Box|Mail|Decoration", re.I)
# Entries every living / top list keeps across regenerations.
LIVING_SIGNATURE = "Base.Mov_Cot"
TOP_SIGNATURE = "Moveables.fixtures_counters_01_16"
MAIN = "workshop/Contents/mods/VehicleLivingSlots/common/media"
SCRIPT_DIRS = ["workshop/Contents/mods/VehicleLivingSlots/common/media/scripts",
               "workshop/Contents/mods/VehicleLivingSlotsKI5Campers/common/media/scripts",
               "workshop/Contents/mods/VehicleLivingSlotsKI5F700/common/media/scripts"]


def read_tiles(path):
    data = path.read_bytes()
    pos = 0

    def take(n):
        nonlocal pos
        chunk = data[pos:pos + n]
        pos += n
        return chunk

    def i32():
        return struct.unpack("<i", take(4))[0]

    def line():
        nonlocal pos
        end = data.index(b"\n", pos)
        text = data[pos:end].decode("utf-8", "replace")
        pos = end + 1
        return text

    assert take(4) == b"tdef", path
    i32()
    tiles = OrderedDict()
    for _ in range(i32()):
        name = line()
        line()
        i32(), i32(), i32()
        for index in range(i32()):
            props = {}
            for _ in range(i32()):
                key = line()
                props[key] = line()
            if props:
                tiles["%s_%d" % (name, index)] = props
    return tiles


def read_moveable_items(path):
    """Base.Mov_* item -> its world sprite, and the reverse map."""
    by_item, by_sprite, current = {}, {}, None
    for text in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"\s*item (\w+)", text)
        if m:
            current = "Base." + m.group(1)
        m = re.match(r"\s*WorldObjectSprite\s*=\s*([\w]+)", text)
        if m and current:
            by_item.setdefault(current, m.group(1))
            by_sprite.setdefault(m.group(1), current)
    return by_item, by_sprite


def space_of(props):
    """The space rule. Returns (space or None, reason)."""
    if "IsMoveAble" not in props:
        return None, "not_movable"
    if "SpriteGridPos" in props:
        return None, "multi_tile"
    if "IsTableTop" in props:
        return TOP, "tabletop"
    if "IsHigh" in props or (props.get("MoveType") == "WallObject"
                             and props.get("ContainerPosition") == "High"):
        return TOP, "wall_high"
    if props.get("ScrapSize") == "Small" and int(props.get("PickUpWeight", "999")) <= 100:
        return TOP, "small"
    return LIVING, "regular"


def generic_surface(props):
    """Match installed 42.21 IsoObject.isGenericCraftingSurface()."""
    explicit = props.get("GenericCraftingSurface")
    if explicit in ("true", "false"):
        return explicit == "true"
    surface = int(props.get("Surface", "0") or 0)
    return 24 <= surface <= 47 and "IsSurfaceOffset" not in props


def sprite_index(sprite):
    return int(sprite.rsplit("_", 1)[1])


def main():
    media, repo = Path(sys.argv[1]), Path(sys.argv[2])
    check = "--check" in sys.argv[3:]
    tiles_path = media / "newtiledefinitions.tiles"
    items_path = media / "scripts/generated/items/moveable.txt"
    tiles = read_tiles(tiles_path)
    mov_sprite, sprite_mov = read_moveable_items(items_path)
    custom = {}
    for sprite, props in tiles.items():
        if "CustomItem" in props:
            custom.setdefault(props["CustomItem"], sprite)

    def type_sprite(full_type):
        if full_type.startswith("Moveables."):
            return full_type.split(".", 1)[1]
        return mov_sprite.get(full_type) or custom.get(full_type)

    def type_space(full_type):
        sprite = type_sprite(full_type)
        props = tiles.get(sprite) if sprite else None
        if not props or "bed" in props:
            return None  # beds, sleeping bags, batteries, plain items keep their slots
        return space_of(props)[0]

    # Types listed in the shipped slots before this rule keep their identity.
    # A line may name the sprite VLS recognises when the vanilla item points elsewhere.
    legacy_spaces = OrderedDict()
    for text in (repo / "tools/space_legacy_types.txt").read_text(encoding="utf-8").splitlines():
        fields = text.split()
        if fields and not fields[0].startswith(("#", "[")):
            if len(fields) > 1:
                mov_sprite[fields[0]] = fields[1]
            legacy_spaces[fields[0]] = type_space(fields[0])
    legacy_sprites = {type_sprite(t) for t in legacy_spaces} - {None}
    # Overhead cupboards VLS only recognises (installable=false) stay out of the lists.
    overhead = (repo / MAIN / "lua/shared/VLS_OverheadCatalog.lua").read_text(encoding="utf-8")
    recognised_only = set()
    for entry in re.finditer(r'type="([^"]+)", installable=(true|false)[^}]*sprites=\{([^}]*)\}', overhead):
        legacy_sprites.update(re.findall(r'"([^"]+)"', entry.group(3)))
        if entry.group(2) == "false":
            recognised_only.add(entry.group(1))
    pattern = re.compile(r"(itemType\s*=\s*)([^,\n]+)(,)")
    sources = {path: path.read_text(encoding="utf-8")
               for d in SCRIPT_DIRS for path in sorted((repo / d).glob("*.txt"))}

    # Group vanilla sprites into furniture families (one sheet, one name).
    families = OrderedDict()
    for sprite, props in tiles.items():
        sheet = sprite.rsplit("_", 1)[0]
        families.setdefault((sheet, props.get("CustomName", ""), props.get("GroupName", "")), []).append(sprite)

    new_types = OrderedDict()
    for (sheet, custom_name, group), sprites in families.items():
        props = tiles[sprites[0]]
        space, _ = space_of(props)
        if legacy_sprites.intersection(sprites):
            continue  # already supported under its shipped type
        if not sheet.startswith(FURNITURE_SHEETS) or NOT_FURNITURE.search(custom_name + " " + group):
            continue
        if not space or "Corner" in custom_name or "Corner" in group or "bed" in props:
            continue
        device = appliance(props)
        if not device:
            if not ("container" in props or generic_surface(props)):
                continue
            if props.get("IsoType") in APPLIANCE_ISOTYPES or props.get("container") in APPLIANCE_CONTAINERS:
                continue
        sprites = sorted(sprites, key=sprite_index)
        facings = {}
        for s in sprites:
            facings.setdefault(tiles[s].get("Facing", ""), []).append(s)
        named = [s for s in sprites if s in sprite_mov]
        if any(len(v) > 1 for v in facings.values()):
            # Two pieces per facing (corner/straight pairs): only the half a
            # vanilla named item points at is unambiguous.
            if not named:
                continue
            parity = sprite_index(named[0]) % 2
            sprites = [s for s in sprites if sprite_index(s) % 2 == parity]
        if any(space_of(tiles[s])[0] != space for s in sprites):
            continue
        canonical = next((sprite_mov[s] for s in sprites if s in sprite_mov), None) \
            or tiles[sprites[0]].get("CustomItem") or "Moveables." + sprites[0]
        if canonical == "Base.Mov_GreenWallLocker":
            continue  # weapon cabinet keeps its dedicated slot
        name = "_".join(x for x in (group, custom_name) if x).replace(" ", "_")
        new_types[canonical] = {
            "space": space, "sprites": sprites, "name": name,
            "container": props.get("container"),
            "capacity": int(props["ContainerCapacity"]) if props.get("ContainerCapacity", "").isdigit() else None,
            "surface": generic_surface(props),
            "device": device,
            "sounds": {key: props[prop] for key, prop in SOUNDS if prop in props},
        }

    # Rewrite every living/top slot list from the same rule.
    living_types = [t for t, s in sorted(legacy_spaces.items()) if s == LIVING] \
        + [t for t, e in new_types.items() if e["space"] == LIVING]
    top_types = [t for t, s in sorted(legacy_spaces.items()) if s == TOP] \
        + [t for t, e in new_types.items() if e["space"] == TOP]

    def rewrite(m):
        items = [x.strip() for x in m.group(2).split(";") if x.strip()]
        # Beds and other unclassified entries keep their place.
        unclassified = [t for t in items if t not in new_types and t not in recognised_only
                        and legacy_spaces.get(t) is None]
        if LIVING_SIGNATURE in items:
            merged = unclassified + living_types
        elif TOP_SIGNATURE in items:
            merged = unclassified + top_types
        else:
            return m.group(0)
        seen, unique = set(), []
        for t in merged:
            if t not in seen:
                seen.add(t)
                unique.append(t)
        return m.group(1) + ";".join(unique) + m.group(3)

    outputs = {path: pattern.sub(rewrite, text) for path, text in sources.items()}

    lua = ["-- GENERATED by tools/generate_space_catalog.py from vanilla 42.21 data. Do not edit.",
           "-- tiles sha256 %s" % hashlib.sha256(tiles_path.read_bytes()).hexdigest(),
           "-- moveables sha256 %s" % hashlib.sha256(items_path.read_bytes()).hexdigest(),
           "-- Space rule: not movable or multi-tile -> not installable; tabletop, wall-high,",
           "-- or small (ScrapSize Small, PickUpWeight <= 100) -> top; other movable -> living.",
           "return {", "    spaces = {"]
    for t, s in sorted(legacy_spaces.items()):
        if s and t not in new_types:
            lua.append('        [%s] = "%s",' % (lua_str(t), s))
    lua.append("    },")
    lua.append("    furniture = {")
    for t, e in new_types.items():
        fields = ['space = "%s"' % e["space"], "name = %s" % lua_str(e["name"]),
                  "sprites = {%s}" % ", ".join(lua_str(s) for s in e["sprites"]),
                  "surface = %s" % ("true" if e["surface"] else "false")]
        device = e["device"]
        container = device["container"] if device else e["container"]
        if container:
            fields.append("container = %s" % lua_str(container))
        if device:
            fields.append("capability = %s" % lua_str(device["capability"]))
            if e["capacity"]:
                fields.append("capacity = %d" % e["capacity"])
            for key in ("window", "laundry"):
                if key in device:
                    fields.append("%s = %s" % (key, lua_str(device[key])))
            if device["capability"] == "cooling":
                fields.append("freezer = %d" % device["freezer"])
                fields.append("freezerOnly = %s" % ("true" if device["freezerOnly"] else "false"))
            if e["sounds"]:
                fields.append("sounds = { %s }" % ", ".join(
                    "%s = %s" % (k, lua_str(v)) for k, v in sorted(e["sounds"].items())))
        lua.append("        [%s] = { %s }," % (lua_str(t), ", ".join(fields)))
    lua.append("    },")
    lua.append("}")
    outputs[repo / MAIN / "lua/shared/VLS_SpaceCatalog.lua"] = "\n".join(lua) + "\n"

    changed = [p for p, text in outputs.items() if not p.exists() or p.read_text(encoding="utf-8") != text]
    if check:
        for p in changed:
            print("OUT OF DATE", p.relative_to(repo))
        sys.exit(1 if changed else 0)
    for p in changed:
        p.write_text(outputs[p], encoding="utf-8")
        print("wrote", p.relative_to(repo))
    counts = {LIVING: 0, TOP: 0}
    for e in new_types.values():
        counts[e["space"]] += 1
    print("furniture families: living %d, top %d; legacy types with a space: %d"
          % (counts[LIVING], counts[TOP], sum(1 for t, s in legacy_spaces.items() if s and t not in new_types)))


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


if __name__ == "__main__":
    main()
