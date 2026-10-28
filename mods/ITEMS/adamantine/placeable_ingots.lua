-- Adamantine: placeable ingots (optional integration with CraftoPlus).
-- Modeled on the gold ingot code in CraftoPlus (items/gold/gold_material.lua).
-- Does nothing unless CraftoPlus is installed and its "Make Ingots Placeble"
-- setting (cfp_placeble_ingots) is enabled.

if not minetest.get_modpath("craftoplus") then
	return
end
if not (rawget(_G, "craftoplus") and craftoplus.make_craftitem_placeble) then
	return
end
if not minetest.settings:get_bool("cfp_placeble_ingots", true) then
	return
end

-- Reuse the (already recolored) adamantine block texture for the ingot piles,
-- the same way CraftoPlus uses the gold block texture for its gold ingots.
local block_def = minetest.registered_nodes["adamantine:block"]
local pile_tile = block_def and block_def.tiles and block_def.tiles[1]
if type(pile_tile) == "table" then
	pile_tile = pile_tile.name or pile_tile.image
end
if type(pile_tile) ~= "string" then
	return
end

local BOX_1 = { type = "fixed", fixed = { { -0.4, -0.5, -0.2, 0.4, -0.3, 0.2 } } }
local BOX_N = { type = "fixed", fixed = { { -0.4, -0.5, -0.4, 0.4, -0.2, 0.4 } } }

-- Same meshes CraftoPlus uses for its ingot piles (1, 2 and 3 ingots).
local piles = {
	{ suffix = "",   mesh = "mcl_ingot_1.obj", box = BOX_1, drop = "adamantine:ingot" },
	{ suffix = "_2", mesh = "mcl_ingot_2.obj", box = BOX_N, drop = "adamantine:ingot 2" },
	{ suffix = "_3", mesh = "mcl_ingot_3.obj", box = BOX_N, drop = "adamantine:ingot 3" },
}

for _, p in ipairs(piles) do
	minetest.register_node("adamantine:ingot_on_ground" .. p.suffix, {
		description = "Adamantine Ingot",
		drawtype = "mesh",
		mesh = p.mesh,
		tiles = { pile_tile },
		paramtype = "light",
		paramtype2 = "facedir",
		walkable = false,
		selection_box = p.box,
		groups = {
			dig_immediate = 3, falling_node = 1,
			attached_node = 1, not_in_creative_inventory = 1,
		},
		sounds = mcl_sounds.node_sound_metal_defaults(),
		drop = p.drop,
	})
end

-- Right-click with an ingot to place it; click the pile again to add more (max 3).
craftoplus.make_craftitem_placeble(
	"adamantine:ingot",
	"adamantine:ingot_on_ground",
	"adamantine:ingot_on_ground_2",
	"adamantine:ingot_on_ground_3"
)
