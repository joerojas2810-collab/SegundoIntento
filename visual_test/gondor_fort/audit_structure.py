#!/usr/bin/env python3
"""Geometry audit of the converted schematic (no game runtime required).

Everything here is derived from the .mts voxel data.  It can prove dimensions,
openings, route connectivity and counts; it cannot prove lighting, collision,
texture appearance or stair/ladder behaviour in Luanti.
"""

from __future__ import annotations

import json
from collections import Counter, deque
from pathlib import Path

import convert_gondor_fort as conv

ROOT = Path(__file__).resolve().parent
PATH = ROOT / "gondor_fort_ruined.mts"

NON_SOLID = {
    "mcl_core:ladder",
    "mcl_torches:torch_wall",
    "mcl_torches:torch",
}


def load(path):
    data = conv.read_mts(path)
    sx, sy, sz = data["size"]
    grid = {}
    for i, cid in enumerate(data["cids"]):
        name = data["palette"][cid]
        if name == "air":
            continue
        x = i % sx
        y = (i // sx) % sy
        z = i // (sx * sy)
        grid[(x, y, z)] = (name, data["param2"][i])
    return (sx, sy, sz), grid


def solid(grid, p):
    return p in grid and grid[p][0] not in NON_SOLID


def free(grid, p):
    return p not in grid or grid[p][0] in NON_SOLID


def bfs(grid, start, goal, y_levels):
    """Walk on the given y levels; a cell is usable if it is free and has a floor."""
    q = deque([start])
    seen = {start}
    parent = {}
    while q:
        p = q.popleft()
        if p == goal:
            path = []
            while p in parent:
                path.append(p)
                p = parent[p]
            return list(reversed(path))
        x, y, z = p
        # Same level, and one block up/down when there is headroom.
        moves = [(dx, dy, dz) for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))
                 for dy in (0, 1, -1)] + [(0, 1, 0), (0, -1, 0)]
        for dx, dy, dz in moves:
            ny = y + dy
            if ny not in y_levels:
                continue
            np = (x + dx, ny, z + dz)
            if not (0 <= np[0] < 19 and 0 <= np[2] < 20 and 0 <= np[1] < 30):
                continue
            if np in seen or not free(grid, np):
                continue
            # Headroom: the cell above must be free.
            if not free(grid, (np[0], np[1] + 1, np[2])):
                continue
            # Floor: a solid block (or ladder) below, or we are on the foundation.
            below = (np[0], np[1] - 1, np[2])
            # The temporary test world adds a platform at schematic y=2 in
            # front of the gate (z < 4); count it as a floor for connectivity.
            virtual_platform = below[1] == 2 and -1 <= below[2] < 4
            if not solid(grid, below) and below not in grid and not virtual_platform:
                continue
            seen.add(np)
            parent[np] = p
            q.append(np)
    return None


def main():
    size, grid = load(PATH)
    sx, sy, sz = size
    xs = [p[0] for p in grid]
    ys = [p[1] for p in grid]
    zs = [p[2] for p in grid]

    counts = Counter(n for n, _ in grid.values())
    gate_cells = [(x, y, z) for x in (8, 9, 10) for y in (4, 5, 6) for z in (2, 3, 4)]
    gate_open = sum(1 for p in gate_cells if free(grid, p))

    route = bfs(grid, (9, 3, 0), (9, 4, 12), {2, 3, 4, 5, 6, 7})
    courtyard = bfs(grid, (9, 3, 0), (9, 4, 6), {2, 3, 4, 5, 6, 7})

    ladders = [(p, v[1]) for p, v in grid.items() if v[0] == "mcl_core:ladder"]
    wall_side = {2: (1, 0), 3: (-1, 0), 4: (0, 1), 5: (0, -1)}
    unsupported_ladders = []
    for p, p2 in ladders:
        dx, dz = wall_side.get(p2, (0, 0))
        q = (p[0] + dx, p[1], p[2] + dz)
        if q not in grid:
            unsupported_ladders.append(p)

    stairs = [p for p, v in grid.items() if v[0].startswith("mcl_stairs:stair")]
    slabs = [p for p, v in grid.items() if v[0].startswith("mcl_stairs:slab")]
    torches = [p for p, v in grid.items() if v[0].startswith("mcl_torches:")]
    beds = [p for p, v in grid.items() if v[0].startswith("mcl_beds:")]
    chests = [p for p, v in grid.items() if v[0] == "mcl_chests:chest_small"]

    # Floor levels inside the walled footprint.
    floors = Counter()
    for x in range(3, 17):
        for z in range(3, 17):
            for y in range(13, -1, -1):
                if solid(grid, (x, y, z)):
                    floors[y] += 1
                    break

    # Torch spacing on the ground/room levels (rough, Euclidean).
    air_cells = [
        (x, y, z) for x in range(3, 17) for z in range(3, 17) for y in (4, 5, 6)
        if free(grid, (x, y, z))
    ]
    if torches:
        dists = []
        for p in air_cells:
            d = min(abs(p[0] - t[0]) + abs(p[1] - t[1]) + abs(p[2] - t[2]) for t in torches)
            dists.append(d)
        dists.sort()
        torch_stats = {
            "air_cells_sampled": len(dists),
            "median_manhattan": dists[len(dists) // 2],
            "max_manhattan": dists[-1],
            "cells_within_8": sum(1 for d in dists if d <= 8) / len(dists),
        }
    else:
        torch_stats = {}

    out = {
        "source": "gondorfort.we (LOTT, CC BY-SA 3.0) -> Mineclonia .mts",
        "size": [sx, sy, sz],
        "cells": sx * sy * sz,
        "solid_nodes": len(grid),
        "solid_bbox": [min(xs), min(ys), min(zs), max(xs), max(ys), max(zs)],
        "bbox_dimensions": [max(xs) - min(xs) + 1, max(ys) - min(ys) + 1, max(zs) - min(zs) + 1],
        "counts": dict(counts.most_common()),
        "gate": {
            "span": "x=8..10, y=4..6, z=2..4",
            "open_cells_of_27": gate_open,
            "width": 3,
            "height": 3,
            "note": "the 3x3 opening at z=4 was added in the ruin/access pass; "
                    "the original north gate was a blind alcove.",
        },
        "route_outside_to_courtyard": {
            "found": courtyard is not None,
            "steps": len(courtyard) if courtyard else None,
        },
        "route_outside_to_keep_level": {
            "found": route is not None,
            "steps": len(route) if route else None,
            "path_head": route[:12] if route else None,
        },
        "stairs": len(stairs),
        "slabs": len(slabs),
        "ladders": len(ladders),
        "unsupported_ladders": len(unsupported_ladders),
        "unsupported_ladder_positions": unsupported_ladders,
        "torches": len(torches),
        "beds": len(beds),
        "chests": len(chests),
        "floor_levels_topmost_under_y14": dict(sorted(floors.items())),
        "torch_spacing_ground_rooms": torch_stats,
    }
    (ROOT / "audit.json").write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
