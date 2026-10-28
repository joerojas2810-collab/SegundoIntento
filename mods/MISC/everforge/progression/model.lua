-- SPDX-License-Identifier: GPL-3.0-or-later
-- Pure data model. No engine calls, vanilla XP, classes or migrations.
local M = {}
M.disciplines = {"mining", "forging", "combat", "exploration", "crafting"}
M.skills = {
 deep_miner = {label = "Minería cuidadosa", discipline = "mining", max = 3, description = "Herramientas Everforge: −4% desgaste por rango."},
 forgemaster = {label = "Forjador", discipline = "forging", max = 3, description = "Forja cercana: −1 s por rango (mínimo 3 s)."},
 trailblazer = {label = "Explorador", discipline = "exploration", max = 3, description = "4% más velocidad por rango."},
 guard = {label = "Guardia", discipline = "combat", max = 1, description = "10% menos daño cuerpo a cuerpo de mobs y jugadores."},
}
function M.new()
 local p = {version = 1, mastery = 0, disciplines = {}, spent = 0, skills = {}, seen = {}, explored = {}}
 for _, id in ipairs(M.disciplines) do p.disciplines[id] = 0 end
 return p
end
local function integer(n, max)
 return type(n) == "number" and n == n and n >= 0 and n <= max and n == math.floor(n)
end
function M.valid(p)
 if type(p) ~= "table" or p.version ~= 1 or not integer(p.mastery, 2147483647)
 or not integer(p.spent, 2147483647) then return false end
 for _, key in ipairs({"disciplines", "skills", "seen", "explored"}) do
  if type(p[key]) ~= "table" then return false end
 end
 for _, id in ipairs(M.disciplines) do if not integer(p.disciplines[id], 2147483647) then return false end end
 for id, rank in pairs(p.skills) do if not M.skills[id] or not integer(rank, M.skills[id].max) then return false end end
 if #p.seen > 128 then return false end
 for _, id in ipairs(p.seen) do if type(id) ~= "string" or #id > 160 then return false end end
 local count = 0
 for cell, value in pairs(p.explored) do
  count = count + 1
  if type(cell) ~= "string" or #cell > 80 or value ~= true or count > 4096 then return false end
 end
 return true
end
function M.level(xp, base) return math.floor(math.sqrt(xp / base)) end
function M.next_xp(xp, base) return base * (M.level(xp, base) + 1)^2 end
function M.points(p, cfg) return math.max(0, M.level(p.mastery, cfg.mastery_base) - p.spent) end
function M.grant(p, event, cfg)
 if type(event) ~= "table" or type(event.id) ~= "string" or #event.id == 0 or #event.id > 160 then return false, "invalid event" end
 if event.cell and (type(event.cell) ~= "string" or #event.cell > 80 or event.discipline ~= "exploration") then return false, "invalid cell" end
 local track = event.discipline
 if p.disciplines[track] == nil then return false, "unknown discipline" end
 for _, id in ipairs(p.seen) do if id == event.id then return false, "duplicate" end end
 local amount = cfg.rates[track]
 if not integer(amount, 10000) or amount == 0 then return false, "disabled activity" end
 if event.cell then
  if p.explored[event.cell] then return false, "visited" end
  local count = 0
  for _ in pairs(p.explored) do count = count + 1 end
  if count >= 4096 then return false, "exploration capacity" end
  p.explored[event.cell] = true
 end
 p.mastery = math.min(2147483647, p.mastery + amount)
 p.disciplines[track] = math.min(2147483647, p.disciplines[track] + amount)
 p.seen[#p.seen + 1] = event.id
 if #p.seen > 128 then table.remove(p.seen, 1) end
 return true
end
function M.buy(p, id, cfg)
 local skill = M.skills[id]
 if not skill then return false, "Habilidad desconocida" end
 local rank = p.skills[id] or 0
 if rank >= skill.max then return false, "Rango máximo" end
 if M.points(p, cfg) < 1 then return false, "Necesitas un punto de Dominio" end
 if M.level(p.disciplines[skill.discipline], cfg.discipline_base) < rank + 1 then
  return false, "Necesitas nivel " .. (rank + 1) .. " de la disciplina"
 end
 p.skills[id] = rank + 1
 p.spent = p.spent + 1
 return true, "Habilidad aprendida"
end
return M
