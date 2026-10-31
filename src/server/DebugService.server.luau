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
	p.TutorialDone = true
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
