-- SPDX-License-Identifier: GPL-3.0-or-later
local path = core.get_modpath("everforge") .. "/progression/"
local model = dofile(path .. "model.lua")
local P = {model = model, key = "everforge:progression:v1"}
everforge.progression = P
local function setting(name, default, min, max)
 local n = tonumber(core.settings:get("everforge_" .. name)) or default
 if n ~= n then n = default end
 return math.floor(math.max(min, math.min(max, n)))
end
P.config = {mastery_base = setting("mastery_base", 50, 1, 100000),
 discipline_base = setting("discipline_base", 25, 1, 100000), rates = {}}
for id, value in pairs({mining = 1, forging = 6, combat = 15, exploration = 8, crafting = 4}) do
 P.config.rates[id] = setting("xp_" .. id, value, 0, 10000)
end
local session = tostring(core.get_us_time())
local sequence = 0
local cooldowns = {}
function P.load(player)
 local raw = player:get_meta():get_string(P.key)
 if raw == "" then return model.new() end
 local data = core.deserialize(raw, true)
 if not model.valid(data) then
  -- Never reset unknown/corrupt data or replace it with an empty profile.
  core.log("error", "[Everforge] Invalid progression profile: " .. player:get_player_name())
  return nil
 end
 return data
end
function P.save(player, profile)
 assert(model.valid(profile), "Invalid Everforge profile")
 player:get_meta():set_string(P.key, core.serialize(profile))
end
function P.rank(player, skill)
 local p = P.load(player)
 return p and p.skills[skill] or 0
end
function P.apply(player)
 for _, attr in ipairs({"speed", "jump", "gravity"}) do
  -- Remove only our obsolete factors; unrelated mods remain intact.
  playerphysics.remove_physics_factor(player, attr, "everforge:class")
  playerphysics.remove_physics_factor(player, attr, "everforge:skill")
 end
 local rank = P.rank(player, "trailblazer")
 if rank > 0 then playerphysics.add_physics_factor(player, "speed", "everforge:skill", 1 + .04 * rank) end
end
function P.record(player, discipline, subject, cell, event_id)
 if not player or not player:is_player() or core.is_creative_enabled(player:get_player_name()) then return false end
 local name = player:get_player_name()
 local now = core.get_us_time() / 1000000
 local times = cooldowns[name] or {}
 cooldowns[name] = times
 if not event_id and now - (times[discipline] or -10) < 0.5 then return false end
 local p = P.load(player)
 if not p then return false end
 sequence = sequence + 1
 local old_level = model.level(p.mastery, P.config.mastery_base)
 local ok = model.grant(p, {id = event_id or session .. ":" .. sequence, discipline = discipline, cell = cell}, P.config)
 if not ok then return false end
 times[discipline] = now
 P.save(player, p)
 if model.level(p.mastery, P.config.mastery_base) > old_level then
  core.chat_send_player(name, "Dominio: nivel " .. model.level(p.mastery, P.config.mastery_base)
   .. ". Puntos disponibles: " .. model.points(p, P.config) .. ". Abre /everforge.")
 end
 return true
end
core.register_on_joinplayer(function(player)
 local p = P.load(player)
 if p then P.save(player, p) end
 P.apply(player)
end)
core.register_on_leaveplayer(function(player) cooldowns[player:get_player_name()] = nil end)
-- No XP-vanilla callbacks, death handlers, class selection or legacy point readers.
core.register_on_dignode(function(pos, node, player)
 if node.name == "air" or not player or not player:is_player() then return end
 -- Fixed coordinate ID prevents immediate place/dig loops in the bounded recent window.
 P.record(player, "mining", node.name, nil, "dig:" .. core.pos_to_string(pos))
end)
core.register_on_craft(function(stack, player)
 if not stack:is_empty() then P.record(player, "crafting", stack:get_name()) end
end)
mcl_damage.register_on_death(function(object, reason)
 local entity = object and object:get_luaentity()
 if not entity or entity.type ~= "monster" then return end
 local player = reason and reason.source
 if not player or not player:is_player() then return end
 P.record(player, "combat", entity.name)
end)
local elapsed = 0
core.register_globalstep(function(dt)
 elapsed = elapsed + dt
 if elapsed < 3 then return end
 elapsed = 0
 for _, player in ipairs(core.get_connected_players()) do
  local pos = player:get_pos()
  local dimension = mcl_worlds.pos_to_dimension(pos)
  if dimension ~= "void" and dimension ~= "default" then
   local cell = dimension .. ":" .. math.floor(pos.x / 128) .. ":" .. math.floor(pos.z / 128)
   P.record(player, "exploration", cell, cell, "explore:" .. cell)
  end
 end
end)
mcl_damage.register_modifier(function(object, damage, reason)
 if object and object:is_player() and damage > 0 and P.rank(object, "guard") > 0
 and reason and (reason.type == "mob" or reason.type == "player") then return damage * .9 end
end, 0)
return P
