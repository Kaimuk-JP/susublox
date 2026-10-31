--!strict
-- ฉากบทสนทนาเนื้อเรื่อง: กล่องข้อความล่างจอ ชื่อผู้พูดมีสีประจำตัว พิมพ์ทีละตัวอักษร แตะ/Space/E เพื่อไปต่อ ข้ามได้
-- ไม่ล็อกการควบคุมผู้เล่น (เป็นกล่องข้อความไม่บังจอ) ฉากที่มาพร้อมกันเข้าคิวเล่นต่อกัน
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Scenes = require(ReplicatedStorage.Shared.Scenes)
local remote = ReplicatedStorage:WaitForChild("WorldRemote") :: RemoteEvent
local player = Players.LocalPlayer

local PANEL = Color3.fromHex("1E2033")
local CPS = 42 -- ตัวอักษรต่อวินาที

local gui = Instance.new("ScreenGui")
gui.Name = "SceneUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local box = Instance.new("TextButton")
box.AutoButtonColor = false
box.Text = ""
box.AnchorPoint = Vector2.new(0.5, 1)
box.Position = UDim2.new(0.5, 0, 1, -24)
box.Size = UDim2.new(0.9, 0, 0, 150)
box.BackgroundColor3 = PANEL
box.BackgroundTransparency = 0.05
box.Visible = false
box.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(760, 170)
limit.Parent = box
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Parent = box

local nameTag = Instance.new("TextLabel")
nameTag.Position = UDim2.fromOffset(18, 10)
nameTag.Size = UDim2.new(1, -36, 0, 26)
nameTag.BackgroundTransparency = 1
nameTag.TextXAlignment = Enum.TextXAlignment.Left
nameTag.Font = Enum.Font.FredokaOne
nameTag.TextSize = 22
nameTag.Parent = box

local body = Instance.new("TextLabel")
body.Position = UDim2.fromOffset(18, 42)
body.Size = UDim2.new(1, -36, 1, -78)
body.BackgroundTransparency = 1
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextWrapped = true
body.TextColor3 = Color3.new(1, 1, 1)
body.Font = Enum.Font.FredokaOne
body.TextSize = 19
body.Parent = box

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(1, 1)
hint.Position = UDim2.new(1, -16, 1, -10)
hint.Size = UDim2.fromOffset(240, 20)
hint.BackgroundTransparency = 1
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.TextColor3 = Color3.fromHex("C9CED6")
hint.Font = Enum.Font.FredokaOne
hint.TextSize = 13
hint.Text = "แตะ / Space / E เพื่อไปต่อ"
hint.Parent = box

local skip = Instance.new("TextButton")
skip.AnchorPoint = Vector2.new(0, 1)
skip.Position = UDim2.new(0, 16, 1, -8)
skip.Size = UDim2.fromOffset(70, 26)
skip.BackgroundColor3 = Color3.fromHex("3A3D5C")
skip.TextColor3 = Color3.fromHex("FFB7C5")
skip.Font = Enum.Font.FredokaOne
skip.TextSize = 14
skip.Text = "ข้าม"
skip.Parent = box
Instance.new("UICorner", skip)

---------------------------------------------------------------- คิวฉาก
local queue: { { Scenes.Line } } = {}
local playing = false
local advanceRequested = false
local skipAll = false
local typing = false
local finishTyping = false

local function setLine(line: Scenes.Line)
	local color = Color3.fromHex(Scenes.ColorOf(line.Who))
	nameTag.Text = line.Who
	nameTag.TextColor3 = color
	stroke.Color = color
	body.Text = line.Text
	body.MaxVisibleGraphemes = 0
	typing = true
	finishTyping = false
	local total = utf8.len(line.Text) or #line.Text
	local shown = 0
	local last = os.clock()
	while shown < total and not finishTyping and not skipAll do
		task.wait()
		local now = os.clock()
		shown = math.min(total, shown + (now - last) * CPS)
		last = now
		body.MaxVisibleGraphemes = math.floor(shown)
	end
	body.MaxVisibleGraphemes = -1
	typing = false
end

local function playScene(lines: { Scenes.Line })
	for _, line in lines do
		if skipAll then
			break
		end
		advanceRequested = false
		setLine(line)
		while not advanceRequested and not skipAll do
			task.wait()
		end
	end
end

local function drain()
	if playing then
		return
	end
	playing = true
	skipAll = false
	box.Visible = true
	box.BackgroundTransparency = 0.05
	while #queue > 0 do
		local lines = table.remove(queue, 1) :: { Scenes.Line }
		playScene(lines)
	end
	box.Visible = false
	playing = false
end

local function request()
	if not playing then
		return
	end
	if typing then
		finishTyping = true -- แตะครั้งแรก: แสดงประโยคทั้งหมดทันที
	else
		advanceRequested = true
	end
end

box.Activated:Connect(request)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not playing then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Return then
		request()
	end
end)
skip.Activated:Connect(function()
	skipAll = true
	table.clear(queue)
end)

remote.OnClientEvent:Connect(function(kind: string, key: unknown)
	if kind == "Scene" and typeof(key) == "string" then
		local lines = Scenes.Scenes[key]
		if lines then
			table.insert(queue, lines)
			task.spawn(drain)
		end
	end
end)
