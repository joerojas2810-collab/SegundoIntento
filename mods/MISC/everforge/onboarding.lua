-- SPDX-License-Identifier: GPL-3.0-or-later
-- Welcome cards and a permanent guide, built only with native Luanti formspecs
-- and the game's existing help, recipe-book, and achievement interfaces.
local S = core.get_translator(core.get_current_modname())
local unpack = table.unpack or unpack

local FORM_HUB = "everforge:guide"
local FORM_HELP = "everforge:guide_help"
local FORM_INTRO = "everforge:introduction"
local FORM_STEPS = "everforge:first_steps"
local META_AUTO_SEEN = "everforge:onboarding:auto_intro_seen"
local META_INTRO_DONE = "everforge:onboarding:intro_done"
local META_STEPS_OFFERED = "everforge:onboarding:first_steps_offer_seen"
local active_cards = {}

local introductions = {
	{
		title = S("A World Without a Written Destination."),
		text = S("There is no prescribed route. Set your own pace: explore, build, mine, or let the landscape suggest a direction. This story is yours."),
		icon = "everforge_part_handle.png",
	},
	{
		title = S("What You Do Defines You."),
		text = S("Mining, forging, combat, exploration, and crafting each leave a different mark. What you choose to practice shapes your progress; there is no single way forward."),
		icon = "everforge_part_head.png",
	},
	{
		title = S("Forge Your Own Path."),
		text = S("No permanent class locks you into a role. Try skills from different disciplines and grow your Mastery at your own pace."),
		icon = "everforge_part_binding.png",
	},
	{
		title = S("Not Everything Is in Sight."),
		text = S("There is more to discover than what you see at first, but nothing demands that you go in a particular direction. Explore when you are ready and let curiosity guide you."),
		icon = "everforge_part_axe_head.png",
	},
	{
		title = S("The World Continues With You."),
		text = S("Your journey does not end with this welcome. Build, change, and inhabit the world around you. When you close this card, the wider world is yours to explore."),
		icon = "everforge_part_shovel_head.png",
	},
}

local first_steps = {
	{
		title = S("Your First Tools"),
		text = S("Collect logs. Open your inventory, place logs in the crafting grid, and take the planks. Use them to make a crafting table; the recipe book (book icon) shows how to make a wooden axe."),
		icon = "mcl_crafting_table_inv_fill.png",
	},
	{
		title = S("Learn by Doing"),
		text = S("Try mining, forging, combat, exploration, or crafting. Use /everforge to see the five disciplines and available skills. There is no required order."),
		icon = "everforge_part_head.png",
	},
	{
		title = S("Prepare Your Shelter"),
		text = S("Build a shelter that suits you. Gather food and keep an eye on your health and hunger as you settle in."),
		icon = "default_furnace_fire_bg.png",
	},
	{
		title = S("Discover the Unknown"),
		text = S("Head out whenever you like. Take in the landscape and choose your own direction; exploration has no required objectives."),
		icon = "everforge_part_handle.png",
	},
	{
		title = S("Know Your Tools"),
		text = S("To return to this guide without typing a command, open your inventory (I), select the Everforge tab, and choose \"Everforge Guide\". Or press T to open chat, type /everforge, and press Enter. I and T are Luanti's default keys; you can change them in Settings > Change keys."),
		icon = "doc_button_icon_lores.png",
	},
}

local function mark_auto_handled(player)
	player:get_meta():set_int(META_AUTO_SEEN, 1)
end

local function mark_manual_open(player)
	mark_auto_handled(player)
end

local function theme(width, height)
	return table.concat({
		"bgcolor[#08090BEF;true]",
		"background9[0,0;" .. width .. "," .. height .. ";everforge_ui_panel.png;false;8]",
		"style_type[label;textcolor=#F2E8D9]",
		"style_type[hypertext;textcolor=#F2E8D9]",
		"style_type[button,button_exit;textcolor=#FFF1DC;border=false;bgimg=everforge_ui_button.png;bgimg_pressed=everforge_ui_button_pressed.png;bgimg_middle=4;font=bold]",
		"style_type[button:hovered,button_exit:hovered;bgimg=everforge_ui_button_hover.png]",
	})
end

local function button(x, y, width, height, field, label)
	return ("button[%s,%s;%s,%s;%s;%s]"):format(x, y, width, height, field, core.formspec_escape(label))
end

local function button_exit(x, y, width, height, field, label)
	return ("button_exit[%s,%s;%s,%s;%s;%s]"):format(x, y, width, height, field, core.formspec_escape(label))
end

local function escape_hypertext(text)
	return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\n", "<br>")
end

local function card_text(text)
	-- In Luanti hypertext, <global> sets global styles and is not a container;
	-- closing it is invalid and the client renders </global> as literal text.
	-- Keep it open for this element, close only the nested style, and escape
	-- translated copy before formspec delimiters are escaped.
	return core.formspec_escape("<global valign=middle><style color=#F2E8D9 size=22>" .. escape_hypertext(text) .. "</style>")
end

local function subtitle_text(text)
	return core.formspec_escape("<style color=#B9AEA3 size=13>" .. escape_hypertext(text) .. "</style>")
end

local function show_form(player, formname, formspec)
	if everforge._suppress_waila then everforge._suppress_waila(player, formname) end
	core.show_formspec(player:get_player_name(), formname, formspec)
end

local function release_onboarding_waila(player)
	if not everforge._restore_waila then return end
	for _, formname in ipairs({FORM_HUB, FORM_HELP, FORM_INTRO, FORM_STEPS, "everforge:progression"}) do
		everforge._restore_waila(player, formname)
	end
end

local function show_hub(player, manual)
	if manual ~= false then mark_manual_open(player) end
	active_cards[player:get_player_name()] = nil
	local fs = {
		theme(12, 7.5),
		"box[0.35,0.25;11.3,0.75;#242325]",
		"box[0.35,0.25;0.06,0.75;#C27A4A]",
		"label[0.72,0.49;" .. core.formspec_escape(core.colorize("#E8B17D", S("Everforge — Guide and Path"))) .. "]",
		"label[0.72,1.12;" .. core.formspec_escape(S("A world to shape at your own pace. Choose a guide or return to your progress.")) .. "]",
	}
	local tiles = {
		{0.55, 1.7, "intro", S("Introduction"), S("Welcome to Everforge"), "everforge_part_handle.png"},
		{4.35, 1.7, "first_steps", S("First Steps"), S("Suggestions, never missions"), "mcl_crafting_table_inv_fill.png"},
		{8.15, 1.7, "progression", S("Progress"), S("Five disciplines and skills"), "everforge_part_head.png"},
		{0.55, 3.25, "help", S("Help"), S("Controls and commands"), "doc_button_icon_lores.png"},
		{4.35, 3.25, "recipes", S("Recipes"), S("Recipe book"), "craftguide_book.png"},
		{8.15, 3.25, "achievements", S("Achievements"), S("Game achievements"), "mcl_achievements_button.png"},
	}
	for _, tile in ipairs(tiles) do
		local x, y, field, title, subtitle, icon = unpack(tile)
		fs[#fs + 1] = ("box[%s,%s;3.3,1.3;#111214EE]"):format(x, y)
		fs[#fs + 1] = ("image[%s,%s;0.8,0.8;%s]"):format(x + 0.16, y + 0.2, icon)
		fs[#fs + 1] = button(x + 1.0, y + 0.15, 2.15, 0.5, field, title)
		fs[#fs + 1] = ("hypertext[%s,%s;2.15,0.48;tile_subtitle;%s]"):format(x + 1.0, y + 0.73, subtitle_text(subtitle))
	end
	fs[#fs + 1] = button_exit(0.55, 6.55, 2.0, 0.55, "close", S("Close"))
	show_form(player, FORM_HUB, "formspec_version[7]size[12,7.5]" .. table.concat(fs))
end

local function show_help(player, manual)
	if manual ~= false then mark_manual_open(player) end
	local fs = {
		theme(12, 6.2),
		"box[0.35,0.25;11.3,0.75;#242325]",
		"box[0.35,0.25;0.06,0.75;#C27A4A]",
		"label[0.72,0.49;" .. core.formspec_escape(core.colorize("#E8B17D", S("Controls and Commands"))) .. "]",
		"label[0.72,1.25;" .. core.formspec_escape(S("Open the available help pages. Controls can be changed in the game settings.")) .. "]",
		button(0.8, 2.1, 4.5, 0.8, "controls", S("Controls")),
		button(6.7, 2.1, 4.5, 0.8, "commands", S("Commands")),
		button(0.8, 3.3, 4.5, 0.8, "all_help", S("Complete Help")),
		button(0.8, 4.85, 2.0, 0.55, "back", S("Back")),
		button_exit(9.2, 4.85, 2.0, 0.55, "close", S("Close")),
	}
	show_form(player, FORM_HELP, "formspec_version[7]size[12,6.2]" .. table.concat(fs))
end

local function show_cards(player, kind, page, manual)
	local is_intro = kind == "intro"
	local cards = is_intro and introductions or first_steps
	page = math.max(1, math.min(#cards, page or 1))
	if manual ~= false then mark_manual_open(player) end
	local name = player:get_player_name()
	active_cards[name] = {kind = kind, page = page}
	local card = cards[page]
	local title = is_intro and S("Everforge — Welcome") or S("Everforge — First Steps")
	local fs = {
		theme(12, 7.5),
		"box[0.35,0.25;11.3,0.8;#242325]",
		"box[0.35,0.25;0.06,0.8;#C27A4A]",
		"label[0.72,0.52;" .. core.formspec_escape(core.colorize("#E8B17D", title)) .. "]",
		"label[0.72,1.18;" .. core.formspec_escape(S("Card @1 of @2", tostring(page), tostring(#cards))) .. "]",
		"label[1.0,1.63;" .. core.formspec_escape(core.colorize("#E8B17D", card.title)) .. "]",
		("image[9.75,1.45;1.0,1.0;%s]"):format(card.icon),
		"box[0.7,2.05;10.6,3.15;#111214EE]",
		"hypertext[1.0,2.35;9.95,2.55;card_text;" .. card_text(card.text) .. "]",
	}
	if is_intro and page == #cards then
		fs[#fs + 1] = "label[0.78,5.42;" .. core.formspec_escape(core.colorize("#E8B17D", S("Would you like to see a few first steps?"))) .. "]"
		fs[#fs + 1] = button(7.0, 5.3, 3.25, 0.5, "steps_now", S("Yes, show me"))
	end
	fs[#fs + 1] = button(0.55, 6.45, 1.85, 0.55, "previous", S("Previous"))
	local next_label = page == #cards and (is_intro and S("Finish and Explore") or S("Finish")) or S("Next")
	fs[#fs + 1] = button(2.55, 6.45, 2.25, 0.55, "next", next_label)
	fs[#fs + 1] = ("button_exit[7.45,6.45;1.8,0.55;skip;%s]"):format(core.formspec_escape(S("Skip")))
	fs[#fs + 1] = ("button_exit[9.55,6.45;1.8,0.55;close;%s]"):format(core.formspec_escape(S("Close")))
	local formname = is_intro and FORM_INTRO or FORM_STEPS
	show_form(player, formname, "formspec_version[7]size[12,7.5]" .. table.concat(fs))
end

local function tell_steps_offer(player)
	local meta = player:get_meta()
	if meta:get_int(META_STEPS_OFFERED) == 1 then return end
	meta:set_int(META_STEPS_OFFERED, 1)
	core.chat_send_player(player:get_player_name(), S("Would you like to see a few first steps? You can open them any time with /everforge first_steps; the world is ready to explore."))
end

local function end_intro(player, offer)
	local meta = player:get_meta()
	local name = player:get_player_name()
	meta:set_int(META_AUTO_SEEN, 1)
	meta:set_int(META_INTRO_DONE, 1)
	active_cards[name] = nil
	if offer then
		core.after(0.1, function()
			local current = core.get_player_by_name(name)
			if current then tell_steps_offer(current) end
		end)
	end
end

local function show_doc_entry(player, category, entry)
	local name = player:get_player_name()
	local available = doc and doc.show_entry and doc.data and doc.data.categories
	local cat = available and doc.data.categories[category]
	if cat and cat.entries and cat.entries[entry] then
		release_onboarding_waila(player)
		if everforge._suppress_waila then everforge._suppress_waila(player, "doc:") end
		doc.show_entry(name, category, entry)
		return true
	end
	if doc and doc.show_doc then
		release_onboarding_waila(player)
		if everforge._suppress_waila then everforge._suppress_waila(player, "doc:") end
		doc.show_doc(name)
		return true
	end
	core.chat_send_player(name, S("The help pages are unavailable right now."))
	return false
end

local function open_recipes(player)
	mark_manual_open(player)
	release_onboarding_waila(player)
	if mcl_craftguide and type(mcl_craftguide.show) == "function" then
		if everforge._suppress_waila then everforge._suppress_waila(player, "mcl_craftguide") end
		mcl_craftguide.show(player:get_player_name())
		return true
	end
	core.chat_send_player(player:get_player_name(), S("The recipe book is unavailable right now."))
	return false
end

local function open_achievements(player)
	mark_manual_open(player)
	release_onboarding_waila(player)
	local has_mcl_achievements = core.get_modpath and core.get_modpath("mcl_achievements")
	if has_mcl_achievements and awards and type(awards.show_to) == "function" then
		-- awards consumes its own close callback; leave WAILA untouched so its
		-- suppression state cannot outlive the native achievements form.
		awards.show_to(player:get_player_name(), player:get_player_name(), nil, false)
		return true
	end
	core.chat_send_player(player:get_player_name(), S("The achievements screen is unavailable in this world."))
	return false
end

local function show_progression(player)
	mark_manual_open(player)
	if everforge.open_progression then
		everforge.open_progression(player)
		return true
	end
	core.chat_send_player(player:get_player_name(), S("Everforge progression is not available right now."))
	return false
end

local function open_controls(player)
	mark_manual_open(player)
	return show_doc_entry(player, "basics", "controls")
end

local function open_commands(player)
	mark_manual_open(player)
	return show_doc_entry(player, "advanced", "commands")
end

local function handle_card_fields(player, formname, fields)
	local name = player:get_player_name()
	local session = active_cards[name]
	if not session then return true end
	local is_intro = session.kind == "intro"
	local cards = is_intro and introductions or first_steps

	if fields.steps_now and is_intro then
		player:get_meta():set_int(META_STEPS_OFFERED, 1)
		end_intro(player, false)
		show_cards(player, "first_steps", 1, false)
		return true
	end
	if fields.next then
		if session.page < #cards then
			show_cards(player, session.kind, session.page + 1, false)
		elseif is_intro then
			end_intro(player, true)
			if everforge._restore_waila then everforge._restore_waila(player, formname) end
			core.close_formspec(name, formname)
		else
			active_cards[name] = nil
			if everforge._restore_waila then everforge._restore_waila(player, formname) end
			core.close_formspec(name, formname)
		end
		return true
	end
	if fields.previous then
		show_cards(player, session.kind, session.page - 1, false)
		return true
	end
	if fields.skip then
		active_cards[name] = nil
		if is_intro then end_intro(player, true) end
		if everforge._restore_waila then everforge._restore_waila(player, formname) end
		return true
	end
	if fields.close or fields.quit then
		active_cards[name] = nil
		-- A dismissed first-time card is not reopened automatically. It remains
		-- available from /everforge, without recording any gameplay objective.
		mark_auto_handled(player)
		if everforge._restore_waila then everforge._restore_waila(player, formname) end
		return true
	end
	return true
end

core.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if formname == FORM_INTRO or formname == FORM_STEPS then
		return handle_card_fields(player, formname, fields)
	elseif formname == FORM_HUB then
		if fields.intro then show_cards(player, "intro", 1, false)
		elseif fields.first_steps then show_cards(player, "first_steps", 1, false)
		elseif fields.progression then show_progression(player)
		elseif fields.help then show_help(player, false)
		elseif fields.recipes then open_recipes(player)
		elseif fields.achievements then open_achievements(player)
		end
		return true
	elseif formname == FORM_HELP then
		if fields.controls then open_controls(player)
		elseif fields.commands then open_commands(player)
		elseif fields.all_help then
			mark_manual_open(player)
			release_onboarding_waila(player)
			if doc and doc.show_doc then
				if everforge._suppress_waila then everforge._suppress_waila(player, "doc:") end
				doc.show_doc(name)
			else
				core.chat_send_player(name, S("The help pages are unavailable right now."))
			end
		elseif fields.back then show_hub(player, false) end
		return true
	end
	return false
end)

core.register_chatcommand("everforge", {
	params = "[guide|intro|first_steps|help|controls|commands|recipes|achievements|progression]",
	description = S("Open Everforge's guide, progression, or a reference."),
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then return false, S("You must be online to use this command.") end
		local action = (param or ""):match("^%s*(.-)%s*$"):lower()
		if action == "" or action == "guide" then show_hub(player)
		elseif action == "intro" or action == "introduction" then show_cards(player, "intro", 1)
		elseif action == "first_steps" or action == "first-steps" then show_cards(player, "first_steps", 1)
		elseif action == "help" then show_help(player)
		elseif action == "controls" then open_controls(player)
		elseif action == "commands" then open_commands(player)
		elseif action == "recipes" then open_recipes(player)
		elseif action == "achievements" or action == "advancements" then open_achievements(player)
		elseif action == "progression" or action == "progress" then show_progression(player)
		else
			show_hub(player)
			return true, S("Unknown section; showing the Everforge guide.")
		end
		return true
	end,
})

local function player_world_ready(player)
	if mcl_biome_dispatch and type(mcl_biome_dispatch.in_limbo) == "function" then
		local ok, in_limbo = pcall(mcl_biome_dispatch.in_limbo, player)
		if ok and in_limbo then return false end
	end
	local pos = player:get_pos()
	if not pos then return false end
	local x, y, z = math.floor(pos.x + 0.5), math.floor(pos.y), math.floor(pos.z + 0.5)
	local feet = core.get_node_or_nil({x = x, y = y, z = z})
	local floor = core.get_node_or_nil({x = x, y = y - 1, z = z})
	return feet and floor and feet.name ~= "ignore" and floor.name ~= "ignore"
end

local function start_region_state()
	local start_region = everforge.start_region
	if not start_region or type(start_region.get) ~= "function" then return nil, false end
	local ok, info = pcall(start_region.get)
	if not ok or type(info) ~= "table" then return nil, true end
	return info.state, true
end

local function try_auto_intro(name, attempt)
	local player = core.get_player_by_name(name)
	if not player or player:get_meta():get_int(META_AUTO_SEEN) == 1 then return end
	local state, has_region = start_region_state()
	if has_region then
		if state == "ready" and player_world_ready(player) then
			player:get_meta():set_int(META_AUTO_SEEN, 1)
			show_cards(player, "intro", 1, false)
			return
		elseif state ~= "building" then
			return
		end
	elseif player_world_ready(player) then
		-- Older worlds have no newly generated start region. Wait until the
		-- player's spawn nodes are emerged, then offer the welcome once.
		player:get_meta():set_int(META_AUTO_SEEN, 1)
		show_cards(player, "intro", 1, false)
		return
	end
	if attempt < 240 then
		core.after(0.5, function() try_auto_intro(name, attempt + 1) end)
	end
end

core.register_on_joinplayer(function(player)
	if player:get_meta():get_int(META_AUTO_SEEN) == 1 then return end
	local name = player:get_player_name()
	core.after(1, function() try_auto_intro(name, 0) end)
end)

everforge.onboarding = {
	show_hub = function(player) show_hub(player, false) end,
	show_intro = function(player) show_cards(player, "intro", 1, false) end,
	show_first_steps = function(player) show_cards(player, "first_steps", 1, false) end,
	show_help = function(player) show_help(player, false) end,
	open_controls = open_controls,
	open_commands = open_commands,
	open_recipes = open_recipes,
	open_achievements = open_achievements,
	mark_manual_open = mark_manual_open,
}
