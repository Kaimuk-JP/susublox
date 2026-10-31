--!strict
-- เลเวล, EXP, Mastery, สเตตัส, Prestige, อันดับ, รางวัลจากการฆ่า และ remote สำหรับเมนู
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Passives = require(ReplicatedStorage.Shared.Passives)
local Progression = require(ReplicatedStorage.Shared.Progression)
local StyleData = require(ReplicatedStorage.Shared.Styles)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local LiveOps = require(script.Parent.LiveOps)

local menu = Instance.new("RemoteEvent")
menu.Name = "MenuRemote"
menu.Parent = ReplicatedStorage

-- ให้บริการอื่น (เช่นโหมดทดสอบ) สั่งรีเฟรชโปรไฟล์ -> ตัวละคร/Attribute
local profileChanged = Instance.new("BindableEvent")
profileChanged.Name = "ProfileChanged"
profileChanged.Parent = game:GetService("ServerStorage")

local ranks = {
	{ Fame = 2000, Title = "ราชาโรงเรียน" },
	{ Fame = 500, Title = "หัวหน้าแก๊ง" },
	{ Fame = 100, Title = "หัวหน้าห้อง" },
	{ Fame = 0, Title = "นักเรียนปี 1" },
}

local function rankOf(fame: number): string
	for _, r in ranks do
		if fame >= r.Fame then
			return r.Title
		end
	end
	return ranks[#ranks].Title
end

-- ส่งค่าไป Attribute เพื่อให้ HUD อ่านได้
local function replicate(player: Player)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	player:SetAttribute("Level", p.Level)
	player:SetAttribute("Exp", math.floor(p.Exp))
	player:SetAttribute("ExpNeeded", Progression.ExpForLevel(p.Level))
	player:SetAttribute("Yen", p.Yen)
	player:SetAttribute("Fame", p.Fame)
	player:SetAttribute("Rank", rankOf(p.Fame))
	player:SetAttribute("StatPoints", p.StatPoints)
	-- ตารางอันดับมุมขวาบน (leaderstats ของ Roblox)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	for name, value in { Lv = p.Level, Fame = p.Fame, Wins = p.Wins, Rank = p.RankPoints } do
		local v = ls:FindFirstChild(name) :: IntValue?
		if not v then
			v = Instance.new("IntValue")
			v.Name = name
			v.Parent = ls
		end
		(v :: IntValue).Value = value
	end
	player:SetAttribute("Style", p.EquippedStyle)
	-- สถานะสกิลติดตัวที่ใส่อยู่ (ให้เมนูแสดง ✓ และจำนวนช่อง)
	for id in Passives.All do
		player:SetAttribute("Passive_" .. id, table.find(p.Passives, id) ~= nil)
	end
	player:SetAttribute("PassiveSlots", #p.Passives)
	for stat, value in p.Stats :: any do
		player:SetAttribute("Stat_" .. stat, value)
	end
	for id in StyleData.Styles do
		player:SetAttribute("StyleUnlocked_" .. id, table.find(p.UnlockedStyles, id) ~= nil)
	end
	if player.Character then
		player.Character:SetAttribute("Style", p.EquippedStyle) -- ให้ทุกคนเห็นขอบสีสไตล์
	end
	player:SetAttribute("Prestige", p.Prestige)
	local m = p.Mastery[p.EquippedStyle]
	player:SetAttribute("MasteryLevel", m and m.Level or 1)
end

-- ใช้สเตตัสและพาสซีฟกับตัวละคร
local function applyToCharacter(player: Player)
	local p, char = PlayerData.Get(player), player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local s = Combat.Get(char)
	if not p or not char or not hum or not s then
		return
	end
	local ratio = hum.Health / hum.MaxHealth
	hum.MaxHealth = Config.BaseHealth + 5 * p.Stats.Health
	hum.Health = hum.MaxHealth * ratio
	hum.WalkSpeed = 16 + 0.3 * p.Stats.Speed
	char:SetAttribute("DamageMult", 1 + 0.05 * p.Stats.Strength) -- +5% ต่อแต้ม (ดูตัวเลขจริงในเมนูสเตตัส)
	char:SetAttribute("MaxStamina", Config.BaseStamina + 5 * p.Stats.Stamina)
	char:SetAttribute("MaxMana", Config.BaseMana + 5 * p.Stats.Stamina)
	s.Equipped = table.clone(p.Passives)
end

local function addExp(player: Player, amount: number)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	amount *= LiveOps.ExpMultiplier()
	if p.Passes.Exp2x then
		amount *= 2
	end
	if os.time() < p.ExpBoostUntil then
		amount *= 2
	end
	local level, exp, points = Progression.AddExp(p.Level, p.Exp, amount, p.Prestige)
	p.Level, p.Exp = level, exp
	p.StatPoints += points
	replicate(player)
end

local function addMastery(player: Player, amount: number)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	local id = p.EquippedStyle
	local m = p.Mastery[id]
	if not m then
		m = { Level = 1, Exp = 0 }
		p.Mastery[id] = m
	end
	if m.Level >= StyleData.MaxMastery then
		return
	end
	m.Exp += amount
	while m.Level < StyleData.MaxMastery and m.Exp >= StyleData.MasteryExp(m.Level) do
		m.Exp -= StyleData.MasteryExp(m.Level)
		m.Level += 1
	end
	player:SetAttribute("MasteryLevel", m.Level)
end

-- ได้ Mastery จากการตีโดน
Combat.OnHit(function(attacker)
	local player = Players:GetPlayerFromCharacter(attacker.Character)
	if player then
		addMastery(player, 1)
	end
end)

-- รางวัลจากการฆ่า
Combat.OnKill(function(killer, victim)
	local player = Players:GetPlayerFromCharacter(killer.Character)
	local p = player and PlayerData.Get(player)
	if not player or not p then
		return
	end
	local victimPlayer = Players:GetPlayerFromCharacter(victim.Character)
	local npcLevel = (victim.Character:GetAttribute("NpcLevel") :: number?) or 1
	local exp = if victimPlayer then 50 else 30 * npcLevel * (if victim.IsBoss then 5 else 1)

	-- โบนัสเล่นเป็นทีม: มีผู้เล่นอื่นอยู่ใกล้ (60 studs) คนละ +15% สูงสุด +45%
	local killerRoot = killer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local allies = 0
	if killerRoot then
		for _, other in Players:GetPlayers() do
			local oroot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if oroot and (oroot.Position - killerRoot.Position).Magnitude <= 60 then
				allies += 1
			end
		end
	end
	local mult = 1 + math.min(allies, 3) * 0.15
	-- โบนัสรายวัน: ศัตรู 5 ตัวแรกของวัน EXP x2 (รีเซ็ตทุกวัน ให้มีเหตุผลกลับมาเล่นทุกวัน)
	local today = os.time() // 86400
	if p.DailyBonus.Day ~= today then
		p.DailyBonus.Day, p.DailyBonus.Used = today, 0
	end
	if not victimPlayer and p.DailyBonus.Used < 5 then
		mult *= 2
		p.DailyBonus.Used += 1
	end
	player:SetAttribute("DailyBonusLeft", math.max(0, 5 - p.DailyBonus.Used))
	player:SetAttribute("PartyBonus", allies)
	exp = math.floor(exp * mult)
	p.Yen += math.floor((if victimPlayer then 25 else 10 * npcLevel) * LiveOps.YenMultiplier())
	p.Fame += if victimPlayer then 10 else (if victim.IsBoss then 50 else 5)
	p.Wins += 1
	addExp(player, exp)
	if victimPlayer then
		local vp = PlayerData.Get(victimPlayer)
		if vp then
			vp.Losses += 1
		end
	end
	applyToCharacter(player)
end)

local function setup(player: Player)
	local profile = PlayerData.Load(player)
	if not profile then
		player:Kick("โหลดข้อมูลไม่สำเร็จ ลองเข้าใหม่อีกครั้ง")
		return
	end
	replicate(player)
	local function onChar(char: Model)
		char:WaitForChild("Humanoid")
		task.wait() -- ให้ CombatService ลงทะเบียนก่อน
		applyToCharacter(player)
		replicate(player)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		task.spawn(onChar, player.Character)
	end
end

Players.PlayerAdded:Connect(setup)
for _, p in Players:GetPlayers() do
	task.spawn(setup, p)
end

profileChanged.Event:Connect(function(player: Player)
	applyToCharacter(player)
	replicate(player)
end)

-- replicate หลอดพลังงาน/ท่าไม้ตายให้ HUD
task.spawn(function()
	while true do
		task.wait(0.1)
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local s = Combat.Get(char)
			if char and s then
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				player:SetAttribute("InSafeZone", root ~= nil and Combat.InSafeZone(root.Position))
				char:SetAttribute("Stamina", s.Stamina)
				char:SetAttribute("Mana", s.Mana)
				char:SetAttribute("Ult", s.Ult)
			end
		end
	end
end)

-- เมนู: ลงสเตตัส, เปลี่ยนสไตล์, ใส่พาสซีฟ, Prestige
menu.OnServerEvent:Connect(function(player: Player, action: unknown, arg: unknown)
	local p = PlayerData.Get(player)
	if not p or typeof(action) ~= "string" then
		return
	end
	if action == "AddStat" and typeof(arg) == "string" then
		if p.StatPoints > 0 and (p.Stats :: any)[arg] ~= nil then
			(p.Stats :: any)[arg] += 1
			p.StatPoints -= 1
		end
	elseif action == "EquipStyle" and typeof(arg) == "string" then
		if table.find(p.UnlockedStyles, arg) and StyleData.Styles[arg] then
			p.EquippedStyle = arg
		end
	elseif action == "EquipPassive" and typeof(arg) == "string" then
		local idx = table.find(p.Passives, arg)
		if idx then
			table.remove(p.Passives, idx)
		elseif #p.Passives < Passives.MaxSlots and Passives.CanEquip(p.Level, arg) then
			table.insert(p.Passives, arg)
		end
	elseif action == "Prestige" then
		if p.Level >= Progression.MaxLevel then
			p.Prestige += 1
			p.Level, p.Exp, p.StatPoints = 1, 0, 0
			p.Stats = { Strength = 0, Health = 0, Stamina = 0, Speed = 0 }
		end
	end
	applyToCharacter(player)
	replicate(player)
end)

-- ปลดล็อกสไตล์ตามเลเวล (เช็กเมื่อเลเวลเปลี่ยน)
Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local p = PlayerData.Get(player)
		if not p then
			return
		end
		for id, style in StyleData.Styles do
			if style.UnlockLevel and p.Level >= style.UnlockLevel and not table.find(p.UnlockedStyles, id) then
				table.insert(p.UnlockedStyles, id)
			end
		end
	end)
end)
