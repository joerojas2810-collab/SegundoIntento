-- SPDX-License-Identifier: GPL-3.0-or-later
-- Disposable world integration: real feature output and reload invariance.
return function(stage, store, check, passed, stop)
 local lg=mcl_levelgen
 local leaves=core.registered_nodes["mcl_trees:leaves_oak"]
 check(leaves.drawtype=="nodebox" and leaves.tiles[1]=="everforge_world_visuals_leaves_oak.png",
  "actual final oak visual override active")
 local ok,status=core.registered_chatcommands.everforge_visuals.func("")
 check(ok and status:find("ACTIVO",1,true),"read-only visual diagnostic confirms applied textures")
 local names={"everforge_world_visuals:forest_shrub", "everforge_world_visuals:field_stones"}
 local function scan(area)
  core.load_area(area.minp,area.maxp)
  local snapshot={}
  for _,name in ipairs(names) do
   local def=core.registered_nodes[name]
   check(def and not def.walkable and not def.pointable and not def.diggable
    and def.buildable_to and def.drop=="", "noninteractive visual node "..name)
   local nodes=core.find_nodes_in_area(area.minp,area.maxp,{name})
   local keys={}
   for _,pos in ipairs(nodes) do
    local ground=core.get_node(vector.offset(pos,0,-1,0)).name
    check(ground~="air" and core.get_item_group(ground,"leaves")==0
     and core.get_item_group(ground,"tree")==0, "scenery has ground support")
    keys[#keys+1]=core.pos_to_string(pos)
   end
   table.sort(keys); snapshot[name]=keys
   core.log("action", "EVERFORGE_VISUAL_COUNT: "..name.."="..#keys)
   check(#keys>0,"real generated "..name)
  end
  return snapshot
 end
 if stage=="legacy" then
  local c=core.parse_json(store:get_string("center"))
  check(c,"legacy fixture has a camp center")
  local minp,maxp=vector.offset(c,-24,-24,-24),vector.offset(c,24,32,24)
  core.load_area(minp,maxp)
  for _,name in ipairs(names) do
   check(#core.find_nodes_in_area(minp,maxp,{name})==0,"no retroactive decorations in old terrain")
  end
  passed("legacy world: no retroactive scenery; existing camp, construction and metadata preserved")
  stop(); return
 end
 if stage=="restart" then
  local area=core.deserialize(store:get_string("visual_area"),true)
  check(area,"visual test area saved")
  local actual=scan(area)
  local expected=core.deserialize(store:get_string("visual_snapshot"),true)
  check(type(expected)=="table","valid saved scenery snapshot")
  for name,positions in pairs(actual) do
   check(type(expected[name])=="table"
    and table.concat(positions,";")==table.concat(expected[name],";"),
    "no scenery added or removed on restart: "..name)
  end
  passed("visuals: scenery snapshot unchanged on reload")
  stop(); return
 end
 local dim=lg.get_dimension("mcl_levelgen:overworld")
 local x,y,z=lg.locate_biome_spirally(dim.preset,0,80,0,2048,32,64,
  lg.make_biome_test({"Forest","BirchForest","Meadow"}),nil)
 check(x,"selected biome located")
 -- Locator returns Minecraft coordinates; generate_area uses Luanti coordinates.
 z=-z-1
 y=y-dim.y_offset
 core.log("action", "EVERFORGE_VISUAL_AREA: "..core.pos_to_string({x=x,y=y,z=z}))
 local area={minp={x=x-64,y=dim.y_global,z=z-64},maxp={x=x+64,y=dim.y_max,z=z+64}}
 local done=false
 lg.generate_area(area.minp.x,area.minp.y,area.minp.z,area.maxp.x,area.maxp.y,area.maxp.z,function(progress)
  if not done and progress.n_regenerated==progress.total_regen and progress.n_emerged==progress.total_emerge
   and lg.is_area_fully_regenerated(dim,area.minp.x,area.minp.y,area.minp.z,area.maxp.x,area.maxp.y,area.maxp.z) then
   done=true
   core.after(0,function()
    store:set_string("visual_area",core.serialize(area))
    store:set_string("visual_snapshot",core.serialize(scan(area)))
    passed("visuals: shrubs and stones actually generated in selected biomes")
    stop()
   end)
  end
 end)
end
