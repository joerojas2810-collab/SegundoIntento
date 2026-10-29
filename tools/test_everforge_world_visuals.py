#!/usr/bin/env python3
"""Static asset, API-surface, and mapgen-safety checks for Everforge visuals."""
from __future__ import annotations

import hashlib
import json
import re
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "mods/MISC/everforge_world_visuals"
LUA = (MOD / "init.lua").read_text(encoding="utf-8")
LG_SCRIPT = (MOD / "lg_register.lua").read_text(encoding="utf-8")
CONF = (MOD / "mod.conf").read_text(encoding="utf-8")
LEVELGEN_BIOMES = (ROOT / "mods/MAPGEN/mcl_levelgen/biomes.lua").read_text(encoding="utf-8")
CREDITS = (MOD / "CREDITS.md").read_text(encoding="utf-8")
MANIFEST = json.loads((MOD / "ASSET_MANIFEST.json").read_text(encoding="utf-8"))


class EverforgeWorldVisuals(unittest.TestCase):
    def test_bundled_texture_files_are_pinned_attributed_and_unmodified(self) -> None:
        self.assertEqual(MANIFEST["license"], "CC-BY-SA-4.0")
        self.assertIn("MysticTempest/REFI_Textures", MANIFEST["repository"])
        self.assertIn(MANIFEST["revision"], CREDITS)
        self.assertIn("creativecommons.org/licenses/by-sa/4.0", CREDITS)
        self.assertEqual(len(MANIFEST["assets"]), 19)
        for item in MANIFEST["assets"]:
            data = (MOD / "textures" / item["file"]).read_bytes()
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n", item["file"])
            self.assertEqual(struct.unpack(">II", data[16:24]), (16, 16), item["file"])
            self.assertEqual(data[24], 8, item["file"])
            self.assertEqual(data[25], 6, item["file"])
            self.assertEqual(hashlib.sha256(data).hexdigest(), item["sha256"])
            git_blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
            self.assertEqual(git_blob, item["git_blob_sha1"], item["file"])

    def test_foliage_overrides_only_registered_mineclonia_leaf_families(self) -> None:
        for family in (
            "oak", "jungle", "acacia", "dark_oak", "birch", "spruce",
            "mangrove", "cherry_blossom", "pale_oak", "azalea", "azalea_flowering",
        ):
            self.assertIn(f'["mcl_trees:leaves_{family}"]', LUA)
        self.assertIn('node_name:gsub("_orphan$", "")', LUA)
        self.assertIn('def.groups.leaves', LUA)
        self.assertIn('drawtype = "nodebox"', LUA)
        self.assertIn('selection_box = {', LUA)
        self.assertIn('collision_box = {', LUA)
        self.assertIn('fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}', LUA)
        self.assertIn('mcl_flowers:tallgrass', LUA)
        self.assertIn('mcl_flowers:fern', LUA)
        self.assertIn('mcl_flowers:bush', LUA)
        self.assertIn('modname .. ":forest_shrub"', LUA)
        self.assertIn('pointable = false', LUA)
        self.assertIn('diggable = false', LUA)

    def test_mapgen_decor_is_sparse_and_does_not_change_existing_world_rules(self) -> None:
        self.assertEqual(LUA.count("core.register_decoration({"), 3)
        ratios = [float(x) for x in re.findall(r"fill_ratio = ([0-9.]+)", LUA)]
        self.assertEqual(len(ratios), 3)
        self.assertTrue(all(0 < ratio <= 0.004 for ratio in ratios))
        for biome in ("Forest", "RoofedForest", "BirchForest", "Taiga", "Meadow", "ExtremeHills"):
            self.assertIn(f'"{biome}"', LUA)
        for forbidden in ("core.set_node(", "core.register_craft(", "set_mapgen_setting", "formspec[", "register_on_generated"):
            self.assertNotIn(forbidden, LUA)
        for node in ("mcl_core:stone", "mcl_core:andesite", "mcl_core:granite"):
            self.assertIn(node, LUA)
        self.assertIn('pointable = false', LUA)
        self.assertIn('walkable = false', LUA)
        self.assertIn('diggable = false', LUA)
        self.assertIn('drop = ""', LUA)

    def test_levelgen_decorations_support_singlenode_and_target_real_biomes(self) -> None:
        self.assertIn("mcl_levelgen", CONF)
        self.assertIn('mcl_levelgen.register_levelgen_script(modpath .. "/lg_register.lua")', LUA)
        self.assertIn("lg.register_configured_feature", LG_SCRIPT)
        self.assertIn("lg.register_placed_feature", LG_SCRIPT)
        self.assertIn("lg.generate_feature", LG_SCRIPT)
        self.assertIn('"mcl_levelgen:freeze_top_layer", biomes, 12', LG_SCRIPT)
        self.assertIn('lg.build_heightmap("motion_blocking_wg")', LG_SCRIPT)
        self.assertIn("content_id_set(node_names)", LG_SCRIPT)
        self.assertIn('"mcl_core:dirt_with_grass", "mcl_core:podzol"', LG_SCRIPT)
        self.assertIn('"mcl_core:stone", "mcl_core:andesite", "mcl_core:granite", "mcl_core:diorite"', LG_SCRIPT)
        self.assertIn("mcl_levelgen", (ROOT / "docs/everforge-world-visuals.md").read_text(encoding="utf-8"))

        expected_biomes = (
            "Forest", "DarkForest", "BirchForest", "OldGrowthBirchForest",
            "Taiga", "OldGrowthSpruceTaiga", "OldGrowthPineTaiga", "Meadow",
            "FlowerForest", "CherryGrove", "WindsweptForest", "StonyPeaks",
            "StonyShore", "WindsweptHills", "WindsweptGravellyHills",
        )
        for name in expected_biomes:
            match = re.search(r'mcl_levelgen\.register_biome \("' + re.escape(name) + r'", \{', LEVELGEN_BIOMES)
            self.assertIsNotNone(match, name)
            following = re.search(r'mcl_levelgen\.register_biome \("', LEVELGEN_BIOMES[match.end():])
            end = match.end() + following.start() if following else len(LEVELGEN_BIOMES)
            self.assertIn("mcl_levelgen:freeze_top_layer", LEVELGEN_BIOMES[match.start():end], name)

    def test_submod_uses_only_builtin_dependencies_and_keeps_resource_licenses_separate(self) -> None:
        es = (MOD / "locale/everforge_world_visuals.es.po").read_text(encoding="utf-8")
        for label in ("Field Stone Cluster", "Foothill Stone Cluster", "Mountain Stone Cluster", "Forest Shrub"):
            self.assertIn(f'msgid "{label}"', es)
        self.assertIn("depends = mcl_core, mcl_trees, mcl_flowers, mcl_biomes, mcl_levelgen", CONF)
        self.assertIn("AGPL-3.0-or-later", CONF)
        self.assertTrue((MOD / "LICENSE-AGPL-3.0-or-later.txt").is_file())
        self.assertIn("AGPL-3.0-or-later", LUA.splitlines()[0])
        self.assertIn("Bushy Leaves", CREDITS)
        self.assertIn("Nils Dagsson Moskopp", CREDITS)
        self.assertIn("CC-BY-SA-4.0", CREDITS)
        self.assertIn("launcher/resource-pack toggle", CREDITS.lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)
