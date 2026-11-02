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
		-- ออร่าพลังงานแบบเกมต่อสู้อนิเมะ: เปลวลอยขึ้นจากตัว + วงพลังที่พื้น ไม่ใช้ Highlight (ไม่ทับสีชุด)
		local color = Color3.fromHex(style.Color)
		local hot = color:Lerp(Color3.new(1, 1, 1), 0.55)
		local folder = Instance.new("Folder")
		folder.Name = "StyleAura"
		folder.Parent = character

		local function flame(part: BasePart?, rate: number, size: number)
			if not part then
				return
			end
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/fire_main.dds"
			e.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, hot),
				ColorSequenceKeypoint.new(0.5, color),
				ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.5)),
			})
			e.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, size),
				NumberSequenceKeypoint.new(0.6, size * 0.8),
				NumberSequenceKeypoint.new(1, 0),
			})
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(0.7, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			})
			e.Lifetime = NumberRange.new(0.6, 1.1)
			e.Speed = NumberRange.new(3, 6)
			e.Acceleration = Vector3.new(0, 7, 0) -- ลอยขึ้นเหมือนเปลวไฟ
			e.EmissionDirection = Enum.NormalId.Top
			e.SpreadAngle = Vector2.new(12, 12)
			e.Rate = rate
			e.LightEmission = 0.9
			e.LightInfluence = 0
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-40, 40)
			e.ZOffset = -1 -- วาดหลังตัวละคร ไม่บังชุด
			e.Parent = part
		end
		flame(character:FindFirstChild("UpperTorso") :: BasePart?, 14, 3.2)
		flame(character:FindFirstChild("LowerTorso") :: BasePart?, 10, 2.8)
		flame(character:FindFirstChild("LeftLowerArm") :: BasePart?, 5, 1.6)
		flame(character:FindFirstChild("RightLowerArm") :: BasePart?, 5, 1.6)
		flame(character:FindFirstChild("LeftLowerLeg") :: BasePart?, 5, 1.8)
		flame(character:FindFirstChild("RightLowerLeg") :: BasePart?, 5, 1.8)

		-- วงพลังที่พื้นใต้เท้า
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = character:FindFirstChildOfClass("Humanoid")
		if root and hum then
			local ring = Instance.new("Part")
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.12, 6, 6)
			ring.Color = color
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.55
			ring.CanCollide, ring.CanQuery, ring.CanTouch = false, false, false
			ring.Massless = true
			ring.CastShadow = false
			ring.Parent = folder
			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = ring
			weld.C0 = CFrame.new(0, -(root.Size.Y / 2 + hum.HipHeight), 0) * CFrame.Angles(0, 0, math.rad(90))
			weld.Parent = ring
			TweenService:Create(
				ring,
				TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.8, Size = Vector3.new(0.12, 7.4, 7.4) }
			):Play()
		end
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
