-- SPDX-License-Identifier: GPL-3.0-or-later
local modname = core.get_current_modname()
local S = core.get_translator(modname)
local random = PcgRandom(249955)

everforge = { version = "1.1.0-dev" }

local waila_huds = {}
local waila_suppressed = {}

local function hide_waila_for_player(player)
	local hud = waila_huds[player:get_player_name()]
	if not hud or hud[3] == false then return end
	player:hud_change(hud[1], "text", "")
	player:hud_change(hud[2], "text", "")
	-- Force the next visible update to restore the cached HUD text.
	hud[3] = false
end

local function suppress_waila_for_player(player, form_key)
	local name = player:get_player_name()
	waila_suppressed[name] = form_key
	hide_waila_for_player(player)
end

local function restore_waila_for_player(player, form_key)
	local name = player:get_player_name()
	if waila_suppressed[name] == form_key then
		waila_suppressed[name] = nil
	end
end

everforge._suppress_waila = suppress_waila_for_player
everforge._restore_waila = restore_waila_for_player

core.register_on_player_receive_fields(function(player, formname, fields)
	if not fields.quit then return end
	local key = waila_suppressed[player:get_player_name()]
	if key == formname or (key == "doc:" and formname:sub(1, 4) == "doc:") then
		restore_waila_for_player(player, key)
	end
end)

local progression = dofile(core.get_modpath(modname) .. "/progression/init.lua")
local function skill_rank(player, key) return progression.rank(player, key) end

-- Presentation is local to Everforge forms; never change mcl_vars or defaults.
local function forge_theme(width, height)
	return table.concat({
		"bgcolor[#08090BEF;true]",
		"background9[0,0;" .. width .. "," .. height .. ";everforge_ui_panel.png;false;8]",
		"style_type[label;textcolor=#F2E8D9]",
		"style_type[textarea;textcolor=#F2E8D9]",
		"style_type[button,button_exit;textcolor=#FFF1DC;border=false;bgimg=everforge_ui_button.png;bgimg_pressed=everforge_ui_button_pressed.png;bgimg_middle=4;font=bold]",
		"style_type[button:hovered,button_exit:hovered;bgimg=everforge_ui_button_hover.png]",
		"listcolors[#17191C;#704F39;#00000000;#151619;#F2E8D9]",
	})
end

local function forge_slots(x, y, w, h)
	return mcl_formspec.get_itemslot_bg_v4(x, y, w, h, nil, "everforge_ui_slot.png")
end

dofile(core.get_modpath(modname) .. "/progression/ui.lua")
dofile(core.get_modpath(modname) .. "/onboarding.lua")

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

local function forge_bonus_at(pos)
	local forge_bonus = 0
	for _, player in ipairs(core.get_connected_players()) do
		if vector.distance(player:get_pos(), pos) <= 8 then
			local personal_bonus = skill_rank(player, "forgemaster")
			forge_bonus = math.max(forge_bonus, personal_bonus)
		end
	end
	return forge_bonus
end

local function build_forge_formspec(pos)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local input = inv:get_stack("input", 1)
	local recipe = smelt_recipes[input:get_name()]
	local burn_total = math.max(0, meta:get_int("burn_total"))
	local burn = math.max(0, meta:get_int("burn"))
	local fuel_percent = burn_total > 0 and math.max(0, math.min(100, math.floor(burn * 100 / burn_total + 0.5))) or 0
	local progress_percent = 0
	if recipe then
		local effective_time = math.max(3, recipe.time - forge_bonus_at(pos))
		progress_percent = math.max(0, math.min(100, math.floor(meta:get_int("progress") * 100 / effective_time + 0.5)))
	end

	local state, state_color
	if not recipe then
		if input:is_empty() then
			state, state_color = S("No materials"), "#b7a58c"
		else
			state, state_color = S("Unsupported material"), "#e08b72"
		end
	elseif not inv:room_for_item("output", ItemStack(recipe.output)) then
		state, state_color = S("Output full"), "#e08b72"
	elseif burn > 0 then
		state, state_color = S("Working"), "#8bcf91"
	else
		local fuel_stack = inv:get_stack("fuel", 1)
		local fuel = core.get_craft_result({method = "fuel", width = 1, items = {fuel_stack}})
		if fuel and fuel.time and fuel.time > 0 then
			state, state_color = S("Ready"), "#e0b26f"
		else
			state, state_color = S("No fuel"), "#e08b72"
		end
	end

	local function colored(text, color)
		return core.formspec_escape(core.colorize(color, text))
	end
	local fire = "default_furnace_fire_bg.png"
	if fuel_percent > 0 then
		fire = fire .. "^[lowpart:" .. fuel_percent .. ":default_furnace_fire_fg.png"
	end
	local arrow = "gui_furnace_arrow_bg.png^[transformR270"
	if progress_percent > 0 then
		arrow = "gui_furnace_arrow_bg.png^[lowpart:" .. progress_percent .. ":gui_furnace_arrow_fg.png^[transformR270"
	end
	local fs = {
		"formspec_version[7]", "size[11.75,10.95]",
		forge_theme(11.75, 10.95),
		"box[0.2,0.15;11.35,4.95;#191A1DEE]",
		"box[0.38,0.32;0.055,0.38;#c27a4a]",
		"label[0.58,0.375;" .. colored(S("Everforge Alloy Melter"), "#e8b17d") .. "]",
		"label[0.375,0.85;" .. core.formspec_escape(S("Accepts: Tin, silver, mithril or adamantine lumps.")) .. "]",
		"label[0.375,1.2;" .. core.formspec_escape(S("Also raw iron and raw gold; ingots are not accepted.")) .. "]",
		"box[0.35,1.45;11.0,3.85;#242326EE]",
		"label[0.5,1.55;" .. core.formspec_escape(S("Status")) .. "]",
		"label[1.6,1.55;" .. colored(state, state_color) .. "]",
		"label[0.5,1.9;" .. core.formspec_escape(S("Fuel: @1%", tostring(fuel_percent))) .. "]",
		"label[5.0,1.9;" .. core.formspec_escape(S("Progress: @1%", tostring(progress_percent))) .. "]",
		"label[0.75,2.35;" .. core.formspec_escape(S("Input")) .. "]",
		forge_slots(0.75, 2.65, 1, 1),
		"list[context;input;0.75,2.65;1,1;]",
		"image[2.1,2.4;1,1;" .. fire .. "]",
		"label[2.1,3.78;" .. core.formspec_escape(S("Fuel")) .. "]",
		forge_slots(2.1, 4.05, 1, 1),
		"list[context;fuel;2.1,4.05;1,1;]",
		"image[4.5,2.65;1.5,1;" .. arrow .. "]",
		"label[6.5,2.35;" .. core.formspec_escape(S("Products")) .. "]",
		forge_slots(6.5, 2.65, 4, 2),
		"list[context;output;6.5,2.65;4,2;]",
		"label[0.375,5.2;" .. core.formspec_escape(S("Inventory")) .. "]",
		forge_slots(0.375, 5.55, 9, 3),
		"list[current_player;main;0.375,5.55;9,3;9]",
		forge_slots(0.375, 9.5, 9, 1),
		"list[current_player;main;0.375,9.5;9,1;]",
		"listring[context;output]listring[current_player;main]",
		"listring[context;input]listring[current_player;main]",
		"listring[context;fuel]listring[current_player;main]",
	}
	return table.concat(fs), state
end

local function update_melter_interface(pos)
	local meta = core.get_meta(pos)
	local formspec, state = build_forge_formspec(pos)
	meta:set_string("formspec", formspec)
	-- Luanti renders `infotext` as a separate native label, independently
	-- of our WAILA HUD. Keep the full status for WAILA and the formspec,
	-- but do not publish a second copy to the client's native label.
	meta:set_string("everforge:machine_infotext", S("Everforge Alloy Melter — @1", state))
	meta:set_string("infotext", "")
end

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
	if meta:get_int("burn") < 0 then meta:set_int("burn", 0) end
	if meta:get_int("progress") < 0 then meta:set_int("progress", 0) end
	if meta:get_int("burn_total") < meta:get_int("burn") then
		-- Adopt the remaining time of a melter saved by an older build without
		-- changing its fuel consumption or duration.
		meta:set_int("burn_total", math.max(0, meta:get_int("burn")))
	end
	update_melter_interface(pos)
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
	update_melter_interface(pos)
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
	if moved then
		core.get_meta(melter_pos):set_string("everforge:forger", "")
		restart_melter(melter_pos)
	end
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
		meta:set_int("burn_total", 0)
		meta:set_int("progress", 0)
		meta:set_string("active_input", "")
		core.get_node_timer(pos):start(1)
	end,
	on_rightclick = function(_, _, clicker, itemstack)
		if clicker and clicker:is_player() then
			suppress_waila_for_player(clicker, "melter")
		end
		return itemstack
	end,
	on_receive_fields = function(_, _, fields, sender)
		if fields.quit and sender and sender:is_player() then
			restore_waila_for_player(sender, "melter")
		end
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
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "input" then core.get_meta(pos):set_string("everforge:forger", player and player:get_player_name() or "") end
		restart_melter(pos)
	end,
	on_metadata_inventory_take = restart_melter,
	on_metadata_inventory_move = function(pos, from_list, from_index, to_list)
		if to_list == "input" then core.get_meta(pos):set_string("everforge:forger", "") end
		restart_melter(pos)
	end,
	on_timer = function(pos)
		local meta = core.get_meta(pos)
		local inv = meta:get_inventory()
		local input = inv:get_stack("input", 1)
		local recipe = smelt_recipes[input:get_name()]
		sync_melter_input(pos)
		if not recipe then
			meta:set_int("progress", 0)
			update_melter_interface(pos)
			return false
		end

		local out = ItemStack(recipe.output)
		if not inv:room_for_item("output", out) then
			update_melter_interface(pos)
			return false
		end
		if meta:get_int("burn") <= 0 then
			local fuel_stack = inv:get_stack("fuel", 1)
			local fuel, afterfuel = core.get_craft_result({method = "fuel", width = 1, items = {fuel_stack}})
			if not fuel or not fuel.time or fuel.time <= 0 then
				update_melter_interface(pos)
				return false
			end
			local fuel_duration = math.max(1, math.floor(fuel.time))
			meta:set_int("burn", fuel_duration)
			meta:set_int("burn_total", fuel_duration)
			local remaining_fuel = afterfuel and afterfuel.items and afterfuel.items[1] or ItemStack("")
			inv:set_stack("fuel", 1, remaining_fuel)
		end

		meta:set_int("burn", meta:get_int("burn") - 1)
		local effective_time = math.max(3, recipe.time - forge_bonus_at(pos))
		local progress = meta:get_int("progress") + 1
		if progress >= effective_time then
			-- Add the output before consuming the ingredient, and verify the
			-- inventory accepted it. This keeps a full output slot lossless.
			local leftover = inv:add_item("output", out)
			if not leftover:is_empty() then return false end
			input:take_item(1)
			inv:set_stack("input", 1, input)
			local actor = core.get_player_by_name(meta:get_string("everforge:forger"))
			if actor and vector.distance(actor:get_pos(), pos) <= 16 then
				progression.record(actor, "forging", out:get_name())
			end
			progress = 0
		end
		meta:set_int("progress", progress)
		-- Keep the open node formspec in step with these authoritative timer
		-- values; metadata formspecs are refreshed when their metadata changes.
		update_melter_interface(pos)
		return true
	end,
})

-- Refresh already-placed melters after updates, without clearing their saved
-- inventories or smelting state. This also repairs old list sizes/formspecs.
core.register_lbm({
	label = S("Update Everforge alloy melter inventory and interface"),
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
-- Contextual block identification (WAILA-style) and mineral field guide.
-- Mineclonia's doc system remains the source of rich item descriptions; this
-- small HUD only adds the live target, native mining groups and available state.
-- ---------------------------------------------------------------------------
local waila_timer = 0
local waila_interval = math.max(0.15, math.min(1.5, core.settings:get("everforge_waila_interval") and tonumber(core.settings:get("everforge_waila_interval")) or 0.35))
local waila_default_enabled = core.settings:get_bool("everforge_waila_enabled", true)
local mining_group_labels = {
	{"pickaxey", S("Pickaxe")}, {"axey", S("Axe")}, {"shovely", S("Shovel")}, {"hoey", S("Hoe")},
	{"swordy", S("Sword")}, {"shearsy", S("Shears")},
}

local function get_mining_requirement(groups)
	for _, entry in ipairs(mining_group_labels) do
		local value = tonumber(groups[entry[1]])
		if value and value > 0 then
			local tool = S("Recommended tool: @1", entry[2])
			-- Mineclonia defines material tiers only for pickaxey. Other diggroup
			-- values identify tool suitability; they are not mining levels.
			if entry[1] == "pickaxey" then return tool, S("Minimum mining level: @1", tostring(value)) end
			return tool, nil
		end
	end
	if (groups.cultivatable or 0) > 0 then return S("Recommended tool: Hoe"), nil end
	if (groups.path_creation_possible or 0) > 0 then return S("Recommended tool: Shovel"), nil end
	return S("Recommended tool: Hand or any tool"), nil
end

local function get_node_kind(node_name, def, meta)
	local groups = def.groups or {}
	if node_name:find("ore", 1, true) or node_name:find("mineral", 1, true) or node_name:find("stone_with_", 1, true) or node_name:find("deepslate_with_", 1, true) or groups.ore then return S("Ore") end
	if node_name:find("mcl_farming:", 1, true) or groups.crop then return S("Crop") end
	local inv = meta and meta:get_inventory()
	local has_inventory = inv and inv:get_size("main") > 0
	if def.on_timer or ((def.allow_metadata_inventory_put or def.allow_metadata_inventory_take) and has_inventory) then return S("Machine") end
	if groups.container and groups.container > 0 then return S("Container") end
	if groups.plant or groups.flower or groups.sapling then return S("Plant") end
	if groups.material_stone or groups.stone then return S("Stone") end
	if groups.wood or groups.tree or groups.material_wood then return S("Wood") end
	if groups.metal or groups.iron then return S("Metal") end
	return nil
end

local localized_item_name

local function safe_hud_status(text)
	if type(text) ~= "string" or text == "" then return "" end
	text = text:gsub("([%w_%-]+:[%w_%-]+)", function(itemname)
		return localized_item_name and localized_item_name(itemname) or ""
	end)
	text = text:gsub("%s+([,.;:])", "%1"):gsub("%s%s+", " ")
	return text
end

local function get_node_extra(node_name, def, pos, meta)
	local extra = {}
	local info = meta and meta:get_string("infotext") or ""
	if node_name == "everforge:alloy_melter" and meta then
		info = meta:get_string("everforge:machine_infotext")
	end
	if def.on_timer or node_name == "everforge:alloy_melter" then
		local active = meta and meta:get_string("active_input") or ""
		local recipe = smelt_recipes[active]
		if recipe then
			local input_name = localized_item_name and localized_item_name(active)
			local output_name = localized_item_name and localized_item_name(recipe.output)
			if input_name and output_name then
				extra[#extra + 1] = S("Processing: @1 → @2", input_name, output_name)
			elseif info ~= "" then
				extra[#extra + 1] = S("Status: @1", safe_hud_status(info))
			end
		elseif meta and meta:get_int("burn") > 0 then
			extra[#extra + 1] = S("Machine is burning fuel.")
		elseif info ~= "" then
			extra[#extra + 1] = S("Status: @1", safe_hud_status(info))
		end
	elseif info ~= "" then
		extra[#extra + 1] = S("Status: @1", safe_hud_status(info))
	end
	if core.get_item_group(node_name, "plant") > 0 then
		local stage = node_name:match("_(%d+)$")
		if stage then extra[#extra + 1] = S("Crop stage: @1", stage) end
	end
	return extra
end

local function localize_waila_lines(lines, lang_code)
	lang_code = lang_code or "en"
	local translated = {}
	for index, line in ipairs(lines) do
		translated[index] = core.get_translated_string(lang_code, line)
	end
	return translated
end

-- Kept private-by-convention so the translation regression test can exercise
-- the exact conversion used by the HUD without needing a pointed player.
everforge._localize_waila_lines = localize_waila_lines

local function waila_text(player)
	local pointed = mcl_util.get_pointed_thing(player, false, false)
	if not pointed or pointed.type ~= "node" or not pointed.under then return "" end
	local node = core.get_node_or_nil(pointed.under)
	local def = node and core.registered_nodes[node.name]
	if not def or node.name == "air" or node.name == "ignore" then return "" end
	local name = localized_item_name and localized_item_name(node.name)
	local meta = core.get_meta(pointed.under)
	-- Prefer a registered, translated description (including documentation
	-- aliases for internal variants). If none exists, use a translated generic
	-- label and keep live-state information without exposing registry IDs.
	local _, level = get_mining_requirement(def.groups or {})
	local lines = {name or S("Unlabeled block")}
	if level then lines[#lines + 1] = level end
	for _, line in ipairs(get_node_extra(node.name, def, pointed.under, meta)) do lines[#lines + 1] = line end
	-- Resolve each independently translated field in the player's language
	-- before joining the HUD. This prevents a domain marker from one field
	-- being interpreted as part of another field's translation template.
	local player_info = core.get_player_information(player:get_player_name())
	lines = localize_waila_lines(lines, player_info and player_info.lang_code or "en")
	return table.concat(lines, "\n")
end

-- Read-only diagnostic, also used by runtime HUD regressions.
everforge._waila_text = waila_text

local function waila_enabled(player)
	if not waila_default_enabled then return false end
	local saved = player:get_meta():get_string("everforge:waila_enabled")
	return saved == "" or saved == "1"
end

local WAILA_TEXTURE_SIZE = 256
local WAILA_CHAR_WIDTH = 9
local WAILA_LINE_HEIGHT = 20

local function waila_line_count(text)
	if text == "" then return 0 end
	local _, newlines = text:gsub("\n", "")
	return newlines + 1
end

local function layout_waila_text(text)
	if text == "" then return "", {x = 1, y = 1} end
	-- This is only a conservative sizing estimate. Do not feed a composite of
	-- already-translated strings from several textdomains back through
	-- get_translated_string: nested domain markers (for example Adamantine item
	-- descriptions inside Everforge HUD text) are not a translation template.
	-- Strip Luanti's markup from a copy while keeping the displayed string intact.
	local measured_text = text:gsub("\27%([^)]-%)", ""):gsub("\27.", "")

	local longest, line_count = 0, 0
	for line in (measured_text .. "\n"):gmatch("(.-)\n") do
		line_count = line_count + 1
		longest = math.max(longest, #line)
	end
	-- Translation should retain explicit line breaks; use the source count if a
	-- translation backend ever collapses them so the panel still reserves space.
	line_count = math.max(line_count, waila_line_count(text))
	local width = math.max(220, math.ceil(longest * WAILA_CHAR_WIDTH * 1.25 + 32))
	local height = math.max(40, line_count * WAILA_LINE_HEIGHT + 18)
	return text, {
		x = math.ceil(width / 16) * 16 / WAILA_TEXTURE_SIZE,
		y = math.ceil(height / 16) * 16 / WAILA_TEXTURE_SIZE,
	}
end

local function waila_bossbar_offset(player)
	local bossbars = rawget(_G, "mcl_bossbars")
	local visible_bars = bossbars and bossbars.huds and bossbars.huds[player:get_player_name()]
	return 24 + (visible_bars and #visible_bars or 0) * 40
end

local function update_waila(player)
	local name = player:get_player_name()
	if waila_suppressed[name] then
		hide_waila_for_player(player)
		return
	end
	local enabled = waila_enabled(player)
	local content = enabled and waila_text(player) or ""
	local text, panel_scale = layout_waila_text(content)
	local visible = text ~= ""
	local offset_y = waila_bossbar_offset(player)
	local hud = waila_huds[name]
	if not hud then
		-- y=1 anchors the top edge. y=-1 would shift a multiline text block
		-- above the screen, leaving only its last line visible.
		local background = {
			type = "image", position = {x = 0.5, y = 0.04}, alignment = {x = 0, y = 1},
			offset = {x = 0, y = offset_y - 8}, scale = panel_scale,
			text = visible and "everforge_waila_panel.png" or "", z_index = 4,
		}
		-- Text HUD sizing uses `size`, not the ignored `scale` field.
		local label = {
			type = "text", position = {x = 0.5, y = 0.04}, alignment = {x = 0, y = 1},
			offset = {x = 0, y = offset_y}, size = {x = 1, y = 1},
			text = text, number = 0xF2E8D9, style = 1, z_index = 5,
		}
		waila_huds[name] = {
			player:hud_add(background), player:hud_add(label), text, panel_scale.x, panel_scale.y, offset_y,
		}
	elseif hud[3] ~= text or hud[4] ~= panel_scale.x or hud[5] ~= panel_scale.y or hud[6] ~= offset_y then
		hud[3], hud[4], hud[5], hud[6] = text, panel_scale.x, panel_scale.y, offset_y
		player:hud_change(hud[1], "text", visible and "everforge_waila_panel.png" or "")
		player:hud_change(hud[1], "scale", panel_scale)
		player:hud_change(hud[1], "offset", {x = 0, y = offset_y - 8})
		player:hud_change(hud[2], "text", text)
		player:hud_change(hud[2], "offset", {x = 0, y = offset_y})
	end
end

core.register_globalstep(function(dtime)
	waila_timer = waila_timer + dtime
	if waila_timer < waila_interval then return end
	waila_timer = 0
	for _, player in ipairs(core.get_connected_players()) do update_waila(player) end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	waila_huds[name] = nil
	waila_suppressed[name] = nil
end)

core.register_chatcommand("everforge_waila", {
	params = S("[on|off]"), description = S("Enable or disable the contextual block information overlay."),
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then return false, S("You must be online to change this setting.") end
		local option = param:lower():match("^%s*(.-)%s*$")
		if option ~= "on" and option ~= "off" then
			option = player:get_meta():get_string("everforge:waila_enabled") == "1" and "off" or "on"
		end
		if option == "on" and not waila_default_enabled then
			return false, S("The server has disabled the contextual block information overlay.")
		end
		player:get_meta():set_string("everforge:waila_enabled", option == "on" and "1" or "0")
		return true, option == "on" and S("Block information overlay enabled.") or S("Block information overlay disabled.")
	end,
})

local function valid_display_name(text)
	if type(text) ~= "string" or text == "" then return nil end
	local first = text:match("^[^\n]+") or text
	-- Some internally generated nodes have no description. Never turn their
	-- registry key into ordinary HUD copy.
	if first:match("^[%w_%-]+:[%w_%-]+$") then return nil end
	return first
end

local function documentation_display_name(itemname)
	if not (doc and doc.get_entry_definition) then return nil end
	for _, category in ipairs({"nodes", "tools", "craftitems", "mobs"}) do
		local entry = doc.get_entry_definition(category, itemname)
		local name = entry and valid_display_name(entry.name)
		if name then return name end
	end
	return nil
end

localized_item_name = function(itemname)
	if type(itemname) ~= "string" or itemname == "" then return nil end
	itemname = itemname:match("^([^%s]+)") or itemname
	local def = core.registered_items[itemname]
	local name = def and (valid_display_name(def.description) or valid_display_name(def._doc_items_entry_name))
	return name or documentation_display_name(itemname)
end

local function mineral_drop_item(node_def)
	local drop = node_def and node_def.drop
	if type(drop) == "string" then return drop:match("^([^%s]+)") end
	if type(drop) == "table" and drop.items and drop.items[1] and drop.items[1].items then return drop.items[1].items[1] end
	return nil
end

local function mining_guide_line(node_name)
	local def = core.registered_nodes[node_name]
	local groups = def and def.groups or {}
	local tool, level = get_mining_requirement(groups)
	local pick_level = tonumber(groups.pickaxey)
	if pick_level and pick_level > 0 then
		return S("Recommended tool: Pickaxe; Mineclonia pickaxey group level: @1", tostring(pick_level))
	end
	return level and (tool .. "\n" .. level) or tool
end

local function active_overworld_biome_count(placed_name)
	local count = 0
	for _, biome in pairs(mcl_levelgen.registered_biomes or {}) do
		if biome.groups and biome.groups.is_overworld and biome.features and biome.features[7]
			and table.indexof(biome.features[7], placed_name) ~= -1 then count = count + 1 end
	end
	return count
end

local function get_material_uses(material, ingot)
	local has_components, equipment = false, false
	for name, def in pairs(core.registered_items) do
		if def._everforge_component and def._everforge_component.material == material then has_components = true end
		if def._repair_material == ingot then equipment = true end
	end
	local uses = {}
	local modname = ingot:match("^([^:]+):")
	if modname and (core.registered_items[modname .. ":block"] or core.registered_items[modname .. ":" .. material .. "_block"]) then
		uses[#uses + 1] = S("Storage and construction blocks.")
	end
	if has_components then uses[#uses + 1] = S("Everforge heads, bindings and reinforced handles.") end
	if equipment then uses[#uses + 1] = S("Tools or equipment registered for this ingot.") end
	if #uses == 0 then uses[1] = S("No additional Everforge recipes use this metal.") end
	return table.concat(uses, "\n")
end

local function moreores_band_lines(mineral)
	local cfg_prefix = "moreores." .. mineral .. "_"
	local labels = {{"high", S("High band")}, {"", S("Middle band")}, {"deep", S("Deep band")}}
	local lines = {}
	for _, band in ipairs(labels) do
		local suffix = band[1] == "" and "" or "_" .. band[1]
		local y_min = tonumber(moreores[cfg_prefix .. "min_depth" .. suffix])
		local y_max = tonumber(moreores[cfg_prefix .. "max_depth" .. suffix])
		local chunk_size = tonumber(moreores[cfg_prefix .. "chunk_size" .. suffix])
		local ore_count = tonumber(moreores[cfg_prefix .. "ore_per_chunk" .. suffix])
		local cluster_size = tonumber(moreores[cfg_prefix .. "clust_size" .. suffix])
		if y_min and y_max and chunk_size and ore_count and cluster_size then
			local low, high = math.min(y_min, y_max), math.max(y_min, y_max)
			local expected = ((high - low + 1) * 256 / (chunk_size ^ 3)) * ore_count / 8
			lines[#lines + 1] = S("@1, Y @2 to @3; approximately @4 configured cluster placements per horizontal chunk.", band[2], tostring(low), tostring(high), string.format("%.2f", expected))
		end
	end
	return lines
end

local function mineral_entry_text(mineral, title, node_name, ingot, moreores_key)
	local def = core.registered_nodes[node_name]
	if not def then return nil end
	local lines = {S("Mineral: @1", title), S("Block: @1", localized_item_name(node_name) or S("Unlabeled block")),
		S("Dimension: Overworld"), S("Biomes: registered overworld biome entries for high, middle and deep features (@1, @2 and @3).",
			tostring(active_overworld_biome_count("moreores:" .. mineral .. "_high_placed")),
			tostring(active_overworld_biome_count("moreores:" .. mineral .. "_placed")),
			tostring(active_overworld_biome_count("moreores:" .. mineral .. "_deep_placed"))),
		mining_guide_line(node_name)}
	if moreores_key then
		lines[#lines + 1] = mcl_vars.enable_mcl_levelgen and S("Generation path: Mineclonia levelgen placed features.")
			or S("Generation path: engine ore fallback; Mineclonia levelgen is disabled.")
		for _, band_line in ipairs(moreores_band_lines(moreores_key)) do lines[#lines + 1] = band_line end
	else
		local generation = adamantine and adamantine.generation or {}
		local levelgen_active = generation.levelgen_enabled and (generation.levelgen_features_registered or 0) > 0
		lines[#lines + 1] = levelgen_active and S("Generation path: Mineclonia levelgen placed features.")
			or S("Generation path: engine register_ore fallback; Mineclonia levelgen is disabled.")
		local y_min = tonumber(generation.y_min or mcl_vars.mg_overworld_min or -128)
		local y_max = tonumber(generation.y_max) or -64
		lines[#lines + 1] = S("Depth: Y @1 to @2, taken from the active Adamantine generation bounds.", tostring(math.min(y_min, y_max)), tostring(math.max(y_min, y_max)))
		if levelgen_active then
			lines[#lines + 1] = S("Frequency: each stone/deepslate feature has a 1-in-@1 filter per eligible chunk; cluster size @2.", tostring(generation.rarity_filter or 4), tostring(generation.cluster_size or 2))
		else
			lines[#lines + 1] = S("Fallback frequency: scarcity @1 nodes, @2 ores per cluster, cluster size @3.", tostring(generation.legacy_scarcity or 13824), tostring(generation.legacy_ores_per_cluster or 2), tostring(generation.cluster_size or 2))
		end
		local stone_count = active_overworld_biome_count("adamantine:ore_stone_placed")
		local deep_count = active_overworld_biome_count("adamantine:ore_deepslate_placed")
		lines[#lines + 1] = S("Biomes: registered overworld entries; @1 stone and @2 deepslate levelgen features.", tostring(stone_count), tostring(deep_count))
	end
	local drop = mineral_drop_item(def)
	local drop_name = drop and localized_item_name(drop) or S("Unknown registered drop")
	lines[#lines + 1] = S("Mined resource: @1.", drop_name)
	local recipe = drop and smelt_recipes[drop]
	if recipe then
		local output_name = localized_item_name(recipe.output)
		if output_name then lines[#lines + 1] = S("Processing: @1 → @2 in a Mineclonia furnace or Alloy Melter.", drop_name, output_name) end
	elseif drop and core.get_craft_result then
		local result = core.get_craft_result({method = "cooking", width = 1, items = {ItemStack(drop)}})
		if result and result.item and not result.item:is_empty() then
			local output_name = localized_item_name(result.item:get_name())
			if output_name then lines[#lines + 1] = S("Processing: @1 → @2 in a Mineclonia furnace.", drop_name, output_name) end
		end
	end
	lines[#lines + 1] = S("Main uses: @1", get_material_uses(mineral, ingot))
	lines[#lines + 1] = S("Only newly generated terrain can contain new deposits; existing map blocks are unchanged.")
	return table.concat(lines, "\n")
end

if doc and doc.add_category and doc.add_entry then
	local category_id = "everforge_minerals"
	doc.add_category(category_id, {
		name = S("Minerals"), description = S("Generation, mining, processing and uses for Everforge metals."),
		build_formspec = function(data, playername)
			local body = doc.entry_builders.text_and_gallery({text = data.text, images = {{imagetype = "item", image = data.item}}}, playername)
			-- Keep doc's native gallery/layout, but tint the text panel to the
			-- same warm dark palette used by Everforge's RPG and forge forms.
			body = body:gsub("#000000%]", "#17191C]")
			return "style_type[textarea;textcolor=#F2E8D9]" .. body
				.. ("box[%s,%s;0.035,%s;#C27A4A]"):format(doc.FORMSPEC.ENTRY_START_X - 0.175, doc.FORMSPEC.ENTRY_START_Y, doc.FORMSPEC.ENTRY_HEIGHT - 1)
		end,
	})
	local entries = {
		{key = "tin", mineral = "tin", label = S("Tin"), node = "moreores:mineral_tin", ingot = "moreores:tin_ingot", config = "tin"},
		{key = "silver", mineral = "silver", label = S("Silver"), node = "moreores:mineral_silver", ingot = "moreores:silver_ingot", config = "silver"},
		{key = "mithril", mineral = "mithril", label = S("Mithril"), node = "moreores:mineral_mithril", ingot = "moreores:mithril_ingot", config = "mithril"},
		{key = "adamantine", mineral = "adamantine", label = S("Adamantine"), node = "adamantine:ore", ingot = "adamantine:ingot"},
	}
	for _, entry in ipairs(entries) do
		local text = mineral_entry_text(entry.mineral, entry.label, entry.node, entry.ingot, entry.config)
		if text then doc.add_entry(category_id, entry.key, {name = entry.label, data = {text = text, item = entry.node}}) end
	end
	core.register_chatcommand("everforge_minerals", {
		params = "", description = S("Open the in-game mineral generation and mining guide."),
		func = function(name)
			if doc.get_entry_count(category_id) == 0 then return false, S("No mineral entries are available.") end
			local player = core.get_player_by_name(name)
			if player then suppress_waila_for_player(player, "doc:") end
			doc.show_category(name, category_id)
			return true
		end,
	})
end

-- ---------------------------------------------------------------------------
-- Persistent dungeon markers, procedural structures, loot and enemy spawns.
-- The generator uses mcl_levelgen's feature API, not legacy register_ore.
-- ---------------------------------------------------------------------------
core.register_craftitem("everforge:relic", {description = S("Dungeon Relic"), inventory_image = "default_gold_ingot.png^[colorize:#6d45ba:110", stack_max = 16})
local function cache_is_protected(pos, player)
	if player and player:is_player() and core.is_protected(pos, player:get_player_name()) then
		core.record_protection_violation(pos, player:get_player_name())
		return true
	end
	return false
end

local function build_reward_cache_formspec(pos)
	local node_inv = ("nodemeta:%s,%s,%s"):format(pos.x, pos.y, pos.z)
	return table.concat({
		"formspec_version[7]size[11.75,11.75]",
		forge_theme(11.75, 11.75),
		"label[0.5,0.4;" .. core.formspec_escape(core.colorize("#E8B17D", S("Dungeon Reward Cache"))) .. "]",
		forge_slots(3.5, 1, 4, 4),
		("list[%s;main;3.5,1;4,4;]"):format(node_inv),
		"label[0.375,6.1;" .. core.formspec_escape(S("Inventory")) .. "]",
		forge_slots(0.375, 6.45, 9, 3),
		"list[current_player;main;0.375,6.45;9,3;9]",
		forge_slots(0.375, 10.4, 9, 1),
		"list[current_player;main;0.375,10.4;9,1;]",
		("listring[%s;main]"):format(node_inv),
		"listring[current_player;main]",
	})
end

core.register_node("everforge:reward_cache", {
	description = S("Sealed Dungeon Cache"), tiles = {"mcl_chests_normal.png^default_gold_ingot.png"},
	groups = {choppy = 2, material_wood = 1}, is_ground_content = false, paramtype2 = "facedir",
	_on_ignite = false,
	on_rightclick = function(pos, _, clicker)
		if not clicker or not clicker:is_player() or cache_is_protected(pos, clicker) then return end
		local meta = core.get_meta(pos)
		local formname = "everforge:reward_cache"
		suppress_waila_for_player(clicker, formname)
		core.show_formspec(clicker:get_player_name(), formname,
			meta:get_string("formspec") ~= "" and meta:get_string("formspec") or build_reward_cache_formspec(pos))
	end,
	allow_metadata_inventory_put = function() return 0 end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		if listname ~= "main" or cache_is_protected(pos, player) then return 0 end
		return stack:get_count()
	end,
	allow_metadata_inventory_move = function() return 0 end,
	can_dig = function(pos, player)
		return not cache_is_protected(pos, player) and core.get_meta(pos):get_inventory():is_empty("main")
	end,
})
core.register_node("everforge:dungeon_spawner", {
	description = S("Ancient Dungeon Spawner"), tiles = {"default_stone_brick.png^[colorize:#332849:120"},
	groups = {cracky = 2, not_in_creative_inventory = 1}, is_ground_content = false, drop = "", walkable = false,
})

local spawner_lbm = "everforge:activate_dungeon_spawners"
core.register_lbm({
	label = S("Activate Everforge dungeon spawners"), name = spawner_lbm,
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
	label = S("Initialize Everforge dungeon caches"), name = "everforge:initialize_dungeon_caches",
	nodenames = {"everforge:reward_cache"}, run_at_every_load = true,
	action = function(pos)
		local meta = core.get_meta(pos)
		meta:set_string("infotext", S("Sealed Dungeon Cache"))
		meta:set_string("formspec", build_reward_cache_formspec(pos))
		if meta:get_int("everforge:initialized") == 1 then return end
		local inv = meta:get_inventory(); inv:set_size("main", 16)
		inv:add_item("main", ItemStack("everforge:relic 1"))
		if core.registered_items["moreores:mithril_ingot"] then inv:add_item("main", ItemStack("moreores:mithril_ingot 2")) end
		if core.registered_items["adamantine:ingot"] then inv:add_item("main", ItemStack("adamantine:ingot")) end
		inv:add_item("main", ItemStack("mcl_core:gold_ingot 3"))
		meta:set_int("everforge:initialized", 1)
	end,
})

local mob_names = {"mobs_mc:skeleton", "mobs_mc:stray", "mobs_mc:zombie"}
local function mob_scale_context(ent, pos)
	if not ent or not pos or not ent.name or not ent.name:match("^mobs_mc:") or ent.type ~= "monster"
		or mcl_worlds.pos_to_dimension(pos) ~= "overworld" then
		return nil
	end
	local depth = math.max(0, -pos.y - 32)
	local zone = math.floor(depth / 48)
	local in_dungeon = ent.everforge_dungeon == true
	local hp_multiplier = math.min(2.2, 1 + zone * 0.12)
	if in_dungeon then hp_multiplier = math.min(2.5, hp_multiplier + 0.35) end
	local damage_multiplier = 1 + zone * 0.08 + (in_dungeon and 0.2 or 0)
	return {depth = depth, zone = zone, in_dungeon = in_dungeon,
		hp_multiplier = hp_multiplier, damage_multiplier = damage_multiplier}
end

core.register_chatcommand("everforge_mobdiag", {
	params = "",
	description = S("Show health, configured melee damage, depth and scaling for the mob you point at."),
	privs = {server = true},
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then return false, S("You must be online to use this command.") end
		local pointed = mcl_util.get_pointed_thing(player, true, false)
		if not pointed or pointed.type ~= "object" or not pointed.ref then
			return false, S("Point at a mob and run this command again.")
		end
		local obj = pointed.ref
		local ent = obj:get_luaentity()
		local pos = obj:get_pos()
		if not ent or not ent.name or not ent.name:match("^mobs_mc:") or ent.type ~= "monster" or not pos then
			return false, S("The pointed object is not a Mineclonia monster.")
		end
		local context = mob_scale_context(ent, pos)
		local health = ent.health or obj:get_hp()
		local health_max = ent.hp_max or obj:get_properties().hp_max or 0
		local damage = type(ent.damage) == "number" and ent.damage or nil
		local hp_multiplier, damage_multiplier, scale_state
		if ent.everforge_scaled then
			hp_multiplier = ent.everforge_hp_multiplier
			damage_multiplier = ent.everforge_damage_multiplier
			if hp_multiplier then
				scale_state = S("Applied (stored)")
			else
				scale_state = S("Already scaled by a version that did not record its multipliers")
			end
		elseif context then
			hp_multiplier, damage_multiplier = context.hp_multiplier, context.damage_multiplier
			scale_state = S("Eligible; scaling applies when a player is within 34 nodes")
		else
			hp_multiplier, damage_multiplier = 1, 1
			scale_state = S("Excluded: scaling only affects native Overworld monsters")
		end
		local hp_factor_text = hp_multiplier and string.format("%.2f", hp_multiplier) or S("unknown")
		local damage_factor_text = damage_multiplier and string.format("%.2f", damage_multiplier) or S("unknown")
		local damage_text = damage and tostring(damage) or S("custom / not exposed")
		local message = S("Mob: @1; health: @2 / @3; configured melee damage: @4; Y: @5; depth below Y=-32: @6; health multiplier: @7x; damage multiplier: @8x; @9",
			ent.name, tostring(health), tostring(health_max), damage_text, tostring(math.floor(pos.y)),
			context and tostring(math.floor(context.depth)) or "—", hp_factor_text, damage_factor_text, scale_state)
		core.chat_send_player(name, message)
		return true
	end,
})

core.register_globalstep(function(dtime)
	-- Scaling is applied once per native Mineclonia monster in a small radius
	-- around players, and only in the Overworld. Values remain depth-based.
	local now = core.get_us_time() / 1000000
	if now - (everforge._last_scale or 0) < 4 then return end
	everforge._last_scale = now
	for _, player in ipairs(core.get_connected_players()) do
		local ppos = player:get_pos()
		for _, obj in ipairs(core.get_objects_inside_radius(ppos, 34)) do
			local ent = obj:get_luaentity()
			local pos = obj:get_pos()
			local context = mob_scale_context(ent, pos)
			if context and not ent.everforge_scaled then
				local hp = ent.hp_max or 20
				ent.everforge_base_hp_max = hp
				ent.everforge_hp_multiplier = context.hp_multiplier
				ent.hp_max = math.floor(hp * context.hp_multiplier)
				obj:set_properties({hp_max = ent.hp_max})
				obj:set_hp(ent.hp_max)
				if type(ent.damage) == "number" then
					ent.everforge_base_damage = ent.damage
					ent.everforge_damage_multiplier = context.damage_multiplier
					ent.damage = math.ceil(ent.damage * context.damage_multiplier)
				end
				ent.everforge_scaled = true
			end
		end
	end
end)

core.register_abm({
	label = S("Everforge dungeon spawn pulse"), nodenames = {"everforge:dungeon_spawner"},
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

-- Load the isolated Extra Structures 1.4.0 to Mineclonia levelgen port.
dofile(core.get_modpath(modname) .. "/extra_structures.lua")

local function count_group_nodes(group)
	local count = 0
	for _, def in pairs(core.registered_nodes) do
		if def.groups and (def.groups[group] or 0) > 0 then count = count + 1 end
	end
	return count
end

core.register_chatcommand("everforge_mapgen_status", {
	params = "",
	description = S("Show registered Everforge and Adamantine generation paths (server only)."),
	privs = {server = true},
	func = function(name)
		local generation = adamantine and adamantine.generation or {}
		local levelgen_enabled = mcl_vars.enable_mcl_levelgen == true
		local levelgen_features = generation.levelgen_features_registered or 0
		local ore_path = levelgen_enabled and levelgen_features > 0 and "Mineclonia levelgen"
			or (not levelgen_enabled and (generation.legacy_ore_definitions or 0) > 0 and "legacy register_ore fallback")
			or "ERROR: no Adamantine generation path registered"
		local lines = {
			"[Everforge mapgen] levelgen=" .. tostring(levelgen_enabled)
				.. "; Adamantine path=" .. ore_path
				.. "; legacy ore definitions=" .. tostring(generation.legacy_ore_definitions or 0)
				.. "; levelgen placed features=" .. tostring(levelgen_features) .. ".",
			"[Adamantine] Y=" .. tostring(generation.y_min or "?") .. ".." .. tostring(generation.y_max or "?")
				.. "; stone targets=" .. tostring(count_group_nodes("stone_ore_target"))
				.. "; deepslate targets=" .. tostring(count_group_nodes("deepslate_ore_target"))
				.. "; biome entries stone=" .. tostring(active_overworld_biome_count("adamantine:ore_stone_placed"))
				.. ", deepslate=" .. tostring(active_overworld_biome_count("adamantine:ore_deepslate_placed")) .. ".",
			"[Adamantine rates] levelgen filter=1/" .. tostring(generation.rarity_filter or "?")
				.. " per eligible chunk per feature; legacy scarcity=" .. tostring(generation.legacy_scarcity or "?")
				.. " nodes, ores/cluster=" .. tostring(generation.legacy_ores_per_cluster or "?")
				.. "; only new mapblocks generate ore.",
			"[Everforge structures] levelgen=" .. tostring(levelgen_enabled)
				.. "; registration=world_features.lua in levelgen environments; server biome tables are not placement counters."
				.. " Placement=1/256 candidate per eligible chunk; floor must be dirt, grass, snow or snow block.",
			"[Everforge structures] no forced generation or world edits are performed by this diagnostic.",
		}
		for _, line in ipairs(lines) do core.chat_send_player(name, line) end
		return true, "Generation registration status sent to chat."
	end,
})

-- Run only on explicit administrator request; no global translation wrappers.
dofile(core.get_modpath(modname) .. "/ui_probe.lua")(function(player)
	return waila_enabled(player), waila_suppressed[player:get_player_name()] ~= nil
end)

dofile(core.get_modpath(modname) .. "/start_region.lua")
