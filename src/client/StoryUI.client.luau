--!strict
-- การ์ดเป้าหมายบน HUD: เนื้อเรื่องหลักขั้นปัจจุบัน + ใบสั่งล่าแก๊งที่รับอยู่ (บอกเสมอว่า "ต้องทำอะไรต่อ")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PANEL, GOLD, PINK = Color3.fromHex("2B2D42"), Color3.fromHex("FFE066"), Color3.fromHex("FFB7C5")

local gui = Instance.new("ScreenGui")
gui.Name = "StoryUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Position = UDim2.fromOffset(16, 172)
card.Size = UDim2.fromOffset(300, 0)
card.AutomaticSize = Enum.AutomaticSize.Y
card.BackgroundColor3 = PANEL
card.BackgroundTransparency = 0.25
card.Parent = gui
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
pad.Parent = card
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 2)
list.Parent = card

local function label(color: Color3, size: number, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.TextColor3 = color
	l.Font = Enum.Font.FredokaOne
	l.TextSize = size
	l.LayoutOrder = order
	l.Parent = card
	return l
end

local storyTitle = label(GOLD, 14, 1)
local storyText = label(Color3.new(1, 1, 1), 13, 2)
local bountyText = label(PINK, 13, 3)
local bountyReward = label(Color3.fromHex("BFE9FF"), 12, 4)

RunService.Heartbeat:Connect(function()
	local title = player:GetAttribute("StoryTitle")
	local text = player:GetAttribute("StoryText")
	local bounty = player:GetAttribute("BountyText")
	card.Visible = typeof(title) == "string" or typeof(bounty) == "string"
	storyTitle.Text = if typeof(title) == "string" then "📖 " .. title else ""
	storyTitle.Visible = typeof(title) == "string"
	storyText.Text = if typeof(text) == "string" then text else ""
	storyText.Visible = typeof(text) == "string"
	bountyText.Text = if typeof(bounty) == "string" then "🎯 " .. bounty else ""
	bountyText.Visible = typeof(bounty) == "string"
	local reward = player:GetAttribute("BountyReward")
	bountyReward.Text = if typeof(reward) == "string" then "รางวัล: " .. reward else ""
	bountyReward.Visible = typeof(reward) == "string" and typeof(bounty) == "string"
end)
