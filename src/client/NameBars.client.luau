--!strict
-- ชื่อ + แถบเลือดเหนือหัวผู้เล่นอื่น/ศัตรู/บอส (ซ่อนชื่อมาตรฐานของ Roblox)
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local function attach(character: Model, label: string, color: Color3, big: boolean)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head") :: BasePart?
	if not hum or not head or head:FindFirstChild("NameBar") then
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local gui = Instance.new("BillboardGui")
	gui.Name = "NameBar"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(if big then 180 else 120, if big then 44 else 34)
	gui.StudsOffset = Vector3.new(0, if big then 3.8 else 2.8, 0)
	gui.MaxDistance = 90
	gui.Parent = head

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.BackgroundTransparency = 1
	name.Text = label
	name.TextColor3 = color
	name.TextStrokeTransparency = 0.3
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0.05, 0.62)
	back.Size = UDim2.fromScale(0.9, 0.28)
	back.BackgroundColor3 = Color3.fromHex("2B2D42")
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromHex("EF233C")
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local function update()
		fill.Size = UDim2.fromScale(math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1), 1)
	end
	hum.HealthChanged:Connect(update)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end

local function playerLabel(p: Player): string
	local level = p:GetAttribute("Level") or 1
	local gang = p:GetAttribute("Gang")
	local tag = if typeof(gang) == "string" and gang ~= "" then `[{gang}] ` else ""
	return `{tag}{p.DisplayName}  Lv.{level}`
end

local function watchPlayer(p: Player)
	if p == localPlayer then
		return
	end
	local function onChar(char: Model)
		char:WaitForChild("Head")
		attach(char, playerLabel(p), Color3.new(1, 1, 1), false)
		p:GetAttributeChangedSignal("Level"):Connect(function()
			local head = char:FindFirstChild("Head")
			local bar = head and head:FindFirstChild("NameBar")
			local text = bar and bar:FindFirstChildOfClass("TextLabel")
			if text then
				text.Text = playerLabel(p)
			end
		end)
	end
	p.CharacterAdded:Connect(onChar)
	if p.Character then
		task.spawn(onChar, p.Character)
	end
end
for _, p in Players:GetPlayers() do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)

local function watchFolder(name: string)
	task.spawn(function()
		local folder = workspace:WaitForChild(name, 30)
		if not folder then
			return
		end
		local function onChild(model: Instance)
			if not model:IsA("Model") then
				return
			end
			task.spawn(function()
				model:WaitForChild("Head", 10)
				local boss = model:GetAttribute("IsBoss") == true
				local level = model:GetAttribute("NpcLevel") or 1
				local text = if boss then `{model:FindFirstChildOfClass("Humanoid") and (model :: any).Humanoid.DisplayName or model.Name}` else `{model.Name}  Lv.{level}`
				attach(model, text, if boss then Color3.fromHex("FFE066") else Color3.fromHex("FF8A8A"), boss)
			end)
		end
		for _, c in folder:GetChildren() do
			onChild(c)
		end
		folder.ChildAdded:Connect(onChild)
	end)
end
watchFolder("Npcs")
watchFolder("Bosses")
