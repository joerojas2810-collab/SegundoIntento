-- SPDX-License-Identifier: GPL-3.0-or-later
-- Preflight only. Never writes terrain; usable with generated natural columns.
local S = {}
local terrain = {}
for _,name in ipairs({"stone","andesite","granite","diorite","dirt","dirt_with_grass",
 "podzol","podzol_snow","coarse_dirt","mycelium","mycelium_snow","dirt_with_grass_snow","gravel","sand","sandstone","redsand","redsandstone","clay","snowblock"}) do
 terrain["mcl_core:"..name]=true
end
terrain["mcl_mud:mud"]=true
terrain["mcl_amethyst:calcite"]=true
terrain["mcl_deepslate:deepslate"]=true
terrain["mcl_deepslate:tuff"]=true
terrain["mcl_colorblocks:hardened_clay"]=true
for _,color in ipairs({"white","orange","yellow","brown","red","silver"}) do
 terrain["mcl_colorblocks:hardened_clay_"..color]=true
end
terrain["mcl_copper:stone_with_copper"]=true
for _,ore in ipairs({"coal","iron","gold","redstone","lapis","emerald","diamond"}) do
 terrain["mcl_core:stone_with_"..ore]=true
end
function S.natural(name)
 local def=core.registered_nodes[name]
 return terrain[name] and def and def.walkable and def.liquidtype=="none"
  and (def.damage_per_second or 0)==0
end
function S.clearable(name)
 local d=core.registered_nodes[name]
 if not d or d.liquidtype~="none" or (d.damage_per_second or 0)>0 then return false end
 return name=="air" or name=="mcl_core:snow" or core.get_item_group(name,"top_snow")>0
  or name:sub(1,24)=="everforge_world_visuals:"
  or core.get_item_group(name,"tree")>0 or core.get_item_group(name,"leaves")>0
  or core.get_item_group(name,"plant")>0 or core.get_item_group(name,"double_plant")>0
  or core.get_item_group(name,"huge_mushroom")>0
end
function S.column(x,z,estimate,min_y,max_y)
 if not estimate then return nil,"heightmap_missing" end
 -- Search spans several server steps. Never trust residency from an earlier
 -- stage: unused mapblocks may have been unloaded in the meantime.
 core.load_area({x=x,y=math.max(estimate-80,min_y),z=z},
  {x=x,y=math.min(estimate+16,max_y-1),z=z})
 for y=math.min(estimate+16,max_y-1),math.max(estimate-80,min_y),-1 do
  local name=core.get_node({x=x,y=y,z=z}).name
  if name=="ignore" then return nil,"unloaded_column" end
  if S.natural(name) then return y end
  if not S.clearable(name) then return nil,"blocked_surface:"..name end
 end
 return nil,"ground_not_found"
end
function S.validate(c)
 core.load_area(vector.offset(c,-5,-4,-5),vector.offset(c,6,10,10))
 -- Match the complete clearing envelope and all foundation/bench/lamp columns.
 for x=c.x-5,c.x+6 do for z=c.z-5,c.z+10 do
  local support=false
  -- The top soil layer is replaced by the camp floor; support must exist BELOW it.
  for y=c.y-2,c.y-4,-1 do
   local name=core.get_node({x=x,y=y,z=z}).name
   if S.natural(name) then support=true;break end
   if name=="ignore" then return false,"unloaded_column" end
   if not S.clearable(name) then return false,"wet_or_built_support" end
  end
  if not support then return false,"unsupported_footprint" end
  for y=c.y-4,c.y+10 do
   local p={x=x,y=y,z=z}
   if core.is_protected(p,"") then return false,"protected" end
   if mcl_levelgen.get_structures_at and next(mcl_levelgen.get_structures_at(p,true)) then
    return false,"structure_intersection"
   end
   if y>=c.y then
    local name=core.get_node(p).name
    if name=="ignore" then return false,"unloaded_column" end
    if not S.clearable(name) then return false,"occupied_envelope" end
   end
  end
 end end
 if #core.find_nodes_with_meta(vector.offset(c,-5,-4,-5),vector.offset(c,6,10,10))>0 then
  return false,"node_metadata"
 end
 return true
end
function S.candidates(origin,radius,step)
 local result={}
 for ring=0,radius,step do
  for dx=-ring,ring,step do for dz=-ring,ring,step do
   if math.max(math.abs(dx),math.abs(dz))==ring then
    result[#result+1]={x=origin.x+dx,z=origin.z+dz}
   end
  end end
 end
 return result
end
function S.choose(x,z,column)
 local low,high=math.huge,-math.huge
 for dx=-5,6 do for dz=-5,10 do
  local y,reason=column(x+dx,z+dz)
  if not y then return nil,reason end
  low=math.min(low,y);high=math.max(high,y)
  if high-low>3 then return nil,"slope_over_3" end
 end end
 local c={x=x,y=high+1,z=z}
 local ok,reason=S.validate(c)
 if not ok then return nil,reason end
 return c
end
return S
