#!/usr/bin/env python3
"""Audit the native controls/commands articles Everforge links to.

Run with: python3 tools/test_everforge_help_translations.py
These articles belong to mcl_doc_basics, not Everforge; the check prevents
Everforge changes from masking missing Spanish strings in the bundled source.
"""
from __future__ import annotations

import ast
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASICS = ROOT / "mods/HELP/mcl_doc_basics/basics.lua"
ADVANCED = ROOT / "mods/HELP/mcl_doc_basics/advanced.lua"
CATALOG = ROOT / "mods/HELP/mcl_doc_basics/locale/mcl_doc_basics.es.po"


def lua_strings_between(path: Path, start: str, end: str) -> list[str]:
    text = path.read_text(encoding="utf-8")
    section = text.split(start, 1)[1].split(end, 1)[0]
    raw = re.findall(r'\bS\("((?:[^"\\]|\\.)*)"\)', section)
    return [ast.literal_eval('"' + item + '"') for item in raw]


def parse_po(path: Path) -> dict[str, str]:
    """Read msgid/msgstr strings, including the PO format's folded lines."""
    entries: dict[str, str] = {}
    fields: dict[str, str] = {}
    active: str | None = None

    def finish() -> None:
        if "msgid" in fields:
            entries[fields["msgid"]] = fields.get("msgstr", "")
        fields.clear()

    for line in path.read_text(encoding="utf-8").splitlines() + [""]:
        if not line:
            finish()
            active = None
        elif line.startswith("msgid "):
            active = "msgid"
            fields[active] = ast.literal_eval(line[6:])
        elif line.startswith("msgstr "):
            active = "msgstr"
            fields[active] = ast.literal_eval(line[7:])
        elif line.startswith('"') and active:
            fields[active] += ast.literal_eval(line)
        else:
            active = None
    return entries


class NativeHelpTranslationAudit(unittest.TestCase):
    def test_controls_and_commands_are_native_and_have_spanish_translations(self) -> None:
        controls = lua_strings_between(
            BASICS, 'doc.add_entry("basics", "controls"', 'doc.add_entry("basics", "point"'
        )
        commands = lua_strings_between(
            ADVANCED, 'doc.add_entry("advanced", "commands"', 'doc.add_entry("advanced", "privs"'
        )
        self.assertGreater(len(controls), 0)
        self.assertGreater(len(commands), 0)
        self.assertIn('core.get_translator(core.get_current_modname())', BASICS.read_text(encoding="utf-8"))

        catalog = parse_po(CATALOG)
        missing = [text for text in controls + commands if not catalog.get(text)]
        self.assertEqual(missing, [], "native help strings missing Spanish translations")
        self.assertIn("• T: Open chat window (chat requires the “shout” privilege)", controls)
        self.assertIn("• /: Start issuing a server command", controls)
        print(f"Audited {len(set(controls))} controls and {len(set(commands))} command strings from mcl_doc_basics.es.po")


if __name__ == "__main__":
    unittest.main(verbosity=2)
