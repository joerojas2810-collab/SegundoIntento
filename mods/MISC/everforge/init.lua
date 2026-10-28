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

local forge_formspec = table.concat({
	"formspec_version[4]",
	"size[11.75,10.425]",
	"label[0.375,0.375;" .. core.formspec_escape(S("Everforge Alloy Melter")) .. "]",
	"label[0.375,0.85;" .. core.formspec_escape(S("Accepts: Tin, silver, mithril or adamantine lumps.")) .. "]",
	"label[0.375,1.2;" .. core.formspec_escape(S("Also raw iron and raw gold; ingots are not accepted.")) .. "]",
	"label[3.5,1.45;" .. core.formspec_escape(S("Input")) .. "]",
	mcl_formspec.get_itemslot_bg_v4(3.5, 1.8, 1, 1),
	"list[context;input;3.5,1.8;1,1;]",
	"image[3.5,2.8;1,1;default_furnace_fire_bg.png]",
	"label[3.5,3.55;" .. core.formspec_escape(S("Fuel")) .. "]",
	mcl_formspec.get_itemslot_bg_v4(3.5, 3.85, 1, 1),
	"list[context;fuel;3.5,3.85;1,1;]",
	"image[5.0,2.8;1.5,1;gui_furnace_arrow_bg.png^[transformR270]",
	"label[6.5,1.45;" .. core.formspec_escape(S("Products")) .. "]",
	mcl_formspec.get_itemslot_bg_v4(6.5, 1.8, 4, 2),
	"list[context;output;6.5,1.8;4,2;]",
	"label[0.375,4.7;" .. core.formspec_escape(S("Inventory")) .. "]",
	mcl_formspec.get_itemslot_bg_v4(0.375, 5.1, 9, 3),
	"list[current_player;main;0.375,5.1;9,3;9]",
	mcl_formspec.get_itemslot_bg_v4(0.375, 9.05, 9, 1),
	"list[current_player;main;0.375,9.05;9,1;]",
	"listring[context;output]listring[current_player;main]",
	"listring[context;input]listring[current_player;main]",
	"listring[context;fuel]listring[current_player;main]",
})

core.register_craftitem("everforge:tool_head", {description = S("Forged Tool Head"), inventory_image = "default_steel_ingot.png^[colorize:#b36a3c:100", stack_max = 99})
core.register_craftitem("everforge:tool_binding", {description = S("Forged Tool Binding"), inventory_image = "default_steel_ingot.png^[colorize:#6d7381:100", stack_max = 99})
core.register_craftitem("everforge:reinforced_handle", {description = S("Reinforced Handle"), inventory_image = "default_stick.png^[colorize:#6b4029:80", stack_max = 99})

local melter_lists = {input = true, fuel = true, output = true}

local function melter_inventory(pos)
	return core.get_meta(pos):get_inventory()
end

local function ensure_melter(pos)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	inv:set_size("input", 1)
	inv:set_size("fuel", 1)
	inv:set_size("output", 8)
	meta:set_string("formspec", forge_formspec)
	if meta:get_int("burn") < 0 then meta:set_int("burn", 0) end
	if meta:get_int("progress") < 0 then meta:set_int("progress", 0) end
end

local function melter_is_protected(pos, player)
	if player and player:is_player() and core.is_protected(pos, player:get_player_name()) then
		core.record_protection_violation(pos, player:get_player_name())
		return true
	end
	return false
end

local function sync_melter_input(pos)
	local meta = core.get_meta(pos)
	local input = melter_inventory(pos):get_stack("input", 1)
	local name = input:is_empty() and "" or input:get_name()
	if meta:get_string("active_input") ~= name then
		meta:set_string("active_input", name)
		meta:set_int("progress", 0)
	end
end

local function melter_allow_put(pos, listname, index, stack, player, requested_count)
	if melter_is_protected(pos, player) then return 0 end
	local inv = melter_inventory(pos)
	if not melter_lists[listname] or index < 1 or index > inv:get_size(listname) then return 0 end
	local count = math.min(requested_count or stack:get_count(), stack:get_count())
	if count <= 0 then return 0 end

	if listname == "output" then return 0 end
	if listname == "input" then
		return smelt_recipes[stack:get_name()] and count or 0
	end
	if listname == "fuel" then
		local test = ItemStack(stack)
		test:set_count(1)
		local fuel, afterfuel = core.get_craft_result({method = "fuel", width = 1, items = {test}})
		if not fuel or not fuel.time or fuel.time <= 0 then return 0 end
		local replacement = afterfuel and afterfuel.items and afterfuel.items[1]
		if replacement and not replacement:is_empty() then
			return inv:get_stack("fuel", index):is_empty() and math.min(1, count) or 0
		end
		return count
	end
	return 0
end

local function melter_allow_take(pos, listname, index, stack, player, requested_count)
	if melter_is_protected(pos, player) then return 0 end
	local inv = melter_inventory(pos)
	if not melter_lists[listname] or index < 1 or index > inv:get_size(listname) then return 0 end
	return math.min(requested_count or stack:get_count(), stack:get_count())
end

local function melter_allow_move(pos, from_list, from_index, to_list, to_index, count, player)
	if melter_is_protected(pos, player) then return 0 end
	local inv = melter_inventory(pos)
	local source_inv
	if melter_lists[from_list] then
		source_inv = inv
	elseif player and player.get_inventory then
		source_inv = player:get_inventory()
	end
	if not source_inv or from_index < 1 or from_index > source_inv:get_size(from_list) then return 0 end
	local stack = source_inv:get_stack(from_list, from_index)
	local move_count = math.min(count or stack:get_count(), stack:get_count())
	if stack:is_empty() or move_count <= 0 then return 0 end

	if melter_lists[to_list] then
		local moving = ItemStack(stack)
		moving:set_count(move_count)
		return melter_allow_put(pos, to_list, to_index, moving, player, move_count)
	elseif melter_lists[from_list] then
		return melter_allow_take(pos, from_list, from_index, stack, player, move_count)
	end
	return 0
end

local function restart_melter(pos)
	sync_melter_input(pos)
	core.get_node_timer(pos):start(1)
end

local function melter_hopper_in(hopper_pos, melter_pos)
	if not mcl_util or not mcl_util.get_eligible_transfer_item_slot or not mcl_util.move_item then return false end
	local source = core.get_inventory({type = "node", pos = hopper_pos})
	local destination = core.get_inventory({type = "node", pos = melter_pos})
	if not source or not destination then return false end
	local target_list = hopper_pos.y == melter_pos.y and "fuel" or "input"
	local slot = mcl_util.get_eligible_transfer_item_slot(source, "main", destination, target_list,
		function(stack)
			local one = ItemStack(stack)
			one:set_count(1)
			return melter_allow_put(melter_pos, target_list, 1, one, nil, 1) > 0
				and destination:room_for_item(target_list, one)
		end)
	if not slot then return false end
	local moved = mcl_util.move_item(source, "main", slot, destination, target_list)
	if moved then restart_melter(melter_pos) end
	return moved
end

local function melter_hopper_out(melter_pos, hopper_pos)
	if not mcl_util or not mcl_util.move_item_container then return false end
	local moved = mcl_util.move_item_container(melter_pos, hopper_pos, "output")
	if moved then restart_melter(melter_pos) end
	return moved
end

core.register_node("everforge:alloy_melter", {
	description = S("Alloy Melter"),
	tiles = {"default_stone.png^default_steel_ingot.png", "default_stone.png", "default_stone.png", "default_stone.png", "default_stone.png", "default_stone.png"},
	groups = {pickaxey = 1, material_stone = 1, level = 2, container = 4},
	_mcl_hardness = 3.5,
	_mcl_blast_resistance = 3.5,
	is_ground_content = false,
	paramtype2 = "facedir",
	on_construct = function(pos)
		local meta = core.get_meta(pos)
		ensure_melter(pos)
		meta:set_int("burn", 0)
		meta:set_int("progress", 0)
		meta:set_string("active_input", "")
		core.get_node_timer(pos):start(1)
	end,
	can_dig = function(pos, player)
		local inv = melter_inventory(pos)
		return player and inv:is_empty("input") and inv:is_empty("fuel") and inv:is_empty("output")
	end,
	allow_metadata_inventory_put = melter_allow_put,
	allow_metadata_inventory_take = melter_allow_take,
	allow_metadata_inventory_move = melter_allow_move,
	_on_hopper_in = melter_hopper_in,
	_on_hopper_out = melter_hopper_out,
	on_metadata_inventory_put = restart_melter,
	on_metadata_inventory_take = restart_melter,
	on_metadata_inventory_move = restart_melter,
	on_timer = function(pos)
		local meta = core.get_meta(pos)
		local inv = meta:get_inventory()
		local input = inv:get_stack("input", 1)
		local recipe = smelt_recipes[input:get_name()]
		sync_melter_input(pos)
		if not recipe then meta:set_int("progress", 0); return false end

		local out = ItemStack(recipe.output)
		if not inv:room_for_item("output", out) then return false end
		if meta:get_int("burn") <= 0 then
			local fuel_stack = inv:get_stack("fuel", 1)
			local fuel, afterfuel = core.get_craft_result({method = "fuel", width = 1, items = {fuel_stack}})
			if not fuel or not fuel.time or fuel.time <= 0 then return false end
			meta:set_int("burn", math.max(1, math.floor(fuel.time)))
			local remaining_fuel = afterfuel and afterfuel.items and afterfuel.items[1] or ItemStack("")
			inv:set_stack("fuel", 1, remaining_fuel)
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
			-- Add the output before consuming the ingredient, and verify the
			-- inventory accepted it. This keeps a full output slot lossless.
			local leftover = inv:add_item("output", out)
			if not leftover:is_empty() then return false end
			input:take_item(1)
			inv:set_stack("input", 1, input)
			progress = 0
		end
		meta:set_int("progress", progress)
		return true
	end,
})

-- Refresh already-placed melters after updates, without clearing their saved
-- inventories or smelting state. This also repairs old list sizes/formspecs.
core.register_lbm({
	label = "Update Everforge alloy melter inventory and interface",
	name = "everforge:update_alloy_melter_interface",
	nodenames = {"everforge:alloy_melter"},
	run_at_every_load = true,
	action = function(pos)
		ensure_melter(pos)
		core.get_node_timer(pos):start(1)
	end,
})

-- Modular forging uses existing Mineclonia/More Ores/Adamantine ingots. The
-- metal rarity is material data; manufacturing quality is selected separately
-- with a tempering catalyst when the components are assembled.
local forge_materials = {
	tin = {
		item = "moreores:tin_ingot", label = S("Tin"), rarity = "common", color = "#a9a9a1",
		level = 2, speed = 4, uses = 120, damage = 0.1, dig_speed_class = 2, enchantability = 8,
		binding_durability = 0.80, binding_speed = 0.96, binding_damage = 0.05, binding_attack = 0.96,
		handle_durability = 0.82, handle_speed = 0.96, handle_damage = 0.05, handle_attack = 0.94,
	},
	copper = {
		item = "mcl_copper:copper_ingot", label = S("Copper"), rarity = "common", color = "#c77b4a",
		level = 3, speed = 5, uses = 191, damage = 0.25, dig_speed_class = 3, enchantability = 13,
		binding_durability = 0.95, binding_speed = 1.00, binding_damage = 0.10, binding_attack = 1.00,
		handle_durability = 0.95, handle_speed = 0.99, handle_damage = 0.10, handle_attack = 0.99,
	},
	iron = {
		item = "mcl_core:iron_ingot", label = S("Iron"), rarity = "common", color = "#b9bdc2",
		level = 4, speed = 6, uses = 251, damage = 0.45, dig_speed_class = 4, enchantability = 14,
		binding_durability = 1.00, binding_speed = 1.00, binding_damage = 0.20, binding_attack = 1.00,
		handle_durability = 1.00, handle_speed = 1.00, handle_damage = 0.20, handle_attack = 1.00,
	},
	gold = {
		item = "mcl_core:gold_ingot", label = S("Gold"), rarity = "uncommon", color = "#f3c846",
		level = 2, speed = 12, uses = 33, damage = 0.20, dig_speed_class = 6, enchantability = 22,
		binding_durability = 0.68, binding_speed = 1.05, binding_damage = 0.08, binding_attack = 1.10,
		handle_durability = 0.75, handle_speed = 1.04, handle_damage = 0.08, handle_attack = 1.06,
	},
	silver = {
		item = "moreores:silver_ingot", label = S("Silver"), rarity = "uncommon", color = "#d9e2e8",
		level = 4, speed = 6.5, uses = 600, damage = 0.75, dig_speed_class = 4, enchantability = 16,
		binding_durability = 1.10, binding_speed = 1.02, binding_damage = 0.30, binding_attack = 1.02,
		handle_durability = 1.05, handle_speed = 1.01, handle_damage = 0.25, handle_attack = 1.02,
	},
	mithril = {
		item = "moreores:mithril_ingot", label = S("Mithril"), rarity = "rare", color = "#66d7e5",
		level = 5, speed = 8, uses = 2000, damage = 1.15, dig_speed_class = 5, enchantability = 18,
		binding_durability = 1.20, binding_speed = 1.04, binding_damage = 0.45, binding_attack = 1.04,
		handle_durability = 1.15, handle_speed = 1.02, handle_damage = 0.40, handle_attack = 1.03,
	},
	adamantine = {
		item = "adamantine:ingot", label = S("Adamantine"), rarity = "epic", color = "#a966e8",
		level = 6, speed = 16, uses = 4062, damage = 1.60, dig_speed_class = 6, enchantability = 20,
		binding_durability = 1.25, binding_speed = 1.06, binding_damage = 0.60, binding_attack = 1.06,
		handle_durability = 1.20, handle_speed = 1.03, handle_damage = 0.50, handle_attack = 1.04,
	},
}

local material_rarity_labels = {
	common = S("Common material"), uncommon = S("Uncommon material"),
	rare = S("Rare material"), epic = S("Epic material"), legendary = S("Legendary material"),
}
local quality_defs = {
	common = {label = S("Common"), color = "#b7b7b7", speed = 1.00, durability = 1.00, damage = 1.00, attack = 1.00},
	uncommon = {label = S("Uncommon"), color = "#45c14a", speed = 1.03, durability = 1.08, damage = 1.03, attack = 1.02, catalyst = "mcl_core:iron_nugget"},
	rare = {label = S("Rare"), color = "#3584e4", speed = 1.06, durability = 1.15, damage = 1.06, attack = 1.04, catalyst = "mcl_core:gold_nugget"},
	epic = {label = S("Epic"), color = "#a335ee", speed = 1.09, durability = 1.25, damage = 1.09, attack = 1.06, catalyst = "mcl_core:lapis"},
	legendary = {label = S("Legendary"), color = "#ff8000", speed = 1.12, durability = 1.35, damage = 1.12, attack = 1.08, catalyst = "mcl_core:diamond"},
}
local quality_by_catalyst = {}
for quality, def in pairs(quality_defs) do
	if def.catalyst then quality_by_catalyst[def.catalyst] = quality end
end

local tool_defs = {
	pick = {label = S("Pickaxe"), diggroup = "pickaxey", group = "pickaxe", icon = "default_tool_steelpick.png", damage = 3.0, interval = 0.85, head_icon = "everforge_part_head.png"},
	axe = {label = S("Axe"), diggroup = "axey", group = "axe", icon = "default_tool_steelaxe.png", damage = 6.0, interval = 1.05, head_icon = "everforge_part_axe_head.png"},
	shovel = {label = S("Shovel"), diggroup = "shovely", group = "shovel", icon = "default_tool_steelshovel.png", damage = 3.0, interval = 1.0, head_icon = "everforge_part_shovel_head.png"},
	sword = {label = S("Sword"), diggroup = "swordy", group = "sword", icon = "default_tool_steelsword.png", damage = 6.0, interval = 0.625, head_icon = "everforge_part_sword_blade.png"},
}
local base_output_types = {
	["everforge:alloy_pick"] = "pick", ["everforge:alloy_axe"] = "axe",
	["everforge:alloy_shovel"] = "shovel", ["everforge:alloy_sword"] = "sword",
}

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function calculate_modular_stats(tool_type, head_name, binding_name, handle_name, quality_name)
	local head, binding, handle = forge_materials[head_name], forge_materials[binding_name], forge_materials[handle_name]
	local quality = quality_defs[quality_name]
	if not head or not binding or not handle or not quality then return nil end
	local kind = tool_defs[tool_type]
	local raw_speed_multiplier = binding.binding_speed * handle.handle_speed * quality.speed
	local mining_speed = clamp(head.speed * raw_speed_multiplier, 2.5, 18)
	local speed_multiplier = mining_speed / head.speed
	local uses = clamp(math.floor(head.uses * binding.binding_durability * handle.handle_durability * quality.durability + 0.5), 60, 10000)
	local damage = clamp((kind.damage + head.damage + binding.binding_damage + handle.handle_damage) * quality.damage, 1, 14)
	local attack_speed = binding.binding_attack * handle.handle_attack * quality.attack
	local interval = clamp(kind.interval / attack_speed, 0.35, 1.5)
	return {
		level = head.level, speed = mining_speed, speed_multiplier = speed_multiplier,
		uses = uses, damage = damage, interval = interval, attack_speed = attack_speed,
	}
end

local function format_percent(multiplier)
	return tostring(math.floor((multiplier - 1) * 100 + 0.5))
end

local function build_modular_description(tool_type, head_name, binding_name, handle_name, quality_name, stats)
	local tool, head, binding, handle, quality = tool_defs[tool_type], forge_materials[head_name], forge_materials[binding_name], forge_materials[handle_name], quality_defs[quality_name]
	local title = quality.label .. " " .. head.label .. " " .. tool.label
	if core.colorize then title = core.colorize(quality.color, title) end
	return table.concat({
		title,
		S("Craft quality: @1", quality.label),
		S("Head: @1 (@2); binding: @3 (@4); handle: @5 (@6)", head.label, material_rarity_labels[head.rarity], binding.label, material_rarity_labels[binding.rarity], handle.label, material_rarity_labels[handle.rarity]),
		S("Damage: @1; attack interval: @2 s", string.format("%.1f", stats.damage), string.format("%.2f", stats.interval)),
		S("Mining speed: @1; mining level: @2", string.format("%.1f", stats.speed), tostring(stats.level)),
		S("Durability: @1 uses", tostring(stats.uses)),
		S("Quality bonuses: +@1% damage, +@2% mining speed, +@3% durability, +@4% attack speed", format_percent(quality.damage), format_percent(quality.speed), format_percent(quality.durability), format_percent(quality.attack)),
	}, "\n")
end

local function forged_after_use(stack, user, _node, digparams)
	if user and user:is_player() and digparams and digparams.wear and digparams.wear > 0
		and not core.is_creative_enabled(user:get_player_name()) then
		stack:add_wear(math.floor(digparams.wear * perk_wear_multiplier(user)))
	end
	return stack
end

local function register_modular_tool(name, tool_type, head_name, legacy)
	local tool, material = tool_defs[tool_type], forge_materials[head_name]
	local itemname = name or ("everforge:modular_" .. tool_type .. "_" .. head_name)
	local icon = tool.icon .. "^[colorize:" .. (legacy and "#ba7443" or material.color) .. ":100"
	local legacy_damage = {pick = 5, axe = 6, shovel = 5, sword = 8}
	local level = legacy and 4 or material.level
	local speed = legacy and 8 or material.speed
	local uses = legacy and 600 or material.uses
	local attack_damage = legacy and legacy_damage[tool_type] or (tool.damage + material.damage)
	local interval = legacy and 0.9 or tool.interval
	local groups = {
		tool = 1, [tool.group] = 1,
		dig_speed_class = legacy and 4 or material.dig_speed_class,
		enchantability = legacy and 8 or material.enchantability,
	}
	if not legacy then groups.offhand_item = 1 end
	core.register_tool(itemname, {
		description = legacy and S("Alloy Modular @1", tool.label) or S("Modular @1", tool.label),
		_doc_items_longdesc = S("A modular Everforge tool. Its mining level is fixed by its head; binding, handle and tempering quality affect its other statistics."),
		inventory_image = icon, wield_image = icon, wield_scale = mcl_vars.tool_wield_scale,
		stack_max = 1,
		groups = groups,
		_mcl_toollike_wield = true,
		_mcl_diggroups = {[tool.diggroup] = {speed = speed, level = level, uses = uses}},
		tool_capabilities = {full_punch_interval = interval, max_drop_level = level, punch_attack_uses = uses / (tool_type == "sword" and 1 or 2), damage_groups = {fleshy = attack_damage}},
		on_place = mcl_tools.tool_place_funcs[tool_type],
		sound = {breaks = "default_tool_breaks"},
		_repair_material = not legacy and material.item or nil,
		after_use = forged_after_use,
		_everforge_modular = {tool_type = tool_type, head_material = head_name},
	})
	return itemname
end

-- Keep the original item IDs for old tools and recipes. New crafts output these
-- IDs transiently, then the craft callback replaces them with head-tier variants.
local modular_variants = {}
for tool_type in pairs(tool_defs) do
	modular_variants[tool_type] = {}
	register_modular_tool("everforge:alloy_" .. tool_type, tool_type, "iron", true)
	for material_name in pairs(forge_materials) do
		modular_variants[tool_type][material_name] = register_modular_tool(nil, tool_type, material_name, false)
	end
end

local function component_item(kind, material_name, tool_type)
	if kind == "head" then return "everforge:component_" .. tool_type .. "_head_" .. material_name end
	if kind == "binding" then return "everforge:component_binding_" .. material_name end
	return "everforge:component_handle_" .. material_name
end

local function register_component(itemname, kind, material_name, tool_type, label, image, groups)
	local material = forge_materials[material_name]
	core.register_craftitem(itemname, {
		description = S("@1 @2", material.label, label),
		_doc_items_longdesc = S("A reusable Everforge part made from @1. Material rarity and finished-tool craft quality are separate properties.", material.label),
		inventory_image = image .. "^[colorize:" .. material.color .. ":130",
		stack_max = 99,
		groups = groups,
		_everforge_component = {kind = kind, material = material_name, tool_type = tool_type},
	})
end

local head_groups = {}
for tool_type in pairs(tool_defs) do head_groups[tool_type] = "everforge_component_" .. tool_type .. "_head" end
local binding_group, handle_group = "everforge_component_binding", "everforge_component_handle"

-- Retain the old component item names as iron parts. Old saves and existing
-- stacks remain usable in the new recipes.
local legacy_head_groups = {craftitem = 1, everforge_component = 1}
for _, group in pairs(head_groups) do legacy_head_groups[group] = 1 end
core.register_craftitem("everforge:tool_head", {
	description = S("Iron Tool Head (legacy component)"), inventory_image = "everforge_part_head.png^[colorize:#b9bdc2:130", stack_max = 99,
	groups = legacy_head_groups, _everforge_component = {kind = "head", material = "iron", tool_type = "any"},
})
core.register_craftitem("everforge:tool_binding", {
	description = S("Iron Tool Binding (legacy component)"), inventory_image = "everforge_part_binding.png^[colorize:#b9bdc2:130", stack_max = 99,
	groups = {craftitem = 1, everforge_component = 1, [binding_group] = 1},
	_everforge_component = {kind = "binding", material = "iron"},
})
core.register_craftitem("everforge:reinforced_handle", {
	description = S("Iron-Reinforced Handle (legacy component)"), inventory_image = "everforge_part_handle.png^[colorize:#b9bdc2:130", stack_max = 99,
	groups = {craftitem = 1, everforge_component = 1, [handle_group] = 1},
	_everforge_component = {kind = "handle", material = "iron"},
})

local head_recipes = {
	pick = function(m) return {{m, m, m}, {"", m, ""}} end,
	axe = function(m) return {{m, m}, {m, ""}} end,
	shovel = function(m) return {{m}} end,
	sword = function(m) return {{m}, {m}} end,
}
local head_labels = {pick = S("Pickaxe Head"), axe = S("Axe Head"), shovel = S("Shovel Head"), sword = S("Sword Blade")}
for material_name, material in pairs(forge_materials) do
	for tool_type, tool in pairs(tool_defs) do
		local groups = {craftitem = 1, everforge_component = 1, [head_groups[tool_type]] = 1}
		local itemname = component_item("head", material_name, tool_type)
		register_component(itemname, "head", material_name, tool_type, head_labels[tool_type], tool.head_icon, groups)
		core.register_craft({output = itemname, recipe = head_recipes[tool_type](material.item)})
	end
	local binding = component_item("binding", material_name)
	register_component(binding, "binding", material_name, nil, S("Tool Binding"), "everforge_part_binding.png", {craftitem = 1, everforge_component = 1, [binding_group] = 1})
	core.register_craft({output = binding, recipe = {{material.item, material.item}, {"mcl_core:stick", ""}}})
	local handle = component_item("handle", material_name)
	register_component(handle, "handle", material_name, nil, S("Reinforced Handle"), "everforge_part_handle.png", {craftitem = 1, everforge_component = 1, [handle_group] = 1})
	core.register_craft({output = handle, recipe = {{"mcl_core:stick"}, {material.item}, {"mcl_core:stick"}}})
end

-- Original recipes are kept for the legacy iron component IDs.
core.register_craft({output = "everforge:tool_head 2", recipe = {{"mcl_core:iron_ingot", "mcl_core:iron_ingot"}, {"mcl_core:iron_ingot", ""}}})
core.register_craft({output = "everforge:tool_binding 2", recipe = {{"mcl_core:iron_ingot", "mcl_core:iron_ingot", "mcl_core:iron_ingot"}}})
core.register_craft({output = "everforge:reinforced_handle 2", recipe = {{"mcl_core:stick"}, {"mcl_core:iron_ingot"}}})

local function apply_modular_stack(stack)
	local meta = stack:get_meta()
	local tool_type = meta:get_string("everforge:tool_type")
	local head_name = meta:get_string("everforge:head_material")
	local binding_name = meta:get_string("everforge:binding_material")
	local handle_name = meta:get_string("everforge:handle_material")
	local quality_name = meta:get_string("everforge:quality")
	local stats = calculate_modular_stats(tool_type, head_name, binding_name, handle_name, quality_name)
	if not stats then return stack end

	local itemname = stack:get_name()
	local efficiency, unbreaking = 0, 0
	if mcl_enchanting and mcl_enchanting.get_enchantment then
		efficiency = mcl_enchanting.get_enchantment(stack, "efficiency") or 0
		unbreaking = mcl_enchanting.get_enchantment(stack, "unbreaking") or 0
	end
	local caps = stack:get_tool_capabilities()
	caps = table.copy(caps or {})
	local groupcaps = mcl_autogroup.get_groupcaps(itemname, efficiency)
	for _, groupcap in pairs(groupcaps) do
		if groupcap.times then
			for level, time in pairs(groupcap.times) do
				groupcap.times[level] = math.max(0.05, time / stats.speed_multiplier)
			end
		end
		groupcap.uses = math.floor(stats.uses * (1 + unbreaking) + 0.5)
	end
	caps.groupcaps = groupcaps
	caps.full_punch_interval = stats.interval
	caps.max_drop_level = stats.level
	caps.punch_attack_uses = math.max(1, math.floor(stats.uses / (tool_type == "sword" and 1 or 2)))
	caps.damage_groups = {fleshy = stats.damage}
	meta:set_tool_capabilities(caps)

	local head, binding, handle, quality = forge_materials[head_name], forge_materials[binding_name], forge_materials[handle_name], quality_defs[quality_name]
	local description = build_modular_description(tool_type, head_name, binding_name, handle_name, quality_name, stats)
	meta:set_string("description", description)
	-- Toolranks retains this full materials/quality/stat summary when adding its
	-- own persistent rank line to the stack description.
	meta:set_string("toolranks:original_description", description)
	meta:set_string("everforge:material_rarity:head", head.rarity)
	meta:set_string("everforge:material_rarity:binding", binding.rarity)
	meta:set_string("everforge:material_rarity:handle", handle.rarity)
	meta:set_string("everforge:stats:mining_level", tostring(stats.level))
	meta:set_string("everforge:stats:mining_speed", string.format("%.2f", stats.speed))
	meta:set_string("everforge:stats:durability", tostring(stats.uses))
	meta:set_string("everforge:stats:damage", string.format("%.2f", stats.damage))
	meta:set_string("everforge:stats:attack_interval", string.format("%.3f", stats.interval))
	meta:set_string("everforge:stats:quality_bonus", quality_name)
	return stack
end

local function build_modular_tool(itemstack, old_craft_grid)
	local tool_type = base_output_types[itemstack:get_name()]
	if not tool_type then return itemstack end
	local components, quality_name = {}, "common"
	for _, ingredient in ipairs(old_craft_grid or {}) do
		if ingredient and not ingredient:is_empty() then
			local def = ingredient:get_definition()
			local component = def and def._everforge_component
			if component then
				if components[component.kind] then return itemstack end
				components[component.kind] = component
			else
				local found_quality = quality_by_catalyst[ingredient:get_name()]
				if found_quality then quality_name = found_quality end
			end
		end
	end
	if not components.head or not components.binding or not components.handle then return itemstack end
	if components.head.tool_type and components.head.tool_type ~= "any" and components.head.tool_type ~= tool_type then return itemstack end
	local itemname = modular_variants[tool_type][components.head.material]
	if not itemname then return itemstack end

	itemstack:set_name(itemname)
	local meta = itemstack:get_meta()
	meta:set_string("everforge:tool_type", tool_type)
	meta:set_string("everforge:head_material", components.head.material)
	meta:set_string("everforge:binding_material", components.binding.material)
	meta:set_string("everforge:handle_material", components.handle.material)
	meta:set_string("everforge:quality", quality_name)
	meta:set_string("everforge:quality_catalyst", quality_defs[quality_name].catalyst or "")
	return apply_modular_stack(itemstack)
end

core.register_craft_predict(function(itemstack, _player, old_craft_grid)
	return build_modular_tool(itemstack, old_craft_grid)
end)
core.register_on_craft(function(itemstack, _player, old_craft_grid)
	return build_modular_tool(itemstack, old_craft_grid)
end)

local function register_modular_assembly_recipes()
	local quality_positions = {
		common = nil, uncommon = {1, 1}, rare = {1, 3}, epic = {3, 1}, legendary = {3, 3},
	}
	for tool_type in pairs(tool_defs) do
		for quality_name, quality in pairs(quality_defs) do
			local recipe = {
				{"", "group:" .. head_groups[tool_type], ""},
				{"", "group:" .. binding_group, ""},
				{"", "group:" .. handle_group, ""},
			}
			local position = quality_positions[quality_name]
			if position then recipe[position[1]][position[2]] = quality.catalyst end
			core.register_craft({output = "everforge:alloy_" .. tool_type, recipe = recipe})
		end
	end
end
register_modular_assembly_recipes()

-- Preserve the original component-only assembly patterns as legacy iron tools.
-- New recipes add a binding and support mixed-material, quality-selected builds.
core.register_craft({output = "everforge:alloy_pick", recipe = {{"everforge:tool_head", "everforge:tool_head", "everforge:tool_head"}, {"", "everforge:reinforced_handle", ""}, {"", "everforge:reinforced_handle", ""}}})
core.register_craft({output = "everforge:alloy_axe", recipe = {{"everforge:tool_head", "everforge:tool_head"}, {"everforge:tool_head", "everforge:reinforced_handle"}, {"", "everforge:reinforced_handle"}}})
core.register_craft({output = "everforge:alloy_shovel", recipe = {{"everforge:tool_head"}, {"everforge:reinforced_handle"}, {"everforge:reinforced_handle"}}})
core.register_craft({output = "everforge:alloy_sword", recipe = {{"everforge:tool_head"}, {"everforge:tool_head"}, {"everforge:reinforced_handle"}}})

-- MCL's enchanting mod creates hidden *_enchanted tool definitions and wraps
-- their after_use callbacks. Reapply the per-stack alloy data after that wrapper
-- so Efficiencies/Unbreaking keep working without replacing component stats.
core.register_on_mods_loaded(function()
	for tool_type, by_material in pairs(modular_variants) do
		for _, variant_name in pairs(by_material) do
			local enchanted_name = variant_name .. "_enchanted"
			local def = core.registered_tools[enchanted_name]
			if def and def.after_use then
				local previous_after_use = def.after_use
				core.override_item(enchanted_name, {
					after_use = function(stack, user, node, digparams)
						local result = previous_after_use(stack, user, node, digparams)
						return apply_modular_stack(result or stack)
					end,
				})
			end
		end
	end
end)

core.register_craft({output = "everforge:alloy_melter", recipe = {{"mcl_core:iron_ingot", "mcl_core:iron_ingot", "mcl_core:iron_ingot"}, {"mcl_core:iron_ingot", "mcl_furnaces:furnace", "mcl_core:iron_ingot"}, {"mcl_core:stone", "mcl_core:stone", "mcl_core:stone"}}})

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
