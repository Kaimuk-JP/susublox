--!strict
-- สร้างตัวละคร NPC/บอส (R15) จาก HumanoidDescription — ไม่มี asset ภายนอกที่ต้องเตรียม
local Players = game:GetService("Players")

local RigFactory = {}

function RigFactory.Create(name: string, position: Vector3, parent: Instance, attributes: { [string]: any }?, color: Color3?): Model?
	local ok, rig = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		if color then
			desc.HeadColor, desc.TorsoColor, desc.LeftArmColor = color, color, color
			desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = color, color, color
		end
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[RigFactory] สร้างตัวละครไม่สำเร็จ: " .. tostring(rig))
		return nil
	end
	rig.Name = name
	for k, v in attributes or {} do
		rig:SetAttribute(k, v)
	end
	rig:PivotTo(CFrame.new(position))
	rig.Parent = parent
	return rig
end

return RigFactory
