-- Temporary visual-test world for the Gondor Fort -> Mineclonia conversion.
-- This mod is deliberately NOT part of the game. It only builds a flat
-- platform in a singlenode world, places the converted schematic once, and
-- provides /ruins_view teleports for screenshots.

local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local schematic = modpath .. "/schematics/gondor_fort_ruined.mts"

-- Structure origin. The schematic is 19 x 30 x 20 (x, y, z).
-- The platform top is y=65; the schematic's y=0 foundation starts at y=63,
-- so its y=3 floor is at y=66 and the player stands at y=66 on the platform.
local ORIGIN = { x = 0, y = 63, z = 0 }
local PLATFORM_Y = 65
local PLATFORM_MIN = -18
local PLATFORM_MAX = 36

local function set_platform()
	for x = PLATFORM_MIN, PLATFORM_MAX do
		for z = PLATFORM_MIN, PLATFORM_MAX do
			core.set_node({ x = x, y = PLATFORM_Y, z = z }, { name = "mcl_core:stonebrick" })
		end
	end
end

local function build()
	set_platform()
	local ok = core.place_schematic(ORIGIN, schematic, "0", nil, true)
	core.log("action", "[zz_gondor_preview] schematic placed: " .. tostring(ok))
	if not ok then
		core.log("error", "[zz_gondor_preview] could not place " .. schematic)
	end
end

local views = {
	front = { pos = { x = 9.5, y = 66.1, z = -10 }, yaw = 0, pitch = -0.05 },
	side = { pos = { x = -10, y = 66.1, z = 9.5 }, yaw = math.pi / 2, pitch = -0.05 },
	back = { pos = { x = 9.5, y = 66.1, z = 29 }, yaw = math.pi, pitch = -0.05 },
	gate = { pos = { x = 9.5, y = 66.1, z = -3 }, yaw = 0, pitch = 0 },
	courtyard = { pos = { x = 9.5, y = 67.1, z = 4.5 }, yaw = 0, pitch = 0 },
	interior = { pos = { x = 9.5, y = 67.1, z = 12.5 }, yaw = 0, pitch = 0 },
	top = { pos = { x = 9.5, y = 96, z = 9.5 }, yaw = 0, pitch = -1.4 },
}

local function apply_view(player, view_name)
	local v = views[view_name]
	if not v then
		core.chat_send_player(player:get_player_name(),
			"Vista desconocida. Usa: front, side, back, gate, courtyard, interior, top")
		return false
	end
	player:set_pos(v.pos)
	player:set_look_horizontal(v.yaw)
	player:set_look_vertical(v.pitch)
	return true
end

core.after(1, build)
core.after(2, function()
	core.set_timeofday(0.5) -- fixed noon: comparable screenshots
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local privs = core.get_player_privs(name)
	privs.fly = true
	privs.fast = true
	privs.noclip = true
	privs.creative = true
	core.set_player_privs(name, privs)
	core.after(1, function()
		if player and player:is_player() then
			apply_view(player, "front")
			core.chat_send_player(player:get_player_name(),
				"[Gondor Fort] Vista frontal. /ruins_view front|side|back|gate|courtyard|interior|top. " ..
				"F12 guarda una captura. /ruins_pos muestra la posición.")
		end
	end)
end)

core.register_chatcommand("ruins_view", {
	params = "front|side|back|gate|courtyard|interior|top",
	description = "Teleport to a fixed viewpoint for the Gondor Fort visual test",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "No hay jugador."
		end
		local view = param:match("^%s*(%a+)%s*$") or "front"
		if apply_view(player, view) then
			return true, "Vista: " .. view
		end
		return false, "Vista no válida."
	end,
})

core.register_chatcommand("ruins_pos", {
	description = "Show the current position and the node under it",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "No hay jugador."
		end
		local p = vector.round(player:get_pos())
		local node = core.get_node(p)
		return true, string.format("pos=(%.2f, %.2f, %.2f) node=%s param2=%d",
			player:get_pos().x, player:get_pos().y, player:get_pos().z,
			node.name, node.param2 or 0)
	end,
})
