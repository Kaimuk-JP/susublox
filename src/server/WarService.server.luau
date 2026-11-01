--!strict
-- สงครามแก๊ง NvN (4/5/10/15 ต่อฝั่ง): ล้มหัวหน้าฝ่ายตรงข้ามให้ได้ หมดเวลาตัดสินด้วยจำนวนการล้ม
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

local SIZES = { 4, 5, 10, 15 } -- ขนาดทีมที่เลือกได้ (0 = อัตโนมัติ: เริ่มเมื่อสองแก๊งมีคนรอครบขนาดใดขนาดหนึ่ง เลือกใหญ่สุด)
local COUNTDOWN = 10
local MATCH_TIME = 300
local RETURN_DELAY = 6
local WIN_YEN, WIN_FAME, WIN_FUNDS, WIN_GANG_WINS = 100, 30, 200, 5

type Match = {
	Teams: { [string]: { Player } }, -- ชื่อแก๊ง -> สมาชิก
	Leaders: { [string]: Player },
	Kills: { [string]: number },
	Names: { string },
	Size: number,
	Inst: Arena.Inst,
	StartAt: number,
	Over: boolean,
}

local queue: { [string]: { Player } } = {}
local sizeOf: { [Player]: number } = {} -- ขนาดที่ผู้เล่นเลือกตอนเข้าคิว
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

local function leaderName(m: Match, gang: string): string
	local l = m.Leaders[gang]
	return if l then l.DisplayName else ""
end

local function updateBoard(m: Match)
	local a, b = m.Names[1], m.Names[2]
	Arena.SetBoard(m.Inst, {
		Title = `สงครามแก๊ง {m.Size}v{m.Size}`,
		NameA = a,
		NameB = b,
		Mid = `{m.Kills[a]} : {m.Kills[b]}`,
		LeadA = `หัวหน้า {leaderName(m, a)}`,
		LeadB = `หัวหน้า {leaderName(m, b)}`,
	})
end

local function finish(m: Match, winner: string?, note: string?)
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
	local text = if winner then `แก๊ง {winner} ชนะสงครามแก๊ง! (+¥{WIN_YEN} +{WIN_FAME} ชื่อเสียงให้ผู้ชนะ)` else (note or "สงครามแก๊งจบแบบเสมอ")
	toastAll(text)
	updateBoard(m)
	if winner then
		for gang, members in m.Teams do
			for _, pl in members do
				if gang == winner then
					Arena.Banner(m.Inst, pl, "ชนะ!", nil, 3)
				else
					Arena.Banner(m.Inst, pl, "แพ้", Color3.fromHex("FF5A4E"), 3)
				end
			end
		end
	end
	Arena.SetBoard(m.Inst, { State = "over", Note = if winner then `ผู้ชนะ {winner}` else (note or "เสมอ") })
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
			if m.Inst.Locked then
				finish(m, nil, "ยกเลิกสงครามแก๊ง: หัวหน้าทีมออกระหว่างนับถอยหลัง")
			else
				leaderDown(m, gang)
			end
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
				if m.Inst.Locked then
					finish(m, nil, "ยกเลิกสงครามแก๊ง: ทีมไม่เหลือผู้เล่นระหว่างนับถอยหลัง")
				else
					leaderDown(m, gang)
				end
			end
		end
	end
end

local function valid(pl: Player): boolean
	local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
	return pl.Parent == Players and hum ~= nil and hum.Health > 0 and Arena.Of(pl) == nil and matchOf[pl] == nil
end

local function start(a: string, b: string, size: number)
	-- ตรวจสมาชิกที่เข้าคิวไว้ว่ายังพร้อม (ไม่ตาย ไม่ติดสนามอื่น) ก่อนดึงเข้าแมตช์
	local picked: { [string]: { Player } } = {}
	for _, gang in { a, b } do
		local good: { Player } = {}
		for _, pl in queue[gang] do
			local want = sizeOf[pl] or 0
			if valid(pl) and gangOf(pl) == gang and #good < size and (want == size or want == 0) then
				table.insert(good, pl)
			end
		end
		if #good < size then
			return
		end
		picked[gang] = good
	end
	local inst = Arena.Create("War", `สงครามแก๊ง {size}v{size} · {a} vs {b}`, nil, size * 2)
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
		Size = size,
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
	Arena.SetBoard(inst, { State = "wait", Title = `สงครามแก๊ง {size}v{size}`, NameA = a, NameB = b, Mid = "0 : 0", LeadA = "", LeadB = "", Note = "" })
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
				finish(m, nil, "สงครามแก๊งถูกยกเลิก (ผู้เล่นเข้าสนามไม่ครบ)")
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
		updateBoard(m)
		toastAll(`สงครามแก๊ง {size}v{size}: {a} VS {b} — เริ่มใน {COUNTDOWN} วินาที`)
		-- นับถอยหลัง 10 วิ (ล็อกการเดิน/โจมตี); คนออกระหว่างนับ = ตัดออกจากทีม ยกเลิกเมื่อหัวหน้าออกหรือทีมว่าง
		local counted = Arena.RunCountdown(inst, COUNTDOWN, function()
			return m.Over
		end, true)
		if not counted then
			if not m.Over then
				finish(m, nil, "สงครามแก๊งถูกยกเลิกระหว่างนับถอยหลัง")
			end
			return
		end
		if m.Over then
			return
		end
		m.StartAt = os.clock()
		Arena.SetBoard(inst, { State = "live", Ends = workspace:GetServerTimeNow() + MATCH_TIME, Note = "" })
		remote:FireAllClients("Start", a, b)
		toastAll(`สงครามแก๊งเริ่ม! {a} VS {b}`)
		while not m.Over do
			if os.clock() - m.StartAt >= MATCH_TIME then
				local ka, kb = m.Kills[a], m.Kills[b]
				finish(m, if ka > kb then a elseif kb > ka then b else nil)
				break
			end
			task.wait(0.5)
		end
	end)
end

-- เลือกคู่แก๊งและขนาดทีม: ใหญ่สุดที่สองแก๊งมีคนรอครบ (ผู้เล่นที่เลือกขนาดตายตัวนับเฉพาะขนาดนั้น)
local function tryMatch()
	if forming then
		return
	end
	local function count(gang: string, size: number): number
		local n = 0
		for _, pl in queue[gang] or {} do
			local want = sizeOf[pl] or 0
			if want == size or want == 0 then
				n += 1
			end
		end
		return n
	end
	for k = #SIZES, 1, -1 do
		local size = SIZES[k]
		local ready: { string } = {}
		for gang in queue do
			if count(gang, size) >= size then
				table.insert(ready, gang)
			end
		end
		if #ready >= 2 then
			forming = true
			pcall(start, ready[1], ready[2], size)
			forming = false
			return
		end
	end
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown, size: unknown)
	local gang = gangOf(player)
	if not gang or matchOf[player] or Arena.Of(player) then
		return
	end
	if action == "Queue" then
		removeFromQueue(player)
		queue[gang] = queue[gang] or {}
		local want = if typeof(size) == "number" and table.find(SIZES, size) then size else 0
		sizeOf[player] = want
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
		updateBoard(m)
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
	sizeOf[player] = nil
	local m = matchOf[player]
	matchOf[player] = nil
	if m then
		memberGone(m, player)
	end
end)

publishQueue()
