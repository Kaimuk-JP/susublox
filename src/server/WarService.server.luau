--!strict
-- สงครามแก๊ง 4v4: ล้มหัวหน้าฝ่ายตรงข้ามให้ได้ หมดเวลาตัดสินด้วยจำนวนการล้ม
-- แมตช์ใช้สนาม instance แยก (ArenaManager) ธีมสุ่ม จบแล้วทุกคนถูกส่งกลับลานหน้าสนามประลอง
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.ArenaManager)
local Combat = require(script.Parent.Combat)
local GangStore = require(script.Parent.GangStore)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "WarRemote"
remote.Parent = ReplicatedStorage
local worldRemote = ReplicatedStorage:WaitForChild("WorldRemote") :: RemoteEvent

local TEAM_SIZE = 4
local MATCH_TIME = 300
local RETURN_DELAY = 6
local WIN_YEN, WIN_FAME, WIN_FUNDS, WIN_GANG_WINS = 100, 30, 200, 5

type Match = {
	Teams: { [string]: { Player } }, -- ชื่อแก๊ง -> สมาชิก
	Leaders: { [string]: Player },
	Kills: { [string]: number },
	Names: { string },
	Inst: Arena.Inst,
	StartAt: number,
	Over: boolean,
}

local queue: { [string]: { Player } } = {}
local matchOf: { [Player]: Match } = {}
local forming = false

local function gangOf(player: Player): string?
	local p = PlayerData.Get(player)
	return p and p.Gang ~= "" and p.Gang or nil
end

local function publishQueue()
	local gangs, players = 0, 0
	for _, list in queue do
		if #list > 0 then
			gangs += 1
			players += #list
		end
	end
	workspace:SetAttribute("WarQueueGangs", gangs)
	workspace:SetAttribute("WarQueuePlayers", players)
end

local function removeFromQueue(player: Player)
	for _, list in queue do
		local i = table.find(list, player)
		if i then
			table.remove(list, i)
		end
	end
	player:SetAttribute("WarQueued", false)
	publishQueue()
end

local function toastAll(text: string)
	worldRemote:FireAllClients("Toast", text)
end

local function scoreText(m: Match): string
	local a, b = m.Names[1], m.Names[2]
	local left = math.max(0, MATCH_TIME - (os.clock() - m.StartAt))
	return `<b>สงครามแก๊ง 4v4</b>\n<font color="#FF8A80">{a}</font> {m.Kills[a]} : {m.Kills[b]} <font color="#82B1FF">{b}</font>\nเหลือเวลา {math.floor(left / 60)}:{string.format("%02d", math.floor(left) % 60)}`
end

local function finish(m: Match, winner: string?)
	if m.Over then
		return
	end
	m.Over = true
	for gang, members in m.Teams do
		for _, pl in members do
			if matchOf[pl] == m then
				matchOf[pl] = nil
			end
			pl:SetAttribute("InWar", false)
			pl:SetAttribute("WarLeader", false)
			local p = PlayerData.Get(pl)
			if p and gang == winner and Arena.Of(pl) == m.Inst then
				p.Yen += WIN_YEN
				p.Fame += WIN_FAME
				pl:SetAttribute("Yen", p.Yen)
			end
		end
	end
	Arena.EndFight(m.Inst)
	if winner then
		task.spawn(GangStore.AddWins, winner, WIN_GANG_WINS, WIN_FUNDS)
	end
	local text = if winner then `แก๊ง {winner} ชนะสงครามแก๊ง! (+¥{WIN_YEN} +{WIN_FAME} ชื่อเสียงให้ผู้ชนะ)` else "สงครามแก๊งจบแบบเสมอ"
	toastAll(text)
	Arena.SetScore(m.Inst, `<b>{text}</b>`)
	remote:FireAllClients("Result", winner or "")
	task.delay(RETURN_DELAY, function()
		Arena.Destroy(m.Inst)
	end)
end

-- หัวหน้าทีมหาย (ตาย/ออก) = ทีมนั้นแพ้
local function leaderDown(m: Match, gang: string)
	for other in m.Teams do
		if other ~= gang then
			finish(m, other)
			return
		end
	end
end

local function memberGone(m: Match, pl: Player)
	if m.Over then
		return
	end
	for gang, leader in m.Leaders do
		if leader == pl then
			leaderDown(m, gang)
			return
		end
	end
	for gang, members in m.Teams do
		local i = table.find(members, pl)
		if i then
			local anyLeft = false
			for _, other in members do
				if other ~= pl and other.Parent and Arena.Of(other) == m.Inst then
					anyLeft = true
				end
			end
			if not anyLeft then
				leaderDown(m, gang)
			end
		end
	end
end

local function valid(pl: Player): boolean
	local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
	return pl.Parent == Players and hum ~= nil and hum.Health > 0 and Arena.Of(pl) == nil and matchOf[pl] == nil
end

local function start(a: string, b: string)
	-- ตรวจสมาชิกที่เข้าคิวไว้ว่ายังพร้อม (ไม่ตาย ไม่ติดสนามอื่น) ก่อนดึงเข้าแมตช์
	local picked: { [string]: { Player } } = {}
	for _, gang in { a, b } do
		local good: { Player } = {}
		for _, pl in queue[gang] do
			if valid(pl) and gangOf(pl) == gang and #good < TEAM_SIZE then
				table.insert(good, pl)
			end
		end
		if #good < TEAM_SIZE then
			return
		end
		picked[gang] = good
	end
	local inst = Arena.Create("War", `สงครามแก๊ง {a} vs {b}`)
	if not inst then
		return
	end
	for _, gang in { a, b } do
		for _, pl in picked[gang] do
			removeFromQueue(pl)
		end
	end
	local m: Match = {
		Teams = {},
		Leaders = {},
		Kills = { [a] = 0, [b] = 0 },
		Names = { a, b },
		Inst = inst,
		StartAt = os.clock(),
		Over = false,
	}
	inst.OnLeave = function(pl: Player)
		memberGone(m, pl)
	end
	for _, gang in { a, b } do
		m.Teams[gang] = picked[gang]
		for _, pl in picked[gang] do
			matchOf[pl] = m
			pl:SetAttribute("InWar", true)
		end
	end
	task.spawn(function()
		local pending = 0
		for side, gang in { a, b } do
			for i, pl in picked[gang] do
				pending += 1
				task.spawn(function()
					local ok = Arena.Enter(inst, pl, (if side == 1 then "SpawnA" else "SpawnB") .. i, "fighter")
					if ok and pl.Character then
						pl.Character:SetAttribute("Team", gang)
						pl:SetAttribute("WarLeader", i == 1)
					else
						matchOf[pl] = nil
						pl:SetAttribute("InWar", false)
						local list = m.Teams[gang]
						local at = table.find(list, pl)
						if at then
							table.remove(list, at)
						end
					end
					pending -= 1
				end)
			end
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 12 do
			task.wait(0.1)
		end
		for gang, members in m.Teams do
			if #members == 0 then
				finish(m, nil)
				return
			end
			local leader = members[1]
			m.Leaders[gang] = leader
			leader:SetAttribute("WarLeader", true)
			local hum = leader.Character and leader.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Died:Once(function() -- ตายเองโดยไม่ผ่านการล้ม (ตกขอบ ฯลฯ) ก็นับว่าหัวหน้าล้ม
					if not m.Over then
						leaderDown(m, gang)
					end
				end)
			end
		end
		m.StartAt = os.clock()
		remote:FireAllClients("Start", a, b)
		toastAll(`สงครามแก๊งเริ่ม! {a} VS {b}`)
		while not m.Over do
			local left = MATCH_TIME - (os.clock() - m.StartAt)
			if left <= 0 then
				local ka, kb = m.Kills[a], m.Kills[b]
				finish(m, if ka > kb then a elseif kb > ka then b else nil)
				break
			end
			Arena.SetScore(inst, scoreText(m))
			task.wait(1)
		end
	end)
end

local function tryMatch()
	if forming then
		return
	end
	local ready: { string } = {}
	for gang, list in queue do
		if #list >= TEAM_SIZE then
			table.insert(ready, gang)
		end
	end
	if #ready >= 2 then
		forming = true
		pcall(start, ready[1], ready[2])
		forming = false
	end
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown)
	local gang = gangOf(player)
	if not gang or matchOf[player] or Arena.Of(player) then
		return
	end
	if action == "Queue" then
		removeFromQueue(player)
		queue[gang] = queue[gang] or {}
		table.insert(queue[gang], player)
		player:SetAttribute("WarQueued", true)
		publishQueue()
		tryMatch()
	elseif action == "Unqueue" then
		removeFromQueue(player)
	end
end)

Combat.OnKill(function(killer, victim)
	local kp, vp = Players:GetPlayerFromCharacter(killer.Character), Players:GetPlayerFromCharacter(victim.Character)
	local m = vp and matchOf[vp]
	if not m or m.Over or not kp or m ~= matchOf[kp] then
		return
	end
	local kg = killer.Character:GetAttribute("Team") :: string?
	if kg and m.Kills[kg] then
		m.Kills[kg] += 1
	end
	for gang, leader in m.Leaders do
		if leader == vp then
			leaderDown(m, gang)
			return
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
	local m = matchOf[player]
	matchOf[player] = nil
	if m then
		memberGone(m, player)
	end
end)

publishQueue()
