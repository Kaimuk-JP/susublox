--!strict
-- รับคำสั่งผลักตัวละครของเราจาก server (Dash, กระเด็น) แล้วใช้กับฟิสิกส์ที่ client เป็นเจ้าของ
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local feedback = ReplicatedStorage:WaitForChild("CombatFeedback") :: RemoteEvent
local player = Players.LocalPlayer

feedback.OnClientEvent:Connect(function(kind: string, velocity: Vector3, duration: number)
	if kind ~= "Impulse" then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	-- Humanoid ทับ AssemblyLinearVelocity ทุกเฟรมขณะเดิน จึงใช้ LinearVelocity คงไว้ช่วงสั้น ๆ
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = 1e6
	lv.VectorVelocity = velocity
	lv.Parent = root
	Debris:AddItem(lv, duration)
	Debris:AddItem(attachment, duration)
end)
