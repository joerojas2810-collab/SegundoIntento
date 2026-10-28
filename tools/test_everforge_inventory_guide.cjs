// Native mcl_inventory tab integration test, executed with Fengari (not Luanti).
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const lua = require('luaparse');
const checkLayout = require('./check_formspec_layout.cjs');
const source = 'mods/MISC/everforge/progression/ui.lua';
lua.parse(fs.readFileSync(source, 'utf8'), { luaVersion: '5.1' });

const script = `
local callbacks, tab = {}, nil
local player = {name="Tester"}
function player:get_player_name() return self.name end
local progression = {
  config={mastery_base=100,discipline_base=100},
  model={
    disciplines={"mining","forging","combat","exploration","crafting"},
    skills={
      deep_miner={label="Miner",max=3,description="Mining"},
      forgemaster={label="Smith",max=3,description="Forging"},
      guard={label="Guard",max=3,description="Combat"},
      trailblazer={label="Scout",max=3,description="Exploration"},
    },
    level=function() return 1 end,
    next_xp=function() return 10 end,
    points=function() return 0 end,
    buy=function() return false,"No points" end,
  },
  load=function() return {mastery=0,disciplines={mining=0,forging=0,combat=0,exploration=0,crafting=0},skills={}} end,
  save=function() end,
  apply=function() end,
}
local opened_hub, inventory_updates, current_form = nil, 0, nil
everforge={
  progression=progression,
  onboarding={
    mark_manual_open=function() end,
    show_hub=function(p) opened_hub=p; current_form="everforge:guide" end,
  },
  _suppress_waila=function() end,
}
core={
  get_current_modname=function() return "everforge" end,
  get_translator=function() return function(s) return s end end,
  formspec_escape=function(s) return s end,
  show_formspec=function(_,name) current_form=name end,
  register_on_player_receive_fields=function(fn) callbacks[#callbacks+1]=fn end,
}
mcl_inventory={
  register_survival_inventory_tab=function(def) tab=def end,
  update_inventory=function() inventory_updates=inventory_updates+1 end,
}
dofile("mods/MISC/everforge/progression/ui.lua")
assert(tab and tab.id=="everforge_rpg" and tab.show_inventory==false)
local inv_fs=tab.build(player)
print("PROGRESSION_LAYOUT|"..inv_fs)
assert(inv_fs:find("Everforge Guide",1,true),"native inventory tab must show the direct guide button")
assert(inv_fs:find("guide;Everforge Guide",1,true),"guide button must have its expected callback field")
tab.handle(player,{guide=true})
assert(opened_hub==player and current_form=="everforge:guide")
assert(inventory_updates==0,"opening the guide must not rebuild or strand the inventory form")
opened_hub=nil
 everforge.open_progression(player)
assert(current_form=="everforge:progression")
callbacks[1](player,"everforge:progression",{guide=true})
assert(opened_hub==player and current_form=="everforge:guide")
-- Exercise the actual survival builder with the optional Everforge skin.
local joins={}
function core.register_on_joinplayer(fn) joins[#joins+1]=fn end
function core.register_on_leaveplayer() end
function core.register_on_player_inventory_action() end
function core.register_allow_player_inventory_action() end
function core.colorize(_,text) return text end
function player:get_inventory()
 return {get_width=function() return 2 end,get_stack=function() return {is_empty=function() return true end} end}
end
function player:get_meta() return {get_string=function() return "survival" end} end
mcl_player={get_player_formspec_model=function() return "" end}
dofile("mods/HUD/mcl_formspec/init.lua")
dofile("mods/HUD/mcl_inventory/survival.lua")
dofile("mods/MISC/everforge/progression/ui.lua")
joins[1](player)
local native=mcl_inventory.build_survival_formspec(player)
assert(native:find("size[11.75,10.9]",1,true),"keep the original inventory window size")
assert(native:find("no_prepend[]",1,true) and native:find("everforge_ui_slot.png",1,true))
assert(not native:find(",-1.34;",1,true),"tabs must remain inside the window")
assert(native:find("list[current_player;craft;6.625,1.55;2,1]",1,true))
assert(native:find("list[current_player;craft;6.625,2.8;2,1;2]",1,true))
assert(native:find("list[current_player;main;0.375,5.575;9,3;9]",1,true))
assert(native:find("list[current_player;main;0.375,9.525;9,1;]",1,true))
for index=1,4 do
 assert(native:find(";1,1;"..index.."]",1,true),"armor indices must remain unchanged")
end
assert(native:find("list[current_player;offhand;5.375,4.125;1,1]",1,true))
assert(native:find(";craftpreview;10.375,1.65;1,1;]",1,true))
for _,field in ipairs({"__mcl_crafting_fillgrid","__mcl_craftguide","__mcl_doc","__mcl_player_settings","__mcl_achievements"}) do
 assert(native:find(field,1,true),"preserve inventory action "..field)
end
mcl_inventory.survival_inventory_theme=nil
local vanilla=mcl_inventory.build_survival_formspec(player)
assert(vanilla:find("crafting_creative_active.png",1,true),"the builder must retain its unthemed fallback")
assert(vanilla:find("list[current_player;craft;6.625,0.875;2,1]",1,true))
print("Native inventory guide harness passed: visible Everforge tab button opens the /everforge hub from both inventory and progression forms.")
`;
const file = path.join(os.tmpdir(), 'everforge-inventory-guide-harness.lua');
fs.writeFileSync(file, script);
const output = cp.execFileSync('fengari', [file], { encoding: 'utf8' });
if (/stack traceback|error/i.test(output)) throw new Error(output);
for(const line of output.split(/\r?\n/)) {
 if(line.startsWith('PROGRESSION_LAYOUT|')) checkLayout(line.slice('PROGRESSION_LAYOUT|'.length),11.5,8);
 else if(line) console.log(line);
}
console.log('Survival inventory theme passed: native inventory lists, armor and crafting indices, action fields, in-window tabs, unthemed fallback and progression foreground geometry.');
