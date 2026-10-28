// Executes the actual Adamantine registration and Mineclonia register_set with the official 5.17 translator.
// Requires luaparse and fengari-node-cli. BASELINE_REF=28a73c847 tests the old call site.
const fs=require('fs'),cp=require('child_process'),lua=require('luaparse');
const parse=s=>lua.parse(s,{ranges:true,luaVersion:'5.1'});
const armorPath='mods/ITEMS/mcl_armor/api.lua', itemPath='mods/ITEMS/adamantine/init.lua';
const baseline=process.env.BASELINE_REF;
const armor=fs.readFileSync(armorPath,'utf8'), item=baseline ? cp.execFileSync('git',['show',baseline+':'+itemPath],{encoding:'utf8'}) : fs.readFileSync(itemPath,'utf8');
if(!process.argv[2])throw Error('Pass the official Luanti 5.17.0 builtin/common/misc_helpers.lua path');
const engine=fs.readFileSync(process.argv[2],'utf8');
const crypto=require('crypto');
if(crypto.createHash('sha256').update(engine).digest('hex')!=='d83916589500178cce8ccf1f1012861d421b9f94f0b675ecbc2f3460af9019e3')throw Error('Unexpected Luanti translator source checksum');
let code=`core={}; minetest=core; local ESCAPE_CHAR=string.char(27)\n`;
for(const n of parse(engine).body)if(n.type==='FunctionDeclaration'&&['translate','core.translate','core.translate_n','core.get_translator'].includes(n.identifier?.name|| (n.identifier?.base?.name+'.'+n.identifier?.identifier?.name)))code+=engine.slice(...n.range)+'\n';
code+=`local original_translate=core.translate
local bad_templates=0
core.translate=function(domain,template,...)
 if template:find(string.char(27),1,true) then
  bad_templates=bad_templates+1
  print('OFFENDING_TEMPLATE '..string.format('%q',template))
  print(debug.traceback('REAL CALL STACK',2))
 end
 return original_translate(domain,template,...)
end
core.get_current_modname=function() return 'adamantine' end
core.log=function(level,msg) print(level..': '..msg) end
local tools={};local crafts={}
core.register_tool=function(name,def) tools[name]=def end
core.register_craft=function(def) crafts[#crafts+1]=def end
table.copy=function(t) local c={}; for k,v in pairs(t) do c[k]=v end;return c end
mcl_armor={trims={core_textures={}}}
local S=core.get_translator('adamantine')
local ENCHANTABILITY=10
local TEX={}
`;
// Pull elements and both functions from the real checked-out Mineclonia sources.
const init=fs.readFileSync('mods/ITEMS/mcl_armor/init.lua','utf8');
const ass=parse(init).body.find(n=>n.type==='AssignmentStatement'&&n.variables?.[0]?.name==='mcl_armor');
const elements=ass.init[0].fields.find(f=>f.key?.name==='elements').value;
code+='mcl_armor.elements='+init.slice(...elements.range)+'\n';
// get_armor_texture is local to its chunk: load both functions together instead.
const needed=parse(armor).body.filter(n=>n.type==='FunctionDeclaration'&&(n.identifier?.name==='get_armor_texture'||n.identifier?.identifier?.name==='register_set'));
const start=needed[0].range[0],end=needed[1].range[1];
code+=`assert(load(${JSON.stringify('\n'.repeat(armor.slice(0,start).split('\n').length-1)+armor.slice(start,end))},'@${armorPath}'))()\n`;
let reg;function walk(v){if(!v||typeof v!=='object')return;if(v.type==='CallExpression'&&v.base?.base?.name==='mcl_armor'&&v.base?.identifier?.name==='register_set')reg=v;for(const x of Object.values(v))if(Array.isArray(x))x.forEach(walk);else walk(x)}walk(parse(item));
// S and texture constants are upvalues at the actual registration site.
const expr=item.slice(...reg.range);
code+=`local register_site=assert(load(${JSON.stringify('\n'.repeat(item.slice(0,reg.range[0]).split('\n').length-1)+'local S=core.get_translator("adamantine"); local ENCHANTABILITY=10; local TEX={}; '+expr)},'@${itemPath}'))\nregister_site()\n`;
code+=`local count=0;for name,def in pairs(tools) do count=count+1;print('REGISTERED '..name..' '..string.format('%q',def.description)) end
local function serialize(v)
 if type(v)=='table' then local keys={};for k in pairs(v) do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end);local t={};for _,k in ipairs(keys) do if k~='description' then t[#t+1]=tostring(k)..'='..serialize(v[k]) end end;return '{'..table.concat(t,',')..'}' end
 if type(v)=='function' then return '<callback>' end
 return tostring(v)
end
print('MECHANICS '..serialize(tools)..serialize(crafts))
print('RESULT bad_templates='..bad_templates..' armor_pieces='..count..' crafts='..#crafts)
assert(count==4)
if os.getenv('BASELINE_REF')==nil then assert(bad_templates==0,'invalid template in real register_set route') else assert(bad_templates==4,'expected four calls on uncorrected baseline') end
`;
const path=require('path'),os=require('os');
const harness=path.join(fs.mkdtempSync(path.join(os.tmpdir(),'everforge-armor-')),'trace.lua');
fs.writeFileSync(harness,code);
const r=cp.spawnSync('fengari',[harness],{encoding:'utf8'});process.stdout.write(r.stdout);process.stderr.write(r.stderr);if(r.status!==0||r.stderr.includes('stack traceback'))process.exit(1);
