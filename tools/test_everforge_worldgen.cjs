// Execute the production site selector, camp preflight and spawn provider.
const fs=require('fs'),cp=require('child_process'),os=require('os'),path=require('path');
const parse=require('luaparse').parse;
const files=['camp_site','camp','start_region','worldgen_compat'];
const sources=Object.fromEntries(files.map(f=>[f,fs.readFileSync('mods/MISC/everforge/'+f+'.lua','utf8')]));
for(const s of Object.values(sources))parse(s,{luaVersion:'5.1'});
const biomes=fs.readFileSync('mods/MAPGEN/mcl_levelgen/biomes.lua','utf8');
const treeWalk=biomes.slice(biomes.indexOf('local function rtree_index_1'),biomes.indexOf('local function rtree_index_closest'));
parse(treeWalk,{luaVersion:'5.1'});
const dripstone=fs.readFileSync('mods/ITEMS/mcl_dripstone/lg_register.lua','utf8');
parse(dripstone,{luaVersion:'5.1'});
const dripstoneLoop=dripstone.slice(dripstone.indexOf('local function generate_large_dripstone'),dripstone.indexOf('local function large_dripstone_place'));
const quote=s=>'[====['+s+']====]';
let lua=`local sources={}\n`+files.map(f=>`sources['${f}']=${quote(sources[f])}`).join('\n')+`\n
unpack=unpack or table.unpack
local checks=0
local function check(v,message) assert(v,message);checks=checks+1 end
local function copy(t) if type(t)~='table' then return t end local n={} for k,v in pairs(t) do n[k]=copy(v) end return n end
vector={round=function(p) return {x=math.floor(p.x+.5),y=math.floor(p.y+.5),z=math.floor(p.z+.5)} end,offset=function(p,x,y,z) return {x=p.x+x,y=p.y+y,z=p.z+z} end,copy=copy,new=function(x,y,z) return {x=x,y=y,z=z} end}
local nodes={}
local function node(n,walk,groups,liquid,damage)
 nodes[n]={walkable=walk,groups=groups or {},liquidtype=liquid or 'none',damage_per_second=damage or 0}
end
node('air',false);node('ignore',false)
node('mcl_core:dirt_with_grass',true);node('mcl_core:stone',true);node('mcl_core:stonebrick',true)
node('mcl_core:water_source',false,{},'source');node('mcl_core:lava_source',false,{},'source',4)
node('mcl_trees:tree_oak',true,{tree=1});node('mcl_trees:leaves_oak',true,{leaves=1})
node('mcl_flowers:tallgrass',false,{plant=1});node('everforge_world_visuals:field_stones',false)
local heights=function() return 0 end
local overrides={} local protected,metadata,structure=false,false,false
local function key(p) return p.x..':'..p.y..':'..p.z end
local writes=0
local generation=0
local meta={to_table=function() return {fields={},inventory={}} end}
local world_exists=false
io={open=function() if world_exists then return {close=function() end} end end}
local stored,region,scheduled,provider='',nil,{},nil
local save_count=0 local last_json local loaded={} local now=0
core={registered_nodes=nodes,get_modpath=function() return '/everforge' end,
 get_node=function(p) return {name=overrides[key(p)] or (p.y<=heights(p.x,p.z) and 'mcl_core:dirt_with_grass' or 'air')} end,
 get_item_group=function(n,g) return nodes[n] and nodes[n].groups[g] or 0 end,
 is_protected=function() return protected end,find_nodes_with_meta=function() return metadata and {{x=0,y=0,z=0}} or {} end,
 set_node=function(p,n) writes=writes+1;overrides[key(p)]=n.name end,
 get_meta=function() return meta end,hash_node_position=key,
 pos_to_string=key,get_us_time=function() return now*1000000 end,get_worldpath=function() return '/world' end,
 get_mod_storage=function() return {get_string=function() return stored end,set_string=function() save_count=save_count+1 end} end,
 parse_json=function(s) return s=='json' and copy(last_json) or region end,write_json=function(t) last_json=copy(t);return 'json' end,
 settings={get_bool=function() return true end},log=function() end,get_mapgen_setting=function() return '8675309' end,
 load_area=function() end,after=function(delay,f) scheduled[#scheduled+1]=f end,
 register_on_mods_loaded=function(f) loaded[#loaded+1]=f end,register_on_joinplayer=function() end,
 register_on_leaveplayer=function() end,register_on_prejoinplayer=function() end,register_on_newplayer=function() end,kick_player=function() end}
mcl_levelgen={get_structures_at=function() return structure and {test={}} or {} end,
 is_generated=function() return true end,levelgen_enabled=true,generate_area=function() generation=generation+1 end,
 get_dimension=function() return {y_global=-128,y_max=255} end}
mcl_biome_dispatch={register_world_spawn_provider=function(f) provider=f end}
everforge={}
dofile=function(p) local f=p:match('/([^/]+)%.lua$');return assert(load(sources[f],f))() end
local S=dofile('/everforge/camp_site.lua')
local C=dofile('/everforge/camp.lua')
local function reset() heights=function() return 0 end;overrides={};protected=false;metadata=false;structure=false;writes=0 end
local function column(x,z) return S.column(x,z,0,-128,255) end
local p=S.choose(0,0,column);check(p and p.y==1,'flat site')
for _,name in ipairs({'mcl_core:sandstone','mcl_core:redsandstone','mcl_core:dirt_with_grass_snow',
 'mcl_colorblocks:hardened_clay','mcl_colorblocks:hardened_clay_red','mcl_amethyst:calcite',
 'mcl_copper:stone_with_copper'}) do
 node(name,true);check(S.natural(name),'natural surface coverage: '..name)
end
check(#S.candidates({x=0,z=0},60,4)==961,'bounded candidate count')
for _=1,3 do local a=S.candidates({x=7,z=-9},12,4);check(a[1].x==7 and a[2].x==3 and a[#a].z==3,'fixed search order') end
for x=-5,6 do for z=-5,10 do
 reset();overrides[key({x=x,y=1,z=z})]='mcl_core:water_source'
 check(not S.choose(0,0,column),'water anywhere in footprint rejected')
end end
reset();heights=function(x) return x>0 and 3 or 0 end
check(S.choose(0,0,column).y==4,'gentle slope uses highest ground')
heights=function(x) return x>0 and 4 or 0 end
check(not S.choose(0,0,column),'steep mountainside rejected')
reset();heights=function(x,z) return x==5 and z==10 and -9 or 0 end
check(not S.choose(0,0,column),'ravine at clearing edge rejected')
reset();for y=-1,-4,-1 do overrides['0:'..y..':0']='air' end
check(not S.choose(0,0,column),'thin soil roof above cave is not foundation support')
local cave_ok=pcall(C.place,{x=0,y=1,z=0});check(not cave_ok and writes==0,'cave preflight fails before any placement')
reset();for y=1,9 do overrides['0:'..y..':0']='mcl_trees:tree_oak' end
overrides['0:10:0']='mcl_trees:leaves_oak'
check(S.choose(0,0,column).y==1,'dense canopy is not ground')
reset();overrides['0:1:0']='everforge_world_visuals:field_stones'
check(S.choose(0,0,column).y==1,'noninteractive decoration can be cleared')
reset();overrides['0:1:0']='mcl_core:stonebrick'
check(not S.choose(0,0,column),'constructed roof rejected')
reset();structure=true;check(not S.choose(0,0,column),'native structure extent rejected')
reset();protected=true;check(not S.choose(0,0,column),'protection rejected')
reset();metadata=true;check(not S.choose(0,0,column),'node metadata preserved')
local ok=pcall(C.place,{x=0,y=1,z=0});check(not ok and writes==0,'invalid preflight writes nothing')
reset();for _,op in ipairs(C.plan({x=0,y=1,z=0})) do if not nodes[op.name] then node(op.name,true) end end
local counts=C.place({x=0,y=1,z=0});check(counts.roof==63 and counts.post==12,'valid camp complete')
reset()
-- A saved ready manifest must not generate, build, save or migrate terrain.
stored='saved';region={state='ready',center={x=0,y=1,z=0},radius=10,arrival={x=0,y=1,z=7}}
dofile('/everforge/start_region.lua')
check(writes==0 and generation==0 and save_count==0,'existing world untouched on load')
local arrival=everforge.start_region.find_arrival();check(arrival.x==0 and arrival.z==7 and arrival.y==.5,'preferred arrival connected to interior')
-- A nearby high roof must not become a fallback arrival.
overrides['0:1:7']='mcl_core:stonebrick';overrides['0:9:7']='mcl_core:stonebrick'
arrival=everforge.start_region.find_arrival();check(arrival and arrival.y<=1.5,'blocked courtyard fallback cannot jump to distant roof')
protected=true;check(everforge.start_region.find_arrival()==nil,'no protected spawn')
reset();local old_provider=provider;stored='';region=nil;world_exists=true
dofile('/everforge/start_region.lua')
check(provider==old_provider and writes==0 and generation==0 and save_count==0,'legacy world with no region stays untouched')
-- Unknown saved records must also remain untouched.
stored='invalid';region={state='ready',center={x='bad',z=0}};world_exists=false
dofile('/everforge/start_region.lua')
check(writes==0 and generation==0 and save_count==0,'malformed saved manifest not overwritten')
-- Completely unsuitable terrain must stop after three stages / 961 candidates.
local function initialize_new(stall)
 reset();stored='';region=nil;world_exists=false;scheduled={};loaded={};now=0;save_count=0;generation=0
 core.after=function(delay,f) scheduled[#scheduled+1]={time=now+delay,f=f} end
 mcl_biome_dispatch.get_spawn_point_2d=function() return {x=0,y=0,z=0} end
 mcl_levelgen.map_index_heightmap=function() return nil end
 mcl_levelgen.is_area_fully_regenerated=function() return true end
 mcl_levelgen.generate_area=function(_,_,_,_,_,_,cb)
  generation=generation+1
  if not stall then cb({n_regenerated=1,total_regen=1,n_emerged=1,total_emerge=1}) end
 end
 dofile('/everforge/start_region.lua')
 for _,f in ipairs(loaded) do f() end
end
local function drain()
 local ticks=0
 while #scheduled>0 do
  table.sort(scheduled,function(a,b) return a.time<b.time end)
  local next_task=table.remove(scheduled,1);now=next_task.time;next_task.f()
  ticks=ticks+1;check(ticks<1500,'bounded scheduling')
 end
 return ticks
end
initialize_new(false);drain()
local failed=everforge.start_region.get()
check(failed.state=='needs_review' and failed.failure.attempts==961 and generation==4,'bounded exhausted search')
check(writes==0,'failed search never alters terrain')
initialize_new(true)
local prepares=0 local ready_callback
mcl_biome_dispatch.emerged_teleport_prepare=function(_,_,_,_,cb)
 prepares=prepares+1;ready_callback=cb;return {x=31007,y=31007,z=31007}
end
local player={get_player_name=function() return 'WaitingPlayer' end,
 get_meta=function() return {set_int=function() end} end,is_valid=function() return true end,set_pos=function() end}
provider(player);provider(player);check(prepares==1,'one emergence request while waiting')
ready_callback(player)
local ticks=drain()
check(everforge.start_region.get().state=='needs_review' and generation==1 and writes==0,'stalled generation times out without retry or placement')
check(now==180 and ticks<750,'arrival wait bounded by generation deadline')
-- Open ocean anchor relocates once to the SAME seed's native land anchor.
initialize_new(false)
mcl_levelgen.get_dimension=function() return {y_global=-128,y_max=255,preset={find_spawn_position=function() return 100,-1 end}} end
mcl_levelgen.map_index_heightmap=function() return 130 end
local saved_get_node=core.get_node
core.get_node=function(p)
 if p.x<80 and p.y==1 then return {name='mcl_core:water_source'} end
 return saved_get_node(p)
end
drain()
local relocated=everforge.start_region.get()
check(relocated.state=='ready' and relocated.center.x==100 and relocated.fallback_origin.x==100
 and relocated.seed=='8675309','same-seed dry land fallback')
check(relocated.site.attempts==50 and generation==3,'one bounded relocation after 49 water candidates')
core.get_node=saved_get_node
-- Completion may precede native context unlock; do not reject a transient lock.
initialize_new(false)
mcl_levelgen.map_index_heightmap=function() return 130 end
local lock_checks=0
mcl_levelgen.is_generated=function()
 lock_checks=lock_checks+1
 if lock_checks<=4 then check(writes==0,'no writes while native context locked');return false end
 return true
end
drain()
check(everforge.start_region.get().state=='ready' and everforge.start_region.get().site.attempts==1,'locked native completion keeps the first deterministic site')
initialize_new(false)
mcl_levelgen.is_generated=function() return false end
drain()
check(everforge.start_region.get().state=='needs_review' and writes==0,'native unlock wait respects existing deadline')
mcl_levelgen.is_generated=function() return true end
-- Missing resident blocks are resolved before moving to another candidate.
local normal_get_node=core.get_node
initialize_new(false)
mcl_levelgen.map_index_heightmap=function() return 130 end
local resident=false local emerges=0
core.get_node=function(p) if not resident then return {name='ignore'} end return normal_get_node(p) end
core.emerge_area=function(_,_,cb) emerges=emerges+1;resident=true;cb(nil,1,0) end
drain()
check(everforge.start_region.get().state=='ready' and emerges==1,'same unloaded candidate resolved once')
core.get_node=normal_get_node
initialize_new(false)
mcl_levelgen.map_index_heightmap=function() return 130 end
emerges=0
core.get_node=function() return {name='ignore'} end
core.emerge_area=function(_,_,cb) emerges=emerges+1;cb(nil,1,0) end
drain()
check(everforge.start_region.get().state=='needs_review' and emerges==2 and writes==0,'unavailable blocks fail after exactly two emergence attempts')
core.get_node=normal_get_node
local native=function() return 17 end
mcl_levelgen.generate_stronghold_positions=native
local current_hook,hook_mask,hook_count=nil,'',0
local gethook,sethook=debug.gethook,debug.sethook
debug.gethook=function() return current_hook,hook_mask,hook_count end
debug.sethook=function(h,m,c) current_hook=h;hook_mask=m;hook_count=c end
local prepare=function(a,b)
 check(current_hook~=nil,'startup execution hook active')
 if a=='throw' then error('native failure') end
 if a=='timeout' then now=now+91;current_hook() end
 return a,b
end
mcl_levelgen.prime_concentric_placement=prepare
core.global_exists=function(n) return n=='jit' end
core.get_version=function() return {string='5.17.0'} end
jit={os='Linux',arch='arm64'}
dofile('/everforge/worldgen_compat.lua');check(mcl_levelgen.prime_concentric_placement==prepare,'other platforms unchanged')
jit.os='OSX';dofile('/everforge/worldgen_compat.lua')
local a,b=mcl_levelgen.prime_concentric_placement(19,23)
check(a==19 and b==23 and current_hook==nil,'native return values and hook restored')
local ok=pcall(mcl_levelgen.prime_concentric_placement,'throw')
check(not ok and current_hook==nil,'native error restores hook')
ok=pcall(mcl_levelgen.prime_concentric_placement,'timeout')
check(not ok and current_hook==nil,'startup watchdog restores hook on timeout')
local previous=function() end
current_hook=previous;hook_mask='l';hook_count=1000
mcl_levelgen.prime_concentric_placement(0,0)
check(current_hook==previous and hook_mask=='l' and hook_count==1000,'existing debugger untouched')
check(mcl_levelgen.generate_stronghold_positions==native and native()==17,'same native algorithm')
local wrapped=mcl_levelgen.prime_concentric_placement
core.get_version=function() return {string='5.18.0'} end
dofile('/everforge/worldgen_compat.lua');check(mcl_levelgen.prime_concentric_placement==wrapped,'workaround limited to affected engine')
debug.gethook=gethook;debug.sethook=sethook
-- Execute the production dripstone loop with deterministic geometry and RNG.
local disabled,placed={},{}
jit.off=function(fn) disabled[#disabled+1]=fn end
local mathsqrt,mathmin,floor,huge=math.sqrt,math.min,math.floor,math.huge
local index_heightmap=function() return 20 end
local dripstone_height=function() return 3 end
local air_water_or_lava_p=function(x,y,z) check(type(y)=='number','numeric native dripstone coordinate');return true end
local set_block=function(x,y,z) placed[#placed+1]={x,y,z} end
local dripstone_replaceable_p=function() return true end
local cid_dripstone_block=1
${dripstoneLoop}
check(#disabled==1 and disabled[1]==generate_large_dripstone,'ARM workaround targets actual native function')
local rng={next_float=function() return .5 end}
for _,dir in ipairs({-1,1}) do
 generate_large_dripstone({radius=1,scale=1,bluntness=1,dir=dir,origin_y=10,origin_x=0,origin_z=0,is_stalagmite=dir==1},rng,nil)
end
check(#placed==30,'both native dripstone directions retained')
-- Native recursive biome walk is interpreted only in the affected coordinator.
core.get_version=function() return {string='5.17.0'} end
local distance_total=function(extents,coords) return extents.distance end
local before=#disabled
mcl_levelgen.load_feature_environment=false
${treeWalk}
check(#disabled==before+1 and disabled[#disabled]==rtree_index_1,'target coordinator tree function only')
local first={value='Forest',extents={distance=2}}
local tie={value='Taiga',extents={distance=2}}
local closer={value='Meadow',extents={distance=1}}
local t={children={first,{extents={distance=0},children={tie,closer}}}}
local leaf,distance=rtree_index_1({},nil,math.huge,t)
check(leaf==closer and distance==1,'native traversal and nearest biome retained')
t.children[2].children[2]=nil
leaf,distance=rtree_index_1({},nil,math.huge,t)
check(leaf==first and distance==2,'native tie order retained')
before=#disabled;mcl_levelgen.load_feature_environment=true
${treeWalk}
check(#disabled==before,'feature workers keep their JIT configuration')
print('PASS '..checks..' camp site / spawn / existing-world / native-compat checks')
`;
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'everforge-worldgen-'));
try{const f=path.join(dir,'test.lua');fs.writeFileSync(f,lua);const output=cp.execFileSync('fengari',[f],{encoding:'utf8'});if(!/^PASS /m.test(output))throw new Error('Lua tests did not complete');process.stdout.write(output);}finally{fs.rmSync(dir,{recursive:true,force:true});}
