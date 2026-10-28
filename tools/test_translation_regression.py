#!/usr/bin/env python3
"""Regression model for Luanti 5.17.0 translation escape handling.

Run with: python3 tools/test_translation_regression.py

This models the relevant builtin translator serialization and server-side
translate_string parser. It is not an in-game test; it also guards the WAILA
call path in init.lua so each independently translated line is resolved before
HUD composition.
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ESC = "\x1b"
ROOT = Path(__file__).resolve().parents[1]
WAILA_SOURCE = ROOT / "mods/MISC/everforge/init.lua"


def core_translate(domain: str, template: str, *args: str) -> str:
    """Serialize the subset of builtin/common/misc_helpers.lua used here."""
    index = 0

    def substitute(match: re.Match[str]) -> str:
        nonlocal index
        code = match.group(1)
        if code.isdigit() and code != "0":
            arg_index = int(code)
            if arg_index != index + 1:
                raise ValueError("translation arguments must be in order")
            if arg_index > len(args):
                raise ValueError("missing translation argument")
            index += 1
            return f"{ESC}F{args[arg_index - 1]}{ESC}E"
        if code == "n":
            return "\n"
        return code

    body = re.sub(r"@(.)", substitute, template)
    if index != len(args):
        raise ValueError("unused translation argument")
    return f"{ESC}(T@{domain}){body}{ESC}E"


def _escape_at(text: str, index: int) -> tuple[str, int]:
    """Read one Luanti escape, returning its payload and next offset."""
    if text[index + 1 : index + 2] == "(":
        end = text.find(")", index + 2)
        if end < 0:
            return text[index + 1 :], len(text)
        return text[index + 2 : end], end + 1
    return text[index + 1 : index + 2], min(len(text), index + 2)


def luanti_517_translate_string(text: str) -> tuple[str, list[str]]:
    """Model the parser's nesting/error behavior, not gettext lookups."""
    warnings: list[str] = []

    def scan_top(start: int, stop_at_end: bool = False) -> tuple[str, int]:
        out: list[str] = []
        i = start
        while i < len(text):
            if text[i] != ESC:
                out.append(text[i])
                i += 1
                continue
            sequence, next_i = _escape_at(text, i)
            i = next_i
            if sequence == "E":
                if stop_at_end:
                    return "".join(out), i
                continue
            if sequence == "F":
                # Outside a translated template, F is just an opaque escape.
                out.append(ESC + "F")
                continue
            if sequence == "T" or sequence.startswith("T@"):
                translated, i = scan_template(i, sequence)
                out.append(translated)
                continue
            out.append(ESC + sequence)
        return "".join(out), i

    def scan_template(start: int, domain_marker: str) -> tuple[str, int]:
        template: list[str] = []
        arguments: list[str] = []
        i = start
        while i < len(text):
            if text[i] != ESC:
                template.append(text[i])
                i += 1
                continue
            sequence, next_i = _escape_at(text, i)
            i = next_i
            if sequence == "E":
                break
            if sequence == "F":
                argument, i = scan_top(i, stop_at_end=True)
                arguments.append(argument)
                template.append(f"@{len(arguments)}")
                continue
            warnings.append(sequence)
            # 5.17.0 logs and ignores any escape other than F/E in a template.


        result = "".join(template)
        for number, argument in enumerate(arguments, 1):
            result = result.replace(f"@{number}", argument)
        return result, i

    result, _ = scan_top(0)
    return result, warnings


class TranslationRegression(unittest.TestCase):
    def test_bad_raw_domain_nesting_reproduces_adamantine_warning(self) -> None:
        adamantine = core_translate("adamantine", "Adamantine Ore")
        malformed = core_translate("everforge", "Block: " + adamantine)

        _, warnings = luanti_517_translate_string(malformed)

        # core.translate's @-escape pass changes the embedded domain marker
        # from T@adamantine to Tadamantine before Luanti parses the template.
        self.assertEqual(warnings, ["Tadamantine"])

    def test_translator_argument_and_waila_lines_are_safe(self) -> None:
        adamantine = core_translate("adamantine", "Adamantine Ore")
        ore = core_translate("everforge", "Ore")
        kind = core_translate("everforge", "Type: @1", ore)
        recommended = core_translate("everforge", "Recommended tool: Pickaxe")

        # This is the production strategy: resolve each WAILA field separately,
        # then join plain strings. A marked argument is also explicitly tested.
        deepslate_adamantine = core_translate(
            "adamantine", "Deepslate Adamantine Ore"
        )
        ordinary_block = core_translate("mcl_core", "Stone")
        line_by_line = [
            luanti_517_translate_string(line)
            for line in (
                adamantine,
                deepslate_adamantine,
                ordinary_block,
                kind,
                recommended,
            )
        ]
        self.assertEqual([warnings for _, warnings in line_by_line], [[]] * 5)
        self.assertEqual(
            [value for value, _ in line_by_line],
            [
                "Adamantine Ore",
                "Deepslate Adamantine Ore",
                "Stone",
                "Type: Ore",
                "Recommended tool: Pickaxe",
            ],
        )

        wrapped = core_translate("everforge", "Block: @1", adamantine)
        translated, warnings = luanti_517_translate_string(wrapped)
        self.assertEqual(warnings, [])
        self.assertEqual(translated, "Block: Adamantine Ore")

    def test_waila_localizes_fields_before_joining(self) -> None:
        source = WAILA_SOURCE.read_text(encoding="utf-8")
        helper_start = source.index("local function localize_waila_lines")
        helper_end = source.index("local function waila_text", helper_start)
        helper = source[helper_start:helper_end]
        waila_start = helper_end
        waila_end = source.index("local function waila_enabled", waila_start)
        waila = source[waila_start:waila_end]

        self.assertIn("core.get_translated_string(lang_code, line)", helper)
        self.assertIn("lines = localize_waila_lines(lines,", waila)
        self.assertLess(waila.index("localize_waila_lines"), waila.index('table.concat(lines, "\\n")'))


if __name__ == "__main__":
    unittest.main(verbosity=2)
