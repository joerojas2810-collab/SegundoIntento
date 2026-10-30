-- SPDX-License-Identifier: GPL-3.0-or-later
-- Runs in the levelgen feature environment, after its builders are loaded.
local function set_node(x, y, z, name)
	local cid = core.get_content_id(name)
	if cid then mcl_levelgen.set_block(x, y, z, cid, 0) end
end

local function register_structure_feature(id, kind)
	mcl_levelgen.register_feature(id, {
		place = function(_, x, y, z, cfg, rng)
			local surface = y
			local height = kind == "ice_tower" and 14 or 2
			if surface < mcl_levelgen.placement_level_min + 4
				or surface + height >= mcl_levelgen.placement_level_min + mcl_levelgen.placement_level_height then return false end
			local node = mcl_levelgen.get_block(x, surface - 1, z)
			if not node then return false end
			local dirt = core.get_content_id("mcl_core:dirt")
			local grass = core.get_content_id("mcl_core:dirt_with_grass")
			local snow = core.get_content_id("mcl_core:snow")
			local snow_block = core.get_content_id("mcl_core:snowblock")
			if node ~= dirt and node ~= grass and node ~= snow and node ~= snow_block then return false end
			local stone = "mcl_core:stonebrick"
			local cobble = "mcl_core:cobble"
			local chest = "everforge:reward_cache"
			local spawner = "everforge:dungeon_spawner"
			if kind == "graveyard" then
				-- Rectangular low wall, paired graves, central crypt and guardian.
				for dx = -4, 4 do for dz = -4, 4 do
					if math.abs(dx) == 4 or math.abs(dz) == 4 then set_node(x + dx, surface, z + dz, cobble) end
				end end
				for _, offset in ipairs({{-2,-2},{2,-2},{-2,2},{2,2}}) do
					set_node(x + offset[1], surface, z + offset[2], stone)
					set_node(x + offset[1], surface + 1, z + offset[2], "mcl_core:stonebrickmossy")
				end
				set_node(x, surface, z, "mcl_core:stonebrickcracked")
				set_node(x, surface + 1, z, chest)
				set_node(x, surface, z - 1, spawner)
				set_node(x + 1, surface, z, "mcl_torches:torch_wall")
			else
				-- A tapered 15-block ice watchtower with a hollow core and loot.
				for h = 0, 13 do
					local radius = h < 3 and 4 or (h < 9 and 3 or 2)
					for dx = -radius, radius do for dz = -radius, radius do
						if math.max(math.abs(dx), math.abs(dz)) == radius then
							local material = (h % 4 == 0) and "mcl_core:packed_ice" or "mcl_core:blue_ice"
							set_node(x + dx, surface + h, z + dz, material)
						end
					end end
				end
				for h = 1, 10 do set_node(x, surface + h, z, "air") end
				set_node(x, surface + 8, z, chest)
				set_node(x, surface, z, spawner)
			end
			return true
		end,
	})
	local configured = id .. "_configured"
	local placed = id .. "_placed"
	mcl_levelgen.register_configured_feature(configured, {feature = id, structure = kind})
	mcl_levelgen.register_placed_feature(placed, {
		configured_feature = configured,
		placement_modifiers = {
			mcl_levelgen.build_count(function(rng) return rng:next_within(256) == 0 and 1 or 0 end),
			mcl_levelgen.build_in_square(),
			mcl_levelgen.build_heightmap("motion_blocking"),
			mcl_levelgen.build_in_biome(),
		},
	})
	return placed
end

local function add_overworld_feature(placed_id, step, predicate)
	for _, biome in pairs(mcl_levelgen.registered_biomes or {}) do
		if biome.groups and biome.groups.is_overworld and biome.features[step]
			and (not predicate or predicate(biome)) then
			local list = biome.features[step]
			if table.indexof(list, placed_id) == -1 then list[#list + 1] = placed_id end
		end
	end
end

local birch_ruin_schematics = {
	"everforge:birch_forest_temple_ruins_1",
	"everforge:birch_forest_temple_ruins_2",
}

local function register_birch_ruins_feature()
	local id = "everforge:birch_forest_temple_ruins"
	local ground_dirt = core.get_content_id("mcl_core:dirt")
	local ground_grass = core.get_content_id("mcl_core:dirt_with_grass")
	local get_block = mcl_levelgen.get_block
	local get_schematic_size = mcl_levelgen.get_schematic_size
	local place_schematic = mcl_levelgen.place_schematic
	local notify_generated = mcl_levelgen.notify_generated
	local random_rotation = mcl_levelgen.random_schematic_rotation

	mcl_levelgen.register_feature(id, {
		place = function(_, x, y, z, _cfg, rng)
			local schematic = birch_ruin_schematics[rng:next_within(#birch_ruin_schematics) + 1]
			local rotation = random_rotation(rng)
			local sx, sy, sz = get_schematic_size(schematic, rotation)
			local base_y = y - 1 -- The original schematics include their soil/grass base layer.
			if y < mcl_levelgen.placement_level_min + 4
				or y + sy >= mcl_levelgen.placement_level_min + mcl_levelgen.placement_level_height then
				return false
			end

			local half_x, half_z = math.floor(sx / 2), math.floor(sz / 2)
			local origin_x, origin_z = x - half_x, z - half_z
			-- Require a level grass/dirt footprint across the whole small schematic.
			for dx = -half_x, half_x do
				for dz = -half_z, half_z do
					local ground = get_block(x + dx, base_y, z + dz)
					if ground ~= ground_dirt and ground ~= ground_grass then return false end
				end
			end

			place_schematic(origin_x, base_y, origin_z, schematic, rotation, true, nil, rng)
			notify_generated("everforge:birch_forest_temple_ruins_loot", {
				x = origin_x, y = base_y, z = origin_z,
				sx = sx, sy = sy, sz = sz, loot_seed = math.abs(rng:next_integer()),
			})
			return true
		end,
	})

	local configured = id .. "_configured"
	local placed = id .. "_placed"
	mcl_levelgen.register_configured_feature(configured, {feature = id})
	mcl_levelgen.register_placed_feature(placed, {
		configured_feature = configured,
		placement_modifiers = {
			mcl_levelgen.build_count(function(rng)
				return rng:next_within(256) == 0 and 1 or 0
			end),
			-- These ruins are at most 9 x 9, so anchor them in the chunk
			-- interior to avoid clipping at the levelgen run boundary.
			function(x, y, z, rng)
				return {x + 4 + rng:next_within(8), y, z + 4 + rng:next_within(8)}
			end,
			mcl_levelgen.build_heightmap("motion_blocking"),
			mcl_levelgen.build_in_biome(),
		},
	})
	return placed
end

local function add_biome_named_feature(placed_id, step, names)
	for biome_name, biome in pairs(mcl_levelgen.registered_biomes or {}) do
		if names[biome_name] and biome.features and biome.features[step] then
			local list = biome.features[step]
			if table.indexof(list, placed_id) == -1 then list[#list + 1] = placed_id end
		end
	end
end

if mcl_vars.enable_mcl_levelgen and mcl_levelgen.register_feature then
	local graveyard_id = register_structure_feature("everforge:graveyard", "graveyard")
	local ice_tower_id = register_structure_feature("everforge:ice_tower", "ice_tower")
	local birch_ruins_id = register_birch_ruins_feature()
	add_overworld_feature(graveyard_id, 4)
	add_overworld_feature(ice_tower_id, 4, function(biome)
		return biome.temperature <= 0.15 or biome.groups.is_taiga
	end)
	add_biome_named_feature(birch_ruins_id, 4, {
		BirchForest = true,
		OldGrowthBirchForest = true,
	})
else
	core.log("warning", "[Everforge] Graveyard, Ice Tower and Birch Forest Ruins generation requires Mineclonia's singlenode levelgen. RPG, forging, minerals and difficulty remain available.")
end
