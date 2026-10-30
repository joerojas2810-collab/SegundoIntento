-- SPDX-License-Identifier: GPL-3.0-or-later
-- "El sello de las ruinas": a short, persistent, party-based adventure.
--
-- This module deliberately reuses the existing expedition NPC, camp and
-- character inventories.  It only adds quest state, the ruin site markers and
-- the encounter director.  It never changes combat, forging, skills or items.

local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local E = everforge.expedition
local storage = core.get_mod_storage()
local STATE_KEY = "everforge:ruins_quest:v1"
local SITE_KEY = "everforge:ruins_site:v1"
local FORM_NPC = "everforge:ruins_npc"
local FORM_INVITE = "everforge:ruins_invite"
local FORM_COMPLETE = "everforge:ruins_complete"
local SIGIL = "everforge:ruin_sigil"
local MAX_MEMBERS = 4
local INVITE_TTL = 300
local SITE_FILE = modpath .. "/schematics/sello_ruinas.json"
local Q = {}

local function now()
	return os.time()
end

local function log(message)
	core.log("action", "[Everforge] " .. message)
end

local function read_json_file(path)
	local file = io.open(path, "r")
	if not file then return nil end
	local raw = file:read("*a")
	file:close()
	local ok, value = pcall(core.parse_json, raw)
	if not ok or type(value) ~= "table" then return nil end
	return value
end

local manifest = read_json_file(SITE_FILE)
local site

local function load_site()
	local raw = storage:get_string(SITE_KEY)
	if raw == "" then return nil end
	local ok, value = pcall(core.parse_json, raw)
	if not ok or type(value) ~= "table" or type(value.anchor) ~= "table" then
		core.log("error", "[Everforge] Corrupt ruin site record; it is preserved")
		return nil
	end
	return value
end
site = load_site()

local function save_site()
	if not site then return end
	storage:set_string(SITE_KEY, core.write_json(site))
end

local function load_state()
	local raw = storage:get_string(STATE_KEY)
	if raw == "" then
		return {version = 1, next_id = 1, invites = {}, party = nil}
	end
	local ok, value = pcall(core.parse_json, raw)
	if not ok or type(value) ~= "table" then
		core.log("error", "[Everforge] Corrupt ruins quest record; actions are disabled but the record is preserved")
		return nil
	end
	if type(value.invites) ~= "table" then value.invites = {} end
	if type(value.next_id) ~= "number" then value.next_id = 1 end
	return value
end

local state = load_state()

local function save()
	if not state then return false end
	local ok, err = pcall(function() storage:set_string(STATE_KEY, core.write_json(state)) end)
	if not ok then
		core.log("error", "[Everforge] Could not save ruins quest: " .. tostring(err))
		return false
	end
	return true
end

local function online(name)
	local player = core.get_player_by_name(name)
	if player and player:is_valid() then return player end
	return nil
end

local function tell(name, message)
	if name then core.chat_send_player(name, "[El sello] " .. message) end
end

local function escape(text)
	return core.formspec_escape(tostring(text or ""))
end

local function rich(text)
	return core.hypertext_escape(tostring(text or "")):gsub("\n", "<br>")
end

local function frame(width, height)
	return "formspec_version[7]size[" .. width .. "," .. height .. "]" ..
		"bgcolor[#0d1118;true]" ..
		"style_type[label;textcolor=#F2E8D9]" ..
		"style_type[button;bgcolor=#34465e;textcolor=#F7F1E3]" ..
		"style_type[button_exit;bgcolor=#34465e;textcolor=#F7F1E3]"
end

local function member(party, name)
	return party and party.members and party.members[name] == true
end

local function party_members(party)
	local list = {}
	if not party then return list end
	for _, name in ipairs(party.order or {}) do list[#list + 1] = name end
	return list
end

local function member_count(party)
	local n = 0
	for _ in pairs(party and party.members or {}) do n = n + 1 end
	return n
end

local function broadcast(party, message)
	for _, name in ipairs(party_members(party)) do
		if online(name) then tell(name, message) end
	end
end

local function current_party_for(name)
	if not state or not state.party then return nil end
	if member(state.party, name) then return state.party end
	return nil
end

local function stage_text(party)
	if not party then return "" end
	if party.stage == "prepared" then
		return "Preparativos. Consigue una espada y usa la piedra de viaje del campamento."
	elseif party.stage == "explore" then
		return "Explora la fortaleza. La escalera del patio oeste baja a la cripta."
	elseif party.stage == "return" then
		return "El sello está en juego. Vuelve al campamento y entrégalo a la Maestra."
	elseif party.stage == "done" then
		return "Misión completada. El sello volvió a las manos de la Maestra."
	end
	return "Habla con la Maestra."
end

local function objective_text(party)
	if not party then return "" end
	if party.stage == "prepared" then
		return "El sello de las ruinas · prepara una espada y viaja desde el campamento"
	elseif party.stage == "explore" then
		return "El sello de las ruinas · baja a la cripta y encuentra la cámara del sello"
	elseif party.stage == "return" then
		return "El sello de las ruinas · vuelve al campamento y entrégalo"
	elseif party.stage == "done" then
		return "El sello de las ruinas · completada"
	end
	return "El sello de las ruinas"
end

local hud_ids = {}

local function refresh_hud(name)
	local player = online(name)
	if not player then return end
	local party = current_party_for(name)
	if not party or party.stage == "done" then
		if hud_ids[name] then
			player:hud_remove(hud_ids[name])
			hud_ids[name] = nil
		end
		return
	end
	local text = objective_text(party)
	if hud_ids[name] then
		player:hud_change(hud_ids[name], "text", text)
	else
		hud_ids[name] = player:hud_add({
			hud_elem_type = "text",
			position = {x = 0.985, y = 0.055},
			alignment = {x = -1, y = 1},
			offset = {x = 0, y = 0},
			number = 0xF2E8D9,
			text = text,
			z_index = 10,
		})
	end
end

local function refresh_all_huds()
	for _, player in ipairs(core.get_connected_players()) do
		refresh_hud(player:get_player_name())
	end
end

local function has_item(player, item)
	local inv = player:get_inventory()
	if not inv then return false end
	for i = 1, inv:get_size("main") do
		if inv:get_stack("main", i):get_name() == item then return true, i end
	end
	return false
end

local function give(player, item, count)
	local inv = player:get_inventory()
	if not inv then return false end
	local leftover = inv:add_item("main", ItemStack(item .. " " .. tostring(count or 1)))
	if leftover and not leftover:is_empty() then
		core.add_item(player:get_pos(), leftover)
	end
	return true
end

local function take_item(player, item, count)
	local inv = player:get_inventory()
	if not inv then return false end
	local need = count or 1
	for i = 1, inv:get_size("main") do
		local stack = inv:get_stack("main", i)
		if stack:get_name() == item and stack:get_count() >= need then
			stack:take_item(need)
			inv:set_stack("main", i, stack)
			return true
		end
	end
	return false
end

local function has_sword(player)
	if E and E.has_sword then return E.has_sword(player) end
	local inv = player:get_inventory()
	if not inv then return false end
	for i = 1, inv:get_size("main") do
		if core.get_item_group(inv:get_stack("main", i):get_name(), "sword") > 0 then return true end
	end
	return false
end

local function count_item(player, item)
	local inv = player:get_inventory()
	if not inv then return 0 end
	local n = 0
	for i = 1, inv:get_size("main") do
		local stack = inv:get_stack("main", i)
		if stack:get_name() == item then n = n + stack:get_count() end
	end
	return n
end

local function ensure_kit(player)
	local given = {}
	if not has_sword(player) then
		give(player, "mcl_tools:sword_stone", 1)
		given[#given + 1] = "una espada de piedra"
	end
	if count_item(player, "mcl_torches:torch") < 8 then
		give(player, "mcl_torches:torch", 12)
		given[#given + 1] = "antorchas"
	end
	if count_item(player, "mcl_farming:bread") < 3 then
		give(player, "mcl_farming:bread", 4)
		given[#given + 1] = "pan"
	end
	if #given == 0 then return false end
	tell(player:get_player_name(), "La Maestra te entrega " .. table.concat(given, ", ") .. " para el camino.")
	return true
end

local function free_players(party)
	local out = {}
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		if not member(party, name) then
			local other = current_party_for(name)
			if not other then out[#out + 1] = name end
		end
	end
	table.sort(out)
	return out
end

local function pending_invite(name)
	if not state or not state.invites then return nil end
	local invite = state.invites[name]
	if not invite then return nil end
	if type(invite.at) ~= "number" or now() - invite.at > INVITE_TTL then
		state.invites[name] = nil
		save()
		return nil
	end
	if not state.party or state.party.id ~= invite.party or state.party.stage == "done" then
		state.invites[name] = nil
		save()
		return nil
	end
	return state.party
end

local function show_invite(player, party)
	local name = player:get_player_name()
	core.show_formspec(name, FORM_INVITE, table.concat({
		frame(9.5, 5.2),
		"label[0.6,0.5;INVITACIÓN · EL SELLO DE LAS RUINAS]",
		("hypertext[0.6,1.15;8.3,2.2;invite;%s]"):format(rich(
			("La Maestra te invita a unirte a la expedición de %s.\n\nEs una misión de 15–20 minutos: fortaleza en ruinas, cripta, guardianes y un sello. El progreso se comparte y se conserva al desconectarse."):format(
				party.leader or "otro jugador"))),
		"button[0.6,3.9;3.0,0.8;accept;Aceptar]",
		"button_exit[3.8,3.9;2.6,0.8;decline;Rechazar]",
	}))
end

local function show_error(player)
	core.show_formspec(player:get_player_name(), FORM_NPC, table.concat({
		frame(9, 3.6),
		"label[0.6,0.5;MAESTRA DE EXPEDICIONES]",
		"hypertext[0.6,1.1;7.8,1.4;err;El registro de la expedición no está disponible. No se ha modificado ningún dato; consulta el registro del servidor.",
		"button_exit[0.6,2.7;3.2,0.7;close;Cerrar]",
	}))
end

local function show_start(player)
	core.show_formspec(player:get_player_name(), FORM_NPC, table.concat({
		frame(11.5, 6.4),
		"label[0.6,0.5;MAESTRA DE EXPEDICIONES]",
		("hypertext[0.6,1.15;10.2,2.6;intro;%s]"):format(rich(
			"Hace años sellé una puerta bajo la fortaleza del oeste. El sello ha vuelto a latir y los guardianes despiertan.\n\n" ..
			"Necesito a alguien que entre, lo recupere y vuelva. Puedes ir solo o con un grupo pequeño.\n\n" ..
			"Antes de partir necesitarás una espada. Yo puedo prestarte una si no tienes ninguna.")),
		"label[0.6,4.2;Misión: «El sello de las ruinas» · 15–20 minutos]",
		"button[0.6,4.9;5.6,0.8;start;Iniciar «El sello de las ruinas»]",
		"button_exit[6.5,4.9;2.6,0.8;close;Cerrar]",
	}))
end

local function show_active(player, party)
	local name = player:get_player_name()
	local lines = {}
	for _, who in ipairs(party_members(party)) do
		local status = (who == party.leader) and " (guía)" or ""
		if who == party.seal_carrier and party.seal_claimed and not party.sigil_delivered then
			status = status .. " · lleva el sello"
		end
		lines[#lines + 1] = "- " .. who .. status
	end
	local fs = {
		frame(12.5, 8.2),
		("label[0.6,0.5;EXPEDICIÓN #%d · EL SELLO DE LAS RUINAS]"):format(party.id or 1),
		("hypertext[0.6,1.1;11.0,1.5;stage;%s]"):format(rich(stage_text(party))),
		("label[0.6,2.7;Participantes (%d/%d)"):format(member_count(party), MAX_MEMBERS),
		("hypertext[0.6,3.15;5.2,2.2;members;%s]"):format(rich(table.concat(lines, "\n"))),
	}
	if party.leader == name then
		local candidates = free_players(party)
		fs[#fs + 1] = "label[6.6,2.7;Invitar jugadores conectados]"
		if #candidates == 0 then
			fs[#fs + 1] = "label[6.6,3.15;No hay jugadores disponibles.]"
		else
			for i, candidate in ipairs(candidates) do
				if i > 3 then break end
				local label = candidate
				if #label > 20 then label = label:sub(1, 20) end
				fs[#fs + 1] = ("button[6.6,%s;4.8,0.62;invite_%d;Invitar a %s]"):format(
					3.15 + (i - 1) * 0.72, i, escape(label))
			end
		end
	else
		fs[#fs + 1] = "label[6.6,2.7;Tu misión]"
		fs[#fs + 1] = ("hypertext[6.6,3.15;5.0,2.2;help;%s]"):format(rich(
			"Compartes el progreso con el grupo. Si el guía se desconecta, la misión no se pierde."))
	end
	if party.stage ~= "done" then
		fs[#fs + 1] = "button[0.6,6.45;4.2,0.75;deliver;Entregar el sello]"
		fs[#fs + 1] = "button[5.2,6.45;3.2,0.75;help;Cómo llegar]"
		fs[#fs + 1] = "button_exit[8.8,6.45;2.8,0.75;close;Cerrar]"
	else
		fs[#fs + 1] = "button_exit[0.6,6.45;3.2,0.75;close;Cerrar]"
	end
	core.show_formspec(name, FORM_NPC, table.concat(fs))
end

function Q.show_npc(player)
	if not player or not player:is_player() then return end
	local name = player:get_player_name()
	if not state then show_error(player); return end
	local party = state.party
	if not party then show_start(player); return end
	if member(party, name) then
		show_active(player, party)
		return
	end
	if pending_invite(name) then
		show_invite(player, party)
		return
	end
	core.show_formspec(name, FORM_NPC, table.concat({
		frame(10.5, 4.8),
		"label[0.6,0.5;MAESTRA DE EXPEDICIONES]",
		("hypertext[0.6,1.15;9.2,2.1;busy;%s]"):format(rich(
			("Ya dirijo la expedición #%d de %s. Pídele al guía que te invite desde esta ventana."):format(
				party.id or 1, party.leader or "otro jugador"))),
		"button_exit[0.6,3.8;3.2,0.7;close;Cerrar]",
	}))
end

local function show_completion(player, party)
	local name = player:get_player_name()
	core.show_formspec(name, FORM_COMPLETE, table.concat({
		frame(10.5, 5.6),
		"label[0.6,0.5;EL SELLO DE LAS RUINAS]",
		("hypertext[0.6,1.15;9.3,2.8;done;%s]"):format(rich(
			("La cripta vuelve a estar en silencio. El sello está a salvo.\n\nEntrega registrada por: %s.\n\nRecompensa del grupo: 8 lingotes de hierro, 3 de oro y 6 panes. Cada participante la recibe una sola vez."):format(
				party.delivered_by or name))),
		"button_exit[0.6,4.65;3.2,0.7;close;Cerrar]",
	}))
end

local function reward_member(party, name)
	if not party or party.rewarded[name] then return false end
	local player = online(name)
	if not player then return false end
	-- Mark before handing out the items.  A crash may lose a reward, but it can
	-- never duplicate one; this is the same one-shot policy as the seal.
	party.rewarded[name] = true
	save()
	give(player, "mcl_core:iron_ingot", 8)
	give(player, "mcl_core:gold_ingot", 3)
	give(player, "mcl_farming:bread", 6)
	tell(name, "Recompensa recibida: 8 lingotes de hierro, 3 de oro y 6 panes.")
	return true
end

local function notify_completion(party)
	for _, name in ipairs(party_members(party)) do
		local player = online(name)
		if player then
			if not party.notified[name] then
				party.notified[name] = true
				tell(name, "La expedición ha entregado el sello. ¡Misión completada!")
				show_completion(player, party)
			end
			reward_member(party, name)
		end
	end
	save()
	refresh_all_huds()
end

function Q.start(player)
	if not state then tell(player:get_player_name(), "El registro de expediciones no está disponible."); return false end
	local name = player:get_player_name()
	if state.party then
		if member(state.party, name) then Q.show_npc(player); return false end
		tell(name, "La Maestra ya dirige otra expedición. Pide una invitación al guía.")
		Q.show_npc(player)
		return false
	end
	local party = {
		id = state.next_id,
		version = 1,
		leader = name,
		members = {[name] = true},
		order = {name},
		stage = "prepared",
		created_at = now(),
		updated_at = now(),
		encounters = {},
		seal_claimed = false,
		sigil_delivered = false,
		rewarded = {},
		notified = {},
	}
	state.next_id = state.next_id + 1
	state.party = party
	state.invites = {}
	save()
	ensure_kit(player)
	tell(name, ("Has iniciado la expedición #%d. Invita a tus compañeros desde la Maestra; la piedra de viaje está junto al campamento."):format(party.id))
	refresh_hud(name)
	show_active(player, party)
	return true
end

function Q.invite(actor, target_name)
	if not state or not state.party then return false end
	local name = actor:get_player_name()
	local party = state.party
	if party.leader ~= name then tell(name, "Solo el guía puede invitar."); return false end
	if party.stage == "done" then tell(name, "La expedición ya ha terminado."); return false end
	local target = online(target_name)
	if not target then tell(name, "Ese jugador no está conectado."); return false end
	if member(party, target_name) then tell(name, "Ese jugador ya está en la expedición."); return false end
	if current_party_for(target_name) then tell(name, "Ese jugador ya participa en otra expedición."); return false end
	if member_count(party) >= MAX_MEMBERS then tell(name, "La expedición ya está completa."); return false end
	if pending_invite(target_name) then tell(name, "Ese jugador ya tiene una invitación."); return false end
	state.invites[target_name] = {party = party.id, at = now(), by = name}
	save()
	tell(name, "Invitación enviada a " .. target_name .. ".")
	tell(target_name, name .. " te ha invitado a «El sello de las ruinas».")
	show_invite(target, party)
	show_active(actor, party)
	return true
end

function Q.accept(player, party_id)
	if not state or not state.party then return false end
	local name = player:get_player_name()
	local party = state.party
	local invite = state.invites[name]
	if not invite or invite.party ~= party.id or not pending_invite(name) then
		tell(name, "La invitación ya no está disponible.")
		return false
	end
	if member_count(party) >= MAX_MEMBERS then
		tell(name, "La expedición ya está completa.")
		return false
	end
	party.members[name] = true
	party.order[#party.order + 1] = name
	party.updated_at = now()
	state.invites[name] = nil
	ensure_kit(player)
	save()
	tell(name, ("Te has unido a la expedición #%d de %s."):format(party.id, party.leader))
	broadcast(party, name .. " se ha unido a la expedición.")
	refresh_hud(name)
	show_active(player, party)
	return true
end

function Q.decline(player)
	if not state then return false end
	local name = player:get_player_name()
	if not state.invites[name] then return false end
	state.invites[name] = nil
	save()
	tell(name, "Has rechazado la invitación.")
	if state.party then
		tell(state.party.leader, name .. " ha rechazado la invitación.")
	end
	return true
end

local function top_node(pos)
	return {x = pos.x, y = pos.y + 1, z = pos.z}
end

local function set_pedestal_top(taken)
	if not site or not manifest or not manifest.pedestal then return end
	local top = site.pedestal and site.pedestal.top
	if not top then
		local p = manifest.pedestal.top
		top = {x = site.anchor.x + p[1], y = site.anchor.y + p[2], z = site.anchor.z + p[3]}
	end
	core.set_node(top, {name = taken and "everforge:ruin_pedestal_empty" or "everforge:ruin_pedestal_top"})
end

function Q.deliver(player)
	if not state or not state.party then tell(player:get_player_name(), "No tienes una expedición activa."); return false end
	local name = player:get_player_name()
	local party = state.party
	if not member(party, name) then tell(name, "No participas en esta expedición."); return false end
	if party.sigil_delivered then tell(name, "El sello ya fue entregado."); Q.show_npc(player); return false end
	if party.stage ~= "return" then
		tell(name, "Todavía no llevas el sello. Está en la cámara del fondo de la cripta.")
		Q.show_npc(player)
		return false
	end
	if not has_item(player, SIGIL) then
		tell(name, "Necesitas llevar el Sello de las Ruinas en el inventario para entregarlo.")
		Q.show_npc(player)
		return false
	end
	if not take_item(player, SIGIL, 1) then
		tell(name, "No se pudo entregar el sello.")
		return false
	end
	party.sigil_delivered = true
	party.stage = "done"
	party.completed_at = now()
	party.delivered_by = name
	party.updated_at = now()
	save()
	notify_completion(party)
	refresh_all_huds()
	return true
end

-- ---------------------------------------------------------------------------
-- Persistent world markers
-- ---------------------------------------------------------------------------

local function set_waystone(pos, kind)
	if not pos then return end
	local floor = {x = pos.x, y = pos.y - 1, z = pos.z}
	if core.get_node(floor).name == "air" or core.get_node(floor).name == "ignore" then
		core.set_node(floor, {name = "mcl_core:stonebrick"})
	end
	core.set_node(pos, {name = "everforge:waystone"})
	core.set_node(top_node(pos), {name = "everforge:waystone_top"})
	local meta = core.get_meta(pos)
	meta:set_string("kind", kind or "return")
	local top_meta = core.get_meta(top_node(pos))
	top_meta:set_string("kind", kind or "return")
end

local function waystone_exists(pos)
	if not pos then return false end
	local name = core.get_node(pos).name
	return name == "everforge:waystone" or name == "everforge:waystone_top"
end

local function pedestal_exists(pos)
	if not pos then return false end
	local name = core.get_node(pos).name
	return name == "everforge:ruin_pedestal" or name == "everforge:ruin_pedestal_empty"
end

local function world(local_pos)
	if not site or type(local_pos) ~= "table" then return nil end
	return {
		x = site.anchor.x + local_pos[1],
		y = site.anchor.y + local_pos[2],
		z = site.anchor.z + local_pos[3],
	}
end

local function seed_chest(pos, items)
	if not pos then return end
	local meta = core.get_meta(pos)
	if meta:get_int("everforge:sello_loot") == 1 then return end
	local name = core.get_node(pos).name
	if name ~= "mcl_chests:chest_small" then
		core.set_node(pos, {name = "mcl_chests:chest_small", param2 = 0})
		local def = core.registered_nodes["mcl_chests:chest_small"]
		if def and def.on_construct then def.on_construct(pos) end
		meta = core.get_meta(pos)
	end
	local inv = meta:get_inventory()
	if inv and inv:get_size("main") == 0 then inv:set_size("main", 16) end
	if inv then
		for _, item in ipairs(items or {}) do
			inv:add_item("main", ItemStack(item))
		end
	end
	meta:set_int("everforge:sello_loot", 1)
	meta:set_string("infotext", "")
end

local function seed_supply(pos)
	if not pos then return end
	local meta = core.get_meta(pos)
	if meta:get_int("everforge:sello_supply") == 1 then return end
	local name = core.get_node(pos).name
	if name ~= "mcl_chests:chest_small" then
		core.set_node(pos, {name = "mcl_chests:chest_small", param2 = 0})
		local def = core.registered_nodes["mcl_chests:chest_small"]
		if def and def.on_construct then def.on_construct(pos) end
		meta = core.get_meta(pos)
	end
	local inv = meta:get_inventory()
	if inv and inv:get_size("main") == 0 then inv:set_size("main", 16) end
	if inv then
		inv:add_item("main", ItemStack("mcl_tools:sword_stone 1"))
		inv:add_item("main", ItemStack("mcl_torches:torch 16"))
		inv:add_item("main", ItemStack("mcl_farming:bread 6"))
		inv:add_item("main", ItemStack("mcl_core:cobble 24"))
	end
	meta:set_int("everforge:sello_supply", 1)
	meta:set_string("infotext", "")
end

local function initialize_doors()
	if not site then return end
	local anchor = site.anchor
	local minp = {x = anchor.x, y = anchor.y, z = anchor.z}
	local maxp = {x = anchor.x + manifest.size[1] - 1, y = anchor.y + manifest.size[2] - 1, z = anchor.z + manifest.size[3] - 1}
	core.load_area(minp, maxp)
	local names = {}
	for name in pairs(core.registered_nodes) do
		if name:match("^mcl_doors:door_") and (name:match("_b_[12]$") or name:match("_t_[12]$")) then
			names[#names + 1] = name
		end
	end
	if #names == 0 then return end
	local found = core.find_nodes_in_area(minp, maxp, names, true)
	for _, positions in pairs(found or {}) do
		if type(positions) == "table" then
			for _, pos in ipairs(positions) do
				local meta = core.get_meta(pos)
				meta:set_int("is_open", 0)
				meta:set_int("is_mirrored", 0)
				meta:set_string("doors_owner", "")
			end
		end
	end
end

function Q.arm_site(opts)
	if type(opts) ~= "table" or type(opts.anchor) ~= "table" then return false end
	local prepared = site and site.prepared or false
	site = {
		version = 1,
		prepared = prepared,
		anchor = {x = opts.anchor.x, y = opts.anchor.y, z = opts.anchor.z},
		trailhead = opts.trailhead,
		camp = opts.camp,
		camp_stone = opts.camp_stone,
		camp_chest = opts.camp_chest,
		trail_stone = opts.trail_stone,
		camp_center = opts.camp_center,
	}
	save_site()
	return true
end

function Q.setup_site()
	if not site or not manifest then return false end
	if manifest.size and site.anchor then
		-- Custom nodes are placed after the schematic so they cannot be
		-- overwritten by the MTS writer or by a later schematic edit.
		local base = world(manifest.pedestal.base)
		local top = world(manifest.pedestal.top)
		site.pedestal = {base = base, top = top}
		if not pedestal_exists(base) then
			core.set_node(base, {name = "everforge:ruin_pedestal"})
		end
		if not pedestal_exists(top) then
			local taken = state and state.party and state.party.seal_claimed
			core.set_node(top, {name = taken and "everforge:ruin_pedestal_empty" or "everforge:ruin_pedestal_top"})
		end
		for _, local_pos in ipairs(manifest.return_stones or {}) do
			local pos = world(local_pos)
			if not waystone_exists(pos) then set_waystone(pos, "return") end
		end
		if site.trail_stone and not waystone_exists(site.trail_stone) then
			set_waystone(site.trail_stone, "return")
		end
		for _, loot in ipairs(manifest.loot or {}) do
			seed_chest(world(loot.pos), loot.items)
		end
		initialize_doors()
	end
	site.prepared = true
	save_site()
	return true
end

function Q.ensure_runtime()
	if not site or not site.prepared or not manifest then return false end
	if site.trail_stone and not waystone_exists(site.trail_stone) then set_waystone(site.trail_stone, "return") end
	if site.camp_stone and not waystone_exists(site.camp_stone) then set_waystone(site.camp_stone, "camp") end
	if site.pedestal then
		if not pedestal_exists(site.pedestal.base) then
			core.set_node(site.pedestal.base, {name = "everforge:ruin_pedestal"})
		end
		local taken = state and state.party and state.party.seal_claimed
		local top_name = core.get_node(site.pedestal.top).name
		if taken and top_name ~= "everforge:ruin_pedestal_empty" then
			core.set_node(site.pedestal.top, {name = "everforge:ruin_pedestal_empty"})
		elseif not taken and top_name ~= "everforge:ruin_pedestal_top" then
			core.set_node(site.pedestal.top, {name = "everforge:ruin_pedestal_top"})
		end
	end
	for _, local_pos in ipairs(manifest.return_stones or {}) do
		local pos = world(local_pos)
		if not waystone_exists(pos) then set_waystone(pos, "return") end
	end
	return true
end

function Q.setup_camp(center)
	if not site or not center then return false end
	if E and E.ensure_npc then
		local ok, found = pcall(E.ensure_npc)
		if not ok then core.log("error", "[Everforge] NPC check failed: " .. tostring(found)) end
	end
	if E and E.setup_camp then
		local ok, spawned = pcall(E.setup_camp, center)
		if not ok then core.log("error", "[Everforge] NPC setup failed: " .. tostring(spawned)) end
	end
	if site.camp_stone and not waystone_exists(site.camp_stone) then
		set_waystone(site.camp_stone, "camp")
	end
	if site.camp_chest then seed_supply(site.camp_chest) end
	return true
end

function Q.is_armed()
	return site ~= nil and site.prepared == true and manifest ~= nil
end

function Q.is_configured()
	return site ~= nil
end

-- ---------------------------------------------------------------------------
-- Waystone travel and the seal pedestal
-- ---------------------------------------------------------------------------

local function safe_target(pos)
	if type(pos) ~= "table" then return nil end
	for dy = 0, 3 do
		local feet = {x = pos.x, y = pos.y + dy, z = pos.z}
		local head = {x = pos.x, y = pos.y + dy + 1, z = pos.z}
		local floor = {x = pos.x, y = pos.y + dy - 1, z = pos.z}
		local floor_def = core.registered_nodes[core.get_node(floor).name]
		local feet_def = core.registered_nodes[core.get_node(feet).name]
		if floor_def and floor_def.walkable and feet_def and not feet_def.walkable
			and core.get_node(head).name == "air" then
			return feet
		end
	end
	return {x = pos.x, y = pos.y, z = pos.z}
end

local function teleport(player, target, yaw)
	if not target then return false end
	core.load_area({x = target.x - 2, y = target.y - 2, z = target.z - 2},
		{x = target.x + 2, y = target.y + 3, z = target.z + 2})
	local pos = safe_target(target)
	player:set_pos(pos)
	if yaw then player:set_look_horizontal(yaw) end
	return true
end

function Q.travel(player, kind)
	if not state or not site then return false end
	local name = player:get_player_name()
	local party = state.party
	if kind == "camp" then
		if not party or not member(party, name) then
			tell(name, "La piedra no responde. Primero habla con la Maestra y empieza una expedición.")
			return false
		end
		if party.stage == "done" then
			tell(name, "La expedición ya ha terminado. La Maestra te espera en el campamento.")
			return false
		end
		if not has_sword(player) then
			tell(name, "La Maestra no te dejará partir sin una espada. Pídesela o coge la del cofre del campamento.")
			return false
		end
		if teleport(player, site.trailhead, 0) then
			if party.stage == "prepared" then
				party.stage = "explore"
				party.updated_at = now()
				save()
				broadcast(party, "El grupo ha llegado a la fortaleza. La escalera del patio oeste baja a la cripta.")
				refresh_all_huds()
			end
			tell(name, "Has llegado al inicio del sendero. La fortaleza está al sur, 25 pasos más adelante.")
			return true
		end
		return false
	end
	if teleport(player, site.camp, math.pi) then
		tell(name, "La piedra te devuelve al campamento.")
		return true
	end
	return false
end

local function give_seal(player)
	if not state or not state.party then
		tell(player:get_player_name(), "El pedestal está vacío y frío.")
		return false
	end
	local name = player:get_player_name()
	local party = state.party
	if not member(party, name) then
		tell(name, "El sello no te reconoce. No participas en esta expedición.")
		return false
	end
	if party.sigil_delivered or party.stage == "done" then
		tell(name, "El sello ya ha sido entregado. El pedestal está vacío.")
		return false
	end
	if party.stage ~= "explore" and party.stage ~= "return" then
		tell(name, "El sello duerme. Aún no has llegado a la fortaleza.")
		return false
	end
	if party.seal_claimed then
		if party.seal_carrier ~= name then
			tell(name, ("El sello ya lo lleva %s. Vuelve al campamento y entrégalo."):format(party.seal_carrier or "otro miembro"))
			return false
		end
		if has_item(player, SIGIL) then
			tell(name, "Ya llevas el Sello de las Ruinas. Vuelve al campamento.")
			return false
		end
		give(player, SIGIL, 1)
		tell(name, "El sello vuelve a tu mano. No lo pierdas esta vez.")
		return true
	end
	local inv = player:get_inventory()
	if inv and not inv:room_for_item("main", ItemStack(SIGIL .. " 1")) then
		tell(name, "No tienes espacio en el inventario para el sello. Libera un hueco y vuelve a intentarlo.")
		return false
	end
	give(player, SIGIL, 1)
	party.seal_claimed = true
	party.seal_carrier = name
	party.stage = "return"
	party.updated_at = now()
	save()
	set_pedestal_top(true)
	broadcast(party, ("%s ha tomado el Sello de las Ruinas. Vuelve al campamento y entrégalo a la Maestra."):format(name))
	refresh_all_huds()
	return true
end

core.register_craftitem(SIGIL, {
	description = "Sello de las Ruinas",
	inventory_image = "default_diamond.png^[colorize:#6d45ba:185",
	wield_image = "default_diamond.png^[colorize:#6d45ba:185",
	stack_max = 1,
	groups = {quest_item = 1},
	on_use = function(itemstack, user)
		if user and user:is_player() then
			tell(user:get_player_name(), "El sello late suavemente. Debe volver a la Maestra del campamento.")
		end
		return itemstack
	end,
})

local function waystone_on_rightclick(pos, _, clicker)
	if not clicker or not clicker:is_player() then return end
	local kind = core.get_meta(pos):get_string("kind")
	if kind == "" then
		local below = {x = pos.x, y = pos.y - 1, z = pos.z}
		kind = core.get_meta(below):get_string("kind")
	end
	Q.travel(clicker, kind ~= "" and kind or "return")
end

core.register_node("everforge:waystone", {
	description = "Piedra de viaje",
	tiles = {
		"mcl_core_stonebrick_carved.png^[colorize:#2C536E:150",
		"mcl_core_stonebrick_carved.png^[colorize:#2C536E:150",
		"mcl_core_stonebrick_carved.png^[colorize:#2C536E:150",
		"mcl_core_stonebrick_carved.png^[colorize:#2C536E:150",
		"mcl_core_stonebrick_carved.png^[colorize:#6AC7D9:170",
		"mcl_core_stonebrick_carved.png^[colorize:#2C536E:150",
	},
	groups = {cracky = 1, not_in_creative_inventory = 1},
	is_ground_content = false,
	light_source = 7,
	paramtype2 = "facedir",
	on_rightclick = waystone_on_rightclick,
	can_dig = function() return false end,
	drop = "",
})

core.register_node("everforge:waystone_top", {
	description = "Piedra de viaje",
	tiles = {"mcl_core_stonebrick_carved.png^[colorize:#6AC7D9:180"},
	groups = {cracky = 1, not_in_creative_inventory = 1},
	is_ground_content = false,
	light_source = 10,
	on_rightclick = waystone_on_rightclick,
	can_dig = function() return false end,
	drop = "",
})

core.register_node("everforge:ruin_pedestal", {
	description = "Pedestal del sello",
	tiles = {
		"mcl_core_stonebrick_carved.png^[colorize:#3A3145:120",
		"mcl_core_stonebrick_carved.png^[colorize:#3A3145:120",
		"mcl_core_stonebrick_carved.png^[colorize:#3A3145:120",
		"mcl_core_stonebrick_carved.png^[colorize:#3A3145:120",
		"mcl_core_stonebrick_carved.png^[colorize:#9B7BC4:120",
		"mcl_core_stonebrick_carved.png^[colorize:#3A3145:120",
	},
	groups = {cracky = 1, not_in_creative_inventory = 1},
	is_ground_content = false,
	light_source = 6,
	on_rightclick = function(_, _, clicker)
		if clicker and clicker:is_player() then give_seal(clicker) end
	end,
	can_dig = function() return false end,
	drop = "",
})

core.register_node("everforge:ruin_pedestal_top", {
	description = "Sello de las Ruinas",
	tiles = {"default_diamond_block.png^[colorize:#6d45ba:170"},
	groups = {cracky = 1, not_in_creative_inventory = 1},
	is_ground_content = false,
	light_source = 12,
	on_rightclick = function(_, _, clicker)
		if clicker and clicker:is_player() then give_seal(clicker) end
	end,
	can_dig = function() return false end,
	drop = "",
})

core.register_node("everforge:ruin_pedestal_empty", {
	description = "Pedestal vacío",
	tiles = {"mcl_core_stonebrick_carved.png^[colorize:#25212B:150"},
	groups = {cracky = 1, not_in_creative_inventory = 1},
	is_ground_content = false,
	light_source = 1,
	on_rightclick = function(_, _, clicker)
		if clicker and clicker:is_player() then give_seal(clicker) end
	end,
	can_dig = function() return false end,
	drop = "",
})

-- ---------------------------------------------------------------------------
-- Encounter director
-- ---------------------------------------------------------------------------

local function spawn_room(party, room)
	local center = world(room.center)
	local count = 1
	if member_count(party) >= 2 then count = count + 1 end
	if room.final then count = count + 1 end
	count = math.min(count, 3)
	local spawned = 0
	local positions = room.spawns or {}
	for i = 1, math.min(count, #positions) do
		local pos = world(positions[i])
		local node = core.get_node(pos)
		local head = core.get_node({x = pos.x, y = pos.y + 1, z = pos.z})
		local floor = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z})
		local floor_def = core.registered_nodes[floor.name]
		if node.name == "air" and head.name == "air"
			and floor_def and floor_def.walkable and (floor_def.liquidtype or "none") == "none" then
			local mob = room.mobs[((i - 1) % #room.mobs) + 1]
			local object = core.add_entity(pos, mob)
			if object then
				local ent = object:get_luaentity()
				if ent then
					ent.everforge_dungeon = true
					ent.persistent = true
					ent.can_despawn = false
				end
				spawned = spawned + 1
			end
		end
	end
	if spawned > 0 then
		broadcast(party, room.hint or "Los guardianes han despertado.")
		log(("Encounter %s: %d mobs spawned for party %d"):format(room.id, spawned, party.id))
	end
end

local scan_elapsed = 0
local function director_step(dt)
	scan_elapsed = scan_elapsed + dt
	if scan_elapsed < 1.0 then return end
	scan_elapsed = 0
	if not state or not state.party or not manifest then return end
	local party = state.party
	party.encounters = party.encounters or {}
	if party.stage ~= "explore" and party.stage ~= "return" then return end
	for _, room in ipairs(manifest.rooms or {}) do
		if not party.encounters[room.id] then
			local center = world(room.center)
			for _, name in ipairs(party_members(party)) do
				local player = online(name)
				if player then
					local pos = player:get_pos()
					if pos and math.abs(pos.y - center.y) <= 6
						and vector.distance(pos, center) <= (room.radius or 8) then
						party.encounters[room.id] = true
						party.updated_at = now()
						save()
						spawn_room(party, room)
						break
					end
				end
			end
		end
	end
end

core.register_globalstep(director_step)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == FORM_NPC then
		if fields.start then
			Q.start(player)
		elseif fields.deliver then
			Q.deliver(player)
		elseif fields.help then
			local name = player:get_player_name()
			tell(name, "El sendero sale del campamento hacia el sur. Entra por la puerta norte de la fortaleza, cruza el patio y baja por la escalera del oeste. La cámara del sello está al fondo de la cripta.")
		elseif fields.invite_1 or fields.invite_2 or fields.invite_3 then
			local index = fields.invite_1 and 1 or (fields.invite_2 and 2 or 3)
			local party = current_party_for(player:get_player_name())
			if party then
				local candidates = free_players(party)
				local target = candidates[index]
				if target then Q.invite(player, target) end
			end
		end
	elseif formname == FORM_INVITE then
		if fields.accept and state and state.party then
			Q.accept(player, state.party.id)
		elseif fields.decline then
			Q.decline(player)
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Login, HUD and pending state
-- ---------------------------------------------------------------------------

local function on_join(player)
	if not player or not player:is_valid() then return end
	local name = player:get_player_name()
	if not state then return end
	local party = current_party_for(name)
	if party then
		if party.stage == "done" then
			if not party.rewarded[name] then reward_member(party, name) end
			if not party.notified[name] then
				party.notified[name] = true
				save()
				show_completion(player, party)
			end
			refresh_hud(name)
		else
			refresh_hud(name)
			tell(name, stage_text(party))
		end
		return
	end
	local pending = pending_invite(name)
	if pending then
		core.after(1.5, function()
			local current = online(name)
			if current then show_invite(current, pending) end
		end)
	end
end

core.register_on_joinplayer(function(player)
	core.after(1, function()
		if player and player:is_valid() then on_join(player) end
	end)
	if site and site.prepared and E and E.ensure_npc then
		core.after(1, function() pcall(E.ensure_npc) end)
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if hud_ids[name] then
		player:hud_remove(hud_ids[name])
		hud_ids[name] = nil
	end
end)

core.register_on_mods_loaded(function()
	core.after(2, function()
		if site and site.prepared and E and E.ensure_npc then pcall(E.ensure_npc) end
	end)
end)

everforge.ruins_quest = Q
return Q
