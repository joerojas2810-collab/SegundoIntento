-- SPDX-License-Identifier: GPL-3.0-or-later
-- Development prototype: one small camp, built only in a fresh world.
local camp = dofile(core.get_modpath("everforge") .. "/camp.lua")
local storage = core.get_mod_storage()
local key = "start_region:v1"
local encoded = storage:get_string(key)
local region = encoded ~= "" and core.parse_json(encoded) or nil
local enabled = core.settings:get_bool("everforge_start_region", true)
if not enabled then return end
local previous_environment = io.open(core.get_worldpath() .. "/env_meta.txt", "r")
local existing_world = previous_environment ~= nil
if previous_environment then previous_environment:close() end
if not region and existing_world then
 core.log("warning", "[Everforge] Existing world without region: no terrain will be changed")
 return
end
local function save() storage:set_string(key, core.write_json(region)) end
local starting = false
if not region then
 region = {version = 1, state = "building", radius = 10,
  center = vector.copy(mcl_biome_dispatch.get_spawn_point_2d()), seed = core.get_mapgen_setting("seed")}
 save()
 starting = true
elseif region.state ~= "ready" then
 region.state = "needs_review"
 save()
 core.log("error", "[Everforge] Interrupted region creation: review or recreate the development world")
end
local function safe(x, y, z, name)
 local p = {x=x,y=y,z=z}
 local floor = core.get_node({x=x,y=y-1,z=z})
 local feet, head = core.get_node(p), core.get_node({x=x,y=y+1,z=z})
 local a,b,c = core.registered_nodes[floor.name],core.registered_nodes[feet.name],core.registered_nodes[head.name]
 if not a or not b or not c or not a.walkable or b.walkable or c.walkable then return false end
 for _, pair in ipairs({{floor,a},{feet,b},{head,c}}) do
  if pair[1].name == "ignore" or pair[2].liquidtype ~= "none" or (pair[2].damage_per_second or 0)>0
  or core.get_item_group(pair[1].name,"portal")>0 then return false end
 end
 return not core.is_protected(p, name or "") and not core.is_protected({x=x,y=y-1,z=z}, name or "")
  and not core.is_protected({x=x,y=y+1,z=z}, name or "")
end
local function find_arrival(player)
 if region.state ~= "ready" then return nil end
 local c,r = region.center,region.radius
 core.load_area({x=c.x-r,y=c.y-12,z=c.z-r}, {x=c.x+r,y=c.y+12,z=c.z+r})
 local preferred = region.arrival or c
 for radius = 0,r*2 do
  for dx=-radius,radius do for dz=-radius,radius do
   if math.max(math.abs(dx),math.abs(dz)) == radius then
    for _,dy in ipairs({0,1,-1,2,-2,3,-3,4,-4,5,-5,6,-6,-7,-8}) do
     if math.abs(preferred.x+dx-c.x)<=r and math.abs(preferred.z+dz-c.z)<=r
     and safe(preferred.x+dx,c.y+dy,preferred.z+dz,player and player:get_player_name()) then
      return {x=preferred.x+dx,y=c.y+dy-.5,z=preferred.z+dz}
     end
    end
   end
  end end
 end
end
local limbo = {x=31007,y=31007,z=31007}
local provider
provider = function(player)
 if region.state == "building" and player and mcl_levelgen.levelgen_enabled then
  player:get_meta():set_int("everforge:arrival_pending",1)
  local c,r,dim=region.center,region.radius+2,mcl_levelgen.get_dimension("mcl_levelgen:overworld")
  return mcl_biome_dispatch.emerged_teleport_prepare(player,
   vector.new(c.x-r,dim.y_global,c.z-r),vector.new(c.x+r,dim.y_max,c.z+r),
   "Preparando la región inicial de Everforge...",function(obj)
    core.after(0,function() if obj:is_valid() then obj:set_pos(provider(obj)) end end)
   end)
 end
 local p = find_arrival(player)
 if p then
  if player then
   if player:get_meta():get_int("everforge:arrival_pending")==1 then player:set_look_horizontal(math.pi) end
   player:get_meta():set_int("everforge:arrival_pending",0)
  end
  return p
 end
 if player then
  player:get_meta():set_int("everforge:arrival_pending",1)
  local name = player:get_player_name()
  core.log("error", "[Everforge] Arrival blocked for " .. name .. "; region=" .. region.state)
  core.after(0, function() core.kick_player(name, "Everforge: región inicial no disponible. El administrador debe revisar el mundo; no se han alterado construcciones.") end)
 end
 return vector.copy(limbo)
end
mcl_biome_dispatch.register_world_spawn_provider(provider)
core.register_on_joinplayer(function(player)
 if player:get_meta():get_int("everforge:arrival_pending") == 1 and not mcl_biome_dispatch.in_limbo(player) then player:set_pos(provider(player)) end
end)
core.register_on_prejoinplayer(function()
 if region.state == "needs_review" or (region.state == "building" and not mcl_levelgen.levelgen_enabled) then
  return "Everforge: región inicial no disponible. Consulta el registro del servidor."
 end
end)
local function fail(message)
 region.state = "needs_review"; save()
 core.log("error", "[Everforge] Region: " .. message)
end
local function build()
 local c = region.center
 local surface
 if mcl_levelgen.levelgen_enabled then
  local dim = mcl_levelgen.get_dimension("mcl_levelgen:overworld")
  local height = mcl_levelgen.map_index_heightmap(dim,c.x,c.z,false)
  if not height then return fail("no heightmap") end
  surface = height + dim.y_global - 2
 else
  surface = core.get_spawn_level(c.x,c.z) or 16
 end
 core.load_area({x=c.x-8,y=surface-32,z=c.z-8},{x=c.x+8,y=surface+32,z=c.z+8})
 -- Find a natural dry support near the native center, never flatten the region.
 local found
 for dy=32,-96,-1 do
  local p=vector.new(c.x,surface+dy-1,c.z)
  local ground=core.get_node(p).name
  local above=core.registered_nodes[core.get_node(vector.offset(p,0,1,0)).name]
  local def=core.registered_nodes[ground]
  -- A canopy is walkable, but is not ground. Trunks/vegetation within the
  -- first-build footprint will be cleared; don't require an empty tree column.
  if def and def.walkable and above and above.liquidtype=="none"
  and (core.get_item_group(ground,"soil")>0 or core.get_item_group(ground,"stone")>0
   or core.get_item_group(ground,"sand")>0 or ground=="mcl_core:snowblock") then
   found=surface+dy; break
  end
 end
 if not found then return fail("no dry ground at procedural spawn; try another development seed") end
 c.y = found
 local ok,counts=pcall(camp.place,vector.new(c.x,c.y,c.z))
 if not ok then return fail(tostring(counts)) end
 region.revision=camp.revision
 region.components=counts
 region.arrival={x=c.x-1,y=c.y,z=c.z+6}
 region.state = "ready"; save()
 if not find_arrival() then return fail("camp has no safe arrival") end
 core.log("action", "[Everforge] REGION_READY " .. core.write_json(region))
end
if starting then
 core.register_on_mods_loaded(function()
  core.after(0.2, function()
   local c,r=region.center,region.radius+2
   if mcl_levelgen.levelgen_enabled then
    local dim=mcl_levelgen.get_dimension("mcl_levelgen:overworld")
    local done=false
    mcl_levelgen.generate_area(c.x-r,dim.y_global,c.z-r,c.x+r,dim.y_max,c.z+r,function(progress)
     if not done and progress.n_regenerated == progress.total_regen and progress.n_emerged == progress.total_emerge
     and mcl_levelgen.is_area_fully_regenerated(dim,c.x-r,dim.y_global,c.z-r,c.x+r,dim.y_max,c.z+r) then
      done=true; core.after(0,build)
     end
    end)
   else
    local bad=false
    core.emerge_area({x=c.x-r,y=-32,z=c.z-r},{x=c.x+r,y=160,z=c.z+r},function(_,action,left)
     if action==core.EMERGE_CANCELLED or action==core.EMERGE_ERRORED then bad=true end
     if left==0 then if bad then fail("emerge failed") else core.after(0,build) end end
    end)
   end
  end)
 end)
end
core.register_on_newplayer(function(player)
 core.after(0,function() if player:is_valid() then player:set_look_horizontal(math.pi) end end)
end)
-- Diagnostic API for reproducible integration tests; no regeneration method.
everforge.start_region = {get = function() return core.parse_json(core.write_json(region)) end, find_arrival = find_arrival}
