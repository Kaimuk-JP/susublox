--!strict
-- โลกเปิด: ศัตรูประจำย่าน (เกิดเมื่อมีผู้เล่นเข้าใกล้), บอสประจำย่าน, ผู้ให้ภารกิจ, ภารกิจ (เก็บ/ล่า/สำรวจ/บอส),
-- การค้นพบย่านและเดินทางด่วน (Stone) — สถานะเก็บในโปรไฟล์ p.World
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local World = require(ReplicatedStorage.Shared.World)
local WQ = require(ReplicatedStorage.Shared.WorldQuests)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local RigFactory = require(script.Parent.RigFactory)

local remote = Instance.new("RemoteEvent")
remote.Name = "WorldRemote"
remote.Parent = ReplicatedStorage

local changed = ServerStorage:WaitForChild("ProfileChanged") :: BindableEvent
local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end
local npcs = workspace:WaitForChild("Npcs")
local questNpcs = Instance.new("Folder")
questNpcs.Name = "QuestNpcs"
questNpcs.Parent = workspace

local rng = Random.new(99)
local SPAWN_RADIUS_EXTRA = 140
local DESPAWN_RADIUS_EXTRA = 380
local DESPAWN_AFTER = 45
local TRAVEL_COOLDOWN = 12

---------------------------------------------------------------- พื้นที่/ตำแหน่ง
local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { npcs, questNpcs }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function groundAt(x: number, z: number): Vector3
	local res = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), rayParams())
	return Vector3.new(x, if res then res.Position.Y else 0, z)
end

-- หาตำแหน่งเกิดศัตรู: พื้นเรียบ ไม่ใช่น้ำ ไม่ซ้อนกับสิ่งก่อสร้าง/ต้นไม้
local function findSpawn(d: World.District): Vector3?
	for _ = 1, 25 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = d.Radius * 0.9 * math.sqrt(rng:NextNumber())
		local x, z = d.Center.X + math.cos(a) * r, d.Center.Z + math.sin(a) * r
		local res = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), rayParams())
		if res and res.Material ~= Enum.Material.Water then
			local y = res.Position.Y
			if y <= (if d.Theme == "temple" then 30 else 2) then
				local overlap = OverlapParams.new()
				overlap.FilterType = Enum.RaycastFilterType.Exclude
				overlap.FilterDescendantsInstances = { npcs, questNpcs }
				local clear = true
				for _, p in workspace:GetPartBoundsInBox(CFrame.new(x, y + 4.5, z), Vector3.new(4, 6, 4), overlap) do
					if p.CanCollide then
						clear = false
						break
					end
				end
				if clear then
					return Vector3.new(x, y, z)
				end
			end
		end
	end
	return nil
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

---------------------------------------------------------------- ศัตรูประจำย่าน (เกิด/หายตามผู้เล่นที่อยู่ใกล้)
type DistrictState = { Spawned: boolean, Spawning: boolean, LastNear: number, Models: { Model } }
local states: { [string]: DistrictState } = {}
for _, d in World.Districts do
	states[d.Id] = { Spawned = false, Spawning = false, LastNear = 0, Models = {} }
end

local function makeEnemy(d: World.District, name: string, npcType: string, level: number, pos: Vector3, boss: boolean, respawn: number): Model?
	local rig = RigFactory.Create(name, pos + Vector3.new(0, 3, 0), npcs, {
		NpcLevel = level,
		NpcType = npcType,
		District = d.Id,
		IsBoss = boss,
		RespawnTime = respawn,
	}, Color3.fromHex(d.EnemyColor))
	if rig then
		local hum = rig:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayName = name
		end
	end
	return rig
end

local function spawnDistrict(d: World.District)
	local st = states[d.Id]
	if st.Spawned or st.Spawning then
		return
	end
	st.Spawning = true
	local count = 6 + math.floor(d.Radius / 45) -- ไม่มากเกินไป (ค่ายแก๊งมีลูกน้องเพิ่มอีกค่ายละ 7)
	for _ = 1, count do
		local pos = findSpawn(d)
		if pos then
			local level = rng:NextInteger(d.Levels[1], d.Levels[2])
			local roll = rng:NextNumber()
			local npcType, name = "Grunt", d.EnemyName
			if roll > 0.85 then
				npcType, name = "Brute", d.EnemyName .. " (ตัวหนัก)"
			elseif roll > 0.6 then
				npcType, name = "Speedy", d.EnemyName .. " (ว่องไว)"
			end
			local m = makeEnemy(d, name, npcType, level, pos, false, 30)
			if m then
				table.insert(st.Models, m)
			end
		end
	end
	local bossPos = groundAt(d.Center.X + d.BossOffset.X, d.Center.Z + d.BossOffset.Z)
	local boss = makeEnemy(d, d.BossName, "Brute", d.Levels[2] + 2, bossPos, true, 240)
	if boss then
		table.insert(st.Models, boss)
	end
	st.Spawned = true
	st.Spawning = false
	npcs:SetAttribute("Active_" .. d.Id, true)
end

local function despawnDistrict(d: World.District)
	local st = states[d.Id]
	st.Spawned = false
	npcs:SetAttribute("Active_" .. d.Id, false)
	for _, m in npcs:GetChildren() do
		if m:GetAttribute("District") == d.Id then
			m:SetAttribute("Despawned", true)
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Health = 0
			end
			task.delay(3.5, function()
				m:Destroy()
			end)
		end
	end
	table.clear(st.Models)
end

task.spawn(function()
	while true do
		task.wait(3)
		for _, d in World.Districts do
			local st = states[d.Id]
			local nearest = math.huge
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					nearest = math.min(nearest, horizontal(root.Position, d.Center))
				end
			end
			if nearest <= d.Radius + SPAWN_RADIUS_EXTRA then
				st.LastNear = os.clock()
				if not st.Spawned and not st.Spawning then
					task.spawn(spawnDistrict, d)
				end
			elseif st.Spawned and nearest > d.Radius + DESPAWN_RADIUS_EXTRA and os.clock() - st.LastNear > DESPAWN_AFTER then
				despawnDistrict(d)
			end
		end
	end
end)

---------------------------------------------------------------- ผู้ให้ภารกิจ
local giverPos: { [string]: Vector3 } = {}

local function dialog(player: Player, title: string, text: string, acceptId: string?, rewardText: string?)
	remote:FireClient(player, "Dialog", { Title = title, Text = text, Accept = acceptId, Reward = rewardText })
end

local function rewardText(q: WQ.Quest): string
	local r = q.Reward
	local text = `¥{r.Yen}  EXP {r.Exp}  Fame {r.Fame}`
	if r.Outfit then
		text ..= `  + ชุด`
	end
	return text
end

local function activeCount(p: any): number
	local n = 0
	for _ in p.World.Active do
		n += 1
	end
	return n
end

-- ภารกิจถัดไปของย่านที่ยังไม่เสร็จ (ลำดับบังคับ)
local function nextQuest(p: any, districtId: string): WQ.Quest?
	for _, q in WQ.ForDistrict(districtId) do
		if not p.World.Done[q.Id] then
			return q
		end
	end
	return nil
end

local visited: { [Player]: { [string]: { [number]: boolean } } } = {}

local function questTarget(p: any, player: Player, q: WQ.Quest): Vector3
	local d = World.ById(q.District) :: World.District
	local prog = p.World.Active[q.Id] or 0
	if prog >= q.Count then
		return giverPos[d.Id] or d.Center
	end
	if q.Kind == "Explore" then
		local v = visited[player] and visited[player][q.Id] or {}
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local best, bestDist = nil, math.huge
		for i, poi in d.Pois do
			if not v[i] then
				local pos = d.Center + poi
				local dist = if root then horizontal(root.Position, pos) else 0
				if dist < bestDist then
					best, bestDist = pos, dist
				end
			end
		end
		return best or d.Center
	elseif q.Kind == "Boss" then
		return d.Center + d.BossOffset
	end
	return d.Center
end

local function publishTracker(player: Player)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	local i = 0
	for qid, prog in p.World.Active do
		local q = WQ.ById[qid]
		if q and i < WQ.MaxActive then
			i += 1
			local done = prog >= q.Count
			player:SetAttribute(`QT{i}Name`, q.Name)
			player:SetAttribute(`QT{i}Text`, if done then "ทำครบแล้ว! กลับไปหาผู้ให้ภารกิจ" else `{prog}/{q.Count}`)
			player:SetAttribute(`QT{i}Pos`, questTarget(p, player, q))
			player:SetAttribute(`QT{i}Done`, done)
			player:SetAttribute(`QT{i}Id`, qid)
		end
	end
	for k = i + 1, WQ.MaxActive do
		player:SetAttribute(`QT{k}Name`, nil)
		player:SetAttribute(`QT{k}Text`, nil)
		player:SetAttribute(`QT{k}Pos`, nil)
		player:SetAttribute(`QT{k}Done`, nil)
		player:SetAttribute(`QT{k}Id`, nil)
	end
	player:SetAttribute("QTCount", i)
end

local function addProgress(player: Player, kind: string, districtId: string, amount: number)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	local touched = false
	for qid, prog in p.World.Active do
		local q = WQ.ById[qid]
		if q and q.District == districtId and q.Kind == kind and prog < q.Count then
			p.World.Active[qid] = math.min(q.Count, prog + amount)
			touched = true
		end
	end
	if touched then
		publishTracker(player)
	end
end

local function giveReward(player: Player, p: any, q: WQ.Quest)
	local r = q.Reward
	p.Yen += r.Yen
	p.Fame += r.Fame
	local level, exp, points = Progression.AddExp(p.Level, p.Exp, r.Exp, p.Prestige)
	p.Level, p.Exp = level, exp
	p.StatPoints += points
	if r.Outfit and not table.find(p.Owned, r.Outfit) then
		table.insert(p.Owned, r.Outfit)
	end
	changed:Fire(player)
end

local function onGiverTriggered(player: Player, d: World.District)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	local q = nextQuest(p, d.Id)
	if not q then
		dialog(player, d.GiverName, "ขอบคุณมากนะ! ภารกิจในย่านนี้เสร็จหมดแล้ว ไปช่วยย่านอื่นต่อได้เลย", nil, nil)
		return
	end
	local prog = p.World.Active[q.Id]
	if prog ~= nil then
		if prog >= q.Count then
			p.World.Active[q.Id] = nil
			p.World.Done[q.Id] = true
			giveReward(player, p, q)
			publishTracker(player)
			dialog(player, "ภารกิจสำเร็จ!", `{q.Name}\nขอบคุณมาก! นี่คือรางวัลของเธอ`, nil, rewardText(q))
		else
			dialog(player, q.Name, `{q.Desc}\n\nความคืบหน้า: {prog}/{q.Count}`, nil, nil)
		end
	elseif p.Level < q.ReqLevel then
		dialog(player, d.GiverName, `ภารกิจต่อไปคือ "{q.Name}" แต่ยังอันตรายเกินไปสำหรับเธอ กลับมาตอนเลเวล {q.ReqLevel} นะ`, nil, nil)
	elseif activeCount(p) >= WQ.MaxActive then
		dialog(player, d.GiverName, `เธอรับภารกิจไว้เต็มแล้ว ({WQ.MaxActive} ภารกิจ) ทำให้เสร็จก่อนแล้วค่อยกลับมานะ`, nil, nil)
	else
		dialog(player, q.Name, q.Desc, q.Id, rewardText(q))
	end
end

local function makeGiver(d: World.District)
	local pos = groundAt(d.Center.X + d.GiverOffset.X, d.Center.Z + d.GiverOffset.Z)
	local rig = RigFactory.Create(d.GiverName, pos + Vector3.new(0, 3, 0), questNpcs, nil, Color3.fromHex("FFE066"))
	if not rig then
		return
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = rig:FindFirstChild("Head") :: BasePart?
	if not hum or not root or not head then
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(d.Center.X, root.Position.Y, d.Center.Z + 30))
	root.Anchored = true
	giverPos[d.Id] = pos

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 56)
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.MaxDistance = 120
	gui.Adornee = head
	gui.Parent = head
	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.new(1, 0, 0.6, 0)
	mark.BackgroundTransparency = 1
	mark.Text = "!"
	mark.TextColor3 = Color3.fromHex("FFE066")
	mark.TextStrokeTransparency = 0
	mark.Font = Enum.Font.FredokaOne
	mark.TextScaled = true
	mark.Parent = gui
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromScale(0, 0.6)
	label.Size = UDim2.new(1, 0, 0.4, 0)
	label.BackgroundTransparency = 1
	label.Text = d.GiverName
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "คุยด้วย"
	prompt.ObjectText = d.GiverName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		onGiverTriggered(player, d)
	end)

	-- พฤติกรรมเล็กๆ: หันหาผู้เล่นที่เดินเข้าใกล้ + โบกมือเมื่อมีภารกิจให้รับ (ตรวจทุก 0.4 วินาที เฉพาะตอนมีคนอยู่ใกล้)
	local homeCf = root.CFrame
	local lastWave: { [Player]: number } = {}
	task.spawn(function()
		while rig.Parent do
			task.wait(0.4)
			local nearest: Player?, best = nil, 28
			for _, pl in Players:GetPlayers() do
				local c = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if c then
					local dist = (c.Position - root.Position).Magnitude
					if dist < best then
						nearest, best = pl, dist
					end
				end
			end
			local target = homeCf
			if nearest then
				local c = (nearest.Character :: Model).HumanoidRootPart :: BasePart
				target = CFrame.lookAt(root.Position, Vector3.new(c.Position.X, root.Position.Y, c.Position.Z))
				local pd = PlayerData.Get(nearest)
				local q = pd and nextQuest(pd, d.Id)
				local waveOk = q ~= nil and pd.World.Active[q.Id] == nil and pd.Level >= q.ReqLevel
				if waveOk and best < 20 and os.clock() - (lastWave[nearest] or -99) > 15 then
					lastWave[nearest] = os.clock()
					RigFactory.Wave(rig)
				end
			end
			root.CFrame = root.CFrame:Lerp(CFrame.new(root.Position) * (target - target.Position), 0.45)
		end
	end)
end

for _, d in World.Districts do
	task.spawn(makeGiver, d)
end

---------------------------------------------------------------- ของสะสมสำหรับภารกิจ Collect
local ORBS_PER_DISTRICT = 10
local orbNames: { [string]: string } = {
	SakuraPark = "กลีบซากุระวิเศษ",
	Shotengai = "กล่องพัสดุ",
	Downtown = "กระเป๋าผู้โดยสาร",
	Docks = "ลังสินค้า",
}

-- หน้าตาของสะสมตามธีมย่าน (ชิ้นเล็ก เรืองแสงอ่อน หมุนช้าฝั่ง client)
local orbLooks = {
	SakuraPark = { shape = Enum.PartType.Ball, size = Vector3.new(1.5, 1.1, 1.5), material = Enum.Material.Neon, color = Color3.fromHex("F7B6C8"), glow = Color3.fromHex("FFC6D6") },
	Shotengai = { shape = Enum.PartType.Block, size = Vector3.new(1.8, 1.3, 1.4), material = Enum.Material.SmoothPlastic, color = Color3.fromHex("C69C6D"), glow = Color3.fromHex("FFD9A0") },
	Downtown = { shape = Enum.PartType.Block, size = Vector3.new(1.5, 1.7, 0.7), material = Enum.Material.Fabric, color = Color3.fromHex("2F4A7A"), glow = Color3.fromHex("9CC0FF") },
	Docks = { shape = Enum.PartType.Block, size = Vector3.new(1.9, 1.6, 1.9), material = Enum.Material.Wood, color = Color3.fromHex("8A5A2B"), glow = Color3.fromHex("FFC070") },
	Default = { shape = Enum.PartType.Ball, size = Vector3.one * 1.6, material = Enum.Material.Neon, color = Color3.fromHex("FFE066"), glow = Color3.fromHex("FFE066") },
}

for _, d in World.Districts do
	local hasCollect = false
	for _, q in WQ.ForDistrict(d.Id) do
		if q.Kind == "Collect" then
			hasCollect = true
		end
	end
	if hasCollect then
		local orbFolder = Instance.new("Folder")
		orbFolder.Name = "Orbs_" .. d.Id
		orbFolder.Parent = worldFolder
		for _ = 1, ORBS_PER_DISTRICT do
			local pos = findSpawn(d)
			if pos then
				local orb = Instance.new("Part")
				orb.Name = orbNames[d.Id] or "ของสะสม"
				local look = orbLooks[d.Id] or orbLooks.Default
				orb.Shape = look.shape
				orb.Size = look.size
				orb.Anchored = true
				orb.CanCollide = false
				orb.Material = look.material
				orb.Color = look.color
				orb.Position = pos + Vector3.new(0, 2.2, 0)
				orb.Orientation = Vector3.new(0, math.random(0, 359), 0)
				orb.Parent = orbFolder
				local light = Instance.new("PointLight")
				light.Color = look.glow
				light.Brightness = 0.8
				light.Range = 9
				light.Parent = orb
				local ready = true
				orb.Touched:Connect(function(hit)
					if not ready then
						return
					end
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					local p = player and PlayerData.Get(player)
					if not player or not p then
						return
					end
					for qid, prog in p.World.Active do
						local q = WQ.ById[qid]
						if q and q.District == d.Id and q.Kind == "Collect" and prog < q.Count then
							ready = false
							orb.Transparency = 1
							light.Enabled = false
							addProgress(player, "Collect", d.Id, 1)
							remote:FireClient(player, "Toast", `เก็บ {orb.Name} แล้ว!`)
							task.delay(35, function()
								ready = true
								orb.Transparency = 0
								light.Enabled = true
							end)
							return
						end
					end
				end)
			end
		end
	end
end

-- ให้ client รู้ว่าย่านไหนมีเควสเก็บของค้างอยู่ (Attribute "Orb_<ย่าน>") ของสะสมจะแสดงเฉพาะตอนนั้น
task.spawn(function()
	while true do
		task.wait(1)
		for _, pl in Players:GetPlayers() do
			local p = PlayerData.Get(pl)
			if p then
				local on: { [string]: boolean } = {}
				for qid, prog in p.World.Active do
					local q = WQ.ById[qid]
					if q and q.Kind == "Collect" and prog < q.Count then
						on[q.District] = true
					end
				end
				for _, d in World.Districts do
					local want = on[d.Id] == true
					if pl:GetAttribute("Orb_" .. d.Id) ~= want then
						pl:SetAttribute("Orb_" .. d.Id, want)
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------- ล้มศัตรู/บอสในย่าน -> ความคืบหน้า
Combat.OnKill(function(killer, victim)
	local player = Players:GetPlayerFromCharacter(killer.Character)
	local districtId = victim.Character:GetAttribute("District")
	if not player or typeof(districtId) ~= "string" then
		return
	end
	addProgress(player, "Kill", districtId, 1)
	if victim.IsBoss then
		addProgress(player, "Boss", districtId, 1)
	end
end)

---------------------------------------------------------------- การค้นพบย่าน + จุดสำรวจ
local function discover(player: Player, p: any, d: World.District)
	if p.World.Discovered[d.Id] then
		return
	end
	p.World.Discovered[d.Id] = true
	p.Fame += 10
	player:SetAttribute("Disc_" .. d.Id, true)
	remote:FireClient(player, "Discovered", d.Name)
	changed:Fire(player)
end

task.spawn(function()
	while true do
		task.wait(0.6)
		for _, player in Players:GetPlayers() do
			local p = PlayerData.Get(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if p and root then
				for _, d in World.Districts do
					local dist = horizontal(root.Position, d.Center)
					if dist <= d.Radius then
						discover(player, p, d)
					end
					-- จุดสำรวจ
					for qid, prog in p.World.Active do
						local q = WQ.ById[qid]
						if q and q.District == d.Id and q.Kind == "Explore" and prog < q.Count then
							local vp = visited[player]
							if not vp then
								vp = {}
								visited[player] = vp
							end
							local v = vp[qid]
							if not v then
								v = {}
								vp[qid] = v
							end
							for i, poi in d.Pois do
								if not v[i] and horizontal(root.Position, d.Center + poi) < 14 then
									v[i] = true
									addProgress(player, "Explore", d.Id, 1)
									remote:FireClient(player, "Toast", "สำรวจจุดนี้แล้ว!")
								end
							end
						end
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------- remote จากเมนู/หน้าต่างภารกิจ
local travelAt: { [Player]: number } = {}

remote.OnServerEvent:Connect(function(player: Player, action: unknown, arg: unknown)
	local p = PlayerData.Get(player)
	if not p or typeof(action) ~= "string" or typeof(arg) ~= "string" then
		return
	end
	if action == "Accept" then
		local q = WQ.ById[arg]
		if not q or p.World.Done[arg] or p.World.Active[arg] ~= nil then
			return
		end
		if nextQuest(p, q.District) ~= q or p.Level < q.ReqLevel or activeCount(p) >= WQ.MaxActive then
			return
		end
		p.World.Active[arg] = 0
		if visited[player] then
			visited[player][arg] = nil
		end
		publishTracker(player)
		remote:FireClient(player, "Toast", `รับภารกิจ: {q.Name}`)
	elseif action == "Abandon" then
		if p.World.Active[arg] ~= nil then
			p.World.Active[arg] = nil
			publishTracker(player)
		end
	elseif action == "Travel" then
		local now = os.clock()
		if now - (travelAt[player] or -math.huge) < TRAVEL_COOLDOWN then
			remote:FireClient(player, "Toast", "รอสักครู่ก่อนเดินทางอีกครั้ง")
			return
		end
		if player:GetAttribute("InDuel") or player:GetAttribute("InWar") or player:GetAttribute("ArenaRole") then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local target: Vector3? = nil
		if arg == "School" then
			target = Vector3.new(0, 4, 18)
		elseif p.World.Discovered[arg] then
			local f = worldFolder:FindFirstChild("Districts") and worldFolder.Districts:FindFirstChild(arg)
			target = f and f:GetAttribute("StonePos") :: Vector3?
		end
		if target then
			travelAt[player] = now
			root.CFrame = CFrame.new(target)
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end)

local function setup(player: Player)
	for _ = 1, 100 do
		if PlayerData.Get(player) then
			break
		end
		task.wait(0.2)
	end
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	for id in p.World.Discovered do
		player:SetAttribute("Disc_" .. id, true)
	end
	publishTracker(player)
end
Players.PlayerAdded:Connect(setup)
for _, pl in Players:GetPlayers() do
	task.spawn(setup, pl)
end
Players.PlayerRemoving:Connect(function(player)
	visited[player] = nil
	travelAt[player] = nil
end)

-- อัปเดตลูกศรนำทางเป็นระยะ (ตำแหน่งจุดสำรวจที่ใกล้สุดเปลี่ยนตามผู้เล่น)
task.spawn(function()
	while true do
		task.wait(2)
		for _, pl in Players:GetPlayers() do
			publishTracker(pl)
		end
	end
end)
