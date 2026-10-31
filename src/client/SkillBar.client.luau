--!strict
-- แถบสกิลล่างกลางจอ: ชื่อสกิล คูลดาวน์ และล็อกตาม Mastery (Z X C V + ไม้ตาย G)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local StyleData = require(ReplicatedStorage.Shared.Styles)
local player = Players.LocalPlayer

local PANEL = Color3.fromHex("2B2D42")
local ACCENT = Color3.fromHex("FFE066")

local gui = Instance.new("ScreenGui")
gui.Name = "SkillBar"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -16)
bar.Size = UDim2.fromOffset(5 * 76, 72)
bar.BackgroundTransparency = 1
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = bar

type Slot = { Key: string, Label: string, Frame: Frame, Name: TextLabel, Cool: Frame, Count: TextLabel, Lock: TextLabel }
local slots: { Slot } = {}

local order = { { "Z", "Z" }, { "X", "X" }, { "C", "C" }, { "V", "V" }, { "U", "G" } }
for _, def in order do
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(70, 70)
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.15
	f.Parent = bar
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT
	stroke.Transparency = 0.5
	stroke.Parent = f

	local key = Instance.new("TextLabel")
	key.Size = UDim2.fromOffset(22, 22)
	key.Position = UDim2.fromOffset(4, 2)
	key.BackgroundTransparency = 1
	key.Text = def[2]
	key.TextColor3 = ACCENT
	key.Font = Enum.Font.FredokaOne
	key.TextSize = 18
	key.Parent = f

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -6, 0, 34)
	name.Position = UDim2.new(0, 3, 1, -36)
	name.BackgroundTransparency = 1
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 11
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Bottom
	name.Parent = f

	local cool = Instance.new("Frame")
	cool.Size = UDim2.fromScale(1, 0)
	cool.AnchorPoint = Vector2.new(0, 1)
	cool.Position = UDim2.fromScale(0, 1)
	cool.BackgroundColor3 = Color3.new(0, 0, 0)
	cool.BackgroundTransparency = 0.4
	cool.BorderSizePixel = 0
	cool.ZIndex = 2
	cool.Parent = f
	Instance.new("UICorner", cool).CornerRadius = UDim.new(0, 10)

	local count = Instance.new("TextLabel")
	count.Size = UDim2.fromScale(1, 1)
	count.BackgroundTransparency = 1
	count.TextColor3 = Color3.new(1, 1, 1)
	count.Font = Enum.Font.FredokaOne
	count.TextSize = 24
	count.ZIndex = 3
	count.Text = ""
	count.Parent = f

	local lock = Instance.new("TextLabel")
	lock.Size = UDim2.fromScale(1, 1)
	lock.BackgroundColor3 = Color3.new(0, 0, 0)
	lock.BackgroundTransparency = 0.35
	lock.TextColor3 = Color3.fromHex("FFB7C5")
	lock.Font = Enum.Font.FredokaOne
	lock.TextSize = 12
	lock.TextWrapped = true
	lock.ZIndex = 4
	lock.Visible = false
	lock.Parent = f
	Instance.new("UICorner", lock).CornerRadius = UDim.new(0, 10)

	table.insert(slots, { Key = def[1], Label = def[2], Frame = f, Name = name, Cool = cool, Count = count, Lock = lock })
end

RunService.RenderStepped:Connect(function()
	local styleId = player:GetAttribute("Style")
	local style = typeof(styleId) == "string" and StyleData.Styles[styleId]
	if not style then
		return
	end
	local mastery = (player:GetAttribute("MasteryLevel") :: number?) or 1
	local char = player.Character
	local ult = (char and char:GetAttribute("Ult") :: number?) or 0
	local now = workspace:GetServerTimeNow()

	for _, s in slots do
		local isUlt = s.Key == "U"
		local skill = if isUlt then style.Ultimate else (style.Skills :: any)[s.Key]
		s.Name.Text = if isUlt then skill.Name else `{skill.Name}\n⚡{StyleData.SkillCost(skill)}`
		local need = StyleData.MasteryUnlock[if isUlt then "Ultimate" else s.Key]
		if mastery < need then
			s.Lock.Visible = true
			s.Lock.Text = `Mastery\n{need}`
			s.Cool.Size = UDim2.fromScale(1, 0)
			s.Count.Text = ""
		else
			s.Lock.Visible = false
			local remaining = ((player:GetAttribute("CD_" .. s.Key) :: number?) or 0) - now
			local length = (player:GetAttribute("CDLen_" .. s.Key) :: number?) or math.max(skill.Cooldown, 1)
			if isUlt then
				-- ไม้ตายพร้อมเมื่อหลอดเต็ม
				local ready = ult >= Config.UltMax
				s.Cool.Size = UDim2.fromScale(1, if ready then 0 else 1 - ult / Config.UltMax)
				s.Count.Text = if ready then "" else `{math.floor(ult)}%`
				s.Frame.UIStroke.Transparency = if ready then 0 else 0.6
			elseif remaining > 0 then
				s.Cool.Size = UDim2.fromScale(1, math.clamp(remaining / length, 0, 1))
				s.Count.Text = tostring(math.ceil(remaining))
			else
				s.Cool.Size = UDim2.fromScale(1, 0)
				s.Count.Text = ""
			end
		end
	end
end)
