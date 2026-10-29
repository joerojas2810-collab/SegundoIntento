-- SPDX-License-Identifier: GPL-3.0-or-later
return function(stage,store,check,passed,stop)
 local C=dofile(core.get_modpath("everforge").."/camp.lua")
 local r=everforge.start_region.get()
 local c=r.center
 local a=everforge.start_region.find_arrival()
 check(a and math.abs(a.x-c.x)<=10 and math.abs(a.z-c.z)<=10,"arrival near camp")
 local feet=core.registered_nodes[core.get_node(vector.round(a)).name]
 check(feet and not feet.walkable and feet.liquidtype=="none","arrival feet clear and dry")
 local final={}
 for _,op in ipairs(C.plan(c)) do final[core.pos_to_string(op.pos)]=op end
 local lines={}
 for k,op in pairs(final) do
  local node=core.get_node(op.pos)
  check(node.name==op.name,"camp component at "..k)
  lines[#lines+1]=k.."="..node.name..":"..node.param2
  if op.component=="foundation" or op.component=="floor" or op.component=="path"
   or op.component=="hearth" or op.component=="bench_support" or op.component=="lamp_support" then
   local supported=false
   for dy=1,4 do
    local below=core.get_node(vector.offset(op.pos,0,-dy,0)).name
    if below~="mcl_core:stonebrick" then
     local def=core.registered_nodes[below]
     supported=def and def.walkable and core.get_item_group(below,"tree")==0
      and core.get_item_group(below,"leaves")==0 and def.liquidtype=="none"
     break
    end
   end
   check(supported,"bounded natural camp support at "..k)
  end
 end
 table.sort(lines)
 local digest=core.sha1(table.concat(lines,"\n"))
 local center=core.pos_to_string(c)
 local marker=vector.offset(c,5,12,5)
 if stage=="seedtest" then
  store:set_string("seed_center",center);store:set_string("seed_digest",digest)
  core.set_node(marker,{name="mcl_core:goldblock"})
  core.get_meta(marker):set_string("seedtest","preserve")
 else
  check(store:get_string("seed_center")==center and store:get_string("seed_digest")==digest,"camp stable on reload")
  check(core.get_node(marker).name=="mcl_core:goldblock"
   and core.get_meta(marker):get_string("seedtest")=="preserve","saved construction and metadata preserved")
 end
 local decos=core.find_nodes_in_area(vector.offset(c,-20,-8,-20),vector.offset(c,20,20,20),{
  "everforge_world_visuals:forest_shrub","everforge_world_visuals:field_stones",
  "everforge_world_visuals:foothill_stones","everforge_world_visuals:mountain_stones"})
 local terrain={biomes={},water_samples=0,min_y=math.huge,max_y=-math.huge,mountain_samples={}}
 local dim=mcl_levelgen.get_dimension("mcl_levelgen:overworld")
 local origin=r.fallback_origin or r.origin or c
 local radius=r.search_radius or 12
 for dx=-radius,radius,8 do for dz=-radius,radius,8 do
  local x,z=origin.x+dx,origin.z+dz
  local h=mcl_levelgen.map_index_heightmap(dim,x,z,false)
  if h then
   local y=h+dim.y_global-2
   local pos={x=x,y=y,z=z}
   local biome=mcl_biome_dispatch.get_biome_name(pos)
   terrain.biomes[biome]=(terrain.biomes[biome] or 0)+1
   terrain.min_y=math.min(terrain.min_y,y);terrain.max_y=math.max(terrain.max_y,y)
   local node=core.get_node(pos).name
   if core.get_item_group(node,"water")>0 or node:find("water",1,true) then terrain.water_samples=terrain.water_samples+1 end
   if (biome:find("Peaks",1,true) or biome:find("Windswept",1,true)) and #terrain.mountain_samples<4 then
    terrain.mountain_samples[#terrain.mountain_samples+1]=pos
   end
  end
 end end
 -- Original generation heightmaps are immutable under gameplay, unlike live
 -- fluids/leaves. Compare them rather than elapsed-time-dependent simulations.
 local generated={}
 for dx=-12,12,2 do for dz=-12,12,2 do
  local x,z=origin.x+dx,origin.z+dz
  local h,m=mcl_levelgen.map_index_heightmap(dim,x,z,true)
  check(h~=nil,"saved original heightmap available")
  local biome=mcl_biome_dispatch.get_biome_name_nosample({x=x,y=h+dim.y_global-2,z=z})
  generated[#generated+1]=x..":"..z..":"..h..":"..m..":"..biome
 end end
 local terrain_digest=core.sha1(table.concat(generated,"\n"))
 local previous=store:get_string("seed_terrain_digest")
 if stage=="seedtest" then store:set_string("seed_terrain_digest",terrain_digest)
 elseif previous~="" then check(previous==terrain_digest,"original generated terrain unchanged on reload") end
 local decoration_counts={}
 for _,name in ipairs({"forest_shrub","field_stones","foothill_stones","mountain_stones"}) do
  decoration_counts[name]=#core.find_nodes_in_area(vector.offset(c,-20,-8,-20),vector.offset(c,20,20,20),{"everforge_world_visuals:"..name})
 end
 local result={terrain_digest=terrain_digest,origin=r.origin,fallback_origin=r.fallback_origin,decoration_counts=decoration_counts,terrain=terrain,seed=core.get_mapgen_setting("seed"),center=c,arrival=a,digest=digest,
  biome=mcl_biome_dispatch.get_biome_name(c),decorations=#decos,stage=stage,site=r.site}
 core.log("action","EVERFORGE_SEED_RESULT "..core.write_json(result))
 passed("seed: full camp, bounded supports, safe arrival, saved world unchanged")
 stop()
end
