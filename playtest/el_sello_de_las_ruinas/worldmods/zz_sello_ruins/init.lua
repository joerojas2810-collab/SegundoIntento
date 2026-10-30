-- SPDX-License-Identifier: GPL-3.0-or-later
-- Prepared, self-contained world for "El sello de las ruinas".
--
-- The world is singlenode on purpose: this mod authors a small grassy shelf, a
-- ruined hill-fort from the distributed .mts, a trailhead and a camp. It does
-- not call the normal world generator and never touches an existing map.

local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local gamepath = core.get_modpath("everforge")
local Q = everforge.ruins_quest
local E = everforge.expedition
local camp = dofile(gamepath .. "/camp.lua")

local ANCHOR = {x = -30, y = 61, z = -30}
local CAMP = {x = 0, y = 83, z = -62}
local CAMP_LANDING = {x = 0, y = 83, z = -57}
local CAMP_STONE = {x = -4, y = 83, z = -56}
local CAMP_CHEST = {x = 5, y = 83, z = -62}
local TRAIL_LANDING = {x = 0, y = 83, z = -47}
local TRAIL_STONE = {x = 0, y = 83, z = -50}

local PLATFORM = {minx = -66, maxx = 66, minz = -84, maxz = 74, top = 82}

local function set_node(pos, name, param2)
	core.set_node(pos, {name = name, param2 = param2 or 0})
end

local function clear_column(x, z, y1, y2)
	for y = y1, y2 do set_node({x = x, y = y, z = z}, "air") end
end

local function build_platform()
	for x = PLATFORM.minx, PLATFORM.maxx do
		for z = PLATFORM.minz, PLATFORM.maxz do
			set_node({x = x, y = 80, z = z}, "mcl_core:stone")
			set_node({x = x, y = 81, z = z}, "mcl_core:dirt")
			set_node({x = x, y = 82, z = z}, "mcl_core:dirt_with_grass")
		end
	end
	-- Low, irregular grassy shoulders so the shelf does not end in a razor line.
	for x = PLATFORM.minx, PLATFORM.maxx do
		for z = PLATFORM.minz, PLATFORM.maxz do
			if x < -52 or x > 52 or z < -74 or z > 64 then
				local n = (x * 17 + z * 31) % 100
				if n < 22 then
					set_node({x = x, y = 83, z = z}, "mcl_core:dirt_with_grass")
					if n < 8 then set_node({x = x, y = 84, z = z}, "mcl_core:dirt_with_grass") end
				end
			end
		end
	end
end

local function build_trailhead()
	for x = -4, 4 do
		for z = -54, -46 do
			local n = (x * 13 + z * 7) % 100
			local name = "mcl_core:stonebrick"
			if n < 18 then name = "mcl_core:stonebrickcracked"
			elseif n < 34 then name = "mcl_core:stonebrickmossy" end
			set_node({x = x, y = 82, z = z}, name)
			clear_column(x, z, 83, 88)
		end
	end
	for _, x in ipairs({-3, 3}) do
		for y = 83, 85 do set_node({x = x, y = y, z = -54}, "mcl_fences:dark_oak_fence") end
		set_node({x = x, y = 86, z = -54}, "mcl_lanterns:lantern_floor")
	end
	set_node({x = 3, y = 83, z = -47}, "mcl_campfires:campfire_lit")
	set_node({x = -4, y = 83, z = -47}, "mcl_chests:chest_small")
	-- A little rubble on the approach: the ruins begin before the gate.
	for _, p in ipairs({{-5, -45}, {5, -44}, {-6, -49}, {6, -52}, {-4, -56}}) do
		set_node({x = p[1], y = 83, z = p[2]}, "mcl_core:cobble")
	end
end

local function build_path()
	-- Gravel path, 3 wide, from the trailhead to the gate.  The last two
	-- blocks step up to the fort's 84-level threshold.
	for z = -49, -25 do
		for x = -1, 1 do
			local n = (x * 9 + z * 5) % 100
			local name = "mcl_core:gravel"
			if n < 8 then name = "mcl_core:grass_path"
			elseif n < 13 then name = "mcl_core:cobble" end
			set_node({x = x, y = 82, z = z}, name)
			clear_column(x, z, 83, 87)
		end
	end
	for z = -27, -25 do
		for x = -1, 1 do
			set_node({x = x, y = 83, z = z}, "mcl_core:stonebrick")
			clear_column(x, z, 84, 87)
		end
	end
	-- Lamp posts every eight metres; low fence rails on the wild side.
	for z = -44, -28, 8 do
		for _, x in ipairs({-3, 3}) do
			set_node({x = x, y = 82, z = z}, "mcl_core:cobble")
			for y = 83, 84 do set_node({x = x, y = y, z = z}, "mcl_fences:dark_oak_fence") end
			set_node({x = x, y = 85, z = z}, "mcl_lanterns:lantern_floor")
		end
	end
end

local function tree(x, z, height)
	for y = 82, 82 + height do
		set_node({x = x, y = y, z = z}, "mcl_trees:tree_oak")
	end
	for dx = -2, 2 do
		for dz = -2, 2 do
			for dy = height - 2, height + 1 do
				if math.abs(dx) + math.abs(dz) + math.abs(dy - height) <= 4 then
					local p = {x = x + dx, y = 82 + dy, z = z + dz}
					if core.get_node(p).name == "air" then
						set_node(p, "mcl_trees:leaves_oak")
					end
				end
			end
		end
	end
end

local function build_landscape()
	local trees = {
		{-48, -70, 5}, {-55, -58, 4}, {-47, -34, 6}, {-51, -12, 5},
		{-46, 18, 4}, {-52, 42, 5}, {-38, 58, 4}, {45, -72, 5},
		{53, -54, 4}, {48, -28, 6}, {55, -6, 5}, {47, 22, 4},
		{53, 44, 5}, {40, 60, 4}, {-30, 68, 5}, {24, 69, 4},
	}
	for _, t in ipairs(trees) do
		if core.get_node({x = t[1], y = 82, z = t[2]}).name == "mcl_core:dirt_with_grass" then
			tree(t[1], t[2], t[3])
		end
	end
	-- Scattered boulders and dry grass, kept away from the path and camp.
	for i = 1, 34 do
		local x = ((i * 37) % 110) - 55
		local z = ((i * 53) % 130) - 74
		local in_fort = x >= -29 and x <= 29 and z >= -29 and z <= 29
		if not in_fort and (math.abs(x) > 8 or z < -58 or z > 8)
			and core.get_node({x = x, y = 82, z = z}).name == "mcl_core:dirt_with_grass" then
			local n = (x * 3 + z * 11) % 100
			if n < 45 then
				set_node({x = x, y = 83, z = z}, "mcl_core:cobble")
				if n < 18 then set_node({x = x, y = 84, z = z}, "mcl_core:mossycobble") end
			elseif n < 80 then
				set_node({x = x, y = 83, z = z}, "mcl_flowers:fern")
			else
				set_node({x = x, y = 83, z = z}, "mcl_core:deadbush")
			end
		end
	end
end

local function build_camp()
	local ok, err = pcall(camp.place, CAMP)
	if not ok then
		core.log("error", "[zz_sello_ruins] camp.place failed: " .. tostring(err))
		-- A minimal fallback still leaves the world playable.
		for x = -3, 3 do
			for z = -4, 3 do set_node({x = x, y = 82, z = z}, "mcl_core:stonebrick") end
		end
		set_node({x = 0, y = 83, z = -58}, "mcl_campfires:campfire_lit")
		return false
	end
	-- Camp supply chest, just outside the hut.
	set_node(CAMP_CHEST, "mcl_chests:chest_small")
	local def = core.registered_nodes["mcl_chests:chest_small"]
	if def and def.on_construct then def.on_construct(CAMP_CHEST) end
	return true
end

local function prepare_waystones()
	-- Q.setup_site places the crypt and gate stones from the manifest.
	Q.arm_site({
		anchor = ANCHOR,
		trailhead = TRAIL_LANDING,
		camp = CAMP_LANDING,
		camp_stone = CAMP_STONE,
		camp_chest = CAMP_CHEST,
		trail_stone = TRAIL_STONE,
		camp_center = CAMP,
	})
	Q.setup_site()
	Q.setup_camp(CAMP)
end

local function build_all()
	core.log("action", "[zz_sello_ruins] Building the prepared adventure world")
	build_platform()
	build_trailhead()
	build_path()
	build_landscape()
	build_camp()
	core.load_area({x = ANCHOR.x, y = ANCHOR.y, z = ANCHOR.z},
		{x = ANCHOR.x + 60, y = ANCHOR.y + 39, z = ANCHOR.z + 60})
	-- Force placement is required: the schematic's stair shaft must cut the
	-- solid grass shelf.  The short path through the plateau is rebuilt below.
	local ok, placed = pcall(core.place_schematic, ANCHOR,
		gamepath .. "/schematics/sello_ruinas.mts", "0", nil, true)
	if not ok or not placed then
		core.log("error", "[zz_sello_ruins] Could not place sello_ruinas.mts: " .. tostring(placed))
		return false
	end
	-- The schematic owns the fort interior, but the last metres of the approach
	-- must remain a walkable gravel ramp through the plateau lip.
	build_path()
	prepare_waystones()
	core.set_timeofday(0.32)
	core.log("action", "[zz_sello_ruins] Adventure world ready")
end

local function give_starter_kit(player)
	local meta = player:get_meta()
	if meta:get_int("everforge:sello:starter") == 1 then return end
	meta:set_int("everforge:sello:starter", 1)
	local inv = player:get_inventory()
	if not inv then return end
	for _, item in ipairs({
		"mcl_tools:sword_stone 1",
		"mcl_torches:torch 16",
		"mcl_farming:bread 6",
		"mcl_core:cobble 24",
	}) do
		inv:add_item("main", ItemStack(item))
	end
end

local function place_player_at_camp(player)
	player:set_pos(CAMP_LANDING)
	player:set_look_horizontal(0)
	local meta = player:get_meta()
	if meta:get_string("mcl_beds:spawn") == "" then
		meta:set_string("mcl_beds:spawn", core.pos_to_string(CAMP_LANDING))
	end
end

core.after(0, function()
	if Q.is_armed() then
		Q.ensure_runtime()
		Q.setup_camp(CAMP)
		core.log("action", "[zz_sello_ruins] Existing adventure world loaded; terrain left untouched")
	else
		build_all()
	end
end)

-- Safety net: the prepared world is a grass shelf surrounded by empty sky.
-- If someone walks off it, return them to camp instead of losing the run.
local fall_check = 0
core.register_globalstep(function(dt)
	fall_check = fall_check + (dt or 0)
	if fall_check < 2 then return end
	fall_check = 0
	for _, player in ipairs(core.get_connected_players()) do
		local pos = player:get_pos()
		if pos and pos.y < 60 then
			place_player_at_camp(player)
			core.chat_send_player(player:get_player_name(), "[El sello] El vacío te devuelve al campamento.")
		end
	end
end)

core.register_on_newplayer(function(player)
	core.after(0.5, function()
		if not player or not player:is_valid() then return end
		place_player_at_camp(player)
		give_starter_kit(player)
		local name = player:get_player_name()
		core.chat_send_player(name, "[El sello] Habla con la Maestra junto a la hoguera del campamento (detrás de ti, al norte).")
		core.chat_send_player(name, "[El sello] Cuando aceptes la misión, usa la piedra de viaje que está a un lado del campamento.")
	end)
end)

core.register_on_joinplayer(function(player)
	core.after(1, function()
		if not player or not player:is_valid() then return end
		local pos = player:get_pos()
		if not pos or pos.y < 70 or pos.y > 110 then
			place_player_at_camp(player)
		end
		give_starter_kit(player)
	end)
end)

-- A small read-only diagnostic for the prepared world. It is not needed to
-- play and grants no privileges.
core.register_chatcommand("sello", {
	description = "Muestra el estado de la expedición del mundo preparado",
	func = function(name)
		local Qstate = Q
		local player = core.get_player_by_name(name)
		if not player then return false, "Sin jugador." end
		local pos = vector.round(player:get_pos())
		local sm = Qstate.is_armed() and "sitio preparado" or "sitio sin preparar"
		return true, ("%s · posición %d,%d,%d · el sello está en la cámara del fondo de la cripta"):format(
			sm, pos.x, pos.y, pos.z)
	end,
})
