--!strict
-- บอสหัวหน้าชมรมเคนโด้ (เกิดซ้ำทุก 10 นาที ที่โรงยิม) และบอสพเนจรทุกวัน 20:00 (ที่หลังโรงเรียน)
-- ผู้ที่สร้างดาเมจ >= 5% ของเลือดบอสได้รางวัลร่วมกัน: เคนโด้ (ครั้งแรก), ชุดหายาก (สุ่ม), EXP/เงิน/ชื่อเสียง
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Combat = require(script.Parent.Combat)
local LiveOps = require(script.Parent.LiveOps)
local PlayerData = require(script.Parent.PlayerData)
local RigFactory = require(script.Parent.RigFactory)

local CLUB_BOSS_RESPAWN = 600
local MIN_SHARE = 0.05
local SLAM_INTERVAL, SLAM_RADIUS, SLAM_DAMAGE, SLAM_WARNING = 8, 12, 20, 1.2
local ATTACK_RANGE, AGGRO_RANGE = 7, 70

local folder = Instance.new("Folder")
folder.Name = "Bosses"
folder.Parent = workspace

type BossDef = { Name: string, Position: Vector3, Level: number, Color: Color3, DropsStyle: string?, RareOutfit: string }

local CLUB_BOSS: BossDef = {
	Name = "หัวหน้าชมรมเคนโด้",
	Position = Vector3.new(130, 5, 0),
	Level = 5,
	Color = Color3.fromHex("2B2D42"),
	DropsStyle = "Kendo",
	RareOutfit = "Uniform_Night",
}
local WANDERING_BOSS: BossDef = {
	Name = "บอสพเนจร",
	Position = Vector3.new(0, 5, 110),
	Level = 8,
	Color = Color3.fromHex("EF233C"),
	DropsStyle = nil,
	RareOutfit = "Aura_Sparkle",
}

-- ดาเมจที่ผู้เล่นทำต่อบอสแต่ละตัว (listener เดียวตลอดเกม ไม่รั่วเมื่อบอสเกิดใหม่)
local trackers: { [any]: { [Player]: number } } = {}
Combat.OnHit(function(attacker, victim, amount)
	local damage = trackers[victim]
	local pl = Players:GetPlayerFromCharacter(attacker.Character)
	if damage and pl then
		damage[pl] = (damage[pl] or 0) + amount
	end
end)

local function nearestTarget(from: Vector3): BasePart?
	local best: BasePart?, bestDist = nil, AGGRO_RANGE
	for _, pl in Players:GetPlayers() do
		local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and not Combat.InSafeZone(root.Position) then
			local d = (root.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best
end

local function reward(def: BossDef, damage: { [Player]: number }, maxHealth: number)
	for player, dealt in damage do
		local p = PlayerData.Get(player)
		if p and player.Parent and dealt >= maxHealth * MIN_SHARE then
			p.Yen += 300
			p.Fame += 50
			local level, exp, points = Progression.AddExp(p.Level, p.Exp, 500, p.Prestige)
			p.Level, p.Exp = level, exp
			p.StatPoints += points
			if def.DropsStyle and not table.find(p.UnlockedStyles, def.DropsStyle) then
				table.insert(p.UnlockedStyles, def.DropsStyle)
			end
			if math.random() < 0.3 and not table.find(p.Owned, def.RareOutfit) then
				table.insert(p.Owned, def.RareOutfit)
			end
			player:SetAttribute("Yen", p.Yen)
			player:SetAttribute("Level", p.Level)
			player:SetAttribute("Exp", math.floor(p.Exp))
			player:SetAttribute("StatPoints", p.StatPoints)
			player:SetAttribute("Fame", p.Fame)
		end
	end
end

-- ท่ากระแทกพื้น: แจ้งเตือนด้วยวงแดงก่อนโดน ให้ผู้เล่นหลบได้
local function slam(s: any, root: BasePart)
	local ring = Instance.new("Part")
	ring.Anchored, ring.CanCollide, ring.CanQuery = true, false, false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, SLAM_RADIUS * 2, SLAM_RADIUS * 2)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromHex("EF233C")
	ring.Transparency = 0.5
	ring.Material = Enum.Material.Neon
	ring.Parent = workspace
	task.delay(SLAM_WARNING, function()
		ring:Destroy()
		if s.Character.Parent then
			for _, v in Combat.QueryRadius(s, SLAM_RADIUS) do
				Combat.Hit(s, v, SLAM_DAMAGE, { Knockdown = 1 })
			end
		end
	end)
end

local function spawnBoss(def: BossDef)
	local rig = RigFactory.Create(def.Name, def.Position, folder, { NpcLevel = def.Level, IsBoss = true }, def.Color)
	if not rig then
		return
	end
	local s = Combat.Register(rig)
	s.IsBoss = true
	local hum = rig:WaitForChild("Humanoid") :: Humanoid
	local root = rig:WaitForChild("HumanoidRootPart") :: BasePart
	hum.MaxHealth = (100 + 20 * (def.Level - 1)) * 8
	hum.Health = hum.MaxHealth
	hum.DisplayName = def.Name
	rig:SetAttribute("DamageMult", 1 + 0.1 * (def.Level - 1))

	local damage: { [Player]: number } = {}
	trackers[s] = damage

	task.spawn(function()
		local lastSlam = os.clock()
		while hum.Health > 0 and rig.Parent do
			local target = nearestTarget(root.Position)
			if target then
				local dist = (target.Position - root.Position).Magnitude
				if dist > ATTACK_RANGE then
					hum:MoveTo(target.Position)
				else
					hum:MoveTo(root.Position)
					root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.Position.X, root.Position.Y, target.Position.Z))
					Combat.M1(s)
				end
				if os.clock() - lastSlam >= SLAM_INTERVAL then
					lastSlam = os.clock()
					slam(s, root)
				end
			end
			task.wait(0.25)
		end
	end)

	hum.Died:Once(function()
		trackers[s] = nil
		reward(def, damage, hum.MaxHealth)
		task.delay(5, function()
			rig:Destroy()
		end)
	end)
	return rig
end

-- บอสชมรม: เกิดซ้ำเมื่อตายหรือไม่มีในแมพ
task.spawn(function()
	while true do
		if LiveOps.Flags.ClubBoss ~= false then
			local boss = spawnBoss(CLUB_BOSS)
			if boss then
				local hum = boss:FindFirstChildOfClass("Humanoid")
				while hum and hum.Health > 0 and boss.Parent do
					task.wait(2)
				end
			end
		end
		task.wait(CLUB_BOSS_RESPAWN)
	end
end)

-- บอสพเนจร 20:00 นาน 15 นาที
task.spawn(function()
	local active: Model? = nil
	while true do
		task.wait(10)
		if LiveOps.WanderingBossActive() then
			if not active or not active.Parent then
				active = spawnBoss(WANDERING_BOSS)
			end
		elseif active then
			active:Destroy()
			active = nil
		end
	end
end)
