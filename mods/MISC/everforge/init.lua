-- SPDX-License-Identifier: GPL-3.0-or-later
local modname = core.get_current_modname()
local S = core.get_translator(modname)
local FORM = "everforge:rpg"
local random = PcgRandom(249955)

everforge = { version = "1.0.0", classes = {}, skills = {} }

-- Class and skill definitions are deliberately small stat modifiers. Physics
-- changes go through playerphysics so they compose with Mineclonia and other mods.
everforge.classes = {
	vanguard = {label = S("Vanguard"), description = S("Takes 10% less mob and player melee damage."), speed = 0.98, jump = 1.02, gravity = 1.0},
	ranger = {label = S("Ranger"), description = S("Mobile explorer and ranged specialist."), speed = 1.08, jump = 1.08, gravity = 1.0},
	arcanist = {label = S("Arcanist"), description = S("A scholar of ancient dungeons."), speed = 1.0, jump = 1.0, gravity = 0.96},
	smith = {label = S("Smith"), description = S("A specialist in alloys and crafted gear."), speed = 1.0, jump = 1.0, gravity = 1.0},
}

mcl_damage.register_modifier(function(object, damage, reason)
	if object and object:is_player() and damage > 0 then
		local class = object:get_meta():get_string("everforge:class")
		local dtype = reason and reason.type
		if class == "vanguard" and (dtype == "mob" or dtype == "player") then
			return damage * 0.9
		end
	end
end, 0)

everforge.skills = {
	trailblazer = {label = S("Trailblazer"), description = S("Run faster."), attribute = "speed", factor = 1.04, max = 3},
	deep_miner = {label = S("Deep Miner"), description = S("Reduces wear on Everforge tools."), max = 3},
	dungeoneer = {label = S("Dungeoneer"), description = S("Gain a small XP bonus near dungeon guardians."), max = 3},
	forgemaster = {label = S("Forgemaster"), description = S("Smelt alloys faster at Everforge melters."), max = 3},
}

local function get_meta(player)
	return player:get_meta()
end

local function earned_points(player)
	local m = get_meta(player)
	local earned = math.floor((mcl_experience.get_level(player) or 0) / 5)
	local saved = m:get_int("everforge:earned")
	if earned > saved then
		saved = earned
		m:set_int("everforge:earned", saved)
	end
	return math.max(earned, saved)
end

local function get_points(player)
	return math.max(0, earned_points(player) - get_meta(player):get_int("everforge:spent"))
end

local function apply_class(player)
	local m = get_meta(player)
	local class = everforge.classes[m:get_string("everforge:class")]
	for _, attr in ipairs({"speed", "jump", "gravity"}) do
		playerphysics.remove_physics_factor(player, attr, "everforge:class")
		playerphysics.remove_physics_factor(player, attr, "everforge:skill")
	end
	if class then
		for attr, value in pairs({speed = class.speed, jump = class.jump, gravity = class.gravity}) do
			if value ~= 1 then playerphysics.add_physics_factor(player, attr, "everforge:class", value) end
		end
	end
	local rank = m:get_int("everforge:skill:trailblazer")
	if rank > 0 then playerphysics.add_physics_factor(player, "speed", "everforge:skill", 1 + 0.04 * rank) end
end

local function skill_rank(player, key)
	return get_meta(player):get_int("everforge:skill:" .. key)
end

mcl_experience.register_on_add_xp(function(player, xp)
	if not player or not player:is_player() or xp <= 0 then return xp end
	local rank = skill_rank(player, "dungeoneer")
	local class_bonus = get_meta(player):get_string("everforge:class") == "arcanist" and 1 or 0
	if rank + class_bonus == 0 then return xp end
	local pos = player:get_pos()
	local minp = {x = pos.x - 18, y = pos.y - 18, z = pos.z - 18}
	local maxp = {x = pos.x + 18, y = pos.y + 18, z = pos.z + 18}
	local nearby = core.find_nodes_in_area(minp, maxp, {"everforge:dungeon_spawner"})
	if #nearby > 0 then return math.floor(xp * (1 + 0.05 * (rank + class_bonus))) end
	return xp
end)

local function show_rpg(player)
	local m = get_meta(player)
	local class_key = m:get_string("everforge:class")
	local class = everforge.classes[class_key]
	local class_name = class and class.label or S("Unassigned")
	local lv = mcl_experience.get_level(player) or 0
	local fs = {"formspec_version[7]size[9,8]", "label[0.5,0.45;Everforge RPG]",
		"label[0.5,0.95;Class: ", core.formspec_escape(class_name), "    Level: ", tostring(lv),
		"    Skill points: ", tostring(get_points(player)), "]",
		"label[0.5,1.55;Choose your class (selection is permanent):]"}
	local buttons = {{"vanguard", "Vanguard"}, {"ranger", "Ranger"}, {"arcanist", "Arcanist"}, {"smith", "Smith"}}
	for i, b in ipairs(buttons) do
		local x = 0.5 + ((i - 1) % 2) * 4.1
		local y = 1.9 + math.floor((i - 1) / 2) * 0.65
		fs[#fs + 1] = ("button[%s,%s;3.8,0.55;class_%s;%s]"):format(x, y, b[1], b[2])
		fs[#fs + 1] = ("tooltip[class_%s;%s]"):format(b[1], core.formspec_escape(everforge.classes[b[1]].description))
	end
	fs[#fs + 1] = "label[0.5,3.35;Skills: each rank costs one point (earned every 5 XP levels).]"
	local skills = {"trailblazer", "deep_miner", "dungeoneer", "forgemaster"}
	for i, key in ipairs(skills) do
		local skill = everforge.skills[key]
		local rank = skill_rank(player, key)
		local y = 3.7 + (i - 1) * 0.65
		fs[#fs + 1] = ("label[0.55,%s;%s %s/%s — %s]"):format(y, skill.label, rank, skill.max, skill.description)
		fs[#fs + 1] = ("button[7.1,%s;1.35,0.5;skill_%s;Learn]"):format(y - 0.1, key)
	end
	fs[#fs + 1] = "button_exit[7.0,7.25;1.5,0.55;close;Close]"
	core.show_formspec(player:get_player_name(), FORM, table.concat(fs))
end

core.register_chatcommand("everforge", {
	params = "",
	description = S("Open Everforge class and skill progression."),
	func = function(name)
		local player = core.get_player_by_name(name)
		if player then show_rpg(player); return true end
		return false, S("You must be online to use this command.")
	end,
})

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then return false end
	local m = get_meta(player)
	for key in pairs(everforge.classes) do
		if fields["class_" .. key] then
			local current = m:get_string("everforge:class")
			if current == "" then
				m:set_string("everforge:class", key)
				apply_class(player)
			else
				core.chat_send_player(player:get_player_name(), S("Your class is already set; it cannot be changed."))
			end
		end
	end
	for key, skill in pairs(everforge.skills) do
		if fields["skill_" .. key] then
			local rank = skill_rank(player, key)
			if get_points(player) > 0 and rank < skill.max then
				m:set_int("everforge:spent", m:get_int("everforge:spent") + 1)
				m:set_int("everforge:skill:" .. key, rank + 1)
				apply_class(player)
			elseif rank >= skill.max then
				core.chat_send_player(player:get_player_name(), S("That skill is already at its maximum rank."))
			else
				core.chat_send_player(player:get_player_name(), S("You need another skill point. Earn XP and level up."))
			end
		end
	end
	if not fields.quit then show_rpg(player) end
	return true
end)

core.register_on_joinplayer(function(player)
	core.after(1, function()
		if player and player:is_player() then apply_class(player) end
	end)
end)

-- Mineclonia diggroups are authoritative for block mining. The optional perk
-- augments only Everforge-forged tools, retaining each tool's registered caps.
local perk_wear_multiplier = function(player)
	return math.max(0.7, 1 - 0.04 * skill_rank(player, "deep_miner"))
end

-- ---------------------------------------------------------------------------
-- Advanced forge: smelting, components, and modular tools using native tools.
-- ---------------------------------------------------------------------------
local smelt_recipes = {
	["moreores:tin_lump"] = {output = "moreores:tin_ingot", time = 7},
	["moreores:silver_lump"] = {output = "moreores:silver_ingot", time = 9},
	["moreores:mithril_lump"] = {output = "moreores:mithril_ingot", time = 15},
	["adamantine:lump"] = {output = "adamantine:ingot", time = 20},
	["mcl_raw_ores:raw_iron"] = {output = "mcl_core:iron_ingot", time = 9},
	["mcl_raw_ores:raw_gold"] = {output = "mcl_core:gold_ingot", time = 9},
}

local forge_formspec = "formspec_version[7]size[9,8]label[0.5,0.4;Everforge Alloy Melter]" ..
	"list[context;input;1,1;1,1;]list[context;fuel;1,3;1,1;]" ..
	"list[context;output;6.5,2;2,1;]" ..
	"label[0.45,0.8;Ore / metal]label[0.45,2.8;Fuel]label[6.3,1.65;Alloy output]" ..
	"list[current_player;main;0.5,4.1;8,4;]listring[context;input]listring[current_player;main]"

core.register_craftitem("everforge:tool_head", {description = S("Forged Tool Head"), inventory_image = "default_steel_ingot.png^[colorize:#b36a3c:100", stack_max = 99})
core.register_craftitem("everforge:tool_binding", {description = S("Forged Tool Binding"), inventory_image = "default_steel_ingot.png^[colorize:#6d7381:100", stack_max = 99})
core.register_craftitem("everforge:reinforced_handle", {description = S("Reinforced Handle"), inventory_image = "default_stick.png^[colorize:#6b4029:80", stack_max = 99})

core.register_node("everforge:alloy_melter", {
	description = S("Alloy Melter"),
	tiles = {"default_stone.png^default_steel_ingot.png", "default_stone.png", "default_stone.png", "default_stone.png", "default_stone.png", "default_stone.png"},
	groups = {pickaxey = 1, material_stone = 1, level = 2},
	_mcl_hardness = 3.5,
	_mcl_blast_resistance = 3.5,
	is_ground_content = false,
	paramtype2 = "facedir",
	on_construct = function(pos)
		local meta = core.get_meta(pos)
		meta:set_string("formspec", forge_formspec)
		local inv = meta:get_inventory()
		inv:set_size("input", 1); inv:set_size("fuel", 1); inv:set_size("output", 8)
		meta:set_int("burn", 0); meta:set_int("progress", 0)
		core.get_node_timer(pos):start(1)
	end,
	can_dig = function(pos, player)
		local inv = core.get_meta(pos):get_inventory()
		return player and inv:is_empty("input") and inv:is_empty("fuel") and inv:is_empty("output")
	end,
	allow_metadata_inventory_put = function(pos, listname, _index, stack)
		if listname == "output" then return 0 end
		if listname == "input" then return smelt_recipes[stack:get_name()] and stack:get_count() or 0 end
		if listname == "fuel" then
			local test = ItemStack(stack)
			test:set_count(1)
			local fuel, afterfuel = core.get_craft_result({method = "fuel", width = 1, items = {test}})
			if not fuel or fuel.time <= 0 then return 0 end
			local replacement = afterfuel and afterfuel.items and afterfuel.items[1]
			if replacement and not replacement:is_empty() then
				local inv = core.get_meta(pos):get_inventory()
				return inv:get_stack("fuel", _index):is_empty() and 1 or 0
			end
			return stack:get_count()
		end
		return 0
	end,
	on_metadata_inventory_put = function(pos)
		core.get_node_timer(pos):start(1)
	end,
	on_metadata_inventory_take = function(pos)
		core.get_node_timer(pos):start(1)
	end,
	on_timer = function(pos)
		local meta, inv = core.get_meta(pos), core.get_meta(pos):get_inventory()
		local input = inv:get_stack("input", 1)
		local recipe = smelt_recipes[input:get_name()]
		if not recipe then meta:set_int("progress", 0); return false end
		local out = ItemStack(recipe.output)
		if not inv:room_for_item("output", out) then return false end
		if meta:get_int("burn") <= 0 then
			local fuel = inv:get_stack("fuel", 1)
			local fuel_def, afterfuel = core.get_craft_result({method = "fuel", width = 1, items = {fuel}})
			if not fuel_def or fuel_def.time <= 0 then return false end
			meta:set_int("burn", math.max(1, math.floor(fuel_def.time)))
			inv:set_stack("fuel", 1, afterfuel.items[1])
		end
		meta:set_int("burn", meta:get_int("burn") - 1)
		local effective_time = recipe.time
		for _, player in ipairs(core.get_connected_players()) do
			if vector.distance(player:get_pos(), pos) <= 8 then
				local player_meta = player:get_meta()
				if player_meta:get_string("everforge:class") == "smith" then effective_time = effective_time - 2 end
				effective_time = effective_time - skill_rank(player, "forgemaster")
			end
		end
		effective_time = math.max(3, effective_time)
		local progress = meta:get_int("progress") + 1
		if progress >= effective_time then
			input:take_item(1); inv:set_stack("input", 1, input)
			inv:add_item("output", out); progress = 0
		end
		meta:set_int("progress", progress)
		return true
	end,
})

-- Components can be assembled into four separate MCL-diggroup tools. Their
-- mining caps are Mineclonia-native; no generic `groupcaps` are rewritten.
local function forged_tool(name, desc, image, diggroup, speed, level, uses, fleshy)
	core.register_tool("everforge:" .. name, {
		description = desc, inventory_image = image, wield_scale = mcl_vars.tool_wield_scale,
		groups = {tool = 1, [diggroup == "swordy" and "sword" or diggroup == "pickaxey" and "pickaxe" or diggroup == "axey" and "axe" or "shovel"] = 1, dig_speed_class = 4, enchantability = 8},
		_mcl_toollike_wield = true,
		_mcl_diggroups = {[diggroup] = {speed = speed, level = level, uses = uses}},
		tool_capabilities = {full_punch_interval = 0.9, max_drop_level = level, damage_groups = {fleshy = fleshy}},
		sound = {breaks = "default_tool_breaks"},
		after_use = function(stack, user, node, digparams)
			if user and user:is_player() and digparams and digparams.wear and digparams.wear > 0 then
				if not core.is_creative_enabled(user:get_player_name()) then
					stack:add_wear(math.floor(digparams.wear * perk_wear_multiplier(user)))
				end
				return stack
			end
			return stack
		end,
	})
end
forged_tool("alloy_pick", S("Alloy Modular Pickaxe"), "default_tool_steelpick.png^[colorize:#ba7443:100", "pickaxey", 8, 4, 600, 5)
forged_tool("alloy_axe", S("Alloy Modular Axe"), "default_tool_steelaxe.png^[colorize:#ba7443:100", "axey", 8, 4, 600, 6)
forged_tool("alloy_shovel", S("Alloy Modular Shovel"), "default_tool_steelshovel.png^[colorize:#ba7443:100", "shovely", 8, 4, 600, 5)
forged_tool("alloy_sword", S("Alloy Modular Sword"), "default_tool_steelsword.png^[colorize:#ba7443:100", "swordy", 8, 4, 600, 8)

core.register_craft({output = "everforge:alloy_melter", recipe = {{"mcl_core:iron_ingot", "mcl_core:iron_ingot", "mcl_core:iron_ingot"}, {"mcl_core:iron_ingot", "mcl_furnaces:furnace", "mcl_core:iron_ingot"}, {"mcl_core:stone", "mcl_core:stone", "mcl_core:stone"}}})
core.register_craft({output = "everforge:tool_head 2", recipe = {{"mcl_core:iron_ingot", "mcl_core:iron_ingot"}, {"mcl_core:iron_ingot", ""}}})
core.register_craft({output = "everforge:tool_binding 2", recipe = {{"mcl_core:iron_ingot", "mcl_core:iron_ingot", "mcl_core:iron_ingot"}}})
core.register_craft({output = "everforge:reinforced_handle 2", recipe = {{"mcl_core:stick"}, {"mcl_core:iron_ingot"}}})
local function craft_modular(output, rows)
	core.register_craft({output = output, recipe = rows})
end
craft_modular("everforge:alloy_pick", {{"everforge:tool_head", "everforge:tool_head", "everforge:tool_head"}, {"", "everforge:reinforced_handle", ""}, {"", "everforge:reinforced_handle", ""}})
craft_modular("everforge:alloy_axe", {{"everforge:tool_head", "everforge:tool_head"}, {"everforge:tool_head", "everforge:reinforced_handle"}, {"", "everforge:reinforced_handle"}})
craft_modular("everforge:alloy_shovel", {{"everforge:tool_head"}, {"everforge:reinforced_handle"}, {"everforge:reinforced_handle"}})
craft_modular("everforge:alloy_sword", {{"everforge:tool_head"}, {"everforge:tool_head"}, {"everforge:reinforced_handle"}})

-- ---------------------------------------------------------------------------
-- Persistent dungeon markers, procedural structures, loot and enemy spawns.
-- The generator uses mcl_levelgen's feature API, not legacy register_ore.
-- ---------------------------------------------------------------------------
local function set_node(x, y, z, name)
	local cid = core.get_content_id(name)
	if cid then mcl_levelgen.set_block(x, y, z, cid, 0) end
end

local function register_structure_feature(id, kind)
	mcl_levelgen.register_feature(id, {
		place = function(x, y, z, cfg, rng)
			local surface = y
			local height = kind == "ice_tower" and 14 or 2
			if surface < mcl_levelgen.level_min + 4
				or surface + height >= mcl_levelgen.level_min + mcl_levelgen.level_height then return false end
			local node = mcl_levelgen.get_block(x, surface - 1, z)
			if not node then return false end
			local dirt = core.get_content_id("mcl_core:dirt")
			local grass = core.get_content_id("mcl_core:dirt_with_grass")
			if node ~= dirt and node ~= grass and node ~= core.get_content_id("mcl_core:snow") then return false end
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

core.register_craftitem("everforge:relic", {description = S("Dungeon Relic"), inventory_image = "default_gold_ingot.png^[colorize:#6d45ba:110", stack_max = 16})
core.register_node("everforge:reward_cache", {
	description = S("Sealed Dungeon Cache"), tiles = {"mcl_chests_normal.png^default_gold_ingot.png"},
	groups = {choppy = 2, material_wood = 1}, is_ground_content = false, paramtype2 = "facedir",
	_on_ignite = false,
})
core.register_node("everforge:dungeon_spawner", {
	description = S("Ancient Dungeon Spawner"), tiles = {"default_stone_brick.png^[colorize:#332849:120"},
	groups = {cracky = 2, not_in_creative_inventory = 1}, is_ground_content = false, drop = "", walkable = false,
})

local spawner_lbm = "everforge:activate_dungeon_spawners"
core.register_lbm({
	label = "Activate Everforge dungeon spawners", name = spawner_lbm,
	nodenames = {"everforge:dungeon_spawner"}, run_at_every_load = true,
	action = function(pos)
		local meta = core.get_meta(pos)
		if meta:get_int("everforge:initialized") == 0 then
			meta:set_int("everforge:initialized", 1)
			meta:set_int("everforge:spawned", 0)
		end
	end,
})

core.register_lbm({
	label = "Initialize Everforge dungeon caches", name = "everforge:initialize_dungeon_caches",
	nodenames = {"everforge:reward_cache"}, run_at_every_load = true,
	action = function(pos)
		local meta = core.get_meta(pos)
		if meta:get_int("everforge:initialized") == 1 then return end
		local inv = meta:get_inventory(); inv:set_size("main", 16)
		inv:add_item("main", ItemStack("everforge:relic 1"))
		if core.registered_items["moreores:mithril_ingot"] then inv:add_item("main", ItemStack("moreores:mithril_ingot 2")) end
		if core.registered_items["adamantine:ingot"] then inv:add_item("main", ItemStack("adamantine:ingot")) end
		inv:add_item("main", ItemStack("mcl_core:gold_ingot 3"))
		meta:set_string("formspec", "formspec_version[7]size[8,7]label[0.5,0.4;Dungeon Reward Cache]list[context;main;1,1;4,4;]list[current_player;main;0,4.7;8,3;]listring[context;main]listring[current_player;main]")
		meta:set_int("everforge:initialized", 1)
	end,
})

local mob_names = {"mobs_mc:skeleton", "mobs_mc:stray", "mobs_mc:zombie"}
core.register_globalstep(function(dtime)
	-- Scaling is applied per mob in a small radius around players. Values are
	-- bounded and based on depth, preventing global difficulty overrides.
	local now = core.get_us_time() / 1000000
	if now - (everforge._last_scale or 0) < 4 then return end
	everforge._last_scale = now
	for _, player in ipairs(core.get_connected_players()) do
		earned_points(player)
		local ppos = player:get_pos()
		for _, obj in ipairs(core.get_objects_inside_radius(ppos, 34)) do
			local ent = obj:get_luaentity()
			local pos = obj:get_pos()
			if ent and pos and ent.name and ent.name:match("^mobs_mc:") and ent.type == "monster" and not ent.everforge_scaled then
				local depth = math.max(0, -pos.y - 32)
				local zone = math.floor(depth / 48)
				local in_dungeon = ent.everforge_dungeon == true
				local factor = math.min(2.2, 1 + zone * 0.12)
				if in_dungeon then factor = math.min(2.5, factor + 0.35) end
				local hp = ent.hp_max or 20
				ent.hp_max = math.floor(hp * factor)
				obj:set_properties({hp_max = ent.hp_max})
				obj:set_hp(ent.hp_max)
				if type(ent.damage) == "number" then ent.damage = math.ceil(ent.damage * (1 + zone * 0.08 + (in_dungeon and 0.2 or 0))) end
				ent.everforge_scaled = true
			end
		end
	end
end)

core.register_abm({
	label = "Everforge dungeon spawn pulse", nodenames = {"everforge:dungeon_spawner"},
	interval = 18, chance = 1, catch_up = false,
	action = function(pos, node)
		local meta = core.get_meta(pos)
		if meta:get_int("everforge:spawned") >= 3 then return end
		local players = core.get_connected_players()
		local active = false
		for _, player in ipairs(players) do if vector.distance(player:get_pos(), pos) < 28 then active = true; break end end
		if not active then return end
		local count = 0
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 18)) do
			local ent = obj:get_luaentity(); if ent and ent.type == "monster" then count = count + 1 end
		end
		if count >= 4 then return end
		local name = mob_names[1 + (meta:get_int("everforge:spawned") % #mob_names)]
		if core.registered_entities[name] then
			local spawn = {x = pos.x + random:next_within(5) - 2, y = pos.y + 1, z = pos.z + random:next_within(5) - 2}
			local head = {x = spawn.x, y = spawn.y + 1, z = spawn.z}
			if core.get_node(spawn).name == "air" and core.get_node(head).name == "air" then
				local object = core.add_entity(spawn, name)
				local spawned = object and object:get_luaentity()
				if spawned then spawned.everforge_dungeon = true end
				meta:set_int("everforge:spawned", meta:get_int("everforge:spawned") + 1)
			end
		end
	end,
})

-- Register native levelgen features for mineral deposits and both dungeon types.
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
