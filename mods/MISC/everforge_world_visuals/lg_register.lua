-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Sparse, surface-only details for Mineclonia's native feature generator.
-- This file runs inside mcl_levelgen's feature environment.
local modname = "everforge_world_visuals"
local lg = mcl_levelgen

local shrub_biomes = {
	"Forest", "DarkForest", "BirchForest", "OldGrowthBirchForest",
	"Taiga", "OldGrowthSpruceTaiga", "OldGrowthPineTaiga", "Meadow",
	"FlowerForest", "CherryGrove", "WindsweptForest",
}
local field_biomes = {
	"Forest", "DarkForest", "BirchForest", "OldGrowthBirchForest",
	"Taiga", "OldGrowthSpruceTaiga", "OldGrowthPineTaiga", "Meadow",
	"FlowerForest", "CherryGrove",
}
local mountain_biomes = {
	"StonyPeaks", "StonyShore", "WindsweptHills",
	"WindsweptGravellyHills", "WindsweptForest",
}

-- Exact natural-terrain node lists avoid relying on registered_nodes in
-- Luanti's restricted mapgen environment and exclude generated structures.
local function content_id_set(node_names)
	local ids = {}
	for _, node_name in ipairs(node_names) do
		ids[core.get_content_id(node_name)] = true
	end
	return ids
end

local shrub_ground_ids = content_id_set({
	"mcl_core:dirt_with_grass", "mcl_core:podzol",
})
local stone_ground_ids = content_id_set({
	"mcl_core:stone", "mcl_core:andesite", "mcl_core:granite", "mcl_core:diorite",
	"mcl_core:dirt", "mcl_core:coarse_dirt", "mcl_core:podzol", "mcl_core:mycelium",
	"mcl_core:gravel", "mcl_core:sand",
})

local function surface_support_filter(support_ids)
	return function (x, y, z)
		local cid = lg.get_block(x, y - 1, z)
		if support_ids[cid] then return {x, y, z} end
		return nil
	end
end

local function biomes_with_surface_feature(names)
	local result = {}
	for _, biome_name in ipairs(names) do
		local biome = lg.registered_biomes[biome_name]
		local surface_features = biome and biome.features and biome.features[12]
		if surface_features and table.indexof(surface_features, "mcl_levelgen:freeze_top_layer") ~= -1 then
			result[#result + 1] = biome_name
		end
	end
	return result
end

local function register_block(name, node_names, biomes, support_ids, count, rarity)
	local configured_id = modname .. ":" .. name .. "_configured"
	local placed_id = modname .. ":" .. name .. "_placed"
	local content_ids = {}
	for _, node_name in ipairs(node_names) do
		content_ids[#content_ids + 1] = core.get_content_id(node_name)
	end

	lg.register_configured_feature(configured_id, {
		feature = "mcl_levelgen:simple_block",
		content = function (_, _, _, rng)
			local index = rng:next_within(#content_ids) + 1
			return content_ids[index], 0
		end,
	})
	lg.register_placed_feature(placed_id, {
		configured_feature = configured_id,
		placement_modifiers = {
			lg.build_rarity_filter(rarity),
			lg.build_count(function () return count end),
			lg.build_in_square(),
			lg.build_heightmap("motion_blocking_wg"),
			surface_support_filter(support_ids),
			lg.build_in_biome(),
		},
	})
	lg.generate_feature(placed_id, "mcl_levelgen:freeze_top_layer", biomes, 12)
end

register_block("forest_shrub", {modname .. ":forest_shrub"}, biomes_with_surface_feature(shrub_biomes), shrub_ground_ids, 2, 4)
register_block("field_stones", {modname .. ":field_stones"}, biomes_with_surface_feature(field_biomes), stone_ground_ids, 2, 4)
register_block("mountain_stones", {
	modname .. ":foothill_stones", modname .. ":mountain_stones",
}, biomes_with_surface_feature(mountain_biomes), stone_ground_ids, 2, 3)
