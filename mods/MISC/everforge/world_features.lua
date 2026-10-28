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


if mcl_vars.enable_mcl_levelgen and mcl_levelgen.register_feature then
	local graveyard_id = register_structure_feature("everforge:graveyard", "graveyard")
	local ice_tower_id = register_structure_feature("everforge:ice_tower", "ice_tower")
	add_overworld_feature(graveyard_id, 4)
	add_overworld_feature(ice_tower_id, 4, function(biome)
		return biome.temperature <= 0.15 or biome.groups.is_taiga
	end)
else
	core.log("warning", "[Everforge] Graveyard and Ice Tower generation requires Mineclonia's singlenode levelgen. RPG, forging, minerals and difficulty remain available.")
end
