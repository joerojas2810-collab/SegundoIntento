-- SPDX-License-Identifier: GPL-3.0-or-later
-- Installed ONLY as worldmod in disposable integration worlds by play_everforge.py.
local P = everforge.progression
local M = P.model
local store = core.get_mod_storage()
local stage = core.settings:get("everforge_test_stage")
local function check(value, message) assert(value, "EVERFORGE_TEST_FAIL: " .. message) end
local function passed(message) core.log("action", "EVERFORGE_TEST_PASS: " .. message) end
local function model_tests()
 local cfg={mastery_base=50,discipline_base=25,rates={mining=1,forging=6,combat=15,exploration=8,crafting=4}}
 local p=M.new()
 check(M.valid(core.deserialize(core.serialize(p), true)),"empty profile serialization roundtrip")
 for i=1,50 do check(M.grant(p,{id="mining:"..i,discipline="mining"},cfg),"grant") end
 check(p.mastery==50 and p.disciplines.mining==50 and M.points(p,cfg)==1,"independent points")
 check(not M.grant(p,{id="mining:50",discipline="mining"},cfg) and p.mastery==50,"dedupe")
 check(M.buy(p,"deep_miner",cfg),"skill purchase")
 check(not M.buy(p,"deep_miner",cfg) and p.spent==1,"no overspend")
 check(M.valid(core.deserialize(core.serialize(p), true)),"purchased profile serialization roundtrip")
 check(not M.grant(p,{id="bad",discipline="unknown"},cfg),"reject unknown track")
 check(M.grant(p,{id="cell",discipline="exploration",cell="overworld:0:0"},cfg),"exploration")
 check(not M.grant(p,{id="cell2",discipline="exploration",cell="overworld:0:0"},cfg),"persistent exploration dedupe")
 for i=1,150 do M.grant(p,{id="craft:"..i,discipline="crafting"},cfg) end
 check(#p.seen==128 and M.valid(p),"bounded event history")
 passed("model: serialization, curves, points, purchase, dedupe, exploration, bounds")
end
local function stop() core.after(1,function() core.request_shutdown("Everforge integration test completed",false,0) end) end
local function region_tests()
 local r=everforge.start_region and everforge.start_region.get()
 if not r or r.state~="ready" then return false end
 local arrival=everforge.start_region.find_arrival()
 check(arrival and math.abs(arrival.x-r.center.x)<=r.radius,"safe arrival in region")
 if r.revision==2 then
  check(arrival.x==r.arrival.x and arrival.z==r.arrival.z and arrival.y==r.center.y-.5,"ground-first courtyard arrival")
  local c=r.center
  local expected={
   {vector.offset(c,0,6,-1),"mcl_trees:wood_oak"},
   {vector.offset(c,-3,0,1),"mcl_trees:tree_oak"},
   {vector.offset(c,3,0,5),"mcl_campfires:campfire_lit"},
   {vector.offset(c,-2,0,-2),"mcl_crafting_table:crafting_table"},
   {vector.offset(c,2,0,-2),"mcl_furnaces:furnace"},
   {vector.offset(c,0,5,-1),"mcl_lanterns:lantern_ceiling"},
  }
  for _,pair in ipairs(expected) do check(core.get_node(pair[1]).name==pair[2],"physical camp component "..pair[2]) end
  check(r.components.roof==63 and r.components.post==12,"complete roof and posts recorded")
  -- Exercise the actual HUD producer. The native guide keeps mining mechanics.
  local original=mcl_util.get_pointed_thing
  local target=vector.offset(c,0,-1,4)
  mcl_util.get_pointed_thing=function() return {type="node",under=target} end
  local text=everforge._waila_text({get_player_name=function() return "RuntimeHUD" end})
  mcl_util.get_pointed_thing=original
  check(text~="" and not text:find("Type:",1,true) and not text:find("Recommended tool:",1,true),"compact HUD does not restore removed fields")
  check(text:find("Minimum mining level:",1,true),"HUD keeps mining level")
  passed("physical camp: roof, posts, campfire, lantern and workstations; compact HUD")
 end
 local marker=vector.new(r.center.x+5,r.center.y+6,r.center.z+5)
 core.load_area(marker)
 if stage=="bootstrap" then
  core.set_node(marker,{name="mcl_core:goldblock"})
  core.get_meta(marker):set_string("everforge_test","player construction survives restart")
  store:set_string("center",core.write_json(r.center))
  if r.revision==2 then
   local edit=vector.offset(r.center,4,4,-4)
   core.set_node(edit,{name="mcl_core:goldblock"})
   core.get_meta(edit):set_string("player_edit","do not rebuild")
  end
  passed("actual singlenode region generated; world edit saved for restart")
  stop()
 elseif stage=="restart" then
  check(store:get_string("center")==core.write_json(r.center),"same region after restart")
  check(core.get_node(marker).name=="mcl_core:goldblock","construction preserved")
  if r.revision==2 then
   local edit=vector.offset(r.center,4,4,-4)
   check(core.get_node(edit).name=="mcl_core:goldblock" and core.get_meta(edit):get_string("player_edit")=="do not rebuild","player modification of roof survives without regeneration")
  end
  check(core.get_meta(marker):get_string("everforge_test")~="","node metadata preserved")
  passed("restart: same region, blocks and node metadata preserved")
  stop()
 end
 return true
end
local function equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
local executed=false
local function players_test()
 if executed then return end
 local a,b=core.get_player_by_name("ForgeAlice"),core.get_player_by_name("ForgeBob")
 if not a or not b then return end
 executed=true
 local r=everforge.start_region.get()
 for _,player in ipairs({a,b}) do
  local pos=player:get_pos()
  check(math.abs(pos.x-r.center.x)<=r.radius and math.abs(pos.z-r.center.z)<=r.radius,"both players arrive in same camp")
 end
 P.save(a,M.new()); P.save(b,M.new())
 mcl_experience.set_xp(a,10)
 mcl_experience.add_xp(a,10)
 check(mcl_experience.get_xp(a)==20,"vanilla XP unmodified")
 -- Exercise the real dig path with a real player and native tool.
 local pos=vector.new(r.center.x+4,r.center.y+1,r.center.z+4)
 core.set_node(pos,{name="mcl_core:stone"})
 a:set_wielded_item(ItemStack("mcl_tools:pick_diamond"))
 core.node_dig(pos,core.get_node(pos),a)
 check(P.load(a).disciplines.mining==1,"real node_dig adapter")
 -- A completed craft dispatch uses the engine's registered callbacks.
 local grid={ItemStack("mcl_core:wood")}
 for _, cb in ipairs(core.registered_on_crafts) do cb(ItemStack("mcl_core:stick 4"),a,grid,a:get_inventory()) end
 check(P.load(a).disciplines.crafting==4,"completed craft callbacks")
 local forge=vector.offset(pos,1,0,0)
 core.set_node(forge,{name="everforge:alloy_melter"})
 local def=core.registered_nodes["everforge:alloy_melter"]
 def.on_construct(forge)
 local inv=core.get_meta(forge):get_inventory()
 inv:set_stack("input",1,ItemStack("mcl_raw_ores:raw_iron"))
 inv:set_stack("fuel",1,ItemStack("mcl_core:coal_lump"))
 def.on_metadata_inventory_put(forge,"input",1,inv:get_stack("input",1),a)
 for _=1,12 do def.on_timer(forge) end
 check(not inv:get_stack("output",1):is_empty() and P.load(a).disciplines.forging==6,"real melter timer output")
 local mob=core.add_entity(vector.offset(pos,0,2,1),"mobs_mc:zombie")
 check(mob~=nil,"spawn native monster")
 mcl_util.deal_damage(mob,1000,{type="player",source=a,direct=a})
 check(P.load(a).disciplines.combat==15,"actual attributed monster death")
 check(P.record(a,"exploration","test","test:100:100","qa-explore"),"exploration record")
 check(P.load(a).disciplines.exploration==8,"exploration XP")
 check(P.load(b).mastery==0,"individual progression isolation")
 check(mcl_experience.get_xp(a)==20,"all new progression leaves vanilla XP intact")
 -- Enough actual events for one purchase, no XP cheats in the production module.
 for i=1,30 do P.record(a,"mining","test",nil,"qa-mine:"..i) end
 local p=P.load(a)
 check(M.buy(p,"deep_miner",P.config),"buy first real profile skill")
 P.save(a,p); P.apply(a)
 local actual = a:get_pos()
 local dim = mcl_worlds.pos_to_dimension(actual)
 local cell = dim .. ":" .. math.floor(actual.x/128) .. ":" .. math.floor(actual.z/128)
 P.record(a,"exploration",cell,cell,"explore:"..cell)
 store:set_string("alice",a:get_meta():get_string(P.key))
 store:set_int("vanilla_xp",20)
 passed("two real clients: shared spawn, dig, craft dispatch, forge, kill, exploration, isolated XP, skill purchase")
 -- Save a physical change made through Bob's world and verify from Alice's map.
 core.set_node(pos,{name="mcl_core:brick_block"})
 store:set_string("shared_pos",core.pos_to_string(pos))
 passed("shared physical world edited; profile saved for reconnect/restart")
 stop()
end
core.register_on_joinplayer(function(player)
 if stage=="solo" then
  local function ready()
   if not player:is_valid() then return end
   local r=everforge.start_region.get()
   if r.state~="ready" then core.after(1,ready); return end
   core.after(2,function()
    check(math.abs(player:get_pos().x-r.center.x)<=r.radius,"singleplayer creation arrives in region")
    check(P.load(player),"singleplayer profile")
    core.registered_chatcommands.everforge.func(player:get_player_name())
    passed("local game: fresh world, pending arrival, player spawn, profile and UI command")
    stop()
   end)
  end
  core.after(1,ready)
 else
  core.after(1,function() if player:is_valid() then core.registered_chatcommands.everforge.func(player:get_player_name()) end end)
 end
 if stage=="players" then core.after(4,players_test) end
 if stage=="mechanics" and player:get_player_name()=="ForgeAlice" then
  core.after(3,function()
   local r=everforge.start_region.get()
   local p=M.new(); p.mastery=800
   for _,id in ipairs(M.disciplines) do p.disciplines[id]=25 end
   P.save(player,p)
   local reason={type="mob",flags={}}
   local before=mcl_damage.run_modifiers(player,10,reason)
   for _,id in ipairs({"deep_miner","forgemaster","trailblazer","guard"}) do
    for _,cb in ipairs(core.registered_on_player_receive_fields) do
     cb(player,"everforge:progression",{["learn_"..id]=true,quit=true})
    end
    check(P.rank(player,id)==1,"UI purchase "..id)
   end
   check(math.abs(playerphysics.get_physics_factor(player,"speed","everforge:skill")-1.04)<.00001,"speed effect")
   check(math.abs(mcl_damage.run_modifiers(player,10,reason)-before*.9)<.00001,"guard damage effect")
   local c=r.center
   local platform=vector.new(c.x+20,c.y,c.z)
   for dx=-3,3 do for dz=-3,3 do
    core.set_node(vector.offset(platform,dx,-1,dz),{name="mcl_core:stone"})
    for dy=0,2 do core.set_node(vector.offset(platform,dx,dy,dz),{name="air"}) end
   end end
   core.set_node(platform,{name="mcl_beds:bed_red_bottom",param2=0})
   core.set_node(vector.offset(platform,0,0,1),{name="mcl_beds:bed_red_top",param2=0})
   player:get_meta():set_string("mcl_beds:spawn",core.pos_to_string(platform))
   local bed,custom=mcl_spawn.get_player_spawn_pos(player)
   check(custom and math.abs(bed.x-platform.x)<=2,"native bed priority outside region")
   core.set_node(platform,{name="mcl_beds:respawn_anchor_charged_2"})
   local anchor=mcl_spawn.get_player_spawn_pos(player)
   check(anchor.x==platform.x and core.get_node(platform).name=="mcl_beds:respawn_anchor_charged_1","native charged anchor consumption")
   player:get_meta():set_string("mcl_beds:spawn","")
   local fallback=mcl_spawn.get_player_spawn_pos(player)
   check(math.abs(fallback.x-c.x)<=r.radius,"native fallback returns to region")
   local nodes={}
   for dx=-r.radius,r.radius do for dz=-r.radius,r.radius do for dy=-10,9 do
    local pos=vector.new(c.x+dx,c.y+dy,c.z+dz)
    nodes[#nodes+1]={pos,core.get_node(pos)}
    core.swap_node(pos,{name="mcl_core:stone"})
   end end end
   check(not everforge.start_region.find_arrival(player),"completely blocked region has no unsafe fallback")
   for _,item in ipairs(nodes) do core.swap_node(item[1],item[2]) end
   check(everforge.start_region.find_arrival(player),"alternative arrival after restoring test blocks")
   passed("mechanics: UI purchases, speed, defense, bed priority, anchor charge, fallback, blocked region")
   stop()
  end)
 end
 if stage=="verify_players" and player:get_player_name()=="ForgeAlice" then
  core.after(3,function()
   check(equal(P.load(player),core.deserialize(store:get_string("alice"),true)),"actual player profile survives restart")
   check(mcl_experience.get_xp(player)==store:get_int("vanilla_xp"),"vanilla XP persists")
   local pos=core.string_to_pos(store:get_string("shared_pos"));core.load_area(pos)
   check(core.get_node(pos).name=="mcl_core:brick_block","shared modification persists")
   passed("real player reconnect: XP, skill, vanilla XP and world modification persist")
   local mastery = P.load(player).mastery
   player:set_hp(0)
   check(mcl_experience.get_xp(player)==0,"native XP death loss")
   check(P.load(player).mastery==mastery,"Mastery survives real death")
   player:respawn()
   local r=everforge.start_region.get()
   check(math.abs(player:get_pos().x-r.center.x)<=r.radius,"native death fallback to camp")
   passed("real death and respawn: vanilla XP lost, Everforge XP retained, shared fallback")
   stop()
  end)
 end
end)
core.register_on_mods_loaded(function()
 core.after(1,model_tests)
 local elapsed=0
 core.register_globalstep(function(dt)
  elapsed=elapsed+dt
  if elapsed<1 then return end
  elapsed=0
  if not executed and (stage=="bootstrap" or stage=="restart") then executed=region_tests() end
 end)
 -- Bounded smoke test: a hung generation must fail visibly.
 core.after(180,function() error("EVERFORGE_TEST_FAIL: runtime timeout") end)
end)

core.register_on_shutdown(function()
 if stage == "players" then
  local a=core.get_player_by_name("ForgeAlice")
  if a then
   store:set_string("alice",a:get_meta():get_string(P.key))
   store:set_int("vanilla_xp",mcl_experience.get_xp(a))
  end
 end
end)
