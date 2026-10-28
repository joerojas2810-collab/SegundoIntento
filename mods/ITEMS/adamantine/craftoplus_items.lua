-- Adamantine: decorative items built the way CraftoPlus builds its gold ones
-- (items/gold/*.lua by Mish7913, GPL-3.0-or-later), with the textures
-- recolored to adamantine in code. Optional: does nothing without CraftoPlus.
-- Items: ladder, chain, door (+ double door), bars, trapdoor, carved block.

if not minetest.get_modpath("craftoplus") then
	return
end
if not (rawget(_G, "craftoplus") and rawget(_G, "m7a")) then
	return
end

local INGOT = "adamantine:ingot"
local BLOCK = "adamantine:block"

local block_def = minetest.registered_nodes[BLOCK]
if not block_def or not minetest.registered_items[INGOT] then
	return
end

-- Gold is about hue 45; the adamantine block is about hue 270.
-- Change the first number to adjust the color.
local TINT = "^[hsl:-135:0:0"

local function tint(tex)
	return tex .. TINT
end

-- craftoplus.img() can return two values (gsub), so keep only the first.
local function img(name)
	local t = craftoplus.img(name, { "mts", "mcl" })
	return t
end

local function metal()
	return mcl_sounds.node_sound_metal_defaults()
end

-- ---------------------------------------------------------------------------
-- Ladder
-- ---------------------------------------------------------------------------
if craftoplus.register_ladder then
	local tex = tint(img("cfp_gold_ladder.png"))
	local ladder = craftoplus.register_ladder("adamantine:ladder", {
		description = "Adamantine Ladder",
		_doc_items_longdesc = "A piece of ladder which allows you to climb vertically. "
			.. "Ladders can only be placed on the side of solid blocks "
			.. "and not on glass, leaves, ice, slabs, glowstone, nor sea lanterns.",
		tiles = { tex, "" },
		inventory_image = tex,
		wield_image = tex,
		groups = {
			handy = 1, axey = 1, attached_node = 1, deco_block = 1,
			dig_by_piston = 1, unsticky = 1, pathfinder_partial = 1,
		},
		sounds = metal(),
		_mcl_blast_resistance = 6,
		_mcl_hardness = 2,
	})
	if ladder then
		minetest.register_craft({
			output = ladder .. " 9",
			recipe = {
				{ INGOT, "",    INGOT },
				{ INGOT, INGOT, INGOT },
				{ INGOT, "",    INGOT },
			},
		})
	end
end

-- ---------------------------------------------------------------------------
-- Chain
-- ---------------------------------------------------------------------------
do
	local chain_box = { type = "fixed", fixed = { { -0.0625, -0.5, -0.0625, 0.0625, 0.5, 0.0625 } } }

	minetest.register_node("adamantine:chain", {
		description = "Adamantine Chain",
		_doc_items_longdesc = "Chains are adamantine metallic decoration blocks.",
		inventory_image = tint(img("cfp_gold_chain.png")),
		tiles = { tint(img("cfp_gold_chain_texture.png")), "" },
		drawtype = "mesh",
		mesh = "cfp_chain.obj",
		paramtype = "light",
		paramtype2 = "facedir",
		use_texture_alpha = "clip",
		is_ground_content = false,
		sunlight_propagates = true,
		collision_box = chain_box,
		selection_box = chain_box,
		climbable = minetest.settings:get_bool("cfp_climable_chains", true),
		groups = { pickaxey = 1, deco_block = 1, solid = 1 },
		sounds = metal(),
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end
			local on_rc = m7a.on_rightclick(itemstack, placer, pointed_thing)
			if on_rc then
				return itemstack
			end

			local p0 = pointed_thing.under
			local p1 = pointed_thing.above
			local param2 = 0

			local placer_pos = placer:get_pos()
			if placer_pos then
				local dir = { x = p1.x - placer_pos.x, y = p1.y - placer_pos.y, z = p1.z - placer_pos.z }
				param2 = minetest.dir_to_facedir(dir)
			end

			if     p0.y - 1 == p1.y then param2 = 20
			elseif p0.x - 1 == p1.x then param2 = 16
			elseif p0.x + 1 == p1.x then param2 = 12
			elseif p0.z - 1 == p1.z then param2 = 8
			elseif p0.z + 1 == p1.z then param2 = 4
			end

			return minetest.item_place_node(itemstack, placer, pointed_thing, param2)
		end,
		_mcl_blast_resistance = 6,
		_mcl_hardness = 5,
	})

	minetest.register_craft({
		output = "adamantine:chain 3",
		recipe = { { INGOT }, { INGOT }, { INGOT } },
	})
end

-- ---------------------------------------------------------------------------
-- Bars
-- ---------------------------------------------------------------------------
if type(mcl_panes) == "table" and mcl_panes.register_pane then
	mcl_panes.register_pane("adamantine:bars", {
		description = "Adamantine Bars",
		_doc_items_longdesc = "Adamantine bars neatly connect to their neighbors as you build them.",
		textures = {
			tint("mcl_gold_bars.png"), "", tint("mcl_gold_bars_top.png"),
		},
		use_texture_alpha = "clip",
		inventory_image = tint(img("cfp_gold_bars.png")),
		groups = { pickaxey = 1, iron_bars = 1 },
		sounds = metal(),
		recipe = {
			{ INGOT, INGOT, INGOT },
			{ INGOT, INGOT, INGOT },
		},
		_mcl_blast_resistance = 6,
		_mcl_hardness = 5,
	})
end

-- ---------------------------------------------------------------------------
-- Door (single + double)
-- ---------------------------------------------------------------------------
if type(mcl_doors) == "table" and mcl_doors.register_door then
	local door_inv = tint(img("cfp_gold_door_inv.png"))
	local door_tex = tint(img("cfp_door_gold.png"))
	local door_longdesc = "Adamantine doors are 2-block high barriers which can only be "
		.. "opened or closed by a redstone signal, and by hand."

	mcl_doors:register_door("adamantine:door", {
		description = "Adamantine Door",
		_doc_items_longdesc = door_longdesc,
		inventory_image = door_inv,
		tiles = { { name = door_tex, backface_culling = true } },
		tiles_top = {
			tint("mcl_gold_door_upper.png") .. "^[transformFX",
			tint("mcl_gold_door_side_upper.png"),
		},
		tiles_bottom = {
			tint("mcl_gold_door_lower.png") .. "^[transformFX",
			tint("mcl_gold_door_side_lower.png"),
		},
		groups = { pickaxey = 1, door_iron = 1 },
		sounds = metal(),
		sound_open = "doors_steel_door_open",
		sound_close = "doors_steel_door_close",
		_mcl_hardness = 4,
	})

	minetest.register_craft({
		output = "adamantine:door",
		recipe = {
			{ INGOT, INGOT },
			{ INGOT, INGOT },
			{ INGOT, INGOT },
		},
	})

	if m7a.register_door then
		m7a.register_door("adamantine:door", {
			single_description = "Adamantine Door",
			double_description = "Adamantine Double Door",
			reverse_description = "Adamantine Reverse Door",

			single_inv_image = door_inv,
			double_inv_image = tint(img("cfp_gold_double_door_inv.png")),

			tiles = { door_tex, door_tex, "" },
			groups = { pickaxey = 1, door_iron = 1 },
			pos_type = "side",
			types = { "double" },

			sounds = metal(),
			sound_open = "doors_steel_door_open",
			sound_close = "doors_steel_door_close",

			_doc_items_longdesc = door_longdesc,
			_mcl_hardness = 4,
		})

		if craftoplus.register_double_door_craft then
			craftoplus.register_double_door_craft("adamantine:door", "adamantine:door_double")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Trapdoor
-- ---------------------------------------------------------------------------
if m7a.register_multinode then
	local trap_tex = tint(img("cfp_gold_trapdoor.png"))
	local trap_inv = tint(img("cfp_gold_trapdoor_inv.png"))

	m7a.register_multinode("adamantine:trapdoor", {
		shared = {
			description = "Adamantine Trapdoor",
			tiles = { trap_tex, "" },
			inventory_image = trap_inv,
			wield_image = trap_inv,
			drawtype = "mesh",
			paramtype = "light",
			paramtype2 = "facedir",

			after_place_node = function(pos, placer, itemstack, pointed_thing)
				if m7a.is_pointing_above_middle(placer, pointed_thing) then
					minetest.swap_node(pos, { name = "adamantine:trapdoor", param2 = 20 })
				end
			end,

			sounds = metal(),
			drop = "adamantine:trapdoor",

			_mcl_hardness = 5,
			_mcl_blast_resistance = 6,
		},
		nodes = {
			[""] = {
				mesh = "cfp_trapdoor_closed.obj",
				selection_box = { type = "fixed", fixed = { { -0.5, -0.5, -0.5, 0.5, -0.35, 0.5 } } },
				collision_box = { type = "fixed", fixed = { { -0.5, -0.5, -0.5, 0.5, -0.35, 0.5 } } },
				groups = { pickaxey = 1, deco_block = 1, solid = 1 },
				on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
					minetest.swap_node(pos, { name = "adamantine:trapdoor_open", param2 = node.param2 })
				end,
			},
			["_open"] = {
				mesh = "cfp_trapdoor_open.obj",
				climbable = true,
				selection_box = { type = "fixed", fixed = { { -0.5, -0.5, 0.35, 0.5, 0.5, 0.5 } } },
				collision_box = { type = "fixed", fixed = { { -0.5, -0.5, 0.35, 0.5, 0.5, 0.5 } } },
				groups = { pickaxey = 1, deco_block = 1, solid = 1, not_in_creative_inventory = 1 },
				on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
					minetest.swap_node(pos, { name = "adamantine:trapdoor", param2 = node.param2 })
				end,
			},
		},
	})

	minetest.register_craft({
		output = "adamantine:trapdoor",
		recipe = {
			{ INGOT, INGOT },
			{ INGOT, INGOT },
		},
	})
end

-- ---------------------------------------------------------------------------
-- Carved block
-- ---------------------------------------------------------------------------
do
	local carved = "adamantine:block_carved"
	local carved_tex = tint(img("cfp_gold_block_carved.png"))
	local carved_groups = table.copy(block_def.groups or {})

	if m7a.override_groups then
		m7a.override_groups(BLOCK, { stonecuttable = 1 })
	end

	minetest.register_node(carved, {
		description = "Carved Adamantine Block",
		tiles = { carved_tex, carved_tex, carved_tex, carved_tex, carved_tex, carved_tex },
		is_ground_content = false,
		groups = carved_groups,
		sounds = metal(),
		_mcl_stonecutter_recipes = { BLOCK },
		_mcl_blast_resistance = block_def._mcl_blast_resistance or 12,
		_mcl_hardness = block_def._mcl_hardness or 6,
	})

	if type(mcl_stonecutter) == "table" and mcl_stonecutter.register_recipe then
		mcl_stonecutter.register_recipe(BLOCK, carved)
	end

	minetest.register_craft({
		output = carved .. " 4",
		recipe = {
			{ BLOCK, BLOCK },
			{ BLOCK, BLOCK },
		},
	})
	minetest.register_craft({
		type = "cooking",
		output = BLOCK,
		recipe = carved,
		cooktime = 5,
	})
end
