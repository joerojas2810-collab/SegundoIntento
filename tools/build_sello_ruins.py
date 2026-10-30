#!/usr/bin/env python3
"""Deterministic builder for the original "El sello de las ruinas" complex.

The output is a Luanti .mts voxel schematic plus a small JSON manifest that
tells the runtime where the rooms, encounter anchors, waystones and pedestal
are.  No source schematic is used: every block below is authored here, so the
result can be distributed with the game (GPL-3.0-or-later).

The complex is a ruined hill-fort (49 x 49 footprint) standing on a rough
stone plateau.  A stair in the west courtyard descends into a five-room crypt:
antechamber, hall of echoes, barracks, cistern and seal chamber.  The roof,
upper walls, merlons and several floors are deliberately broken; the ruin
pass is deterministic so repeated builds are byte-identical.

Run:
    python3 tools/build_sello_ruins.py
"""

from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "mods" / "MISC" / "everforge" / "schematics"
OUT_MTS = OUT_DIR / "sello_ruinas.mts"
OUT_JSON = OUT_DIR / "sello_ruinas.json"

W, H, D = 61, 40, 61
MTSM_SIGNATURE = 0x4D54534D
MTSM_VERSION = 4
MTSM_PROB_ALWAYS = 0x7F

AIR = "air"
STONE = "mcl_core:stone"
COBBLE = "mcl_core:cobble"
MOSSY_COBBLE = "mcl_core:mossycobble"
BRICK = "mcl_core:stonebrick"
MOSSY = "mcl_core:stonebrickmossy"
CRACKED = "mcl_core:stonebrickcracked"
CARVED = "mcl_core:stonebrickcarved"
GRASS = "mcl_core:dirt_with_grass"
DIRT = "mcl_core:dirt"
GRAVEL = "mcl_core:gravel"
WATER = "mcl_core:water_source"
COBWEB = "mcl_core:cobweb"
DEADBUSH = "mcl_core:deadbush"
FERN = "mcl_flowers:fern"
DANDELION = "mcl_flowers:dandelion"
WOOD = "mcl_trees:wood_oak"
DARK_WOOD = "mcl_trees:wood_dark_oak"
FENCE = "mcl_fences:dark_oak_fence"
FENCE_GATE = "mcl_fences:dark_oak_fence_gate"
DOOR_B = "mcl_doors:door_dark_oak_b_1"
DOOR_T = "mcl_doors:door_dark_oak_t_1"
SLAB = "mcl_stairs:slab_stonebrick"
STAIR = "mcl_stairs:stair_stonebrick"
TORCH = "mcl_torches:torch"
TORCH_WALL = "mcl_torches:torch_wall"
LANTERN = "mcl_lanterns:lantern_ceiling"
LANTERN_FLOOR = "mcl_lanterns:lantern_floor"
CHAIN = "mcl_lanterns:chain"
SOUL_LANTERN = "mcl_lanterns:soul_lantern_floor"
CHEST = "mcl_chests:chest_small"
BARREL = "mcl_barrels:barrel_closed"
BOOKSHELF = "mcl_books:bookshelf"
ANVIL = "mcl_anvils:anvil"
FURNACE = "mcl_furnaces:furnace"
CAMPFIRE = "mcl_campfires:campfire_lit"
CAULDRON = "mcl_cauldrons:cauldron"
WOOL_RED = "mcl_wool:red"
WOOL_BROWN = "mcl_wool:brown"
FLOWER_POT = "mcl_flowerpots:flower_pot_dandelion"
LADDER = "mcl_core:ladder"

GRID: dict[tuple[int, int, int], tuple[str, int]] = {}


def h(x: int, y: int, z: int, salt: str = "") -> int:
    raw = f"{x}/{y}/{z}/{salt}".encode("utf-8")
    return int.from_bytes(hashlib.blake2s(raw, digest_size=4).digest(), "big")


def inside(x: int, y: int, z: int) -> bool:
    return 0 <= x < W and 0 <= y < H and 0 <= z < D


def put(x: int, y: int, z: int, name: str, param2: int = 0) -> None:
    if inside(x, y, z):
        GRID[(x, y, z)] = (name, param2 & 0xFF)


def get(x: int, y: int, z: int) -> str:
    item = GRID.get((x, y, z))
    return item[0] if item else AIR


def fill(x1: int, x2: int, y1: int, y2: int, z1: int, z2: int,
         name: str, param2: int = 0) -> None:
    for x in range(min(x1, x2), max(x1, x2) + 1):
        for y in range(min(y1, y2), max(y1, y2) + 1):
            for z in range(min(z1, z2), max(z1, z2) + 1):
                put(x, y, z, name, param2)


def carve(x1: int, x2: int, y1: int, y2: int, z1: int, z2: int) -> None:
    fill(x1, x2, y1, y2, z1, z2, AIR)


def brick(x: int, y: int, z: int, salt: str = "", moss_bias: int = 0) -> str:
    n = h(x, y, z, salt) % 100
    if n < 8 + moss_bias:
        return MOSSY
    if n < 18:
        return CRACKED
    if n < 21:
        return CARVED
    if n < 25:
        return COBBLE
    return BRICK


def wall_face(x: int, y: int, z: int, salt: str = "", moss_bias: int = 0) -> None:
    put(x, y, z, brick(x, y, z, salt, moss_bias))


def floor_face(x: int, z: int, y: int, salt: str = "floor", moss_bias: int = 0) -> None:
    n = h(x, y, z, salt) % 100
    if n < 6 + moss_bias:
        put(x, y, z, MOSSY)
    elif n < 13:
        put(x, y, z, CRACKED)
    elif n < 17:
        put(x, y, z, COBBLE)
    else:
        put(x, y, z, BRICK)


def rough_plateau() -> None:
    """A low, rough stone shelf. It is mostly buried by the flat test world."""
    for x in range(2, 59):
        for z in range(2, 59):
            # Jagged edge: the outer ring loses some top blocks.
            edge = min(x - 2, 58 - x, z - 2, 58 - z)
            top = 22
            if edge < 3 and h(x, 0, z, "edge") % 100 < 35:
                top = 21
            for y in range(0, top + 1):
                if y == top:
                    if 5 <= x <= 55 and 5 <= z <= 55:
                        put(x, y, z, GRASS if h(x, 0, z, "cap") % 100 < 72 else STONE)
                    else:
                        put(x, y, z, COBBLE if h(x, 0, z, "rim") % 3 else MOSSY_COBBLE)
                elif y >= top - 2:
                    put(x, y, z, DIRT if h(x, y, z, "soil") % 4 == 0 else STONE)
                else:
                    put(x, y, z, STONE)


def courtyard_and_surface() -> None:
    # Foundation course: the plateau cap ends at y=22, so every wall foot
    # gets a solid y=23 block instead of floating one layer above the rock.
    for x in range(5, 56):
        for z in range(5, 56):
            on_edge = x in (6, 7, 8, 52, 53, 54) or z in (6, 7, 8, 52, 53, 54)
            tower = (19 <= x <= 25 or 35 <= x <= 41) and 1 <= z <= 7
            pylon = x in (27, 28, 31, 32) and 5 <= z <= 8
            buttress = x in (13, 47) and z in (32, 38, 44, 49)
            if (on_edge or tower or pylon or buttress) and get(x, 23, z) == AIR:
                put(x, 23, z, COBBLE if h(x, 23, z, "found") % 3 else BRICK)

    # Courtyard paving: irregular, worn and partly overgrown.
    for x in range(8, 53):
        for z in range(8, 30):
            n = h(x, 23, z, "court") % 100
            if n < 4:
                put(x, 23, z, GRASS)
            elif n < 9:
                put(x, 23, z, GRAVEL)
            else:
                floor_face(x, z, 23, "court", 10)
    # A narrow, muddy approach inside the gate.
    for x in range(28, 33):
        for z in range(4, 9):
            floor_face(x, z, 23, "gatepath", 8)

    # Outer curtain wall, two blocks thick and deliberately broken on the east.
    for x in range(6, 55):
        for z in range(6, 55):
            on_edge = x in (6, 7, 8, 52, 53, 54) or z in (6, 7, 8, 52, 53, 54)
            if not on_edge:
                continue
            # Gate opening in the north wall.
            if 28 <= x <= 31 and z <= 8:
                continue
            # Collapsed east wall gap.
            if x in (52, 53, 54) and 22 <= z <= 27:
                continue
            for y in range(24, 32):
                if y < 30 and h(x, y, z, "curtain") % 100 < 7:
                    continue
                wall_face(x, y, z, "curtain", 12)
            # Battlements on the outer ring.
            if (x in (6, 54) and z % 2 == 0) or (z in (6, 54) and x % 2 == 1):
                if h(x, 0, z, "merlon") % 100 < 78:
                    wall_face(x, 32, z, "merlon", 18)
                    if h(x, 1, z, "merlon2") % 100 < 62:
                        wall_face(x, 33, z, "merlon2", 20)

    # Gate pylons and a shallow arch.
    for x in (27, 28, 31, 32):
        for z in (5, 6, 7, 8):
            for y in range(24, 31):
                wall_face(x, y, z, "gatepylon", 8)
    for x in range(28, 32):
        for y in range(28, 31):
            put(x, y, 6, CARVED if y == 30 else brick(x, y, 6, "gatearch"))
    # Gate floor / threshold.
    for x in range(28, 32):
        for z in range(5, 9):
            put(x, 23, z, CARVED if z == 6 else BRICK)
    # The gate is a working pair of dark-oak doors.  Runtime metadata opens
    # and closes them; they are the only route through the north wall.
    for x in (29, 30):
        put(x, 24, 6, DOOR_B, 0)
        put(x, 25, 6, DOOR_T, 0)
        carve(x, x, 26, 26, 6, 6)
    # Arrow slits and patched masonry around the gate.
    for x in (26, 33):
        for y in (27, 29):
            carve(x, x, y, y, 6, 6)
            put(x, y - 1, 6, SLAB)

    # Twin gate towers.  Chamfered corners read as round-ish from the ground.
    for cx, cz in ((22, 4), (38, 4)):
        x1, x2 = cx - 3, cx + 3
        z1, z2 = cz - 3, cz + 3
        for x in range(x1, x2 + 1):
            for z in range(z1, z2 + 1):
                if (x in (x1, x2) and z in (z1, z2)):
                    continue
                for y in range(24, 38):
                    if y > 35 and h(x, y, z, "tower") % 100 < 22:
                        continue
                    wall_face(x, y, z, "tower", 16)
        # Hollow the tower so the door and ladder are real access, not a
        # decorative door set into solid masonry.
        carve(x1 + 1, x2 - 1, 24, 37, z1 + 1, z2 - 1)
        for x in range(x1 + 1, x2):
            for z in range(z1 + 1, z2):
                put(x, 23, z, BRICK)
        for y in (29, 34):
            for x in range(x1 + 1, x2):
                for z in range(z1 + 1, z2):
                    if (x, z) == (cx, z1 + 1):
                        continue
                    put(x, y, z, SLAB)
        # Arrow slits on all four faces.
        for x, z in ((cx, z1), (cx, z2), (x1, cz), (x2, cz)):
            for y in (28, 32, 35):
                carve(x, x, y, y + 1, z, z)
        # Cap and broken merlons.
        for x in range(x1, x2 + 1):
            for z in range(z1, z2 + 1):
                if x in (x1, x2) or z in (z1, z2):
                    if h(x, 0, z, "towercap") % 100 < 65:
                        put(x, 38, z, brick(x, 38, z, "towercap", 20))
        # A small door from the courtyard into each tower, with a ladder.
        for x in range(cx - 1, cx + 2):
            put(x, 24, 7, AIR)
            put(x, 25, 7, AIR)
        put(cx, 26, 7, SLAB)
        put(cx, 24, 7, FENCE_GATE, 0)
        # Ladder against the north inner face, from courtyard to the top.
        for y in range(24, 38):
            put(cx, y, z1 + 1, LADDER, 5)
        put(cx, 26, cz, TORCH)

    # West courtyard stairhouse: a broken arch frames the descent.
    for x in range(8, 13):
        for z in range(10, 14):
            for y in range(24, 29):
                if x in (8, 12) or z in (10, 13):
                    wall_face(x, y, z, "stairhouse", 10)
    carve(9, 11, 24, 27, 10, 11)
    put(9, 24, 11, AIR)
    put(10, 24, 11, AIR)
    put(11, 24, 11, AIR)
    # A cracked lintel and a hanging lantern.
    for x in range(8, 13):
        put(x, 28, 10, brick(x, 28, 10, "lintel", 15))
    put(10, 27, 10, LANTERN)
    # Railings along the exposed top of the stair.
    for z in (12, 14, 16, 18, 20):
        put(8, 24, z, FENCE)
        put(12, 24, z, FENCE)
        if z % 4 == 0:
            put(8, 25, z, TORCH_WALL, 2)
            put(12, 25, z, TORCH_WALL, 3)

    # Courtyard arcade along the east wall: columns, arches, collapsed roof.
    for z in range(10, 25, 4):
        for y in range(24, 31):
            put(48, y, z, brick(48, y, z, "arcade", 18))
        put(48, 31, z, CARVED)
        put(49, 31, z, CARVED)
        if z + 2 < 25:
            for x in range(48, 52):
                put(x, 31, z + 2, SLAB)
        for y in range(24, 27):
            put(47, y, z, AIR)
    for z in (16, 20):
        for x in (49, 50, 51):
            for y in range(26, 31):
                if h(x, y, z, "arcade_ruin") % 100 < 55:
                    put(x, y, z, brick(x, y, z, "arcade_ruin", 20))
    # Fountain / well in the courtyard, dry and choked with rubble.
    for x in range(27, 34):
        for z in range(16, 22):
            if (x in (27, 33) or z in (16, 21)) and not (x == 30 and z == 16):
                for y in (24, 25):
                    put(x, y, z, brick(x, y, z, "fountain", 12))
            elif 28 <= x <= 32 and 17 <= z <= 20:
                put(x, 23, z, GRAVEL if (x + z) % 3 else COBBLE)
    put(30, 24, 16, CARVED)
    put(30, 25, 16, CARVED)

    # Rubble, weeds and abandoned objects: readable ruin, not a clean castle.
    for x in range(9, 53):
        for z in range(9, 29):
            n = h(x, 24, z, "debris") % 1000
            if n < 10:
                put(x, 24, z, COBBLE if n % 2 else CRACKED)
            elif n < 14 and get(x, 23, z) in (BRICK, CRACKED, MOSSY, GRAVEL):
                put(x, 24, z, DEADBUSH if n % 3 else FERN)
    for x, z in ((10, 22), (14, 26), (44, 12), (50, 23), (20, 10), (46, 27)):
        for dx in range(0, 2):
            for dz in range(0, 2):
                put(x + dx, 24, z + dz, COBBLE if h(x, 0, z, "pile") % 2 else CRACKED)
    # Barrels and a broken cart-wheel-like ring near the gate.
    for x, z in ((34, 9), (42, 27), (11, 27)):
        put(x, 24, z, BARREL)
    for x in range(24, 27):
        put(x, 24, 12, WOOD if x != 25 else AIR)
    for z in (11, 13):
        put(25, 24, z, WOOD)


def stair_down() -> None:
    """17-step descent from the west courtyard to the crypt landing."""
    # Steps are solid blocks: no facedir-dependent geometry in the critical path.
    for i, z in enumerate(range(11, 27)):
        y = 23 - i
        fill(9, 11, y, y, z, z, BRICK if i % 3 else CRACKED)
        carve(9, 11, y + 1, y + 3, z, z)
        # Side walls get a torch every few steps.
        if i % 4 == 2:
            put(8, y + 2, z, TORCH_WALL, 2)
            put(12, y + 2, z, TORCH_WALL, 3)
        # Worn, irregular edges.
        if i % 2 == 0:
            put(8, y, z, MOSSY_COBBLE)
            put(12, y, z, MOSSY_COBBLE)
    # Bottom landing and a last short corridor east.
    fill(9, 11, 8, 8, 26, 29, BRICK)
    carve(9, 11, 9, 12, 26, 29)
    carve(12, 23, 9, 11, 28, 30)
    fill(12, 23, 8, 8, 28, 30, BRICK)
    # Rubble on the landing, but keep a 3-wide route.
    put(9, 9, 29, COBBLE)
    put(11, 9, 29, CRACKED)
    put(10, 12, 28, LANTERN)
    put(22, 11, 28, TORCH_WALL, 4)
    put(23, 11, 30, TORCH_WALL, 5)


def line_room(x1: int, x2: int, z1: int, z2: int, floor_y: int, ceil_y: int,
              salt: str, moss_bias: int = 0) -> None:
    """Carve a room interior and line its floor, ceiling and four walls."""
    carve(x1 + 1, x2 - 1, floor_y + 1, ceil_y - 1, z1 + 1, z2 - 1)
    for x in range(x1 + 1, x2):
        for z in range(z1 + 1, z2):
            floor_face(x, z, floor_y, salt, moss_bias)
            put(x, ceil_y, z, brick(x, ceil_y, z, salt + "ceil", 15))
    for y in range(floor_y + 1, ceil_y):
        for x in range(x1 + 1, x2):
            for z in (z1 + 1, z2 - 1):
                wall_face(x, y, z, salt + "wall", moss_bias)
        for z in range(z1 + 1, z2):
            for x in (x1 + 1, x2 - 1):
                wall_face(x, y, z, salt + "wall", moss_bias)
    # A dark plinth course makes the rooms read at a distance.
    for x in range(x1 + 1, x2):
        for z in (z1, z2):
            put(x, floor_y + 1, z, CARVED)
    for z in range(z1 + 1, z2):
        for x in (x1, x2):
            put(x, floor_y + 1, z, CARVED)


def torch_on_wall(x: int, y: int, z: int, side: str) -> None:
    # wallmounted: +X 2, -X 3, +Z 4, -Z 5
    p2 = {"+x": 2, "-x": 3, "+z": 4, "-z": 5}[side]
    put(x, y, z, TORCH_WALL, p2)


def crypt() -> None:
    # Antechamber
    line_room(24, 36, 27, 35, 8, 14, "ante", 10)
    carve(12, 24, 9, 11, 28, 30)
    # Antechamber pillars and a collapsed offering table.
    for x, z in ((27, 29), (33, 29), (27, 33), (33, 33)):
        fill(x, x, 9, 13, z, z, CARVED if (x + z) % 2 else MOSSY)
        put(x, 9, z, SLAB)
    fill(29, 31, 9, 9, 30, 31, WOOD)
    put(30, 9, 31, AIR)
    put(28, 10, 27, TORCH_WALL, 4)
    put(32, 10, 27, TORCH_WALL, 4)
    put(25, 11, 31, LANTERN)
    put(35, 11, 31, LANTERN)
    for x, z in ((25, 34), (35, 34), (24, 27), (36, 27)):
        put(x, 9, z, COBWEB)

    # Hall of Echoes
    line_room(18, 42, 36, 44, 8, 15, "hall", 6)
    carve(29, 31, 9, 11, 35, 36)
    for x in (22, 27, 33, 38):
        for z in (38, 42):
            fill(x, x, 9, 14, z, z, CARVED if (x + z) % 3 else MOSSY)
            for dx in (-1, 1):
                put(x + dx, 9, z, SLAB)
    # Side chapels / niches: shallow alcoves that reward a look around.
    for x, z, side in ((18, 39, "-x"), (42, 39, "+x")):
        for dz in (39, 40, 41):
            carve(x, x, 9, 11, dz, dz)
    torch_on_wall(19, 11, 37, "+z")
    torch_on_wall(41, 11, 37, "+z")
    put(22, 13, 40, LANTERN)
    put(38, 13, 40, LANTERN)
    # A collapsed section of the south-east corner.
    for x in range(38, 43):
        for z in range(43, 45):
            if h(x, 0, z, "hallfall") % 100 < 45:
                put(x, 9, z, COBBLE if h(x, 1, z, "fall") % 2 else CRACKED)
    put(20, 9, 43, COBWEB)
    put(40, 9, 37, COBWEB)

    # Barracks (west), with cells and bunks
    line_room(6, 19, 36, 48, 8, 13, "barracks", 8)
    carve(17, 18, 9, 11, 39, 41)
    # Two rough cell partitions with working gates.
    for z in (42, 45):
        for x in range(9, 18):
            put(x, 9, z, FENCE)
            put(x, 10, z, FENCE)
        put(13, 9, z, FENCE_GATE, 0)
        carve(13, 13, 9, 10, z, z)
    # Bunks: wood frames and coarse wool.
    for z in (38, 40, 44):
        fill(10, 12, 9, 9, z, z, WOOD)
        put(11, 10, z, WOOL_BROWN if z % 2 else WOOL_RED)
        put(10, 10, z, FENCE)
    put(10, 9, 45, CHEST)
    put(17, 9, 45, BARREL)
    put(17, 9, 38, BARREL)
    put(8, 10, 39, TORCH_WALL, 2)
    put(15, 11, 44, LANTERN)
    put(12, 9, 48, COBWEB)
    put(16, 12, 43, COBWEB)

    # Cistern: one block of water, dry walkways and a bridge.
    line_room(42, 53, 34, 50, 8, 13, "cistern", 12)
    carve(42, 44, 9, 11, 39, 41)
    # Lower the pool basin and flood it.
    carve(45, 50, 8, 8, 37, 47)
    for x in range(45, 51):
        for z in range(37, 48):
            put(x, 7, z, CRACKED if h(x, 7, z, "pool") % 3 else MOSSY)
            put(x, 8, z, WATER)
    # Bridge at walkway height.
    for x in range(44, 52):
        for z in (39, 40, 41):
            put(x, 8, z, SLAB)
    for x in range(44, 52):
        put(x, 8, 39, BRICK)
        put(x, 8, 41, BRICK)
    # Dry ledge with supplies.
    fill(44, 45, 8, 8, 34, 38, BRICK)
    put(44, 9, 36, CHEST)
    put(45, 9, 37, BARREL)
    put(51, 9, 47, CAULDRON)
    put(44, 10, 34, TORCH_WALL, 4)
    put(52, 10, 45, TORCH_WALL, 3)
    put(46, 12, 44, LANTERN)
    put(49, 9, 49, COBWEB)
    put(44, 12, 50, COBWEB)
    # Broken water channels in the floor.
    for x in range(45, 50):
        if h(x, 8, 46, "channel") % 100 < 35:
            put(x, 7, 46, GRAVEL)

    # Seal chamber (south), taller and more formal.
    line_room(22, 38, 45, 55, 8, 16, "seal", 4)
    carve(29, 31, 9, 11, 44, 45)
    # The entry door is a working dark-oak pair.
    for x in (29, 30):
        put(x, 9, 45, DOOR_B, 0)
        put(x, 10, 45, DOOR_T, 0)
    # Dais: one clean step up from the chamber floor.
    for x in range(26, 35):
        for z in range(48, 54):
            floor_face(x, z, 9, "dais")
    for x in range(27, 34):
        for z in range(49, 54):
            put(x, 9, z, CARVED if (x + z) % 2 else MOSSY)
    # Four corner pillars + a ribbed ceiling.
    for x, z in ((24, 47), (36, 47), (24, 53), (36, 53)):
        fill(x, x, 9, 15, z, z, CARVED if (x + z) % 2 else MOSSY)
        put(x, 9, z, SLAB)
        put(x, 15, z, SLAB)
    for z in (47, 50, 53):
        for x in (25, 30, 35):
            put(x, 15, z, SLAB)
    # Rune band around the chamber.
    for x in range(23, 38):
        put(x, 13, 46, CARVED if x % 2 else CRACKED)
    for z in range(46, 55):
        put(23, 13, z, CARVED if z % 2 else CRACKED)
        put(37, 13, z, CARVED if z % 2 else CRACKED)
    # Braziers and cold lanterns.
    for x in (25, 35):
        put(x, 10, 52, CAMPFIRE)
        put(x, 12, 46, TORCH_WALL, 4)
    put(30, 14, 48, CHAIN)
    put(30, 13, 48, SOUL_LANTERN)
    put(26, 10, 53, CHEST)
    put(34, 10, 53, BARREL)
    put(24, 12, 54, COBWEB)
    put(37, 9, 45, COBWEB)
    # The pedestal stands on the dais; runtime places the quest nodes here.
    # Keep the two blocks it occupies clear so placement is deterministic.
    carve(29, 31, 10, 11, 52, 52)


def open_crypt_connections() -> None:
    """Punch the walking route through the three-block-thick room shells.

    line_room() builds a solid wall ring inside its bounds.  These openings
    are cut after every room and door exists, so the door nodes themselves are
    preserved.  Widths are three blocks (two for the door pair), which also
    gives skeletons room to path through without getting stuck.
    """
    carve(24, 26, 9, 11, 28, 30)   # stair corridor -> antechamber
    carve(29, 31, 9, 11, 34, 38)   # antechamber -> hall
    carve(17, 20, 9, 11, 39, 41)   # hall -> barracks
    carve(41, 45, 9, 11, 39, 41)   # hall -> cistern
    carve(29, 31, 9, 11, 43, 44)   # hall -> seal doorway
    carve(29, 31, 9, 11, 46, 47)   # seal doorway -> seal chamber


def keep() -> None:
    # Outer shell: 2 blocks thick, 11 high, with a pitched, partly collapsed roof.
    for x in range(14, 47):
        for z in range(30, 52):
            on_edge = x in (14, 15, 45, 46) or z in (30, 31, 50, 51)
            if not on_edge:
                continue
            # Door opening.
            if 29 <= x <= 30 and z <= 31:
                continue
            for y in range(24, 35):
                if y < 32 and h(x, y, z, "keep") % 100 < 4:
                    continue
                wall_face(x, y, z, "keep", 10)
            # Arrow slits.
            if (z in (30, 51) and x in (20, 26, 34, 40)) or (x in (14, 46) and z in (35, 40, 46)):
                for y in (28, 31):
                    carve(x, x, y, y, z, z)
    # A continuous floor under the shell, so the keep never floats over a
    # grassy trench.  This also forms the threshold from the courtyard.
    for x in range(14, 47):
        for z in range(30, 52):
            floor_face(x, z, 23, "keepbase", 8)
    # Interior floor: wood in the west rooms, stone in the hall and solar.
    for x in range(16, 45):
        for z in range(32, 50):
            if x <= 26 and z <= 39:
                put(x, 23, z, WOOD if h(x, 0, z, "libfloor") % 5 else DARK_WOOD)
            elif x >= 34 and z <= 39:
                floor_face(x, z, 23, "armfloor", 8)
            else:
                floor_face(x, z, 23, "hallfloor", 4)
    # Main double door.
    for x in (29, 30):
        put(x, 24, 30, DOOR_B, 0)
        put(x, 25, 30, DOOR_T, 0)
        carve(x, x, 26, 27, 30, 30)
    # Interior partition walls with wide arches.
    for z in range(32, 40):
        for y in range(24, 27):
            if z in (35, 36):
                continue
            put(27, y, z, brick(27, y, z, "libpart", 8))
    for z in range(32, 40):
        for y in range(24, 27):
            if z in (35, 36):
                continue
            put(33, y, z, brick(33, y, z, "armpart", 8))
    for x in range(16, 44):
        for y in range(24, 27):
            if x in (29, 30, 31):
                continue
            put(x, y, 42, brick(x, y, 42, "solarpart", 8))
    # Library: shelves, a reading table and a collapsed mezzanine beam.
    for z in range(33, 39):
        put(16, 25, z, BOOKSHELF)
        put(16, 26, z, BOOKSHELF)
        put(25, 25, z, BOOKSHELF if z % 2 else AIR)
    for x in range(18, 25):
        put(x, 25, 32, BOOKSHELF)
    fill(19, 22, 24, 24, 35, 36, WOOD)
    put(19, 25, 35, FLOWER_POT)
    for x in (19, 22):
        put(x, 24, 34, STAIR, 2)
    put(17, 29, 36, CHAIN)
    put(17, 28, 36, LANTERN)
    # Fallen beam and broken shelf in the library corner.
    for x in range(21, 25):
        put(x, 24, 39, DARK_WOOD)
    put(24, 24, 39, COBWEB)
    # Armory: anvils, furnace, barrels, weapon racks.
    for x, z in ((36, 34), (39, 34), (42, 34)):
        put(x, 24, z, ANVIL)
    put(44, 24, 32, FURNACE, 2)
    put(35, 24, 32, FURNACE, 3)
    for x, z in ((37, 38), (41, 38), (43, 37)):
        put(x, 24, z, BARREL)
    for z in range(35, 39):
        put(35, 25, z, FENCE)
        if z % 2 == 0:
            put(35, 26, z, TORCH_WALL, 3)
    put(42, 24, 39, CHEST)
    put(36, 30, 38, CHAIN)
    put(36, 29, 38, LANTERN)
    put(44, 24, 38, COBWEB)
    # Great hall pillars, banners of soot, and a broken chandelier.
    for x in (18, 24, 30, 36, 42):
        for z in (33, 41):
            if x in (27, 33):
                continue
            fill(x, x, 24, 33, z, z, CARVED if (x + z) % 3 else MOSSY)
            put(x, 24, z, SLAB)
    put(30, 33, 37, CHAIN)
    put(30, 32, 37, LANTERN)
    put(30, 31, 37, CHAIN)
    put(30, 30, 37, LANTERN)
    # Solar / dining hall.
    fill(24, 36, 24, 24, 45, 46, WOOD)
    for x in (25, 28, 31, 34):
        put(x, 25, 45, FLOWER_POT if x % 2 else AIR)
        put(x, 24, 44, STAIR, 2)
        put(x, 24, 47, STAIR, 0)
    for x in (22, 38):
        put(x, 24, 46, FENCE)
        put(x, 25, 46, CAMPFIRE)
    put(30, 25, 50, CARVED)
    put(29, 24, 50, CAMPFIRE)
    put(31, 24, 50, CAMPFIRE)
    # Deep collapse in the west bay: sky, rubble and a fallen column.
    for x in range(16, 21):
        for z in range(43, 48):
            if h(x, 34, z, "hole") % 100 < 55:
                put(x, 34, z, AIR)
                if h(x, 33, z, "hole2") % 100 < 25:
                    put(x, 33, z, AIR)
            if h(x, 24, z, "rubble") % 100 < 28:
                put(x, 24, z, COBBLE if h(x, 0, z, "rubble2") % 2 else CRACKED)
    for z in range(44, 47):
        put(18, 24, z, COBBLE)
        put(18, 25, z, COBBLE)
    # Roof: stepped slabs on the east, collapsed to the west.  No stair
    # facedir tricks in the load-bearing roof.
    for x in range(14, 47):
        if x < 27 and h(x, 0, 30, "roofwest") % 100 < 60:
            continue
        # Height rises toward the ridge at x=30, then falls to the east wall.
        rise = min(x - 14, 46 - x)
        top = 35 + max(0, min(4, rise // 3))
        for z in range(30, 52):
            if h(x, top, z, "roofhole") % 100 < 10:
                continue
            put(x, top, z, SLAB if (x + z) % 2 else BRICK)
            if z in (30, 51):
                put(x, top + 1, z, BRICK)
    # Gable triangles in the end walls.
    for z in (30, 51):
        for x in range(16, 45):
            rise = min(x - 14, 46 - x)
            top = 35 + max(0, min(4, rise // 3))
            for y in range(35, top + 1):
                if h(x, y, z, "gable") % 100 < 15:
                    continue
                wall_face(x, y, z, "gable", 18)
    # Buttresses outside the keep.
    for z in (32, 38, 44, 49):
        for y in range(24, 31):
            wall_face(13, y, z, "buttress", 12)
            wall_face(47, y, z, "buttress", 12)
        put(13, 31, z, SLAB)
        put(47, 31, z, SLAB)
    # A few visible torches on the courtyard face of the keep.
    for x in (18, 24, 36, 42):
        put(x, 27, 30, TORCH_WALL, 4)
    put(29, 28, 29, LANTERN)
    put(30, 28, 29, LANTERN)


def ruin_pass() -> None:
    """Cracks, moss, missing roof tiles, fallen masonry and cobwebs."""
    # Surface masonry: deterministic patches of moss and missing upper stones.
    for x in range(14, 47):
        for z in range(30, 52):
            if get(x, 34, z) == BRICK and h(x, 34, z, "roofmoss") % 100 < 12:
                put(x, 34, z, MOSSY)
    # Weeds in courtyard cracks.
    for x in range(8, 53):
        for z in range(8, 30):
            if get(x, 23, z) in (CRACKED, COBBLE, GRAVEL) and h(x, 24, z, "weed") % 100 < 2:
                put(x, 24, z, DEADBUSH if h(x, 0, z, "weed2") % 2 else FERN)
    # Cobwebs at high crypt corners.
    for x, y, z in ((25, 13, 28), (35, 13, 34), (19, 14, 37), (41, 14, 43),
                    (9, 12, 37), (16, 12, 47), (44, 12, 35), (51, 12, 49),
                    (23, 15, 46), (37, 15, 52)):
        if get(x, y, z) == AIR:
            put(x, y, z, COBWEB)


def verify() -> dict:
    errors: list[str] = []
    missing = sorted({name for name, _ in GRID.values() if name != AIR})
    # Every schematic name must resolve in the game's node registry.  The map
    # colour table covers all placeable nodes except the door pair, whose
    # registered names are dynamic but stable.
    colors_path = ROOT / "mods/ITEMS/mcl_maps/colors.json"
    if colors_path.exists():
        colors = json.loads(colors_path.read_text(encoding="utf-8"))
        unknown = [n for n in missing if n not in colors and not n.startswith("mcl_doors:")]
        if unknown:
            errors.append("palette names do not resolve: " + ", ".join(unknown))
    # Critical walkable clearances: the spawn anchors must have solid floor,
    # two air blocks above them and not be water.
    anchors = [
        ("antechamber", 30, 9, 31), ("hall", 30, 9, 40), ("barracks", 15, 9, 40),
        ("cistern", 44, 9, 40), ("seal", 30, 9, 47), ("landing", 10, 9, 27),
    ]
    for label, x, y, z in anchors:
        if get(x, y - 1, z) not in (BRICK, CRACKED, MOSSY, CARVED, GRAVEL,
                                    SLAB, WOOD, COBBLE):
            errors.append(f"{label}: no solid floor at {x},{y - 1},{z}")
        if get(x, y, z) != AIR or get(x, y + 1, z) != AIR:
            errors.append(f"{label}: blocked headroom at {x},{y},{z}")
    # Connectivity from the outside gate to the pedestal, treating doors,
    # gates, water and slabs as passable.
    passable = {AIR, DOOR_B, DOOR_T, FENCE_GATE, WATER, SLAB, LADDER,
                TORCH, TORCH_WALL, LANTERN, LANTERN_FLOOR, CHAIN,
                SOUL_LANTERN, COBWEB, DEADBUSH, FERN}
    start = (30, 23, 4)  # on the approach, just outside the gate
    goal = (30, 10, 49)  # on the dais, directly in front of the pedestal
    # A conservative walking model: feet and head must be free, there must be
    # a floor directly below, and a player may step up one block or drop up to
    # three.  This deliberately does not model swimming or jumping over walls.
    def solid_floor(pos: tuple[int, int, int]) -> bool:
        return get(*pos) not in (AIR, WATER, COBWEB)
    def standable(pos: tuple[int, int, int]) -> bool:
        x, y, z = pos
        return (inside(x, y, z) and inside(x, y + 1, z)
                and get(x, y, z) in passable
                and get(x, y + 1, z) in passable
                and solid_floor((x, y - 1, z)))
    seen = {start}
    queue = [start]
    while queue:
        x, y, z = queue.pop(0)
        if (x, y, z) == goal:
            break
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = x + dx, z + dz
            candidates = []
            for dy in (0, 1, -1, -2, -3):
                if standable((nx, y + dy, nz)):
                    candidates.append((nx, y + dy, nz))
                    break
            for pos in candidates:
                if pos not in seen:
                    seen.add(pos)
                    queue.append(pos)
    if goal not in seen:
        errors.append("no connected route from the gate to the pedestal")
    # Quest markers and encounter spawn points must be clear and supported.
    markers = {
        "pedestal base": (30, 10, 52), "return gate": (33, 24, 9),
        "return crypt": (10, 9, 28),
    }
    for label, x, y, z in [(k, v[0], v[1], v[2]) for k, v in markers.items()]:
        if get(x, y, z) not in (AIR, WATER):
            errors.append(f"{label}: marker cell is occupied at {x},{y},{z}")
        if get(x, y - 1, z) in (AIR, WATER):
            errors.append(f"{label}: marker has no support at {x},{y - 1},{z}")
    # The pedestal top is placed on top of the runtime base, so the schematic
    # only needs to leave both cells clear.
    for x, y, z in ((30, 11, 52), (30, 12, 52)):
        if get(x, y, z) != AIR:
            errors.append(f"pedestal stack: blocked at {x},{y},{z}")
    for room, positions in {
        "antechamber": [(28, 9, 29), (32, 9, 33), (30, 9, 32)],
        "hall": [(24, 9, 40), (36, 9, 40), (30, 9, 43)],
        "seal": [(26, 10, 50), (34, 10, 50), (30, 9, 47)],
    }.items():
        for x, y, z in positions:
            if get(x, y, z) != AIR or get(x, y + 1, z) != AIR:
                errors.append(f"{room}: encounter spawn blocked at {x},{y},{z}")
            if get(x, y - 1, z) in (AIR, WATER):
                errors.append(f"{room}: encounter spawn has no floor at {x},{y},{z}")

    # Torch count and door count are reported for manual review.
    counts: dict[str, int] = {}
    for name, _ in GRID.values():
        if name != AIR:
            counts[name] = counts.get(name, 0) + 1
    return {
        "errors": errors,
        "nodes": sum(1 for name, _ in GRID.values() if name != AIR),
        "doors": sum(counts.get(k, 0) for k in (DOOR_B, DOOR_T)),
        "torches": counts.get(TORCH, 0) + counts.get(TORCH_WALL, 0),
        "lanterns": sum(counts.get(k, 0) for k in (LANTERN, LANTERN_FLOOR, SOUL_LANTERN)),
        "rooms": 5,
        "walkable_goal": goal in seen,
        "counts": dict(sorted(counts.items())),
    }


def write_mts(path: Path) -> dict:
    palette = sorted({name for name, _ in GRID.values()} | {AIR})
    ids = {name: i for i, name in enumerate(palette)}
    ordered = [GRID.get((x, y, z)) for z in range(D) for y in range(H) for x in range(W)]
    content = bytearray()
    for item in ordered:
        content += struct.pack(">H", 0 if item is None else ids[item[0]])
    content += bytes([MTSM_PROB_ALWAYS]) * len(ordered)
    for item in ordered:
        content.append(0 if item is None else item[1])
    out = bytearray()
    out += struct.pack(">IHHHH", MTSM_SIGNATURE, MTSM_VERSION, W, H, D)
    out += bytes([MTSM_PROB_ALWAYS]) * H
    out += struct.pack(">H", len(palette))
    for name in palette:
        raw = name.encode("utf-8")
        out += struct.pack(">H", len(raw))
        out += raw
    out += zlib.compress(bytes(content), 9)
    path.write_bytes(out)
    return {"path": str(path.relative_to(ROOT)), "bytes": len(out),
            "sha256": hashlib.sha256(out).hexdigest(), "palette": palette}


def manifest() -> dict:
    return {
        "id": "sello_ruinas",
        "version": 1,
        "size": [W, H, D],
        "anchor": [-30, 61, -30],
        "surface_floor_y": 23,
        "gate_local": [30, 23, 6],
        "trailhead_offset": [0, -20],
        "camp_offset": [0, -32],
        "rooms": [
            {"id": "antechamber", "label": "Cámara de entrada", "center": [30, 9, 31],
             "radius": 6, "mobs": ["mobs_mc:skeleton", "mobs_mc:skeleton"],
             "spawns": [[28, 9, 29], [32, 9, 33], [30, 9, 32]],
             "hint": "Los guardianes de la entrada han despertado. Velas y piedra húmeda."},
            {"id": "hall", "label": "Salón de los Ecos", "center": [30, 9, 40],
             "radius": 6, "mobs": ["mobs_mc:zombie", "mobs_mc:skeleton"],
             "spawns": [[24, 9, 40], [36, 9, 40], [30, 9, 43]],
             "hint": "Algo arrastra los pies entre las columnas del salón."},
            {"id": "seal", "label": "Cámara del Sello", "center": [30, 9, 50],
             "radius": 6, "final": True, "mobs": ["mobs_mc:zombie", "mobs_mc:skeleton"],
             "spawns": [[26, 10, 50], [34, 10, 50], [30, 9, 47]],
             "hint": "El sello brilla sobre el pedestal. Sus últimos guardianes no piensan cederlo."},
        ],
        "side_rooms": [
            {"id": "barracks", "label": "Barracones", "center": [13, 9, 40]},
            {"id": "cistern", "label": "Cisterna", "center": [47, 9, 42]},
        ],
        "pedestal": {"base": [30, 10, 52], "top": [30, 11, 52],
                     "display": [30, 12, 52]},
        "return_stones": [[33, 24, 9], [10, 9, 28]],
        "loot": [
            {"pos": [10, 9, 45], "items": ["mcl_core:iron_ingot 2", "mcl_farming:bread 2"]},
            {"pos": [44, 9, 36], "items": ["mcl_core:gold_ingot 1", "mcl_torches:torch 6"]},
            {"pos": [26, 10, 53], "items": ["mcl_core:diamond 1", "mcl_core:iron_ingot 2"]},
            {"pos": [42, 24, 39], "items": ["mcl_core:iron_ingot 2", "mcl_farming:bread 2"]},
        ],
    }


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rough_plateau()
    courtyard_and_surface()
    stair_down()
    crypt()
    open_crypt_connections()
    keep()
    ruin_pass()
    report = verify()
    info = write_mts(OUT_MTS)
    data = manifest()
    data["build"] = info
    data["verify"] = report
    OUT_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8")
    print(json.dumps({"mts": {k: info[k] for k in ("path", "bytes", "sha256")},
                      "verify": {k: report[k] for k in
                                 ("errors", "nodes", "doors", "torches",
                                  "lanterns", "walkable_goal")}},
                     ensure_ascii=False, indent=2))
    if report["errors"]:
        for err in report["errors"]:
            print("ERROR:", err, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
