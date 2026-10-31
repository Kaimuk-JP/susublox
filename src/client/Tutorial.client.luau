--!strict
-- บทสอนภายใน 2 นาทีแรก: เดิน -> ชก -> บล็อก -> หลบ -> สู้ NPC ตัวแรก
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local function done(): boolean
	return player:GetAttribute("TutorialDone") == true
end

-- รอให้ server ตั้งค่า TutorialDone ก่อน (กันบทสอนโผล่ให้คนเก่า)
for _ = 1, 100 do
	if player:GetAttribute("TutorialDone") ~= nil then
		break
	end
	task.wait(0.1)
end
if done() then
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 24)
label.Size = UDim2.fromOffset(360, 56)
label.BackgroundColor3 = Color3.fromHex("2B2D42")
label.TextColor3 = Color3.fromHex("FFE066")
label.Font = Enum.Font.FredokaOne
label.TextSize = 18
label.TextWrapped = true
label.Parent = gui
Instance.new("UICorner", label)

local steps = {
	{ Text = "เดินด้วย WASD / จอยสติ๊ก / ปุ่มเดินบนจอ", Key = "move" },
	{ Text = "ชกด้วยคลิกซ้าย / ปุ่ม ชก", Key = "M1" },
	{ Text = "กด F ค้างเพื่อบล็อก (กดทันจังหวะ = Perfect Block)", Key = "Block" },
	{ Text = "กด Q เพื่อหลบ (Dash)", Key = "Dash" },
	{ Text = "ไปหลังโรงเรียน แล้วล้มศัตรูตัวแรก! (เปิดเมนูด้วยปุ่ม M)", Key = "kill" },
}
local index = 1
local function show()
	label.Text = `บทสอน {index}/{#steps}: {steps[index].Text}`
end
local function advance(key: string)
	if steps[index] and steps[index].Key == key then
		index += 1
		if index > #steps then
			return
		end
		show()
	end
end
show()

-- ฟังอินพุตแบบ Pass (ไม่กินปุ่ม) ผ่าน ContextActionService ให้ใช้ได้ทั้งคีย์บอร์ด/จอย/สัมผัส
local function watcher(key: string)
	return function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			advance(key)
		end
		return Enum.ContextActionResult.Pass
	end
end
ContextActionService:BindActionAtPriority("TutM1", watcher("M1"), false, 3000, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:BindActionAtPriority("TutBlock", watcher("Block"), false, 3000, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
ContextActionService:BindActionAtPriority("TutDash", watcher("Dash"), false, 3000, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

local conn: RBXScriptConnection
conn = RunService.Heartbeat:Connect(function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.MoveDirection.Magnitude > 0 then
		advance("move")
	end
	if done() then
		conn:Disconnect()
		ContextActionService:UnbindAction("TutM1")
		ContextActionService:UnbindAction("TutBlock")
		ContextActionService:UnbindAction("TutDash")
		label.Text = "จบบทสอน! รับเยน ¥50 แล้ว"
		task.delay(3, function()
			gui:Destroy()
		end)
	end
end)
