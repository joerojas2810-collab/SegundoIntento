-- SPDX-License-Identifier: GPL-3.0-or-later
-- One camp in a fresh world only. Bounded, seed-independent terrain preflight.
local site = dofile(core.get_modpath("everforge") .. "/camp_site.lua")
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
if encoded ~= "" and (type(region) ~= "table" or type(region.center) ~= "table"
 or type(region.center.x) ~= "number" or type(region.center.z) ~= "number"
 or type(region.radius) ~= "number" or region.radius < 1 or region.radius > 64
 or (region.arrival and (type(region.arrival) ~= "table"
  or type(region.arrival.x) ~= "number" or type(region.arrival.z) ~= "number"))
 or (region.state == "ready" and type(region.center.y) ~= "number")) then
 core.log("error", "[Everforge] Invalid saved region; preserved without migration or terrain changes")
 return
end
if not region and existing_world then
 core.log("warning", "[Everforge] Existing world without region: no terrain will be changed")
 return
end
local function save() storage:set_string(key, core.write_json(region)) end
local starting = false
if not region then
 region = {version = 1, state = "building", radius = 10,
  center = vector.round(mcl_biome_dispatch.get_spawn_point_2d()), seed = core.get_mapgen_setting("seed")}
 region.origin = vector.copy(region.center)
 save()
 starting = true
elseif region.state ~= "ready" then
 region.state = "needs_review"
 core.log("error", "[Everforge] Interrupted region creation: no automatic retry or terrain changes; administrator review required")
end
local function safe(x, y, z, name)
 local p = {x=x,y=y,z=z}
 local floor = core.get_node({x=x,y=y-1,z=z})
 local feet, head = core.get_node(p), core.get_node({x=x,y=y+1,z=z})
 local a,b,c = core.registered_nodes[floor.name],core.registered_nodes[feet.name],core.registered_nodes[head.name]
 if not a or not b or not c or not a.walkable or b.walkable or c.walkable
 or core.get_item_group(floor.name,"leaves")>0 or core.get_item_group(floor.name,"tree")>0 then return false end
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
 -- Search only positions connected on foot to the camp interior. Never choose
 -- a nearby roof/canopy or disconnected ledge merely because it is walkable.
 local queue,seen={},{}
 local name=player and player:get_player_name()
 for _,dx in ipairs({0,-1,1}) do
  if safe(c.x+dx,c.y,c.z,name) then queue[1]={x=c.x+dx,y=c.y,z=c.z};break end
 end
 if #queue==0 then return nil end
 seen[queue[1].x..":"..queue[1].z]=true
 local best,score,index=nil,math.huge,1
 while queue[index] and index<=441 do
  local p=queue[index];index=index+1
  do
   local distance=math.abs(p.x-preferred.x)+math.abs(p.z-preferred.z)
   if distance<score then best=p;score=distance end
   if score==0 then break end
   for _,d in ipairs({{0,1},{-1,0},{1,0},{0,-1}}) do
    local x,z=p.x+d[1],p.z+d[2]
    if math.abs(x-c.x)<=r and math.abs(z-c.z)<=r and not seen[x..":"..z] then
     for _,dy in ipairs({0,1,-1}) do
      if safe(x,p.y+dy,z,name) then
       seen[x..":"..z]=true
       queue[#queue+1]={x=x,y=p.y+dy,z=z};break
      end
     end
    end
   end
  end
 end
 if best then return {x=best.x,y=best.y-.5,z=best.z} end
end
local limbo = {x=31007,y=31007,z=31007}
local waiting={}
local provider
provider = function(player)
 if region.state == "building" and player and mcl_levelgen.levelgen_enabled then
  player:get_meta():set_int("everforge:arrival_pending",1)
  local name=player:get_player_name()
  if waiting[name]==player then return vector.copy(limbo) end
  waiting[name]=player
  local c,r,dim=region.center,region.radius+2,mcl_levelgen.get_dimension("mcl_levelgen:overworld")
  return mcl_biome_dispatch.emerged_teleport_prepare(player,
   vector.new(c.x-r,dim.y_global,c.z-r),vector.new(c.x+r,dim.y_max,c.z+r),
   "Preparando la región inicial de Everforge...",function(obj)
    local function ready()
     if not obj:is_valid() then
      if waiting[name]==obj then waiting[name]=nil end
      return
     end
     if region.state=="building" then core.after(0.25,ready);return end
     if waiting[name]==obj then waiting[name]=nil end
     obj:set_pos(provider(obj))
    end
    core.after(0,ready)
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
core.register_on_leaveplayer(function(player)
 local name=player:get_player_name()
 if waiting[name]==player then waiting[name]=nil end
end)
core.register_on_joinplayer(function(player)
 if player:get_meta():get_int("everforge:arrival_pending") == 1 and not mcl_biome_dispatch.in_limbo(player) then player:set_pos(provider(player)) end
end)
core.register_on_prejoinplayer(function()
 if region.state == "needs_review" or (region.state == "building" and not mcl_levelgen.levelgen_enabled) then
  return "Everforge: región inicial no disponible. Consulta el registro del servidor."
 end
end)
local begin_time=core.get_us_time()
local attempts,rejected,cache,visited=0,{},{},{}
local function fail(message)
 if region.state~="building" then return end
 region.state="needs_review"
 region.failure={reason=message,attempts=attempts,rejected=rejected,
  elapsed_seconds=(core.get_us_time()-begin_time)/1000000}
 save()
 core.log("error", "[Everforge] REGION_FAILED seed="..tostring(region.seed).." "..core.write_json(region.failure))
end
local function alive()
 if region.state~="building" then return false end
 if core.get_us_time()-begin_time>=180000000 then
  fail("generation deadline exceeded (180s); no automatic retry")
  return false
 end
 return true
end
local function place(c)
 if not alive() then return end
 local ok,counts=pcall(camp.place,c)
 if not ok then return fail("preflight_or_placement: "..tostring(counts)) end
 region.center=c
 region.revision=camp.revision
 region.components=counts
 region.arrival={x=c.x,y=c.y,z=c.z+7}
 region.site={attempts=attempts,rejected=rejected,max_support_depth=3,
  search_radius=region.search_radius,elapsed_seconds=(core.get_us_time()-begin_time)/1000000}
 region.state="ready"
 if not find_arrival() then region.state="building";return fail("no connected safe arrival after camp placement") end
 save()
 core.log("action", "[Everforge] REGION_READY "..core.write_json(region))
end
if starting then
 core.register_on_mods_loaded(function()
  begin_time=core.get_us_time()
  core.after(180,function() if region.state=="building" then fail("generation deadline exceeded (180s); no automatic retry") end end)
  core.after(0.2,function()
   local origin=region.origin
   local fallback_used=false
   local stages={4,12,28,60}
   local dim=mcl_levelgen.levelgen_enabled and mcl_levelgen.get_dimension("mcl_levelgen:overworld")
   local next_stage
   next_stage=function(stage)
    if not alive() then return end
    -- A configured anchor can be in open ocean. Try the same seed's native
    -- terrestrial anchor once instead of exhausting the ocean or changing seed.
    local water=(rejected["blocked_surface:mcl_core:water_source"] or 0)
     +(rejected["blocked_surface:mcl_core:water_flowing"] or 0)
    if (not stages[stage] or (stage==3 and attempts>0 and water==attempts))
     and not fallback_used and dim and dim.preset then
     fallback_used=true
     local x,z=dim.preset:find_spawn_position()
     local natural=vector.round({x=x,y=0,z=-z-1})
     if natural.x~=origin.x or natural.z~=origin.z then
      region.fallback_origin=natural
      core.log("warning","[Everforge] REGION_RELOCATE seed="..tostring(region.seed)
       .." unsuitable anchor; trying native land anchor "..core.pos_to_string(natural).." once (same seed)")
      origin=natural;cache={};visited={};stage=1
     end
    end
    local radius=stages[stage]
    if not radius then return fail("no safe footprint within 60 nodes of selected anchors; max 1922 candidates") end
    region.search_radius=radius
    local margin=radius+12
    local minp={x=origin.x-margin,y=dim and dim.y_global or -32,z=origin.z-margin}
    local maxp={x=origin.x+margin,y=dim and dim.y_max or 160,z=origin.z+margin}
    core.log("action","[Everforge] REGION_SEARCH seed="..tostring(region.seed).." radius="..radius.." max_candidates=1922 max_anchors=2")
    -- Native generate_area accepts LOCKED_GENERATED as completed; those blocks
    -- still have pending context writes and are temporarily protected. Wait for
    -- genuinely unlocked blocks before reading terrain or rejecting a site.
    local function unlocked()
     if not dim then return true end
     for bx=math.floor(minp.x/16),math.floor(maxp.x/16) do
      for bz=math.floor(minp.z/16),math.floor(maxp.z/16) do
       for by=math.floor((minp.y-dim.y_global)/16),math.floor((maxp.y-dim.y_global)/16) do
        if not mcl_levelgen.is_generated(dim,bx,by,bz) then return false end
       end
      end
     end
     return true
    end
    local function search()
     if not alive() then return end
     core.load_area(minp,maxp)
     local function column(x,z)
      local key=x..":"..z
      if not cache[key] then
       local height
       if dim then
        local h=mcl_levelgen.map_index_heightmap(dim,x,z,false)
        height=h and h+dim.y_global-2
       else height=core.get_spawn_level(x,z) end
       local y,reason=site.column(x,z,height,minp.y,maxp.y)
       if reason=="unloaded_column" then return nil,reason end
       cache[key]={y=y,reason=reason}
      end
      return cache[key].y,cache[key].reason
     end
     local candidates=site.candidates(origin,radius,4)
     local index=1
     local retries={}
     local batch
     batch=function()
      if not alive() then return end
      if not unlocked() then core.after(0.25,batch);return end
      for _=1,8 do
       local p=candidates[index];index=index+1
       if not p then core.after(0,function() next_stage(stage+1) end);return end
       local key=p.x..":"..p.z
       if not visited[key] then
        visited[key]=true;attempts=attempts+1
        local center,reason=site.choose(p.x,p.z,column)
        if center then place(center);return end
        if reason=="unloaded_column" then
         retries[key]=(retries[key] or 0)+1
         if retries[key]>2 then return fail("terrain unavailable after two emergence attempts at "..key) end
         -- Resolve this same candidate before considering any later candidate.
         -- This avoids selection depending on memory pressure / unload timing.
         visited[key]=nil;attempts=attempts-1;index=index-1;cache={}
         core.log("warning","[Everforge] REGION_LOAD seed="..tostring(region.seed).." candidate="..key.." retry="..retries[key])
         local bad=false
         core.emerge_area({x=p.x-5,y=minp.y,z=p.z-5},{x=p.x+6,y=maxp.y,z=p.z+10},function(_,action,left)
          if action==core.EMERGE_CANCELLED or action==core.EMERGE_ERRORED then bad=true end
          if left==0 and region.state=="building" then
           if bad then fail("candidate emergence failed at "..key) else core.after(0,batch) end
          end
         end)
         return
        end
        rejected[reason or "unknown"]=(rejected[reason or "unknown"] or 0)+1
       end
      end
      core.after(0,batch)
     end
     batch()
    end
    if dim then
     local done=false
     mcl_levelgen.generate_area(minp.x,minp.y,minp.z,maxp.x,maxp.y,maxp.z,function(progress)
      if not alive() or done then return end
      if progress.n_regenerated==progress.total_regen and progress.n_emerged==progress.total_emerge
       and mcl_levelgen.is_area_fully_regenerated(dim,minp.x,minp.y,minp.z,maxp.x,maxp.y,maxp.z) then
       done=true;core.after(0,search)
      end
     end)
    else
     local bad=false
     core.emerge_area(minp,maxp,function(_,action,left)
      if action==core.EMERGE_CANCELLED or action==core.EMERGE_ERRORED then bad=true end
      if left==0 then if bad then fail("emerge failed") else core.after(0,search) end end
     end)
    end
   end
   next_stage(1)
  end)
 end)
end
core.register_on_newplayer(function(player)
 core.after(0,function() if player:is_valid() then player:set_look_horizontal(math.pi) end end)
end)
-- Diagnostic API for reproducible integration tests; no regeneration method.
everforge.start_region = {get = function() return core.parse_json(core.write_json(region)) end, find_arrival = find_arrival}
