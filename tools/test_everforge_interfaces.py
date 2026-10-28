#!/usr/bin/env python3
"""Static regressions for Everforge forms and melter timer refresh.

Run with: python3 tools/test_everforge_interfaces.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "mods/MISC/everforge/init.lua").read_text(encoding="utf-8")
SLOT_STEP = 1.25  # mcl_formspec.get_itemslot_bg_v4 / Mineclonia list spacing
SLOT_HEIGHT = 1.0


def number(pattern: str, text: str = SOURCE) -> float:
    match = re.search(pattern, text)
    if not match:
        raise AssertionError(f"could not find coordinate pattern: {pattern}")
    return float(match.group(1))


class EverforgeInterfaceRegressions(unittest.TestCase):
    def test_melter_timer_refreshes_open_form_after_authoritative_state(self) -> None:
        start = SOURCE.index("\ton_timer = function(pos)", SOURCE.index('core.register_node("everforge:alloy_melter"'))
        end = SOURCE.index("\n\tend,\n})", start)
        timer = SOURCE[start:end]

        self.assertIn('meta:set_int("progress", progress)', timer)
        self.assertLess(
            timer.index('meta:set_int("progress", progress)'),
            timer.index("update_melter_interface(pos)", timer.index('meta:set_int("progress", progress)')),
        )
        self.assertIn("return true", timer)
        # Keep the existing one-second tick, per-second fuel decrement,
        # one-item input use, one-item output and unchanged recipe timer.
        self.assertIn('core.get_node_timer(pos):start(1)', SOURCE)
        self.assertIn('meta:set_int("burn", meta:get_int("burn") - 1)', timer)
        self.assertIn("input:take_item(1)", timer)
        self.assertIn('local out = ItemStack(recipe.output)', timer)
        self.assertIn('local effective_time = math.max(3, recipe.time - forge_bonus_at(pos))', timer)
        self.assertIn('math.floor(burn * 100 / burn_total + 0.5)', SOURCE)
        self.assertIn('math.floor(meta:get_int("progress") * 100 / effective_time + 0.5)', SOURCE)

    def test_melter_inventory_rows_and_fuel_label_do_not_overlap(self) -> None:
        melter_start = SOURCE.index("local function build_forge_formspec")
        melter_end = SOURCE.index("local function update_melter_interface", melter_start)
        formspec = SOURCE[melter_start:melter_end]
        first_main_y = number(r'list\[current_player;main;0\.375,([0-9.]+);9,3;9\]', formspec)
        hotbar_y = number(r'list\[current_player;main;0\.375,([0-9.]+);9,1;\]', formspec)
        size_y = number(r'"size\[11\.75,([0-9.]+)\]"', formspec)
        main_bottom = first_main_y + 2 * SLOT_STEP + SLOT_HEIGHT
        hotbar_bottom = hotbar_y + SLOT_HEIGHT
        self.assertGreaterEqual(hotbar_y, main_bottom)
        self.assertLessEqual(hotbar_bottom, size_y)

        flame_y = number(r'"image\[2\.1,([0-9.]+);1,1;" \.\. fire', formspec)
        fuel_label_y = number(r'"label\[2\.1,([0-9.]+);" \.\. core\.formspec_escape\(S\("Fuel"\)\)', formspec)
        fuel_slot_y = number(r'forge_slots\(2\.1, ([0-9.]+), 1, 1\)', formspec)
        self.assertGreaterEqual(fuel_label_y, flame_y + SLOT_HEIGHT + 0.1)
        self.assertGreaterEqual(fuel_slot_y, fuel_label_y + 0.2)

    def test_melter_hides_waila_only_while_its_metadata_form_is_open(self) -> None:
        node_start = SOURCE.index('core.register_node("everforge:alloy_melter"')
        node_end = SOURCE.index("-- Refresh already-placed melters", node_start)
        node = SOURCE[node_start:node_end]
        self.assertIn('suppress_waila_for_player(clicker, "melter")', node)
        self.assertIn('if fields.quit and sender and sender:is_player() then', node)
        self.assertIn('restore_waila_for_player(sender, "melter")', node)
        self.assertIn('if waila_suppressed[name] then', SOURCE)
        self.assertIn('waila_suppressed[name] = nil', SOURCE)

    def test_reward_cache_storage_and_player_inventories_are_separated(self) -> None:
        start = SOURCE.index("local function build_reward_cache_formspec")
        end = SOURCE.index('core.register_node("everforge:reward_cache"', start)
        form = SOURCE[start:end]
        storage_y = number(r'forge_slots\(3\.5, ([0-9.]+), 4, 4\)', form)
        inventory_label_y = number(r'"label\[0\.375,([0-9.]+);" \.\. core\.formspec_escape\(S\("Inventory"\)\)', form)
        player_main_y = number(r'list\[current_player;main;0\.375,([0-9.]+);9,3;9\]', form)
        hotbar_y = number(r'list\[current_player;main;0\.375,([0-9.]+);9,1;\]', form)
        size_y = number(r'"formspec_version\[7\]size\[11\.75,([0-9.]+)\]"', form)

        storage_bottom = storage_y + 3 * SLOT_STEP + SLOT_HEIGHT
        player_main_bottom = player_main_y + 2 * SLOT_STEP + SLOT_HEIGHT
        self.assertGreaterEqual(inventory_label_y, storage_bottom)
        self.assertGreaterEqual(player_main_y, inventory_label_y + 0.3)
        self.assertGreaterEqual(hotbar_y, player_main_bottom)
        self.assertLessEqual(hotbar_y + SLOT_HEIGHT, size_y)
        self.assertIn('("list[%s;main;3.5,1;4,4;]"):format(node_inv)', form)
        self.assertIn('("listring[%s;main]"):format(node_inv)', form)

    def test_rpg_layout_fits_its_declared_window_without_rule_changes(self) -> None:
        self.assertIn('"formspec_version[7]size[11.75,6.2]"', SOURCE)
        self.assertIn('button[%s,1.58;2.55,0.5;', SOURCE)
        self.assertIn('local y = 2.75 + (i - 1) * 0.58', SOURCE)
        # Four skill rows end at y=4.89; the modal is 6.2 units tall.
        last_skill_button_bottom = 2.75 + 3 * 0.58 - 0.08 + 0.48
        self.assertLess(last_skill_button_bottom, 6.2)
        # The guide uses doc's own formspec builders; do not override their layout.
        self.assertIn('doc.entry_builders.text_and_gallery', SOURCE)


if __name__ == "__main__":
    unittest.main(verbosity=2)
