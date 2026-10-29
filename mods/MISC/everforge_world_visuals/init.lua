-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Foliage geometry adapts the cross-plane idea from Bushy Leaves by
-- Nils Dagsson Moskopp (AGPL-3.0-or-later). This implementation uses a
-- smaller three-plane canopy for lower per-node geometry cost, an explicit
-- Mineclonia leaf whitelist, and preserves full-cube collision/selection.
-- See CREDITS.md and LICENSE-AGPL-3.0-or-later.txt.
local S = core.get_translator(core.get_current_modname())
local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)

local function texture(name)
	return modname .. "_" .. name .. ".png"
end

-- Mineclonia's leaf nodes keep their IDs, groups, palette/tint, drops,
-- distance-decay, and waving behavior. Only their displayed texture changes.
local leaf_textures = {
	["mcl_trees:leaves_oak"] = texture("leaves_oak"),
	["mcl_trees:leaves_jungle"] = texture("leaves_jungle"),
	["mcl_trees:leaves_acacia"] = texture("leaves_acacia"),
	["mcl_trees:leaves_dark_oak"] = texture("leaves_dark_oak"),
	["mcl_trees:leaves_birch"] = texture("leaves_birch"),
	["mcl_trees:leaves_spruce"] = texture("leaves_spruce"),
	["mcl_trees:leaves_mangrove"] = texture("leaves_mangrove"),
	["mcl_trees:leaves_cherry_blossom"] = texture("leaves_cherry"),
	["mcl_trees:leaves_pale_oak"] = texture("leaves_pale_oak"),
	["mcl_trees:leaves_azalea"] = texture("leaves_azalea"),
	["mcl_trees:leaves_azalea_flowering"] = texture("leaves_azalea_flowering"),
}

local function copy_array(source)
	local result = {}
	for index, value in ipairs(source or {}) do result[index] = value end
	return result
end

local function replace_first_tile(node_name, replacement)
	local def = core.registered_nodes[node_name]
	if not def or type(def.tiles) ~= "table" or #def.tiles == 0 then return end
	local tiles = copy_array(def.tiles)
	tiles[1] = replacement
	core.override_item(node_name, {tiles = tiles})
end

local function install_foliage_visuals()
	for node_name, def in pairs(core.registered_nodes) do
		if def.groups and (def.groups.leaves or 0) > 0 then
			local base_name = node_name:gsub("_orphan$", "")
			local replacement = leaf_textures[base_name]
			if replacement then
				core.override_item(node_name, {
					drawtype = "nodebox",
					node_box = {
						type = "fixed",
						fixed = {
							-- Three intersecting planes keep foliage volumetric with
							-- six visible quads per leaf node, rather than a solid cube.
							{-0.5, -0.5, 0, 0.5, 0.5, 0},
							{0, -0.5, -0.5, 0, 0.5, 0.5},
							{-0.5, 0, -0.5, 0.5, 0, 0.5},
						},
					},
					-- Existing leaves are full cubes for movement/targeting. Keep
					-- that contract even though their rendered shape is crossed.
					selection_box = {
						type = "fixed",
						fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
					},
					collision_box = {
						type = "fixed",
						fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
					},
					tiles = {replacement},
				})
			end
		end
	end

	-- Recoloring/tint palettes and snow variants remain untouched. Replace
	-- only selected non-snow ground textures and in-world plant tiles.
	local grass = core.registered_nodes["mcl_core:dirt_with_grass"]
	if grass and type(grass.tiles) == "table" then
		local tiles = copy_array(grass.tiles)
		tiles[1] = texture("grass_top")
		local overlay_tiles = copy_array(grass.overlay_tiles)
		if overlay_tiles[3] then
			overlay_tiles[3] = {name = texture("grass_side_overlay"), tileable_vertical = false}
		end
		core.override_item("mcl_core:dirt_with_grass", {
			tiles = tiles,
			overlay_tiles = overlay_tiles,
		})
	end

	local podzol = core.registered_nodes["mcl_core:podzol"]
	if podzol and type(podzol.tiles) == "table" then
		local tiles = copy_array(podzol.tiles)
		tiles[1] = texture("podzol_top")
		if tiles[3] then
			tiles[3] = {name = texture("podzol_side"), tileable_vertical = false}
		end
		core.override_item("mcl_core:podzol", {tiles = tiles})
	end

	replace_first_tile("mcl_flowers:tallgrass", texture("tallgrass"))
	replace_first_tile("mcl_flowers:fern", texture("fern"))
	replace_first_tile("mcl_flowers:bush", texture("bush"))
	for variant = 1, 4 do
		local node_name = "mcl_flowers:leaf_litter_" .. variant
		local def = core.registered_nodes[node_name]
		if def then
			replace_first_tile(node_name, texture("leaf_litter") .. "^[multiply:#A37546")
		end
	end
end

-- Small, non-interactive nodebox clusters add natural-scale stones without
-- changing Mineclonia stone nodes, drops, mining, collision, or recipes.
core.register_node(modname .. ":forest_shrub", {
	description = S("Forest Shrub"),
	_doc_items_create_entry = false,
	_doc_items_hidden = true,
	drawtype = "plantlike",
	waving = 1,
	tiles = {texture("bush")},
	paramtype = "light",
	paramtype2 = "color",
	palette = "mcl_core_palette_grass.png",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	drop = "",
	groups = {
		not_in_creative_inventory = 1,
		deco_block = 1,
		plant = 1,
		attached_node = 1,
		biomecolor = 1,
		dig_by_piston = 1,
		dig_by_water = 1,
		destroy_by_lava_flow = 1,
	},
	is_ground_content = false,
})

local full_node = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
local rock_nodes = {
	{
		name = "field_stones",
		description = S("Field Stone Cluster"),
		texture = "mcl_core_stone.png",
		boxes = {
				{-0.43, -0.5, -0.22, -0.13, -0.30, 0.08},
				{-0.09, -0.5, -0.32, 0.22, -0.34, -0.03},
				{0.11, -0.5, 0.09, 0.38, -0.37, 0.34},
			},
	},
	{
		name = "foothill_stones",
		description = S("Foothill Stone Cluster"),
		texture = "mcl_core_andesite.png",
		boxes = {
				{-0.45, -0.5, -0.27, -0.10, -0.20, 0.12},
				{-0.02, -0.5, -0.35, 0.36, -0.27, -0.01},
			},
	},
	{
		name = "mountain_stones",
		description = S("Mountain Stone Cluster"),
		texture = "mcl_core_granite.png",
		boxes = {
				{-0.42, -0.5, -0.28, -0.02, -0.16, 0.18},
				{0.02, -0.5, -0.14, 0.43, -0.28, 0.30},
				{-0.25, -0.5, 0.16, 0.10, -0.35, 0.42},
			},
		},
}

for _, rock in ipairs(rock_nodes) do
	core.register_node(modname .. ":" .. rock.name, {
		description = rock.description,
		_doc_items_create_entry = false,
		_doc_items_hidden = true,
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = rock.boxes},
		-- Not pointable or walkable: these are scenery, not mineable resources.
		selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}},
		collision_box = full_node,
		tiles = {rock.texture},
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		pointable = false,
		diggable = false,
		buildable_to = true,
		drop = "",
		groups = {not_in_creative_inventory = 1, deco_block = 1},
		is_ground_content = false,
	})
end

-- Mapgen decorations affect only newly generated mapblocks. No terrain,
-- tree schematic, mapgen setting, already-saved node, or player construction
-- is rewritten by these registrations.
local overworld_min = mcl_vars.mg_overworld_min
local overworld_max = mcl_vars.mg_overworld_max

local shrub_biomes = {"Forest", "RoofedForest", "BirchForest", "BirchForestM", "Taiga", "Meadow", "FlowerForest"}
for _, biome_name in ipairs(shrub_biomes) do
	local biome = core.registered_biomes[biome_name]
	if biome then
		core.register_decoration({
			deco_type = "simple",
			place_on = {"group:grass_block_no_snow", "mcl_core:podzol"},
			fill_ratio = 0.003,
			biomes = {biome_name},
			y_min = overworld_min,
			y_max = overworld_max,
			param2 = biome._mcl_palette_index or 0,
			decoration = modname .. ":forest_shrub",
		})
	end
end

core.register_decoration({
	deco_type = "simple",
	place_on = {"group:grass_block_no_snow", "mcl_core:podzol"},
	fill_ratio = 0.0015,
	biomes = {"Forest", "RoofedForest", "BirchForest", "BirchForestM", "Taiga", "Meadow", "FlowerForest"},
	y_min = overworld_min,
	y_max = overworld_max,
	decoration = modname .. ":field_stones",
})

core.register_decoration({
	deco_type = "simple",
	place_on = {"mcl_core:stone", "mcl_core:andesite", "mcl_core:granite", "mcl_core:diorite"},
	fill_ratio = 0.004,
	biomes = {"ExtremeHills", "ExtremeHills+", "ExtremeHillsM", "ExtremeHills+_snowtop"},
	y_min = overworld_min,
	y_max = overworld_max,
	decoration = {modname .. ":foothill_stones", modname .. ":mountain_stones"},
})

-- Mineclonia normally routes singlenode through its own levelgen. This
-- script is executed in that generator's feature environment; classic Core
-- mapgens continue to use the registrations above.
if mcl_vars.enable_mcl_levelgen then
	mcl_levelgen.register_levelgen_script(modpath .. "/lg_register.lua")
end

core.register_on_mods_loaded(install_foliage_visuals)
