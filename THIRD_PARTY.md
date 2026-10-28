# Third-party mods and attribution

The following upstream sources are bundled in this repository and adapted for Mineclonia. Each source is pinned to the exact commit listed here (the `version` is the commit SHA, not a moving branch). Original license and copyright notices are retained in each mod directory.

| Mod | Upstream | Pinned source | License | Integration |
|---|---|---|---|---|
| More Ores | https://github.com/minetest-mods/moreores | `73c8696c82ab43d36560d3818ca105d9773c8461` | zlib (see `mods/ITEMS/moreores/LICENSE.md`) | Included; Mineclonia tool groups and `mcl_levelgen` ore features adapted. |
| Adamantine | https://github.com/ArcticExpanseTM/Adamantine | `8098bbb01090201d2165e1fb31ca4821fac142dd` | GPL-3.0-or-later (see `mods/ITEMS/adamantine/LICENSE`) | Included; ore generation adapted to `mcl_levelgen`; native Mineclonia tools/armor retained. |
| Toolranks | https://github.com/lisacvuk/minetest-toolranks | `05eea5177e4c804eea6fdf77eccd141405b38613` | LGPL-2.1-or-later (see `mods/ITEMS/toolranks/LICENCE`) | The upstream rank concept is ported; unsafe generic groupcap buffs are omitted. |
| Melterns (code inspected; six icons reused) | https://github.com/InfiniteCoder01/melterns | `0091c21443b045ec04b62b240c4eee746af6bc42` | MIT | No upstream code is vendored because it requires external `fluid_lib` and the `default` game API. Six original 16×16 part silhouettes (`tinkering_pickaxe_head`, `tinkering_axe_head`, `tinkering_shovel_head`, `tinkering_sword_blade`, `tinkering_tool_binding`, `tinkering_tool_rod`) are reused as color-tinted Everforge item icons. The full MIT license is retained at `mods/MISC/everforge/textures/LICENSE-MELTERNS.txt`. |

The specified Classy, Skills & States, Extra Structures 1.5.0, and More Danger names did not resolve to matching, installable original GitHub repositories in the available source search. They are therefore implemented as the bundled native Everforge progression, structure, and scaling systems rather than as renamed or remote dependencies. These implementations contain no third-party code from those unverified names.
