# Everforge RPG systems

This bundled Mineclonia integration is enabled automatically as part of the `MISC` modpack. It uses Mineclonia's existing XP, player physics, tools, mobs and `mcl_levelgen` APIs; it does not require players to install separate mods.

## In-game systems

- **Progression:** `/everforge` opens the Everforge guide; choose **Progress** (or the Everforge inventory tab) to view persistent Mastery (Dominio), five disciplines, general specialization points and four buyable skills. No permanent classes, vanilla XP multiplier, vanilla-level point generator or character migration. See `docs/everforge-playable.md` for provisional curves, rates and the isolated launcher.
- **Shared starting region:** a small terrain-following camp is built once per fresh world, then persists as ordinary editable map nodes. Native beds and respawn anchors keep priority. An interrupted build requires review or a new development world; a completed camp is never automatically rebuilt.
- **Alloy Melter:** smelts More Ores tin/silver/mithril lumps, Adamantine lumps, and Mineclonia raw iron/raw gold into their registered ingots. Use normal Mineclonia fuel. Ingots are not inputs. The updated interface displays all eight output slots; existing melters are refreshed on mapblock load without clearing their inventories.
- **Modular forging:** fabricate material-specific heads, bindings, and reinforced handles from existing tin, copper, iron, gold, silver, mithril, or adamantine ingots. Assemble one head, one binding, and one handle into a pickaxe, axe, shovel, or sword. The chosen materials are stored on the individual ItemStack and listed in its tooltip.
- **Manufacturing quality:** a catalyst in the tool assembly recipe chooses Common, Uncommon, Rare, Epic, or Legendary quality. Quality is independent from each material's rarity. It changes stack-specific damage, attack interval, mining speed, and durability; it never raises the head's Mineclonia mining level. Item metadata and per-stack tool capabilities persist when saved, dropped, traded, or moved between inventories. Finished tools are unstackable.
- **Materials:** More Ores adds tin, silver and mithril; Adamantine adds its endgame ore, tools and armor. Both source mods are bundled, and their ore generation is registered as `mcl_levelgen` features for new chunks. The Adamantine tier requires a diamond-level pickaxe; More Ores dig groups follow the upstream Mineclonia definitions.
- **Structures:** newly generated overworld chunks can contain the existing Everforge Graveyard or Ice Tower, plus the reused Birch Forest Temple Ruins from Extra Structures 1.4.0. Ruins spawn only in Birch Forest variants, retain the upstream chest loot, and use native `mcl_levelgen` features. Graveyard/Ice Tower caches and their limited guardian spawners remain unchanged.
- **Progressive danger:** Mineclonia's global difficulty and mob definitions are left intact. Everforge applies bounded HP/damage growth to supported `mobs_mc` monsters by underground depth and adds a local bonus at dungeon spawners.
- **Tool ranks:** the Mineclonia port records persistent tool use and displays ranks. It deliberately does not change generic groupcaps or Mineclonia dig groups, preserving native drop levels, speeds and durability.

## Welcome and permanent guide

On a character's first entry, five short welcome cards appear once the new-world starting region is ready. Closing or skipping them returns directly to the world; it does not set objectives or modify progression. The optional first-steps cards are suggestions only and can be dismissed without tracking. Player metadata stores the one-time automatic welcome state, while both card sets remain manually available at any time.

Use `/everforge` to open the guide hub. It links to **Introduction**, **First Steps**, **Controls and Commands**, the recipe book, achievements, and Everforge **Progress**. You can also open it without typing a command: press **I** for the inventory, select the **Everforge** tab, then choose **Guía de Everforge**. Alternatively, press **T** to open chat, type `/everforge`, and press **Enter**. **I** and **T** are Luanti's default keys; change them in **Settings → Change keys**. Direct shortcuts are `/everforge intro`, `/everforge first_steps`, `/everforge help`, `/everforge controls`, `/everforge commands`, `/everforge recipes`, `/everforge achievements`, and `/everforge progression`. The controls and command pages use the bundled help entries; the recipe book and achievements open their existing native interfaces. No duplicate help, recipe, or achievement system is added.

The `/everforge` command and native inventory tab are registered again on every game start; the one-time welcome flags do not gate manual access. Close a guide with its **Close** button or the normal formspec close key to return to the world.

The native controls and command articles are supplied by `mcl_doc_basics`, not by Everforge. The repository's Spanish catalogue has translations for all source strings in those two articles (50 controls strings and 22 command strings). The complete help index can also show entries supplied by `doc_items` or other game components; any untranslated text there belongs to those components. Everforge only opens the native pages and does not replace or rewrite their help system. The default inventory/chat keys in Luanti 5.17.0 were checked against `src/defaultsettings.cpp` (`keymap_inventory` = I, `keymap_chat` = T).

## Survival forging recipe guide

### Make the parts

Use an existing ingot in place of each `INGOT` below. All parts are craftable in the normal 3×3 crafting grid:

| Part | Crafting pattern | Result |
|---|---|---|
| Pickaxe head | `INGOT INGOT INGOT` / `— INGOT —` | Pickaxe head of that metal |
| Axe head | `INGOT INGOT` / `INGOT —` | Axe head of that metal |
| Shovel head | One ingot | Shovel head of that metal |
| Sword blade | Two ingots vertically | Sword blade of that metal |
| Binding | `INGOT INGOT` / `Stick —` | Binding of that metal |
| Reinforced handle | Stick / `INGOT` / Stick | Handle reinforced with that metal |

The old `everforge:tool_head`, `everforge:tool_binding`, and `everforge:reinforced_handle` items remain registered as iron parts so existing saved items can still be used. The original component-only recipes remain available and still craft legacy iron tools. New modular recipes require a binding and support mixed materials and quality catalysts.

### Assemble a tool and choose its quality

Place the three parts in the **middle column** of the grid: head in the top row, binding in the middle row, handle in the bottom row. Add one quality catalyst in the indicated corner; leave the corner empty for Common:

| Quality | Catalyst | Grid position |
|---|---|---|
| Common | None | Leave all four corners empty |
| Uncommon | `mcl_core:iron_nugget` | Top-left |
| Rare | `mcl_core:gold_nugget` | Top-right |
| Epic | `mcl_core:lapis` | Bottom-left |
| Legendary | `mcl_core:diamond` | Bottom-right |

**Example — Legendary-quality Adamantine/Mithril/Iron pickaxe:** craft an Adamantine Pickaxe Head, a Mithril Tool Binding, and an Iron-Reinforced Handle. Put them in the middle column, top to bottom, and put one diamond in the bottom-right corner. The diamond is consumed as the Legendary quality catalyst. The resulting tool records all three material choices and Legendary quality; its mining level remains the Adamantine head's level.

The tooltip shows the material and its rarity for each part separately from the manufacturing quality, then reports final damage, attack interval, mining speed, mining level, durability, and the quality bonuses. Compare otherwise identical tools made with no catalyst and with a quality catalyst to see actual capability and wear changes. A stronger binding or handle changes the corresponding final statistics, but only the head controls the `_mcl_diggroups` level and therefore the ores the tool can harvest.

### Balance and persistence

- Head materials set the native Mineclonia mining level: Tin/Gold 2, Copper 3, Iron/Silver 4, Mithril 5, Adamantine 6. The quality catalyst cannot change this.
- Bindings and handles affect durability, attack speed, damage and mining speed. Their modifiers are bounded; the head alone determines mining level.
- Quality bonuses range from Common (+0%) through Legendary (+12% damage, +12% mining speed, +35% durability and +8% attack speed). Final caps are clamped to avoid unbounded values.
- Material names, material rarities, quality, final statistics and `tool_capabilities` are stored on the unstackable ItemStack. The head-level variant is also registered separately so Mineclonia's `mcl_autogroup.can_harvest` checks remain tier-safe.

## Persistence and compatibility

Progression v1 is a single serialized player-metadata record, independent of vanilla XP and retained on death. Individual tool-rank counts remain in item metadata. There are no character migrations in this initial-development release. Existing Alloy Melter inventory LBMs remain unchanged. For iteration, create a new isolated world with the supplied launcher instead of deleting any normal Luanti world.

The module uses `mcl_experience.get_level`, `playerphysics.add_physics_factor`, Mineclonia's `_mcl_diggroups`/`mcl_autogroup`, `mcl_enchanting` and `mcl_levelgen` APIs; it does not replace those APIs. Enchanted modular tools retain component modifiers as well as Efficiency/Unbreaking behavior.

Structures and ore deposits affect only chunks generated after the integration is enabled. Existing map data is not changed. Existing chunks will not retroactively gain the new ores or structures. Everforge structure placement requires Mineclonia's standard `singlenode` levelgen; on other mapgens Everforge logs a warning, while RPG progression, forging, native ore fallback and enemy scaling remain available.

## Attribution and source selection

The ContentDB listing identifies Extra Structures 1.5.0 as a port to `mcl_levelgen`, but its downloadable archive was not accessible for source verification. This integration therefore uses the available 1.4.0 source snapshot (pinned in `THIRD_PARTY.md`): it reuses the two Birch Forest Temple Ruins schematics and ports their placement and original chest loot to native `mcl_levelgen`. One obsolete cracked-stone-brick slab ID in the schematics is mapped to Mineclonia's registered stone-brick slab; the structure is limited to Birch Forest and Old Growth Birch Forest. The graveyard and ice tower from that source are not copied because Everforge already generates them. Other 1.4.0 structures are not included here: the oasis/logger camp/obelisk assets need additional node compatibility review, while the brick pyramid is outside this ruins-focused integration.

The corresponding names **Classy**, **Skills & States**, **Melterns**, and **More Danger** could not be resolved to installable original repositories matching the requested Mineclonia/Luanti target. To avoid shipping broken remote dependencies, Everforge supplies native implementations for their RPG progression, melting/modular crafting, and depth/dungeon difficulty roles. The original Melterns code is not vendored because it requires external `fluid_lib` and expects the `default` game API. Six MIT-licensed, 16×16 part silhouettes from its `tinkering/textures` directory are reused and color-tinted for Everforge component icons; see `textures/LICENSE-MELTERNS.txt` and `THIRD_PARTY.md` for attribution and the pinned source commit.

The integrated original mod sources are listed in the repository-level `THIRD_PARTY.md`, pinned to immutable Git commit IDs. Each retains its upstream license file. This integration does not bundle a Luanti engine or alter game worlds.
