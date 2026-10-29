#!/usr/bin/env python3
"""Focused checks for the reused Extra Structures 1.4.0 Birch Ruins assets."""

from pathlib import Path
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
SCHEMATICS = ROOT / "mods/MISC/everforge/schematics/extra_structures_1_4"

# MTS palettes in these source schematics after replacing the obsolete cracked
# slab node with the equivalent registered Mineclonia stone-brick slab.
COMPATIBLE_NODES = {
    "air",
    "mcl_core:dirt",
    "mcl_core:dirt_with_grass",
    "mcl_core:stone",
    "mcl_core:stonebrick",
    "mcl_core:stonebrickcarved",
    "mcl_core:stonebrickcracked",
    "mcl_core:stonebrickmossy",
    "mcl_stairs:slab_stonebrick",
    "mcl_stairs:slab_stonebrick_top",
    "mcl_campfires:campfire",
    "mcl_chests:chest_small",
}


def read_mts(path):
    data = path.read_bytes()
    if data[:4] != b"MTSM":
        raise AssertionError(f"{path.name}: missing MTSM header")
    version, sx, sy, sz = struct.unpack(">HHHH", data[4:12])
    offset = 12 + sy  # One y-slice probability byte per schematic layer.
    palette_size, = struct.unpack(">H", data[offset:offset + 2])
    offset += 2
    palette = []
    for _ in range(palette_size):
        name_size, = struct.unpack(">H", data[offset:offset + 2])
        offset += 2
        palette.append(data[offset:offset + name_size].decode("utf-8"))
        offset += name_size
    voxels = zlib.decompress(data[offset:])
    return version, (sx, sy, sz), palette, voxels


class BirchRuinsAssetsTest(unittest.TestCase):
    def test_both_schematics_have_valid_mts_payloads_and_registered_nodes(self):
        expected_sizes = {
            "birch_forest_temple_ruins_1.mts": (7, 5, 7),
            "birch_forest_temple_ruins_2.mts": (9, 4, 9),
        }
        self.assertEqual(set(expected_sizes), {p.name for p in SCHEMATICS.glob("*.mts")})
        for name, expected_size in expected_sizes.items():
            with self.subTest(schematic=name):
                version, size, palette, voxels = read_mts(SCHEMATICS / name)
                self.assertEqual(version, 4)
                self.assertEqual(size, expected_size)
                self.assertEqual(len(voxels), size[0] * size[1] * size[2] * 4)
                self.assertTrue(set(palette).issubset(COMPATIBLE_NODES))
                self.assertNotIn("mcl_stairs:slab_stonebrickcracked", palette)
                self.assertIn("mcl_chests:chest_small", palette)

    def test_native_levelgen_registration_is_scoped_to_birch_biomes(self):
        source = (ROOT / "mods/MISC/everforge/world_features.lua").read_text()
        init = (ROOT / "mods/MISC/everforge/extra_structures.lua").read_text()
        self.assertIn('"everforge:birch_forest_temple_ruins_1"', init)
        self.assertIn('"everforge:birch_forest_temple_ruins_2"', init)
        self.assertIn("BirchForest = true", source)
        self.assertIn("OldGrowthBirchForest = true", source)
        self.assertIn("mcl_levelgen.place_schematic", source)
        self.assertIn("mcl_levelgen.notify_generated", source)
        self.assertIn("mcl_loot.get_multi_loot", init)


if __name__ == "__main__":
    unittest.main()
