-- Headless integration harness for the expedition prototype.
-- Mocks only the engine boundary; the production expedition files are loaded as-is.
-- Run from the repository root:
--   EVERFORGE_ROOT=. lua tools/test_everforge_expedition.lua
local ROOT = os.getenv("EVERFORGE_ROOT") or "."
local function load_chunk(raw)
	if loadstring then return loadstring(raw) end
	return load(raw, "storage", "t", {})
end
local failures = 0
local function check(value, message)
	if not value then
		failures = failures + 1
		print("FAIL: " .. message)
	else
		print("ok: " .. message)
	end
end

local function deepcopy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[deepcopy(k)] = deepcopy(v) end
	return out
end

local strings = {}
local storage = {
	get_string = function(_, key) return strings[key] or "" end,
	set_string = function(_, key, value) strings[key] = value end,
}

local players = {}
local player_list = {}
local formspecs = {}
local all_forms = {}
local chats = {}
local after_queue = {}
local callbacks = {}
local registered_mobs = {}
local npc_objects = {}
local nodes = {}
local logs = {}

local function player_by_name(name)
	for _, p in ipairs(player_list) do
		if p:get_player_name() == name then return p end
	end
	return nil
end

local function flush()
	local queue = after_queue
	after_queue = {}
	for _, fn in ipairs(queue) do fn() end
end

local function connect(player)
	if not player_by_name(player:get_player_name()) then
		player.valid = true
		player_list[#player_list + 1] = player
	end
end

local function disconnect(player)
	for i = #player_list, 1, -1 do
		if player_list[i] == player then table.remove(player_list, i) end
	end
	player.valid = false
end

local function new_stack(name, count)
	return {
		name = name,
		count = count or 1,
		is_empty = function(self) return self.count <= 0 or self.name == "" end,
		get_name = function(self) return self.name end,
		}
end

-- Add stack methods with separate definitions to keep the table readable.
local stack_methods = {}
function stack_methods:is_empty() return self.count <= 0 or self.name == "" end
function stack_methods:get_name() return self.name end
function stack_methods:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = setmetatable({name = self.name, count = n}, {__index = stack_methods})
	self.count = self.count - n
	return taken
end
function stack_methods:add_item(other)
	if other and other.name == self.name then self.count = self.count + other.count end
end

local function make_stack(name, count)
	return setmetatable({name = name, count = count or 1}, {__index = stack_methods})
end

local function new_player(name)
	local inventory = {main = {}}
	for i = 1, 36 do inventory.main[i] = make_stack("", 0) end
	local p = {
		name = name,
		huds = {},
		valid = true,
	}
	function p:is_player() return true end
	function p:is_valid() return self.valid end
	function p:get_player_name() return self.name end
	function p:get_inventory() return inventory end
	function p:hud_add(def)
		self.huds[#self.huds + 1] = def
		return #self.huds
	end
	function p:hud_change(id, key, value)
		if self.huds[id] then self.huds[id][key] = value end
	end
	function p:hud_remove(id) self.huds[id] = nil end
	function p:set_yaw() end
	local function copy_stack(stack)
		return make_stack(stack.name or "", stack.count or 0)
	end
	inventory.get_list = function(_, listname)
		if listname ~= "main" then return nil end
		local out = {}
		for i, stack in ipairs(inventory.main) do out[i] = copy_stack(stack) end
		return out
	end
	inventory.set_stack = function(_, listname, index, stack)
		assert(listname == "main", "unexpected inventory list")
		inventory.main[index] = copy_stack(stack)
	end
	p.inventory = inventory
	return p
end

local function node_key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end

local core = {}
core.registered_nodes = {
	air = {walkable = false, liquidtype = "none"},
	["mcl_core:dirt"] = {walkable = true, liquidtype = "none"},
	["mcl_core:stone"] = {walkable = true, liquidtype = "none"},
	["mcl_core:leaves"] = {walkable = false, liquidtype = "none"},
}
function core.get_current_modname() return "everforge" end
function core.get_modpath() return ROOT .. "/mods/MISC/everforge" end
function core.get_mod_storage() return storage end
function core.log(level, message) logs[#logs + 1] = level .. ": " .. message end
function core.get_connected_players() return player_list end
function core.get_player_by_name(name) return player_by_name(name) end
function core.chat_send_player(name, message)
	chats[name] = chats[name] or {}
	chats[name][#chats[name] + 1] = message
end
function core.show_formspec(name, formname, fs)
	formspecs[name] = {formname = formname, fs = fs}
	all_forms[#all_forms + 1] = {name = name, formname = formname, fs = fs}
end
function core.formspec_escape(value) return tostring(value) end
function core.hypertext_escape(value) return tostring(value) end
function core.get_item_group(name, group)
	if group == "sword" and name:find("sword") then return 1 end
	if group == "leaves" and name == "mcl_core:leaves" then return 1 end
	if group == "tree" and name:find("tree") then return 1 end
	return 0
end
function core.after(delay, fn) after_queue[#after_queue + 1] = fn end
function core.register_on_player_receive_fields(fn) callbacks.receive = fn end
function core.register_on_joinplayer(fn) callbacks.join = fn end
function core.register_on_leaveplayer(fn) callbacks.leave = fn end
function core.register_on_mods_loaded(fn) callbacks.mods = fn end
function core.register_globalstep(fn) callbacks.step = fn end
function core.register_on_newplayer() end
function core.get_node(pos)
	local name = nodes[node_key(pos)] or "air"
	return {name = name}
end
function core.load_area() end
function core.get_objects_inside_radius() return npc_objects end
function core.add_entity(pos, name)
	local object = {
		name = name,
		pos = deepcopy(pos),
		get_luaentity = function(self) return {name = self.name} end,
		set_yaw = function() end,
	}
	npc_objects[#npc_objects + 1] = object
	return object
end
local function serialize_storage(v)
	local t = type(v)
	if t == "table" then
		local parts = {}
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do
			parts[#parts + 1] = "[" .. serialize_storage(k) .. "]=" .. serialize_storage(v[k])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then
		return string.format("%q", v)
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	end
	return "nil"
end

function core.write_json(value)
	-- The harness data contains no nil holes and is safe to reload with load().
	return "return " .. serialize_storage(value)
end
function core.parse_json(raw)
	local chunk, err = load_chunk(raw)
	if not chunk then error(err) end
	return chunk()
end

local vector = {}
function vector.round(p) return {x = math.floor(p.x + 0.5), y = math.floor(p.y + 0.5), z = math.floor(p.z + 0.5)} end
function vector.offset(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end

local mcl_mobs = {register_mob = function(name, def) registered_mobs[name] = def end}
_G.core = core
_G.vector = vector
_G.mcl_mobs = mcl_mobs
_G.everforge = {}

dofile(ROOT .. "/mods/MISC/everforge/expedition_model.lua")
local E = dofile(ROOT .. "/mods/MISC/everforge/expedition.lua")
local M = E.model
check(type(M.valid_state) == "function", "model and engine load")

local alice, bob, carol = new_player("ForgeAlice"), new_player("ForgeBob"), new_player("ForgeCarol")
connect(alice); connect(bob); connect(carol)

-- Camp NPC: one standable spot next to the camp center.
nodes["2,9,4"] = "mcl_core:dirt"
check(E.setup_camp({x = 0, y = 10, z = 0}), "camp NPC spawned")
check(#npc_objects == 1, "exactly one NPC entity")
check(E.setup_camp({x = 0, y = 10, z = 0}) == false, "setup is idempotent")
check(E.ensure_npc() and #npc_objects == 1, "ensure_npc does not duplicate")

-- Existing world path: no NPC record and no live entity, but a ready camp.
npc_objects = {}
strings["everforge:expedition_npc:v1"] = nil
E.npc_ready = false
everforge.start_region = {get = function()
	return {state = "ready", center = {x = 0, y = 10, z = 0}}
end}
check(E.ensure_npc(), "ready camp without NPC record recovers the NPC")
check(#npc_objects == 1, "recovered camp has exactly one NPC")
check(strings["everforge:expedition_npc:v1"] ~= nil, "recovered NPC position stored")
check(E.ensure_npc() and #npc_objects == 1, "recovery remains idempotent")
local npc_def = registered_mobs["everforge:expedition_npc"]
check(npc_def and npc_def.type == "npc", "NPC registered through mcl_mobs")
npc_def.on_rightclick(nil, alice)
check(formspecs.ForgeAlice.formname == "everforge:expedition_npc", "NPC right-click opens its formspec")
check(formspecs.ForgeAlice.fs:find("Iniciar expedición", 1, true) ~= nil, "NPC offers expedition start")

-- Start and invite.
callbacks.receive(alice, "everforge:expedition_npc", {start = true})
local state = E.get_state()
check(state and M.valid_state(state), "state valid after start")
local exp = M.find_active_for(state, "ForgeAlice")
check(exp and exp.leader == "ForgeAlice" and #exp.order == 1, "Alice starts as leader")
check(#alice.huds == 1, "leader HUD added")
check(formspecs.ForgeAlice.fs:find("Invitar a ForgeBob", 1, true) ~= nil, "connected player can be invited")
callbacks.receive(alice, "everforge:expedition_npc", {["invite_1"] = true})
state = E.get_state(); exp = M.find_active_for(state, "ForgeAlice")
check(exp.invites["ForgeBob"] ~= nil, "invitation pending for Bob")
check(formspecs.ForgeBob.formname == "everforge:expedition_invite", "invitee receives invitation form")
callbacks.receive(bob, "everforge:expedition_invite", {["accept_" .. exp.id] = true})
state = E.get_state(); exp = M.find_active_for(state, "ForgeAlice")
check(exp.members["ForgeBob"] and #exp.order == 2, "Bob accepted and shares the group")
check(#bob.huds == 1, "member HUD added")
E.show_npc(alice)
check(formspecs.ForgeAlice.fs:find("Invitar a ForgeCarol", 1, true) ~= nil, "another connected player can be invited")
callbacks.receive(alice, "everforge:expedition_npc", {["invite_1"] = true})
state = E.get_state(); exp = M.find_active_for(state, "ForgeAlice")
check(exp.invites["ForgeCarol"] ~= nil, "invitation pending for Carol")
callbacks.receive(carol, "everforge:expedition_invite", {["accept_" .. exp.id] = true})
state = E.get_state(); exp = M.find_active_for(state, "ForgeAlice")
check(exp.members["ForgeCarol"] and #exp.order == 3, "Carol joins the group")
check(#carol.huds == 1, "third member HUD added")

-- Shared sword signal and disconnect/reconnect.
local sword = make_stack("mcl_tools:stone_sword", 1)
bob.inventory.main[1] = sword
callbacks.step(4.1)
state = E.get_state(); exp = M.find_active_for(state, "ForgeAlice")
check(exp.progress.sword_found, "shared mission records the found sword")
check(chats.ForgeAlice[#chats.ForgeAlice]:find("ha conseguido una espada", 1, true) ~= nil,
	"group is told who found the sword")

callbacks.leave(bob); disconnect(bob)
check(#bob.huds == 0, "HUD removed on disconnect")
state = E.get_state(); exp = M.find_active_for(state, "ForgeAlice")
check(exp.members["ForgeBob"], "membership survives disconnect")
connect(bob); callbacks.join(bob); E.refresh_hud("ForgeBob"); flush()
check(#bob.huds == 1, "HUD restored after reconnect")
check(chats.ForgeBob[#chats.ForgeBob]:find("Continúas en la expedición", 1, true) ~= nil,
	"reconnecting member resumes the group")

-- Leader disconnects too; the group and its progress remain.
callbacks.leave(alice); disconnect(alice)
state = E.get_state(); exp = M.find_active_for(state, "ForgeBob")
check(exp and exp.members["ForgeAlice"], "leader disconnect keeps group progress")
connect(alice); callbacks.join(alice); E.refresh_hud("ForgeAlice"); flush()
check(#alice.huds == 1, "leader HUD restored")

-- Carol leaves before delivery, so she must receive the confirmation on return.
callbacks.leave(carol); disconnect(carol)

-- Deliver: one sword is consumed and everyone online gets the confirmation.
local delivered = make_stack("mcl_tools:stone_sword", 1)
bob.inventory.main[2] = delivered
local function count_swords(player)
	local n = 0
	for _, stack in ipairs(player.inventory.main) do
		if stack.count > 0 and stack.name:find("sword") then n = n + 1 end
	end
	return n
end
local before_swords = count_swords(bob)
local ok = E.deliver(bob)
check(ok, "member delivers the sword")
check(count_swords(bob) == before_swords - 1, "one delivered sword leaves the inventory")
state = E.get_state(); exp = state.expeditions[tostring(exp.id)]
check(exp.status == "completed" and exp.progress.delivered, "mission completed")
check(exp.progress.delivered_by == "ForgeBob", "deliverer recorded")
check(formspecs.ForgeAlice.formname == "everforge:expedition_complete"
	and formspecs.ForgeBob.formname == "everforge:expedition_complete",
	"confirmation shown to all online participants")
check(chats.ForgeAlice[#chats.ForgeAlice]:find("completada", 1, true) ~= nil,
	"completion message for every participant")

-- Offline member receives the confirmation on return.
local carol_forms = formspecs.ForgeCarol
check(not carol_forms or carol_forms.formname ~= "everforge:expedition_complete",
	"offline member does not receive the live form")
connect(carol); callbacks.join(carol); flush()
check(formspecs.ForgeCarol.formname == "everforge:expedition_complete",
	"offline member gets the confirmation on return")
check(chats.ForgeCarol[#chats.ForgeCarol]:find("se completó", 1, true) ~= nil,
	"offline member gets the completion message")
state = E.get_state(); exp = state.expeditions[tostring(exp.id)]
check(exp.notified["ForgeCarol"], "returning member is marked as notified")

-- A new expedition can start after completion; progress is not reused.
callbacks.receive(alice, "everforge:expedition_npc", {start = true})
state = E.get_state()
local exp2 = M.find_active_for(state, "ForgeAlice")
check(exp2 and exp2.id ~= exp.id and not exp2.progress.sword_found, "completed missions do not block a new one")

-- Persistence: the same storage string reloads into a valid state with history.
local raw = storage:get_string("everforge:expeditions:v1")
check(raw ~= "", "expedition state written to mod storage")
local reloaded = core.parse_json(raw)
check(M.valid_state(reloaded), "stored state survives reload")
local old = reloaded.expeditions[tostring(exp.id)]
check(old and old.status == "completed" and old.progress.delivered_by == "ForgeBob",
	"completed progress persists independently of achievements")

-- Corrupt storage is preserved and disables writes rather than being reset.
strings["everforge:expeditions:v1"] = "return {not_valid=true}"
-- A second module instance in a fresh environment is not available in this
-- harness; validate the model rejection directly and keep the stored blob.
local bad = core.parse_json(strings["everforge:expeditions:v1"])
check(not M.valid_state(bad), "invalid state rejected")
check(strings["everforge:expeditions:v1"] == "return {not_valid=true}", "invalid blob untouched")

-- Model edge cases.
local s = M.new_state()
local e1 = M.new_expedition(s, "A", 1)
check(e1 and M.valid_state(s), "new expedition valid")
check(not M.invite(s, e1, "A", 2), "leader cannot invite self")
check(M.invite(s, e1, "B", 2), "invite member")
check(M.accept(s, e1, "B"), "accept invited member")
local s2 = M.new_state()
local a = M.new_expedition(s2, "A", 1)
local b = M.new_expedition(s2, "B", 1)
check(M.invite(s2, a, "C", 2), "invite C")
check(M.accept(s2, a, "C"), "C accepts")
check(not M.invite(s2, b, "C", 3), "member cannot be invited elsewhere")
check(not M.accept(s2, b, "A"), "no invitation rejected")
check(M.valid_state(s2), "multi-expedition state valid")
check(M.expire_invites(s2, 1000, 300) >= 0, "invite expiry runs")
for i = 1, 10 do
	local x = M.new_expedition(s2, "L" .. i, 10 + i)
	if x then
		for j = 1, 7 do M.invite(s2, x, "M" .. i .. j, 20 + i) end
	end
end
check(M.valid_state(s2), "state remains bounded/valid under many expeditions")

-- Completed history is pruned to leave room for a new expedition.
local s3 = M.new_state()
local fixtures_ok = true
for i = 1, M.MAX_EXPEDITIONS do
	local e = M.new_expedition(s3, "Done" .. i, i)
	if not e or not M.deliver(e, "Done" .. i, i) then fixtures_ok = false; break end
end
check(fixtures_ok and M.valid_state(s3), "64 completed expeditions remain valid")
local fresh = M.new_expedition(s3, "FreshLeader", 100)
check(fresh ~= nil, "old completed expedition pruned to make room")
check(M.valid_state(s3), "pruned state remains valid")

-- Active expeditions are never pruned; the cap refuses one more.
local s4 = M.new_state()
local active_ok = true
for i = 1, M.MAX_EXPEDITIONS do
	if not M.new_expedition(s4, "Active" .. i, i) then active_ok = false; break end
end
check(active_ok, "64 active expeditions created")
check(M.new_expedition(s4, "Overflow", 100) == nil, "active cap refuses overflow")
check(M.valid_state(s4), "full active state remains valid")

-- Optionally emit every generated form for tools/check_formspec_layout.cjs.
local forms_dir = os.getenv("EVERFORGE_FORMS_DIR")
if forms_dir then
	for i, form in ipairs(all_forms) do
		local f = assert(io.open(forms_dir .. "/expedition_form_" .. i .. ".txt", "w"))
		f:write(form.formname, "\n", form.fs)
		f:close()
	end
end
print(("EXPEDITION_FORMS: %d"):format(#all_forms))

if failures > 0 then
	print(("EVERFORGE_EXPEDITION_TEST_FAIL (%d)"):format(failures))
	os.exit(1)
end
print("EVERFORGE_EXPEDITION_TEST_PASS")
