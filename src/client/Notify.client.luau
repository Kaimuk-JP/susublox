--!strict
-- แจ้งเตือนกลางจอ: เลเวลอัป, +EXP, +เยน และภาพตอนโดนตี/เลือดต่ำ
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Notify"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local function floatText(text: string, color: Color3, yOffset: number, size: number?)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.new(0.5, 0, 0.62, yOffset)
	l.Size = UDim2.fromOffset(300, 30)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.Font = Enum.Font.FredokaOne
	l.TextSize = size or 20
	l.Parent = gui
	TweenService:Create(l, TweenInfo.new(1.1), {
		Position = UDim2.new(0.5, 0, 0.62, yOffset - 50),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.2, function()
		l:Destroy()
	end)
end

local function banner(text: string)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.3)
	l.Size = UDim2.fromOffset(420, 70)
	l.BackgroundColor3 = Color3.fromHex("2B2D42")
	l.BackgroundTransparency = 0.15
	l.Text = text
	l.TextColor3 = Color3.fromHex("FFE066")
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 38
	l.Parent = gui
	Instance.new("UICorner", l)
	l.Size = UDim2.fromOffset(300, 50)
	TweenService:Create(l, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(420, 70) }):Play()
	task.delay(2, function()
		TweenService:Create(l, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.delay(0.5, function()
			l:Destroy()
		end)
	end)
end

-- รางวัลล็อกอินต่อเนื่อง 7 วัน (วันที่ 7 ใหญ่สุด)
local function showLogin()
	local v = player:GetAttribute("LoginReward")
	if typeof(v) == "string" then
		local parts = v:split("|")
		local day, yen = parts[1], parts[2]
		if day and yen then
			banner(`ล็อกอินวันที่ {day}/7  +¥{yen}`)
		end
	end
end
player:GetAttributeChangedSignal("LoginReward"):Connect(showLogin)
if player:GetAttribute("LoginReward") ~= nil then
	task.defer(showLogin)
end

local last: { [string]: number } = {}
local function track(name: string, onIncrease: (delta: number, value: number) -> ())
	-- ข้ามเฉพาะค่าแรกที่เซิร์ฟเวอร์ตั้งตอนโหลด (ถ้าตอนเริ่มยังไม่มีค่า) ไม่ข้ามการเพิ่มครั้งแรกจริง
	local initializing = player:GetAttribute(name) == nil
	player:GetAttributeChangedSignal(name):Connect(function()
		local v = (player:GetAttribute(name) :: number?) or 0
		if initializing then
			initializing = false
			last[name] = v
			return
		end
		local prev = last[name] or v
		last[name] = v
		if v > prev then
			onIncrease(v - prev, v)
		end
	end)
	last[name] = (player:GetAttribute(name) :: number?) or 0
end

track("Level", function(_, v)
	banner(`LEVEL UP!  Lv.{v}`)
end)
track("Yen", function(d)
	floatText(`+¥{d}`, Color3.fromHex("FFE066"), 0, 22)
end)
track("Exp", function(d)
	floatText(`+{d} EXP`, Color3.fromHex("FFB7C5"), 26, 18)
end)

-- โดนตี: วาบแดงทั้งจอ / เลือดต่ำกว่า 30%: ขอบจอแดงกระพริบ
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromHex("EF233C")
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

local edges: { Frame } = {}
for _, def in { { UDim2.new(1, 0, 0, 14), UDim2.new() }, { UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -14) }, { UDim2.new(0, 14, 1, 0), UDim2.new() }, { UDim2.new(0, 14, 1, 0), UDim2.new(1, -14, 0, 0) } } do
	local e = Instance.new("Frame")
	e.Size = def[1]
	e.Position = def[2]
	e.BackgroundColor3 = Color3.fromHex("EF233C")
	e.BackgroundTransparency = 1
	e.BorderSizePixel = 0
	e.Parent = gui
	table.insert(edges, e)
end

local function watchHumanoid(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local previous = hum.Health
	hum.HealthChanged:Connect(function(h)
		if h < previous then
			flash.BackgroundTransparency = 0.72
			TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end
		previous = h
	end)
end
player.CharacterAdded:Connect(watchHumanoid)
if player.Character then
	task.spawn(watchHumanoid, player.Character)
end

RunService.RenderStepped:Connect(function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local low = hum and hum.Health > 0 and hum.Health / hum.MaxHealth < 0.3
	local t = if low then 0.55 + 0.25 * math.sin(os.clock() * 6) else 1
	for _, e in edges do
		e.BackgroundTransparency = t
	end
end)
