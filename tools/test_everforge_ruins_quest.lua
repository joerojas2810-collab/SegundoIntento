-- Headless test for the ruins adventure. Mocks only the engine boundary.
-- Run from the repository root with tools/run_lua_test.py.
local ROOT = os.getenv("EVERFORGE_ROOT") or "."
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
local chats = {}
local after_queue = {}
local callbacks = {}
local nodes = {}
local node_meta = {}
local entities = {}
local registered_nodes = {}
local globalstep
local receive_fields
local join_callbacks = {}
local leave_callbacks = {}
local logs = {}

local stack_methods = {}
function stack_methods:is_empty() return self.count <= 0 or self.name == "" end
function stack_methods:get_name() return self.name end
function stack_methods:get_count() return self.count end
function stack_methods:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = setmetatable({name = self.name, count = n}, {__index = stack_methods})
	self.count = self.count - n
	return taken
end
function stack_methods:add_item(other)
	if other and other.name == self.name then self.count = self.count + other.count end
end

function ItemStack(value)
	local name, count = tostring(value or ""):match("^(%S+)%s*(%d*)")
	if name == nil then name = "" end
	return setmetatable({name = name, count = tonumber(count) or 1}, {__index = stack_methods})
end

local function copy_stack(stack)
	return setmetatable({name = stack.name or "", count = stack.count or 0}, {__index = stack_methods})
end

local function new_inventory()
	local inventory = {main = {}}
	for i = 1, 36 do inventory.main[i] = copy_stack({name = "", count = 0}) end
	function inventory:get_size(list) return list == "main" and 36 or 0 end
	function inventory:set_size() end
	function inventory:get_stack(list, i) return copy_stack(inventory.main[i]) end
	function inventory:set_stack(list, i, stack) inventory.main[i] = copy_stack(stack) end
	function inventory:add_item(list, stack)
		local remaining = stack.count
		for i = 1, 36 do
			local slot = inventory.main[i]
			if slot.name == stack.name and slot.count < 64 then
				local add = math.min(64 - slot.count, remaining)
				slot.count = slot.count + add
				remaining = remaining - add
				if remaining == 0 then return ItemStack("") end
			end
		end
		for i = 1, 36 do
			if inventory.main[i].count == 0 then
				inventory.main[i] = copy_stack({name = stack.name, count = remaining})
				return ItemStack("")
			end
		end
		return ItemStack(stack.name .. " " .. remaining)
	end
	function inventory:room_for_item(_, stack)
		for i = 1, 36 do
			local slot = inventory.main[i]
			if slot.count == 0 or (slot.name == stack.name and slot.count < 64) then return true end
		end
		return false
	end
	function inventory:count_item(item)
		local n = 0
		for i = 1, 36 do if inventory.main[i].name == item then n = n + inventory.main[i].count end end
		return n
	end
	return inventory
end

local function new_player(name)
	local p = {name = name, huds = {}, valid = true, inventory = new_inventory()}
	function p:is_player() return true end
	function p:is_valid() return self.valid end
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inventory end
	function p:get_pos() return self.pos or {x = 0, y = 20, z = 0} end
	function p:set_pos(pos) self.pos = deepcopy(pos) end
	function p:set_look_horizontal() end
	function p:hud_add(def) self.huds[#self.huds + 1] = def; return #self.huds end
	function p:hud_change(id, key, value) if self.huds[id] then self.huds[id][key] = value end end
	function p:hud_remove(id) self.huds[id] = nil end
	function p:get_meta() return {get_int = function() return 0 end, set_int = function() end,
		get_string = function() return "" end, set_string = function() end} end
	p.pos = {x = 0, y = 20, z = 0}
	return p
end

local function connect(p)
	if not player_list[p] then player_list[#player_list + 1] = p end
	players[p:get_player_name()] = p
	p.valid = true
end

local function disconnect(p)
	for i = #player_list, 1, -1 do if player_list[i] == p then table.remove(player_list, i) end end
	p.valid = false
end

local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end

local function get_node(pos)
	local item = nodes[key(pos)]
	return {name = item and item.name or "air", param2 = item and item.param2 or 0}
end

local function get_meta(pos)
	local k = key(pos)
	if not node_meta[k] then
		local inv = new_inventory()
		node_meta[k] = {
			data = {},
			inventory = inv,
			get_int = function(self, name) return self.data[name] or 0 end,
			set_int = function(self, name, value) self.data[name] = value end,
			get_string = function(self, name) return self.data[name] or "" end,
			set_string = function(self, name, value) self.data[name] = value end,
			get_inventory = function(self) return self.inventory end,
		}
	end
	return node_meta[k]
end

local function set_node(pos, node) nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0} end

local core = {
	registered_nodes = registered_nodes,
	registered_items = {},
}
function core.get_current_modname() return "everforge" end
function core.get_modpath(name) if name == "everforge" then return ROOT .. "/mods/MISC/everforge" end return ROOT .. "/mods/" .. name end
function core.get_mod_storage() return storage end
function core.log(level, message) logs[#logs + 1] = level .. ": " .. message end
function core.get_connected_players() return player_list end
function core.get_player_by_name(name) return players[name] end
function core.chat_send_player(name, message)
	chats[name] = chats[name] or {}
	chats[name][#chats[name] + 1] = message
end
function core.show_formspec(name, formname, fs) formspecs[name] = {formname = formname, fs = fs} end
function core.formspec_escape(value) return tostring(value) end
function core.hypertext_escape(value) return tostring(value) end
function core.get_item_group(name, group)
	if group == "sword" and name:find("sword") then return 1 end
	return 0
end
function core.after(delay, fn) after_queue[#after_queue + 1] = fn end
function core.register_on_player_receive_fields(fn) receive_fields = fn end
function core.register_on_joinplayer(fn) join_callbacks[#join_callbacks + 1] = fn end
function core.register_on_leaveplayer(fn) leave_callbacks[#leave_callbacks + 1] = fn end
function core.register_on_newplayer() end
function core.register_on_mods_loaded(fn) end
function core.register_globalstep(fn) globalstep = fn end
function core.register_chatcommand() end
function core.get_node(pos) return get_node(pos) end
function core.set_node(pos, node)
	set_node(pos, node)
	local def = registered_nodes[node.name]
	if def and def.on_construct then pcall(def.on_construct, pos) end
end
function core.get_meta(pos) return get_meta(pos) end
function core.load_area() end
function core.find_nodes_in_area() return {} end
function core.get_objects_inside_radius() return entities end
function core.add_entity(pos, name)
	local object = {name = name, pos = deepcopy(pos)}
	function object:get_luaentity() return {name = name, persistent = false} end
	function object:get_pos() return self.pos end
	entities[#entities + 1] = object
	return object
end
function core.add_item(pos, stack)
	entities[#entities + 1] = {name = stack.name, pos = pos, item = true}
end
function core.register_node(name, def)
	registered_nodes[name] = def
	registered_nodes[name].name = name
end
function core.register_craftitem(name, def)
	registered_nodes[name] = def
end

local function serialize(v)
	local t = type(v)
	if t == "table" then
		local parts, keys = {}, {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do
			parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(v[k])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then
		return string.format("%q", v)
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	end
	return "nil"
end
function core.write_json(value) return "return " .. serialize(value) end
local function decode_json(raw)
	local i = 1
	local function skip()
		while i <= #raw and raw:sub(i, i):match("%s") do i = i + 1 end
	end
	local parse_value
	local function parse_string()
		i = i + 1
		local out = {}
		while i <= #raw do
			local c = raw:sub(i, i)
			if c == '"' then i = i + 1; return table.concat(out) end
			if c == "\\" then
				local n = raw:sub(i + 1, i + 1)
				local map = {n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/"}
				out[#out + 1] = map[n] or n
				i = i + 2
			else
				out[#out + 1] = c
				i = i + 1
			end
		end
		error("unterminated JSON string")
	end
	local function parse_number()
		local start = i
		while i <= #raw and raw:sub(i, i):match("[%d%.eE%+%-]") do i = i + 1 end
		return tonumber(raw:sub(start, i - 1))
	end
	parse_value = function()
		skip()
		local c = raw:sub(i, i)
		if c == "{" then
			i = i + 1
			local out = {}
			skip()
			if raw:sub(i, i) == "}" then i = i + 1; return out end
			while true do
				skip()
				local key = parse_string()
				skip(); assert(raw:sub(i, i) == ":"); i = i + 1
				out[key] = parse_value()
				skip()
				local sep = raw:sub(i, i); i = i + 1
				if sep == "}" then return out end
				assert(sep == ",")
			end
		elseif c == "[" then
			i = i + 1
			local out = {}
			skip()
			if raw:sub(i, i) == "]" then i = i + 1; return out end
			while true do
				out[#out + 1] = parse_value()
				skip()
				local sep = raw:sub(i, i); i = i + 1
				if sep == "]" then return out end
				assert(sep == ",")
			end
		elseif c == '"' then
			return parse_string()
		elseif raw:sub(i, i + 3) == "true" then i = i + 4; return true
		elseif raw:sub(i, i + 4) == "false" then i = i + 5; return false
		elseif raw:sub(i, i + 3) == "null" then i = i + 4; return nil
		else return parse_number() end
	end
	return parse_value()
end

function core.parse_json(raw)
	if raw:match("^%s*[{[]") then return decode_json(raw) end
	local chunk, err = load(raw, "storage", "t", {})
	if not chunk then error(err) end
	return chunk()
end

local vector = {}
function vector.distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

registered_nodes["air"] = {walkable = false, liquidtype = "none"}
registered_nodes["mcl_core:stonebrick"] = {walkable = true, liquidtype = "none"}
registered_nodes["mcl_core:dirt_with_grass"] = {walkable = true, liquidtype = "none"}
registered_nodes["mcl_chests:chest_small"] = {
	walkable = false,
	on_construct = function(pos)
		local meta = get_meta(pos)
		meta:get_inventory():set_size("main", 16)
	end,
}

_G.core = core
_G.vector = vector
_G.ItemStack = ItemStack
_G.everforge = {
	expedition = {
		has_sword = function(player)
			local inv = player:get_inventory()
			for i = 1, inv:get_size("main") do
				if core.get_item_group(inv:get_stack("main", i):get_name(), "sword") > 0 then return true end
			end
			return false
		end,
		ensure_npc = function() return true end,
		setup_camp = function() return true end,
	},
}

local Q = dofile(ROOT .. "/mods/MISC/everforge/ruins_quest.lua")
check(type(Q) == "table", "ruins quest module loads")
check(type(globalstep) == "function", "director globalstep registered")

local alice, bob = new_player("RuinaAlice"), new_player("RuinaBob")
connect(alice); connect(bob)

-- Site anchors are synthetic but use the real manifest offsets.
Q.arm_site({
	anchor = {x = 0, y = 0, z = 0},
	trailhead = {x = 0, y = 20, z = -5},
	camp = {x = 0, y = 20, z = 10},
	camp_stone = {x = 2, y = 20, z = 10},
	camp_chest = {x = 3, y = 20, z = 10},
	trail_stone = {x = 0, y = 21, z = -5},
	camp_center = {x = 0, y = 20, z = 10},
})
set_node({x = 0, y = 19, z = -5}, {name = "mcl_core:stonebrick"})
set_node({x = 0, y = 19, z = 10}, {name = "mcl_core:stonebrick"})
set_node({x = 0, y = 20, z = -5}, {name = "air"})
set_node({x = 0, y = 21, z = -5}, {name = "air"})
set_node({x = 0, y = 20, z = 10}, {name = "air"})
set_node({x = 0, y = 21, z = 10}, {name = "air"})
-- Solid crypt floors under the manifest encounter points.
for _, p in ipairs({
	{28, 9, 29}, {32, 9, 33}, {30, 9, 32},
	{24, 9, 40}, {36, 9, 40}, {30, 9, 43},
	{26, 10, 50}, {34, 10, 50}, {30, 9, 47},
}) do
	set_node({x = p[1], y = p[2] - 1, z = p[3]}, {name = "mcl_core:stonebrick"})
end
Q.setup_site()
Q.setup_camp({x = 0, y = 20, z = 10})
check(Q.is_armed(), "site is armed after setup")
check(get_node({x = 30, y = 10, z = 52}).name == "everforge:ruin_pedestal", "pedestal base placed from manifest")
check(get_node({x = 30, y = 11, z = 52}).name == "everforge:ruin_pedestal_top", "pedestal seal placed")

check(Q.start(alice), "leader starts the adventure")
check(alice.inventory:count_item("mcl_tools:sword_stone") == 1, "leader receives a stone sword when unarmed")
check(Q.invite(alice, "RuinaBob"), "leader invites Bob")
check(formspecs.RuinaBob and formspecs.RuinaBob.formname == "everforge:ruins_invite", "invitee receives the invitation form")
check(Q.accept(bob, 1), "Bob accepts")
check(formspecs.RuinaAlice.fs:find("RuinaBob", 1, true) ~= nil, "party form lists the new member")

check(Q.travel(alice, "camp"), "camp waystone travels to the trailhead")
check(alice:get_pos().z == -5, "player landed at the trailhead")
check(chats.RuinaAlice[#chats.RuinaAlice]:find("sendero", 1, true) ~= nil, "travel message explains the trail")

alice:set_pos({x = 30, y = 9, z = 31})
globalstep(1.1)
check(#entities == 2, "two-player party spawns two controlled mobs once")
local first_encounter_count = #entities
globalstep(1.1)
check(#entities == first_encounter_count, "re-entering a triggered room does not respawn enemies")

alice:set_pos({x = 30, y = 9, z = 40})
globalstep(1.1)
check(#entities == first_encounter_count + 2, "hall encounter adds two more controlled mobs")
alice:set_pos({x = 30, y = 9, z = 47})
globalstep(1.1)
check(#entities == first_encounter_count + 5, "seal chamber encounter adds the final three mobs")
local all_encounters = #entities
globalstep(1.1)
check(#entities == all_encounters, "the three encounters never respawn")

alice:set_pos({x = 30, y = 10, z = 51})
local pedestal = registered_nodes["everforge:ruin_pedestal_top"]
pedestal.on_rightclick({x = 30, y = 11, z = 52}, {}, alice)
check(alice.inventory:count_item("everforge:ruin_sigil") == 1, "pedestal grants exactly one sigil")
check(get_node({x = 30, y = 11, z = 52}).name == "everforge:ruin_pedestal_empty", "pedestal is visibly emptied")
pedestal.on_rightclick({x = 30, y = 11, z = 52}, {}, alice)
check(alice.inventory:count_item("everforge:ruin_sigil") == 1, "second pedestal click does not duplicate the sigil")

disconnect(bob)
check(Q.deliver(alice), "carrier delivers the sigil")
check(alice.inventory:count_item("everforge:ruin_sigil") == 0, "delivery consumes the sigil")
check(alice.inventory:count_item("mcl_core:iron_ingot") == 8, "leader receives the one-time reward")
check(alice.inventory:count_item("mcl_farming:bread") >= 6, "leader receives bread")
check(not Q.deliver(alice), "a completed expedition cannot be delivered twice")
check(alice.inventory:count_item("mcl_core:iron_ingot") == 8, "failed second delivery grants no extra reward")

-- Bob was offline at completion. Reconnect and run the login path.
connect(bob)
for _, fn in ipairs(join_callbacks) do fn(bob) end
-- The module schedules the join handling with core.after(1).
for _, fn in ipairs(after_queue) do fn() end
check(bob.inventory:count_item("mcl_core:iron_ingot") == 8, "offline member receives the reward on reconnect")
check(bob.inventory:count_item("everforge:ruin_sigil") == 0, "offline member never receives a second sigil")

local raw = strings["everforge:ruins_quest:v1"]
check(type(raw) == "string" and raw:find("done", 1, true) ~= nil, "completed state is persisted")
local stored = core.parse_json(raw)
check(stored.party and stored.party.sigil_delivered == true, "stored state records the delivery")
check(raw:find("sigil_delivered", 1, true) ~= nil, "persistence includes the anti-duplication flag")

-- A malformed record must be preserved, not reset.
strings["everforge:ruins_quest:v1"] = "not json"
local Q2 = dofile(ROOT .. "/mods/MISC/everforge/ruins_quest.lua")
check(Q2 ~= nil, "module survives a corrupt record without throwing")
check(strings["everforge:ruins_quest:v1"] == "not json", "corrupt record is preserved")

print(failures == 0 and "EVERFORGE_RUINS_TEST_PASS" or ("FAILURES: " .. failures))
