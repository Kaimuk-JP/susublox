--!strict
-- ชุดตัวละครแบบโค้ดล้วน: เปลี่ยนสีร่างกาย + ชิ้นส่วนตกแต่งเชื่อมกับตัว (ไม่ใช้ asset ภายนอก)
-- ทุกคนเริ่มด้วยชุดนักเรียน; สวมชุดที่ซื้อ/ได้มา ผู้เล่นอื่นเห็นด้วย
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Outfits = require(ReplicatedStorage.Shared.Outfits)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "OutfitRemote"
remote.Parent = ReplicatedStorage

local function hex(c: string): Color3
	return Color3.fromHex(c)
end

type Look = {
	Torso: string,
	Arms: string,
	Legs: string,
	Shoes: string?,
	Decor: ((character: Model, add: (partName: string, size: Vector3, offset: CFrame, color: string, material: Enum.Material?, shape: Enum.PartType?) -> ()) -> ())?,
	Aura: boolean?,
}

local looks: { [string]: Look } = {
	Uniform_School = {
		Torso = "FFFFFF",
		Arms = "FFFFFF",
		Legs = "2B2D42",
		Shoes = "2B2D42",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(0.9, 0.55, 0.25), CFrame.new(0, 0.55, -0.62), "EF233C") -- ริบบิ้น
			add("UpperTorso", Vector3.new(1.9, 0.18, 1.1), CFrame.new(0, 0.95, -0.05), "2B2D42") -- ปกเสื้อ
		end,
	},
	Uniform_Sakura = {
		Torso = "FFB7C5",
		Arms = "FFB7C5",
		Legs = "FFFFFF",
		Shoes = "FFFFFF",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(2.1, 0.22, 1.3), CFrame.new(0, 0.95, -0.05), "FFFFFF") -- ปกกะลาสี
			add("UpperTorso", Vector3.new(0.9, 0.55, 0.25), CFrame.new(0, 0.55, -0.62), "EF233C")
			add("Head", Vector3.new(0.5, 0.5, 0.2), CFrame.new(0.55, 0.55, -0.4), "FF8FAB", Enum.Material.SmoothPlastic, Enum.PartType.Ball) -- กิ๊บติดผม
		end,
	},
	Uniform_Night = {
		Torso = "1B1D3A",
		Arms = "1B1D3A",
		Legs = "1B1D3A",
		Shoes = "0F1024",
		Decor = function(_, add)
			for i = 0, 2 do
				add("UpperTorso", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.55 - i * 0.45, -0.58), "FFE066", Enum.Material.Neon, Enum.PartType.Ball) -- กระดุมทอง
			end
			add("UpperTorso", Vector3.new(1.9, 0.14, 1.1), CFrame.new(0, 0.95, -0.05), "FFE066", Enum.Material.Neon)
		end,
	},
	Jacket_Gang = {
		Torso = "15151A",
		Arms = "15151A",
		Legs = "333340",
		Shoes = "EF233C",
		Decor = function(character, add)
			local player = Players:GetPlayerFromCharacter(character)
			local gang = player and player:GetAttribute("GangColor")
			local color = if typeof(gang) == "string" and gang ~= "" then gang else "EF233C"
			add("UpperTorso", Vector3.new(1.7, 1.7, 0.12), CFrame.new(0, 0, 0.62), color) -- ลายหลัง
			add("UpperTorso", Vector3.new(0.5, 0.5, 1.3), CFrame.new(-1.15, 0.8, 0), "15151A") -- ไหล่
			add("UpperTorso", Vector3.new(0.5, 0.5, 1.3), CFrame.new(1.15, 0.8, 0), "15151A")
			add("UpperTorso", Vector3.new(0.18, 1.9, 0.12), CFrame.new(0, 0, -0.62), color) -- แถบซิป
		end,
	},
	Aura_Sparkle = {
		Torso = "FFFFFF",
		Arms = "FFFFFF",
		Legs = "2B2D42",
		Shoes = "2B2D42",
		Aura = true,
	},
}

local function clearOutfit(character: Model)
	for _, d in character:GetDescendants() do
		if d.Name == "OutfitDecor" or d.Name == "OutfitAura" then
			d:Destroy()
		end
	end
	for _, c in character:GetChildren() do
		if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") then
			c:Destroy() -- ลบเสื้อกางเกงเดิมของอวาตาร์ให้สีชุดเกมเห็นชัด
		end
	end
end

local function setColor(character: Model, names: { string }, color: Color3)
	for _, n in names do
		local p = character:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			p.Color = color
		end
	end
end

local function apply(character: Model, id: string)
	local look = looks[id] or looks[Outfits.Default]
	-- Aura_Sparkle ใช้ชุดนักเรียนเป็นฐานแล้วเพิ่มออร่า
	local base = if look.Aura then looks[Outfits.Default] else look
	clearOutfit(character)

	local bc = character:FindFirstChildOfClass("BodyColors")
	if bc then
		bc:Destroy() -- ไม่ให้ BodyColors ทับสีที่ตั้งเอง
	end
	setColor(character, { "UpperTorso", "LowerTorso" }, hex(base.Torso))
	setColor(character, { "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }, hex(base.Arms))
	setColor(character, { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }, hex(base.Legs))
	setColor(character, { "LeftFoot", "RightFoot" }, hex(base.Shoes or base.Legs))

	local function add(partName: string, size: Vector3, offset: CFrame, color: string, material: Enum.Material?, shape: Enum.PartType?)
		local anchor = character:FindFirstChild(partName) :: BasePart?
		if not anchor then
			return
		end
		local p = Instance.new("Part")
		p.Name = "OutfitDecor"
		p.Size = size
		p.Color = hex(color)
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Massless = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CFrame = anchor.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchor
		weld.Part1 = p
		weld.Parent = p
		p.Parent = character
	end

	if base.Decor then
		base.Decor(character, add)
	end

	if look.Aura then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local e = Instance.new("ParticleEmitter")
			e.Name = "OutfitAura"
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(hex("FFB7C5"), hex("FFE066"))
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
			e.Lifetime = NumberRange.new(0.8, 1.4)
			e.Speed = NumberRange.new(1, 3)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Rate = 22
			e.LightEmission = 1
			e.Parent = root
			local light = Instance.new("PointLight")
			light.Name = "OutfitAura"
			light.Color = hex("FFB7C5")
			light.Range = 10
			light.Brightness = 0.8
			light.Parent = root
		end
	end
end

local function publish(player: Player)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	player:SetAttribute("Outfit", p.EquippedOutfit)
	for _, id in Outfits.Order do
		player:SetAttribute("OutfitOwned_" .. id, id == Outfits.Default or table.find(p.Owned, id) ~= nil)
	end
end

local function applyTo(player: Player)
	local p = PlayerData.Get(player)
	local char = player.Character
	if p and char and char:FindFirstChild("UpperTorso") then
		apply(char, p.EquippedOutfit)
	end
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown, id: unknown)
	local p = PlayerData.Get(player)
	if not p or action ~= "Equip" or typeof(id) ~= "string" or not looks[id] then
		return
	end
	if id ~= Outfits.Default and not table.find(p.Owned, id) then
		return -- ต้องเป็นเจ้าของก่อน
	end
	p.EquippedOutfit = id
	publish(player)
	applyTo(player)
end)

local function setup(player: Player)
	for _ = 1, 100 do
		if PlayerData.Get(player) then
			break
		end
		task.wait(0.2)
	end
	publish(player)
	local function onChar(char: Model)
		char:WaitForChild("UpperTorso", 10)
		task.wait(0.5) -- รอให้ Humanoid ใส่คำอธิบายอวาตาร์เสร็จก่อน
		applyTo(player)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		task.spawn(onChar, player.Character)
	end
end
Players.PlayerAdded:Connect(setup)
for _, pl in Players:GetPlayers() do
	task.spawn(setup, pl)
end

-- ชุดที่ได้จากการซื้อ/บอส/Battle Pass เพิ่มเข้า Owned โดยตรง จึงซิงก์สถานะความเป็นเจ้าของเป็นระยะ
task.spawn(function()
	while true do
		task.wait(2)
		for _, pl in Players:GetPlayers() do
			publish(pl)
		end
	end
end)
