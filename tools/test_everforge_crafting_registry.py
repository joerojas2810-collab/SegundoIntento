#!/usr/bin/env python3
"""Source checks for the beginner guide's Mineclonia recipe families.

Run with: python3 tools/test_everforge_crafting_registry.py
These checks inspect source registrations and do not launch Luanti.
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CRAFTING = (ROOT / "mods/MISC/everforge/crafting_guide.lua").read_text(encoding="utf-8")
CORE_CRAFT = (ROOT / "mods/ITEMS/mcl_core/crafting.lua").read_text(encoding="utf-8")
TREES = (ROOT / "mods/ITEMS/mcl_trees/api.lua").read_text(encoding="utf-8")
TABLE = (ROOT / "mods/ITEMS/mcl_crafting_table/init.lua").read_text(encoding="utf-8")
TOOLS = (ROOT / "mods/ITEMS/mcl_tools/init.lua").read_text(encoding="utf-8")
TOOL_SETS = (ROOT / "mods/ITEMS/mcl_tools/register.lua").read_text(encoding="utf-8")
HOES = (ROOT / "mods/ITEMS/mcl_farming/hoes.lua").read_text(encoding="utf-8")
TORCH = (ROOT / "mods/ITEMS/mcl_torches/register.lua").read_text(encoding="utf-8")
FURNACE = (ROOT / "mods/ITEMS/mcl_furnaces/init.lua").read_text(encoding="utf-8")
CHEST = (ROOT / "mods/ITEMS/mcl_chests/init.lua").read_text(encoding="utf-8")
BED = (ROOT / "mods/ITEMS/mcl_beds/beds.lua").read_text(encoding="utf-8")
BED_API = (ROOT / "mods/ITEMS/mcl_beds/api.lua").read_text(encoding="utf-8")
AUTOGROUP = (ROOT / "mods/CORE/_mcl_autogroup/init.lua").read_text(encoding="utf-8")
CRAFTGUIDE = (ROOT / "mods/HELP/mcl_craftguide/init.lua").read_text(encoding="utf-8")


def compact(text: str) -> str:
    return re.sub(r"\s+", "", text)


class RegisteredRecipeSource(unittest.TestCase):
    def test_logs_planks_sticks_and_table_are_registered(self) -> None:
        self.assertIn('output = "mcl_core:stick 4"', CORE_CRAFT)
        self.assertIn('output = "mcl_trees:wood_"..name.." "..wood_amount', TREES)
        self.assertIn('single = {output = "mcl_trees:wood_"..name.." "..wood_amount}', TREES)
        self.assertIn('wood_amount = p.wood_amount or 4', TREES)
        self.assertIn('output = "mcl_crafting_table:crafting_table"', TABLE)
        self.assertIn('"group:wood", "group:wood"', TABLE)
        self.assertIn('crafting_output = tdef._mcl_crafting_output', AUTOGROUP)
        self.assertIn('core.register_craft({', AUTOGROUP)

    def test_five_tool_families_and_material_variants_come_from_live_registrations(self) -> None:
        for kind in ('"axe"', '"pick"', '"shovel"', '"sword"'):
            self.assertIn(f'[{kind}]', TOOLS)
        self.assertIn('craft_shapes = {', HOES)
        self.assertIn('material = "group:wood"', TOOL_SETS)
        self.assertIn('material = "group:cobble"', TOOL_SETS)
        self.assertIn('craftable = false', TOOL_SETS)
        self.assertIn('if materialdefs.craftable then', TOOLS)
        self.assertIn('core.register_craft({', TOOLS)

    def test_survival_recipes_and_bed_variants_match_source(self) -> None:
        self.assertIn('output = "mcl_torches:torch 4"', TORCH)
        self.assertIn('output = "mcl_furnaces:furnace"', FURNACE)
        self.assertIn('output = "mcl_chests:chest"', CHEST)
        self.assertIn('output = "mcl_beds:bed_"..color.."_bottom"', BED)
        self.assertIn('"group:bed", "mcl_dyes:"..color', BED)
        self.assertIn('recipe = def.recipe', BED_API)
        self.assertIn('mcl_wool:"..color', compact(BED))
        self.assertIn('enable_bed_respawn', BED_API)
        self.assertIn('enable_bed_night_skip', BED_API)

    def test_guide_never_registers_recipes_and_reads_the_engine_catalog(self) -> None:
        self.assertIn('core.get_all_craft_recipes(itemname)', CRAFTING)
        self.assertNotIn('core.register_craft(', CRAFTING)
        self.assertIn('mcl_craftguide.show(name)', CRAFTING)
        self.assertIn('mcl_craftguide_progressive_mode', CRAFTGUIDE)
        self.assertIn('Default progressive filter', CRAFTGUIDE)
        self.assertIn('Collect items to reveal more recipes', CRAFTGUIDE)
        self.assertIn('mcl_tools:' + '" .. entry.tool .. "_" .. setname', CRAFTING)
        self.assertIn('mcl_trees:wood_([%w_]+)', CRAFTING)
        self.assertIn('mcl_beds:bed_([%w_]+)_bottom', CRAFTING)


if __name__ == "__main__":
    unittest.main(verbosity=2)
