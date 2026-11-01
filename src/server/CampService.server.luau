--!strict
-- ค่ายแก๊งประจำย่าน: ย่านละ 2 ค่าย กลุ่มศัตรูมีหัวหน้ากลุ่ม เคลียร์หมดแล้วได้โบนัส (เงิน เหรียญ EXP ชื่อเสียง)
-- ค่ายเกิดเมื่อผู้เล่นเข้าใกล้ หายเมื่อห่างไกล และเกิดใหม่หลังเคลียร์ครบ 4 นาที
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local World = require(ReplicatedStorage.Shared.World)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local PlayerData = require(script.Parent.PlayerData)
local RigFactory = require(script.Parent.RigFactory)

local remote = ReplicatedStorage:WaitForChild("WorldRemote") :: RemoteEvent
local changed = ServerStorage:WaitForChild("ProfileChanged") :: BindableEvent
local npcs = workspace:WaitForChild("Npcs")
local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end

local rng = Random.new(2024)
local CAMPS_PER_DISTRICT = 2
local CAMP_RESPAWN = 240
local SPAWN_NEAR, DESPAWN_FAR, DESPAWN_AFTER = 250, 520, 45

type Camp = {
	Key: string,
	District: World.District,
	Center: Vector3,
	Spawned: boolean,
	Spawning: boolean,
	ClearedAt: number,
	LastNear: number,
}
local camps: { Camp } = {}
local byKey: { [string]: Camp } = {}

local function horizontal(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function clearGround(d: World.District, x: number, z: number, margin: number): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npcs }
	local res = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), params)
	if not res or res.Material == Enum.Material.Water then
		return nil
	end
	if res.Position.Y > (if d.Theme == "temple" then 30 else 2) then
		return nil
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { npcs }
	for _, p in workspace:GetPartBoundsInBox(CFrame.new(x, res.Position.Y + 5, z), Vector3.new(margin, 8, margin), overlap) do
		if p.CanCollide then
			return nil
		end
	end
	return res.Position
end

-- เลือกที่ตั้งค่าย (พื้นที่โล่งกว้างพอ) + สร้างธง/ป้าย/กองไฟ/ลังเป็นของตกแต่งถาวร
local propsFolder = Instance.new("Folder")
propsFolder.Name = "Camps"
propsFolder.Parent = worldFolder

local function buildProps(c: Camp)
	local d, pos = c.District, c.Center
	local color = Color3.fromHex(d.EnemyColor)
	local function part(name: string, size: Vector3, p: Vector3, col: Color3, material: Enum.Material?): Part
		local x = Instance.new("Part")
		x.Name = name
		x.Anchored = true
		x.Size = size
		x.Position = p
		x.Color = col
		x.Material = material or Enum.Material.SmoothPlastic
		x.Parent = propsFolder
		return x
	end
	local pole = part("CampPole", Vector3.new(0.6, 16, 0.6), pos + Vector3.new(0, 8, 0), Color3.fromHex("C9CED6"), Enum.Material.Metal)
	pole.Shape = Enum.PartType.Block
	part("CampFlag", Vector3.new(6, 4, 0.2), pos + Vector3.new(3.3, 13.5, 0), color)
	local sign = part("CampSign", Vector3.new(11, 2.2, 0.3), pos + Vector3.new(0, 5, -4), Color3.fromHex("1A1A22"))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = `ค่ายแก๊ง{d.EnemyName}`
	label.TextColor3 = color
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	part("CampSignPost", Vector3.new(0.5, 5, 0.5), pos + Vector3.new(-4.5, 2.5, -4), Color3.fromHex("8D6E63"), Enum.Material.Wood)
	part("CampSignPost", Vector3.new(0.5, 5, 0.5), pos + Vector3.new(4.5, 2.5, -4), Color3.fromHex("8D6E63"), Enum.Material.Wood)
	-- ลังและกองไฟ
	for i = 1, 3 do
		part("CampCrate", Vector3.new(3, 3, 3), pos + Vector3.new(-7 + i * 2.2, 1.5, 6 + (i % 2) * 1.5), Color3.fromHex("D9B382"), Enum.Material.Wood)
	end
	local fire = part("CampFire", Vector3.new(2, 2, 2), pos + Vector3.new(6, 1, 4), Color3.fromHex("FF8A3D"), Enum.Material.Neon)
	fire.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = fire.Color
	light.Range = 26
	light.Brightness = 1.4
	light.Parent = fire
end

for _, d in World.Districts do
	for i = 1, CAMPS_PER_DISTRICT do
		local found: Vector3? = nil
		-- ย่านแน่น (ตึกเต็มริมถนน): ลองลานโล่งที่กำหนดใน World.Plazas ก่อน (ลานที่ i ของย่านนี้) แล้วค่อยสุ่ม
		local plaza: { any }? = nil
		local n = 0
		for _, pz in World.Plazas do
			if pz[5] == d.Id then
				n += 1
				if n == i then
					plaza = pz
				end
			end
		end
		for attempt = 1, 60 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = d.Radius * 0.8 * math.sqrt(rng:NextNumber())
			local x, z = d.Center.X + math.cos(a) * r, d.Center.Z + math.sin(a) * r
			if plaza and attempt <= 15 then
				x, z = (plaza[1] + plaza[2]) / 2 + rng:NextNumber(-3, 3), (plaza[3] + plaza[4]) / 2 + rng:NextNumber(-3, 3)
			end
			local p = clearGround(d, x, z, 22)
			local ok = p ~= nil
			if p then
				for _, other in camps do
					if horizontal(other.Center, p) < 70 then
						ok = false
					end
				end
				if horizontal(p, d.Center + d.GiverOffset) < 40 then
					ok = false
				end
			end
			if ok then
				found = p
				break
			end
		end
		if found then
			local c: Camp = {
				Key = `{d.Id}_{i}`,
				District = d,
				Center = found,
				Spawned = false,
				Spawning = false,
				ClearedAt = -math.huge,
				LastNear = 0,
			}
			table.insert(camps, c)
			byKey[c.Key] = c
			buildProps(c)
		end
	end
end

local function spawnCamp(c: Camp)
	if c.Spawned or c.Spawning then
		return
	end
	c.Spawning = true
	local d = c.District
	local level = d.Levels[2]
	-- ทหารในค่าย 6 คน + หัวหน้ากลุ่ม 1 คน
	for i = 1, 7 do
		local leader = i == 7
		-- หัวหน้ายืนด้านที่ไม่มีธง/ลัง/ป้าย (ฝั่ง -X) ไม่งั้น raycast ชนธงแล้วไม่เกิด
		local a = if leader then math.pi else (i / 7) * math.pi * 2
		local r = if leader then 5 else rng:NextNumber(8, 15)
		local pos = clearGround(d, c.Center.X + math.cos(a) * r, c.Center.Z + math.sin(a) * r, 4)
		if pos then
			local npcType = if leader then "Brute" else (if i % 3 == 0 then "Speedy" else "Grunt")
			local name = if leader then `หัวหน้ากลุ่ม{d.EnemyName}` else d.EnemyName
			local rig = RigFactory.Create(name, pos + Vector3.new(0, 3, 0), npcs, {
				NpcLevel = if leader then level + 2 else level,
				NpcType = npcType,
				District = d.Id,
				Camp = c.Key,
				CampLeader = leader,
				RespawnTime = 1e9, -- ทั้งค่ายเกิดใหม่พร้อมกัน ไม่เกิดทีละตัว
				HpMult = if leader then 3 else nil,
			}, Color3.fromHex(d.EnemyColor))
			if rig then
				local hum = rig:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.DisplayName = name
				end
			end
		end
	end
	c.Spawned = true
	c.Spawning = false
end

local function despawnCamp(c: Camp)
	c.Spawned = false
	for _, m in npcs:GetChildren() do
		if m:GetAttribute("Camp") == c.Key then
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
end

-- เคลียร์ค่ายแล้ว: ใครอยู่ใกล้ได้โบนัส
local function onCleared(c: Camp)
	c.Spawned = false
	c.ClearedAt = os.clock()
	local level = c.District.Levels[2]
	Loot.Coins(c.Center + Vector3.new(0, 1, 0), level * 45, 12)
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local p = PlayerData.Get(player)
		if root and p and horizontal(root.Position, c.Center) < 90 then
			local exp = level * 40
			local lv, ex, pts = Progression.AddExp(p.Level, p.Exp, exp, p.Prestige)
			p.Level, p.Exp = lv, ex
			p.StatPoints += pts
			p.Yen += level * 20
			p.Fame += 8
			changed:Fire(player)
			-- นับเข้าเนื้อเรื่อง/ใบสั่งล่า
			local storyEvent = ServerStorage:FindFirstChild("StoryEvent") :: BindableEvent?
			if storyEvent then
				storyEvent:Fire(player, "CampCleared", c.District.Id)
			end
			remote:FireClient(player, "Toast", `เคลียร์ค่ายแก๊ง{c.District.EnemyName}! +{exp} EXP +¥{level * 20}`)
		end
	end
end

Combat.OnKill(function(_killer, victim)
	local key = victim.Character:GetAttribute("Camp")
	if typeof(key) ~= "string" or victim.Character:GetAttribute("Despawned") == true then
		return
	end
	local c = byKey[key]
	if not c then
		return
	end
	-- เหลือสมาชิกค่ายที่ยังมีชีวิตอยู่ไหม
	task.defer(function()
		for _, m in npcs:GetChildren() do
			local hum = m:FindFirstChildOfClass("Humanoid")
			if m:GetAttribute("Camp") == key and hum and hum.Health > 0 and m ~= victim.Character then
				return
			end
		end
		if c.Spawned then
			onCleared(c)
		end
	end)
end)

task.spawn(function()
	while true do
		task.wait(3)
		for _, c in camps do
			local nearest = math.huge
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					nearest = math.min(nearest, horizontal(root.Position, c.Center))
				end
			end
			if nearest <= SPAWN_NEAR then
				c.LastNear = os.clock()
				if not c.Spawned and not c.Spawning and os.clock() - c.ClearedAt >= CAMP_RESPAWN then
					task.spawn(spawnCamp, c)
				end
			elseif c.Spawned and nearest > DESPAWN_FAR and os.clock() - c.LastNear > DESPAWN_AFTER then
				despawnCamp(c)
			end
		end
	end
end)
