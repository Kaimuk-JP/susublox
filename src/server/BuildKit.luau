--!strict
-- ชุดตัวช่วยสร้างฉากจากชิ้นส่วน ใช้โดย WorldBuilder (ต้นไม้ อาคาร ถนน ป้าย ไฟ ฯลฯ)
local BK = {}

BK.rng = Random.new(1234)

function BK.part(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function BK.box(name: string, x1: number, x2: number, y1: number, y2: number, z1: number, z2: number, color: Color3, parent: Instance, material: Enum.Material?): Part
	return BK.part(name, Vector3.new(x2 - x1, y2 - y1, z2 - z1), Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), color, parent, material)
end

function BK.cylinder(name: string, radius: number, height: number, position: Vector3, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = BK.part(name, Vector3.new(height, radius * 2, radius * 2), position, color, parent, material)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

function BK.ball(name: string, diameter: number, position: Vector3, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = BK.part(name, Vector3.one * diameter, position, color, parent, material)
	p.Shape = Enum.PartType.Ball
	return p
end

function BK.noCollide(p: BasePart)
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
end

function BK.light(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness
	l.Parent = p
end

-- ป้ายข้อความ yaw: 0 = หันไป -Z, 180 = หันไป +Z, 90 = หันไป -X, -90 = หันไป +X
function BK.sign(parent: Instance, text: string, size: Vector3, position: Vector3, yaw: number, bg: Color3, fg: Color3): Part
	local p = BK.part("Sign", size, position, bg, parent)
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = fg
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	return p
end

local hex = Color3.fromHex

local function jitter(c: Color3, amt: number): Color3
	local h, sat, v = c:ToHSV()
	return Color3.fromHSV(h, math.clamp(sat + BK.rng:NextNumber(-amt, amt), 0, 1), math.clamp(v + BK.rng:NextNumber(-amt, amt), 0, 1))
end
BK.jitter = jitter

-- กิ่ง/ลำต้นเป็นทรงกระบอกเอียงจากจุด a ไป b
function BK.branch(parent: Instance, a: Vector3, b: Vector3, radius: number, color: Color3, material: Enum.Material?): Part
	local mid = (a + b) / 2
	local p = BK.part("Branch", Vector3.new((b - a).Magnitude, radius * 2, radius * 2), mid, color, parent, material or Enum.Material.Wood)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
	return p
end

-- ก้อนใบไม้/พุ่ม: ลูกบอลแบนเล็กน้อย หมุนสุ่มให้ไม่ซ้ำกัน
function BK.blob(parent: Instance, pos: Vector3, d: number, color: Color3, material: Enum.Material?): Part
	local p = BK.ball("Leaves", d, pos, color, parent, material or Enum.Material.Grass)
	p.Size = Vector3.new(d, d * BK.rng:NextNumber(0.72, 0.92), d * BK.rng:NextNumber(0.88, 1.05))
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, BK.rng:NextNumber(0, 6.28), 0)
	return p
end

function BK.pine(parent: Instance, x: number, z: number, h: number)
	local bark = jitter(hex("6B4E3B"), 0.04)
	BK.cylinder("PineTrunk", h * 0.045 + 0.35, h * 0.5, Vector3.new(x, h * 0.25, z), bark, parent, Enum.Material.Wood)
	local green = jitter(hex("3E8453"), 0.05)
	for i = 0, 4 do
		local d = h * 0.46 * (1 - i * 0.18)
		BK.blob(parent, Vector3.new(x, h * 0.22 + i * h * 0.15 + d * 0.2, z), d, jitter(green, 0.03))
	end
	BK.blob(parent, Vector3.new(x, h * 0.98, z), h * 0.12, jitter(green, 0.03))
end

-- ต้นไม้จริงที่นำเข้าและตรวจแล้ว (ServerStorage.ImportedAssets.Trees) ข้อตกลง: Pivot = โคนต้นที่พื้น สูงราว 12 studs ไม่มีสคริปต์
-- ถ้ามีจะใช้แทนต้นไม้ที่ประกอบจากก้อนกลม; ถ้าไม่มีก็ใช้แบบเดิม
function BK.importedTree(parent: Instance, x: number, z: number, scale: number): boolean
	local assets = game:GetService("ServerStorage"):FindFirstChild("ImportedAssets")
	local folder = assets and assets:FindFirstChild("Trees")
	local list = folder and folder:GetChildren() or {}
	if #list == 0 then
		return false
	end
	local src = list[BK.rng:NextInteger(1, #list)]
	if not src:IsA("Model") then
		return false
	end
	local model = src:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model:ScaleTo(math.max(0.5, scale) * BK.rng:NextNumber(0.9, 1.15))
	model:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, BK.rng:NextNumber(0, 6.28), 0))
	model.Parent = parent
	return true
end

function BK.roundTree(parent: Instance, x: number, z: number, scale: number, leaf: Color3?)
	if BK.importedTree(parent, x, z, scale) then
		return
	end
	local s = scale
	local bark = jitter(hex("7A5A44"), 0.04)
	BK.cylinder("TrunkBase", 1.25 * s, 1.5 * s, Vector3.new(x, 0.75 * s, z), bark, parent, Enum.Material.Wood)
	local top = Vector3.new(x + BK.rng:NextNumber(-0.7, 0.7) * s, 8 * s, z + BK.rng:NextNumber(-0.7, 0.7) * s)
	BK.branch(parent, Vector3.new(x, 1 * s, z), top, 0.8 * s, bark)
	local base = leaf or hex("5FAE5C")
	for _ = 1, 2 do
		local a = BK.rng:NextNumber(0, 6.28)
		BK.branch(parent, Vector3.new(x, 5 * s, z), top + Vector3.new(math.cos(a) * 3.4 * s, 0.4 * s, math.sin(a) * 3.4 * s), 0.35 * s, bark)
	end
	BK.blob(parent, top + Vector3.new(0, 2.2 * s, 0), 8.6 * s, jitter(base, 0.04))
	local n = 6
	local phase = BK.rng:NextNumber(0, 6.28)
	for i = 1, n do
		local a = phase + i / n * 6.28
		local r = 3.5 * s * BK.rng:NextNumber(0.75, 1.1)
		BK.blob(parent, top + Vector3.new(math.cos(a) * r, BK.rng:NextNumber(-0.6, 2.4) * s, math.sin(a) * r), BK.rng:NextNumber(5, 6.8) * s, jitter(base, 0.07))
	end
	BK.blob(parent, top + Vector3.new(0, 4.6 * s, 0), 5.2 * s, jitter(base, 0.05))
end

function BK.sakura(parent: Instance, x: number, z: number, scale: number)
	local s = scale
	local bark = jitter(hex("6E5448"), 0.03)
	BK.cylinder("TrunkBase", 1.5 * s, 1.4 * s, Vector3.new(x, 0.7 * s, z), bark, parent, Enum.Material.Wood)
	local lean = Vector3.new(BK.rng:NextNumber(-1.2, 1.2) * s, 0, BK.rng:NextNumber(-1.2, 1.2) * s)
	local fork = Vector3.new(x, 6.5 * s, z) + lean
	BK.branch(parent, Vector3.new(x, 1 * s, z), fork, 1.05 * s, bark)
	local crownC = fork + Vector3.new(0, 3.5 * s, 0)
	for i = 1, 3 do
		local a = i / 3 * 6.28 + BK.rng:NextNumber(-0.4, 0.4)
		BK.branch(parent, fork, crownC + Vector3.new(math.cos(a) * 4.6 * s, 0.6 * s, math.sin(a) * 4.6 * s), 0.45 * s, bark)
	end
	local pinks = { hex("FFB7C5"), hex("FFC6D3"), hex("FFA9BC"), hex("FFD6E0") }
	local center = BK.blob(parent, crownC + Vector3.new(0, 1.2 * s, 0), 11 * s, jitter(pinks[1], 0.03))
	for i = 1, 7 do
		local a = i / 7 * 6.28 + BK.rng:NextNumber(-0.3, 0.3)
		local r = 4.8 * s * BK.rng:NextNumber(0.8, 1.1)
		BK.blob(parent, crownC + Vector3.new(math.cos(a) * r, BK.rng:NextNumber(-1.5, 1.8) * s, math.sin(a) * r), BK.rng:NextNumber(6, 8) * s, jitter(pinks[BK.rng:NextInteger(1, 4)], 0.03))
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(hex("FFB7C5"), hex("FFD6E0"))
	e.Size = NumberSequence.new(0.5)
	e.Lifetime = NumberRange.new(6, 9)
	e.Speed = NumberRange.new(0, 1)
	e.Acceleration = Vector3.new(1.5, -2.2, 0.6)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 2
	e.LightEmission = 0.3
	e.Parent = center
end

function BK.bush(parent: Instance, x: number, z: number, s: number, color: Color3?)
	local base = color or hex("4E9A58")
	BK.blob(parent, Vector3.new(x, 1.1 * s, z), 3.6 * s, jitter(base, 0.05))
	for _ = 1, 2 do
		BK.blob(parent, Vector3.new(x + BK.rng:NextNumber(-1.4, 1.4) * s, 0.9 * s, z + BK.rng:NextNumber(-1.4, 1.4) * s), BK.rng:NextNumber(2.2, 3) * s, jitter(base, 0.06))
	end
end

function BK.rock(parent: Instance, x: number, z: number, s: number)
	local mats = { Enum.Material.Slate, Enum.Material.Basalt, Enum.Material.Granite }
	local gray = BK.rng:NextNumber(0.42, 0.66)
	local mat = mats[BK.rng:NextInteger(1, 3)]
	for i = 1, BK.rng:NextInteger(1, 3) do
		local d = s * (if i == 1 then 1 else BK.rng:NextNumber(0.4, 0.65))
		local ox = if i == 1 then 0 else BK.rng:NextNumber(-0.8, 0.8) * s
		local oz = if i == 1 then 0 else BK.rng:NextNumber(-0.8, 0.8) * s
		local pos = Vector3.new(x + ox, d * 0.22, z + oz)
		local p = BK.ball("Rock", d, pos, Color3.new(gray, gray * 0.98, gray * 0.95), parent, mat)
		p.Size = Vector3.new(d * 1.25, d * 0.7, d)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(BK.rng:NextNumber(-0.15, 0.15), BK.rng:NextNumber(0, 6.28), BK.rng:NextNumber(-0.15, 0.15))
	end
end

function BK.flowers(parent: Instance, x: number, z: number, color: Color3, radius: number)
	local base = BK.blob(parent, Vector3.new(x, 0.4, z), radius * 1.8, hex("5FAE5C"))
	base.Size = Vector3.new(radius * 1.8, 0.8, radius * 1.8)
	for _ = 1, 7 do
		local a, r = BK.rng:NextNumber(0, 6.28), BK.rng:NextNumber(0, radius)
		local fx, fz = x + math.cos(a) * r, z + math.sin(a) * r
		BK.cylinder("Stem", 0.06, 1, Vector3.new(fx, 0.9, fz), hex("3E7D3E"), parent)
		BK.ball("Flower", 0.7, Vector3.new(fx, 1.5, fz), jitter(color, 0.04), parent)
	end
end

-- รถยนต์เล็ก (หันหน้าไปทาง -Z ที่ yaw=0) ตัวถังโลหะ + กระจก + ล้อ + ไฟหน้า/ท้าย
function BK.car(parent: Instance, x: number, z: number, yaw: number, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "Car"
	m.Parent = parent
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
	local function piece(name: string, size: Vector3, offset: Vector3, col: Color3, mat: Enum.Material?): Part
		local p = BK.part(name, size, Vector3.zero, col, m, mat)
		p.CFrame = cf * CFrame.new(offset)
		return p
	end
	piece("Chassis", Vector3.new(4.2, 0.8, 9.2), Vector3.new(0, 0.9, 0), hex("23252E"), Enum.Material.Metal)
	piece("Body", Vector3.new(4.2, 1.3, 9), Vector3.new(0, 1.85, 0), color, Enum.Material.Metal)
	local glass = piece("Glass", Vector3.new(3.7, 1.3, 4.6), Vector3.new(0, 3.15, 0.5), hex("2E3B4A"), Enum.Material.Glass)
	glass.Transparency = 0.25
	piece("Roof", Vector3.new(3.8, 0.25, 4.3), Vector3.new(0, 3.9, 0.5), color, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		for _, sz in { -2.9, 2.9 } do
			local w = BK.part("Wheel", Vector3.new(0.8, 1.9, 1.9), Vector3.zero, hex("1A1B20"), m, Enum.Material.SmoothPlastic)
			w.Shape = Enum.PartType.Cylinder
			w.CFrame = cf * CFrame.new(sx * 2.05, 0.95, sz)
		end
		BK.noCollide(piece("Headlight", Vector3.new(0.9, 0.45, 0.2), Vector3.new(sx * 1.4, 1.9, -4.55), hex("FFF3C9"), Enum.Material.Neon))
		BK.noCollide(piece("Taillight", Vector3.new(0.9, 0.4, 0.2), Vector3.new(sx * 1.4, 1.9, 4.55), hex("E8352E"), Enum.Material.Neon))
	end
	return m
end

function BK.bench(parent: Instance, x: number, z: number, yaw: number)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
	local function piece(size: Vector3, offset: Vector3, col: Color3, mat: Enum.Material)
		local p = BK.part("Bench", size, Vector3.zero, col, parent, mat)
		p.CFrame = cf * CFrame.new(offset)
	end
	piece(Vector3.new(5, 0.3, 1.6), Vector3.new(0, 1.6, 0), hex("8D6E4B"), Enum.Material.WoodPlanks)
	piece(Vector3.new(5, 1.2, 0.25), Vector3.new(0, 2.5, 0.7), hex("8D6E4B"), Enum.Material.WoodPlanks)
	for _, sx in { -2.1, 2.1 } do
		piece(Vector3.new(0.3, 1.6, 1.5), Vector3.new(sx, 0.8, 0), hex("2B2D42"), Enum.Material.Metal)
	end
end

-- รั้วตาข่าย/รั้วเหล็กแนวตรง: เสาทุก ~8 stud + แผ่นรั้วกึ่งโปร่ง + ราวบน
function BK.fence(parent: Instance, x1: number, z1: number, x2: number, z2: number, height: number, color: Color3?)
	local col = color or hex("6B7280")
	local len = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	local steps = math.max(1, math.floor(len / 8))
	local mid = Vector3.new((x1 + x2) / 2, height / 2, (z1 + z2) / 2)
	local look = CFrame.lookAt(mid, Vector3.new(x2, height / 2, z2)) * CFrame.Angles(0, math.rad(90), 0)
	local panel = BK.part("FencePanel", Vector3.new(len, height - 0.6, 0.12), mid, col, parent, Enum.Material.DiamondPlate)
	panel.Transparency = 0.45
	panel.CFrame = look
	local rail = BK.part("FenceRail", Vector3.new(len, 0.25, 0.25), mid, col, parent, Enum.Material.Metal)
	rail.CFrame = look * CFrame.new(0, height / 2 - 0.2, 0)
	for i = 0, steps do
		local t = i / steps
		BK.cylinder("FencePost", 0.22, height, Vector3.new(x1 + (x2 - x1) * t, height / 2, z1 + (z2 - z1) * t), col, parent, Enum.Material.Metal)
	end
end

function BK.lamp(parent: Instance, x: number, z: number, color: Color3?)
	local glow = color or hex("FFE066")
	BK.cylinder("PoleBase", 0.7, 0.8, Vector3.new(x, 0.4, z), hex("3A3D4A"), parent, Enum.Material.Metal)
	BK.cylinder("Pole", 0.25, 11.6, Vector3.new(x, 6.2, z), hex("2B2D42"), parent, Enum.Material.Metal)
	BK.box("LampArm", x - 0.15, x + 0.15, 11.8, 12, z - 1.4, z + 0.2, hex("2B2D42"), parent, Enum.Material.Metal)
	BK.box("LampHousing", x - 0.7, x + 0.7, 11.5, 11.9, z - 2.1, z - 0.7, hex("3A3D4A"), parent, Enum.Material.Metal)
	local bulb = BK.box("Bulb", x - 0.5, x + 0.5, 11.35, 11.5, z - 1.9, z - 0.9, glow, parent, Enum.Material.Neon)
	BK.light(bulb, glow, 30, 1.1)
end

-- อาคารทึบ (เข้าไปข้างในไม่ได้): ผนัง วัสดุจริง (Concrete/Brick/Plaster) เสามุม เส้นคาดชั้น หน้าต่างมีกรอบ บางบานเปิดไฟ
-- ชายคา ราวกันตก ของบนดาดฟ้า (ถังน้ำ เสาอากาศ) opts: Awning, SignText, Windows, Storefront, Facing, Material, GlassColor
function BK.building(parent: Instance, cx: number, cz: number, w: number, d: number, h: number, wall: Color3, roof: Color3, opts: { [string]: any }?)
	local o = opts or {}
	local model = Instance.new("Folder")
	model.Name = "Building"
	model.Parent = parent
	local y0 = o.BaseY or 0
	local facing: number = o.Facing or 1
	local trim = wall:Lerp(Color3.new(0.35, 0.36, 0.4), 0.35)
	local frameColor = wall:Lerp(Color3.new(1, 1, 1), 0.5)
	BK.box("Walls", cx - w / 2, cx + w / 2, y0, y0 + h, cz - d / 2, cz + d / 2, wall, model, o.Material or Enum.Material.Concrete)
	BK.box("BaseTrim", cx - w / 2 - 0.3, cx + w / 2 + 0.3, y0, y0 + 1.2, cz - d / 2 - 0.3, cz + d / 2 + 0.3, trim:Lerp(Color3.new(0, 0, 0), 0.2), model, Enum.Material.Concrete)
	-- ชายคา + แผ่นหลังคา (Concrete เทาเข้ม ไม่ใช้ Slate ที่ลายใหญ่เกินไป)
	BK.box("Cornice", cx - w / 2 - 0.9, cx + w / 2 + 0.9, y0 + h - 0.9, y0 + h, cz - d / 2 - 0.9, cz + d / 2 + 0.9, trim, model, Enum.Material.Concrete)
	BK.box("RoofSlab", cx - w / 2 - 0.9, cx + w / 2 + 0.9, y0 + h, y0 + h + 0.6, cz - d / 2 - 0.9, cz + d / 2 + 0.9, roof, model, Enum.Material.Concrete)
	if o.Detail ~= false and h > 8 then
		-- เสามุมตึก
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				BK.box("Pilaster", cx + sx * (w / 2) - 0.6 + sx * 0.2, cx + sx * (w / 2) + 0.6 + sx * 0.2, y0 + 1.2, y0 + h - 0.9, cz + sz * (d / 2) - 0.6 + sz * 0.2, cz + sz * (d / 2) + 0.6 + sz * 0.2, trim, model, Enum.Material.Concrete)
			end
		end
		-- เส้นคาดระหว่างชั้น
		local floors = math.max(1, math.floor((h - 3) / 6.5))
		for r = 1, floors - 1 do
			local by = y0 + (if o.Storefront then 5.3 else 3) + r * 6.5 + 0.5
			if by + 0.4 < y0 + h - 1 then
				BK.box("FloorBand", cx - w / 2 - 0.25, cx + w / 2 + 0.25, by, by + 0.5, cz - d / 2 - 0.25, cz + d / 2 + 0.25, trim, model, Enum.Material.Concrete)
			end
		end
		-- ราวกันตก 4 ด้าน + ของบนดาดฟ้า
		local py = y0 + h + 0.6
		BK.box("ParapetN", cx - w / 2 - 0.9, cx + w / 2 + 0.9, py, py + 1, cz - d / 2 - 0.9, cz - d / 2 - 0.5, trim, model, Enum.Material.Concrete)
		BK.box("ParapetS", cx - w / 2 - 0.9, cx + w / 2 + 0.9, py, py + 1, cz + d / 2 + 0.5, cz + d / 2 + 0.9, trim, model, Enum.Material.Concrete)
		BK.box("ParapetW", cx - w / 2 - 0.9, cx - w / 2 - 0.5, py, py + 1, cz - d / 2 - 0.5, cz + d / 2 + 0.5, trim, model, Enum.Material.Concrete)
		BK.box("ParapetE", cx + w / 2 + 0.5, cx + w / 2 + 0.9, py, py + 1, cz - d / 2 - 0.5, cz + d / 2 + 0.5, trim, model, Enum.Material.Concrete)
		for _ = 1, 2 do
			local vx = cx + BK.rng:NextNumber(-w / 2 + 3, w / 2 - 3)
			local vz = cz + BK.rng:NextNumber(-d / 2 + 3, d / 2 - 3)
			BK.box("RoofVent", vx - 1.2, vx + 1.2, py, py + 1.8, vz - 1.2, vz + 1.2, hex("8E94A3"), model, Enum.Material.Metal)
		end
		if h > 14 and BK.rng:NextNumber() > 0.45 then
			local tx = cx + BK.rng:NextNumber(-w / 4, w / 4)
			local tz = cz + BK.rng:NextNumber(-d / 4, d / 4)
			for _, lx in { -1.4, 1.4 } do
				for _, lz in { -1.4, 1.4 } do
					BK.cylinder("TankLeg", 0.18, 2, Vector3.new(tx + lx, py + 1, tz + lz), hex("4A4D5C"), model, Enum.Material.Metal)
				end
			end
			BK.cylinder("WaterTank", 2.2, 3.6, Vector3.new(tx, py + 3.8, tz), hex("8E6F55"), model, Enum.Material.Wood)
			BK.cylinder("TankCap", 2.3, 0.4, Vector3.new(tx, py + 5.8, tz), hex("4A4D5C"), model, Enum.Material.Metal)
		end
		if h > 20 then
			BK.cylinder("Antenna", 0.12, 7, Vector3.new(cx + BK.rng:NextNumber(-w / 3, w / 3), py + 3.5, cz + BK.rng:NextNumber(-d / 3, d / 3)), hex("2B2D42"), model, Enum.Material.Metal)
		end
		-- เครื่องปรับอากาศใต้หน้าต่างบางบาน
		local acRows = math.max(1, math.floor((h - 3) / 6.5))
		for r = 0, acRows - 1 do
			if BK.rng:NextNumber() > 0.55 then
				local ax = cx + BK.rng:NextNumber(-w / 2 + 4, w / 2 - 4)
				local side = if BK.rng:NextNumber() > 0.5 then 1 else -1
				local ay = y0 + 3 + r * 6.5
				BK.box("AirCon", ax - 1.4, ax + 1.4, ay, ay + 1.6, math.min(cz + side * (d / 2), cz + side * (d / 2 + 1.1)), math.max(cz + side * (d / 2), cz + side * (d / 2 + 1.1)), hex("D8D8E0"), model, Enum.Material.Metal)
			end
		end
		for _, sx in { -1, 1 } do
			BK.cylinder("Drainpipe", 0.25, h - 1, Vector3.new(cx + sx * (w / 2 - 1.2), y0 + h / 2, cz - facing * (d / 2 + 0.35)), hex("6B7280"), model, Enum.Material.Metal)
		end
		if h > 16 and BK.rng:NextNumber() > 0.4 then
			local by = y0 + 3 + 6.5
			local fz = cz + facing * (d / 2)
			BK.box("Balcony", cx - 5, cx + 5, by, by + 0.4, math.min(fz, fz + facing * 2.2), math.max(fz, fz + facing * 2.2), hex("C9CED6"), model, Enum.Material.Concrete)
			BK.box("BalconyRail", cx - 5, cx + 5, by + 0.4, by + 1.6, math.min(fz + facing * 2, fz + facing * 2.2), math.max(fz + facing * 2, fz + facing * 2.2), hex("2B2D42"), model, Enum.Material.Metal)
		end
	end
	if o.Windows ~= false then
		local cols = math.max(1, math.floor((w - 3) / 7))
		local rows = math.max(1, math.floor((h - 3) / 6.5))
		local glass = o.GlassColor or hex("7FB2D6")
		local function pane(size: Vector3, pos: Vector3, lit: boolean)
			local frame = BK.part("WindowFrame", size + Vector3.new(0.45, 0.45, 0.45), pos, frameColor, model, Enum.Material.Concrete)
			frame.CanCollide = false
			local gw = BK.part("Window", size, pos, if lit then hex("FFE6A8") else glass, model, if lit then Enum.Material.Neon else Enum.Material.Glass)
			if not lit then
				gw.Transparency = 0.3
			end
			gw.CanCollide = false
			return gw
		end
		for r = 0, rows - 1 do
			local wy = y0 + 4.5 + r * 6.5
			if wy + 2 < y0 + h - 0.9 then
				for c = 0, cols - 1 do
					local wx = cx - w / 2 + (c + 0.5) * (w / cols)
					for _, side in { -1, 1 } do
						if o.Storefront and side == facing then
							continue
						end
						pane(Vector3.new(4, 3.4, 0.2), Vector3.new(wx, wy, cz + side * (d / 2 + 0.05)), BK.rng:NextNumber() < 0.16)
					end
				end
				local sideCols = math.max(1, math.floor((d - 3) / 7))
				for c = 0, sideCols - 1 do
					local wz = cz - d / 2 + (c + 0.5) * (d / sideCols)
					for _, side in { -1, 1 } do
						pane(Vector3.new(0.2, 3.4, 4), Vector3.new(cx + side * (w / 2 + 0.05), wy, wz), BK.rng:NextNumber() < 0.16)
					end
				end
			end
		end
		if o.Storefront then
			-- หน้าร้านชั้นล่าง: กระจกบานใหญ่ + ประตู + เสาคั่น
			local fz = cz + facing * (d / 2 + 0.06)
			local g = BK.part("ShopGlass", Vector3.new(w - 5, 3.8, 0.2), Vector3.new(cx - 1.5, y0 + 3.1, fz), hex("5F7F96"), model, Enum.Material.Glass)
			g.Transparency = 0.35
			g.CanCollide = false
			BK.box("ShopDoor", cx + w / 2 - 4.2, cx + w / 2 - 1.2, y0 + 1.2, y0 + 5.4, fz - 0.15 * facing - 0.15, fz + 0.15, hex("5A4636"), model, Enum.Material.Wood)
			for i = 0, 2 do
				BK.box("ShopMullion", cx - w / 2 + 2.5 + i * ((w - 5) / 2) - 0.2, cx - w / 2 + 2.5 + i * ((w - 5) / 2) + 0.2, y0 + 1.2, y0 + 5, fz - 0.2, fz + 0.2, trim, model, Enum.Material.Concrete)
			end
		end
	end
	if o.SignText then
		-- ป้ายหันไปทางถนน (o.Facing = +1 หัน +Z, -1 หัน -Z)
		BK.sign(model, o.SignText, Vector3.new(math.min(w - 2, 12), 2.6, 0.4), Vector3.new(cx, y0 + 8.8, cz + facing * (d / 2 + 0.3)), if facing == 1 then 180 else 0, o.SignBg or hex("2B2D42"), o.SignFg or hex("FFE066"))
	end
	if o.Awning then
		local aw = BK.box("Awning", cx - w / 2 + 0.5, cx + w / 2 - 0.5, y0 + 6.6, y0 + 7.1, cz + facing * (d / 2), cz + facing * (d / 2 + 4.5), o.Awning :: Color3, model, Enum.Material.Fabric)
		aw.Name = "Awning"
	end
	return model
end

-- ถนนแนวแกน: ลาดยางแอสฟัลต์ + เส้นกลางประ + ขอบทาง (เส้นขอบเลนอยู่ใน StreetScape)
function BK.road(parent: Instance, x1: number, z1: number, x2: number, z2: number, width: number)
	local ax1, ax2 = math.min(x1, x2), math.max(x1, x2)
	local az1, az2 = math.min(z1, z2), math.max(z1, z2)
	local horizontal = (ax2 - ax1) >= (az2 - az1)
	local asphalt = hex("3F424E")
	local curbColor = hex("B9BCC4")
	if horizontal then
		BK.box("Road", ax1, ax2, 0, 0.3, az1 - width / 2, az1 + width / 2, asphalt, parent, Enum.Material.Asphalt)
		for _, side in { -1, 1 } do
			BK.box("Curb", ax1, ax2, 0, 0.55, az1 + side * (width / 2) - (if side == 1 then 0 else -0.4), az1 + side * (width / 2) + (if side == 1 then 0.4 else 0), curbColor, parent, Enum.Material.Concrete)
		end
		for x = ax1 + 6, ax2 - 6, 12 do
			BK.box("Dash", x, x + 5, 0.3, 0.34, az1 - 0.2, az1 + 0.2, hex("F2D95C"), parent)
		end
	else
		BK.box("Road", ax1 - width / 2, ax1 + width / 2, 0, 0.3, az1, az2, asphalt, parent, Enum.Material.Asphalt)
		for _, side in { -1, 1 } do
			BK.box("Curb", ax1 + side * (width / 2) - (if side == 1 then 0 else -0.4), ax1 + side * (width / 2) + (if side == 1 then 0.4 else 0), 0, 0.55, az1, az2, curbColor, parent, Enum.Material.Concrete)
		end
		for z = az1 + 6, az2 - 6, 12 do
			BK.box("Dash", ax1 - 0.2, ax1 + 0.2, 0.3, 0.34, z, z + 5, hex("F2D95C"), parent)
		end
	end
end

-- ทางเท้า (ปูแผ่นคอนกรีต) แนวแกน
function BK.sidewalk(parent: Instance, x1: number, x2: number, z1: number, z2: number)
	BK.box("Sidewalk", math.min(x1, x2), math.max(x1, x2), 0, 0.45, math.min(z1, z2), math.max(z1, z2), hex("CFCBC2"), parent, Enum.Material.Concrete)
end

-- ประตูโทริอิ (ไม้ทาแดง + ฐานหิน)
function BK.torii(parent: Instance, x: number, y: number, z: number, yaw: number, scale: number)
	local red = hex("D93A2F")
	local model = Instance.new("Model")
	model.Name = "Torii"
	model.Parent = parent
	local function piece(size: Vector3, offset: Vector3, color: Color3, mat: Enum.Material?)
		local p = BK.part("ToriiPart", size * scale, Vector3.zero, color, model, mat or Enum.Material.Wood)
		p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(offset * scale)
	end
	for _, sx in { -5, 5 } do
		piece(Vector3.new(1.8, 1.2, 1.8), Vector3.new(sx, 0.6, 0), hex("5A5F6E"), Enum.Material.Slate)
		piece(Vector3.new(1.4, 11.4, 1.4), Vector3.new(sx, 6.9, 0), red)
	end
	piece(Vector3.new(14.5, 1.1, 1.5), Vector3.new(0, 10.6, 0), red)
	piece(Vector3.new(17, 0.9, 2), Vector3.new(0, 12.3, 0), hex("22242E"))
	piece(Vector3.new(18, 0.4, 2.4), Vector3.new(0, 12.95, 0), hex("22242E"))
	piece(Vector3.new(11.5, 0.9, 1), Vector3.new(0, 8.4, 0), red)
	piece(Vector3.new(1.2, 2.2, 0.9), Vector3.new(0, 9.4, 0), red)
end

-- เกลาตำแหน่งบนพื้น: คืนค่าตำแหน่งบนพื้นที่เสมอ y=0
function BK.groundPos(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

return BK
