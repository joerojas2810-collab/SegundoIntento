// Execute production registrations and filters against real biome stage tables.
const fs=require('fs'), cp=require('child_process'), path=require('path'), os=require('os');
const parse=require('luaparse').parse;
const dir='mods/MISC/everforge_world_visuals/';
const biomes=fs.readFileSync('mods/MAPGEN/mcl_levelgen/biomes.lua','utf8');
const definitions=biomes.slice(biomes.indexOf('local registered_biomes = {}'),biomes.indexOf('-- Biome groups.'));
const init=fs.readFileSync(dir+'init.lua','utf8'),script=fs.readFileSync(dir+'lg_register.lua','utf8');
for(const s of [init,script,definitions]) parse(s,{luaVersion:'5.1'});
const features=fs.readFileSync('mods/MAPGEN/mcl_levelgen/features.lua','utf8');
const generate=features.slice(features.indexOf('function mcl_levelgen.generate_feature ('), features.indexOf('local for_each_dimension',features.indexOf('function mcl_levelgen.generate_feature (')));
let lua=`local function copy(t) if type(t)~='table' then return t end local r={} for k,v in pairs(t) do r[k]=copy(v) end return r end
table.copy=copy
table.indexof=function(t,v) for i,x in ipairs(t) do if x==v then return i end end return -1 end
local checks=0
local function check(v) assert(v); checks=checks+1 end
local ids={} local nextid=0
local function cid(n) if not ids[n] then nextid=nextid+1; ids[n]=nextid end return ids[n] end
local nodes={} local callbacks={} local commands={}
core={get_content_id=cid,registered_nodes=nodes,register_chatcommand=function(n,d) commands[n]=d end,after=function() end,get_current_modname=function() return 'everforge_world_visuals' end,
get_modpath=function() return '${dir.slice(0,-1)}' end,get_translator=function() return function(s) return s end end,
register_node=function(n,d) nodes[n]=d end,override_item=function(n,d) for k,v in pairs(d) do nodes[n][k]=v end end,
register_on_mods_loaded=function(f) callbacks[#callbacks+1]=f end}
mcl_vars={enable_mcl_levelgen=true}
local registered_placed_features={} local configured={} local features_generated={}
mcl_levelgen={register_levelgen_script=function(p) check(p=='${dir}lg_register.lua') end,
register_configured_feature=function(n,d) configured[n]=d end,
register_placed_feature=function(n,d) registered_placed_features[n]=d end}
for _,n in ipairs({'build_rarity_filter','build_count','build_in_square','build_heightmap','build_in_biome'}) do
 mcl_levelgen[n]=function(v) return {kind=n,value=v} end
end
`+definitions+'\n'+generate+`\n`+init+`\n`+script+`\n
local shrub='everforge_world_visuals:forest_shrub_placed'
local field='everforge_world_visuals:field_stones_placed'
local mountain='everforge_world_visuals:mountain_stones_placed'
local counts={[shrub]=0,[field]=0,[mountain]=0}
for name,b in pairs(mcl_levelgen.registered_biomes) do
 for _,id in ipairs(b.features[11] or {}) do if counts[id] then counts[id]=counts[id]+1 end end
end
check(counts[shrub]==11 and counts[field]==10 and counts[mountain]==5)
for _,name in ipairs({'Forest','BirchForest','Taiga','Meadow'}) do
 local list=mcl_levelgen.registered_biomes[name].features[11]
 check(table.indexof(list,shrub)>0 and table.indexof(list,field)>0)
 check(table.indexof(list,field)<table.indexof(list,'mcl_levelgen:freeze_top_layer'))
end
for _,name in ipairs({'Ocean','Desert','TheEnd'}) do
 check(table.indexof(mcl_levelgen.registered_biomes[name].features[11] or {},shrub)==-1)
end
for id,p in pairs(registered_placed_features) do
 local filter=p.placement_modifiers[5]
 local ground=cid('mcl_core:dirt_with_grass')
 local obstacle=nil
 mcl_levelgen.get_block=function(x,y,z) if y==9 then return ground end return obstacle or cid('air') end
 check(filter(0,10,0)~=nil)
 for _,n in ipairs({'mcl_trees:leaves_oak','mcl_trees:tree_oak','mcl_core:stonebrick','mcl_core:snow','mcl_core:water_source','ignore'}) do
  ground=cid(n); check(filter(0,10,0)==nil)
 end
 ground=cid('mcl_core:dirt_with_grass')
 for _,n in ipairs({'mcl_trees:tree_oak','mcl_flowers:tallgrass','mcl_core:water_source','mcl_core:stonebrick'}) do
  obstacle=cid(n); check(filter(0,10,0)==nil)
 end
 obstacle=nil
 for x=-1,1 do for z=-1,1 do for y=10,11 do
  mcl_levelgen.get_block=function(a,b,c) if a==x and b==y and c==z then return cid('mcl_core:stonebrick') end return b==9 and ground or cid('air') end
  check(filter(0,10,0)==nil)
 end end end
 local cfg=configured[p.configured_feature]
 for _,roll in ipairs({0,1}) do
  local c=cfg.content(0,10,0,{next_within=function(_,n) return roll % n end})
  check(c~=nil)
 end
end
for _,n in ipairs({'forest_shrub','field_stones','foothill_stones','mountain_stones'}) do
 local d=nodes['everforge_world_visuals:'..n]
 check(not d.walkable and not d.pointable and not d.diggable and d.buildable_to and d.floodable and d.drop=='')
end
-- Overrides must preserve all nonvisual properties, including orphan leaves.
local original={groups={leaves=1},walkable=true,drop='original',paramtype2='color',palette='original',waving=1,
 on_timer=function() end,tiles={'old'},collision_box={type='regular'},selection_box={type='regular'}}
nodes['mcl_trees:leaves_oak']=copy(original)
nodes['mcl_trees:leaves_oak_orphan']=copy(original)
for _,f in ipairs(callbacks) do f() end
for _,n in ipairs({'mcl_trees:leaves_oak','mcl_trees:leaves_oak_orphan'}) do
 for _,key in ipairs({'walkable','drop','paramtype2','palette','waving','on_timer'}) do check(nodes[n][key]==original[key]) end
 check(nodes[n].groups.leaves==1 and nodes[n].collision_box.fixed[1]==-.5 and nodes[n].selection_box.fixed[6]==.5)
end
check(commands.everforge_visuals~=nil)
print('PASS '..checks..' world visual behavior checks using actual biome definitions and generate_feature')
`;
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'everforge-visuals-'));
try {const file=path.join(tmp,'test.lua'); fs.writeFileSync(file,lua); const output=cp.execFileSync('fengari',[file],{encoding:'utf8'});if(!/^PASS /m.test(output))throw new Error('Lua tests did not complete');process.stdout.write(output);} finally {fs.rmSync(tmp,{recursive:true,force:true});}
