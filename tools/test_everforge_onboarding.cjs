// Runtime harness for onboarding.lua, executed with Fengari; no Luanti world is started.
// Requires luaparse and fengari-node-cli on NODE_PATH / PATH.
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const lua = require('luaparse');
const checkLayout = require('./check_formspec_layout.cjs');
const sourcePath = 'mods/MISC/everforge/onboarding.lua';
const source = fs.readFileSync(sourcePath, 'utf8');
lua.parse(source, { luaVersion: '5.1' });

const harness = `
local queue, callbacks, join_callback, command = {}, {}, nil, nil
local current_form, current_spec, native, messages, closed, screens = nil, nil, nil, {}, {}, {}
local region_state = "ready"
local function dispatch(player, formname, fields)
  for _, callback in ipairs(callbacks) do
    if callback(player, formname, fields) then return true end
  end
end
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
  if s=="There is no prescribed route. Set your own pace: explore, build, mine, or let the landscape suggest a direction. This story is yours." then
    s="Unsafe <tag> & translated </global> text"
  end
  local args={...}
  return (s:gsub("@(%d+)",function(i) return tostring(args[tonumber(i)]) end))
end end
function core.get_modpath() return "mods/MISC/everforge" end
core.registered_items={}
core.registered_nodes=core.registered_items
function core.get_player_information() return {lang_code="es"} end
function core.get_translated_string(_,s) return s end
function core.get_all_craft_recipes() return nil end
mcl_formspec={get_itemslot_bg_v4=function() return "" end}
mcl_tools={sets={}}
function core.register_craft() error("guide must not register recipes") end
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
function core.get_modpath(name)
  if name=="mcl_achievements" then return "mods/HUD/mcl_achievements" end
  if name=="everforge" then return "mods/MISC/everforge" end
end
function core.chat_send_player(_,s) messages[#messages+1]=s end
function core.get_player_privs() return {} end

function core.hypertext_escape(s) return (s:gsub(string.char(92),string.char(92,92)):gsub("<",string.char(92).."<"):gsub(">",string.char(92)..">")) end
function core.register_on_leaveplayer() end
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
dispatch(player,current_form,{hub_next=true})
assert(current_spec:find("craftguide_book.png",1,true) and current_spec:find("mcl_achievements_button.png",1,true))
dispatch(player,current_form,{hub_previous=true})
assert(current_spec:find("Basic Crafting",1,true),"hub must expose the new basic crafting guide")
dispatch(player,current_form,{basic_crafting=true})
assert(current_form=="everforge:basic_crafting" and current_spec:find("This material is gathered from the world",1,true))
dispatch(player,current_form,{general_book=true})
assert(native=="recipes","basic guide must reuse the general recipe book")
everforge.onboarding.show_inventory_help(player)
assert(current_form=="everforge:inventory_help" and current_spec:find("Complete Help",1,true))
dispatch(player,current_form,{complete_help=true})
assert(native=="full_help","inventory help chooser must preserve complete help")
everforge.onboarding.show_inventory_help(player)
dispatch(player,current_form,{basic_crafting=true})
assert(current_form=="everforge:basic_crafting","inventory help chooser must open basic crafting")
command.func("Tester","")
dispatch(player,current_form,{intro=true})
assert(current_form == "everforge:introduction")
local intro_titles={"A World Without a Written Destination","What You Do Defines You","Forge Your Own Path","Not Everything Is in Sight","The World Continues With You"}
for i,title in ipairs(intro_titles) do
  assert(current_spec:find(title,1,true),"missing narrative card "..i)
  assert(not current_spec:find("</global>",1,true),"invalid global closing tag in narrative card "..i)
  if i==1 then
    assert(current_spec:find("Unsafe "..string.char(92).."<tag"..string.char(92).."> & translated "..string.char(92).."</global"..string.char(92).."> text",1,true),"translated hypertext was not escaped")
  end
  if i<#intro_titles then dispatch(player,current_form,{next=true}) end
end
assert(current_spec:find("The World Continues With You",1,true))
assert(current_spec:find("Would you like to see a few first steps?",1,true))
dispatch(player,current_form,{next=true})
assert(closed["everforge:introduction"] == 1)
assert(player.meta:get_int("everforge:onboarding:auto_intro_seen") == 1)
assert(player.meta:get_int("everforge:onboarding:intro_done") == 1)
while #queue>0 do local fn=table.remove(queue,1); fn() end
assert(messages[#messages]:find("/everforge first_steps",1,true))
command.func("Tester","first_steps")
assert(current_form == "everforge:first_steps" and current_spec:find("Your First Tools",1,true))
dispatch(player,current_form,{skip=true,quit=true})
assert(everforge.last_restored == "everforge:first_steps")
command.func("Tester","recipes"); assert(native=="recipes")
command.func("Tester","achievements"); assert(native=="achievements")
command.func("Tester","help"); assert(current_form=="everforge:guide_help")
command.func("Tester","controls"); assert(native=="basics:controls")
command.func("Tester","commands"); assert(native=="advanced:commands")
command.func("Tester","progression"); assert(native=="progression")

local returner=make_player("Returner")
command.func("Returner","first_steps")
assert(current_spec:find("see_basic_recipes",1,true))
dispatch(returner,current_form,{see_basic_recipes=true})
assert(current_form=="everforge:basic_crafting" and current_spec:find("Back to tutorial",1,true))
assert(returner.meta:get_int("everforge:onboarding:intro_done")==0)
dispatch(returner,current_form,{category_tools=true})
dispatch(returner,current_form,{item_axe=true})
dispatch(returner,current_form,{back_hub=true})
assert(current_form=="everforge:first_steps" and current_spec:find("Your First Tools",1,true))
assert(returner.meta:get_int("everforge:onboarding:intro_done")==0)
dispatch(returner,current_form,{next=true})
assert(current_spec:find("Learn by Doing",1,true),"continue the suspended tutorial instead of restarting/completing it")
local full_steps=make_player("FullSteps")
command.func("FullSteps","first_steps")
local step_titles={"Your First Tools","Learn by Doing","Prepare Your Shelter","Discover the Unknown","Know Your Tools"}
for i,title in ipairs(step_titles) do
  assert(current_spec:find(title,1,true),"missing practical card "..i)
  assert(not current_spec:find("</global>",1,true),"invalid global closing tag in practical card "..i)
  if i<#step_titles then dispatch(full_steps,current_form,{next=true}) end
end
dispatch(full_steps,current_form,{next=true})
assert(closed["everforge:first_steps"]==1,"finishing practical cards must close the form")

local optional=make_player("Optional")
command.func("Optional","intro")
for _=1,4 do dispatch(optional,current_form,{next=true}) end
dispatch(optional,current_form,{steps_now=true})
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
local saved_auto=player.meta:get_int("everforge:onboarding:auto_intro_seen")
local saved_done=player.meta:get_int("everforge:onboarding:intro_done")
dofile("mods/MISC/everforge/onboarding.lua")
assert(player.meta:get_int("everforge:onboarding:auto_intro_seen")==saved_auto)
assert(player.meta:get_int("everforge:onboarding:intro_done")==saved_done)
assert(command.func("Tester","")==true and current_form=="everforge:guide")
for _,screen in ipairs(screens) do print("SCREEN|"..screen[1].."|"..screen[2]:gsub(string.char(10)," ")) end
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
  const size = name === 'everforge:guide_help' ? [12, 6.2]
    : name === 'everforge:inventory_help' ? [12, 5.8]
    : name === 'everforge:basic_crafting' ? [12, 8.2]
    : [12, 7.5];
  checkLayout(spec, ...size);
  if (spec.includes('</global>')) throw new Error(`${name}: invalid closing global tag reached the client`);
  if (spec.includes('Mineclonia')) throw new Error(`${name}: internal dependency brand leaked into Everforge UI`);
  const stylesOpen = (spec.match(/<style/g) || []).length;
  const stylesClose = (spec.match(/<\/style>/g) || []).length;
  if (stylesOpen !== stylesClose) throw new Error(`${name}: unbalanced hypertext style tags`);
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
