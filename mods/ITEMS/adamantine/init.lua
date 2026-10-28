-- Adamantine: endgame tier above Diamond and Netherite for Mineclonia.
-- Textures are Mineclonia's own diamond/iron textures, recolored in code.
-- Tool stats are read from the netherite tools at load time so every
-- adamantine tool is guaranteed to beat its netherite counterpart.

local TINT = "^[hsl:90:30:0^[contrast:20:0"

local METAL_TINT = "^[multiply:#b266ff^[contrast:15:0"

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- Inventory image of an existing item, or a fallback texture name.
local function item_image(name, fallback)
	local def = minetest.registered_items[name]
	local img = def and def.inventory_image
	if type(img) == "string" and img ~= "" then
		return img
	end
	return fallback
end

local function tint_tile(tile)
	if type(tile) == "string" then
		return tile .. TINT
	end
	if type(tile) == "table" then
		local copy = {}
		for k, v in pairs(tile) do
			copy[k] = v
		end
		if type(copy.name) == "string" then
			copy.name = copy.name .. TINT
		end
		if type(copy.image) == "string" then
			copy.image = copy.image .. TINT
		end
		return copy
	end
	return tile
end

-- Copies the tiles of an existing node and recolors them.
local function tint_tiles(nodename, fallback)
	local def = minetest.registered_nodes[nodename]
	local src
	if def and type(def.tiles) == "table" and #def.tiles > 0 then
		src = def.tiles
	else
		src = { fallback }
	end
	local out = {}
	for i, tile in ipairs(src) do
		out[i] = tint_tile(tile)
	end
	return out
end

local function diggroup_caps(toolname, group)
	local def = minetest.registered_tools[toolname]
	return (def and def._mcl_diggroups and def._mcl_diggroups[group]) or {}
end

-- ---------------------------------------------------------------------------
-- Textures
-- ---------------------------------------------------------------------------
local TEX = {
	ingot  = item_image("mcl_core:iron_ingot", "default_steel_ingot.png") .. METAL_TINT,
	lump   = item_image("mcl_raw_ores:raw_iron",
		item_image("mcl_core:diamond", "default_diamond.png")) .. METAL_TINT,
	sword  = item_image("mcl_tools:sword_diamond", "default_tool_diamondsword.png") .. TINT,
	pick   = item_image("mcl_tools:pick_diamond", "default_tool_diamondpick.png") .. TINT,
	axe    = item_image("mcl_tools:axe_diamond", "default_tool_diamondaxe.png") .. TINT,
	shovel = item_image("mcl_tools:shovel_diamond", "default_tool_diamondshovel.png") .. TINT,
	hoe    = item_image("mcl_farming:hoe_diamond", "farming_tool_diamondhoe.png") .. TINT,
	-- Worn armor textures
	helmet     = "mcl_armor_helmet_diamond.png" .. TINT,
	chestplate = "mcl_armor_chestplate_diamond.png" .. TINT,
	leggings   = "mcl_armor_leggings_diamond.png" .. TINT,
	boots      = "mcl_armor_boots_diamond.png" .. TINT,
	-- Inventory icons
	inv_helmet     = item_image("mcl_armor:helmet_diamond", "mcl_armor_inv_helmet_diamond.png") .. TINT,
	inv_chestplate = item_image("mcl_armor:chestplate_diamond", "mcl_armor_inv_chestplate_diamond.png") .. TINT,
	inv_leggings   = item_image("mcl_armor:leggings_diamond", "mcl_armor_inv_leggings_diamond.png") .. TINT,
	inv_boots      = item_image("mcl_armor:boots_diamond", "mcl_armor_inv_boots_diamond.png") .. TINT,
}

local TILES_BLOCK = tint_tiles("mcl_core:diamondblock", "default_diamond_block.png")
local TILES_ORE = tint_tiles("mcl_core:stone_with_diamond", "default_stone.png^default_diamond.png")
local TILES_DEEPSLATE_ORE = tint_tiles("mcl_deepslate:deepslate_with_diamond", "mcl_deepslate_diamond_ore.png")

-- ---------------------------------------------------------------------------
-- Tier constants (minimums; tool values are raised above netherite below)
-- ---------------------------------------------------------------------------
local SPEED = 16
local LEVEL = 6
local USES = 4062
local ENCHANTABILITY = 15

-- Ores need at least a diamond-level pickaxe.
local ORE_LEVEL = diggroup_caps("mcl_tools:pick_diamond", "pickaxey").level or 5

local wield_scale = (rawget(_G, "mcl_vars") and mcl_vars.tool_wield_scale)
	or { x = 1.8, y = 1.8, z = 1 }

-- Netherite counterparts (used for stat comparison and crafting recipes).
local NETHERITE = {
	sword      = "mcl_tools:sword_netherite",
	pick       = "mcl_tools:pick_netherite",
	axe        = "mcl_tools:axe_netherite",
	shovel     = "mcl_tools:shovel_netherite",
	hoe        = "mcl_farming:hoe_netherite",
	helmet     = "mcl_armor:helmet_netherite",
	chestplate = "mcl_armor:chestplate_netherite",
	leggings   = "mcl_armor:leggings_netherite",
	boots      = "mcl_armor:boots_netherite",
}

-- Stats that always beat the netherite tool: 1.5x speed, 2x durability,
-- +2 damage, same-or-faster attack. Dig level cannot exceed the top tier,
-- so it matches netherite.
local function derive_stats(nether_name, group, own_damage, own_interval)
	local def = minetest.registered_tools[nether_name]
	local caps = diggroup_caps(nether_name, group)
	local tc = (def and def.tool_capabilities) or {}
	local ndamage = (tc.damage_groups and tc.damage_groups.fleshy) or 0
	return {
		speed = math.max(SPEED, (caps.speed or 0) * 1.5),
		level = math.max(LEVEL, caps.level or 0),
		uses = math.max(USES, (caps.uses or 0) * 2),
		damage = math.max(own_damage, ndamage + 2),
		interval = math.min(own_interval, tc.full_punch_interval or own_interval),
		n_speed = caps.speed,
		n_uses = caps.uses,
		n_damage = ndamage,
		found = def ~= nil,
	}
end

local function log_stats(label, s)
	minetest.log("action", string.format(
		"[adamantine] %s: speed %s (netherite %s), uses %s (netherite %s), damage %s (netherite %s)%s",
		label, tostring(s.speed), tostring(s.n_speed), tostring(s.uses), tostring(s.n_uses),
		tostring(s.damage), tostring(s.n_damage),
		s.found and "" or " [netherite tool not found, used defaults]"))
end

-- ---------------------------------------------------------------------------
-- Materials
-- ---------------------------------------------------------------------------
minetest.register_craftitem("adamantine:lump", {
	description = "Adamantine Lump",
	_doc_items_longdesc = "A lump of raw adamantine. Smelt it in a furnace to get an adamantine ingot.",
	inventory_image = TEX.lump,
	groups = { craftitem = 1 },
})

minetest.register_craftitem("adamantine:ingot", {
	description = "Adamantine Ingot",
	_doc_items_longdesc = "An ingot of adamantine, a metal harder and tougher than diamond and netherite.",
	inventory_image = TEX.ingot,
	groups = { craftitem = 1 },
})

-- ---------------------------------------------------------------------------
-- Fortune support
-- Mineclonia reads the _mcl_fortune_drop field of a node when it is dug with a
-- Fortune pickaxe. Copy the diamond ore's own table (so the drop formula
-- matches diamond) and point it at the lump.
-- ---------------------------------------------------------------------------
local function make_fortune_drop()
	local src = minetest.registered_nodes["mcl_core:stone_with_diamond"]
	local fd = src and src._mcl_fortune_drop
	if type(fd) == "table" and fd.items then
		local copy = {}
		for k, v in pairs(fd) do
			copy[k] = v
		end
		copy.items = { "adamantine:lump" }
		return copy
	end
	return {
		discrete_uniform_distribution = true,
		items = { "adamantine:lump" },
		min_count = 1,
		max_count = 1,
		factor = 1,
	}
end

-- ---------------------------------------------------------------------------
-- Nodes
-- ---------------------------------------------------------------------------
minetest.register_node("adamantine:ore", {
	description = "Adamantine Ore",
	_doc_items_longdesc = "Adamantine ore is found very deep underground. It needs at least a diamond pickaxe to mine.",
	tiles = TILES_ORE,
	is_ground_content = true,
	groups = { pickaxey = ORE_LEVEL, building_block = 1, material_stone = 1 },
	drop = "adamantine:lump",
	sounds = mcl_sounds.node_sound_stone_defaults(),
	_mcl_blast_resistance = 4,
	_mcl_hardness = 4,
	_mcl_silk_touch_drop = true,
	_mcl_fortune_drop = make_fortune_drop(),
})

minetest.register_node("adamantine:deepslate_ore", {
	description = "Deepslate Adamantine Ore",
	_doc_items_longdesc = "Adamantine ore embedded in deepslate. It needs at least a diamond pickaxe to mine.",
	tiles = TILES_DEEPSLATE_ORE,
	is_ground_content = true,
	groups = { pickaxey = ORE_LEVEL, building_block = 1, material_stone = 1 },
	drop = "adamantine:lump",
	sounds = mcl_sounds.node_sound_stone_defaults(),
	_mcl_blast_resistance = 4,
	_mcl_hardness = 6,
	_mcl_silk_touch_drop = true,
	_mcl_fortune_drop = make_fortune_drop(),
})

minetest.register_node("adamantine:block", {
	description = "Block of Adamantine",
	_doc_items_longdesc = "A block of adamantine. Very hard; needs at least a diamond pickaxe to mine.",
	tiles = TILES_BLOCK,
	is_ground_content = false,
	groups = { pickaxey = ORE_LEVEL, building_block = 1 },
	sounds = mcl_sounds.node_sound_metal_defaults(),
	_mcl_blast_resistance = 12,
	_mcl_hardness = 6,
})

-- ---------------------------------------------------------------------------
-- Ore generation (newly generated chunks only)
-- Diamond in Mineclonia: about 4 ores per cluster, 1 cluster per 15^3 nodes.
-- Adamantine: 3 ores per cluster, 1 cluster per 25^3 nodes (about 6x fewer
-- ores than diamond), only in the deepest part of the overworld.
-- ---------------------------------------------------------------------------
local ORE_Y_MAX = -64
local ore_y_min = (rawget(_G, "mcl_vars") and mcl_vars.mg_overworld_min) or -128
if ore_y_min >= ORE_Y_MAX then
	ore_y_min = -128
end

local function register_adamantine_ore(ore_name, replacement, y_min, y_max, suffix)
	if not minetest.registered_nodes[replacement] then return end
	-- Legacy-mapgen fallback. The primary Mineclonia mapgen path below uses
	-- a levelgen placed feature and does not read engine register_ore entries.
	minetest.register_ore({
		ore_type = "scatter", ore = ore_name, wherein = replacement,
		clust_scarcity = 24 * 24 * 24, clust_num_ores = 2, clust_size = 2,
		y_min = y_min, y_max = y_max,
	})
	if not (mcl_levelgen and mcl_levelgen.register_configured_feature
		and mcl_levelgen.uniform_height) then return end
	local configured = "adamantine:ore_" .. suffix .. "_configured"
	local placed = "adamantine:ore_" .. suffix .. "_placed"
	mcl_levelgen.register_configured_feature(configured, {
		feature = "mcl_levelgen:ore", size = 2,
		discard_chance_on_air_exposure = 0.3,
			substitutions = mcl_levelgen.construct_ore_substitution_list({
			{target = suffix == "deepslate" and "group:deepslate_ore_target" or "group:stone_ore_target", replacement = ore_name},
		}),
	})
	mcl_levelgen.register_placed_feature(placed, {
		configured_feature = configured,
		placement_modifiers = {
			mcl_levelgen.build_rarity_filter(4),
			mcl_levelgen.build_in_square(),
			mcl_levelgen.build_height_range(mcl_levelgen.uniform_height(y_min, y_max)),
			mcl_levelgen.build_in_biome(),
		},
	})
	for _, biome in pairs(mcl_levelgen.registered_biomes or {}) do
		if biome.groups and biome.groups.is_overworld and biome.features[7]
			and table.indexof(biome.features[7], placed) == -1 then
			biome.features[7][#biome.features[7] + 1] = placed
		end
	end
end

register_adamantine_ore("adamantine:ore", "mcl_core:stone", ore_y_min, ORE_Y_MAX, "stone")
register_adamantine_ore("adamantine:deepslate_ore", "mcl_deepslate:deepslate", ore_y_min, ORE_Y_MAX, "deepslate")

-- ---------------------------------------------------------------------------
-- Tools
-- ---------------------------------------------------------------------------
local diamond_axe = minetest.registered_tools["mcl_tools:axe_diamond"]
local diamond_shovel = minetest.registered_tools["mcl_tools:shovel_diamond"]
local diamond_hoe = minetest.registered_tools["mcl_farming:hoe_diamond"]

-- Sword
local sword_s = derive_stats(NETHERITE.sword, "swordy", 10, 0.625)
log_stats("sword", sword_s)
minetest.register_tool("adamantine:sword", {
	description = "Adamantine Sword",
	_doc_items_longdesc = "An adamantine sword. Deals more damage than diamond or netherite and lasts far longer.",
	inventory_image = TEX.sword,
	wield_scale = wield_scale,
	groups = { weapon = 1, sword = 1, dig_speed_class = 6, enchantability = ENCHANTABILITY },
	tool_capabilities = {
		full_punch_interval = sword_s.interval,
		max_drop_level = sword_s.level,
		damage_groups = { fleshy = sword_s.damage },
		punch_attack_uses = sword_s.uses,
	},
	sound = { breaks = "default_tool_breaks" },
	_repair_material = "adamantine:ingot",
	_mcl_toollike_wield = true,
	_mcl_diggroups = {
		swordy = { speed = sword_s.speed, level = sword_s.level, uses = sword_s.uses },
		swordy_cobweb = { speed = sword_s.speed, level = sword_s.level, uses = sword_s.uses },
	},
})

-- Pickaxe
local pick_s = derive_stats(NETHERITE.pick, "pickaxey", 8, 0.83333333)
log_stats("pickaxe", pick_s)
minetest.register_tool("adamantine:pick", {
	description = "Adamantine Pickaxe",
	_doc_items_longdesc = "An adamantine pickaxe. It mines faster than any other pickaxe and can break every block that needs a pickaxe.",
	inventory_image = TEX.pick,
	wield_scale = wield_scale,
	groups = { tool = 1, pickaxe = 1, dig_speed_class = 6, enchantability = ENCHANTABILITY },
	tool_capabilities = {
		full_punch_interval = pick_s.interval,
		max_drop_level = pick_s.level,
		damage_groups = { fleshy = pick_s.damage },
		punch_attack_uses = pick_s.uses,
	},
	sound = { breaks = "default_tool_breaks" },
	_repair_material = "adamantine:ingot",
	_mcl_toollike_wield = true,
	_mcl_diggroups = {
		pickaxey = { speed = pick_s.speed, level = pick_s.level, uses = pick_s.uses },
	},
})

-- Axe
local axe_s = derive_stats(NETHERITE.axe, "axey", 12, 1.0)
log_stats("axe", axe_s)
minetest.register_tool("adamantine:axe", {
	description = "Adamantine Axe",
	_doc_items_longdesc = "An adamantine axe. It chops wood extremely fast and hits very hard.",
	inventory_image = TEX.axe,
	wield_scale = wield_scale,
	groups = { tool = 1, axe = 1, dig_speed_class = 6, enchantability = ENCHANTABILITY },
	tool_capabilities = {
		full_punch_interval = axe_s.interval,
		max_drop_level = axe_s.level,
		damage_groups = { fleshy = axe_s.damage },
		punch_attack_uses = axe_s.uses,
	},
	on_place = diamond_axe and diamond_axe.on_place or nil,
	sound = { breaks = "default_tool_breaks" },
	_repair_material = "adamantine:ingot",
	_mcl_toollike_wield = true,
	_mcl_diggroups = {
		axey = { speed = axe_s.speed, level = axe_s.level, uses = axe_s.uses },
	},
})

-- Shovel
local shovel_s = derive_stats(NETHERITE.shovel, "shovely", 8, 1.0)
log_stats("shovel", shovel_s)
minetest.register_tool("adamantine:shovel", {
	description = "Adamantine Shovel",
	_doc_items_longdesc = "An adamantine shovel. It digs soft blocks extremely fast.",
	inventory_image = TEX.shovel,
	wield_scale = wield_scale,
	groups = { tool = 1, shovel = 1, dig_speed_class = 6, enchantability = ENCHANTABILITY },
	tool_capabilities = {
		full_punch_interval = shovel_s.interval,
		max_drop_level = shovel_s.level,
		damage_groups = { fleshy = shovel_s.damage },
		punch_attack_uses = shovel_s.uses,
	},
	on_place = diamond_shovel and diamond_shovel.on_place or nil,
	sound = { breaks = "default_tool_breaks" },
	_repair_material = "adamantine:ingot",
	_mcl_toollike_wield = true,
	_mcl_diggroups = {
		shovely = { speed = shovel_s.speed, level = shovel_s.level, uses = shovel_s.uses },
	},
})

-- Hoe
local hoe_s = derive_stats(NETHERITE.hoe, "hoey", 1, 0.25)
log_stats("hoe", hoe_s)
minetest.register_tool("adamantine:hoe", {
	description = "Adamantine Hoe",
	_doc_items_longdesc = "An adamantine hoe. It tills soil and almost never wears out.",
	inventory_image = TEX.hoe,
	wield_scale = wield_scale,
	groups = { tool = 1, hoe = 1, dig_speed_class = 6, enchantability = ENCHANTABILITY },
	tool_capabilities = {
		full_punch_interval = hoe_s.interval,
		max_drop_level = hoe_s.level,
		damage_groups = { fleshy = hoe_s.damage },
		punch_attack_uses = hoe_s.uses,
	},
	on_place = diamond_hoe and diamond_hoe.on_place or nil,
	sound = { breaks = "default_tool_breaks" },
	_repair_material = "adamantine:ingot",
	_mcl_toollike_wield = true,
	_mcl_diggroups = {
		hoey = { speed = hoe_s.speed, level = hoe_s.level, uses = hoe_s.uses },
	},
})

-- ---------------------------------------------------------------------------
-- Armor
-- Diamond: durability 363, toughness 2. Netherite: durability 407, toughness 3.
-- Adamantine: durability 800, toughness 5, points 3/8/6/3 (20 total).
-- Items: adamantine:helmet_adamantine, chestplate_adamantine,
-- leggings_adamantine, boots_adamantine.
-- ---------------------------------------------------------------------------
local ARMOR_PIECES = { "helmet", "chestplate", "leggings", "boots" }

if minetest.global_exists("mcl_armor") and mcl_armor.register_set then
	mcl_armor.register_set({
		name = "adamantine",
		description = "Adamantine",
		durability = 800,
		enchantability = ENCHANTABILITY,
		points = { head = 3, torso = 8, legs = 6, feet = 3 },
		toughness = 5,
		textures = {
			head = TEX.helmet,
			torso = TEX.chestplate,
			legs = TEX.leggings,
			feet = TEX.boots,
		},
		craft_material = "adamantine:ingot",
		repair_material = "adamantine:ingot",
	})

	local armor_sounds = {
		_mcl_armor_equip = "mcl_armor_equip_diamond",
		_mcl_armor_unequip = "mcl_armor_unequip_diamond",
	}

	for _, piece in ipairs(ARMOR_PIECES) do
		local itemname = "adamantine:" .. piece .. "_adamantine"
		if minetest.registered_items[itemname] then
			minetest.override_item(itemname, {
				inventory_image = TEX["inv_" .. piece],
				sounds = armor_sounds,
			})
			-- Remove the default all-ingot recipe; the netherite-upgrade
			-- recipes below replace it.
			minetest.clear_craft({ output = itemname })
		end
	end
end

-- ---------------------------------------------------------------------------
-- Crafting and smelting
-- ---------------------------------------------------------------------------
local I = "adamantine:ingot"
local STICK = "mcl_core:stick"

-- Registers a recipe only if the required netherite item exists.
local function craft_upgrade(output, nether_item, recipe)
	if not minetest.registered_items[nether_item] then
		minetest.log("warning", "[adamantine] " .. nether_item
			.. " not found; no recipe registered for " .. output)
		return
	end
	minetest.register_craft({ output = output, recipe = recipe })
end

-- 9 ingots -> 1 block, and back
minetest.register_craft({
	output = "adamantine:block",
	recipe = {
		{ I, I, I },
		{ I, I, I },
		{ I, I, I },
	},
})

minetest.register_craft({
	type = "shapeless",
	output = "adamantine:ingot 9",
	recipe = { "adamantine:block" },
})

-- 1 lump -> 1 ingot
minetest.register_craft({
	type = "cooking",
	output = "adamantine:ingot",
	recipe = "adamantine:lump",
	cooktime = 10,
})

-- Tools: adamantine ingots + the netherite tool + stick(s)
local N = NETHERITE

craft_upgrade("adamantine:sword", N.sword, {
	{ I },
	{ I },
	{ N.sword },
})

craft_upgrade("adamantine:pick", N.pick, {
	{ I, I, I },
	{ "", N.pick, "" },
	{ "", STICK, "" },
})

craft_upgrade("adamantine:axe", N.axe, {
	{ I, I },
	{ I, N.axe },
	{ "", STICK },
})
craft_upgrade("adamantine:axe", N.axe, {
	{ I, I },
	{ N.axe, I },
	{ STICK, "" },
})

craft_upgrade("adamantine:shovel", N.shovel, {
	{ I },
	{ N.shovel },
	{ STICK },
})

craft_upgrade("adamantine:hoe", N.hoe, {
	{ I, I },
	{ "", N.hoe },
	{ "", STICK },
})
craft_upgrade("adamantine:hoe", N.hoe, {
	{ I, I },
	{ N.hoe, "" },
	{ STICK, "" },
})

-- Armor: adamantine ingots + the netherite piece in the centre
craft_upgrade("adamantine:helmet_adamantine", N.helmet, {
	{ I, I, I },
	{ I, N.helmet, I },
})

craft_upgrade("adamantine:chestplate_adamantine", N.chestplate, {
	{ I, I, I },
	{ I, N.chestplate, I },
	{ I, I, I },
})

craft_upgrade("adamantine:leggings_adamantine", N.leggings, {
	{ I, I, I },
	{ I, N.leggings, I },
	{ I, "", I },
})

craft_upgrade("adamantine:boots_adamantine", N.boots, {
	{ I, N.boots, I },
	{ I, "", I },
})

dofile(minetest.get_modpath("adamantine") .. "/placeable_ingots.lua")

dofile(minetest.get_modpath("adamantine") .. "/craftoplus_items.lua")
