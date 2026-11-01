--!strict
-- สนามประลอง (ลานหน้าสนามที่ WarArena): ผู้ตัดสินคีออสก์ -> เมนู (ดวล / สงครามแก๊ง / ศึกฝึกซ้อมบอท / ชมการแข่ง / อันดับ)
-- ศึกฝึกซ้อม: เข้า instance ธีมสุ่ม สู้บอท 3 ตัวต่อรอบ สูงสุด 5 รอบ ยากขึ้นตามรอบ ได้รางวัลทุกรอบที่ผ่าน
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Arena = require(script.Parent.ArenaManager)
local Kit = require(script.Parent.ArenaKit)
local GangStore = require(script.Parent.GangStore)
local PlayerData = require(script.Parent.PlayerData)
local RigFactory = require(script.Parent.RigFactory)

local remote = Instance.new("RemoteEvent")
remote.Name = "ArenaRemote"
remote.Parent = ReplicatedStorage
local worldRemote = ReplicatedStorage:WaitForChild("WorldRemote") :: RemoteEvent
local changed = ServerStorage:WaitForChild("ProfileChanged") :: BindableEvent

local MAX_WAVES = 5
local BOTS_PER_WAVE = 3
local WAVE_TIMEOUT = 100
local TRIAL_COOLDOWN = 20
local KIOSK_REACH = 40 -- ต้องอยู่ในลานหน้าสนามและห่างคีออสก์ไม่เกินนี้ จึงขอเมนู/เริ่มได้

local function toast(player: Player, text: string)
	worldRemote:FireClient(player, "Toast", text)
end

local function root(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local kioskPos = Vector3.new(18, 0, Kit.SITE.Z - 54.6) -- หลังเคาน์เตอร์ผู้ตัดสิน (เคาน์เตอร์อยู่ที่ z -57 จากศูนย์วงรี)
local function nearKiosk(player: Player): boolean
	local r = root(player)
	return r ~= nil and Arena.InLobby(r.Position) and (Vector3.new(r.Position.X, 0, r.Position.Z) - kioskPos).Magnitude <= KIOSK_REACH
end

---------------------------------------------------------------- ข้อมูลส่งไปเมนู
local function rankLists(): ({ { Name: string, Points: number } }, { { Name: string, Wins: number } })
	local players = {}
	local gangs: { [string]: number } = {}
	for _, pl in Players:GetPlayers() do
		local p = PlayerData.Get(pl)
		if p then
			table.insert(players, { Name = pl.DisplayName, Points = p.RankPoints })
			if p.Gang ~= "" and gangs[p.Gang] == nil then
				local g = GangStore.Get(p.Gang)
				gangs[p.Gang] = if g then g.Wins else 0
			end
		end
	end
	table.sort(players, function(a, b)
		return a.Points > b.Points
	end)
	local gl = {}
	for name, wins in gangs do
		table.insert(gl, { Name = name, Wins = wins })
	end
	table.sort(gl, function(a, b)
		return a.Wins > b.Wins
	end)
	return players, gl
end

local function buildState(player: Player)
	local nearby = {}
	local me = root(player)
	for _, other in Players:GetPlayers() do
		local r = root(other)
		if other ~= player and r and Arena.InLobby(r.Position) and not Arena.Of(other) then
			table.insert(nearby, { Id = other.UserId, Name = other.DisplayName })
		end
	end
	local matches = {}
	for _, inst in Arena.List() do
		local n = 0
		for _ in inst.Members do
			n += 1
		end
		table.insert(matches, { Id = inst.Id, Kind = inst.Kind, Label = inst.Label, Theme = Kit.THEME_NAMES[inst.Theme] or inst.Theme, Count = n })
	end
	local players, gangs = rankLists()
	local top1, top2 = {}, {}
	for i = 1, math.min(5, #players) do
		top1[i] = players[i]
	end
	for i = 1, math.min(5, #gangs) do
		top2[i] = gangs[i]
	end
	return {
		InLobby = me ~= nil and Arena.InLobby(me.Position) and Arena.Of(player) == nil,
		Nearby = nearby,
		Matches = matches,
		QueueGangs = workspace:GetAttribute("WarQueueGangs") or 0,
		QueuePlayers = workspace:GetAttribute("WarQueuePlayers") or 0,
		TopPlayers = top1,
		TopGangs = top2,
	}
end

---------------------------------------------------------------- ศึกฝึกซ้อม
type Trial = { Player: Player, Inst: Arena.Inst, Done: boolean, Cleared: number, Exp: number, Yen: number, Fame: number, Reason: string }
local trials: { [Player]: Trial } = {}
local lastTrialEnd: { [Player]: number } = {}

local function reward(player: Player, wave: number, botLevel: number, t: Trial)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	local exp, yen, fame = botLevel * 10 * wave, botLevel * 6 * wave, if wave % 2 == 1 then 2 else 3
	local lv, ex, pts = Progression.AddExp(p.Level, p.Exp, exp, p.Prestige)
	p.Level, p.Exp = lv, ex
	p.StatPoints += pts
	p.Yen += yen
	p.Fame += fame
	player:SetAttribute("Yen", p.Yen)
	changed:Fire(player)
	t.Exp += exp
	t.Yen += yen
	t.Fame += fame
	toast(player, `ผ่านรอบ {wave}/{MAX_WAVES}! +{exp} EXP +¥{yen}`)
end

local function botSpec(wave: number, i: number): (string, number)
	-- (ชนิดบอท, ตัวคูณเลือด)
	if wave == 1 then
		return "Grunt", 1
	elseif wave == 2 then
		return if i == 3 then "Speedy" else "Grunt", 1
	elseif wave == 3 then
		return if i == 1 then "Grunt" else "Speedy", 1.1
	elseif wave == 4 then
		return if i == 2 then "Brute" else (if i == 1 then "Grunt" else "Speedy"), 1.1
	end
	return if i == 2 then "Brute" else "Grunt", if i == 2 then 1.6 else 1.2
end

local function spawnBots(t: Trial, wave: number, botLevel: number): { Model }
	local npcs = workspace:FindFirstChild("Npcs")
	local bots: { Model } = {}
	if not npcs then
		return bots
	end
	for i = 1, BOTS_PER_WAVE do
		local pos = Arena.MarkerPos(t.Inst, "SpawnB" .. (i + 0))
		if pos then
			local kind, hp = botSpec(wave, i)
			local rig = RigFactory.Create("นักสู้ฝึกซ้อม", pos + Vector3.new(0, 4, 0), npcs, {
				NpcLevel = botLevel,
				NpcType = kind,
				Aggressive = true,
				RespawnTime = 1e9,
				HpMult = hp * (if kind == "Brute" then 2.5 else if kind == "Speedy" then 0.7 else 1),
				Trial = true,
				ArenaId = t.Inst.Id,
			}, Color3.fromHex("C8323C"))
			if rig then
				local at = pos + Vector3.new(0, 4, 0)
				rig:PivotTo(CFrame.lookAt(at, Vector3.new(t.Inst.Origin.X, at.Y, t.Inst.Origin.Z)))
				table.insert(bots, rig)
			end
		end
	end
	return bots
end

local function endTrial(t: Trial, reason: string)
	if t.Done then
		return
	end
	t.Done = true
	t.Reason = reason
end

local function runTrial(t: Trial)
	local player, inst = t.Player, t.Inst
	local p = PlayerData.Get(player)
	local plLevel = if p then p.Level else 1
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Once(function()
			endTrial(t, "แพ้")
		end)
	end
	for wave = 1, MAX_WAVES do
		if t.Done then
			break
		end
		local botLevel = math.clamp(math.floor(plLevel * 0.1) + wave, 1, 15)
		Arena.SetScore(inst, `<b>ศึกฝึกซ้อม</b>\nรอบ {wave}/{MAX_WAVES}  ·  เตรียมตัว...`)
		toast(player, `รอบ {wave}/{MAX_WAVES} กำลังจะเริ่ม (บอทเลเวล {botLevel})`)
		for _ = 1, 6 do
			if t.Done then
				break
			end
			task.wait(0.5)
		end
		if t.Done then
			break
		end
		local bots = spawnBots(t, wave, botLevel)
		local t0 = os.clock()
		while not t.Done do
			local alive = 0
			for _, b in bots do
				local h = b:FindFirstChildOfClass("Humanoid")
				if b.Parent and h and h.Health > 0 then
					alive += 1
				end
			end
			Arena.SetScore(inst, `<b>ศึกฝึกซ้อม</b>\nรอบ {wave}/{MAX_WAVES}  ·  เหลือ {alive} ตัว  ·  {math.max(0, WAVE_TIMEOUT - math.floor(os.clock() - t0))} วิ`)
			if alive == 0 then
				break
			end
			if os.clock() - t0 > WAVE_TIMEOUT then
				endTrial(t, "หมดเวลา")
				break
			end
			task.wait(0.5)
		end
		for _, b in bots do
			if b.Parent then
				b:SetAttribute("Despawned", true) -- ไม่เกิดใหม่ และไม่นับเป็นศัตรูทั่วไป
			end
		end
		if t.Done then
			for _, b in bots do
				b:Destroy()
			end
			break
		end
		t.Cleared = wave
		reward(player, wave, botLevel, t)
	end
	if not t.Done then
		t.Done = true
		t.Reason = "ชนะครบ"
		local p2 = PlayerData.Get(player)
		if p2 then
			p2.Fame += 10
			t.Fame += 10
			changed:Fire(player)
		end
	end
	local summary = if t.Reason == "ชนะครบ" then "เคลียร์ศึกฝึกซ้อมครบทุกรอบ!" else `จบศึกฝึกซ้อม ({t.Reason})`
	Arena.SetScore(inst, `<b>{summary}</b>\nผ่าน {t.Cleared}/{MAX_WAVES} รอบ`)
	toast(player, `{summary} ผ่าน {t.Cleared}/{MAX_WAVES} รอบ รวม +{t.Exp} EXP +¥{t.Yen} +{t.Fame} ชื่อเสียง`)
	Arena.EndFight(inst)
	task.wait(3.5)
	trials[player] = nil
	lastTrialEnd[player] = os.clock()
	Arena.Destroy(inst)
end

local function startTrial(player: Player)
	if trials[player] or Arena.Of(player) then
		return
	end
	if not nearKiosk(player) then
		return
	end
	if os.clock() - (lastTrialEnd[player] or -math.huge) < TRIAL_COOLDOWN then
		toast(player, "พักสักครู่ก่อนเริ่มศึกฝึกซ้อมอีกครั้ง")
		return
	end
	local inst = Arena.Create("Trial", `ศึกฝึกซ้อม · {player.DisplayName}`)
	if not inst then
		toast(player, "สนามเต็มแล้ว ลองใหม่ภายหลัง")
		return
	end
	local t: Trial = { Player = player, Inst = inst, Done = false, Cleared = 0, Exp = 0, Yen = 0, Fame = 0, Reason = "" }
	trials[player] = t
	inst.OnLeave = function()
		endTrial(t, "ออกจากสนาม")
	end
	task.spawn(function()
		if not Arena.Enter(inst, player, "SpawnA2", "fighter") then
			trials[player] = nil
			Arena.Destroy(inst)
			return
		end
		local ok, err = pcall(runTrial, t)
		if not ok then
			warn("[Arena] trial error: " .. tostring(err))
			trials[player] = nil
			lastTrialEnd[player] = os.clock()
			Arena.Destroy(inst)
		end
	end)
end

---------------------------------------------------------------- รีโมต
local lastReq: { [Player]: number } = {}
remote.OnServerEvent:Connect(function(player: Player, action: unknown, arg: unknown)
	local now = os.clock()
	if now - (lastReq[player] or -math.huge) < 0.4 then
		return
	end
	lastReq[player] = now
	if action == "Refresh" then
		remote:FireClient(player, "State", buildState(player))
	elseif action == "Trial" then
		startTrial(player)
	elseif action == "Spectate" and typeof(arg) == "number" then
		local inst = Arena.Get(arg)
		if inst and not inst.Over and not Arena.Of(player) and nearKiosk(player) then
			task.spawn(Arena.Enter, inst, player, nil, "spec")
		end
	elseif action == "Leave" then
		Arena.Leave(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastReq[player] = nil
	lastTrialEnd[player] = nil
	local t = trials[player]
	if t then
		endTrial(t, "ผู้เล่นออก")
	end
end)

---------------------------------------------------------------- ผู้ตัดสิน + กระดานที่ลานหน้าสนาม
task.spawn(function()
	local map = workspace:WaitForChild("Map")
	local war = map:WaitForChild("WarArena")
	local ext = war:WaitForChild("WarArenaExterior", 60)
	if not ext then
		return
	end
	local rig = RigFactory.Create("ผู้ตัดสินสนามประลอง", Vector3.new(kioskPos.X, 8, kioskPos.Z), war, { NoLocomotion = true }, Color3.fromHex("B03A2E"), "referee")
	if rig then
		local r = rig:FindFirstChild("HumanoidRootPart") :: BasePart
		local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { rig }
		local hit = workspace:Raycast(Vector3.new(kioskPos.X, 8, kioskPos.Z), Vector3.new(0, -20, 0), params)
		local gy = if hit then hit.Position.Y else Kit.SITE.Y + 0.5
		rig:PivotTo(CFrame.new(kioskPos.X, gy + hum.HipHeight + r.Size.Y / 2, kioskPos.Z)) -- หน้าหัน -Z (ไปทางผู้เล่นที่เดินเข้าลาน)
		r.Anchored = true
		hum.DisplayName = "ผู้ตัดสิน"
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "เข้าสู่สนามประลอง"
		prompt.ObjectText = "ผู้ตัดสิน"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = r
		prompt.Triggered:Connect(function(player)
			if os.clock() - (lastReq[player] or -math.huge) < 0.6 then
				return
			end
			lastReq[player] = os.clock()
			remote:FireClient(player, "Open", buildState(player))
		end)
	end

end)

-- อัปเดตกระดานทุก 5 วินาที (ข้อมูลจริง: ผู้เล่นในเซิร์ฟเวอร์นี้ + แก๊ง)
task.spawn(function()
	local map = workspace:WaitForChild("Map")
	local ext = map:WaitForChild("WarArena"):WaitForChild("WarArenaExterior", 60)
	if not ext then
		return
	end
	local info = ext:FindFirstChild("InfoBoard")
	local rankBoard = ext:FindFirstChild("RankBoard")
	local infoLabel = info and info:FindFirstChild("Body", true) :: TextLabel?
	local rankLabel = rankBoard and rankBoard:FindFirstChild("Body", true) :: TextLabel?
	while true do
		local lines = {
			`คิวสงครามแก๊ง 4v4: {workspace:GetAttribute("WarQueueGangs") or 0} แก๊ง / {workspace:GetAttribute("WarQueuePlayers") or 0} คน`,
		}
		local list = Arena.List()
		table.insert(lines, `แมตช์ที่กำลังแข่ง: {#list}`)
		for i = 1, math.min(4, #list) do
			table.insert(lines, `• {list[i].Label}`)
		end
		if #list == 0 then
			table.insert(lines, "ยังไม่มีแมตช์ — คุยกับผู้ตัดสินเพื่อเริ่ม")
		end
		if infoLabel then
			infoLabel.Text = table.concat(lines, "\n")
		end
		local players, gangs = rankLists()
		local r = { "▍ดวล 1v1 (แต้มแรงก์ในเซิร์ฟเวอร์นี้)" }
		for i = 1, math.min(4, #players) do
			table.insert(r, `{i}. {players[i].Name}  {players[i].Points} แต้ม`)
		end
		table.insert(r, "▍สงครามแก๊ง (ชนะรวม)")
		for i = 1, math.min(3, #gangs) do
			table.insert(r, `{i}. {gangs[i].Name}  {gangs[i].Wins} ชนะ`)
		end
		if #gangs == 0 then
			table.insert(r, "ยังไม่มีแก๊งในเซิร์ฟเวอร์")
		end
		if rankLabel then
			rankLabel.Text = table.concat(r, "\n")
		end
		task.wait(5)
	end
end)
