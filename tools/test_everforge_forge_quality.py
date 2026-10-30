#!/usr/bin/env python3
"""Focused regressions for Everforge's probabilistic modular-forge quality.

Run with: python3 tools/test_everforge_forge_quality.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "mods/MISC/everforge/init.lua").read_text(encoding="utf-8")

QUALITIES = ("common", "uncommon", "rare", "epic", "legendary")
EXPECTED = {
    "common": (7500, 1800, 550, 130, 20),
    "uncommon": (4500, 3500, 1500, 400, 100),
    "rare": (2500, 3000, 3000, 1200, 300),
    "epic": (1200, 2000, 3000, 2800, 1000),
    "legendary": (500, 1000, 2000, 3500, 3000),
}


def parse_chances() -> dict[str, dict[str, int]]:
    match = re.search(r"local quality_chances = \{(.*?)\n\}", SOURCE, re.S)
    if not match:
        raise AssertionError("central quality_chances table is missing")
    rows: dict[str, dict[str, int]] = {}
    for tier, fields in re.findall(r"^\s*(\w+)\s*=\s*\{([^}]*)\},?$", match.group(1), re.M):
        values = {name: int(value) for name, value in re.findall(r"(\w+)\s*=\s*(\d+)", fields)}
        rows[tier] = values
    return rows


class ForgeQualityRegressions(unittest.TestCase):
    def test_all_tiers_are_retained_and_each_probability_row_sums_to_100_percent(self) -> None:
        rows = parse_chances()
        self.assertEqual(set(rows), set(QUALITIES))
        for tier in QUALITIES:
            with self.subTest(catalyst=tier):
                self.assertEqual(tuple(rows[tier][q] for q in QUALITIES), EXPECTED[tier])
                self.assertEqual(sum(rows[tier].values()), 10_000)
                self.assertEqual(set(rows[tier]), set(QUALITIES))

    def test_higher_catalyst_strictly_improves_each_upper_tail_without_guaranteeing_tier(self) -> None:
        rows = parse_chances()
        for low, high in zip(QUALITIES, QUALITIES[1:]):
            for cutoff in range(1, len(QUALITIES)):
                low_tail = sum(rows[low][q] for q in QUALITIES[cutoff:])
                high_tail = sum(rows[high][q] for q in QUALITIES[cutoff:])
                self.assertGreater(high_tail, low_tail, (low, high, QUALITIES[cutoff]))
            self.assertLess(rows[high][high], 10_000)
            self.assertGreater(rows[high]["common"], 0)

    def test_preview_does_not_roll_and_actual_craft_rolls_once(self) -> None:
        prediction = SOURCE.split("core.register_craft_predict(function", 1)[1].split("end)", 1)[0]
        actual = SOURCE.split("core.register_on_craft(function(itemstack, _player, old_craft_grid)", 1)[1].split("end)", 1)[0]
        self.assertIn("build_modular_tool(itemstack, old_craft_grid, false)", prediction)
        self.assertIn("build_modular_tool(itemstack, old_craft_grid, true)", actual)

        build = SOURCE.split("local function build_modular_tool(", 1)[1].split("\nend\n\ncore.register_craft_predict", 1)[0]
        self.assertIn('local quality_name = real_craft and roll_quality(catalyst_tier) or "common"', build)
        self.assertIn('meta:get_string("everforge:quality_pending") == "1"', build)
        self.assertIn('meta:set_string("everforge:quality_pending", real_craft and "" or "1")', build)
        roll = SOURCE.split("local function roll_quality(", 1)[1].split("\nend", 1)[0]
        self.assertIn("quality_rng:next(1, 10000)", roll)
        self.assertIn('preview and S("Quality is determined at crafting; preview uses Common stats.")', SOURCE)
        self.assertIn('S("Craft quality: @1", quality.label)', SOURCE)

    def test_every_assembly_still_uses_existing_quality_recipes_and_catalysts(self) -> None:
        recipes = SOURCE.split("local function register_modular_assembly_recipes()", 1)[1].split("register_modular_assembly_recipes()", 1)[0]
        for tier in QUALITIES:
            self.assertIn(tier, recipes)
        for catalyst in ("mcl_core:iron_nugget", "mcl_core:gold_nugget", "mcl_core:lapis", "mcl_core:diamond"):
            self.assertIn(catalyst, SOURCE)
        self.assertIn('meta:set_string("everforge:quality", quality_name)', SOURCE)
        self.assertIn("apply_modular_stack(itemstack, not real_craft)", SOURCE)


if __name__ == "__main__":
    unittest.main(verbosity=2)
