-- SPDX-License-Identifier: GPL-3.0-or-later
local P = everforge.progression
local M = P.model
local labels = {mining = "Minería", forging = "Forja", combat = "Combate", exploration = "Exploración", crafting = "Artesanía"}
local order = {"deep_miner", "forgemaster", "guard", "trailblazer"}
local form = "everforge:progression"
local function content(player)
 local p = P.load(player)
 if not p then return "label[.5,.5;Perfil inválido: consulta al administrador.]" end
 local fs = {"bgcolor[#17191CEF;true]", "label[.5,.45;EVERFORGE — Dominio]",
  ("label[.5,.95;Nivel %d | XP %d / %d | Puntos %d]"):format(M.level(p.mastery, P.config.mastery_base), p.mastery,
   M.next_xp(p.mastery, P.config.mastery_base), M.points(p, P.config))}
 for i, id in ipairs(M.disciplines) do
  fs[#fs+1] = ("label[.5,%s;%s: nivel %d — %d / %d XP]"):format(1.1 + i * .45, labels[id],
   M.level(p.disciplines[id], P.config.discipline_base), p.disciplines[id], M.next_xp(p.disciplines[id], P.config.discipline_base))
 end
 fs[#fs+1] = "label[.5,3.9;Cada rango cuesta 1 punto y exige ese nivel de disciplina.]"
 for i, id in ipairs(order) do
  local skill = M.skills[id]
  fs[#fs+1] = ("button[.5,%s;3.1,.55;learn_%s;%s %d/%d]"):format(4.1+i*.65, id, skill.label, p.skills[id] or 0, skill.max)
  fs[#fs+1] = ("label[3.85,%s;%s]"):format(4.35+i*.65, core.formspec_escape(skill.description))
 end
 fs[#fs+1] = "button_exit[9.4,7.35;1.6,.55;quit;Cerrar]"
 return table.concat(fs)
end
local function show(player)
 core.show_formspec(player:get_player_name(), form, "formspec_version[7]size[11.5,8]" .. content(player))
end
local function receive(player, fields)
 for _, id in ipairs(order) do
  if fields["learn_" .. id] then
   local p = P.load(player)
   if not p then return end
   local ok, message = M.buy(p, id, P.config)
   if ok then P.save(player, p); P.apply(player) end
   core.chat_send_player(player:get_player_name(), message)
   return true
  end
 end
end
core.register_chatcommand("everforge", {description = "Dominio, disciplinas y habilidades", func = function(name)
 local player = core.get_player_by_name(name)
 if not player then return false end
 show(player)
 return true
end})
core.register_on_player_receive_fields(function(player, name, fields)
 if name ~= form then return end
 receive(player, fields)
 if not fields.quit then show(player) end
 return true
end)
mcl_inventory.register_survival_inventory_tab({id = "everforge_rpg", description = "Everforge", item_icon = "adamantine:ingot",
 show_inventory = false, build = content, handle = function(player, fields)
 if receive(player, fields) then mcl_inventory.update_inventory(player) end
end})
