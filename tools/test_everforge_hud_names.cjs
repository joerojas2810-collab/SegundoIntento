// Exercise the actual HUD naming helpers and target formatter with Fengari.
// This validates Lua logic, not client rendering or a live Mineclonia world.
const fs = require('fs');
const cp = require('child_process');
const os = require('os');
const path = require('path');
const lua = require('luaparse');
const source = fs.readFileSync('mods/MISC/everforge/init.lua', 'utf8');
const ast = lua.parse(source, { ranges: true, luaVersion: '5.1' });
const required = ['safe_hud_status', 'get_node_extra', 'localize_waila_lines', 'waila_text', 'valid_display_name', 'documentation_display_name'];
let code = `local function S(text,...) local a={...}; return (text:gsub('@(%d+)',function(i) return tostring(a[tonumber(i)]) end)) end
local localized_item_name
local smelt_recipes={}
local get_mining_requirement=function() return 'Recommended tool: Hand or any tool',nil end
local pointed, node, names, metadata = nil,nil,{},{}
local translated={Stone='Piedra',['Red Mushroom Block Cap']='Sombrero de hongo rojo'}
core={registered_items={},registered_nodes={},
 get_translated_string=function(lang,text) return translated[text] or text end,
 get_player_information=function() return {lang_code='es'} end,
 get_node_or_nil=function() return node end,
 get_meta=function() return metadata end,
 get_item_group=function() return 0 end}
doc={get_entry_definition=function(category,id) return names[category..':'..id] end}
mcl_util={get_pointed_thing=function() return pointed end}
metadata={get_string=function(_,key) return key=='infotext' and 'Working on mcl_hidden:private_node' or '' end,get_int=function() return 0 end}
local player={get_player_name=function() return 'tester' end}
`;
for (const name of required) {
  const declaration = ast.body.find(n => n.type === 'FunctionDeclaration' && n.identifier?.name === name);
  if (!declaration) throw new Error(`Missing Lua helper: ${name}`);
  code += source.slice(...declaration.range) + '\n';
}
const assignment = ast.body.find(n => n.type === 'AssignmentStatement' && n.variables?.some(v => v.type === 'Identifier' && v.name === 'localized_item_name'));
if (!assignment) throw new Error('Missing localized_item_name assignment');
code += source.slice(...assignment.range) + '\n';
code += `
local function read(id,def,doc_entry)
 core.registered_items[id]=def;core.registered_nodes[id]=def
 names['nodes:'..id]=doc_entry
 node={name=id};pointed={type='node',under={x=0,y=0,z=0}}
 return everforge._waila_text and everforge._waila_text(player)
end
-- Reproduce the exported reference to the actual formatter.
everforge={}
everforge._waila_text=waila_text
local named=read('mcl_core:stone',{description='Stone',groups={}})
assert(named:find('Piedra',1,true),'registered descriptions should use the player translation')
assert(not named:find('mcl_core:stone',1,true),'a technical node ID leaked into the HUD')
local alias=read('mcl_mushrooms:red_mushroom_block_cap_100010',{groups={}}, {name='Red Mushroom Block Cap'})
assert(alias:find('Sombrero de hongo rojo',1,true),'documentation aliases should provide a friendly name for internal nodes')
assert(not alias:find('100010',1,true),'internal numeric variant suffix leaked into the HUD')
local unnamed=read('mcl_hidden:private_node',{groups={}})
assert(not unnamed:find('mcl_hidden:private_node',1,true),'node without a description/alias must not fall back to its technical ID')
assert(unnamed:find('Unlabeled block',1,true),'a node without a friendly name should use a generic readable label')
assert(localized_item_name('mcl_tools:pick_wood')==nil,'unregistered tools must not fall back to an ID')
core.registered_items['mcl_tools:pick_wood']={description='Wooden Pickaxe'}
assert(localized_item_name('mcl_tools:pick_wood')=='Wooden Pickaxe','registered tool descriptions should be preserved')
local extra=get_node_extra('mcl_hidden:private_node',{groups={}}, {}, metadata)
assert(not table.concat(extra,'\\n'):find('mcl_hidden:private_node',1,true),'metadata status must not echo an unknown technical item ID')
pointed={type='object',ref={}}
assert(waila_text(player)=='','entities/objects are not named by this node-only HUD')
print('HUD naming harness passed: translated node, internal node alias, missing name, tool description, sanitized status, and non-node target.')
`;
const file = path.join(os.tmpdir(), 'everforge-hud-names-harness.lua');
fs.writeFileSync(file, code);
const result = cp.spawnSync('fengari', [file], { encoding: 'utf8' });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.status !== 0 || result.error) process.exit(1);
