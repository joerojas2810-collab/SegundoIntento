-- SPDX-License-Identifier: LGPL-2.1-or-later
-- Mineclonia port of the Toolranks progression idea. The upstream tool-rank
-- speed/uses multipliers mutate generic groupcaps, which Mineclonia does not
-- use for block mining. This adaptation stores/display ranks per ItemStack
-- and intentionally leaves _mcl_diggroups, damage and wear untouched.
local S = core.get_translator("toolranks")
local level_digs = math.max(1, tonumber(core.settings:get("toolranks_level_digs")) or 100)
local max_level = math.max(1, tonumber(core.settings:get("toolranks_levels")) or 10)

toolranks = {colors = {
	green = core.get_color_escape_sequence("#1eff00"),
	gold = core.get_color_escape_sequence("#ffdf00"),
	grey = core.get_color_escape_sequence("#9d9d9d"),
	white = core.get_color_escape_sequence("#ffffff"),
}}

function toolranks.get_tool_type(description)
	local text = (description or ""):lower()
	if text:find("pick") then return S("pickaxe") end
	if text:find("axe") then return S("axe") end
	if text:find("shovel") then return S("shovel") end
	if text:find("sword") then return S("sword") end
	if text:find("hoe") then return S("hoe") end
	return S("tool")
end

function toolranks.get_level(uses)
	return math.min(max_level, math.floor(math.max(0, tonumber(uses) or 0) / level_digs))
end

function toolranks.create_description(description, uses)
	local level = toolranks.get_level(uses)
	return S("@1\n@2Level @3 @4\n@5Blocks mined: @6",
		toolranks.colors.green .. (description or S("Tool")),
		toolranks.colors.gold, level, toolranks.get_tool_type(description),
		toolranks.colors.grey, tonumber(uses) or 0)
end

local function rank_stack(stack, player, successful)
	if not successful or stack:is_empty() then return stack end
	local def = stack:get_definition()
	if not def or not (def._mcl_diggroups or (def.groups and def.groups.tool)) then return stack end
	local meta = stack:get_meta()
	local old_level = tonumber(meta:get_string("toolranks:lastlevel")) or 0
	local dug = (tonumber(meta:get_string("toolranks:dug")) or 0) + 1
	local level = toolranks.get_level(dug)
	local desc = meta:get_string("toolranks:original_description")
	if desc == "" then
		desc = def.original_description or def.description or S("Tool")
		meta:set_string("toolranks:original_description", desc)
	end
	meta:set_string("toolranks:dug", tostring(dug))
	meta:set_string("toolranks:lastlevel", tostring(level))
	meta:set_string("description", toolranks.create_description(desc, dug))
	if level > old_level and player and player:is_player() then
		core.chat_send_player(player:get_player_name(), S("Your @1 reached rank @2!", desc, level))
	end
	return stack
end

-- Called by compatible mods such as More Ores. It intentionally does not
-- change the requested wear or native mining capabilities.
function toolranks.new_afteruse(itemstack, user, _node, digparams)
	local wear = digparams and (tonumber(digparams.wear) or 0) or 0
	local worn = wear > 0
	if worn and user and user:is_player() and not core.is_creative_enabled(user:get_player_name()) then
		itemstack:add_wear(wear)
	end
	return rank_stack(itemstack, user, worn)
end

function toolranks.add_tool(name)
	local def = core.registered_tools[name]
	if not def then return false end
	core.override_item(name, {original_description = def.description})
	return true
end

core.register_on_dignode(function(_pos, _oldnode, digger)
	if not digger or not digger:is_player() then return end
	local stack = digger:get_wielded_item()
	local def = stack:get_definition()
	-- Mods using the upstream-compatible callback are ranked there instead.
	if def and def.after_use == toolranks.new_afteruse then return end
	local updated = rank_stack(stack, digger, true)
	digger:set_wielded_item(updated)
end)
