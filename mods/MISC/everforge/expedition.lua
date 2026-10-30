-- SPDX-License-Identifier: GPL-3.0-or-later
-- Cooperative expedition prototype: one camp NPC, invitations, a shared sword
-- delivery mission and persistent group progress kept in Everforge mod storage.
local modname = core.get_current_modname()
local path = core.get_modpath(modname)
local M = dofile(path .. "/expedition_model.lua")
local storage = core.get_mod_storage()

local E = {
	model = M,
	npc_name = "everforge:expedition_npc",
	state_key = "everforge:expeditions:v1",
	npc_key = "everforge:expedition_npc:v1",
	invite_ttl = 300,
}
everforge.expedition = E

local FORM_NPC = "everforge:expedition_npc"
local FORM_INVITE = "everforge:expedition_invite"
local FORM_COMPLETE = "everforge:expedition_complete"
local state, load_attempted, state_valid
local hud_ids = {}
local ui_invites = {}

local function now()
	return os.time()
end

local function log_error(message)
	core.log("error", "[Everforge] " .. message)
end

local function get_state()
	if load_attempted then return state end
	load_attempted = true
	local raw = storage:get_string(E.state_key)
	if raw == "" then
		state = M.new_state()
		state_valid = true
		return state
	end
	local ok, parsed = pcall(core.parse_json, raw)
	if ok and M.valid_state(parsed) then
		state = parsed
		state_valid = true
		return state
	end
	-- Corrupt or newer data is never silently replaced by an empty table.
	state_valid = false
	log_error("Invalid expedition storage; it is preserved and expedition actions are disabled")
	return nil
end

state = get_state()

local function save()
	if not state or not state_valid then return false end
	local ok, result = pcall(function()
		return storage:set_string(E.state_key, core.write_json(state))
	end)
	if not ok or result == false then
		log_error("Could not save expedition storage")
		return false
	end
	return true
end

local function online(name)
	return core.get_player_by_name(name)
end

local function tell(name, message)
	if not online(name) then return end
	core.chat_send_player(name, "[Everforge] " .. message)
end

local function broadcast(exp, message)
	for _, name in ipairs(exp.order) do
		tell(name, message)
	end
end

local function status_text(exp)
	local sword = exp.progress.sword_found and "conseguida" or "pendiente"
	local delivery = exp.progress.delivered and "completada" or "pendiente"
	return ("Espada: %s · Entrega: %s"):format(sword, delivery)
end

local function hud_text(exp)
	local sword = exp.progress.sword_found and "sí" or "pendiente"
	local delivery = exp.progress.delivered and "completada" or "pendiente"
	return ("Expedición #%d · espada: %s · entrega: %s"):format(exp.id, sword, delivery)
end

local function refresh_hud(name)
	local player = online(name)
	if not player then return end
	local exp = state and M.find_active_for(state, name)
	local id = hud_ids[name]
	if not exp then
		if id then
			player:hud_remove(id)
			hud_ids[name] = nil
		end
		return
	end
	local text = hud_text(exp)
	if id then
		player:hud_change(id, "text", text)
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

local function refresh_online_huds()
	for _, player in ipairs(core.get_connected_players()) do
		refresh_hud(player:get_player_name())
	end
end

local function clear_invites_for(player_name)
	if not state then return false end
	local changed = false
	for _, exp in pairs(state.expeditions) do
		if exp.invites[player_name] then
			exp.invites[player_name] = nil
			changed = true
		end
	end
	return changed
end

local function last_completed_for(name)
	if not state then return nil end
	local best
	for _, exp in pairs(state.expeditions) do
		if exp.status == "completed" and exp.members[name]
			and (not best or (exp.completed_at or 0) > (best.completed_at or 0)) then
			best = exp
		end
	end
	return best
end

local function sword_slot(player)
	if not player or not player:is_player() then return nil end
	local inventory = player:get_inventory()
	if not inventory then return nil end
	local list = inventory:get_list("main")
	if not list then return nil end
	for index, stack in ipairs(list) do
		if not stack:is_empty() and core.get_item_group(stack:get_name(), "sword") > 0 then
			return inventory, index, stack
		end
	end
	return nil
end

function E.has_sword(player)
	return sword_slot(player) ~= nil
end

-- ---------------------------------------------------------------------------
-- Presentation helpers
-- ---------------------------------------------------------------------------
local function escape(text)
	return core.formspec_escape(tostring(text or ""))
end

local function rich(text)
	return core.formspec_escape("<global margin=0 valign=top><style color=#F2E8D9>"
		.. core.hypertext_escape(tostring(text or "")) .. "</style>")
end

local function frame(width, height)
	return table.concat({
		("formspec_version[7]size[%s,%s]"):format(width, height),
		"bgcolor[#08090BEF;true]",
		("background9[0,0;%s,%s;everforge_ui_panel.png;false;8]"):format(width, height),
		"style_type[label;textcolor=#F2E8D9]",
		"style_type[hypertext;textcolor=#F2E8D9]",
		"style_type[button,button_exit;textcolor=#FFF1DC;border=false;bgimg=everforge_ui_button.png;bgimg_pressed=everforge_ui_button_pressed.png;bgimg_middle=4;font=bold]",
		"style_type[button:hovered,button_exit:hovered;bgimg=everforge_ui_button_hover.png]",
	})
end

function E.show_completion(player, exp)
	local members = {}
	for _, name in ipairs(exp.order) do
		members[#members + 1] = name
	end
	local fs = {
		frame(9, 5.6),
		"label[0.6,0.5;EXPEDICIÓN COMPLETADA]",
		("hypertext[0.6,1.15;7.8,1.7;desc;%s]"):format(rich(
			("La expedición #%d ha entregado la espada a la maestra. El progreso queda guardado para todo el grupo.")
				:format(exp.id))),
		("label[0.6,3.0;Entregada por: %s]"):format(escape(exp.progress.delivered_by or "?")),
		("hypertext[0.6,3.4;7.8,0.9;members;%s]"):format(rich(
			"Participantes: " .. table.concat(members, ", "))),
		"button_exit[0.6,4.55;3.4,0.75;close;Cerrar]",
	}
	core.show_formspec(player:get_player_name(), FORM_COMPLETE, table.concat(fs))
end

function E.show_invite(player, exp)
	local name = player:get_player_name()
	local invite = exp.invites[name]
	local age = invite and (now() - invite.at) or nil
	if exp.status ~= "active" or not age or age < 0 or age > E.invite_ttl then
		tell(name, "La invitación ya no está disponible.")
		return
	end
	local fs = {
		frame(8.5, 4.8),
		"label[0.6,0.5;INVITACIÓN A UNA EXPEDICIÓN]",
		("hypertext[0.6,1.1;7.3,1.65;desc;%s]"):format(rich(
			("%s te invita a la expedición #%d. Misión de prueba: consigue una espada y entrégala a la maestra del campamento.")
				:format(exp.leader, exp.id))),
		("button[0.6,3.55;3.3,0.75;accept_%d;Aceptar]"):format(exp.id),
		("button_exit[4.2,3.55;3.3,0.75;decline_%d;Rechazar]"):format(exp.id),
	}
	core.show_formspec(name, FORM_INVITE, table.concat(fs))
end

local function member_lines(exp)
	local lines = {}
	for _, name in ipairs(exp.order) do
		local marker = online(name) and "en línea" or "desconectado"
		local role = name == exp.leader and " · líder" or ""
		lines[#lines + 1] = ("%s (%s)%s"):format(name, marker, role)
	end
	if next(exp.invites) then
		local invited = {}
		for name in pairs(exp.invites) do invited[#invited + 1] = name end
		table.sort(invited)
		lines[#lines + 1] = "Invitaciones pendientes: " .. table.concat(invited, ", ")
	end
	return table.concat(lines, "\n")
end

local function free_players(exp)
	local result = {}
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		if name ~= exp.leader and not exp.members[name] and not exp.invites[name]
			and not M.find_active_for(state, name)
			and not M.pending_invite(state, name, now(), E.invite_ttl) then
			result[#result + 1] = name
		end
	end
	table.sort(result)
	return result
end

function E.show_npc(player)
	local name = player:get_player_name()
	if not state then
		core.show_formspec(name, FORM_NPC, table.concat({
			frame(9, 3.8),
			"label[0.6,0.5;MAESTRA DE EXPEDICIONES]",
			"hypertext[0.6,1.1;7.8,1.2;desc;" .. rich(
				"El registro de expediciones no está disponible. No se ha modificado ningún dato; consulta el registro del servidor.")
				.. "]",
			"button_exit[0.6,2.75;3.2,0.7;close;Cerrar]",
		}))
		return
	end

	local exp = M.find_active_for(state, name)
	if not exp then
		local invited_exp = M.pending_invite(state, name, now(), E.invite_ttl)
		if invited_exp then
			E.show_invite(player, invited_exp)
			return
		end
		local last = last_completed_for(name)
		local intro = "Organizo expediciones cooperativas desde este campamento. Cada grupo comparte una misión de prueba: conseguir una espada y entregarla aquí."
		if last then
			intro = intro .. ("\n\nÚltima expedición completada: #%d."):format(last.id)
		end
		local fs = {
			frame(10.5, 5.5),
			"label[0.6,0.5;MAESTRA DE EXPEDICIONES]",
			("hypertext[0.6,1.15;9.3,1.9;desc;%s]"):format(rich(intro)),
			"label[0.6,3.25;No tienes una expedición activa.]",
			"button[0.6,4.25;4.4,0.8;start;Iniciar expedición]",
			"button_exit[5.2,4.25;3.2,0.8;close;Cerrar]",
		}
		core.show_formspec(name, FORM_NPC, table.concat(fs))
		return
	end

	local fs = {
		frame(11, 7.3),
		("label[0.6,0.5;EXPEDICIÓN #%d]"):format(exp.id),
		("hypertext[0.6,1.1;9.8,1.45;desc;%s]"):format(rich(
			"Misión de prueba: consigue una espada y entrégala a la maestra. El progreso es compartido y se conserva al desconectarse.")),
		("label[0.6,2.65;%s]"):format(escape(status_text(exp))),
		"label[0.6,3.15;Participantes]",
		("hypertext[0.6,3.55;4.8,2.15;members;%s]"):format(rich(member_lines(exp))),
	}

	ui_invites[name] = nil
	if exp.leader == name then
		local candidates = free_players(exp)
		fs[#fs + 1] = "label[5.7,3.15;Invitar jugadores conectados]"
		if #candidates == 0 then
			fs[#fs + 1] = "label[5.7,3.6;No hay jugadores disponibles.]"
		else
			ui_invites[name] = {}
			for i, candidate in ipairs(candidates) do
				if i > 4 then break end
				ui_invites[name][i] = candidate
				local label = candidate
				if #label > 22 then label = label:sub(1, 22) end
				fs[#fs + 1] = ("button[5.7,%s;4.6,0.55;invite_%d;Invitar a %s]"):format(
					3.55 + (i - 1) * 0.62, i, escape(label))
			end
		end
		fs[#fs + 1] = "button[0.6,6.25;3.6,0.7;deliver;Entregar espada]"
		fs[#fs + 1] = "button_exit[4.4,6.25;2.8,0.7;close;Cerrar]"
	else
		fs[#fs + 1] = "label[5.7,3.15;Tu misión]"
		fs[#fs + 1] = ("hypertext[5.7,3.55;4.6,2.0;help;%s]"):format(rich(
			"Busca cualquier espada y pulsa «Entregar espada» cuando estés en el campamento. Cualquier miembro puede completar la entrega por el grupo."))
		fs[#fs + 1] = "button[0.6,6.25;3.6,0.7;deliver;Entregar espada]"
		fs[#fs + 1] = "button_exit[4.4,6.25;2.8,0.7;close;Cerrar]"
	end
	core.show_formspec(name, FORM_NPC, table.concat(fs))
end

-- ---------------------------------------------------------------------------
-- State transitions
-- ---------------------------------------------------------------------------
function E.start(player)
	if not state then
		tell(player:get_player_name(), "El registro de expediciones no está disponible.")
		return false
	end
	local name = player:get_player_name()
	if M.find_active_for(state, name) then
		tell(name, "Ya participas en una expedición activa.")
		E.show_npc(player)
		return false
	end
	local exp = M.new_expedition(state, name, now())
	if not exp then
		tell(name, "No se pudo iniciar la expedición.")
		return false
	end
	clear_invites_for(name)
	save()
	tell(name, ("Has iniciado la expedición #%d. Invita a otros jugadores desde la maestra."):format(exp.id))
	refresh_hud(name)
	E.show_npc(player)
	return true
end

function E.invite(actor, target_name)
	if not state then
		tell(actor:get_player_name(), "El registro de expediciones no está disponible.")
		return false
	end
	local name = actor:get_player_name()
	local exp = M.find_active_for(state, name)
	if not exp or exp.leader ~= name then
		tell(name, "Solo el líder puede invitar jugadores.")
		return false
	end
	local target = online(target_name)
	if not target then
		tell(name, "Ese jugador no está conectado.")
		return false
	end
	if M.pending_invite(state, target_name, now(), E.invite_ttl) then
		tell(name, "Ese jugador ya tiene una invitación pendiente.")
		E.show_npc(actor)
		return false
	end
	local ok, reason = M.invite(state, exp, target_name, now())
	if not ok then
		local messages = {
			busy = "Ese jugador ya participa en otra expedición.",
			["already member"] = "Ese jugador ya está en la expedición.",
			["already invited"] = "Ese jugador ya tiene una invitación pendiente.",
			full = "La expedición ya está completa.",
			["too many invitations"] = "Hay demasiadas invitaciones pendientes.",
		}
		tell(name, messages[reason] or "No se pudo invitar a ese jugador.")
		E.show_npc(actor)
		return false
	end
	save()
	tell(name, ("Invitación enviada a %s."):format(target_name))
	tell(target_name, ("%s te ha invitado a la expedición #%d."):format(name, exp.id))
	E.show_invite(target, exp)
	E.show_npc(actor)
	return true
end

function E.accept(player, id)
	local name = player:get_player_name()
	local exp = state and state.expeditions[tostring(id)]
	local invite = exp and exp.invites[name]
	local age = invite and (now() - invite.at) or nil
	if not exp or not age or age < 0 or age > E.invite_ttl then
		tell(name, "La invitación ya no está disponible.")
		return false
	end
	local ok, reason = M.accept(state, exp, name)
	if not ok then
		local messages = {
			busy = "Ya participas en otra expedición.",
			["no invitation"] = "La invitación ya no está disponible.",
			full = "La expedición ya está completa.",
			inactive = "La expedición ya no está activa.",
		}
		tell(name, messages[reason] or "No se pudo aceptar la invitación.")
		return false
	end
	save()
	tell(name, ("Te has unido a la expedición #%d de %s."):format(exp.id, exp.leader))
	broadcast(exp, ("%s se ha unido a la expedición #%d."):format(name, exp.id))
	refresh_online_huds()
	return true
end

function E.decline(player, id)
	if not state then return false end
	local name = player:get_player_name()
	local exp = state.expeditions[tostring(id)]
	if not exp or not M.decline(exp, name) then
		tell(name, "La invitación ya no está disponible.")
		return false
	end
	save()
	tell(name, "Has rechazado la invitación.")
	tell(exp.leader, ("%s ha rechazado la invitación a la expedición #%d."):format(name, exp.id))
	return true
end

local function notify_completion(exp)
	local message = ("Expedición #%d completada: %s entregó la espada. ¡El grupo ha cumplido la misión!"):format(
		exp.id, exp.progress.delivered_by or "?")
	for _, name in ipairs(exp.order) do
		local player = online(name)
		if player then
			tell(name, message)
			E.show_completion(player, exp)
			M.mark_notified(exp, name)
		end
	end
	save()
	refresh_online_huds()
end

function E.deliver(player)
	if not state then
		tell(player:get_player_name(), "El registro de expediciones no está disponible.")
		return false
	end
	local name = player:get_player_name()
	local exp = M.find_active_for(state, name)
	if not exp then
		tell(name, "No tienes una expedición activa.")
		return false
	end
	local inventory, index, stack = sword_slot(player)
	if not stack then
		tell(name, "Necesitas una espada en el inventario para entregarla.")
		E.show_npc(player)
		return false
	end
	local taken = stack:take_item(1)
	inventory:set_stack("main", index, stack)
	local ok, reason = M.deliver(exp, name, now())
	if not ok then
		-- Put the sword back if the state changed between checks.
		stack:add_item(taken)
		inventory:set_stack("main", index, stack)
		tell(name, reason == "inactive" and "La expedición ya no está activa."
			or "No se pudo completar la entrega.")
		return false
	end
	save()
	notify_completion(exp)
	return true
end

-- ---------------------------------------------------------------------------
-- Persistence and reconnection
-- ---------------------------------------------------------------------------
local function notify_pending(player)
	local name = player:get_player_name()
	if not state then return end
	local active = M.find_active_for(state, name)
	if active then
		tell(name, ("Continúas en la expedición #%d (%s). %s."):format(
			active.id, active.progress.sword_found and "espada conseguida" or "espada pendiente",
			active.progress.delivered and "entrega completada" or "entrega pendiente"))
		refresh_hud(name)
	end
	local completed, when = nil, -1
	for _, exp in pairs(state.expeditions) do
		if M.needs_notice(exp, name) and (exp.completed_at or 0) > when then
			completed, when = exp, exp.completed_at or 0
		end
	end
	if completed then
		tell(name, ("Mientras estabas desconectado, la expedición #%d se completó."):format(completed.id))
		core.after(2, function()
			local current = online(name)
			if not current or not current:is_valid() then return end
			E.show_completion(current, completed)
			M.mark_notified(completed, name)
			save()
		end)
		return
	end
	local invited_exp = M.pending_invite(state, name, now(), E.invite_ttl)
	if invited_exp then
		core.after(1.5, function()
			local current = online(name)
			if current and current:is_valid() then E.show_invite(current, invited_exp) end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Camp NPC placement
-- ---------------------------------------------------------------------------
local function read_npc_record()
	local raw = storage:get_string(E.npc_key)
	if raw == "" then return nil end
	local ok, pos = pcall(core.parse_json, raw)
	if ok and type(pos) == "table" and type(pos.x) == "number"
		and type(pos.y) == "number" and type(pos.z) == "number" then
		return vector.round(pos)
	end
	log_error("Invalid expedition NPC record; it is preserved")
	return nil
end

local function write_npc_record(pos)
	local ok, result = pcall(function()
		return storage:set_string(E.npc_key, core.write_json(vector.round(pos)))
	end)
	if not ok or result == false then log_error("Could not save expedition NPC position") end
end

local function standable(pos)
	local floor = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z})
	local floor_def = core.registered_nodes[floor.name]
	if not floor_def or not floor_def.walkable then return false end
	if (floor_def.liquidtype and floor_def.liquidtype ~= "none")
		or (floor_def.damage_per_second or 0) > 0 then
		return false
	end
	if core.get_item_group(floor.name, "leaves") > 0
		or core.get_item_group(floor.name, "tree") > 0 then
		return false
	end
	local feet = core.get_node(pos).name
	local head = core.get_node({x = pos.x, y = pos.y + 1, z = pos.z}).name
	if feet ~= "air" or head ~= "air" then return false end
	if core.registered_nodes[feet] and core.registered_nodes[feet].walkable then return false end
	return true
end

local function npc_near(pos, radius)
	for _, object in ipairs(core.get_objects_inside_radius(pos, radius or 3)) do
		local entity = object:get_luaentity()
		if entity and entity.name == E.npc_name then return true end
	end
	return false
end

local function spawn_npc(pos)
	local object = core.add_entity(pos, E.npc_name)
	if not object then
		log_error("Could not spawn expedition NPC")
		return false
	end
	object:set_yaw(math.pi)
	write_npc_record(pos)
	return true
end

local function find_npc_pos(center)
	core.load_area(vector.offset(center, -6, -4, -6), vector.offset(center, 7, 5, 11))
	local offsets = {
		{2, 0, 4}, {-2, 0, 4}, {2, 0, 3}, {-2, 0, 3},
		{0, 0, 4}, {1, 0, 4}, {-1, 0, 4}, {0, 0, 5}, {0, 0, 8},
	}
	for _, offset in ipairs(offsets) do
		local pos = vector.offset(center, offset[1], offset[2], offset[3])
		if standable(pos) then return pos end
	end
	return nil
end

function E.setup_camp(center)
	if E.npc_ready or type(center) ~= "table" then return false end
	local pos = find_npc_pos(center)
	if not pos then
		log_error("No safe position found for the expedition NPC in the camp")
		return false
	end
	if not spawn_npc(pos) then return false end
	E.npc_ready = true
	return true
end

function E.ensure_npc()
	if E.npc_ready then return true end
	local recorded = read_npc_record()
	if recorded then
		core.load_area(vector.offset(recorded, -3, -3, -3), vector.offset(recorded, 3, 4, 3))
		if npc_near(recorded) then
			E.npc_ready = true
			return true
		end
		if standable(recorded) and spawn_npc(recorded) then
			E.npc_ready = true
			return true
		end
		log_error("Recorded expedition NPC position is no longer usable; searching the camp")
	end
	local region = everforge.start_region and everforge.start_region.get()
	if not region or region.state ~= "ready" or type(region.center) ~= "table" then
		return false
	end
	core.load_area(vector.offset(region.center, -8, -4, -8), vector.offset(region.center, 8, 5, 11))
	if npc_near(region.center, 10) then
		E.npc_ready = true
		return true
	end
	local pos = find_npc_pos(region.center)
	if pos and spawn_npc(pos) then
		E.npc_ready = true
		return true
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Entity and formspec registration
-- ---------------------------------------------------------------------------
if mcl_mobs and mcl_mobs.register_mob then
	mcl_mobs.register_mob(E.npc_name, {
		type = "npc",
		_spawn_category = "misc",
		description = "Maestra de expediciones",
		nametag = "Maestra de expediciones",
		hp_min = 1000,
		hp_max = 1000,
		armor = 100,
		physical = true,
		collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.9, 0.3},
		visual = "mesh",
		mesh = "mobs_mc_villager.b3d",
		textures = {
			"mobs_mc_villager.png",
			"mobs_mc_villager_profession_cartographer.png",
		},
		animation = {stand_start = 0, stand_end = 0, walk_start = 0, walk_end = 0},
		walk_chance = 0,
		jump = false,
		runaway = false,
		can_despawn = false,
		persistent = true,
		makes_footstep_sound = false,
		damage_texture_modifier = "^[colorize:#704F39:40",
		drops = {},
		do_punch = function() return false end,
		on_rightclick = function(_, clicker)
			if clicker and clicker:is_player() then
				-- In worlds where the ruins site is prepared, the same Maestra
				-- runs the real adventure. Elsewhere the original prototype
				-- remains available unchanged.
				if everforge.ruins_quest and everforge.ruins_quest.is_armed() then
					everforge.ruins_quest.show_npc(clicker)
				else
					E.show_npc(clicker)
				end
			end
		end,
	})
else
	log_error("mcl_mobs is required for the expedition NPC")
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == FORM_NPC then
		if fields.start then
			E.start(player)
		elseif fields.deliver then
			E.deliver(player)
		else
			local actions = ui_invites[player:get_player_name()]
			if actions then
				for field in pairs(fields) do
					local index = field:match("^invite_(%d+)$")
					local target = index and actions[tonumber(index)]
					if target then
						E.invite(player, target)
						break
					end
				end
			end
		end
		return true
	elseif formname == FORM_INVITE then
		for field in pairs(fields) do
			local accept = field:match("^accept_(%d+)$")
			if accept then
				if E.accept(player, tonumber(accept)) then E.show_npc(player) end
				return true
			end
			local decline = field:match("^decline_(%d+)$")
			if decline then
				E.decline(player, tonumber(decline))
				return true
			end
		end
		return true
	end
end)

core.register_on_joinplayer(function(player)
	notify_pending(player)
	core.after(1, function() E.ensure_npc() end)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local id = hud_ids[name]
	if id then player:hud_remove(id) end
	hud_ids[name] = nil
	ui_invites[name] = nil
end)

core.register_on_mods_loaded(function()
	core.after(2, function() E.ensure_npc() end)
end)

-- Shared "sword found" signal and invitation expiry are checked periodically;
-- they do not touch inventories or vanilla achievements.
local scan_elapsed, invite_elapsed = 0, 0
core.register_globalstep(function(dt)
	scan_elapsed = scan_elapsed + dt
	invite_elapsed = invite_elapsed + dt
	if scan_elapsed >= 4 then
		scan_elapsed = 0
		if state then
			local changed = false
			for _, player in ipairs(core.get_connected_players()) do
				local name = player:get_player_name()
				local exp = M.find_active_for(state, name)
				if exp and not exp.progress.sword_found and E.has_sword(player) then
					if M.mark_sword_found(exp) then
						changed = true
						broadcast(exp, ("%s ha conseguido una espada. Entrégala a la maestra para completar la expedición #%d.")
							:format(name, exp.id))
					end
				end
			end
			if changed then
				save()
				refresh_online_huds()
			end
		end
	end
	if invite_elapsed >= 30 then
		invite_elapsed = 0
		if state and M.expire_invites(state, now(), E.invite_ttl) > 0 then save() end
	end
end)

E.get_state = get_state
E.refresh_hud = refresh_hud
return E
