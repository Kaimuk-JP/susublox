--!strict
-- ปุ่มสกิล Z X C V และไม้ตาย (G): ส่งไป server และทำนายท่าทันทีถ้าพร้อมใช้ (Mastery ถึง, คูลดาวน์หมด, หลอดไม้ตายเต็ม)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local StyleData = require(ReplicatedStorage.Shared.Styles)
local remote = ReplicatedStorage:WaitForChild("SkillRemote") :: RemoteEvent
local player = Players.LocalPlayer
local localId = 0

local function canUse(key: string): boolean
	local mastery = (player:GetAttribute("MasteryLevel") :: number?) or 1
	local need = StyleData.MasteryUnlock[if key == "U" then "Ultimate" else key]
	if mastery < need then
		return false
	end
	if key == "U" then
		local ult = player.Character and player.Character:GetAttribute("Ult")
		return typeof(ult) == "number" and ult >= Config.UltMax
	end
	local readyAt = (player:GetAttribute("CD_" .. key) :: number?) or 0
	if workspace:GetServerTimeNow() < readyAt then
		return false
	end
	-- พลังงานพอไหม (ไม่พอก็ไม่ทำนายท่า server จะปฏิเสธ)
	local styleId = player:GetAttribute("Style")
	local style = typeof(styleId) == "string" and StyleData.Styles[styleId]
	local energy = player.Character and player.Character:GetAttribute("Stamina")
	if style and typeof(energy) == "number" then
		return energy >= StyleData.SkillCost((style.Skills :: any)[key])
	end
	return true
end

local function press(key: string)
	remote:FireServer(key)
	local styleId = player:GetAttribute("Style")
	local char = player.Character
	if typeof(styleId) == "string" and char and canUse(key) then
		localId += 1
		char:SetAttribute("Anim", `{styleId}_{if key == "U" then "Ultimate" else key}:L{localId}`)
	end
end

local function bind(name: string, key: string, code: Enum.KeyCode, pad: Enum.KeyCode, title: string)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			press(key)
		end
		return Enum.ContextActionResult.Pass
	end, true, code, pad)
	ContextActionService:SetTitle(name, title)
end

bind("SkillZ", "Z", Enum.KeyCode.Z, Enum.KeyCode.ButtonX, "Z")
bind("SkillX", "X", Enum.KeyCode.X, Enum.KeyCode.ButtonY, "X")
bind("SkillC", "C", Enum.KeyCode.C, Enum.KeyCode.DPadLeft, "C")
bind("SkillV", "V", Enum.KeyCode.V, Enum.KeyCode.DPadRight, "V")
bind("SkillU", "U", Enum.KeyCode.G, Enum.KeyCode.ButtonL1, "ไม้ตาย")

-- ปุ่มสัมผัสมือถือ: จัดเรียงมุมขวาล่าง ขนาด >= 60 พิกเซล ไม่บังกลางจอ
local positions = {
	SkillZ = UDim2.new(1, -230, 1, -190),
	SkillX = UDim2.new(1, -160, 1, -250),
	SkillC = UDim2.new(1, -90, 1, -190),
	SkillV = UDim2.new(1, -160, 1, -130),
	SkillU = UDim2.new(1, -250, 1, -280),
}
for name, pos in positions do
	local button = ContextActionService:GetButton(name)
	if button then
		button.Position = pos
		button.Size = UDim2.fromOffset(64, 64)
	end
end
