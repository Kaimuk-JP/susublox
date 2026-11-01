--!strict
-- เมนูสนามประลอง (เปิดจากผู้ตัดสินที่ลานหน้าสนาม): ดวล 1v1 / สงครามแก๊ง 4v4 / ศึกฝึกซ้อมบอท / ชมการแข่ง / อันดับ
-- + ป๊อปอัปรับคำท้าดวล + ปุ่มออกจากสนามเมื่ออยู่ในแมตช์
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("ArenaRemote") :: RemoteEvent
local duelRemote = ReplicatedStorage:WaitForChild("DuelRemote") :: RemoteEvent
local warRemote = ReplicatedStorage:WaitForChild("WarRemote") :: RemoteEvent

local PANEL, ACCENT, ROW = Color3.fromHex("23252F"), Color3.fromHex("E7C46A"), Color3.fromHex("343747")

local gui = Instance.new("ScreenGui")
gui.Name = "ArenaUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(inst: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
end

local function button(parent: Instance, text: string, size: UDim2, color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = color or ACCENT
	b.TextColor3 = if color then Color3.new(1, 1, 1) else PANEL
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 16
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b)
	return b
end

---------------------------------------------------------------- หน้าต่างคีออสก์
local window = Instance.new("Frame")
window.Size = UDim2.fromOffset(520, 480)
window.Position = UDim2.fromScale(0.5, 0.5)
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.BackgroundColor3 = PANEL
window.Visible = false
window.Parent = gui
corner(window, 12)
local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Thickness = 2
stroke.Parent = window
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(520, 480)
sizeLimit.Parent = window
local scaleFit = Instance.new("UIScale")
scaleFit.Parent = window

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 44)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.FredokaOne
title.TextSize = 24
title.TextColor3 = ACCENT
title.Text = "สนามประลอง · ผู้ตัดสิน"
title.Parent = window

local closeBtn = button(window, "X", UDim2.fromOffset(40, 34), Color3.fromHex("8E3B3B"))
closeBtn.Position = UDim2.new(1, -48, 0, 6)

local back = button(window, "‹ กลับ", UDim2.fromOffset(80, 30), Color3.fromHex("4A4E66"))
back.Position = UDim2.fromOffset(14, 50)
back.Visible = false

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(10, 86)
content.Size = UDim2.new(1, -20, 1, -96)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.ScrollBarThickness = 4
content.Parent = window
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local state: any = nil
local view = "home"
local order = 0

local function clear()
	order = 0
	for _, c in content:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function row(text: string, buttonText: string?, onClick: (() -> ())?, tall: boolean?)
	order += 1
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -8, 0, if tall then 74 else 48)
	f.BackgroundColor3 = ROW
	f.LayoutOrder = order
	f.Parent = content
	corner(f)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, if buttonText then -118 else -16, 1, 0)
	l.Position = UDim2.fromOffset(10, 0)
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 15
	l.Text = text
	l.Parent = f
	if buttonText and onClick then
		local b = button(f, buttonText, UDim2.fromOffset(100, 36))
		b.Position = UDim2.new(1, -108, 0.5, -18)
		b.MouseButton1Click:Connect(onClick)
	end
end

local render: () -> ()

local function go(v: string)
	view = v
	render()
end

local function refresh()
	remote:FireServer("Refresh")
end

local views: { [string]: () -> () } = {}
local WAR_SIZES = { 0, 4, 5, 10, 15 } -- 0 = อัตโนมัติ
local warSize = 0

views.home = function()
	title.Text = "สนามประลอง · ผู้ตัดสิน"
	back.Visible = false
	if state and not state.InLobby then
		row("ต้องอยู่ที่ลานหน้าสนามประลองจึงเข้าร่วมได้")
	end
	row("⚔ ท้าดวล 1v1\nท้าผู้เล่นในลาน ชนะได้แต้มแรงก์", "เลือก", function()
		go("duel")
	end, true)
	row("🏴 สงครามแก๊ง 4v4 – 15v15\nเข้าคิวกับเพื่อนในแก๊ง ล้มหัวหน้าอีกฝั่ง", "เลือก", function()
		go("war")
	end, true)
	row("🥋 ศึกฝึกซ้อมกับบอท (เล่นคนเดียว)\n5 รอบ รอบละ 3 คน ยากขึ้นเรื่อยๆ ได้ EXP/เงิน/ชื่อเสียง", "เริ่ม", function()
		go("trial")
	end, true)
	row("👁 ชมการแข่งขัน\nแมตช์ที่กำลังแข่ง: " .. tostring(if state then #state.Matches else 0), "ดู", function()
		go("watch")
	end, true)
	row("🏆 กระดานอันดับ", "ดู", function()
		go("rank")
	end)
end

views.duel = function()
	title.Text = "ท้าดวล 1v1"
	back.Visible = true
	local list = if state then state.Nearby else {}
	if #list == 0 then
		row("ตอนนี้ไม่มีผู้เล่นอื่นในลานหน้าสนาม\nชวนเพื่อนมา หรือลองศึกฝึกซ้อมกับบอทก่อน", nil, nil, true)
	end
	for _, o in list do
		row(`{o.Name}`, "ท้าดวล", function()
			duelRemote:FireServer("Challenge", o.Id)
		end)
	end
	row("คู่ต่อสู้มี 15 วินาทีตอบรับ · ชนะ +25 / แพ้ -10 แต้มแรงก์ (ไม่ตายจริง ส่งกลับลานหลังจบ)")
end

views.war = function()
	title.Text = "สงครามแก๊ง"
	back.Visible = true
	local gang = (player:GetAttribute("Gang") :: string?) or ""
	if gang == "" then
		row("ต้องมีแก๊งก่อน (เมนู > แก๊ง) ต้องมีสมาชิกเข้าคิว 4 คนต่อแก๊ง", nil, nil, true)
		return
	end
	local queued = player:GetAttribute("WarQueued") == true
	row(`แก๊งของคุณ: {gang}\nคิวตอนนี้: {if state then state.QueueGangs else 0} แก๊ง / {if state then state.QueuePlayers else 0} คน  (ต้องมีคนรอครบขนาดทีมในแต่ละแก๊ง และ 2 แก๊ง)`, nil, nil, true)
	if player:GetAttribute("InWar") then
		row("คุณกำลังอยู่ในสงคราม!")
	else
		if not queued then
			row(`ขนาดทีม: {if warSize == 0 then "อัตโนมัติ (ใหญ่สุดที่คนรอครบ)" else `{warSize}v{warSize}`}`, "เปลี่ยน", function()
				local at = table.find(WAR_SIZES, warSize) or 1
				warSize = WAR_SIZES[at % #WAR_SIZES + 1]
				render()
			end, true)
		end
		row(if queued then "คุณอยู่ในคิวแล้ว รอแมตช์..." else "เข้าคิวเพื่อลงสนาม", if queued then "ออกคิว" else "เข้าคิว", function()
			warRemote:FireServer(if queued then "Unqueue" else "Queue", warSize)
			task.delay(0.5, refresh)
			task.delay(0.7, render)
		end)
	end
end

views.trial = function()
	title.Text = "ศึกฝึกซ้อมกับบอท"
	back.Visible = true
	row("ถูกวาร์ปเข้าสนามธีมสุ่ม สู้บอทนักเลง 3 คนต่อรอบ สูงสุด 5 รอบ\nรางวัลทุกรอบที่ผ่าน (EXP/เงิน/ชื่อเสียง) ตายหรือออก = จบ เก็บรางวัลที่ได้แล้ว", nil, nil, true)
	row("ไม่ต้องมีผู้เล่นอื่น · จบแล้วกลับลานหน้าสนาม", "เริ่มเลย", function()
		remote:FireServer("Trial")
		window.Visible = false
	end)
end

views.watch = function()
	title.Text = "ชมการแข่งขัน"
	back.Visible = true
	local list = if state then state.Matches else {}
	if #list == 0 then
		row("ตอนนี้ไม่มีแมตช์ที่กำลังแข่ง", nil, nil)
	end
	for _, m in list do
		row(`{m.Label}\nสนาม: {m.Theme}  ·  {m.Count} คนในสนาม`, "ไปชม", function()
			remote:FireServer("Spectate", m.Id)
			window.Visible = false
		end, true)
	end
end

views.rank = function()
	title.Text = "กระดานอันดับ"
	back.Visible = true
	row("ดวล 1v1 (แต้มแรงก์ผู้เล่นในเซิร์ฟเวอร์นี้)")
	for i, e in if state then state.TopPlayers else {} do
		row(`{i}. {e.Name}   {e.Points} แต้ม`)
	end
	row("สงครามแก๊ง (จำนวนชนะรวม)")
	for i, e in if state then state.TopGangs else {} do
		row(`{i}. {e.Name}   {e.Wins} ชนะ`)
	end
end

render = function()
	clear()
	local v = views[view] or views.home
	v()
end

back.MouseButton1Click:Connect(function()
	go("home")
end)
closeBtn.MouseButton1Click:Connect(function()
	window.Visible = false
end)

local function fit()
	local cam = workspace.CurrentCamera
	if cam then
		scaleFit.Scale = math.clamp(math.min(cam.ViewportSize.X / 560, cam.ViewportSize.Y / 460), 0.55, 1)
	end
end
fit()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

local function openWindow(s: any)
	state = s
	view = "home"
	window.Visible = true
	render()
	-- รีเฟรชข้อมูลสดทุก 3 วินาทีระหว่างเปิดอยู่
	task.spawn(function()
		while window.Visible do
			task.wait(3)
			if window.Visible then
				refresh()
			end
		end
	end)
end

---------------------------------------------------------------- ป๊อปอัปคำท้า + ปุ่มออกจากสนาม
local popup = Instance.new("Frame")
popup.Size = UDim2.fromOffset(360, 120)
popup.Position = UDim2.new(0.5, 0, 0, 90)
popup.AnchorPoint = Vector2.new(0.5, 0)
popup.BackgroundColor3 = PANEL
popup.Visible = false
popup.Parent = gui
corner(popup, 12)
local ps = Instance.new("UIStroke")
ps.Color = ACCENT
ps.Thickness = 2
ps.Parent = popup
local popupText = Instance.new("TextLabel")
popupText.Size = UDim2.new(1, -20, 0, 60)
popupText.Position = UDim2.fromOffset(10, 6)
popupText.BackgroundTransparency = 1
popupText.TextWrapped = true
popupText.Font = Enum.Font.FredokaOne
popupText.TextSize = 18
popupText.TextColor3 = Color3.new(1, 1, 1)
popupText.Parent = popup
local acceptBtn = button(popup, "รับคำท้า", UDim2.fromOffset(160, 40), Color3.fromHex("3E8E5A"))
acceptBtn.Position = UDim2.fromOffset(14, 70)
local declineBtn = button(popup, "ปฏิเสธ", UDim2.fromOffset(160, 40), Color3.fromHex("8E3B3B"))
declineBtn.Position = UDim2.fromOffset(186, 70)
local currentChallenger = 0
local popupToken = 0

local function hidePopup()
	popup.Visible = false
	currentChallenger = 0
end

acceptBtn.MouseButton1Click:Connect(function()
	if currentChallenger ~= 0 then
		duelRemote:FireServer("Accept", currentChallenger)
	end
	hidePopup()
end)
declineBtn.MouseButton1Click:Connect(function()
	if currentChallenger ~= 0 then
		duelRemote:FireServer("Decline", currentChallenger)
	end
	hidePopup()
end)

duelRemote.OnClientEvent:Connect(function(kind: string, userId: number, name: string)
	if kind == "Challenged" then
		currentChallenger = userId
		popupText.Text = `{name} ท้าคุณดวล 1v1!\nรับภายใน 15 วินาที`
		popup.Visible = true
		popupToken += 1
		local token = popupToken
		task.delay(15, function()
			if popupToken == token then
				hidePopup()
			end
		end)
	end
end)

local leaveBtn = button(gui, "ออกจากสนาม", UDim2.fromOffset(150, 44), Color3.fromHex("8E3B3B"))
leaveBtn.AnchorPoint = Vector2.new(0, 1)
leaveBtn.Position = UDim2.new(0, 16, 1, -90)
leaveBtn.Visible = false
leaveBtn.MouseButton1Click:Connect(function()
	remote:FireServer("Leave")
end)

local function syncRole()
	local role = player:GetAttribute("ArenaRole")
	leaveBtn.Visible = role ~= nil
	if role == "fighter" then
		leaveBtn.Text = "ยอมแพ้/ออก"
		window.Visible = false
	elseif role == "spec" then
		leaveBtn.Text = "ออกจากที่นั่งชม"
		window.Visible = false
	end
end
player:GetAttributeChangedSignal("ArenaRole"):Connect(syncRole)
syncRole()

remote.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "Open" then
		if player:GetAttribute("ArenaRole") == nil then
			openWindow(payload)
		end
	elseif kind == "State" then
		state = payload
		if window.Visible then
			render()
		end
	end
end)
