-- SPDX-License-Identifier: GPL-3.0-or-later
-- Prepared world for "El sello de las ruinas", grounded in Everforge's normal
-- Mineclonia terrain (v7 + mcl_biomes), not a flat singlenode plaza.
--
-- This mod never builds its own terrain from scratch: it reads the real,
-- generated ground height at each column and grounds the camp, the trail and
-- the fortress on it. The fortress footprint is leveled to a single pad
-- height chosen from its own natural centre, with a short tapered skirt at
-- its edges, so hillier ground is quarried into and lower ground is filled
-- only inside and right at the structure's own footprint -- never a platform
-- larger than the building that sits on it.

local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local gamepath = core.get_modpath("everforge")
local Q = everforge.ruins_quest
local E = everforge.expedition
local camp = dofile(gamepath .. "/camp.lua")
local site = dofile(gamepath .. "/camp_site.lua")

-- Horizontal layout (unchanged from the original design): the camp sits
-- south of the fortress, connected by a short trail. Only the vertical
-- placement is now read from the real terrain.
local ANCHOR_X, ANCHOR_Z = -30, -30
local CAMP_X, CAMP_Z = 0, -62
local TRAIL_STONE_X, TRAIL_STONE_Z = 0, -50
local TRAILHEAD_X, TRAILHEAD_Z = 0, -47

-- Local Y, inside the schematic, of its own walkable ground floor (the
-- courtyard/gate level). Placing the schematic at anchor.y = ground - GRADE
-- means this floor lines up with the real surface: the crypt below it stays
-- naturally underground and the walls/towers above it rise out of the hill.
local GRADE_OFFSET = 21
local SKIRT = 6
local MIN_Y, MAX_Y = -64, 200

local function ground_name(name)
	local def = core.registered_nodes[name]
	return name ~= "air" and name ~= "ignore" and site.natural(name) and def
end

-- Topmost natural-ground node in a column; nil if the column never loaded.
local function ground_height(x, z)
	for y = MAX_Y, MIN_Y, -1 do
		local name = core.get_node({x = x, y = y, z = z}).name
		if name == "ignore" then return nil end
		if ground_name(name) then return y end
	end
	return nil
end

-- Set once the fortress footprint is leveled. Used by grade_height() below so
-- the trail never re-scans for "natural" ground under the schematic's own
-- gate/courtyard, where it would see straight through built stonebrick to
-- whatever lies beneath the structure.
local footprint_pad_y = nil

-- Height to build the trail at: the known pad grade inside the fortress
-- footprint (where ground_height() would otherwise be fooled by the
-- schematic's own, non-"natural" floor), the real terrain outside it.
local function grade_height(x, z, fallback)
	if footprint_pad_y and x >= ANCHOR_X and x <= ANCHOR_X + 60
		and z >= ANCHOR_Z and z <= ANCHOR_Z + 60 then
		return footprint_pad_y
	end
	return ground_height(x, z) or fallback
end

local function clear_column_above(x, z, from_y, to_y)
	for y = from_y, to_y do
		local name = core.get_node({x = x, y = y, z = z}).name
		if name ~= "air" then core.set_node({x = x, y = y, z = z}, {name = "air"}) end
	end
end

local function fill_column(x, z, from_y, to_y)
	-- Matches the real soil profile: stone core, two layers of dirt, grass on top.
	for y = from_y, to_y do
		local name
		if y >= to_y - 1 then name = "mcl_core:dirt_with_grass"
		elseif y >= to_y - 3 then name = "mcl_core:dirt"
		else name = "mcl_core:stone" end
		core.set_node({x = x, y = y, z = z}, {name = name})
	end
end

-- Levels the fortress footprint to pad_y, with a short tapered skirt outside
-- it so the edge blends into the surrounding slope instead of ending in a
-- platform lip.
local function level_footprint(anchor_x, anchor_z, size_x, size_z, pad_y)
	for x = anchor_x - SKIRT, anchor_x + size_x - 1 + SKIRT do
		for z = anchor_z - SKIRT, anchor_z + size_z - 1 + SKIRT do
			local inside = x >= anchor_x and x <= anchor_x + size_x - 1
				and z >= anchor_z and z <= anchor_z + size_z - 1
			local h = ground_height(x, z)
			if h then
				local target
				if inside then
					target = pad_y
				else
					local dx = math.max(anchor_x - x, 0, x - (anchor_x + size_x - 1))
					local dz = math.max(anchor_z - z, 0, z - (anchor_z + size_z - 1))
					local dist = math.max(dx, dz)
					local blend = math.min(1, dist / SKIRT)
					target = h + (pad_y - h) * (1 - blend)
					target = math.floor(target + 0.5)
				end
				if target > h then
					fill_column(x, z, h + 1, target)
				elseif target < h then
					-- Clear the excavated soil AND whatever (trees, plants) was
					-- standing on it, so nothing is left floating over the cut.
					clear_column_above(x, z, target + 1, math.min(h + 40, MAX_Y))
				end
			end
		end
	end
end

local function build_trailhead(base_y)
	for x = -4, 4 do
		for z = -54, -46 do
			local h = grade_height(x, z, base_y)
			local n = (x * 13 + z * 7) % 100
			local name = "mcl_core:stonebrick"
			if n < 18 then name = "mcl_core:stonebrickcracked"
			elseif n < 34 then name = "mcl_core:stonebrickmossy" end
			core.set_node({x = x, y = h, z = z}, {name = name})
			clear_column_above(x, z, h + 1, h + 10)
		end
	end
	local h0 = grade_height(-3, -54, base_y)
	local h1 = grade_height(3, -54, base_y)
	for _, pair in ipairs({{-3, h0}, {3, h1}}) do
		local x, h = pair[1], pair[2]
		for y = h + 1, h + 3 do core.set_node({x = x, y = y, z = -54}, {name = "mcl_fences:dark_oak_fence"}) end
		core.set_node({x = x, y = h + 4, z = -54}, {name = "mcl_lanterns:lantern_floor"})
	end
	local hc = grade_height(3, -47, base_y)
	core.set_node({x = 3, y = hc + 1, z = -47}, {name = "mcl_campfires:campfire_lit"})
	local hch = grade_height(-4, -47, base_y)
	core.set_node({x = -4, y = hch + 1, z = -47}, {name = "mcl_chests:chest_small"})
	for _, p in ipairs({{-5, -45}, {5, -44}, {-6, -49}, {6, -52}, {-4, -56}}) do
		local h = grade_height(p[1], p[2], base_y)
		core.set_node({x = p[1], y = h + 1, z = p[2]}, {name = "mcl_core:cobble"})
	end
end

local function build_path(base_y)
	for z = -49, -25 do
		for x = -1, 1 do
			local h = grade_height(x, z, base_y)
			local n = (x * 9 + z * 5) % 100
			local name = "mcl_core:gravel"
			if n < 8 then name = "mcl_core:grass_path"
			elseif n < 13 then name = "mcl_core:cobble" end
			core.set_node({x = x, y = h, z = z}, {name = name})
			clear_column_above(x, z, h + 1, h + 10)
		end
	end
	for z = -27, -25 do
		for x = -1, 1 do
			local h = grade_height(x, z, base_y)
			core.set_node({x = x, y = h, z = z}, {name = "mcl_core:stonebrick"})
			clear_column_above(x, z, h + 1, h + 10)
		end
	end
	for z = -44, -28, 8 do
		for _, x in ipairs({-3, 3}) do
			local h = grade_height(x, z, base_y)
			core.set_node({x = x, y = h, z = z}, {name = "mcl_core:cobble"})
			for y = h + 1, h + 2 do core.set_node({x = x, y = y, z = z}, {name = "mcl_fences:dark_oak_fence"}) end
			core.set_node({x = x, y = h + 3, z = z}, {name = "mcl_lanterns:lantern_floor"})
		end
	end
end

local function build_camp(camp_y)
	local ok, err = pcall(camp.place, {x = CAMP_X, y = camp_y, z = CAMP_Z})
	if not ok then
		core.log("error", "[zz_sello_ruins] camp.place failed: " .. tostring(err))
		-- A minimal fallback still leaves the world playable.
		for x = -3, 3 do
			for z = -4, 3 do core.set_node({x = x, y = camp_y - 1, z = z}, {name = "mcl_core:stonebrick"}) end
		end
		core.set_node({x = 0, y = camp_y, z = -58}, {name = "mcl_campfires:campfire_lit"})
		return false
	end
	local chest = {x = CAMP_X + 5, y = camp_y, z = CAMP_Z}
	core.set_node(chest, {name = "mcl_chests:chest_small"})
	local def = core.registered_nodes["mcl_chests:chest_small"]
	if def and def.on_construct then def.on_construct(chest) end
	return true
end

local function build_all()
	core.log("action", "[zz_sello_ruins] Grounding the prepared adventure on the real terrain")
	local center_h = ground_height(ANCHOR_X + 30, ANCHOR_Z + 30)
	if not center_h then
		core.log("error", "[zz_sello_ruins] Could not read the fortress site's natural height")
		return false
	end
	local anchor_y = center_h - GRADE_OFFSET
	local pad_y = anchor_y + GRADE_OFFSET
	footprint_pad_y = pad_y
	level_footprint(ANCHOR_X, ANCHOR_Z, 61, 61, pad_y)

	local camp_ground = ground_height(CAMP_X, CAMP_Z)
	local camp_y = (camp_ground or (pad_y - 5)) + 1
	if not build_camp(camp_y) then return false end

	build_trailhead(pad_y)
	build_path(pad_y)

	local anchor = {x = ANCHOR_X, y = anchor_y, z = ANCHOR_Z}
	core.load_area({x = anchor.x, y = anchor.y, z = anchor.z},
		{x = anchor.x + 60, y = anchor.y + 39, z = anchor.z + 60})
	-- Force placement is required: the schematic's stair shaft must cut the
	-- leveled pad. The short path through the footprint is rebuilt below.
	local ok, placed = pcall(core.place_schematic, anchor,
		gamepath .. "/schematics/sello_ruinas.mts", "0", nil, true)
	if not ok or not placed then
		core.log("error", "[zz_sello_ruins] Could not place sello_ruinas.mts: " .. tostring(placed))
		return false
	end
	build_path(pad_y)

	local trailhead_h = (ground_height(TRAILHEAD_X, TRAILHEAD_Z) or pad_y)
	local trail_stone_h = (ground_height(TRAIL_STONE_X, TRAIL_STONE_Z) or pad_y)
	local camp_landing = {x = CAMP_X, y = camp_y, z = CAMP_Z + 5}
	local camp_stone = {x = CAMP_X - 4, y = camp_y, z = CAMP_Z + 6}
	local camp_chest = {x = CAMP_X + 5, y = camp_y, z = CAMP_Z}

	Q.arm_site({
		anchor = anchor,
		trailhead = {x = TRAILHEAD_X, y = trailhead_h + 1, z = TRAILHEAD_Z},
		camp = camp_landing,
		camp_stone = camp_stone,
		camp_chest = camp_chest,
		trail_stone = {x = TRAIL_STONE_X, y = trail_stone_h + 1, z = TRAIL_STONE_Z},
		camp_center = {x = CAMP_X, y = camp_y, z = CAMP_Z},
	})
	Q.setup_site()
	Q.setup_camp({x = CAMP_X, y = camp_y, z = CAMP_Z})
	core.set_timeofday(0.32)
	core.log("action", "[zz_sello_ruins] Adventure world ready (anchor y=" .. anchor_y .. ", camp y=" .. camp_y .. ")")
	return true
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
	local site_data = Q.get_site()
	local target = site_data and site_data.camp
	if not target then
		-- Fall back to a column above the camp centre; never below MIN_Y.
		local h = ground_height(CAMP_X, CAMP_Z + 5) or 32
		target = {x = CAMP_X, y = h + 1, z = CAMP_Z + 5}
	end
	player:set_pos(target)
	player:set_look_horizontal(0)
	local meta = player:get_meta()
	if meta:get_string("mcl_beds:spawn") == "" then
		meta:set_string("mcl_beds:spawn", core.pos_to_string(target))
	end
end

local world_ready = false
local min_safe_y = MIN_Y

local function initialize_world()
	if Q.is_armed() then
		Q.ensure_runtime()
		local camp_ground = ground_height(CAMP_X, CAMP_Z)
		Q.setup_camp({x = CAMP_X, y = (camp_ground or 0) + 1, z = CAMP_Z})
		core.log("action", "[zz_sello_ruins] Existing adventure world loaded; terrain left untouched")
	else
		if build_all() == false then return end
	end
	world_ready = true
	for _, player in ipairs(core.get_connected_players()) do
		place_player_at_camp(player)
		give_starter_kit(player)
	end
end

local function emerge_world(attempt)
	local failed = false
	core.emerge_area({x = -90, y = MIN_Y, z = -106}, {x = 90, y = MAX_Y, z = 90},
		function(_, action, remaining)
			if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
				failed = true
			end
			if remaining == 0 then
				core.after(0, function()
					if failed then
						if attempt < 4 then
							core.after(1, function() emerge_world(attempt + 1) end)
						else
							core.log("error", "[zz_sello_ruins] No se pudo preparar el terreno; no se construyó la aventura")
						end
					else
						core.load_area({x = -90, y = MIN_Y, z = -106}, {x = 90, y = MAX_Y, z = 90})
						local anchor_h = ground_height(ANCHOR_X + 30, ANCHOR_Z + 30) or 0
						local camp_h = ground_height(CAMP_X, CAMP_Z) or 0
						min_safe_y = math.min(anchor_h, camp_h) - 60
						initialize_world()
					end
				end)
			end
		end)
end
core.after(0, function() emerge_world(1) end)

-- Safety net: rescue a player who falls into a cave, ravine or mined-out pit
-- well below the quest area, instead of losing the run.
local fall_check = 0
core.register_globalstep(function(dt)
	fall_check = fall_check + (dt or 0)
	if fall_check < 2 then return end
	fall_check = 0
	for _, player in ipairs(core.get_connected_players()) do
		local pos = player:get_pos()
		if world_ready and pos and pos.y < min_safe_y then
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
		if not pos or (world_ready and pos.y < min_safe_y) then
			place_player_at_camp(player)
		end
		give_starter_kit(player)
	end)
	if Q.is_armed() and E and E.ensure_npc then
		core.after(1, function() pcall(E.ensure_npc) end)
	end
end)

core.register_on_mods_loaded(function()
	core.after(2, function()
		if Q.is_armed() and E and E.ensure_npc then pcall(E.ensure_npc) end
	end)
end)

-- A small read-only diagnostic for the prepared world. It is not needed to
-- play and grants no privileges.
core.register_chatcommand("sello", {
	description = "Muestra el estado de la expedición del mundo preparado",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then return false, "Sin jugador." end
		local pos = vector.round(player:get_pos())
		local sm = Q.is_armed() and "sitio preparado" or "sitio sin preparar"
		return true, ("%s · posición %d,%d,%d · el sello está en la cámara del fondo de la cripta"):format(
			sm, pos.x, pos.y, pos.z)
	end,
})
