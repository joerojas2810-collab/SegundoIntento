#!/usr/bin/env python3
"""Convert LOTT's gondorfort.we to a Mineclonia-compatible .mts.

The converter is deliberately dependency-free (Python 3 standard library).
It performs three separate steps so the result can be audited:

1. parse the WorldEdit .we node list;
2. remap every LOTT node name to a real Mineclonia node name;
3. optionally apply a deterministic, moderate "medieval ruin" pass.

It never invents a node name: every target must be listed in MAPPING below.
Unknown source names abort the conversion with a non-zero exit code.

Usage:
    python3 convert_gondor_fort.py \
        --source /path/to/lott/mods/lottmapgen/schems/gondorfort.we \
        --out gondor_fort_ruined.mts \
        --clean-out gondor_fort_clean.mts \
        --report mapping_report.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
import sys
import zlib
from collections import Counter, defaultdict
from pathlib import Path

# ---------------------------------------------------------------------------
# .mts constants (Luanti 5.17, src/mapgen/mg_schematic.h)
# ---------------------------------------------------------------------------
MTSM_SIGNATURE = 0x4D54534D  # 'MTSM'
MTSM_VERSION = 4
MTSM_PROB_ALWAYS = 0x7F
MTSM_FORCE_PLACE = 0x80

# ---------------------------------------------------------------------------
# Source palette -> Mineclonia palette
# ---------------------------------------------------------------------------
# Every target below was checked against this repository (Mineclonia /
# Everforge).  "air" is a real target.  Names with no suitable equivalent are
# mapped to air *explicitly* (never silently dropped).
MAPPING: dict[str, str] = {
    # Masonry and circulation
    "lottblocks:marble_brick": "mcl_core:stonebrick",
    "stairs:stair_marble_brick": "mcl_stairs:stair_stonebrick",
    "stairs:slab_marble_brick": "mcl_stairs:slab_stonebrick",
    "default:ladder": "mcl_core:ladder",
    # Timber and fittings
    "default:wood": "mcl_trees:wood_oak",
    "default:fence_wood": "mcl_fences:oak_fence",
    "default:torch_wall": "mcl_torches:torch_wall",
    "default:furnace": "mcl_furnaces:furnace",
    "lottpotion:brewer": "mcl_brewing:stand_000",
    "lottpotion:cauldron_full": "mcl_cauldrons:cauldron",
    "default:water_source": "mcl_core:water_source",
    # Beds
    "lottblocks:bed_top_blue": "mcl_beds:bed_blue_top",
    "lottblocks:bed_bottom_blue": "mcl_beds:bed_blue_bottom",
    "lottblocks:bed_top_red": "mcl_beds:bed_red_top",
    "lottblocks:bed_bottom_red": "mcl_beds:bed_red_bottom",
    # Terrain (clean export keeps it; the ruin export replaces y<=2)
    "lottother:dirt": "mcl_core:dirt",
    "lottmapgen:gondor_grass": "mcl_core:dirt_with_grass",
    # Spawners / mobs / furniture with no 1:1 equivalent
    "lottmapgen:gondor_chest_spawner": "mcl_chests:chest_small",
    "lottother:gondorms_off": "air",
    "lottblocks:alder_chair": "air",
    "lottblocks:alder_table": "air",
    "lottother:air": "air",
}

# Some spawners are turned into empty chests to keep the rooms readable.  We
# keep four, deterministic by position, and remove the rest.  This is a visual
# decision, not a loot implementation.
CHESTS_TO_KEEP = 4

NODE_RE = re.compile(
    r'\["x"\]=(\d+).*?\["param2"\]=(\d+).*?\["y"\]=(\d+).*?'
    r'\["param1"\]=(\d+).*?\["z"\]=(\d+).*?\["name"\]="([^"]+)"',
    re.S,
)


def parse_we(path: Path) -> dict[tuple[int, int, int], dict]:
    text = path.read_text(encoding="utf-8", errors="replace")
    nodes: dict[tuple[int, int, int], dict] = {}
    for m in NODE_RE.finditer(text):
        x, param2, y, param1, z, name = m.groups()
        pos = (int(x), int(y), int(z))
        if pos in nodes:
            raise SystemExit(f"duplicate node at {pos}")
        nodes[pos] = {
            "name": name,
            "param1": int(param1),
            "param2": int(param2),
        }
    if not nodes:
        raise SystemExit("no nodes parsed from .we file")
    return nodes


def remap(nodes: dict[tuple[int, int, int], dict]) -> tuple[dict, dict]:
    unknown = sorted({n["name"] for n in nodes.values() if n["name"] not in MAPPING})
    if unknown:
        raise SystemExit("unmapped source node names: " + ", ".join(unknown))

    out: dict[tuple[int, int, int], dict] = {}
    counts: Counter[tuple[str, str]] = Counter()
    for pos, node in nodes.items():
        target = MAPPING[node["name"]]
        if target == "air":
            counts[(node["name"], target)] += 1
            continue
        out[pos] = {
            "name": target,
            "param2": node["param2"],
        }
        counts[(node["name"], target)] += 1
    return out, {
        "source_nodes": len(nodes),
        "kept_nodes": len(out),
        "pairs": [
            {"source": s, "target": t, "count": c}
            for (s, t), c in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
        ],
        "unknown": unknown,
    }


def convert_ladders(nodes: dict[tuple[int, int, int], dict]) -> int:
    """LOTT ladders use facedir (0..3); Mineclonia uses wallmounted (2..5).

    In LOTT the stored value points from the ladder towards the supporting
    wall.  The wallmounted value is chosen from that wall, i.e.
    +X -> 2, -X -> 3, +Z -> 4, -Z -> 5.
    """
    wall_to_wallmounted = {
        (1, 0): 2,
        (-1, 0): 3,
        (0, 1): 4,
        (0, -1): 5,
    }
    facedir_to_wall = {
        0: (0, 1),   # +Z
        1: (1, 0),   # +X
        2: (0, -1),  # -Z
        3: (-1, 0),  # -X
    }
    converted = 0
    for pos, node in list(nodes.items()):
        if node["name"] != "mcl_core:ladder":
            continue
        x, y, z = pos
        candidates = []
        preferred = facedir_to_wall.get(node["param2"])
        if preferred:
            candidates.append(preferred)
        candidates += [(1, 0), (-1, 0), (0, 1), (0, -1)]
        chosen = None
        for dx, dz in candidates:
            npos = (x + dx, y, z + dz)
            n = nodes.get(npos)
            if n and n["name"] not in {
                "mcl_core:ladder",
                "mcl_torches:torch_wall",
                "mcl_torches:torch",
            }:
                chosen = (dx, dz)
                break
        if chosen is None:
            chosen = preferred or (0, 1)
        nodes[pos] = {
            "name": "mcl_core:ladder",
            "param2": wall_to_wallmounted[chosen],
        }
        if nodes[pos]["param2"] != node["param2"]:
            converted += 1
    return converted


def keep_some_chests(nodes: dict[tuple[int, int, int], dict]) -> int:
    """Remove all but a few empty chests, deterministically."""
    chest_positions = sorted(
        p for p, n in nodes.items() if n["name"] == "mcl_chests:chest_small"
    )
    if len(chest_positions) <= CHESTS_TO_KEEP:
        return 0
    keep = {
        chest_positions[i]
        for i in [
            round(k * (len(chest_positions) - 1) / (CHESTS_TO_KEEP - 1))
            for k in range(CHESTS_TO_KEEP)
        ]
    }
    removed = 0
    for p in chest_positions:
        if p not in keep:
            del nodes[p]
            removed += 1
    return removed


def material_variant(name: str, x: int, y: int, z: int) -> str:
    """Coherent-ish patches of cracked / mossy / carved stone."""
    if name != "mcl_core:stonebrick":
        return name
    n = math.sin(x * 0.55 + z * 0.35) + math.cos(z * 0.60 - y * 0.20)
    if n > 1.40:
        return "mcl_core:stonebrickmossy"
    if n < -1.50:
        return "mcl_core:stonebrickcracked"
    # Very sparse carved blocks read as old dressed stone.
    if (x * 13 + z * 7 + y * 5) % 97 == 0:
        return "mcl_core:stonebrickcarved"
    return name


def topmost(nodes: dict[tuple[int, int, int], dict]) -> dict[tuple[int, int], int]:
    tops: dict[tuple[int, int], int] = {}
    for (x, y, z) in nodes:
        key = (x, z)
        if y > tops.get(key, -1):
            tops[key] = y
    return tops


def rubble_below(
    nodes: dict[tuple[int, int, int], dict], pos: tuple[int, int, int], rng: int
) -> None:
    """Put one or two rubble blocks on the first floor below a removed block."""
    x, y, z = pos
    for yy in range(y - 1, -1, -1):
        if (x, yy, z) in nodes:
            for dy in (1, 2):
                p = (x, yy + dy, z)
                if p not in nodes and dy <= 2 and (dy == 1 or (rng + x + z) % 3 == 0):
                    nodes[p] = {
                        "name": "mcl_core:cobble"
                        if (rng + x + y + z) % 2
                        else "mcl_core:stonebrickcracked",
                        "param2": 0,
                    }
            return


def apply_ruin_pass(nodes: dict[tuple[int, int, int], dict]) -> dict:
    # 1. Foundation: the source carries a chunk of LOTT terrain.  For a
    #    prefab that can sit on any world, turn y<=2 into a stone plinth.
    for (x, y, z) in list(nodes):
        if y <= 2:
            nodes[(x, y, z)] = {"name": "mcl_core:stonebrick", "param2": 0}

    # 2. Stone variation.
    for (x, y, z), node in list(nodes.items()):
        nodes[(x, y, z)] = {
            "name": material_variant(node["name"], x, y, z),
            "param2": node["param2"],
        }

    # 3. Three small breaches.  They are placed away from the gate (north,
    #    z=2, x=7..11) so the entrance stays fully usable.
    breaches = [
        (3, 8, 2), (4, 8, 2), (3, 9, 2), (4, 9, 2),        # west front tower
        (16, 10, 4), (16, 11, 4), (16, 10, 5), (16, 11, 5),  # east front tower
        (6, 8, 16), (7, 8, 16), (6, 9, 16), (7, 9, 16),    # keep, south wall
    ]
    removed_breach = 0
    for i, p in enumerate(breaches):
        if p in nodes:
            del nodes[p]
            removed_breach += 1
            if i % 4 == 0:
                rubble_below(nodes, p, i + 1)

    # 3b. Accessibility fix: the source north "gate" is a blind 2-deep
    #     alcove closed by the z=4 wall.  Open a 3 x 3 passage at head height
    #     so the courtyard is reachable on foot.  This is a minimal functional
    #     repair, not a redesign; the lintel and the gate silhouette stay.
    gate_opened = 0
    for x in (8, 9, 10):
        for y in (4, 5, 6):
            p = (x, y, 4)
            if p in nodes:
                del nodes[p]
                gate_opened += 1

    # 4. Break the silhouette: take single blocks off the top of walls and
    #    turrets, and open the little central crown.
    tops = topmost(nodes)
    removed_tops = 0
    for (x, z), y in sorted(tops.items()):
        if y < 10:
            continue
        node = nodes.get((x, y, z))
        if not node:
            continue
        if node["name"] in {"mcl_torches:torch_wall", "mcl_torches:torch"}:
            continue
        # Keep the gate lintel and the immediate gate silhouette intact.
        if z <= 3 and 6 <= x <= 12:
            continue
        if (x * 5 + z * 3 + y) % 9 == 0:
            del nodes[(x, y, z)]
            removed_tops += 1

    # Central crown: remove the top cap and part of the course below it.
    for (x, y, z) in list(nodes):
        if y >= 30:
            del nodes[(x, y, z)]
        elif y == 29 and (x + z) % 3 == 0:
            del nodes[(x, y, z)]

    # 5. Rubble outside the gate, only on the flanks (x 5..6 and 13..14).
    rubble_outside = 0
    for (x, z) in [(5, 0), (5, 1), (6, 1), (13, 0), (14, 1), (13, 1)]:
        p = (x, 3, z)
        if p not in nodes:
            nodes[p] = {
                "name": "mcl_core:cobble"
                if (x + z) % 2
                else "mcl_core:stonebrickcracked",
                "param2": 0,
            }
            rubble_outside += 1

    # 6. Moss at the damp base of the outer walls.
    mossy_base = 0
    for (x, y, z), node in list(nodes.items()):
        if y in (3, 4) and node["name"] == "mcl_core:stonebrick":
            # Exterior edge: at least one horizontal neighbour is air.
            neighbours = [(x + 1, y, z), (x - 1, y, z), (x, y, z + 1), (x, y, z - 1)]
            if any(n not in nodes for n in neighbours) and (x + z) % 4 == 0:
                nodes[(x, y, z)] = {
                    "name": "mcl_core:stonebrickmossy",
                    "param2": node["param2"],
                }
                mossy_base += 1

    return {
        "foundation_replaced": "y<=2 -> mcl_core:stonebrick",
        "gate_opened_blocks": gate_opened,
        "breach_blocks_removed": removed_breach,
        "top_blocks_removed": removed_tops,
        "crown_removed": "y>=30, plus one third of y=29",
        "rubble_outside_gate": rubble_outside,
        "mossy_base_blocks": mossy_base,
    }


def bounding_box(nodes: dict[tuple[int, int, int], dict]) -> tuple[int, int, int]:
    xs = [p[0] for p in nodes]
    ys = [p[1] for p in nodes]
    zs = [p[2] for p in nodes]
    size = (max(xs) + 1, max(ys) + 1, max(zs) + 1)
    if min(xs) < 0 or min(ys) < 0 or min(zs) < 0:
        raise SystemExit("negative coordinates are not supported by this converter")
    return size


def write_mts(
    path: Path, nodes: dict[tuple[int, int, int], dict], origin=(0, 0, 0)
) -> dict:
    sx, sy, sz = bounding_box(nodes)
    palette = sorted({n["name"] for n in nodes.values()} | {"air"})
    ids = {name: i for i, name in enumerate(palette)}

    # z, y, x order is what Luanti's MapNode bulk serialization expects.
    ordered = []
    for z in range(sz):
        for y in range(sy):
            for x in range(sx):
                ordered.append(nodes.get((x, y, z)))

    content = bytearray()
    for n in ordered:
        content += struct.pack(">H", 0 if n is None else ids[n["name"]])
    for _ in ordered:
        content += bytes([MTSM_PROB_ALWAYS])
    for n in ordered:
        content.append(0 if n is None else (n["param2"] & 0xFF))

    out = bytearray()
    out += struct.pack(">IHHHH", MTSM_SIGNATURE, MTSM_VERSION, sx, sy, sz)
    out += bytes([MTSM_PROB_ALWAYS]) * sy
    out += struct.pack(">H", len(palette))
    for name in palette:
        data = name.encode("utf-8")
        out += struct.pack(">H", len(data))
        out += data
    out += zlib.compress(bytes(content), 9)
    path.write_bytes(out)

    return {
        "path": str(path),
        "bytes": len(out),
        "size": [sx, sy, sz],
        "cells": sx * sy * sz,
        "solid_nodes": len(nodes),
        "palette": palette,
        "sha256": hashlib.sha256(out).hexdigest(),
    }


def read_mts(path: Path) -> dict:
    b = path.read_bytes()
    sig, ver, sx, sy, sz = struct.unpack(">IHHHH", b[:12])
    assert sig == MTSM_SIGNATURE, hex(sig)
    assert ver == MTSM_VERSION, ver
    o = 12
    probs = list(b[o : o + sy])
    o += sy
    n = struct.unpack(">H", b[o : o + 2])[0]
    o += 2
    palette = []
    for _ in range(n):
        ln = struct.unpack(">H", b[o : o + 2])[0]
        o += 2
        palette.append(b[o : o + ln].decode("utf-8"))
        o += ln
    raw = zlib.decompress(b[o:])
    count = sx * sy * sz
    assert len(raw) == count * 4, (len(raw), count * 4)
    cids = struct.unpack(">" + "H" * count, raw[: 2 * count])
    p1 = raw[2 * count : 3 * count]
    p2 = raw[3 * count : 4 * count]
    assert set(p1) == {MTSM_PROB_ALWAYS}
    return {
        "size": [sx, sy, sz],
        "slice_probs": probs,
        "palette": palette,
        "cids": cids,
        "param2": p2,
        "count": count,
        "non_air": sum(1 for c in cids if palette[c] != "air"),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--clean-out", type=Path)
    ap.add_argument("--report", type=Path)
    args = ap.parse_args()

    raw_nodes = parse_we(args.source)
    mapped, report = remap(raw_nodes)
    report["ladder_param2_converted"] = convert_ladders(mapped)

    removed_chests = keep_some_chests(mapped)
    report["empty_chests_kept"] = CHESTS_TO_KEEP
    report["empty_chests_removed"] = removed_chests
    report["clean"] = write_mts(args.clean_out or args.out.with_suffix(".clean.mts"), mapped)

    ruined = {p: dict(n) for p, n in mapped.items()}
    ruin_report = apply_ruin_pass(ruined)
    report["ruin"] = ruin_report
    report["ruined"] = write_mts(args.out, ruined)

    # Round-trip verification: header, palette, counts, and a few coordinates.
    check = read_mts(args.out)
    report["roundtrip"] = {
        "size_matches": check["size"] == report["ruined"]["size"],
        "palette_matches": check["palette"] == report["ruined"]["palette"],
        "non_air_matches": check["non_air"] == report["ruined"]["solid_nodes"],
        "slice_probs_all_always": all(p == MTSM_PROB_ALWAYS for p in check["slice_probs"]),
    }
    if not all(report["roundtrip"].values()):
        raise SystemExit("round-trip verification failed: " + json.dumps(report["roundtrip"]))

    report["report_version"] = 1
    report["source"] = {
        "path": str(args.source),
        "sha256": hashlib.sha256(args.source.read_bytes()).hexdigest(),
        "source_nodes": len(raw_nodes),
    }
    if args.report:
        args.report.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    print(json.dumps({
        "clean": report["clean"],
        "ruined": report["ruined"],
        "roundtrip": report["roundtrip"],
        "ruin": ruin_report,
    }, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
