--!strict
-- โหมดทดสอบ: ทำงานเฉพาะใน Roblox Studio เท่านั้น (เกมที่เผยแพร่ไม่มีผล)
-- ผู้เล่นเริ่มด้วยค่าสูงเพื่อทดสอบสกิล/ไม้ตาย/Prestige ได้ทันที ปรับตัวเลขด้านล่างได้
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	return
end

local DEBUG = {
	Level = 100,
	StatPoints = 300,
	Yen = 99999,
	Mastery = 100, -- ทุกสไตล์ (สกิลทุกปุ่ม + ไม้ตายใช้ได้ทันที)
	UltFull = true, -- หลอดไม้ตายเต็มตอนเกิด
}

local Progression = require(game.ReplicatedStorage.Shared.Progression)
local StyleData = require(game.ReplicatedStorage.Shared.Styles)
local Passives = require(game.ReplicatedStorage.Shared.Passives)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local changed = ServerStorage:WaitForChild("ProfileChanged") :: BindableEvent

local function boost(player: Player)
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
	p.Level = DEBUG.Level
	p.Exp = 0
	p.StatPoints = math.max(p.StatPoints, DEBUG.StatPoints)
	p.Yen = math.max(p.Yen, DEBUG.Yen)
	p.UnlockedStyles = {}
	for id in StyleData.Styles do
		table.insert(p.UnlockedStyles, id)
		p.Mastery[id] = { Level = DEBUG.Mastery, Exp = 0 }
	end
	-- ลงแต้มสเตตัสให้เต็มทุกช่อง (แบ่งเท่าๆ กัน) แล้วใส่พาสซีฟให้เต็มทุกช่อง
	local statNames = { "Strength", "Health", "Stamina", "Speed" }
	local share = math.floor(DEBUG.StatPoints / #statNames) -- ตั้งค่าตายตัว (ไม่บวกซ้ำทุกครั้งที่เข้าเกม)
	for _, name in statNames do
		(p.Stats :: any)[name] = share
	end
	p.StatPoints = DEBUG.StatPoints - share * #statNames
	table.clear(p.Passives)
	local ids = {}
	for id in Passives.All do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		if #p.Passives < Passives.MaxSlots and Passives.CanEquip(p.Level, id) then
			table.insert(p.Passives, id)
		end
	end
	p.TutorialDone = true
	for _, id in require(game.ReplicatedStorage.Shared.Outfits).Order do
		if not table.find(p.Owned, id) then
			table.insert(p.Owned, id) -- ทดสอบสวมทุกชุดได้ทันที
		end
	end
	for _, d in require(game.ReplicatedStorage.Shared.World).Districts do
		p.World.Discovered[d.Id] = true -- ทดสอบเดินทางด่วนได้ทุกย่าน
		player:SetAttribute("Disc_" .. d.Id, true)
	end
	changed:Fire(player)
	warn(`[Debug] Studio test boost: Lv.{p.Level}, Mastery {DEBUG.Mastery}, styles {#p.UnlockedStyles}, Yen {p.Yen}`)
end

local function fillUlt(player: Player)
	if not DEBUG.UltFull then
		return
	end
	task.wait(1)
	local s = Combat.Get(player.Character)
	if s then
		s.Ult = 100
	end
end

local function onPlayer(player: Player)
	task.spawn(boost, player)
	player.CharacterAdded:Connect(function()
		task.spawn(fillUlt, player)
	end)
	if player.Character then
		task.spawn(fillUlt, player)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end

-- ตัวช่วยทดสอบ: ยิง DebugKill:Fire(ผู้เล่น, โมเดลศัตรู) เพื่อให้ผู้เล่นฆ่าศัตรูผ่าน Combat.Hit จริง (ตั้ง LastAttacker ครบ)
local killEvent = Instance.new("BindableEvent")
killEvent.Name = "DebugKill"
killEvent.Parent = ServerStorage
killEvent.Event:Connect(function(player: Player, victim: Model)
	local a = Combat.Get(player.Character)
	local v = Combat.Get(victim)
	if a and v then
		Combat.Hit(a, v, 1e6)
	end
end)
