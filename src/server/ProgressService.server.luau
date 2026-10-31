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

local menu = Instance.new("RemoteEvent")
menu.Name = "MenuRemote"
menu.Parent = ReplicatedStorage

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
	player:SetAttribute("Style", p.EquippedStyle)
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
	char:SetAttribute("DamageMult", 1 + 0.02 * p.Stats.Strength)
	char:SetAttribute("MaxStamina", Config.BaseStamina + 5 * p.Stats.Stamina)
	s.Equipped = table.clone(p.Passives)
end

local function addExp(player: Player, amount: number)
	local p = PlayerData.Get(player)
	if not p then
		return
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
	p.Yen += if victimPlayer then 25 else 10 * npcLevel
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

-- replicate หลอดพลังงาน/ท่าไม้ตายให้ HUD
task.spawn(function()
	while true do
		task.wait(0.1)
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local s = Combat.Get(char)
			if char and s then
				char:SetAttribute("Stamina", s.Stamina)
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
