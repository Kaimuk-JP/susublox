--!strict
-- เควสรายวัน/รายสัปดาห์ และรางวัลล็อกอินต่อเนื่อง 7 วัน
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local QuestData = require(ReplicatedStorage.Shared.Quests)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "QuestRemote"
remote.Parent = ReplicatedStorage

local function allQuests(): { QuestData.Quest }
	local list = {}
	for _, q in QuestData.Daily do
		table.insert(list, q)
	end
	for _, q in QuestData.Weekly do
		table.insert(list, q)
	end
	return list
end

-- รีเซ็ตเควสเมื่อพ้นรอบ (เช็กตอนล็อกอินและก่อนนับความคืบหน้า)
local function refresh(player: Player)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	local now = os.time()
	local q = p.Quests
	if now - q.DailyReset >= QuestData.DayLength then
		for _, d in QuestData.Daily do
			q.Progress[d.Id], q.Claimed[d.Id] = nil, nil
		end
		q.DailyReset = now - now % QuestData.DayLength
	end
	if now - q.WeeklyReset >= QuestData.WeekLength then
		for _, w in QuestData.Weekly do
			q.Progress[w.Id], q.Claimed[w.Id] = nil, nil
		end
		q.WeeklyReset = now - now % QuestData.WeekLength
	end
end

local function publish(player: Player)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	for _, quest in allQuests() do
		player:SetAttribute("Q_" .. quest.Id, p.Quests.Progress[quest.Id] or 0)
	end
	player:SetAttribute("LoginStreak", p.Login.Streak)
end

local function progress(player: Player, event: string, amount: number)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	refresh(player)
	for _, quest in allQuests() do
		if quest.Event == event then
			p.Quests.Progress[quest.Id] = math.min(quest.Goal, (p.Quests.Progress[quest.Id] or 0) + amount)
		end
	end
	publish(player)
end

local function playerOf(s: any): Player?
	return Players:GetPlayerFromCharacter(s.Character)
end

Combat.OnHit(function(attacker)
	local pl = playerOf(attacker)
	if pl then
		progress(pl, "Hit", 1)
	end
end)

Combat.OnKill(function(killer, victim)
	local pl = playerOf(killer)
	if not pl then
		return
	end
	progress(pl, "Win", 1)
	if playerOf(victim) then
		progress(pl, "PvpWin", 1)
	end
	if victim.IsBoss then
		progress(pl, "BossKill", 1)
	end
end)

Combat.OnEvent(function(name, s)
	local pl = playerOf(s)
	if pl and name == "Ultimate" then
		progress(pl, "Ultimate", 1)
	end
end)

-- ล็อกอินต่อเนื่อง: วันถัดไปนับต่อ, ข้ามวันรีเซ็ต
local function loginReward(player: Player)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	local today = os.time() // QuestData.DayLength
	local last = p.Login.Last
	if last == today then
		return
	end
	p.Login.Streak = if last == today - 1 then p.Login.Streak % 7 + 1 else 1
	p.Login.Last = today
	p.Yen += QuestData.LoginYen[p.Login.Streak]
end

local function setup(player: Player)
	-- รอข้อมูลโหลด (ProgressService เป็นคนโหลด)
	for _ = 1, 100 do
		if PlayerData.Get(player) then
			break
		end
		task.wait(0.2)
	end
	refresh(player)
	loginReward(player)
	publish(player)
end
Players.PlayerAdded:Connect(setup)
for _, pl in Players:GetPlayers() do
	task.spawn(setup, pl)
end

-- รับรางวัลเควสที่ทำครบ
remote.OnServerEvent:Connect(function(player: Player, id: unknown)
	local p = PlayerData.Get(player)
	if not p or typeof(id) ~= "string" then
		return
	end
	refresh(player)
	for _, quest in allQuests() do
		if
			quest.Id == id
			and (p.Quests.Progress[id] or 0) >= quest.Goal
			and not p.Quests.Claimed[id]
		then
			p.Quests.Claimed[id] = true
			p.Yen += quest.Yen
			local level, exp, points = Progression.AddExp(p.Level, p.Exp, quest.Exp, p.Prestige)
			p.Level, p.Exp = level, exp
			p.StatPoints += points
			player:SetAttribute("Yen", p.Yen)
			player:SetAttribute("Level", p.Level)
			player:SetAttribute("Exp", math.floor(p.Exp))
			player:SetAttribute("StatPoints", p.StatPoints)
			return
		end
	end
end)
