-- SPDX-License-Identifier: GPL-3.0-or-later
-- Pure expedition state model. No engine calls: every transition is testable.
local M = {}

M.VERSION = 1
M.MAX_EXPEDITIONS = 64
M.MAX_MEMBERS = 8
M.MAX_INVITES = 8
M.MISSION = "sword_delivery"

local function valid_name(name)
	return type(name) == "string" and #name >= 1 and #name <= 64
		and not name:find("[%z\1-\31]")
end

local function count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

local function integer(n, low, high)
	return type(n) == "number" and n == n and n == math.floor(n)
		and n >= low and n <= high
end

M.valid_name = valid_name

function M.new_state()
	return {version = M.VERSION, next_id = 1, expeditions = {}}
end

function M.new_expedition(state, leader, now)
	if type(state) ~= "table" or type(state.expeditions) ~= "table"
		or not valid_name(leader) or type(now) ~= "number" then
		return nil
	end
	if M.find_active_for(state, leader) then return nil end
	M.prune(state)
	if count(state.expeditions) >= M.MAX_EXPEDITIONS then return nil end
	local id = state.next_id
	if not integer(id, 1, 2147483646) then return nil end
	state.next_id = id + 1
	local exp = {
		id = id,
		leader = leader,
		status = "active",
		created_at = now,
		members = {[leader] = true},
		order = {leader},
		invites = {},
		progress = {sword_found = false, delivered = false},
		notified = {},
	}
	state.expeditions[tostring(id)] = exp
	M.prune(state)
	return exp
end

local function valid_expedition(key, exp)
	if type(exp) ~= "table" or type(key) ~= "string" then return false end
	if not integer(exp.id, 1, 2147483646) or tostring(exp.id) ~= key then return false end
	if not valid_name(exp.leader) then return false end
	if exp.status ~= "active" and exp.status ~= "completed" then return false end
	if type(exp.created_at) ~= "number" or exp.created_at < 0 then return false end
	if exp.completed_at ~= nil and (type(exp.completed_at) ~= "number" or exp.completed_at < 0) then
		return false
	end
	if type(exp.members) ~= "table" or type(exp.order) ~= "table"
		or type(exp.invites) ~= "table" or type(exp.progress) ~= "table"
		or type(exp.notified) ~= "table" then
		return false
	end
	if #exp.order < 1 or #exp.order > M.MAX_MEMBERS then return false end
	if count(exp.members) ~= #exp.order then return false end
	local seen = {}
	for _, name in ipairs(exp.order) do
		if not valid_name(name) or seen[name] or exp.members[name] ~= true then return false end
		seen[name] = true
	end
	if not exp.members[exp.leader] then return false end
	if count(exp.invites) > M.MAX_INVITES then return false end
	for name, invite in pairs(exp.invites) do
		if not valid_name(name) or seen[name] or type(invite) ~= "table"
			or not valid_name(invite.invited_by) or type(invite.at) ~= "number" then
			return false
		end
	end
	if type(exp.progress.sword_found) ~= "boolean"
		or type(exp.progress.delivered) ~= "boolean" then
		return false
	end
	if exp.progress.delivered_by ~= nil
		and (not valid_name(exp.progress.delivered_by)
			or exp.members[exp.progress.delivered_by] ~= true) then
		return false
	end
	if count(exp.notified) > M.MAX_MEMBERS then return false end
	for name, value in pairs(exp.notified) do
		if not valid_name(name) or exp.members[name] ~= true or value ~= true then return false end
	end
	if exp.status == "completed" then
		if exp.completed_at == nil or not exp.progress.delivered
			or exp.progress.delivered_by == nil then
			return false
		end
	else
		if exp.completed_at ~= nil or exp.progress.delivered
			or exp.progress.delivered_by ~= nil then
			return false
		end
	end
	return true
end

function M.valid_state(state)
	if type(state) ~= "table" or state.version ~= M.VERSION then return false end
	if not integer(state.next_id, 1, 2147483647) then return false end
	if type(state.expeditions) ~= "table" then return false end
	if count(state.expeditions) > M.MAX_EXPEDITIONS then return false end
	local active_members = {}
	for key, exp in pairs(state.expeditions) do
		if not valid_expedition(key, exp) then return false end
		if exp.status == "active" then
			for _, name in ipairs(exp.order) do
				if active_members[name] then return false end
				active_members[name] = true
			end
		end
	end
	return true
end

function M.active_count(state)
	local n = 0
	for _, exp in pairs(state.expeditions or {}) do
		if exp.status == "active" then n = n + 1 end
	end
	return n
end

function M.find_active_for(state, name)
	if type(state) ~= "table" or not valid_name(name) then return nil end
	for _, exp in pairs(state.expeditions or {}) do
		if exp.status == "active" and exp.members[name] then return exp end
	end
	return nil
end

function M.find_by_leader(state, name)
	if type(state) ~= "table" or not valid_name(name) then return nil end
	for _, exp in pairs(state.expeditions or {}) do
		if exp.status == "active" and exp.leader == name then return exp end
	end
	return nil
end

function M.pending_invite(state, name, now, ttl)
	if type(state) ~= "table" or not valid_name(name) then return nil end
	for _, exp in pairs(state.expeditions or {}) do
		local invite = exp.status == "active" and exp.invites[name]
		if invite and type(now) == "number"
			and now - invite.at >= 0 and now - invite.at <= ttl then
			return exp, invite
		end
	end
	return nil
end

function M.invite(state, exp, name, now)
	if type(exp) ~= "table" or exp.status ~= "active" then return false, "inactive" end
	if not valid_name(name) or name == exp.leader then return false, "invalid player" end
	if exp.members[name] then return false, "already member" end
	if M.find_active_for(state, name) then return false, "busy" end
	if exp.invites[name] then return false, "already invited" end
	if #exp.order >= M.MAX_MEMBERS then return false, "full" end
	if count(exp.invites) >= M.MAX_INVITES then return false, "too many invitations" end
	exp.invites[name] = {invited_by = exp.leader, at = now}
	return true
end

function M.accept(state, exp, name)
	if type(exp) ~= "table" or exp.status ~= "active" then return false, "inactive" end
	if not valid_name(name) or not exp.invites[name] then return false, "no invitation" end
	if exp.members[name] then return false, "already member" end
	if M.find_active_for(state, name) then return false, "busy" end
	if #exp.order >= M.MAX_MEMBERS then return false, "full" end
	exp.invites[name] = nil
	exp.members[name] = true
	exp.order[#exp.order + 1] = name
	return true
end

function M.decline(exp, name)
	if type(exp) ~= "table" or not exp.invites[name] then return false, "no invitation" end
	exp.invites[name] = nil
	return true
end

function M.mark_sword_found(exp)
	if type(exp) ~= "table" or exp.status ~= "active" then return false end
	if exp.progress.sword_found then return false end
	exp.progress.sword_found = true
	return true
end

function M.deliver(exp, name, now)
	if type(exp) ~= "table" or exp.status ~= "active" then return false, "inactive" end
	if not valid_name(name) or not exp.members[name] then return false, "not a member" end
	if exp.progress.delivered then return false, "already delivered" end
	exp.progress.sword_found = true
	exp.progress.delivered = true
	exp.progress.delivered_by = name
	exp.status = "completed"
	exp.completed_at = now
	exp.invites = {}
	exp.notified = {}
	return true
end

function M.needs_notice(exp, name)
	return type(exp) == "table" and exp.status == "completed"
		and exp.members[name] == true and exp.notified[name] ~= true
end

function M.mark_notified(exp, name)
	if type(exp) ~= "table" or exp.members[name] ~= true then return false end
	exp.notified[name] = true
	return true
end

function M.expire_invites(state, now, ttl)
	local removed = 0
	for _, exp in pairs((state and state.expeditions) or {}) do
		for name, invite in pairs(exp.invites) do
			if type(invite.at) ~= "number" or now - invite.at > ttl then
				exp.invites[name] = nil
				removed = removed + 1
			end
		end
	end
	return removed
end

-- Keep the most recent completed expeditions; active ones are never pruned.
-- Called on creation so the stored table remains bounded without a sweep.
function M.prune(state)
	local total = count(state.expeditions)
	if total < M.MAX_EXPEDITIONS then return 0 end
	local completed = {}
	for key, exp in pairs(state.expeditions) do
		if exp.status == "completed" then
			completed[#completed + 1] = {key = key, at = exp.completed_at or 0, id = exp.id}
		end
	end
	table.sort(completed, function(a, b)
		if a.at ~= b.at then return a.at < b.at end
		return a.id < b.id
	end)
	local removed = 0
	for _, entry in ipairs(completed) do
		if total - removed < M.MAX_EXPEDITIONS then break end
		state.expeditions[entry.key] = nil
		removed = removed + 1
	end
	return removed
end

return M
