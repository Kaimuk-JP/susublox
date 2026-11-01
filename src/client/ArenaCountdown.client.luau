--!strict
-- นับถอยหลังก่อนเริ่มแมตช์ในสนาม: ตัวเลข 10..1 กลางจอ (3 วินาทีท้ายสีแดง ใหญ่ขึ้น) + เสียงติ๊กทุกวินาที + "FIGHT!" ตอนเริ่ม
-- เซิร์ฟเวอร์ส่ง ("Start", endsAt เป็นเวลาเซิร์ฟเวอร์) / "Fight" / "Cancel"; ไคลเอนต์คำนวณเลขจาก endsAt - GetServerTimeNow จึงซิงก์กัน
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local remote = ReplicatedStorage:WaitForChild("ArenaCountdown") :: RemoteEvent
local player = Players.LocalPlayer

-- เสียง: ID ที่ตรวจแล้วว่าโหลดได้ใน Play (ดู docs/IMPORTED_ASSETS.md); 0 = ข้าม
local TICK_ID = 0
local FIGHT_ID = 0
local VOLUME = 0.6

local tickSound = Instance.new("Sound")
tickSound.Name = "CountdownTick"
tickSound.Volume = VOLUME
tickSound.SoundId = if TICK_ID ~= 0 then "rbxassetid://" .. TICK_ID else ""
tickSound.Parent = SoundService
local fightSound = Instance.new("Sound")
fightSound.Name = "CountdownFight"
fightSound.Volume = VOLUME
fightSound.SoundId = if FIGHT_ID ~= 0 then "rbxassetid://" .. FIGHT_ID else ""
fightSound.Parent = SoundService

local gui = Instance.new("ScreenGui")
gui.Name = "ArenaCountdown"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 8
gui.Parent = player:WaitForChild("PlayerGui")

local function label(size: number, y: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromOffset(700, size * 1.3)
	l.BackgroundTransparency = 1
	l.Active = false
	l.Font = Enum.Font.FredokaOne
	l.TextSize = size
	l.TextStrokeTransparency = 0.2
	l.TextStrokeColor3 = Color3.fromHex("1B1D2B")
	l.Visible = false
	l.Parent = gui
	local sc = Instance.new("UIScale")
	sc.Parent = l
	return l
end

local header = label(30, 0.2)
header.Text = "เตรียมตัว! ศึกจะเริ่มใน..."
header.TextColor3 = Color3.fromHex("FFE066")
local number = label(120, 0.34)
local fight = label(110, 0.34)
fight.Text = "FIGHT! ลุย!"
fight.TextColor3 = Color3.fromHex("FF5A4E")

local token = 0

local function popNumber(n: number)
	local urgent = n <= 3
	number.Text = tostring(n)
	number.TextColor3 = if urgent then Color3.fromHex("FF4A3D") else Color3.fromHex("FFFFFF")
	number.TextTransparency = 0
	number.Visible = true
	local sc = number:FindFirstChildOfClass("UIScale") :: UIScale
	sc.Scale = if urgent then 2.1 else 1.6
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if urgent then 1.5 else 1 }):Play()
	TweenService:Create(number, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 0.45 }):Play()
	-- เสียงติ๊ก: 3 วินาทีท้ายเสียงสูงขึ้น
	if tickSound.SoundId ~= "" then
		tickSound.PlaybackSpeed = if urgent then 1.5 else 1
		tickSound.TimePosition = 0
		tickSound:Play()
	end
end

local function hideAll()
	header.Visible = false
	number.Visible = false
end

local function runCountdown(endsAt: number)
	token += 1
	local mine = token
	fight.Visible = false
	header.Visible = true
	local last = -1
	while token == mine do
		local left = endsAt - workspace:GetServerTimeNow()
		if left <= 0 then
			break
		end
		local n = math.ceil(left)
		if n ~= last then
			last = n
			popNumber(n)
		end
		task.wait(0.03)
	end
	if token == mine then
		hideAll() -- หมดเวลาแล้วรอ "Fight" จากเซิร์ฟเวอร์
	end
end

local function flashFight()
	token += 1
	hideAll()
	fight.Visible = true
	fight.TextTransparency = 0
	local sc = fight:FindFirstChildOfClass("UIScale") :: UIScale
	sc.Scale = 0.5
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.2 }):Play()
	if fightSound.SoundId ~= "" then
		fightSound.TimePosition = 0
		fightSound:Play()
	end
	local mine = token
	task.delay(0.9, function()
		if token == mine then
			TweenService:Create(fight, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(0.55, function()
				if token == mine then
					fight.Visible = false
					fight.TextStrokeTransparency = 0.2
				end
			end)
		end
	end)
end

remote.OnClientEvent:Connect(function(kind: string, endsAt: number?)
	if kind == "Start" and endsAt then
		task.spawn(runCountdown, endsAt)
	elseif kind == "Fight" then
		flashFight()
	elseif kind == "Cancel" then
		token += 1
		hideAll()
		fight.Visible = false
	end
end)
