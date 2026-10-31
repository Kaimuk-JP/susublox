--!strict
-- หน้าต่างคุยผู้ให้ภารกิจ, ตัวติดตามภารกิจ + ลูกศรนำทาง, ข้อความค้นพบย่าน/แจ้งเตือน
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local WQ = require(ReplicatedStorage.Shared.WorldQuests)
local remote = ReplicatedStorage:WaitForChild("WorldRemote") :: RemoteEvent
local player = Players.LocalPlayer

local PANEL, ACCENT, GOLD = Color3.fromHex("2B2D42"), Color3.fromHex("FFB7C5"), Color3.fromHex("FFE066")

local gui = Instance.new("ScreenGui")
gui.Name = "WorldQuestUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

---------------------------------------------------------------- หน้าต่างคุย
local box = Instance.new("Frame")
box.AnchorPoint = Vector2.new(0.5, 1)
box.Position = UDim2.new(0.5, 0, 1, -110)
box.Size = UDim2.fromOffset(480, 190)
box.BackgroundColor3 = PANEL
box.BackgroundTransparency = 0.08
box.Visible = false
box.Parent = gui
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Thickness = 2
stroke.Parent = box

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -32, 0, 28)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = GOLD
title.Font = Enum.Font.FredokaOne
title.TextSize = 22
title.Parent = box

local body = Instance.new("TextLabel")
body.Position = UDim2.fromOffset(16, 42)
body.Size = UDim2.new(1, -32, 0, 84)
body.BackgroundTransparency = 1
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextWrapped = true
body.TextColor3 = Color3.new(1, 1, 1)
body.Font = Enum.Font.FredokaOne
body.TextSize = 17
body.Parent = box

local rewardLabel = Instance.new("TextLabel")
rewardLabel.Position = UDim2.fromOffset(16, 128)
rewardLabel.Size = UDim2.new(1, -32, 0, 22)
rewardLabel.BackgroundTransparency = 1
rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
rewardLabel.TextColor3 = ACCENT
rewardLabel.Font = Enum.Font.FredokaOne
rewardLabel.TextSize = 16
rewardLabel.Parent = box

local function button(text: string, x: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(120, 34)
	b.Position = UDim2.new(1, x, 1, -44)
	b.BackgroundColor3 = ACCENT
	b.TextColor3 = PANEL
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 17
	b.Text = text
	b.Parent = box
	Instance.new("UICorner", b)
	return b
end
local acceptButton = button("รับภารกิจ", -270)
local closeButton = button("ปิด", -140)
local pendingId: string? = nil

closeButton.Activated:Connect(function()
	box.Visible = false
end)
acceptButton.Activated:Connect(function()
	if pendingId then
		remote:FireServer("Accept", pendingId)
	end
	box.Visible = false
end)

---------------------------------------------------------------- ข้อความลอย (ค้นพบย่าน / แจ้งเตือน)
local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 130)
toast.Size = UDim2.fromOffset(420, 44)
toast.BackgroundColor3 = PANEL
toast.BackgroundTransparency = 1
toast.TextColor3 = GOLD
toast.TextTransparency = 1
toast.Font = Enum.Font.FredokaOne
toast.TextSize = 20
toast.Parent = gui
Instance.new("UICorner", toast)

local toastId = 0
local function showToast(text: string, big: boolean?)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextSize = if big then 30 else 20
	toast.Size = UDim2.fromOffset(if big then 520 else 420, if big then 60 else 44)
	toast.BackgroundTransparency, toast.TextTransparency = 0.15, 0
	task.delay(if big then 3 else 1.8, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end

remote.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "Dialog" then
		title.Text = data.Title
		body.Text = data.Text
		rewardLabel.Text = if data.Reward then `รางวัล: {data.Reward}` else ""
		pendingId = data.Accept
		acceptButton.Visible = data.Accept ~= nil
		closeButton.Position = if data.Accept then UDim2.new(1, -140, 1, -44) else UDim2.new(1, -140, 1, -44)
		box.Visible = true
	elseif kind == "Discovered" then
		showToast(`ค้นพบ: {data}  (เดินทางด่วนได้ในเมนู)`, true)
	elseif kind == "Toast" then
		showToast(tostring(data))
	end
end)

---------------------------------------------------------------- ตัวติดตามภารกิจ + ลูกศร
local tracker = Instance.new("Frame")
tracker.Position = UDim2.fromOffset(16, 200)
tracker.Size = UDim2.fromOffset(280, 0)
tracker.AutomaticSize = Enum.AutomaticSize.Y
tracker.BackgroundTransparency = 1
tracker.Parent = gui
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.Parent = tracker

local rows: { { Frame: Frame, Name: TextLabel, Info: TextLabel } } = {}
for i = 1, WQ.MaxActive do
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 44)
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.25
	f.Visible = false
	f.LayoutOrder = i
	f.Parent = tracker
	Instance.new("UICorner", f)
	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(8, 2)
	name.Size = UDim2.new(1, -16, 0, 20)
	name.BackgroundTransparency = 1
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = GOLD
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 15
	name.Parent = f
	local info = Instance.new("TextLabel")
	info.Position = UDim2.fromOffset(8, 22)
	info.Size = UDim2.new(1, -16, 0, 18)
	info.BackgroundTransparency = 1
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextColor3 = Color3.new(1, 1, 1)
	info.Font = Enum.Font.FredokaOne
	info.TextSize = 13
	info.Parent = f
	rows[i] = { Frame = f, Name = name, Info = info }
end

-- ลูกศรชี้เป้าหมายภารกิจแรก
local arrow = Instance.new("TextLabel")
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Position = UDim2.new(0.5, 0, 0, 92)
arrow.Size = UDim2.fromOffset(40, 40)
arrow.BackgroundTransparency = 1
arrow.Text = "▲"
arrow.TextColor3 = GOLD
arrow.TextStrokeTransparency = 0.2
arrow.TextSize = 34
arrow.Font = Enum.Font.FredokaOne
arrow.Visible = false
arrow.Parent = gui
local dist = Instance.new("TextLabel")
dist.AnchorPoint = Vector2.new(0.5, 0)
dist.Position = UDim2.new(0.5, 0, 0, 112)
dist.Size = UDim2.fromOffset(120, 18)
dist.BackgroundTransparency = 1
dist.TextColor3 = Color3.new(1, 1, 1)
dist.TextStrokeTransparency = 0.3
dist.Font = Enum.Font.FredokaOne
dist.TextSize = 14
dist.Visible = false
dist.Parent = gui

RunService.RenderStepped:Connect(function()
	local count = (player:GetAttribute("QTCount") :: number?) or 0
	for i = 1, WQ.MaxActive do
		local row = rows[i]
		local name = player:GetAttribute(`QT{i}Name`)
		if i <= count and typeof(name) == "string" then
			row.Frame.Visible = true
			row.Name.Text = name
			row.Info.Text = tostring(player:GetAttribute(`QT{i}Text`) or "")
			row.Info.TextColor3 = if player:GetAttribute(`QT{i}Done`) == true then GOLD else Color3.new(1, 1, 1)
		else
			row.Frame.Visible = false
		end
	end

	local target = player:GetAttribute("QT1Pos")
	local cam = workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if typeof(target) == "Vector3" and root and cam and count > 0 then
		local offset = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		if flatLook.Magnitude > 0.01 and offset.Magnitude > 1 then
			local angle = math.atan2(offset.X, -offset.Z) - math.atan2(flatLook.X, -flatLook.Z)
			arrow.Rotation = math.deg(angle)
			arrow.Visible = offset.Magnitude > 12
			dist.Visible = arrow.Visible
			dist.Text = `{math.floor(offset.Magnitude)} m`
		end
	else
		arrow.Visible = false
		dist.Visible = false
	end
end)
