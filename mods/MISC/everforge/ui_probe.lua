-- SPDX-License-Identifier: GPL-3.0-or-later
-- Explicit, read-only diagnostics: never translate, repair, or filter strings.
return function(waila_state)
	local malformed = string.char(27) .. "(Tadamantine)"
	core.register_chatcommand("everforge_ui_probe", {
		description = "Log HUD provenance and Adamantine translation metadata (read-only).",
		privs = {server = true},
		func = function(name)
			local player = core.get_player_by_name(name)
			if not player then return false, "Player must be online." end
			local bad = 0
			local function log(label, value)
				core.log("action", "[everforge_ui_probe] " .. label .. "=" .. string.format("%q", tostring(value)))
			end
			local function inspect(label, value)
				if type(value) == "string" and value:find(malformed, 1, true) then
					bad = bad + 1
					log("MALFORMED " .. label, value)
				end
			end
			local function inventory(label, inv)
				if not inv then return end
				for list, stacks in pairs(inv:get_lists()) do
					for i, stack in ipairs(stacks) do
						local prefix = label .. "." .. list .. "[" .. i .. "] " .. stack:get_name()
						for key, value in pairs(stack:get_meta():to_table().fields or {}) do
							inspect(prefix .. "." .. key, value)
						end
					end
				end
			end
			local enabled, suppressed = waila_state(player)
			log("player", name)
			log("WAILA enabled", enabled)
			log("WAILA temporarily suppressed", suppressed)
			log("Mineclonia mcl_info_show", player:get_meta():get_string("mcl_info_show"))
			if player.hud_get_all then
				for id, hud in pairs(player:hud_get_all()) do
					-- Native client infotext has no server HUD id.
					log("server HUD " .. id, (hud.type or hud.hud_elem_type or "?") .. " " .. (hud.text or ""))
				end
			end
			for item, def in pairs(core.registered_items) do
				inspect("registered " .. item .. ".description", def.description)
				inspect("registered " .. item .. "._tt_original_description", def._tt_original_description)
			end
			inventory("player", player:get_inventory())
			local pointed = mcl_util.get_pointed_thing(player, false, false)
			if pointed and pointed.type == "node" and pointed.under then
				local pos = pointed.under
				local node = core.get_node(pos)
				local meta = core.get_meta(pos)
				log("pointed node", node.name .. " " .. core.pos_to_string(pos))
				log("native infotext", meta:get_string("infotext"))
				log("Everforge machine status", meta:get_string("everforge:machine_infotext"))
				for key, value in pairs(meta:to_table().fields or {}) do
					inspect("pointed node metadata " .. key, value)
				end
				inventory("pointed node", meta:get_inventory())
			end
			return true, "Read-only probe logged. Malformed fields: " .. bad .. ". See debug.txt / server log."
		end,
	})
end
