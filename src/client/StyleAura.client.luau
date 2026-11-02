--!strict
-- ขอบสีประจำสไตล์รอบตัวละคร + ข้อความแจ้งเมื่อเปลี่ยนสไตล์ (ให้เห็นชัดว่าสวมแล้ว)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local StyleData = require(ReplicatedStorage.Shared.Styles)
local player = Players.LocalPlayer

local function applyAura(character: Model)
	local function refresh()
		local id = character:GetAttribute("Style")
		for _, d in character:GetDescendants() do
			if d.Name == "StyleAuraFlame" then
				d:Destroy() -- เปลวผูกกับชิ้นส่วนตัว ไม่ได้อยู่ใน folder จึงต้องลบเอง
			end
		end
		local old = character:FindFirstChild("StyleAura")
		if old then
			old:Destroy()
		end
		local style = typeof(id) == "string" and StyleData.Styles[id]
		if not style then
			return
		end
		-- ออร่าพลังงานแบบเกมต่อสู้อนิเมะ: เปลวลอยขึ้นจากตัว + ริบบิ้นเกลียว ไม่ใช้ Highlight (ไม่ทับสีชุด)
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
			e.Name = "StyleAuraFlame"
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

		-- เส้นพลังแบบอนิเมะ: ริบบิ้นเกลียวหมุนรอบตัว + เส้นแสงแนวตั้งพุ่งขึ้นจากพื้น (ไม่มีวงกลมที่พื้น)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = character:FindFirstChildOfClass("Humanoid")
		if root and hum then
			local feetY = -(root.Size.Y / 2 + hum.HipHeight)
			local function dot(name: string, size: Vector3, transparency: number): Part
				local p = Instance.new("Part")
				p.Name = name
				p.Anchored = true
				p.Size = size
				p.Color = hot
				p.Material = Enum.Material.Neon
				p.Transparency = transparency
				p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
				p.Parent = folder
				return p
			end
			-- ริบบิ้นเกลียว: จุดโคจรที่ลากรอยไว้ด้วย Trail (จุดเองโปร่งใส)
			local orbiters = {}
			for i = 1, 4 do
				local o = dot("Orbiter", Vector3.new(0.2, 0.2, 0.2), 1)
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, 0.6, 0)
				a0.Parent = o
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, -0.6, 0)
				a1.Parent = o
				local t = Instance.new("Trail")
				t.Attachment0, t.Attachment1 = a0, a1
				t.Lifetime = 1
				t.MinLength = 0
				t.LightEmission = 1
				t.LightInfluence = 0
				t.Color = ColorSequence.new(hot, color)
				t.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.1),
					NumberSequenceKeypoint.new(1, 1),
				})
				t.WidthScale = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				})
				t.Parent = o
				orbiters[i] = o
			end
			local t0 = os.clock()
			local inWorld = false
			local conn: RBXScriptConnection
			conn = RunService.RenderStepped:Connect(function()
				if not root:IsDescendantOf(workspace) then
					-- ตัวละครเก่าถูกถอดออกจาก workspace (ตาย/เกิดใหม่) แต่ root.Parent ยังเป็นโมเดลเดิม จึงต้องเช็คแบบนี้
					-- (ตัวละครที่เพิ่งเกิดอาจยังไม่เข้า workspace จึงเริ่มเช็คหลังเห็นว่าเคยอยู่แล้วเท่านั้น)
					if inWorld then
						conn:Disconnect()
						folder:Destroy()
					end
					return
				end
				inWorld = true
				local t = os.clock() - t0
				local base = root.CFrame * CFrame.new(0, feetY, 0)
				for i, o in orbiters do
					local ang = t * (2.6 + i * 0.25) + i * math.pi / 2
					local h = 2.4 + 2.2 * math.sin(t * 1.3 + i * 1.7) -- ขึ้นลงเป็นเกลียว
					o.CFrame = CFrame.new(base.Position + Vector3.new(math.cos(ang) * 2.3, h, math.sin(ang) * 2.3))
				end
			end)
			folder.Destroying:Connect(function()
				conn:Disconnect()
			end)
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
