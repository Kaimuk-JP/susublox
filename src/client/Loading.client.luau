--!strict
-- หน้าโหลดตอนเข้าเกม: บังฉากจนกว่าโลกสร้างเสร็จและพื้นรอบตัวละครโหลดแล้ว ตัวละครถูกล็อกไว้กันตกพื้น/กระตุกระหว่างโหลด
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
bg.BorderSizePixel = 0
bg.Active = true
bg.Parent = gui

local function label(text: string, y: number, size: number, color: Color3, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromOffset(600, size + 10)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.TextSize = size
	l.Font = font
	l.Parent = bg
	return l
end

label("SUSUBLOX", 0.38, 56, Color3.fromRGB(240, 240, 245), Enum.Font.GothamBlack)
label("ศึกนักเรียนเมืองญี่ปุ่น", 0.46, 22, Color3.fromRGB(200, 70, 70), Enum.Font.GothamMedium)
local status = label("กำลังสร้างเมือง...", 0.60, 18, Color3.fromRGB(170, 175, 190), Enum.Font.Gotham)

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.66)
barBack.Size = UDim2.fromOffset(360, 8)
barBack.BackgroundColor3 = Color3.fromRGB(40, 44, 58)
barBack.BorderSizePixel = 0
barBack.Parent = bg
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0.02, 1)
barFill.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local tips = {
	"เดินเข้าใกล้ผู้ให้ภารกิจ (!) เพื่อรับเควส",
	"กลางคืนมีนักเลงเยอะขึ้น ระวังตัว",
	"ฝนตกและพายุเกิดขึ้นสุ่ม หาที่หลบใต้หลังคาได้",
	"รถบนถนนชนได้ เดินข้ามระวังด้วย",
}
local tip = label("เคล็ดลับ: " .. tips[math.random(#tips)], 0.86, 16, Color3.fromRGB(130, 135, 150), Enum.Font.Gotham)

local progress = 0.02
local function setProgress(p: number, text: string?)
	progress = math.max(progress, p)
	barFill.Size = UDim2.fromScale(progress, 1)
	if text then
		status.Text = text
	end
end

-- ล็อกตัวละครระหว่างโหลด
local locked: BasePart? = nil
local function lockCharacter(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if root then
		root.Anchored = true
		locked = root
	end
end
if player.Character then
	task.spawn(lockCharacter, player.Character)
end
local conn = player.CharacterAdded:Connect(function(char)
	task.spawn(lockCharacter, char)
end)

local started = os.clock()
local function waitFor(cond: () -> boolean, maxSeconds: number, from: number, to: number, text: string)
	local t0 = os.clock()
	setProgress(from, text)
	while not cond() and os.clock() - t0 < maxSeconds do
		local f = math.clamp((os.clock() - t0) / maxSeconds, 0, 0.95)
		setProgress(from + (to - from) * f * 0.6)
		task.wait(0.2)
	end
	setProgress(to)
	print(string.format("[Loading] %s %.1fs (รวม %.1fs)", text, os.clock() - t0, os.clock() - started))
end

-- สัญญาณจริงจาก server (BuildSync): builder ทุกตัวเสร็จ; SchoolMapReady/World.Built เป็นแค่ข้อมูลเสริม
waitFor(function()
	return workspace:GetAttribute("GameReady") == true
end, 120, 0.05, 0.75, "กำลังสร้างเมือง...")

-- รอให้พื้นรอบตัวละครสตรีมเข้ามาจริง (ยิงเรย์ลงใต้ตัว)
waitFor(function()
	local root = locked
	if not root then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	-- ตัวละครเกิดสูง (~y 100) ก่อนลงพื้น ต้องยิงไกลพอ
	local hit = workspace:Raycast(root.Position + Vector3.new(0, 4, 0), Vector3.new(0, -400, 0), params)
	return hit ~= nil
end, 25, 0.75, 0.92, "กำลังโหลดพื้นที่รอบตัว...")

-- ให้ฉากนิ่งสักพักหลังสร้างเสร็จ (ลดอาการกระตุกช่วงแรกจากการสตรีม/สร้างของท้ายๆ)
setProgress(0.95, "เตรียมตัวให้พร้อม...")
local settle = os.clock()
local slow = 0
while os.clock() - settle < 6 do
	local dt = RunService.Heartbeat:Wait()
	if dt > 0.05 then
		slow = 0
	else
		slow += dt
	end
	if slow > 1.5 and os.clock() - settle > 2 then
		break
	end
	setProgress(0.95 + 0.05 * math.clamp((os.clock() - settle) / 6, 0, 1))
end
print(string.format("[Loading] settle %.1fs (รวม %.1fs)", os.clock() - settle, os.clock() - started))
setProgress(1, "พร้อมแล้ว!")

conn:Disconnect()
if locked then
	locked.Anchored = false
end
task.wait(0.3)

local info = TweenInfo.new(0.8)
for _, d in bg:GetDescendants() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, info, { TextTransparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
	end
end
TweenService:Create(bg, info, { BackgroundTransparency = 1 }):Play()
task.wait(0.9)
gui:Destroy()
print(string.format("[Loading] เข้าเกมใน %.1f วินาที", os.clock() - started))
