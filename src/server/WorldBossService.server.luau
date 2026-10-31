--!strict
-- บอสสุ่มเกิดตามแผนที่: ประกาศให้ทุกคน มีลูกศร/ตัวนับเวลา ล้มแล้วดร็อปเหรียญเงินและของหายาก
-- ผู้ที่สร้างดาเมจ >= 4% ของเลือดบอสได้รางวัลตามสัดส่วน (EXP, ชื่อเสียง, โอกาสได้ชุดหายาก/บูสต์ EXP)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Shop = require(ReplicatedStorage.Shared.Shop)
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

local rng = Random.new()
local IS_STUDIO = RunService:IsStudio()

-- ช่วงเวลาเกิดบอส (Studio เร็วขึ้นเพื่อทดสอบ)
local FIRST_SPAWN = if IS_STUDIO then 25 else 120
local MIN_GAP, MAX_GAP = if IS_STUDIO then 90 else 420, if IS_STUDIO then 150 else 720
local BOSS_LIFETIME = 600 -- วินาที ถ้าไม่มีใครล้มได้จะหนีไป
local MIN_SHARE = 0.04

type Tier = { Name: string, Weight: number, LevelBonus: number, HpMult: number, Yen: number, Coins: number, ItemChance: number, Color: string }
local tiers: { Tier } = {
	{ Name = "หัวหน้าแก๊งพเนจร", Weight = 60, LevelBonus = 2, HpMult = 3, Yen = 60, Coins = 14, ItemChance = 0.2, Color = "FFB36B" },
	{ Name = "จอมโหดประจำเมือง", Weight = 30, LevelBonus = 5, HpMult = 5, Yen = 120, Coins = 20, ItemChance = 0.4, Color = "EF233C" },
	{ Name = "ตำนานแก๊งใต้ดิน", Weight = 10, LevelBonus = 9, HpMult = 8, Yen = 260, Coins = 30, ItemChance = 0.8, Color = "9B7BFF" },
}

local function pickTier(): Tier
	local total = 0
	for _, t in tiers do
		total += t.Weight
	end
	local roll = rng:NextNumber(0, total)
	for _, t in tiers do
		roll -= t.Weight
		if roll <= 0 then
			return t
		end
	end
	return tiers[1]
end

-- ตำแหน่งเกิดที่พื้นเรียบ ไม่ซ้อนสิ่งก่อสร้าง
local function findSpawn(d: World.District): Vector3?
	for _ = 1, 30 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = d.Radius * 0.85 * math.sqrt(rng:NextNumber())
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
			for _, p in workspace:GetPartBoundsInBox(CFrame.new(x, res.Position.Y + 5, z), Vector3.new(8, 8, 8), overlap) do
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

local function clearAttributes()
	workspace:SetAttribute("WorldBossAlive", false)
	workspace:SetAttribute("WorldBossName", nil)
	workspace:SetAttribute("WorldBossDistrict", nil)
	workspace:SetAttribute("WorldBossPos", nil)
	workspace:SetAttribute("WorldBossUntil", nil)
end

local trackers: { [any]: { [Player]: number } } = {}
Combat.OnHit(function(attacker, victim, amount)
	local damage = trackers[victim]
	local pl = Players:GetPlayerFromCharacter(attacker.Character)
	if damage and pl then
		damage[pl] = (damage[pl] or 0) + amount
	end
end)

local function reward(tier: Tier, level: number, damage: { [Player]: number }, maxHealth: number, deathPos: Vector3, districtName: string)
	-- ดร็อปเหรียญเงินกระจายให้ทุกคนแย่งเก็บ
	Loot.Coins(deathPos, tier.Yen * level, tier.Coins)
	-- รางวัลต่อคนตามสัดส่วนการสร้างดาเมจ
	local outfits: { string } = {}
	for id, item in Shop.Items do
		if item.Kind == "Outfit" then
			table.insert(outfits, id)
		end
	end
	for player, dealt in damage do
		local p = PlayerData.Get(player)
		if p and player.Parent and dealt >= maxHealth * MIN_SHARE then
			local share = math.clamp(dealt / maxHealth, MIN_SHARE, 1)
			local exp = math.floor(level * 120 * (0.5 + share))
			local lv, ex, pts = Progression.AddExp(p.Level, p.Exp, exp, p.Prestige)
			p.Level, p.Exp = lv, ex
			p.StatPoints += pts
			p.Fame += 20 + math.floor(level / 2)
			p.Yen += math.floor(tier.Yen * level * share * 0.5)
			local gifts: { string } = {}
			if rng:NextNumber() < tier.ItemChance then
				if rng:NextNumber() < 0.5 then
					p.ExpBoostUntil = math.max(os.time(), p.ExpBoostUntil) + 1800
					table.insert(gifts, "บูสต์ EXP 30 นาที")
				else
					local pool: { string } = {}
					for _, id in outfits do
						if not table.find(p.Owned, id) then
							table.insert(pool, id)
						end
					end
					if #pool > 0 then
						local pick = pool[rng:NextInteger(1, #pool)]
						table.insert(p.Owned, pick)
						table.insert(gifts, "ชุด " .. Shop.Items[pick].Name)
					else
						p.Yen += tier.Yen * level
						table.insert(gifts, `เงินพิเศษ ¥{tier.Yen * level}`)
					end
				end
			end
			changed:Fire(player)
			remote:FireClient(player, "Toast", `ล้ม {tier.Name} สำเร็จ! +{exp} EXP` .. (if #gifts > 0 then ` และได้ {table.concat(gifts, ", ")}` else ""))
		end
	end
	announce(`{tier.Name} ที่{districtName} ถูกล้มแล้ว! เหรียญเงินกระจายอยู่บนพื้น`)
end

local function runBoss()
	local d = World.Districts[rng:NextInteger(1, #World.Districts)]
	local pos = findSpawn(d)
	if not pos then
		return
	end
	local tier = pickTier()
	local level = d.Levels[2] + tier.LevelBonus
	local rig = RigFactory.Create(tier.Name, pos + Vector3.new(0, 3, 0), npcs, {
		NpcLevel = level,
		NpcType = "Brute",
		IsBoss = true,
		WorldBoss = true,
		HpMult = tier.HpMult,
		RespawnTime = 1e9,
		District = d.Id,
	}, Color3.fromHex(tier.Color))
	if not rig then
		return
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = `★ {tier.Name}`
	end

	-- รอ NpcService ลงทะเบียนต่อสู้ แล้วเริ่มนับดาเมจ
	local state
	for _ = 1, 40 do
		state = Combat.Get(rig)
		if state then
			break
		end
		task.wait(0.1)
	end
	local damage: { [Player]: number } = {}
	if state then
		trackers[state] = damage
	end

	local expires = workspace:GetServerTimeNow() + BOSS_LIFETIME
	workspace:SetAttribute("WorldBossAlive", true)
	workspace:SetAttribute("WorldBossName", `{tier.Name}  Lv.{level}`)
	workspace:SetAttribute("WorldBossDistrict", d.Name)
	workspace:SetAttribute("WorldBossPos", pos)
	workspace:SetAttribute("WorldBossUntil", expires)
	announce(`บอสสุ่มปรากฏ! {tier.Name} Lv.{level} ที่{d.Name} (ดูลูกศรบนจอ)`)

	local died = false
	if hum then
		hum.Died:Once(function()
			died = true
		end)
	end
	local maxHealth = if hum then hum.MaxHealth else 1
	local lastPos = pos
	local started = os.clock()
	while not died and rig.Parent and os.clock() - started < BOSS_LIFETIME do
		local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			lastPos = root.Position
			workspace:SetAttribute("WorldBossPos", lastPos)
		end
		task.wait(1)
	end

	if state then
		trackers[state] = nil
	end
	if died then
		reward(tier, level, damage, maxHealth, lastPos, d.Name)
		task.delay(4, function()
			rig:Destroy()
		end)
	else
		announce(`{tier.Name} หนีไปแล้ว...`)
		rig:SetAttribute("Despawned", true)
		if hum then
			hum.Health = 0
		end
		task.delay(3.5, function()
			rig:Destroy()
		end)
	end
	clearAttributes()
end

clearAttributes()
task.spawn(function()
	task.wait(FIRST_SPAWN)
	while true do
		if #Players:GetPlayers() > 0 then
			runBoss()
		end
		task.wait(rng:NextNumber(MIN_GAP, MAX_GAP))
	end
end)
