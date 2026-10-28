-- SPDX-License-Identifier: GPL-3.0-or-later
-- A short, beginner-facing index over Mineclonia's live recipe registry.
-- It never registers or changes a recipe; the complete catalog remains in
-- mcl_craftguide.
local S = core.get_translator("everforge")
local FORM = "everforge:basic_crafting"
local CATEGORIES = {"materials", "tools", "survival"}
local category_labels = {
	materials = S("Materials"),
	tools = S("Tools"),
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
	return core.hypertext_escape(tostring(text or ""))
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
	if recipe.width == 0 then return last > 4 and 3 or 2 end
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
	-- Backgrounds and icons share the same pitch in real formspec units.
	local cell, gap = 0.74, 0.12
	local grid_width = size * cell + (size - 1) * gap
	local start_x = x + (2.46 - grid_width) / 2
	local start_y = y + (2.46 - grid_width) / 2
	local fs = {}
	for row = 0, size - 1 do
		for col = 0, size - 1 do
			fs[#fs + 1] = ("image[%0.3f,%0.3f;0.74,0.74;everforge_ui_slot.png]"):format(
				start_x + col * (cell + gap), start_y + row * (cell + gap))
		end
	end
	local recipe_width = recipe.width == 0 and size or math.max(1, recipe.width or 1)
	for index = 1, last do
		local item = items[index]
		if item and item ~= "" then
			local id, count = output_parts(item)
			if id:sub(1, 6) == "group:" then
				local group = group_display[id]
				id = group and group.icon or nil
			end
			if id and icon_id(id) then
				local slot = index - 1
				local col = slot % recipe_width
				local row = math.floor(slot / recipe_width)
				if recipe.width == 0 then
					col = slot % size
					row = math.floor(slot / size)
				end
				if col < size and row < size then
					fs[#fs + 1] = ("item_image[%0.3f,%0.3f;0.60,0.60;%s %d]"):format(
						start_x + col * (cell + gap) + 0.07,
						start_y + row * (cell + gap) + 0.07,
						id, count)
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

local function build_formspec(player, category, key, recipe_index, variant, detail_page)
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
	local function rich(text)
		-- Resolve the translation key before escaping markup characters such as >.
		return escape("<global margin=0><style color=#F2E8D9>" .. html(core.get_translated_string(lang_for(player), text)) .. "</style>")
	end
	local fs = {
		"formspec_version[7]size[12,8.2]",
		"bgcolor[#08090BEF;true]",
		"background9[0,0;12,8.2;everforge_ui_panel.png;false;8]",
		"style_type[label;textcolor=#F2E8D9;font_size=*0.9]",
		"style_type[textarea;textcolor=#F2E8D9;font_size=*0.85]",
		"style_type[hypertext;textcolor=#F2E8D9]",
		"style_type[button,button_exit;textcolor=#FFF1DC;border=false;bgimg=everforge_ui_button.png;bgimg_pressed=everforge_ui_button_pressed.png;bgimg_middle=4;font=bold;font_size=*0.85]",
		"style_type[button:hovered,button_exit:hovered;bgimg=everforge_ui_button_hover.png]",
		"box[0.35,0.25;11.3,0.75;#242325]",
		"box[0.35,0.25;0.06,0.75;#C27A4A]",
		"label[0.72,0.6;" .. escape(core.colorize("#E8B17D", S("Basic Crafting"))) .. "]",
	}
	for index, id in ipairs(CATEGORIES) do
		local x = 0.55 + (index - 1) * 3.7
		fs[#fs + 1] = ("button[%0.2f,1.25;3.5,0.6;category_%s;%s]"):format(x, id, escape(category_labels[id]))
	end
	fs[#fs + 1] = "box[0.45,2.05;3.1,5.1;#111214EE]"
	for index, candidate in ipairs(entries[category]) do
		local y = 2.25 + (index - 1) * 0.85
		fs[#fs + 1] = ("button[0.6,%0.2f;2.8,0.7;item_%s;%s]"):format(y, candidate.key, escape(candidate.key == "table" and S("Crafting\nTable") or candidate.label))
	end
	fs[#fs + 1] = "box[3.7,2.05;7.85,5.1;#111214EE]"
	fs[#fs + 1] = "label[3.9,2.15;6.5,0.6;" .. escape(name) .. "]"
	if output_def and icon_id(selected_item) then
		fs[#fs + 1] = "item_image[10.6,2.16;0.65,0.65;" .. selected_item .. "]"
	end
	detail_page = detail_page == "description" and "description" or "recipe"
	fs[#fs + 1] = "button[3.9,2.85;3.5,0.55;description_page;" .. escape(S("Description")) .. "]"
	fs[#fs + 1] = "button[7.6,2.85;3.65,0.55;recipe_page;" .. escape(S("Recipe")) .. "]"
	local description = entry.purpose .. "\n" .. entry.obtain
	if entry.use then description = description .. "\n" .. entry.use end
	local variant_labels, selected_index = {}, 1
	for index, info in ipairs(variants) do
		variant_labels[#variant_labels + 1] = escape(core.get_translated_string(lang_for(player), info.label or display_name(info.id, player)))
		if info.id == selected_item then selected_index = index end
	end
	if #variants > 1 then
		fs[#fs + 1] = "label[3.9,3.85;" .. escape(S("Variant")) .. "]"
		fs[#fs + 1] = ("dropdown[5.4,3.55;5.85,0.55;material_variant;%s;%d;true]"):format(table.concat(variant_labels, ","), selected_index)
	end
	if detail_page == "description" or not recipe then
		if not recipe and not entry.no_recipe then
			description = description .. "\n" .. S("No crafting-grid recipe is registered for this variant in the current game.")
			local set = selected_item:match("_([^_]+)$")
			local materialdefs = entry.tool and set and mcl_tools and mcl_tools.sets and mcl_tools.sets[set]
			if materialdefs and materialdefs.craftable == false then
				description = description .. "\n" .. S("This tool material is registered as non-grid-craftable.")
			end
		elseif entry.no_recipe then
			description = entry.purpose .. "\n" .. S("This material is gathered from the world; no crafting recipe is registered.")
		end
		local y, height = #variants > 1 and 4.3 or 3.6, #variants > 1 and 2.7 or 3.4
		fs[#fs + 1] = ("hypertext[3.9,%s;7.35,%s;description;%s]"):format(y, height, rich(description))
	else
		local _, last = recipe_items(recipe)
		local outname, outcount = output_parts(recipe.output)
		fs[#fs + 1] = "label[3.9,4.4;" .. escape(S("Recipe @1 of @2", tostring(recipe_index), tostring(#recipes))) .. "]"
		fs[#fs + 1] = "textarea[3.9,5.2;3.15,1.85;;;" .. escape(core.get_translated_string(lang_for(player), S("Materials: @1", material_summary(recipe, player)))) .. "]"
		local grid_label = recipe.width == 0 and S("Shapeless") or (matrix_size(recipe, last) == 2 and S("2×2 or 3×3") or S("3×3"))
		fs[#fs + 1] = "label[3.9,4.7;3.15,0.45;" .. escape(grid_label) .. "]"
		fs[#fs + 1] = "tooltip[3.9,4.7;3.15,0.45;" .. escape(core.get_translated_string(lang_for(player), craft_location(recipe, last))) .. "]"
		fs[#fs + 1] = grid_formspec(recipe, player, 7.35, 4.65)
		fs[#fs + 1] = "image[9.92,5.35;0.45,0.4;craftguide_arrow.png]"
		if outname and icon_id(outname) then
			fs[#fs + 1] = "item_image[10.5,5.13;0.74,0.74;" .. outname .. " " .. outcount .. "]"
		end
		fs[#fs + 1] = "label[10.65,6.15;" .. escape(S("@1×", tostring(outcount))) .. "]"
		if #recipes > 1 then
			fs[#fs + 1] = "button[7.35,4.15;1.75,0.45;previous_recipe;" .. escape(S("Previous")) .. "]"
			fs[#fs + 1] = "button[9.25,4.15;2.0,0.45;next_recipe;" .. escape(S("Next")) .. "]"
		end
	end
	-- The progressive-discovery explanation belongs to the complete catalog.
	fs[#fs + 1] = "tooltip[general_book;" .. escape(core.get_translated_string(lang_for(player), get_progressive_notice())) .. "]"
	local tutorial = everforge.onboarding and everforge.onboarding.recipe_return_pending and everforge.onboarding.recipe_return_pending(player)
	fs[#fs + 1] = "button[0.55,7.45;3.45,0.55;general_book;" .. escape(S("Recipe book")) .. "]"
	fs[#fs + 1] = "button[4.2,7.45;4.55,0.55;back_hub;" .. escape(tutorial and S("Back to tutorial") or S("Back to guide")) .. "]"
	fs[#fs + 1] = "button_exit[9.0,7.45;2.25,0.55;close;" .. escape(S("Close")) .. "]"
	return table.concat(fs), category, key, recipe_index, selected_item, detail_page
end

local state = {}

local function show(player, category, key, recipe_index, variant, detail_page)
	local name = player:get_player_name()
	local formspec, saved_category, saved_key, saved_index, saved_variant, saved_page = build_formspec(player, category, key, recipe_index, variant, detail_page)
	state[name] = {category = saved_category, key = saved_key, recipe_index = saved_index, variant = saved_variant, detail_page = saved_page}
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
	if fields.description_page or fields.recipe_page then
		show(player, current.category, current.key, current.recipe_index, current.variant, fields.description_page and "description" or "recipe")
		return true
	end
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
		if fields.material_variant then
			local info = variants[tonumber(fields.material_variant)]
			-- Luanti submits dropdown values with other buttons too. Only a
			-- changed selection is a variant event; otherwise handle navigation.
			if info and info.id ~= current.variant then
				show(player, current.category, current.key, 1, info.id)
				return true
			end
		end
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
		state[name] = nil
		if everforge._restore_waila then everforge._restore_waila(player, FORM) end
		if everforge.onboarding and everforge.onboarding.return_from_recipes then
			everforge.onboarding.return_from_recipes(player)
		elseif everforge.onboarding and everforge.onboarding.show_hub then everforge.onboarding.show_hub(player) end
		return true
	elseif fields.close or fields.quit then
		state[name] = nil
		if everforge._restore_waila then everforge._restore_waila(player, FORM) end
		return true
	end
	return true
end)

core.register_on_leaveplayer(function(player) state[player:get_player_name()] = nil end)

everforge.basic_crafting = {
	formname = FORM,
	show = show,
	build_formspec = build_formspec,
}

return everforge.basic_crafting
