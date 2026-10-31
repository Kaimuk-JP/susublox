--!strict
-- เหตุการณ์สุ่มกลางเมือง (นอกเหนือจากบอสสุ่ม): ทุก 3-6 นาทีมีเหตุการณ์หนึ่งเกิดในย่านสุ่ม ประกาศให้ทุกคนทราบ
--   1) "ขบวนส่งเงิน" หีบสมบัติเรืองแสงเกิดที่จุดสุ่ม (ใครไปถึงก่อนเก็บได้ มีนักเลงเฝ้า 4 คน)
--   2) "ศึกชิงถนน": นักเลงกลุ่มใหญ่ 10 คนบุกยึดถนนของย่าน ล้มให้หมดภายใน 5 นาทีได้รางวัลใหญ่ทุกคนที่ร่วม
-- ทุกเหตุการณ์มีลูกศรบนจอ (ใช้ Attribute CityEvent* ของ Workspace) และหมดเวลาแล้วหายไปเอง
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local World = require(ReplicatedStorage.Shared.World)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local PlayerData = require(script.Parent.PlayerData)
local RigFactory = require(script.Parent.RigFactory)

local remote = ReplicatedStorage:WaitForChild("WorldRemote", 60) :: RemoteEvent
local changed = ServerStorage:WaitForChild("ProfileChanged") :: BindableEvent
local npcs = workspace:WaitForChild("Npcs")
local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end

local rng = Random.new()
local IS_STUDIO = RunService:IsStudio()
local FIRST = if IS_STUDIO then 45 else 150
local GAP_MIN, GAP_MAX = if IS_STUDIO then 120 else 180, if IS_STUDIO then 200 else 360
local EVENT_TIME = 300

local function findSpot(d: World.District): Vector3?
	for _ = 1, 30 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = d.Radius * 0.8 * math.sqrt(rng:NextNumber())
		local x, z = d.Center.X + math.cos(a) * r, d.Center.Z + math.sin(a) * r
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { npcs }
		local res = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), params)
		if res and res.Material ~= Enum.Material.Water and res.Position.Y <= (if d.Theme == "temple" then 30 else 2) then
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Exclude
			overlap.FilterDescendantsInstances = { npcs }
			local clear = true
			for _, p in workspace:GetPartBoundsInBox(CFrame.new(x, res.Position.Y + 5, z), Vector3.new(10, 8, 10), overlap) do
				if p.CanCollide then
					clear = false
					break
				end
			end
			if clear then
				return res.Position
			end
		end
	end
	return nil
end

local function announce(text: string)
	remote:FireAllClients("Toast", text)
end

local function setEvent(name: string?, districtName: string?, pos: Vector3?, untilAt: number?)
	workspace:SetAttribute("CityEventName", name)
	workspace:SetAttribute("CityEventDistrict", districtName)
	workspace:SetAttribute("CityEventPos", pos)
	workspace:SetAttribute("CityEventUntil", untilAt)
end

local function guards(d: World.District, center: Vector3, count: number, levelBonus: number, tag: string): { Model }
	local out: { Model } = {}
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local r = rng:NextNumber(8, 16)
		local pos = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { npcs }
		local res = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), params)
		if res and res.Material ~= Enum.Material.Water and res.Position.Y < 3 then
			local rig = RigFactory.Create(d.EnemyName, res.Position + Vector3.new(0, 3, 0), npcs, {
				NpcLevel = d.Levels[2] + levelBonus,
				NpcType = if i % 4 == 0 then "Brute" elseif i % 3 == 0 then "Speedy" else "Grunt",
				District = d.Id,
				RespawnTime = 1e9,
				EventTag = tag,
			}, Color3.fromHex(d.EnemyColor))
			if rig then
				local hum = rig:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.DisplayName = d.EnemyName
				end
				table.insert(out, rig)
			end
		end
	end
	return out
end

local function aliveCount(tag: string): number
	local n = 0
	for _, m in npcs:GetChildren() do
		local hum = m:FindFirstChildOfClass("Humanoid")
		if m:GetAttribute("EventTag") == tag and hum and hum.Health > 0 then
			n += 1
		end
	end
	return n
end

local function clearTag(tag: string)
	for _, m in npcs:GetChildren() do
		if m:GetAttribute("EventTag") == tag then
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

local function rewardNear(center: Vector3, radius: number, level: number, text: string)
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local p = PlayerData.Get(player)
		if root and p and Vector2.new(root.Position.X - center.X, root.Position.Z - center.Z).Magnitude < radius then
			local exp = level * 90
			local lv, ex, pts = Progression.AddExp(p.Level, p.Exp, exp, p.Prestige)
			p.Level, p.Exp = lv, ex
			p.StatPoints += pts
			p.Yen += level * 40
			p.Fame += 12
			changed:Fire(player)
			remote:FireClient(player, "Toast", `{text} +{exp} EXP +¥{level * 40}`)
		end
	end
end

---------------------------------------------------------------- เหตุการณ์ 1: ขบวนส่งเงิน (หีบสมบัติ)
local function treasureConvoy()
	local d = World.Districts[rng:NextInteger(1, #World.Districts)]
	local pos = findSpot(d)
	if not pos then
		return
	end
	local tag = "convoy_" .. os.time()
	local chest = Instance.new("Part")
	chest.Name = "ConvoyChest"
	chest.Size = Vector3.new(4, 3, 3)
	chest.Anchored = true
	chest.Material = Enum.Material.Metal
	chest.Color = Color3.fromHex("FFE066")
	chest.Position = pos + Vector3.new(0, 1.6, 0)
	chest.Parent = workspace
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromHex("FFE066")
	glow.Range = 30
	glow.Brightness = 2
	glow.Parent = chest
	local guardList = guards(d, pos, 4, 2, tag)
	local level = d.Levels[2]
	local opened = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "เปิดหีบ"
	prompt.ObjectText = "ขบวนส่งเงิน"
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = chest
	prompt.Triggered:Connect(function(player)
		if opened then
			return
		end
		if aliveCount(tag) > 0 then
			remote:FireClient(player, "Toast", "ล้มนักเลงที่เฝ้าหีบให้หมดก่อน!")
			return
		end
		opened = true
		Loot.Coins(chest.Position, level * 120, 20)
		local p = PlayerData.Get(player)
		if p then
			p.Fame += 15
			changed:Fire(player)
		end
		remote:FireAllClients("Toast", `{player.DisplayName} เปิดหีบขบวนส่งเงินที่{d.Name}ได้แล้ว!`)
		chest:Destroy()
	end)
	local untilAt = workspace:GetServerTimeNow() + EVENT_TIME
	setEvent(`ขบวนส่งเงิน (หีบสมบัติ)`, d.Name, pos, untilAt)
	announce(`ขบวนส่งเงินปรากฏที่{d.Name}! ล้มผู้คุมแล้วเปิดหีบชิงเงิน (ดูลูกศรบนจอ)`)
	local started = os.clock()
	while not opened and os.clock() - started < EVENT_TIME do
		task.wait(2)
	end
	if not opened then
		announce("ขบวนส่งเงินหนีไปแล้ว...")
		chest:Destroy()
	end
	clearTag(tag)
	setEvent(nil, nil, nil, nil)
	for _, m in guardList do
		if m.Parent then
			m:SetAttribute("Despawned", true)
		end
	end
end

---------------------------------------------------------------- เหตุการณ์ 2: ศึกชิงถนน
local function streetWar()
	local d = World.Districts[rng:NextInteger(1, #World.Districts)]
	local pos = findSpot(d)
	if not pos then
		return
	end
	local tag = "war_" .. os.time()
	guards(d, pos, 10, 1, tag)
	local untilAt = workspace:GetServerTimeNow() + EVENT_TIME
	setEvent("ศึกชิงถนน (ล้มนักเลง 10 คน)", d.Name, pos, untilAt)
	announce(`ศึกชิงถนนที่{d.Name}! นักเลงกลุ่มใหญ่บุกยึดถนน ล้มให้หมดก่อนหมดเวลา`)
	local started = os.clock()
	local total = aliveCount(tag)
	while os.clock() - started < EVENT_TIME do
		task.wait(2)
		if aliveCount(tag) == 0 and total > 0 then
			break
		end
	end
	if aliveCount(tag) == 0 and total > 0 then
		Loot.Coins(pos + Vector3.new(0, 1, 0), d.Levels[2] * 150, 24)
		rewardNear(pos, 80, d.Levels[2], "ชนะศึกชิงถนน!")
		announce(`ศึกชิงถนนที่{d.Name}จบลง นักเลงพ่ายแพ้แล้ว!`)
	else
		announce("นักเลงยึดถนนสำเร็จ... (หมดเวลา)")
	end
	clearTag(tag)
	setEvent(nil, nil, nil, nil)
end

setEvent(nil, nil, nil, nil)
task.spawn(function()
	task.wait(FIRST)
	while true do
		if #Players:GetPlayers() > 0 then
			if rng:NextNumber() < 0.5 then
				treasureConvoy()
			else
				streetWar()
			end
		end
		task.wait(rng:NextNumber(GAP_MIN, GAP_MAX))
	end
end)
