--!strict
-- ของสะสมภารกิจ (Orbs_<ย่าน>) แสดงเฉพาะตอนผู้เล่นรับเควสเก็บของของย่านนั้นอยู่
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local function apply(orb: Instance, visible: boolean)
	if orb:IsA("BasePart") then
		orb.LocalTransparencyModifier = if visible then 0 else 1
		local light = orb:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = visible and orb.Transparency < 1
		end
	end
end

local function refresh(folder: Instance)
	local id = folder.Name:match("^Orbs_(.+)$")
	if not id then
		return
	end
	local visible = player:GetAttribute("Orb_" .. id) == true
	for _, orb in folder:GetChildren() do
		apply(orb, visible)
	end
end

task.spawn(function()
	while true do
		local world = workspace:FindFirstChild("World")
		if world then
			for _, f in world:GetChildren() do
				if f:IsA("Folder") and f.Name:sub(1, 5) == "Orbs_" then
					refresh(f)
				end
			end
		end
		task.wait(0.5)
	end
end)

-- หมุนช้าๆ เฉพาะชิ้นที่มองเห็น (หมุนฝั่ง client อย่างเดียว)
RunService.Heartbeat:Connect(function(dt)
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	for _, f in world:GetChildren() do
		if f:IsA("Folder") and f.Name:sub(1, 5) == "Orbs_" and player:GetAttribute("Orb_" .. f.Name:sub(6)) == true then
			for _, orb in f:GetChildren() do
				if orb:IsA("BasePart") and orb.Transparency < 1 then
					orb.CFrame *= CFrame.Angles(0, dt * 1.1, 0)
				end
			end
		end
	end
end)
