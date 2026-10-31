--!strict
-- ตัวบอกเหตุการณ์กลางเมือง (ขบวนส่งเงิน/ศึกชิงถนน): ชื่อ ย่าน ระยะทาง เวลาที่เหลือ ลูกศรชี้ทาง (อ่านจาก Attribute ของ Workspace)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PANEL, ACCENT = Color3.fromHex("2B2D42"), Color3.fromHex("5FBF7A")

local gui = Instance.new("ScreenGui")
gui.Name = "CityEventUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, 292) -- ใต้แผงบอสสุ่ม
panel.Size = UDim2.fromOffset(300, 64)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.15
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Thickness = 2
stroke.Parent = panel

local arrow = Instance.new("TextLabel")
arrow.Position = UDim2.fromOffset(8, 12)
arrow.Size = UDim2.fromOffset(40, 40)
arrow.BackgroundTransparency = 1
arrow.Text = "▲"
arrow.TextColor3 = ACCENT
arrow.TextSize = 34
arrow.Font = Enum.Font.FredokaOne
arrow.Parent = panel

local nameLabel = Instance.new("TextLabel")
nameLabel.Position = UDim2.fromOffset(54, 6)
nameLabel.Size = UDim2.new(1, -62, 0, 24)
nameLabel.BackgroundTransparency = 1
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.TextColor3 = ACCENT
nameLabel.Font = Enum.Font.FredokaOne
nameLabel.TextSize = 15
nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
nameLabel.Parent = panel

local infoLabel = Instance.new("TextLabel")
infoLabel.Position = UDim2.fromOffset(54, 32)
infoLabel.Size = UDim2.new(1, -62, 0, 24)
infoLabel.BackgroundTransparency = 1
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.Font = Enum.Font.FredokaOne
infoLabel.TextSize = 14
infoLabel.Parent = panel

RunService.RenderStepped:Connect(function()
	local name = workspace:GetAttribute("CityEventName")
	local pos = workspace:GetAttribute("CityEventPos")
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = workspace.CurrentCamera
	if typeof(name) ~= "string" or typeof(pos) ~= "Vector3" or not root or not cam then
		panel.Visible = false
		return
	end
	panel.Visible = true
	nameLabel.Text = "⚡ " .. name
	local offset = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
	local untilAt = (workspace:GetAttribute("CityEventUntil") :: number?) or 0
	local left = math.max(0, untilAt - workspace:GetServerTimeNow())
	infoLabel.Text = `{workspace:GetAttribute("CityEventDistrict") or ""}  {math.floor(offset.Magnitude)} m  เหลือ {math.floor(left / 60)}:{string.format("%02d", math.floor(left % 60))}`
	local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	if flatLook.Magnitude > 0.01 and offset.Magnitude > 1 then
		arrow.Rotation = math.deg(math.atan2(offset.X, -offset.Z) - math.atan2(flatLook.X, -flatLook.Z))
	end
end)
