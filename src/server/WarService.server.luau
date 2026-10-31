--!strict
-- สงครามแก๊ง 4v4: ล้มหัวหน้าฝ่ายตรงข้ามให้ได้ หมดเวลาตัดสินด้วยจำนวนการล้ม
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(script.Parent.Combat)
local GangStore = require(script.Parent.GangStore)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "WarRemote"
remote.Parent = ReplicatedStorage

local TEAM_SIZE = 4
local MATCH_TIME = 300
local WIN_YEN, WIN_FAME, WIN_FUNDS, WIN_GANG_WINS = 100, 30, 200, 5
local ARENA_CENTER = Vector3.new(0, 5, 260)
local SPAWN_HOME = Vector3.new(0, 5, 0)

type Match = {
	Teams: { [string]: { Player } }, -- ชื่อแก๊ง -> สมาชิก
	Leaders: { [string]: Player },
	Kills: { [string]: number },
	Over: boolean,
}

local queue: { [string]: { Player } } = {}
local matches: { Match } = {}
local matchOf: { [Player]: Match } = {}

local function gangOf(player: Player): string?
	local p = PlayerData.Get(player)
	return p and p.Gang ~= "" and p.Gang or nil
end

local function removeFromQueue(player: Player)
	for _, list in queue do
		local i = table.find(list, player)
		if i then
			table.remove(list, i)
		end
	end
end

local function finish(m: Match, winner: string?)
	if m.Over then
		return
	end
	m.Over = true
	for gang, members in m.Teams do
		for _, pl in members do
			matchOf[pl] = nil
			pl:SetAttribute("InWar", false)
			if pl.Character then
				pl.Character:SetAttribute("Team", nil)
				if gang == winner then
					pl.Character:PivotTo(CFrame.new(SPAWN_HOME))
				end
			end
			local p = PlayerData.Get(pl)
			if p and gang == winner then
				p.Yen += WIN_YEN
				p.Fame += WIN_FAME
				pl:SetAttribute("Yen", p.Yen)
			end
		end
	end
	if winner then
		task.spawn(GangStore.AddWins, winner, WIN_GANG_WINS, WIN_FUNDS)
	end
	remote:FireAllClients("Result", winner or "")
end

local function start(a: string, b: string)
	local m: Match = { Teams = {}, Leaders = {}, Kills = { [a] = 0, [b] = 0 }, Over = false }
	for side, gang in { a, b } do
		local members = {}
		for _ = 1, TEAM_SIZE do
			local pl = table.remove(queue[gang], 1)
			if pl then
				table.insert(members, pl)
			end
		end
		m.Teams[gang] = members
		m.Leaders[gang] = members[1]
		local z = if side == 1 then -35 else 35
		for i, pl in members do
			matchOf[pl] = m
			pl:SetAttribute("InWar", true)
			pl:SetAttribute("WarLeader", pl == members[1])
			local char = pl.Character
			if char then
				char:SetAttribute("Team", gang)
				char:PivotTo(CFrame.lookAt(ARENA_CENTER + Vector3.new((i - 2.5) * 8, 0, z), ARENA_CENTER))
			end
		end
	end
	table.insert(matches, m)
	remote:FireAllClients("Start", a, b)
	task.delay(MATCH_TIME, function()
		if m.Over then
			return
		end
		local ka, kb = m.Kills[a], m.Kills[b]
		finish(m, if ka > kb then a elseif kb > ka then b else nil)
	end)
end

local function tryMatch()
	local ready: { string } = {}
	for gang, list in queue do
		if #list >= TEAM_SIZE then
			table.insert(ready, gang)
		end
	end
	if #ready >= 2 then
		start(ready[1], ready[2])
	end
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown)
	local gang = gangOf(player)
	if not gang or matchOf[player] then
		return
	end
	if action == "Queue" then
		removeFromQueue(player)
		queue[gang] = queue[gang] or {}
		table.insert(queue[gang], player)
		player:SetAttribute("WarQueued", true)
		tryMatch()
	elseif action == "Unqueue" then
		removeFromQueue(player)
		player:SetAttribute("WarQueued", false)
	end
end)

Combat.OnKill(function(killer, victim)
	local kp, vp = Players:GetPlayerFromCharacter(killer.Character), Players:GetPlayerFromCharacter(victim.Character)
	local m = vp and matchOf[vp]
	if not m or not kp or m ~= matchOf[kp] then
		return
	end
	local kg = killer.Character:GetAttribute("Team") :: string?
	if kg then
		m.Kills[kg] += 1
	end
	for gang, leader in m.Leaders do
		if leader == vp then
			for other in m.Teams do
				if other ~= gang then
					finish(m, other)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
	local m = matchOf[player]
	if m and not m.Over then
		for gang, leader in m.Leaders do
			if leader == player then -- หัวหน้าหลุด = ฝ่ายนั้นแพ้
				for other in m.Teams do
					if other ~= gang then
						finish(m, other)
					end
				end
			end
		end
	end
	matchOf[player] = nil
end)
