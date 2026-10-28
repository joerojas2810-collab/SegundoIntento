-- SPDX-License-Identifier: GPL-3.0-or-later
local P = everforge.progression
local M = P.model
local S = core.get_translator(core.get_current_modname())
local labels = {mining = "Minería", forging = "Forja", combat = "Combate", exploration = "Exploración", crafting = "Artesanía"}
local order = {"deep_miner", "forgemaster", "guard", "trailblazer"}
local form = "everforge:progression"

local function frame(width, height)
 return table.concat({
  "no_prepend[]bgcolor[#08090BEF;true]",
  ("background9[0,0;%s,%s;everforge_ui_panel.png;false;8]"):format(width, height),
  "style_type[label,textarea;textcolor=#F2E8D9;font_size=*1]",
  "style_type[textarea;font_size=*0.8]",
  "style_type[button,button_exit,image_button,item_image_button;textcolor=#FFF1DC;border=false;bgimg=everforge_ui_button.png;bgimg_pressed=everforge_ui_button_pressed.png;bgimg_middle=4;font=bold;font_size=*0.85]",
  "style_type[button:hovered,button_exit:hovered,image_button:hovered,item_image_button:hovered;bgimg=everforge_ui_button_hover.png]",
  "listcolors[#17191C;#704F39;#00000000;#151619;#F2E8D9]",
 })
end

-- Presentation hook consumed only by the survival inventory builder. It neither
-- changes the global prepend nor touches the trusted engine pause menu.
mcl_inventory.survival_inventory_theme = {frame = frame, slot = "everforge_ui_slot.png", main_label = S("Inventory")}

local descriptions = {
 deep_miner = "−4 % de desgaste por rango.",
 forgemaster = "−1 s al forjar (mínimo 3 s).",
 guard = "−10 % daño cuerpo a cuerpo.",
 trailblazer = "+4 % de velocidad por rango.",
}

local function content(player)
 local p = P.load(player)
 if not p then return "label[.5,.5;Perfil inválido: consulta al administrador.]" end
 local fs = {frame(11.5, 8),
  "label[.6,.6;EVERFORGE — Dominio]",
  "box[.45,1.1;4.0,6.0;#111214EE]", "box[4.65,1.1;6.4,6.0;#111214EE]",
  ("label[.65,1.55;Nivel %d]"):format(M.level(p.mastery, P.config.mastery_base)),
  ("label[.65,2.05;XP %d / %d]"):format(p.mastery, M.next_xp(p.mastery, P.config.mastery_base)),
  ("label[.65,2.55;Puntos %d]"):format(M.points(p, P.config))}
 fs[#fs+1] = "style_type[label;font_size=*0.75]"
 for i, id in ipairs(M.disciplines) do
  local text = ("%s: %d"):format(labels[id], M.level(p.disciplines[id], P.config.discipline_base))
  local detail = ("Nivel %d · XP %d/%d"):format(M.level(p.disciplines[id], P.config.discipline_base),
   p.disciplines[id], M.next_xp(p.disciplines[id], P.config.discipline_base))
  fs[#fs+1] = ("label[.65,%s;3.6,.5;%s]"):format(2.95 + (i - 1) * .55, core.formspec_escape(text))
  fs[#fs+1] = ("tooltip[.65,%s;3.6,.5;%s]"):format(2.95 + (i - 1) * .55, core.formspec_escape(detail))
 end
 fs[#fs+1] = "label[.65,6.0;3.6,1.0;1 punto + nivel por rango.]"
 for i, id in ipairs(order) do
  local skill = M.skills[id]
  local y = 1.3 + (i - 1) * 1.4
  fs[#fs+1] = ("button[4.9,%s;5.9,.55;learn_%s;%s %d/%d]"):format(y, id, core.formspec_escape(skill.label), p.skills[id] or 0, skill.max)
  fs[#fs+1] = ("label[5.0,%s;5.7,.75;%s]"):format(y + .62, core.formspec_escape(descriptions[id] or skill.description))
  fs[#fs+1] = ("tooltip[learn_%s;%s]"):format(id, core.formspec_escape(skill.description))
 end
 fs[#fs+1] = "style[guide;font_size=*0.75]"
 fs[#fs+1] = ("button_exit[.5,7.35;4.0,.55;guide;%s]"):format(core.formspec_escape(S("Everforge Guide")))
 fs[#fs+1] = "button_exit[9.0,7.35;2.0,.55;quit;Cerrar]"
 return table.concat(fs)
end

local function show(player)
 if everforge.onboarding and everforge.onboarding.mark_manual_open then
  everforge.onboarding.mark_manual_open(player)
 end
 if everforge._suppress_waila then everforge._suppress_waila(player, form) end
 core.show_formspec(player:get_player_name(), form, "formspec_version[7]size[11.5,8]" .. content(player))
end

everforge.open_progression = show

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

core.register_on_player_receive_fields(function(player, name, fields)
 if name ~= form then return end
 if fields.guide then
  if everforge.onboarding then everforge.onboarding.show_hub(player) end
  return true
 end
 receive(player, fields)
 if not fields.quit then show(player) end
 return true
end)

mcl_inventory.register_survival_inventory_tab({id = "everforge_rpg", description = "Everforge", item_icon = "adamantine:ingot",
 show_inventory = false, build = content, handle = function(player, fields)
 if fields.guide then
  if everforge.onboarding then everforge.onboarding.show_hub(player) end
  return
 end
 if receive(player, fields) then mcl_inventory.update_inventory(player) end
end})
