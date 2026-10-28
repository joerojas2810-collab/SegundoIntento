// Executes real melter metadata / WAILA producers and the read-only probe.
// Requires luaparse and fengari-node-cli; run from game root.
const fs=require('fs'),cp=require('child_process'),os=require('os'),path=require('path'),lua=require('luaparse');
const source=fs.readFileSync('mods/MISC/everforge/init.lua','utf8');
const ast=lua.parse(source,{ranges:true,luaVersion:'5.1'});
let code=`local fields={infotext='old native duplicate'}
local meta={get_string=function(_,k) return fields[k] or '' end,set_string=function(_,k,v) fields[k]=v end,get_int=function()return 0 end}
local function S(s,...) local args={...};return (s:gsub('@(%d)',function(i)return args[tonumber(i)] end)) end
core={get_meta=function()return meta end, get_item_group=function()return 0 end}
local function build_forge_formspec()return 'unchanged formspec','No fuel' end
local smelt_recipes={}
local localized_item_name
`;
for(const name of ['update_melter_interface','get_node_extra']){
const n=ast.body.find(n=>n.type==='FunctionDeclaration'&&n.identifier?.name===name);if(!n)throw Error(name);code+=source.slice(...n.range)+'\n';}
code+=`update_melter_interface({})
assert(fields.infotext=='','native duplicate survives')
assert(fields.formspec=='unchanged formspec')
assert(fields['everforge:machine_infotext']=='Everforge Alloy Melter — No fuel')
local own=get_node_extra('everforge:alloy_melter',{}, {},meta)
assert(own[1]=='Status: Everforge Alloy Melter — No fuel','WAILA lost machine state')
fields.infotext='Other furnace: Output full'
local other=get_node_extra('mcl_furnaces:furnace',{on_timer=function()end},{},meta)
assert(other[1]=='Status: Other furnace: Output full','other machine state changed')
print('PASS native duplicate removed; form and WAILA status preserved; other machines untouched')
-- Instrumentation must not mutate any inventory or call a translator.
local messages={}
core.log=function(_,s) messages[#messages+1]=s end
local function read_only()error('diagnostic attempted mutation')end
local bad=string.char(27)..'(Tadamantine)Old armor description'
local function inv(label)
 local stack={get_name=function()return 'adamantine:helmet_adamantine' end,get_meta=function()return {to_table=function()return {fields={description=bad,name='Custom name',enchantments='unchanged'}}end,set_string=read_only}end}
 return {get_lists=function()return {main={stack}}end,set_stack=read_only}
end
meta.to_table=function()return {fields=fields}end
meta.get_inventory=function()return inv('node')end
local player={get_meta=function()return meta end,get_inventory=function()return inv('player')end,hud_get_all=function()return {[1]={type='text',text='main WAILA'}}end}
core.get_player_by_name=function()return player end
core.registered_items={['adamantine:helmet_adamantine']={description='valid'}}
core.get_node=function()return {name='everforge:alloy_melter'}end
core.pos_to_string=function()return '(0,0,0)'end
mcl_util={get_pointed_thing=function()return {type='node',under={x=0,y=0,z=0}}end}
local command
core.register_chatcommand=function(name,def) assert(name=='everforge_ui_probe');assert(def.privs.server);command=def.func end
core.translate=function()error('diagnostic translated a string')end
`;
const probe=fs.readFileSync('mods/MISC/everforge/ui_probe.lua','utf8');
code+=`assert(load(${JSON.stringify(probe)},'@mods/MISC/everforge/ui_probe.lua'))()(function()return false,false end)
local ok,result=command('tester');assert(ok);assert(result:find('Malformed fields: 2',1,true))
assert(table.concat(messages,'\\n'):find('WAILA enabled="false"',1,true))
assert(table.concat(messages,'\\n'):find('Mineclonia mcl_info_show',1,true))
print('PASS probe detects saved malformed metadata with WAILA off, reports HUD provenance, does not translate or write inventory')
`;
const harness=path.join(fs.mkdtempSync(path.join(os.tmpdir(),'everforge-hud-')),'test.lua');fs.writeFileSync(harness,code);
const r=cp.spawnSync('fengari',[harness],{encoding:'utf8'});process.stdout.write(r.stdout);process.stderr.write(r.stderr);if(r.status!==0||r.stderr.includes('stack traceback'))process.exit(1);
