// Requires luaparse and fengari-node-cli on NODE_PATH / PATH. Run from game root.
// Optional argument: baseline commit. No Luanti engine or world is started.
const fs=require('fs'), cp=require('child_process'), os=require('os'), path=require('path');
const lua=require('luaparse');
const src=fs.readFileSync('mods/MISC/everforge/init.lua','utf8');
const ast=lua.parse(src,{ranges:true,luaVersion:'5.1',comments:false});
const functions=['forge_theme','forge_slots','build_forge_formspec','build_reward_cache_formspec','waila_line_count','layout_waila_text'];
let code=`local function S(t, ...) local a={...}; return (t:gsub('@(%d+)',function(i) return tostring(a[tonumber(i)]) end)) end
core={formspec_escape=function(s) return s end,colorize=function(c,s) return s end}
mcl_formspec={get_itemslot_bg_v4=function() return '' end}
mcl_experience={get_level=function() return 100 end}
everforge={classes={},skills={}}
for _,k in ipairs({'vanguard','ranger','arcanist','smith'}) do everforge.classes[k]={label=k} end
for _,k in ipairs({'trailblazer','deep_miner','dungeoneer','forgemaster'}) do everforge.skills[k]={label=k,max=3,description='description'} end
local meta={get_string=function() return 'smith' end,get_int=function(self,k) if k=='burn_total' then return 100 elseif k=='burn' then return 50 else return 1 end end}
local function get_meta() return meta end
local function get_points() return 20 end
local function skill_rank() return 2 end
local function forge_bonus_at() return 0 end
local smelt_recipes={ore={time=20,output='ingot'}}
local mode='empty'
local inv={get_stack=function() return {get_name=function() return mode=='empty' and '' or mode=='unsupported' and 'other' or 'ore' end,is_empty=function() return mode=='empty' end} end,room_for_item=function() return mode~='full' end}
meta.get_inventory=function() return inv end
core.get_meta=function() return meta end
core.get_craft_result=function() return {time=10} end
ItemStack=function(s) return s end
local WAILA_TEXTURE_SIZE=256
local WAILA_CHAR_WIDTH=8
local WAILA_LINE_HEIGHT=16
`;
for(const name of functions){const n=ast.body.find(n=>n.type==='FunctionDeclaration'&&n.identifier?.name===name);if(!n)throw Error(name);code+=src.slice(...n.range)+'\n';}
code+=`for _,m in ipairs({'empty','unsupported','working','full'}) do mode=m; local f=build_forge_formspec({}); print('FORGE_'..m..'|'..f) end
local _,scale=layout_waila_text('Name\\nType: mineral\\nTool: pickaxe'); assert(scale.x*256==math.ceil(math.max(220,math.ceil(13*8*1.25+32))/16)*16)
print('HUD|dimensions preserved')
`;
let cache; function find(v){if(!v||typeof v!=='object')return; if(v.type==='CallExpression'&&v.base?.identifier?.name==='set_string'&&v.arguments?.[0]?.raw==='"formspec"'&&v.arguments?.[1]?.type==='CallExpression')cache=v.arguments[1]; for(const x of Object.values(v))if(Array.isArray(x))x.forEach(find);else find(x);} find(ast); if(!cache)throw Error('cache missing'); code+=`local pos={x=0,y=0,z=0}; print('CACHE|'..${src.slice(...cache.range)})\n`;
const harness=path.join(os.tmpdir(),'everforge-harness.lua');
fs.writeFileSync(harness,code);
const out=cp.execFileSync('fengari',[harness],{encoding:'utf8'});
if(/stack traceback|error/i.test(out))throw Error(out);
let count=0;
for(const line of out.split('\n')){
 if(!line.includes('|')||line.startsWith('HUD|'))continue;
 const [name,...parts]=line.split('|'), spec=parts.join('|');
 const size=name==='CACHE'?[11.75,11.75]:[11.75,10.95];
 for(const m of spec.matchAll(/(box|button|button_exit|list)\[([^\]]+)\]/g)){
   const fields=m[2].split(';');let pos,dim;
   if(m[1]==='list'){pos=fields[2];dim=fields[3]}else{pos=fields[0];dim=fields[1]}
   let [x,y]=pos.split(',').map(Number),[w,h]=dim.split(',').map(Number);
   if(m[1]==='list'){w=w+(w-1)*.25;h=h+(h-1)*.25;}
   if(x<0||y<0||x+w>size[0]+.001||y+h>size[1]+.001) throw Error(name+': overflow '+m[0]);
   count++;
 }
}
fs.writeFileSync(path.join(os.tmpdir(),'everforge-generated-forms.txt'),out);
console.log('Lua 5.1 syntax passed; generated cache and four melter states; '+count+' bounds passed; HUD visible dimensions preserved.');
// Guard the explicitly out-of-scope gameplay tables against the PR baseline.
const before=cp.execFileSync('git',['show',(process.argv[2] || 'e442c9a69')+':mods/MISC/everforge/init.lua'],{encoding:'utf8'});
function mechanicsTables(text){
 const tree=lua.parse(Buffer.from(text).toString('latin1'),{luaVersion:'5.1',comments:false,encodingMode:'pseudo-latin1'});
 const result={};
 for(const n of tree.body){
  if(n.type==='LocalStatement') for(let i=0;i<n.variables.length;i++) if(['smelt_recipes','base_output_types'].includes(n.variables[i].name)) result[n.variables[i].name]=n.init[i];
 }
 return JSON.stringify(result);
}
if(mechanicsTables(src)!==mechanicsTables(before))throw Error('Smelting recipes or output-type tables changed from the PR baseline');
console.log('Smelting recipes and output-type tables match the PR baseline.');
