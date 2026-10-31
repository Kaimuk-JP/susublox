--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("SkillRemote") :: RemoteEvent

local function bind(name: string, key: string, code: Enum.KeyCode, pad: Enum.KeyCode, title: string)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			remote:FireServer(key)
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
