-- SPDX-License-Identifier: GPL-3.0-or-later
-- Port of Extra Structures 1.4.0 Birch Forest Temple Ruins to Mineclonia's
-- native mcl_levelgen API. Source and asset attribution: THIRD_PARTY.md.
if not mcl_vars.enable_mcl_levelgen then return end

local modpath = core.get_modpath("everforge")
local schematic_path = modpath .. "/schematics/extra_structures_1_4/"
mcl_levelgen.register_portable_schematic("everforge:birch_forest_temple_ruins_1",
	schematic_path .. "birch_forest_temple_ruins_1.mts", true)
mcl_levelgen.register_portable_schematic("everforge:birch_forest_temple_ruins_2",
	schematic_path .. "birch_forest_temple_ruins_2.mts", true)

local birch_ruins_loot = {
	{
		stacks_min = 2,
		stacks_max = 4,
		items = {
			{ itemstring = "mcl_mobitems:rotten_flesh", weight = 16, amount_min = 3, amount_max = 7 },
			{ itemstring = "mcl_core:gold_ingot", weight = 3, amount_min = 2, amount_max = 7 },
			{ itemstring = "mcl_core:iron_ingot", weight = 5, amount_min = 1, amount_max = 5 },
			{ itemstring = "mcl_core:diamond", weight = 1, amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_tools:sword_stone", weight = 15 },
			{ itemstring = "mcl_tools:pick_stone", weight = 15 },
			{ itemstring = "mcl_tools:shovel_stone", weight = 15 },
			{ itemstring = "mcl_torches:torch", weight = 15, amount_min = 3, amount_max = 7 },
		},
	},
	{
		stacks_min = 1,
		stacks_max = 1,
		items = {
			{ itemstring = "mcl_fire:flint_and_steel", weight = 1, amount_min = 1, amount_max = 1 },
		},
	},
}

mcl_levelgen.register_notification_handler("everforge:birch_forest_temple_ruins_loot",
	function(_, data)
		if not mcl_loot then return end
		local x1, y1, z1 = mcl_levelgen.level_to_minetest_position(data.x, data.y, data.z)
		local x2, y2, z2 = mcl_levelgen.level_to_minetest_position(
			data.x + data.sx - 1, data.y + data.sy - 1, data.z + data.sz - 1)
		local p1 = {x = math.min(x1, x2), y = math.min(y1, y2), z = math.min(z1, z2)}
		local p2 = {x = math.max(x1, x2), y = math.max(y1, y2), z = math.max(z1, z2)}
		core.load_area(p1, p2)
		local chests = core.find_nodes_in_area(p1, p2, "mcl_chests:chest_small") or {}
		local pr = PcgRandom(data.loot_seed)
		for _, pos in ipairs(chests) do
			local meta = core.get_meta(pos)
			if meta:get_int("everforge:birch_ruins_loot_initialized") ~= 1 then
				local node = core.get_node(pos)
				if node.name == "mcl_chests:chest_small" then
					if mcl_structures and mcl_structures.init_node_construct then
						mcl_structures.init_node_construct(pos)
					else
						local def = core.registered_nodes[node.name]
						if def and def.on_construct then def.on_construct(pos) end
					end
					local inventory = meta:get_inventory()
					local loot = mcl_loot.get_multi_loot(birch_ruins_loot, pr)
					mcl_loot.fill_inventory(inventory, "main", loot, pr)
					meta:set_int("everforge:birch_ruins_loot_initialized", 1)
				end
			end
		end
	end)

mcl_levelgen.register_levelgen_script(modpath .. "/world_features.lua")
