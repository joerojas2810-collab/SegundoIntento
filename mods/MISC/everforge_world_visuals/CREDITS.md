# Everforge World Visuals: assets and licences

This mod bundles one fixed world-art direction: stylized natural voxel scenery that keeps Mineclonia's palette-driven vegetation and familiar block materials. It does not add a style selector, launcher/resource-pack toggle, or network dependency.

## Textures from REFI Textures

The following image files are redistributed without pixel edits. They were relocated and renamed with an `everforge_world_visuals_` prefix so this mod can assign them only to world nodes and leave native menus, logos, inventory icons, and unrelated interfaces alone.

- **Author:** MysticTempest
- **Source:** [REFI_Textures](https://github.com/MysticTempest/REFI_Textures)
- **Pinned source revision:** `33f1f719930d1d202beaa5fa6251c26d3a711149`
- **Licence:** CC-BY-SA-4.0, [Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/)
- **Upstream project statement:** a 16 px pack with Mineclonia support; every bundled image was checked as a 16×16 RGBA PNG at the pinned revision.

| Upstream image | Bundled image | Use |
|---|---|---|
| `textures/default_mcl_core/trees/default_leaves.png` | `textures/everforge_world_visuals_leaves_oak.png` | Oak canopy |
| `textures/default_mcl_core/trees/default_jungleleaves.png` | `textures/everforge_world_visuals_leaves_jungle.png` | Jungle canopy |
| `textures/default_mcl_core/trees/default_acacia_leaves.png` | `textures/everforge_world_visuals_leaves_acacia.png` | Acacia canopy |
| `textures/default_mcl_core/trees/mcl_core_leaves_big_oak.png` | `textures/everforge_world_visuals_leaves_dark_oak.png` | Dark-oak canopy |
| `textures/default_mcl_core/trees/mcl_core_leaves_birch.png` | `textures/everforge_world_visuals_leaves_birch.png` | Birch canopy |
| `textures/default_mcl_core/trees/mcl_core_leaves_spruce.png` | `textures/everforge_world_visuals_leaves_spruce.png` | Spruce canopy |
| `textures/mcl_wild_update/mcl_mangrove_leaves.png` | `textures/everforge_world_visuals_leaves_mangrove.png` | Mangrove canopy |
| `textures/mcl_cherry_blossom/mcl_cherry_blossom_leaves.png` | `textures/everforge_world_visuals_leaves_cherry.png` | Cherry canopy |
| `textures/mcl_pale_oak/mcl_pale_oak_leaves.png` | `textures/everforge_world_visuals_leaves_pale_oak.png` | Pale-oak canopy |
| `textures/mcl_lush_caves/mcl_lush_caves_azalea_leaves.png` | `textures/everforge_world_visuals_leaves_azalea.png` | Azalea canopy |
| `textures/mcl_lush_caves/mcl_lush_caves_azalea_leaves_flowering.png` | `textures/everforge_world_visuals_leaves_azalea_flowering.png` | Flowering azalea canopy |
| `textures/default_mcl_core/soil/mcl_core_grass_block_top.png` | `textures/everforge_world_visuals_grass_top.png` | Grass-block top |
| `textures/default_mcl_core/soil/mcl_core_grass_block_side_overlay.png` | `textures/everforge_world_visuals_grass_side_overlay.png` | Grass-block side overlay |
| `textures/default_mcl_core/soil/mcl_core_dirt_podzol_top.png` | `textures/everforge_world_visuals_podzol_top.png` | Podzol top |
| `textures/default_mcl_core/soil/mcl_core_dirt_podzol_side.png` | `textures/everforge_world_visuals_podzol_side.png` | Podzol side |
| `textures/flowers_mcl_flowers/mcl_flowers_tallgrass.png` | `textures/everforge_world_visuals_tallgrass.png` | In-world short/tall grass tile |
| `textures/flowers_mcl_flowers/mcl_flowers_fern.png` | `textures/everforge_world_visuals_fern.png` | In-world fern tile |
| `textures/flowers_mcl_flowers/mcl_flowers_bush.png` | `textures/everforge_world_visuals_bush.png` | In-world bush tile |
| `textures/flowers_mcl_flowers/mcl_flowers_leaf_litter.png` | `textures/everforge_world_visuals_leaf_litter.png` | Existing leaf-litter mesh, recolored with Mineclonia's existing tint modifier |

## Bushy canopy geometry

- **Inspired/adapted from:** [Bushy Leaves](https://github.com/minetest-mods-camp/bushy_leaves), copyright © 2022 Nils Dagsson Moskopp.
- **Pinned inspected revision:** `9be33ef9c37836414fac7a9dd78125efed77b581`.
- **Licence:** GNU AGPL v3 or later; the full licence is included as `LICENSE-AGPL-3.0-or-later.txt` and this mod's Lua is marked AGPL-3.0-or-later.
- **Changes for this game:** use three orthogonal planes instead of the upstream nine-plane arrangement to limit per-leaf geometry, restrict the effect to registered Mineclonia leaf IDs, and explicitly retain full-cube collision and selection. No upstream image or tree schematic is redistributed as part of that code adaptation.

## Existing Mineclonia assets and behavior

Existing grass, fern, bush, and leaf-litter nodes reuse Mineclonia's registered `mcl_flowers` definitions; the added forest shrub is a separate hidden, non-interactive plant node using the bundled bush texture. The small rock clusters are new, non-interactive nodebox scenery that uses Mineclonia's existing stone/andesite/granite textures; the added scenery nodes have no drops, collision, mining target, recipe, or inventory icon. All other IDs, recipes, palettes, drops, tree schematics, biomes, and player systems remain unchanged.

## Compatibility evidence

The pinned texture source is 16×16 RGBA and declares Mineclonia support. The mod uses Luanti's longstanding `core.override_item` and `core.register_decoration` APIs and the game's existing `mcl_biomes`, `mcl_trees`, `mcl_flowers`, and `mcl_core` mods. The decorations are low-density and only run during normal new-mapblock generation. **No Luanti 5.17.0/Mineclonia 0.124.1 client runtime, multiplayer session, or performance benchmark was available in this workspace**, so exact runtime compatibility and visual performance still require in-game verification.
