#!/usr/bin/env python3
"""Static contract checks for Everforge's welcome cards and native guide.

Run with: python3 tools/test_everforge_onboarding.py
This checks source wiring/content only; it is not an in-engine UI test.
"""
from __future__ import annotations

import ast
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ONBOARDING = (ROOT / "mods/MISC/everforge/onboarding.lua").read_text(encoding="utf-8")
PROGRESSION = (ROOT / "mods/MISC/everforge/progression/model.lua").read_text(encoding="utf-8")
UI = (ROOT / "mods/MISC/everforge/progression/ui.lua").read_text(encoding="utf-8")
CRAFTING = (ROOT / "mods/MISC/everforge/crafting_guide.lua").read_text(encoding="utf-8")
MCL_DOC = (ROOT / "mods/HELP/mcl_doc/init.lua").read_text(encoding="utf-8")
MODCONF = (ROOT / "mods/MISC/everforge/mod.conf").read_text(encoding="utf-8")
ES = (ROOT / "mods/MISC/everforge/locale/everforge.es.po").read_text(encoding="utf-8")
POT = (ROOT / "mods/MISC/everforge/locale/template.pot").read_text(encoding="utf-8")


def po_translation(text: str, msgid: str) -> str | None:
    pattern = re.compile(
        r'^msgid "' + re.escape(json.dumps(msgid, ensure_ascii=False)[1:-1]) + r'"\nmsgstr "((?:[^"\\]|\\.)*)"$',
        re.MULTILINE,
    )
    match = pattern.search(text)
    return match.group(1) if match else None


class EverforgeOnboardingContract(unittest.TestCase):
    def test_five_narrative_titles_are_present_and_translated_as_requested(self) -> None:
        titles = [
            "Un mundo sin destino escrito.",
            "Lo que haces te define.",
            "Forja tu propio camino.",
            "No todo está a la vista.",
            "El mundo continúa contigo.",
        ]
        for title in titles:
            self.assertIn(title, ES)
        self.assertEqual(ONBOARDING.count('title = S("'), 10)

    def test_five_optional_first_steps_cover_the_requested_topics(self) -> None:
        for title in (
            "Tus primeras herramientas",
            "Aprende haciendo",
            "Prepara tu refugio",
            "Descubre lo desconocido",
            "Conoce tus herramientas",
        ):
            self.assertIn(title, ES)
        self.assertIn("axes, pickaxes, shovels, swords and torches", ONBOARDING)
        self.assertIn("five disciplines", ONBOARDING)
        self.assertIn("health and hunger", ONBOARDING)
        self.assertIn("Inventory (I) → Everforge tab → Everforge Guide → Basic Crafting", ONBOARDING)
        self.assertIn("see_basic_recipes", ONBOARDING)
        self.assertIn("Settings > Change keys", ONBOARDING)

    def test_hypertext_uses_global_as_a_style_setting_not_a_container(self) -> None:
        self.assertIn('<global margin=0 valign=top><style color=#F2E8D9>', ONBOARDING)
        self.assertIn('escape_hypertext(translated(player, text)) .. "</style>"', ONBOARDING)
        self.assertNotIn('escape_hypertext(text) .. "</global>', ONBOARDING)

    def test_inventory_tab_has_a_live_direct_route_to_the_guide(self) -> None:
        self.assertIn('S("Everforge Guide")', UI)
        self.assertIn('if fields.guide then', UI)
        self.assertIn('everforge.onboarding.show_hub(player)', UI)
        self.assertIn('build = content, handle = function(player, fields)', UI)

    def test_introduction_matches_the_current_five_discipline_system(self) -> None:
        for discipline in ("mining", "forging", "combat", "exploration", "crafting"):
            self.assertIn(f'"{discipline}"', PROGRESSION)
        self.assertIn("No permanent class locks you into a role", ONBOARDING)
        self.assertNotIn('"everforge:class"', PROGRESSION)

    def test_auto_welcome_is_persisted_per_player_and_waits_for_the_camp(self) -> None:
        self.assertIn('player:get_meta():set_int(META_AUTO_SEEN, 1)', ONBOARDING)
        self.assertIn('player:get_meta():get_int(META_AUTO_SEEN)', ONBOARDING)
        self.assertIn('state == "ready" and player_world_ready(player)', ONBOARDING)
        self.assertIn('core.register_on_joinplayer', ONBOARDING)
        self.assertIn('core.after(0.5, function() try_auto_intro(name, attempt + 1) end)', ONBOARDING)

    def test_skip_close_and_completion_do_not_repeat_automatically(self) -> None:
        self.assertIn('fields.skip', ONBOARDING)
        self.assertIn('fields.close or fields.quit', ONBOARDING)
        self.assertIn('meta:set_int(META_AUTO_SEEN, 1)', ONBOARDING)
        self.assertIn('meta:set_int(META_INTRO_DONE, 1)', ONBOARDING)
        self.assertIn('META_STEPS_OFFERED', ONBOARDING)

    def test_basic_crafting_reuses_registered_recipes_and_keeps_the_full_catalog(self) -> None:
        for section in ("materials", "tools", "survival"):
            self.assertIn(f'{section} = {{', CRAFTING)
        for item in (
            "mcl_trees:tree_oak", "mcl_trees:wood_oak", "mcl_core:stick",
            "mcl_crafting_table:crafting_table", "mcl_tools:pick_wood",
            "mcl_tools:axe_wood", "mcl_tools:shovel_wood", "mcl_tools:sword_wood",
            "mcl_tools:hoe_wood", "mcl_torches:torch", "mcl_furnaces:furnace",
            "mcl_chests:chest", "mcl_beds:bed_red_bottom",
        ):
            self.assertIn(item, CRAFTING)
        self.assertIn("core.get_all_craft_recipes(itemname)", CRAFTING)
        self.assertIn("mcl_craftguide.show(name)", CRAFTING)
        self.assertIn("get_recipe_filters()", CRAFTING)
        self.assertNotIn("core.register_craft(", CRAFTING)
        self.assertIn('"basic_crafting"', ONBOARDING)
        self.assertIn('action == "basic_crafting" or action == "crafting"', ONBOARDING)

    def test_inventory_help_chooser_preserves_the_native_complete_help(self) -> None:
        self.assertIn('type(everforge.onboarding.show_inventory_help) == "function"', MCL_DOC)
        self.assertIn('everforge.onboarding.show_inventory_help(player)', MCL_DOC)
        self.assertIn('doc.show_doc(player:get_player_name())', MCL_DOC)
        self.assertIn('button(2.25, 3.15, 7.6, 0.75, "complete_help"', ONBOARDING)
        self.assertIn('button(2.25, 2.0, 7.6, 0.75, "basic_crafting"', ONBOARDING)

    def test_basic_crafting_strings_are_in_both_catalogues(self) -> None:
        messages = re.findall(r'\bS\("((?:\\.|[^"\\])*)"', CRAFTING)
        for raw in messages:
            msgid = ast.literal_eval('"' + raw + '"')
            self.assertIsNotNone(po_translation(POT, msgid), f"missing POT entry: {msgid}")
            self.assertIsNotNone(po_translation(ES, msgid), f"missing Spanish entry: {msgid}")

    def test_everforge_hub_routes_to_native_help_recipes_and_achievements(self) -> None:
        for route in ("intro", "first_steps", "help", "controls", "commands", "recipes", "basic_crafting", "achievements", "progression"):
            self.assertIn(route, ONBOARDING)
        self.assertIn('doc.show_entry(name, category, entry)', ONBOARDING)
        self.assertIn('mcl_craftguide.show(player:get_player_name())', ONBOARDING)
        self.assertIn('awards.show_to(player:get_player_name(), player:get_player_name(), nil, false)', ONBOARDING)
        self.assertNotIn('_suppress_waila(player, "awards:awards")', ONBOARDING)
        self.assertIn('release_onboarding_waila(player)', ONBOARDING)
        self.assertIn('"basics", "controls"', ONBOARDING)
        self.assertIn('"advanced", "commands"', ONBOARDING)
        self.assertIn('everforge.onboarding.show_hub(player)', UI)
        self.assertIn('optional_depends =', MODCONF)
        self.assertIn('mcl_achievements, awards', MODCONF)

    def test_strings_are_registered_in_both_catalogues(self) -> None:
        self.assertEqual(po_translation(ES, "Card @1 of @2"), "Tarjeta @1 de @2")
        self.assertIsNotNone(po_translation(POT, "Card @1 of @2"))
        self.assertEqual(
            po_translation(ES, "Would you like to see a few first steps?"),
            "¿Quieres conocer algunos primeros pasos?",
        )
        self.assertEqual(po_translation(ES, "Everforge Guide"), "Guía de Everforge")
        self.assertIsNotNone(po_translation(POT, "Everforge Guide"))
        self.assertIn("Para volver a esta guía sin escribir un comando", ES)
        visible = re.findall(r'S\("((?:[^"\\]|\\.)*)"\)', ONBOARDING)
        self.assertFalse(any("Mineclonia" in value for value in visible))

    def test_all_ten_cards_have_exact_spanish_catalogue_keys(self) -> None:
        cards = ONBOARDING.split("local introductions = {", 1)[1].split("local function mark_auto_handled", 1)[0]
        messages = re.findall(r'\b(?:title|text) = S\("((?:\\.|[^"\\])*)"\)', cards)
        self.assertEqual(len(messages), 20)
        for raw in messages:
            msgid = ast.literal_eval('"' + raw + '"')
            self.assertTrue(po_translation(ES, msgid), f"missing Spanish card text: {msgid}")
            self.assertIsNotNone(po_translation(POT, msgid))

    def test_guidance_does_not_create_quests_or_reveal_hidden_content(self) -> None:
        self.assertNotIn("register_on_dig", ONBOARDING)
        self.assertNotIn("register_on_craft", ONBOARDING)
        self.assertNotIn("register_abm", ONBOARDING)
        self.assertNotIn("reward", ONBOARDING.lower())
        self.assertNotIn("secret", ONBOARDING.lower())
        self.assertNotIn("recipe =", ONBOARDING.lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)
