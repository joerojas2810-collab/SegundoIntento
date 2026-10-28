-- SPDX-License-Identifier: GPL-3.0-or-later
-- A short, beginner-facing index over Mineclonia's live recipe registry.
-- It never registers or changes a recipe; the complete catalog remains in
-- mcl_craftguide.
local S = core.get_translator("everforge")
local FORM = "everforge:basic_crafting"
local CATEGORIES = {"materials", "tools", "survival"}
local category_labels = {
	materials = S("First Materials"),
	tools = S("Tools and Weapons"),
	survival = S("Survival"),
}

local group_display = {
	["group:wood"] = {label = S("Compatible wood"), icon = "mcl_trees:wood_oak"},
	["group:tree"] = {label = S("Any log"), icon = "mcl_trees:tree_oak"},
	["group:cobble"] = {label = S("Compatible stone"), icon = "mcl_core:cobble"},
	["group:coal"] = {label = S("Compatible coal"), icon = "mcl_core:coal_lump"},
	["group:bed"] = {label = S("Any bed"), icon = "mcl_beds:bed_red_bottom"},
}

local entries = {
	materials = {
		{key = "logs", label = S("Logs"), item = "mcl_trees:tree_oak",
			purpose = S("Tree trunks are the first raw material for wooden building and crafting."),
			obtain = S("Break a tree trunk; it is gathered from the world and has no crafting recipe."),
			where = S("Gathered from the world; no crafting grid."), no_recipe = true},
		{key = "planks", label = S("Planks"), item = "mcl_trees:wood_oak", variant_family = "planks",
			purpose = S("Planks are a common building material and a base ingredient for early tools and stations."),
			obtain = S("Craft a log; the output count appears in the registered recipe. Each tree type has its matching plank output.")},
		{key = "sticks", label = S("Sticks"), item = "mcl_core:stick",
			purpose = S("Sticks are handles and components used by tools, weapons and torches."),
			obtain = S("Use the registered wood recipe, or another recipe shown here when available." )},
		{key = "table", label = S("Crafting Table"), item = "mcl_crafting_table:crafting_table",
			purpose = S("A crafting table opens the full 3×3 crafting grid."),
			obtain = S("Place four compatible wood items in a 2×2 square."),
			use = S("Place it in the world and right-click it to open the 3×3 grid.")},
	},
	tools = {
		{key = "pick", label = S("Pickaxe"), tool = "pick", item = "mcl_tools:pick_wood",
			purpose = S("A pickaxe mines stone and other hard blocks; the suitable material depends on the block."),
			obtain = S("Place three pieces of the selected tool material across the top row, then two sticks below the center.")},
		{key = "axe", label = S("Axe"), tool = "axe", item = "mcl_tools:axe_wood",
			purpose = S("An axe is useful for tree trunks, wooden blocks and some other tasks."),
			obtain = S("Use three pieces of the selected tool material and two sticks. Two mirrored layouts are registered.")},
		{key = "shovel", label = S("Shovel"), tool = "shovel", item = "mcl_tools:shovel_wood",
			purpose = S("A shovel is useful for dirt, sand, gravel and other loose blocks."),
			obtain = S("Place one piece of the selected tool material above two sticks.")},
		{key = "sword", label = S("Sword"), tool = "sword", item = "mcl_tools:sword_wood",
			purpose = S("A sword is a close-range weapon and can also cut some particular blocks."),
			obtain = S("Place two pieces of the selected tool material above one stick.")},
		{key = "hoe", label = S("Hoe"), tool = "hoe", item = "mcl_tools:hoe_wood",
			purpose = S("A hoe prepares suitable soil for growing crops."),
			obtain = S("Place two pieces of the selected tool material across the top, then two sticks below. Two mirrored layouts are registered.")},
	},
	survival = {
		{key = "torch", label = S("Torch"), item = "mcl_torches:torch",
			purpose = S("A torch lights nearby spaces."),
			obtain = S("Combine one compatible coal item above one stick; the registered recipe returns four torches." )},
		{key = "furnace", label = S("Furnace"), item = "mcl_furnaces:furnace",
			purpose = S("A furnace cooks food and processes materials using fuel."),
			obtain = S("Place compatible stone around the outside of a 3×3 grid, leaving the center empty." )},
		{key = "chest", label = S("Chest"), item = "mcl_chests:chest",
			purpose = S("A chest stores items. Open it with a right-click."),
			obtain = S("Place compatible wood around the outside of a 3×3 grid, leaving the center empty." )},
		{key = "bed", label = S("Bed"), item = "mcl_beds:bed_red_bottom", variant_family = "bed",
			purpose = S("A bed lets you sleep when it is safe to use. World settings determine whether it also sets a respawn point."),
			obtain = S("Use three matching wool blocks above three compatible wood items. Other colors have corresponding registered recipes." )},
	},
}

local item_by_key = {}
for category, category_entries in pairs(entries) do
	for _, entry in ipairs(category_entries) do
		item_by_key[entry.key] = {category = category, entry = entry}
	end
end

local function first_line(text)
	if type(text) ~= "string" or text == "" then return nil end
	text = text:match("^[^\n]+") or text
	-- Never echo a technical item identifier as a normal display label.
	if text:match("^[%w_%-]+:[%w_%-]+$") then return nil end
	return text
end

local function lang_for(player)
	local info = player and core.get_player_information(player:get_player_name())
	return info and info.lang_code or "en"
end

local function display_name(itemname, player)
	local def = core.registered_items[itemname]
	local name = def and (first_line(def.description) or first_line(def._doc_items_entry_name))
	if not name and doc and doc.get_entry_definition then
		for _, category in ipairs({"nodes", "tools", "craftitems", "mobs"}) do
			local entry = doc.get_entry_definition(category, itemname)
			name = entry and first_line(entry.name)
			if name then break end
		end
	end
	if not name then return S("Unlabeled item") end
	return core.get_translated_string(lang_for(player), name)
end

local function escape(text)
	return core.formspec_escape(tostring(text or ""))
end

local function html(text)
	return tostring(text or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\n", "<br>")
end

local function icon_id(itemname)
	if itemname and core.registered_items[itemname] then return itemname end
	return nil
end

local function item_description(itemname, player)
	local group = group_display[itemname]
	if group then return core.get_translated_string(lang_for(player), group.label), icon_id(group.icon) end
	local name = itemname and display_name(itemname, player)
	return name or S("Compatible material"), icon_id(itemname)
end

local function output_parts(output)
	local itemname, count = tostring(output or ""):match("^%s*([^%s]+)%s*(%d*)")
	return itemname, tonumber(count) or 1
end

local function recipe_list(itemname)
	if not core.get_all_craft_recipes or not itemname then return {} end
	local all = core.get_all_craft_recipes(itemname) or {}
	local result = {}
	for _, recipe in ipairs(all) do
		if recipe and recipe.method == "normal" then
			result[#result + 1] = recipe
		end
	end
	return result
end

local function recipe_items(recipe)
	local items, last = recipe.items or {}, 0
	for index in pairs(items) do
		if type(index) == "number" and index > last then last = index end
	end
	return items, last
end

local function selected_recipe(entry, variant)
	local item = variant or entry.item
	local recipes = recipe_list(item)
	return item, recipes
end

local function craft_location(recipe, last)
	if recipe.width == 0 then return S("Inventory or table; ingredients may be placed in any order.") end
	local width = math.max(1, recipe.width or 1)
	local height = math.max(1, math.ceil(last / width))
	if width <= 2 and height <= 2 then return S("Inventory 2×2 or crafting table 3×3.") end
	return S("Crafting table 3×3.")
end

local function matrix_size(recipe, last)
	if recipe.width == 0 then return 2 end
	local width = math.max(1, recipe.width or 1)
	local height = math.max(1, math.ceil(last / width))
	return (width <= 2 and height <= 2) and 2 or 3
end

local function material_summary(recipe, player)
	local items, last = recipe_items(recipe)
	local counts, order = {}, {}
	if recipe.width == 0 then
		for index = 1, last do
			local item = items[index]
			if item and item ~= "" then
				local name = item_description(item, player)
				counts[name] = (counts[name] or 0) + 1
				if counts[name] == 1 then order[#order + 1] = name end
			end
		end
	else
		for index = 1, last do
			local item = items[index]
			if item and item ~= "" then
				local name = item_description(item, player)
				counts[name] = (counts[name] or 0) + 1
				if counts[name] == 1 then order[#order + 1] = name end
			end
		end
	end
	local summary = {}
	for _, name in ipairs(order) do
		local count = counts[name]
		summary[#summary + 1] = (count > 1 and (tostring(count) .. "× ") or "") .. name
	end
	return table.concat(summary, S(", "))
end

local function material_variant_label(setname)
	local labels = {
		wood = S("Wood"), stone = S("Stone"), copper = S("Copper"),
		iron = S("Iron"), gold = S("Gold"), diamond = S("Diamond"),
		netherite = S("Netherite"),
	}
	return labels[setname] or S("Other")
end

local function tool_variants(entry)
	local result = {}
	local sets = mcl_tools and mcl_tools.sets or {}
	for setname, set in pairs(sets) do
		local item = "mcl_tools:" .. entry.tool .. "_" .. setname
		if core.registered_items[item] then
			result[#result + 1] = {
				id = item,
				set = setname,
				label = material_variant_label(setname),
				craftable = set.craftable ~= false,
			}
		end
	end
	table.sort(result, function(a, b)
		local order = {wood = 1, stone = 2, copper = 3, iron = 4, gold = 5, diamond = 6, netherite = 7}
		return (order[a.set] or 99) < (order[b.set] or 99)
	end)
	return result
end

local function entry_variants(entry)
	if entry.tool then return tool_variants(entry) end
	local result = {}
	if entry.variant_family == "planks" or entry.variant_family == "bed" then
		for itemname in pairs(core.registered_items) do
			local match
			if entry.variant_family == "planks" then
				match = itemname:match("^mcl_trees:wood_([%w_]+)$")
			else
				match = itemname:match("^mcl_beds:bed_([%w_]+)_bottom$")
			end
			if match then result[#result + 1] = {id = itemname, key = match} end
		end
	end
	table.sort(result, function(a, b) return a.id < b.id end)
	return result
end

local function get_progressive_notice()
	local filters = mcl_craftguide and mcl_craftguide.get_recipe_filters and mcl_craftguide.get_recipe_filters()
	local notice
	if filters and type(filters["Default progressive filter"]) == "function" then
		notice = S("The general book may hide undiscovered recipes; this guide shows basics without changing that filter.")
	else
		notice = S("The general book remains useful for searching and the wider registered catalog.")
	end
	return notice .. "\n" .. S("Recipes follow this world, not a fixed Minecraft edition; bed behavior can depend on server settings.")
end

local function grid_formspec(recipe, player, x, y)
	local items, last = recipe_items(recipe)
	local size = matrix_size(recipe, last)
	local cell = size == 2 and 0.78 or 0.62
	local gap = 0.12
	local grid_width = size * cell + (size - 1) * gap
	local start_x = x + (2.85 - grid_width) / 2
	local start_y = y + (2.25 - grid_width) / 2
	local fs = {mcl_formspec.get_itemslot_bg_v4(start_x, start_y, size, size, nil, "everforge_ui_slot.png")}
	local recipe_width = recipe.width == 0 and 2 or math.max(1, recipe.width or 1)
	for index = 1, last do
		local item = items[index]
		if item and item ~= "" then
			local id = item
			if id:sub(1, 6) == "group:" then
				local group = group_display[id]
				id = group and group.icon or nil
			end
			if id and icon_id(id) then
				local slot = index - 1
				local col = slot % recipe_width
				local row = math.floor(slot / recipe_width)
				if recipe.width == 0 then
					col = slot % 2
					row = math.floor(slot / 2)
				end
				if col < size and row < size then
					fs[#fs + 1] = ("item_image[%0.3f,%0.3f;0.60,0.60;%s]"):format(
						start_x + col * (cell + gap) + 0.08,
						start_y + row * (cell + gap) + 0.08,
						id)
				end
			end
		end
	end
	return table.concat(fs), size
end

local function recipe_shapes(entry, item, player)
	local recipes = recipe_list(item)
	local result = {}
	for _, recipe in ipairs(recipes) do
		local items, last = recipe_items(recipe)
		if recipe.method == "normal" and last > 0 then result[#result + 1] = recipe end
	end
	return result
end

local function build_formspec(player, category, key, recipe_index, variant)
	category = entries[category] and category or "materials"
	local selection = item_by_key[key]
	if not selection or selection.category ~= category then
		key = entries[category][1].key
		selection = item_by_key[key]
	end
	local entry = selection.entry
	local selected_item = variant or entry.item
	local variants = entry_variants(entry)
	local valid_variant = false
	for _, info in ipairs(variants) do if info.id == selected_item then valid_variant = true end end
	if #variants > 0 and not valid_variant then selected_item = entry.item end
	local output_def = core.registered_items[selected_item]
	local name = display_name(selected_item, player)
	local recipes = recipe_shapes(entry, selected_item, player)
	recipe_index = math.max(1, math.min(#recipes, recipe_index or 1))
	local recipe = recipes[recipe_index]
	local fs = {
		"formspec_version[7]size[12,8.2]",
		"bgcolor[#08090BEF;true]",
		"background9[0,0;12,8.2;everforge_ui_panel.png;false;8]",
		"style_type[label;textcolor=#F2E8D9]",
		"style_type[hypertext;textcolor=#F2E8D9]",
		"style_type[button,button_exit;textcolor=#FFF1DC;border=false;bgimg=everforge_ui_button.png;bgimg_pressed=everforge_ui_button_pressed.png;bgimg_middle=4;font=bold]",
		"style_type[button:hovered,button_exit:hovered;bgimg=everforge_ui_button_hover.png]",
		"box[0.35,0.25;11.3,0.75;#242325]",
		"box[0.35,0.25;0.06,0.75;#C27A4A]",
		"label[0.72,0.49;" .. escape(core.colorize("#E8B17D", S("Basic Crafting"))) .. "]",
		"label[0.72,1.12;" .. escape(S("Choose a subject to see its purpose, how to obtain it and the registered grid.")) .. "]",
	}
	for index, id in ipairs(CATEGORIES) do
		local x = 0.55 + (index - 1) * 3.78
		fs[#fs + 1] = ("button[%0.2f,1.48;3.3,0.48;category_%s;%s]"):format(x, id, escape(category_labels[id]))
	end
	fs[#fs + 1] = "box[0.45,2.12;2.85,4.45;#111214EE]"
	for index, candidate in ipairs(entries[category]) do
		local y = 2.3 + (index - 1) * 0.66
		if candidate.item and icon_id(candidate.item) then
			fs[#fs + 1] = ("item_image[%0.2f,%0.2f;0.42,0.42;%s]"):format(0.62, y + 0.04, candidate.item)
		end
		fs[#fs + 1] = ("button[%0.2f,%0.2f;2.15,0.5;item_%s;%s]"):format(1.08, y, candidate.key, escape(candidate.label))
	end
	fs[#fs + 1] = "box[3.48,2.12;8.05,4.45;#111214EE]"
	fs[#fs + 1] = "label[3.78,2.28;" .. escape(core.colorize("#E8B17D", name)) .. "]"
	if output_def and icon_id(selected_item) then
		fs[#fs + 1] = "item_image[10.72,2.22;0.72,0.72;" .. selected_item .. "]"
	end
	fs[#fs + 1] = "hypertext[3.78,2.68;7.3,0.48;purpose;" .. escape("<style color=#F2E8D9>" .. html(entry.purpose) .. "</style>") .. "]"
	fs[#fs + 1] = "hypertext[3.78,3.13;7.3,0.64;obtain;" .. escape("<style color=#D6C6B5>" .. html(entry.obtain) .. "</style>") .. "]"
	if entry.use then
		fs[#fs + 1] = "hypertext[3.78,3.72;7.3,0.48;use;" .. escape("<style color=#D6C6B5>" .. html(entry.use) .. "</style>") .. "]"
	end
	if entry.tool and #variants > 0 then
		local x = 3.78
		for _, info in ipairs(variants) do
			local width = 1.03
			fs[#fs + 1] = ("button[%0.2f,3.8;%0.2f,0.42;variant_%s;%s]"):format(x, width, info.set, escape(info.label))
			x = x + width + 0.06
		end
	elseif entry.variant_family and #variants > 1 then
		local variant_label = entry.variant_family == "bed" and S("Bed color") or S("Wood type")
		fs[#fs + 1] = "label[3.78,3.84;" .. escape(variant_label) .. "]"
		fs[#fs + 1] = "button[7.0,3.8;1.45,0.42;previous_variant;" .. escape(S("Previous")) .. "]"
		fs[#fs + 1] = "button[8.55,3.8;1.45,0.42;next_variant;" .. escape(S("Next")) .. "]"
	end
	if recipe then
		local _, last = recipe_items(recipe)
		local outname, outcount = output_parts(recipe.output)
		fs[#fs + 1] = "label[3.78,4.02;" .. escape(S("Recipe @1 of @2", tostring(recipe_index), tostring(#recipes))) .. "]"
		fs[#fs + 1] = "hypertext[3.78,4.28;3.05,0.65;where;" .. escape("<style color=#D6C6B5>" .. html(craft_location(recipe, last)) .. "</style>") .. "]"
		local grid, size = grid_formspec(recipe, player, 6.88, 4.16)
		fs[#fs + 1] = grid
		fs[#fs + 1] = "image[9.78,4.86;0.65,0.52;craftguide_arrow.png]"
		if outname and icon_id(outname) then
			fs[#fs + 1] = "item_image[10.5,4.65;0.86,0.86;" .. outname .. "]"
		end
		local result_name = outname and display_name(outname, player) or name
		fs[#fs + 1] = "hypertext[9.85,5.52;1.58,0.72;output_name;" .. escape("<style color=#D6C6B5>" .. html(S("@1× @2", tostring(outcount), result_name)) .. "</style>") .. "]"
		fs[#fs + 1] = "hypertext[3.78,5.38;3.0,0.84;materials;" .. escape("<style color=#D6C6B5>" .. html(S("Materials: @1", material_summary(recipe, player))) .. "</style>") .. "]"
	else
		local message = entry.no_recipe and S("This material is gathered from the world; no crafting recipe is registered.")
			or S("No crafting-grid recipe is registered for this variant in the current game.")
		fs[#fs + 1] = "hypertext[3.78,4.2;7.2,0.9;no_recipe;" .. escape("<style color=#D6C6B5>" .. html(message) .. "</style>") .. "]"
	end
	if entry.tool then
		local set = selected_item:match("_([^_]+)$")
		local materialdefs = set and mcl_tools and mcl_tools.sets and mcl_tools.sets[set]
		if materialdefs and materialdefs.craftable == false then
			fs[#fs + 1] = "hypertext[3.78,6.08;7.25,0.3;variant_note;" .. escape("<style color=#E8B17D>" .. html(S("This tool material is registered as non-grid-craftable.")) .. "</style>") .. "]"
		end
	end
	fs[#fs + 1] = "hypertext[0.55,6.66;11.0,0.56;progressive_note;" .. escape("<style color=#B9AEA3>" .. html(get_progressive_notice()) .. "</style>") .. "]"
	fs[#fs + 1] = ("button[0.55,7.34;2.5,0.55;general_book;%s]"):format(escape(S("Open general recipe book")))
	fs[#fs + 1] = ("button[4.7,7.34;2.5,0.55;back_hub;%s]"):format(escape(S("Back to Everforge guide")))
	fs[#fs + 1] = ("button_exit[9.35,7.34;2.0,0.55;close;%s]"):format(escape(S("Close")))
	return table.concat(fs), category, key, recipe_index, selected_item
end

local state = {}

local function show(player, category, key, recipe_index, variant)
	local name = player:get_player_name()
	local formspec, saved_category, saved_key, saved_index, saved_variant = build_formspec(player, category, key, recipe_index, variant)
	state[name] = {category = saved_category, key = saved_key, recipe_index = saved_index, variant = saved_variant}
	if everforge._suppress_waila then everforge._suppress_waila(player, FORM) end
	core.show_formspec(name, FORM, formspec)
end

local function open_general_book(player)
	local name = player:get_player_name()
	if mcl_craftguide and type(mcl_craftguide.show) == "function" then
		if everforge._restore_waila then everforge._restore_waila(player, FORM) end
		if everforge._suppress_waila then everforge._suppress_waila(player, "mcl_craftguide") end
		mcl_craftguide.show(name)
		return true
	end
	core.chat_send_player(name, S("The general recipe book is unavailable right now."))
	return false
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then return end
	local name = player:get_player_name()
	local current = state[name] or {category = "materials", key = "logs", recipe_index = 1}
	for _, category in ipairs(CATEGORIES) do
		if fields["category_" .. category] then
			show(player, category, entries[category][1].key, 1)
			return true
		end
	end
	for category, category_entries in pairs(entries) do
		for _, entry in ipairs(category_entries) do
			if fields["item_" .. entry.key] then
				show(player, category, entry.key, 1)
				return true
			end
		end
	end
	local selected = item_by_key[current.key]
	if selected then
		local variants = entry_variants(selected.entry)
		if selected.entry.tool then
			for _, info in ipairs(variants) do
				if fields["variant_" .. info.set] then
					show(player, current.category, current.key, 1, info.id)
					return true
				end
			end
		elseif fields.previous_variant or fields.next_variant then
			local index = 1
			for i, info in ipairs(variants) do if info.id == current.variant then index = i; break end end
			if fields.previous_variant then index = index <= 1 and #variants or index - 1 else index = index >= #variants and 1 or index + 1 end
			local next_variant = variants[index]
			if next_variant then show(player, current.category, current.key, 1, next_variant.id) end
			return true
		end
	end
	if fields.previous_recipe or fields.next_recipe then
		local recipes = recipe_shapes(selected and selected.entry or entries[current.category][1], current.variant or (selected and selected.entry.item), player)
		local index = current.recipe_index or 1
		if fields.previous_recipe then index = index <= 1 and #recipes or index - 1 else index = index >= #recipes and 1 or index + 1 end
		show(player, current.category, current.key, index, current.variant)
		return true
	end
	if fields.general_book then
		open_general_book(player)
		return true
	elseif fields.back_hub then
		if everforge.onboarding and everforge.onboarding.show_hub then everforge.onboarding.show_hub(player) end
		return true
	elseif fields.close or fields.quit then
		state[name] = nil
		if everforge._restore_waila then everforge._restore_waila(player, FORM) end
		return true
	end
	return true
end)

-- Recipe alternatives are navigable. Add controls only when a recipe has peers.
local original_build = build_formspec
build_formspec = function(player, category, key, recipe_index, variant)
	local formspec, saved_category, saved_key, saved_index, saved_variant = original_build(player, category, key, recipe_index, variant)
	local selected = item_by_key[saved_key]
	local selected_item = saved_variant or (selected and selected.entry.item)
	local recipes = selected and recipe_shapes(selected.entry, selected_item, player) or {}
	if #recipes > 1 then
		local controls = ("button[7.05,6.08;1.55,0.42;previous_recipe;%s]button[8.7,6.08;1.55,0.42;next_recipe;%s]"):format(
			escape(S("Previous")), escape(S("Next")))
		formspec = formspec .. controls
	end
	return formspec, saved_category, saved_key, saved_index, saved_variant
end

everforge.basic_crafting = {
	formname = FORM,
	show = show,
	build_formspec = build_formspec,
}

return everforge.basic_crafting
