// Fengari harness for the beginner guide. Recipe data is mocked from the
// Mineclonia source registrations; this is not an engine/runtime test.
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const lua = require('luaparse');
const source = fs.readFileSync('mods/MISC/everforge/crafting_guide.lua', 'utf8');
lua.parse(source, { luaVersion: '5.1' });

const script = `
local callbacks, current_form, current_spec = {}, nil, nil
local opened_book, opened_hub, suppressed, restored, writes = nil, nil, {}, {}, 0
local strings = {}
local function translator(text, ...)
  local args={...}
  local result=text:gsub("@(%d+)",function(i) return tostring(args[tonumber(i)]) end)
  return result
end
local function item(description) return {description=description or ""} end
core={
 get_translator=function() return translator end,
 formspec_escape=function(s) return tostring(s) end,
 colorize=function(_,s) return s end,
 get_player_information=function() return {lang_code="es"} end,
 get_translated_string=function(_,s) return s end,
 get_modpath=function() return "mods/MISC/everforge" end,
 registered_items={},
 register_on_player_receive_fields=function(fn) callbacks[#callbacks+1]=fn end,
 show_formspec=function(_,form,spec) current_form=form;current_spec=spec end,
 get_all_craft_recipes=function(name) return recipes[name] end,
 chat_send_player=function(_,s) strings[#strings+1]=s end,
 register_craft=function() writes=writes+1 end,
}
local known={
 ["mcl_trees:tree_oak"]="Oak Log", ["mcl_trees:wood_oak"]="Oak Planks",
 ["mcl_trees:tree_spruce"]="Spruce Log", ["mcl_trees:wood_spruce"]="Spruce Planks",
 ["mcl_core:stick"]="Stick", ["mcl_crafting_table:crafting_table"]="Crafting Table",
 ["mcl_tools:pick_wood"]="Wooden Pickaxe", ["mcl_tools:pick_copper"]="Copper Pickaxe",
 ["mcl_tools:pick_netherite"]="Netherite Pickaxe", ["mcl_tools:axe_wood"]="Wooden Axe",
 ["mcl_tools:shovel_wood"]="Wooden Shovel", ["mcl_tools:sword_wood"]="Wooden Sword",
 ["mcl_tools:hoe_wood"]="Wooden Hoe", ["mcl_torches:torch"]="Torch",
 ["mcl_furnaces:furnace"]="Furnace", ["mcl_chests:chest"]="Chest",
 ["mcl_beds:bed_red_bottom"]="Red Bed", ["mcl_beds:bed_blue_bottom"]="Blue Bed",
 ["mcl_core:cobble"]="Cobblestone",
 ["mcl_core:coal_lump"]="Coal", ["mcl_mobitems:charcoal_lump"]="Charcoal",
 ["mcl_bamboo:bamboo_small"]="Bamboo", ["mcl_dyes:red"]="Red Dye", ["mcl_dyes:blue"]="Blue Dye", ["mcl_wool:red"]="Red Wool", ["mcl_wool:blue"]="Blue Wool",
}
for id,desc in pairs(known) do core.registered_items[id]=item(desc) end
core.registered_nodes=core.registered_items
mcl_formspec={get_itemslot_bg_v4=function() return "" end}
mcl_tools={sets={
 wood={craftable=true}, stone={craftable=true}, copper={craftable=true}, netherite={craftable=false},
}}
local recipe=function(width,items,output)
 return {method="normal",width=width,items=items,output=output}
end
recipes={
 ["mcl_trees:wood_oak"]={recipe(1,{[1]="mcl_trees:tree_oak"},"mcl_trees:wood_oak 4")},
 ["mcl_trees:wood_spruce"]={recipe(1,{[1]="mcl_trees:tree_spruce"},"mcl_trees:wood_spruce 4")},
 ["mcl_core:stick"]={
  recipe(1,{[1]="group:wood",[2]="group:wood"},"mcl_core:stick 4"),
  recipe(1,{[1]="mcl_bamboo:bamboo_small",[2]="mcl_bamboo:bamboo_small"},"mcl_core:stick"),
 },
 ["mcl_crafting_table:crafting_table"]={recipe(2,{[1]="group:wood",[2]="group:wood",[3]="group:wood",[4]="group:wood"},"mcl_crafting_table:crafting_table")},
 ["mcl_tools:pick_wood"]={recipe(3,{[1]="group:wood",[2]="group:wood",[3]="group:wood",[5]="mcl_core:stick",[8]="mcl_core:stick"},"mcl_tools:pick_wood")},
 ["mcl_tools:pick_copper"]={recipe(3,{[1]="mcl_copper:copper_ingot",[2]="mcl_copper:copper_ingot",[3]="mcl_copper:copper_ingot",[5]="mcl_core:stick",[8]="mcl_core:stick"},"mcl_tools:pick_copper")},
 ["mcl_tools:axe_wood"]={
  recipe(2,{[1]="group:wood",[2]="group:wood",[3]="mcl_core:stick",[4]="group:wood",[5]="mcl_core:stick"},"mcl_tools:axe_wood"),
  recipe(2,{[1]="group:wood",[2]="group:wood",[3]="group:wood",[4]="mcl_core:stick",[6]="mcl_core:stick"},"mcl_tools:axe_wood"),
 },
 ["mcl_tools:shovel_wood"]={recipe(1,{[1]="group:wood",[2]="mcl_core:stick",[3]="mcl_core:stick"},"mcl_tools:shovel_wood")},
 ["mcl_tools:sword_wood"]={recipe(1,{[1]="group:wood",[2]="group:wood",[3]="mcl_core:stick"},"mcl_tools:sword_wood")},
 ["mcl_tools:hoe_wood"]={
  recipe(2,{[1]="group:wood",[2]="group:wood",[3]="mcl_core:stick",[5]="mcl_core:stick"},"mcl_tools:hoe_wood"),
  recipe(2,{[1]="group:wood",[2]="group:wood",[4]="mcl_core:stick",[6]="mcl_core:stick"},"mcl_tools:hoe_wood"),
 },
 ["mcl_torches:torch"]={recipe(1,{[1]="group:coal",[2]="mcl_core:stick"},"mcl_torches:torch 4")},
 ["mcl_furnaces:furnace"]={recipe(3,{[1]="group:cobble",[2]="group:cobble",[3]="group:cobble",[4]="group:cobble",[6]="group:cobble",[7]="group:cobble",[8]="group:cobble",[9]="group:cobble"},"mcl_furnaces:furnace")},
 ["mcl_chests:chest"]={recipe(3,{[1]="group:wood",[2]="group:wood",[3]="group:wood",[4]="group:wood",[6]="group:wood",[7]="group:wood",[8]="group:wood",[9]="group:wood"},"mcl_chests:chest")},
 ["mcl_beds:bed_red_bottom"]={
  recipe(3,{[1]="mcl_wool:red",[2]="mcl_wool:red",[3]="mcl_wool:red",[4]="group:wood",[5]="group:wood",[6]="group:wood"},"mcl_beds:bed_red_bottom"),
  {method="normal",width=0,items={[1]="group:bed",[2]="mcl_dyes:red"},output="mcl_beds:bed_red_bottom"},
 },
 ["mcl_beds:bed_blue_bottom"]={
  recipe(3,{[1]="mcl_wool:blue",[2]="mcl_wool:blue",[3]="mcl_wool:blue",[4]="group:wood",[5]="group:wood",[6]="group:wood"},"mcl_beds:bed_blue_bottom"),
  {method="normal",width=0,items={[1]="group:bed",[2]="mcl_dyes:blue"},output="mcl_beds:bed_blue_bottom"},
 },
}
-- Real recipe icons in the harness are registered items, as in the game.
for id,desc in pairs({["mcl_copper:copper_ingot"]="Copper Ingot",["mcl_wool:red"]="Red Wool",["mcl_wool:blue"]="Blue Wool",["mcl_dyes:blue"]="Blue Dye"}) do core.registered_items[id]=item(desc) end
local progressive=function() end
mcl_craftguide={get_recipe_filters=function() return { ["Default progressive filter"]=progressive } end,
 show=function(name) opened_book=name end}
everforge={
 _suppress_waila=function(_,form) suppressed[form]=true end,
 _restore_waila=function(_,form) restored[form]=true end,
 onboarding={show_hub=function(player) opened_hub=player end},
}
local p={name="Tester"}
function p:get_player_name() return self.name end
`;
const tests = `
dofile("mods/MISC/everforge/crafting_guide.lua")
local api=everforge.basic_crafting
api.show(p,"materials","logs",1)
assert(current_form=="everforge:basic_crafting")
assert(current_spec:find("Logs",1,true) and current_spec:find("This material is gathered from the world",1,true))
assert(current_spec:find("tree_oak",1,true),"actual log icon should appear")
assert(current_spec:find("undiscovered recipes",1,true),"explain the live progressive filter")
assert(current_spec:find("fixed Minecraft edition",1,true),"make Minecraft version scope explicit")
local function dispatch(fields)
 for _,cb in ipairs(callbacks) do if cb(p,current_form,fields) then return true end end
end
-- The page shows the live registered recipe and ingredient icon for planks.
dispatch({category_materials=true})
dispatch({item_planks=true})
assert(current_spec:find("Recipe 1 of 1",1,true))
assert(current_spec:find("mcl_trees:tree_oak",1,true))
assert(current_spec:find("Oak Log",1,true))
dispatch({next_variant=true})
assert(current_spec:find("Spruce Planks",1,true) and current_spec:find("mcl_trees:tree_spruce",1,true),"registered plank variants should be selectable")
-- Recipe alternatives are retained; both mirrored axes and both hoe layouts navigate.
dispatch({category_tools=true})
dispatch({item_axe=true})
assert(current_spec:find("Recipe 1 of 2",1,true) and current_spec:find("previous_recipe",1,true))
dispatch({next_recipe=true})
assert(current_spec:find("Recipe 2 of 2",1,true))
dispatch({item_hoe=true})
assert(current_spec:find("Recipe 1 of 2",1,true))
-- Variant selection reads the registered output and its actual material recipe.
dispatch({item_pick=true})
dispatch({variant_copper=true})
assert(current_spec:find("Copper Pickaxe",1,true))
assert(current_spec:find("mcl_copper:copper_ingot",1,true))
dispatch({variant_netherite=true})
assert(current_spec:find("No crafting-grid recipe is registered",1,true))
assert(current_spec:find("non-grid-craftable",1,true))
-- Survival examples render the real 3x3 patterns and show the bed's shapeless alternative.
dispatch({category_survival=true})
dispatch({item_furnace=true})
assert(current_spec:find("mcl_core:cobble",1,true) and current_spec:find("Crafting table 3×3",1,true))
dispatch({item_bed=true})
assert(current_spec:find("Recipe 1 of 2",1,true))
dispatch({next_recipe=true})
assert(current_spec:find("Recipe 2 of 2",1,true) and current_spec:find("Any bed",1,true))
dispatch({next_variant=true})
assert(current_spec:find("Blue Bed",1,true) and current_spec:find("mcl_wool:blue",1,true),"registered bed-color variants should show their matching wool recipe")
-- The complete guide remains native and does not disable or rewrite filters.
dispatch({general_book=true})
assert(opened_book=="Tester" and writes==0)
dispatch({back_hub=true})
assert(opened_hub==p)
assert(suppressed["everforge:basic_crafting"] and restored["everforge:basic_crafting"])
print("Basic crafting harness passed: 13 guide entries, registered recipe shapes/alternatives, material variants, progressive notice, native book, and hub navigation.")
`;
const file = path.join(os.tmpdir(), 'everforge-crafting-guide-harness.lua');
fs.writeFileSync(file, script + tests);
const result = cp.spawnSync('fengari', [file], { encoding: 'utf8' });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.status !== 0 || /stack traceback|error/i.test(result.stderr || '')) process.exit(1);
