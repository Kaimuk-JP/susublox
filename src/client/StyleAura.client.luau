--!strict
-- ขอบสีประจำสไตล์รอบตัวละคร + ข้อความแจ้งเมื่อเปลี่ยนสไตล์ (ให้เห็นชัดว่าสวมแล้ว)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StyleData = require(ReplicatedStorage.Shared.Styles)
local player = Players.LocalPlayer

local function applyAura(character: Model)
	local function refresh()
		local id = character:GetAttribute("Style")
		local old = character:FindFirstChild("StyleAura")
		if old then
			old:Destroy()
		end
		local style = typeof(id) == "string" and StyleData.Styles[id]
		if not style then
			return
		end
		local h = Instance.new("Highlight")
		h.Name = "StyleAura"
		h.FillTransparency = 1
		h.OutlineColor = Color3.fromHex(style.Color)
		h.OutlineTransparency = 0.35
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = character
	end
	character:GetAttributeChangedSignal("Style"):Connect(refresh)
	refresh()
end

local function watchPlayer(p: Player)
	if p.Character then
		applyAura(p.Character)
	end
	p.CharacterAdded:Connect(applyAura)
end
for _, p in Players:GetPlayers() do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)

-- ข้อความแจ้งเมื่อเปลี่ยนสไตล์ของเรา
local gui = Instance.new("ScreenGui")
gui.Name = "StyleToast"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 80)
toast.Size = UDim2.fromOffset(320, 40)
toast.BackgroundColor3 = Color3.fromHex("2B2D42")
toast.TextColor3 = Color3.fromHex("FFE066")
toast.Font = Enum.Font.FredokaOne
toast.TextSize = 18
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.Parent = gui
Instance.new("UICorner", toast)

local first = true
local function show(text: string)
	toast.Text = text
	toast.BackgroundTransparency, toast.TextTransparency = 0.15, 0
	task.delay(1.8, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
end

player:GetAttributeChangedSignal("Style"):Connect(function()
	local id = player:GetAttribute("Style")
	if first then
		first = false -- ครั้งแรกคือค่าเริ่มต้นตอนโหลด ไม่ต้องแจ้ง
		return
	end
	local style = typeof(id) == "string" and StyleData.Styles[id]
	if style then
		show(`สวมสไตล์ {style.Name} แล้ว!`)
	end
end)
