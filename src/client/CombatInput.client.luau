--!strict
-- อินพุตต่อสู้: ส่งคำสั่งไป server และ "ทำนายท่า" ฝั่ง client ทันที (ไม่รอ server) เพื่อให้กดแล้วขยับในเฟรมเดียวกัน
-- server ยังเป็นผู้ตัดสินดาเมจ/คูลดาวน์/สถานะ ถ้าถูกปฏิเสธ ท่าที่ทำนายไว้เป็นแค่ภาพ ไม่มีผลต่อเกม
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local remote = ReplicatedStorage:WaitForChild("CombatRemote") :: RemoteEvent
local player = Players.LocalPlayer

local combo, lastM1, lastDash = 0, 0, 0
local localId = 0

-- ตั้ง Attribute ท่าแบบ local (ลงท้าย ":L<เลข>" ให้ ProceduralAnim รู้ว่าเป็นท่าที่ทำนาย) ไม่ replicate ไป server
local function predict(name: string)
	local char = player.Character
	if char then
		localId += 1
		char:SetAttribute("Anim", `{name}:L{localId}`)
	end
end

local function handler(name: string, state: Enum.UserInputState)
	if name == "M1" and state == Enum.UserInputState.Begin then
		remote:FireServer("M1")
		local now = os.clock()
		if now - lastM1 >= Config.M1Cooldown then
			if now - lastM1 > Config.ComboResetTime then
				combo = 0
			end
			combo += 1
			lastM1 = now
			local n = if combo >= Config.ComboLength then Config.ComboLength else combo
			if combo >= Config.ComboLength then
				combo = 0
			end
			predict(`M1_{n}`)
		end
	elseif name == "Block" then
		if state == Enum.UserInputState.Begin then
			remote:FireServer("BlockStart")
			predict("Block")
		elseif state == Enum.UserInputState.End then
			remote:FireServer("BlockEnd")
			predict("BlockEnd")
		end
	elseif name == "Dash" and state == Enum.UserInputState.Begin then
		remote:FireServer("Dash")
		local now = os.clock()
		local stamina = player.Character and player.Character:GetAttribute("Stamina")
		if now - lastDash >= Config.DashCooldown and (typeof(stamina) ~= "number" or stamina >= Config.DashStaminaCost) then
			lastDash = now
			predict("Dash")
		end
	end
	return Enum.ContextActionResult.Pass
end

-- คีย์บอร์ด + จอยเกม + ปุ่มสัมผัสบนมือถือ (createTouchButton = true)
ContextActionService:BindAction("M1", handler, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("Block", handler, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
ContextActionService:BindAction("Dash", handler, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
for name, text in { M1 = "ชก", Block = "บล็อก", Dash = "หลบ" } do
	ContextActionService:SetTitle(name, text)
end
