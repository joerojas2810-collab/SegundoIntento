-- SPDX-License-Identifier: GPL-3.0-or-later
-- Only used during the first creation of a world, never on load/join/respawn.
local C = {revision = 2}
local LOG = "mcl_trees:tree_oak"
local WOOD = "mcl_trees:wood_oak"
local STONE = "mcl_core:cobble"
local BRICK = "mcl_core:stonebrick"
function C.plan(center)
 local plan = {}
 local function add(x,y,z,name,component,param2)
  plan[#plan+1] = {pos=vector.offset(center,x,y,z),name=name,param2=param2 or 0,component=component}
 end
 -- Compact, supported floor. The surrounding landscape is not flattened.
 for x=-4,4 do for z=-4,2 do
  add(x,-1,z,STONE,"foundation")
  for y=0,7 do add(x,y,z,"air","clearance") end
 end end
 for x=-3,3 do for z=-3,1 do add(x,-1,z,WOOD,"floor") end end
 -- Four full-height oak posts and a gabled roof visible from the courtyard.
 for _,x in ipairs({-3,3}) do for _,z in ipairs({-3,1}) do
  for y=0,3 do add(x,y,z,LOG,"post") end
 end end
 for x=-4,4 do for z=-4,2 do
  local y=4+math.floor((4-math.abs(x))/2)
  add(x,y,z,WOOD,"roof")
 end end
 for x=-3,3 do add(x,3,1,LOG,"beam",12);add(x,3,-3,LOG,"beam",12) end
 for x=-1,1 do for z=2,9 do
  add(x,-1,z,STONE,"path")
  for y=0,3 do add(x,y,z,"air","courtyard_clearance") end
 end end
 for x=2,4 do for z=4,6 do
  add(x,-1,z,BRICK,"hearth")
  for y=0,3 do add(x,y,z,"air","courtyard_clearance") end
 end end
 add(3,0,5,"mcl_campfires:campfire_lit","campfire")
 for _,x in ipairs({1,5}) do for z=4,6 do
  add(x,-1,z,STONE,"bench_support");add(x,0,z,LOG,"bench",4)
 end end
 add(-2,0,-2,"mcl_crafting_table:crafting_table","workbench")
 add(2,0,-2,"mcl_furnaces:furnace","furnace",2)
 add(0,5,-1,"mcl_lanterns:lantern_ceiling","lantern")
 for _,x in ipairs({-2,2}) do
  add(x,-1,8,STONE,"lamp_support")
  for y=0,2 do add(x,y,8,LOG,"lamp_post") end
  add(x,3,8,"mcl_lanterns:lantern_floor","lantern")
 end
 return plan
end
function C.place(center)
 local plan=C.plan(center)
 -- Missing bundled resources must fail before the first block is placed.
 for _,op in ipairs(plan) do assert(core.registered_nodes[op.name],"Missing camp node: "..op.name) end
 -- Clear only initial vegetation in the small camp envelope. In dense woods,
 -- giant mushroom caps/branches otherwise hang through the courtyard sightline.
 for x=-5,6 do for z=-5,10 do for y=0,10 do
  local pos=vector.offset(center,x,y,z)
  local name=core.get_node(pos).name
  if core.get_item_group(name,"tree")>0 or core.get_item_group(name,"leaves")>0
  or core.get_item_group(name,"huge_mushroom")>0 or core.get_item_group(name,"plant")>0 then
   core.set_node(pos,{name="air"})
  end
 end end end
 local final={}
 for _,op in ipairs(plan) do
  core.set_node(op.pos,{name=op.name,param2=op.param2})
  final[core.hash_node_position(op.pos)]=op
 end
 -- Foundations descend to natural support, including sloped terrain.
 for _,op in pairs(final) do
  if op.component=="foundation" or op.component=="floor" or op.component=="path" or op.component=="hearth" then
   for dy=1,16 do
    local p=vector.offset(op.pos,0,-dy,0)
    local node=core.get_node(p)
    local def=core.registered_nodes[node.name]
    if def and def.walkable and core.get_item_group(node.name,"leaves")==0 and core.get_item_group(node.name,"tree")==0 then break end
    core.set_node(p,{name=BRICK})
   end
  end
 end
 -- Initialize only the final stations, with native vectors and callbacks.
 for _,op in pairs(final) do
  local construct=core.registered_nodes[op.name].on_construct
  if construct then construct(op.pos) end
 end
 local counts={}
 for _,op in pairs(final) do
  assert(core.get_node(op.pos).name==op.name,"Camp placement mismatch: "..op.component)
  counts[op.component]=(counts[op.component] or 0)+1
 end
 assert(counts.roof and counts.roof>=50 and counts.post==12 and counts.campfire==1,"Incomplete camp")
 return counts
end
return C
