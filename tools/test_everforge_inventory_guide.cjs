// Native mcl_inventory tab integration test, executed with Fengari (not Luanti).
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const lua = require('luaparse');
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
print("Native inventory guide harness passed: visible Everforge tab button opens the /everforge hub from both inventory and progression forms.")
`;
const file = path.join(os.tmpdir(), 'everforge-inventory-guide-harness.lua');
fs.writeFileSync(file, script);
const output = cp.execFileSync('fengari', [file], { encoding: 'utf8' });
if (/stack traceback|error/i.test(output)) throw new Error(output);
process.stdout.write(output);
