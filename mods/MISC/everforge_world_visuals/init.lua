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
	floodable = true,
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
		texture = "default_stone.png",
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
		floodable = true,
		drop = "",
		groups = {not_in_creative_inventory = 1, deco_block = 1},
		is_ground_content = false,
	})
end

-- Use only Mineclonia's feature pipeline. Core decorations run at a
-- different time and cannot apply our post-tree/structure clearance filter.
-- Existing classic-mapgen worlds still load the visual node definitions;
-- they receive no new scenery. No mapgen setting or saved mapblock is edited.
if mcl_vars.enable_mcl_levelgen then
	mcl_levelgen.register_levelgen_script(modpath .. "/lg_register.lua")
end

core.register_on_mods_loaded(install_foliage_visuals)

-- Read-only diagnostic: inspect the final definitions, including later overrides.
local function visual_status(player_name)
 local leaf = core.registered_nodes["mcl_trees:leaves_oak"] or {}
 local grass = core.registered_nodes["mcl_core:dirt_with_grass"] or {}
 local function first_tile(def)
  local tile = def.tiles and def.tiles[1]
  return type(tile) == "table" and tile.name or tostring(tile)
 end
 local active = leaf.drawtype == "nodebox"
  and first_tile(leaf) == texture("leaves_oak")
  and first_tile(grass) == texture("grass_top")
 local lines = {
  active and "Everforge visual: ACTIVO" or "Everforge visual: DEFINICIONES ALTERADAS O INCOMPLETAS",
  "Roble: " .. tostring(leaf.drawtype) .. " / " .. first_tile(leaf),
  "Cesped: " .. first_tile(grass),
  "Generador: " .. tostring(core.get_mapgen_setting("mg_name"))
   .. "; mcl_levelgen=" .. tostring(mcl_vars.enable_mcl_levelgen),
 }
 local player = player_name and core.get_player_by_name(player_name)
 local pos = player and player:get_pos()
 if pos then
  local p = vector.round(pos)
  local minp, maxp = vector.offset(p,-24,-16,-24), vector.offset(p,24,16,24)
  local shrubs = core.find_nodes_in_area(minp,maxp,{modname..":forest_shrub"})
  local stones = core.find_nodes_in_area(minp,maxp,{
   modname..":field_stones",modname..":foothill_stones",modname..":mountain_stones",
  })
  lines[#lines+1] = "Cerca (24 bloques): arbustos=" .. #shrubs .. "; piedras=" .. #stones
  lines[#lines+1] = "Cero decoraciones no implica fallo: solo aparecen en terreno nuevo y biomas elegibles."
 end
 return active, table.concat(lines,"\n")
end
core.register_chatcommand("everforge_visuals", {
 description = "Diagnostico de solo lectura de la apariencia Everforge",
 func = function(name) local _,status=visual_status(name); return true,status end,
})
core.register_on_mods_loaded(function()
 -- Read after all mods-loaded callbacks, without changing any world nodes.
 core.after(0, function()
  local _,status=visual_status()
  core.log("action", "[everforge_world_visuals] " .. status:gsub("\n", "; "))
 end)
end)
