// Runtime harness for onboarding.lua, executed with Fengari; no Luanti world is started.
// Requires luaparse and fengari-node-cli on NODE_PATH / PATH.
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const lua = require('luaparse');
const sourcePath = 'mods/MISC/everforge/onboarding.lua';
const source = fs.readFileSync(sourcePath, 'utf8');
lua.parse(source, { luaVersion: '5.1' });

const harness = `
local queue, callbacks, join_callback, command = {}, {}, nil, nil
local current_form, current_spec, native, messages, closed, screens = nil, nil, nil, {}, {}, {}
local region_state = "ready"
local players = {}
function make_player(name)
  local values = {}
  local meta = {
    get_int=function(_,k) return values[k] or 0 end,
    set_int=function(_,k,v) values[k]=v end,
  }
  local p={meta=meta,name=name}
  function p:get_meta() return self.meta end
  function p:get_player_name() return self.name end
  function p:get_pos() return {x=0,y=3,z=0} end
  players[name]=p
  return p
end
local player=make_player("Tester")
core={}
function core.get_current_modname() return "everforge" end
function core.get_translator() return function(s,...)
  local args={...}
  return (s:gsub("@(%d+)",function(i) return tostring(args[tonumber(i)]) end))
end end
function core.formspec_escape(s) return s end
function core.colorize(_,s) return s end
function core.show_formspec(_,name,spec) current_form=name;current_spec=spec;screens[#screens+1]={name,spec} end
function core.close_formspec(_,name) closed[name]=(closed[name] or 0)+1 end
function core.register_on_player_receive_fields(fn) callbacks[#callbacks+1]=fn end
function core.register_on_joinplayer(fn) join_callback=fn end
function core.register_chatcommand(name,def) if name=="everforge" then command=def end end
function core.after(_,fn) queue[#queue+1]=fn end
function core.get_player_by_name(name) return players[name] end
function core.get_node_or_nil() return {name="air"} end
function core.get_modpath(name) if name=="mcl_achievements" then return "mods/HUD/mcl_achievements" end end
function core.chat_send_player(_,s) messages[#messages+1]=s end
function core.get_player_privs() return {} end

everforge={}
everforge.start_region={get=function() return {state=region_state} end}
everforge._suppress_waila=function(_,form) everforge.last_suppressed=form end
everforge._restore_waila=function(_,form) everforge.last_restored=form end
everforge.open_progression=function() native="progression" end
mcl_biome_dispatch={in_limbo=function() return false end}
mcl_craftguide={show=function() native="recipes" end}
awards={show_to=function() native="achievements" end}
doc={data={categories={basics={entries={controls={}}},advanced={entries={commands={}}}}},
 show_entry=function(_,category,entry) native=category..":"..entry end,
 show_doc=function() native="full_help" end}
`;
const script = harness + `
dofile("mods/MISC/everforge/onboarding.lua")
assert(command and command.params:find("first_steps",1,true))
assert(command.func("Tester","") == true)
assert(current_form == "everforge:guide")
assert(current_spec:find("craftguide_book.png",1,true) and current_spec:find("mcl_achievements_button.png",1,true))
callbacks[1](player,current_form,{intro=true})
assert(current_form == "everforge:introduction" and current_spec:find("A World Without a Written Destination",1,true))
for _=1,4 do callbacks[1](player,current_form,{next=true}) end
assert(current_spec:find("The World Continues With You",1,true))
assert(current_spec:find("Would you like to see a few first steps?",1,true))
callbacks[1](player,current_form,{next=true})
assert(closed["everforge:introduction"] == 1)
assert(player.meta:get_int("everforge:onboarding:auto_intro_seen") == 1)
assert(player.meta:get_int("everforge:onboarding:intro_done") == 1)
while #queue>0 do local fn=table.remove(queue,1); fn() end
assert(messages[#messages]:find("/everforge first_steps",1,true))
command.func("Tester","first_steps")
assert(current_form == "everforge:first_steps" and current_spec:find("Your First Tools",1,true))
callbacks[1](player,current_form,{skip=true,quit=true})
assert(everforge.last_restored == "everforge:first_steps")
command.func("Tester","recipes"); assert(native=="recipes")
command.func("Tester","achievements"); assert(native=="achievements")
command.func("Tester","help"); assert(current_form=="everforge:guide_help")
command.func("Tester","controls"); assert(native=="basics:controls")
command.func("Tester","commands"); assert(native=="advanced:commands")
command.func("Tester","progression"); assert(native=="progression")

local optional=make_player("Optional")
command.func("Optional","intro")
for _=1,4 do callbacks[1](optional,current_form,{next=true}) end
callbacks[1](optional,current_form,{steps_now=true})
assert(current_form=="everforge:first_steps")
assert(optional.meta:get_int("everforge:onboarding:intro_done")==1)
assert(optional.meta:get_int("everforge:onboarding:first_steps_offer_seen")==1)

local newcomer=make_player("Newcomer")
region_state="building"
join_callback(newcomer)
local previous_form=current_form
local delayed=table.remove(queue,1); assert(delayed); delayed()
-- No welcome while the camp is being built: the prior active form remains unchanged.
assert(current_form == previous_form)
assert(newcomer.meta:get_int("everforge:onboarding:auto_intro_seen") == 0)
region_state="ready"
while #queue>0 do local fn=table.remove(queue,1); fn() end
assert(current_form=="everforge:introduction")
assert(newcomer.meta:get_int("everforge:onboarding:auto_intro_seen") == 1)
join_callback(newcomer)
assert(#queue==0)
for _,screen in ipairs(screens) do print("SCREEN|"..screen[1].."|"..screen[2]) end
print("Onboarding runtime harness passed: navigation, persistence, camp-ready gate, optional prompt, and Mineclonia-native routes.")
`;
const file = path.join(os.tmpdir(), 'everforge-onboarding-harness.lua');
fs.writeFileSync(file, script);
const output = cp.execFileSync('fengari', [file], { encoding: 'utf8' });
if (/stack traceback|error/i.test(output)) throw new Error(output);
let screens = 0, widgets = 0;
for (const line of output.split(/\r?\n/)) {
  if (!line.startsWith('SCREEN|')) continue;
  const [, name, ...rest] = line.split('|');
  const spec = rest.join('|');
  const size = name === 'everforge:guide_help' ? [12, 6.2] : [12, 7.5];
  screens++;
  for (const match of spec.matchAll(/(box|button|button_exit|image|hypertext)\[([^\]]+)\]/g)) {
    const fields = match[2].split(';');
    // Parse x,y;w,h for each measured formspec element.
    const pos = fields[0].split(',').map(Number);
    const dim = fields[1].split(',').map(Number);
    if (pos.length < 2 || dim.length < 2 || pos.some(Number.isNaN) || dim.some(Number.isNaN))
      throw new Error(`${name}: malformed ${match[0]}`);
    if (pos[0] < 0 || pos[1] < 0 || pos[0] + dim[0] > size[0] + .001 || pos[1] + dim[1] > size[1] + .001)
      throw new Error(`${name}: element outside formspec ${match[0]}`);
    widgets++;
  }
}
if (screens < 12) throw new Error(`Expected multiple captured guide forms, got ${screens}`);
console.log(`Onboarding runtime harness passed: navigation, persistence, camp-ready gate, optional prompt, and native Mineclonia routes; ${screens} forms, ${widgets} widget bounds checked.`);
