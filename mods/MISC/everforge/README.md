# Everforge RPG systems

This bundled Mineclonia integration is enabled automatically as part of the `MISC` modpack. It uses Mineclonia's existing XP, player physics, tools, mobs and `mcl_levelgen` APIs; it does not require players to install separate mods.

## In-game systems

- **Progression:** use `/everforge` to choose one permanent class and spend persistent skill points. One skill point is earned per five Mineclonia XP levels. Vanguard reduces mob/player melee damage by 10%; Ranger gains movement bonuses; Arcanist gains bonus dungeon XP; Smith improves nearby alloy smelting. Player physics bonuses are registered through `playerphysics`; player meta stores class, earned/spent points and ranks.
- **Forge:** craft an Alloy Melter from iron, stone and a Mineclonia furnace. Insert an ore/raw metal and a fuel item in the left input slots. The output slot produces alloy ingots. Forged heads, bindings and handles combine into modular pickaxes, axes, shovels and swords. These tools use `_mcl_diggroups`; the Deep Miner perk reduces wear only on Everforge tools and does not alter Mineclonia's mining tiers.
- **Minerals:** More Ores adds tin, silver and mithril; Adamantine adds its endgame ore, tools and armor. Both source mods are bundled, and their ore generation is registered as `mcl_levelgen` features for new chunks. The Adamantine tier requires a diamond-level pickaxe; the More Ores dig groups follow the upstream Mineclonia definitions.
- **Dungeons:** newly generated overworld chunks can contain a Graveyard or Ice Tower. Each has a sealed reward cache and a limited guardian spawner. Loot is initialized on mapblock load. The structures are generated through native `mcl_levelgen` features.
- **Progressive danger:** Mineclonia's global difficulty and mob definitions are left intact. Everforge applies bounded HP/damage growth to supported `mobs_mc` monsters by underground depth and adds a local bonus at dungeon spawners.
- **Tool ranks:** the Mineclonia port records persistent tool use and displays ranks. It deliberately does not change generic groupcaps or Mineclonia dig groups, preserving native drop levels, speeds and durability.

## Persistence and compatibility

Class/skill data and individual tool-rank counts are stored in player/item metadata. Existing players receive an unassigned class and can choose once. The module uses `mcl_experience.get_level`, `playerphysics.add_physics_factor`, `mcl_tools` definitions and `mcl_levelgen` feature registration; it does not replace those APIs.

Structures and ore deposits affect only chunks generated after the integration is enabled. Existing map data is not changed. Existing chunks will not retroactively gain the new ores or structures. Graveyard and Ice Tower placement requires Mineclonia's standard `singlenode` levelgen; on other mapgens Everforge logs a warning, while RPG progression, forging, native ore fallback and enemy scaling remain available.

## Attribution and source selection

The corresponding names **Classy**, **Skills & States**, **Melterns**, **Extra Structures 1.5.0**, and **More Danger** could not be resolved to installable original GitHub repositories matching the requested Mineclonia/Luanti target. To avoid shipping broken remote dependencies, Everforge supplies native implementations for their RPG progression, melting/modular crafting, Graveyard/Ice Tower structures, and depth/dungeon difficulty roles. The original Melterns GitHub repository was inspected but depends on `fluid_lib` (hosted outside the allowed upstream source hosts) and expects the `default` game API; its non-runnable source is not vendored. The original Toolranks generic groupcap multipliers are likewise not safe for Mineclonia, so only a Mineclonia-native metadata/rank port is included.

The integrated original mod sources are listed in the repository-level `THIRD_PARTY.md`, pinned to immutable Git commit IDs. Each retains its upstream license file. This integration does not bundle a Luanti engine or alter game worlds.
