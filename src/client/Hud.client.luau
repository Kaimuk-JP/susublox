--!strict
-- HUD: หลอดเลือด พลังงาน ท่าไม้ตาย เลเวล/EXP และคูลดาวน์สกิล
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local StyleData = require(ReplicatedStorage.Shared.Styles)
local player = Players.LocalPlayer

local COLORS = {
	Health = Color3.fromHex("EF233C"),
	Stamina = Color3.fromHex("7EC8E3"),
	Ult = Color3.fromHex("FFE066"),
	Exp = Color3.fromHex("FFB7C5"),
	Panel = Color3.fromHex("2B2D42"),
}

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(name: string, y: number, color: Color3): (Frame, TextLabel)
	local back = Instance.new("Frame")
	back.Name = name
	back.Size = UDim2.fromOffset(260, 18)
	back.Position = UDim2.fromOffset(16, y)
	back.BackgroundColor3 = COLORS.Panel
	back.BackgroundTransparency = 0.2
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 9)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 9)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 13
	label.ZIndex = 2
	label.Parent = back
	return fill, label
end

local healthFill, healthLabel = bar("Health", 16, COLORS.Health)
local staminaFill, staminaLabel = bar("Stamina", 40, COLORS.Stamina)
local manaFill, manaLabel = bar("Mana", 64, Color3.fromHex("6C7BFF"))
local ultFill, ultLabel = bar("Ult", 88, COLORS.Ult)
local expFill, expLabel = bar("Exp", 112, COLORS.Exp)

local info = Instance.new("TextLabel")
info.Position = UDim2.fromOffset(16, 136)
info.Size = UDim2.fromOffset(260, 20)
info.BackgroundTransparency = 1
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextColor3 = Color3.new(1, 1, 1)
info.TextStrokeTransparency = 0.4
info.Font = Enum.Font.FredokaOne
info.TextSize = 14
info.Parent = gui

local goalLabel = Instance.new("TextLabel")
goalLabel.Position = UDim2.fromOffset(16, 154)
goalLabel.Size = UDim2.fromOffset(300, 34)
goalLabel.BackgroundTransparency = 1
goalLabel.TextXAlignment = Enum.TextXAlignment.Left
goalLabel.TextYAlignment = Enum.TextYAlignment.Top
goalLabel.TextColor3 = Color3.fromHex("FFE066")
goalLabel.TextStrokeTransparency = 0.5
goalLabel.Font = Enum.Font.FredokaOne
goalLabel.TextSize = 12
goalLabel.TextWrapped = true
goalLabel.Parent = gui

local safeLabel = Instance.new("TextLabel")
safeLabel.AnchorPoint = Vector2.new(0.5, 0)
safeLabel.Position = UDim2.new(0.5, 0, 0, 90)
safeLabel.Size = UDim2.fromOffset(340, 34)
safeLabel.BackgroundColor3 = COLORS.Panel
safeLabel.BackgroundTransparency = 0.2
safeLabel.TextColor3 = Color3.fromHex("7EC8E3")
safeLabel.Font = Enum.Font.FredokaOne
safeLabel.TextSize = 16
safeLabel.Text = "โซนปลอดภัย: ต่อสู้ไม่ได้ ไปหลังโรงเรียนเพื่อสู้กับศัตรู"
safeLabel.Visible = false
safeLabel.Parent = gui
Instance.new("UICorner", safeLabel)

local function set(fill: Frame, label: TextLabel, value: number, max: number, text: string)
	fill.Size = UDim2.fromScale(math.clamp(value / math.max(max, 1), 0, 1), 1)
	label.Text = text
end

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if char and hum then
		set(healthFill, healthLabel, hum.Health, hum.MaxHealth, `เลือด {math.ceil(hum.Health)}/{math.ceil(hum.MaxHealth)}`)
		local maxStamina = (char:GetAttribute("MaxStamina") :: number?) or Config.BaseStamina
		local stamina = (char:GetAttribute("Stamina") :: number?) or maxStamina
		set(staminaFill, staminaLabel, stamina, maxStamina, `พลังงาน {math.floor(stamina)}`)
		local maxMana = (char:GetAttribute("MaxMana") :: number?) or Config.BaseMana
		local mana = (char:GetAttribute("Mana") :: number?) or maxMana
		set(manaFill, manaLabel, mana, maxMana, `มานา {math.floor(mana)}/{math.floor(maxMana)}`)
		local ult = (char:GetAttribute("Ult") :: number?) or 0
		set(ultFill, ultLabel, ult, Config.UltMax, if ult >= Config.UltMax then "ไม้ตายพร้อม! (G)" else `ไม้ตาย {math.floor(ult)}%`)
	end
	local exp = (player:GetAttribute("Exp") :: number?) or 0
	local need = (player:GetAttribute("ExpNeeded") :: number?) or 100
	set(expFill, expLabel, exp, need, `EXP {exp}/{need}`)
	safeLabel.Visible = player:GetAttribute("InSafeZone") == true
	-- เป้าหมายถัดไป: สกิลที่จะปลดล็อก + โบนัสรายวัน/ทีม
	local mastery = (player:GetAttribute("MasteryLevel") :: number?) or 1
	local nextKey, nextNeed = nil, math.huge
	for key, need in StyleData.MasteryUnlock do
		if need > mastery and need < nextNeed then
			nextKey, nextNeed = key, need
		end
	end
	local goal = if nextKey then `เป้าหมาย: ปลดล็อกสกิล {if nextKey == "Ultimate" then "ไม้ตาย" else nextKey} ที่ Mastery {nextNeed} (ตอนนี้ {mastery})` else "ปลดล็อกสกิลครบแล้ว!"
	local daily = (player:GetAttribute("DailyBonusLeft") :: number?)
	if daily == nil or daily > 0 then
		goal ..= `\nโบนัสวันนี้: EXP x2 อีก {daily or 5} ตัว`
	end
	local party = (player:GetAttribute("PartyBonus") :: number?) or 0
	if party > 0 then
		goal ..= `  | ทีม +{party * 15}%`
	end
	goalLabel.Text = goal
	info.Text = `Lv.{player:GetAttribute("Level") or 1}  {player:GetAttribute("Rank") or ""}  ¥{player:GetAttribute("Yen") or 0}`
end)
