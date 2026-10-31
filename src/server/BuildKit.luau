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

function BK.pine(parent: Instance, x: number, z: number, h: number)
	BK.cylinder("PineTrunk", 0.8, h * 0.3, Vector3.new(x, h * 0.15, z), hex("8D6E63"), parent, Enum.Material.Wood)
	for layer = 0, 2 do
		local s = (3 - layer) * 3.4
		local cone = BK.ball("PineLeaves", s, Vector3.new(x, h * 0.3 + layer * h * 0.22 + s * 0.35, z), hex("4FA06A"), parent, Enum.Material.Grass)
		cone.Size = Vector3.new(s, s * 1.35, s)
	end
end

function BK.roundTree(parent: Instance, x: number, z: number, scale: number, leaf: Color3?)
	BK.cylinder("Trunk", 1 * scale, 7 * scale, Vector3.new(x, 3.5 * scale, z), hex("8D6E63"), parent, Enum.Material.Wood)
	BK.ball("Crown", 11 * scale, Vector3.new(x, 10 * scale, z), leaf or hex("6FC27A"), parent, Enum.Material.Grass)
	BK.ball("Crown", 7 * scale, Vector3.new(x + 3 * scale, 9 * scale, z + 2 * scale), leaf or hex("7DD18A"), parent, Enum.Material.Grass)
end

function BK.sakura(parent: Instance, x: number, z: number, scale: number)
	BK.cylinder("Trunk", 1.2 * scale, 9 * scale, Vector3.new(x, 4.5 * scale, z), hex("8D6E63"), parent, Enum.Material.Wood)
	local crown = BK.ball("Crown", 15 * scale, Vector3.new(x, 13 * scale, z), hex("FFB7C5"), parent, Enum.Material.Grass)
	BK.ball("Crown", 10 * scale, Vector3.new(x + 4 * scale, 11 * scale, z + 3 * scale), hex("FFD6E0"), parent, Enum.Material.Grass)
	BK.ball("Crown", 9 * scale, Vector3.new(x - 4 * scale, 12 * scale, z - 3 * scale), hex("FFB7C5"), parent, Enum.Material.Grass)
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
	e.Parent = crown
end

function BK.lamp(parent: Instance, x: number, z: number, color: Color3?)
	BK.cylinder("Pole", 0.4, 12, Vector3.new(x, 6, z), hex("2B2D42"), parent)
	local bulb = BK.ball("Bulb", 2, Vector3.new(x, 12.6, z), color or hex("FFE066"), parent, Enum.Material.Neon)
	BK.light(bulb, color or hex("FFE066"), 30, 1.1)
end

-- อาคารทึบ: ผนัง 4 ด้าน หน้าต่างเป็นแถว หลังคาและขอบ (ไม่เข้าไปข้างในได้) opts: Awning, SignText, Windows
function BK.building(parent: Instance, cx: number, cz: number, w: number, d: number, h: number, wall: Color3, roof: Color3, opts: { [string]: any }?)
	local o = opts or {}
	local model = Instance.new("Folder")
	model.Name = "Building"
	model.Parent = parent
	local y0 = o.BaseY or 0
	BK.box("Walls", cx - w / 2, cx + w / 2, y0, y0 + h, cz - d / 2, cz + d / 2, wall, model, o.Material or Enum.Material.Concrete)
	BK.box("RoofSlab", cx - w / 2 - 0.6, cx + w / 2 + 0.6, y0 + h, y0 + h + 0.8, cz - d / 2 - 0.6, cz + d / 2 + 0.6, roof, model, Enum.Material.Slate)
	BK.box("BaseTrim", cx - w / 2 - 0.3, cx + w / 2 + 0.3, y0, y0 + 1, cz - d / 2 - 0.3, cz + d / 2 + 0.3, hex("8E94A3"), model, Enum.Material.Concrete)
	if o.Detail ~= false and h > 10 then
		-- ช่องระบายบนดาดฟ้า + ขอบกันตก
		for _ = 1, 2 do
			local vx = cx + BK.rng:NextNumber(-w / 2 + 3, w / 2 - 3)
			local vz = cz + BK.rng:NextNumber(-d / 2 + 3, d / 2 - 3)
			BK.box("RoofVent", vx - 1.2, vx + 1.2, y0 + h + 0.8, y0 + h + 2.6, vz - 1.2, vz + 1.2, hex("8E94A3"), model, Enum.Material.Metal)
		end
		BK.box("RoofParapetN", cx - w / 2 - 0.6, cx + w / 2 + 0.6, y0 + h + 0.8, y0 + h + 1.7, cz - d / 2 - 0.6, cz - d / 2 - 0.3, hex("8E94A3"), model, Enum.Material.Concrete)
		BK.box("RoofParapetS", cx - w / 2 - 0.6, cx + w / 2 + 0.6, y0 + h + 0.8, y0 + h + 1.7, cz + d / 2 + 0.3, cz + d / 2 + 0.6, hex("8E94A3"), model, Enum.Material.Concrete)
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
		-- ท่อน้ำที่มุมด้านหน้า
		for _, sx in { -1, 1 } do
			BK.cylinder("Drainpipe", 0.25, h, Vector3.new(cx + sx * (w / 2 - 0.4), y0 + h / 2, cz + d / 2 + 0.3), hex("6B7280"), model, Enum.Material.Metal)
		end
		-- ระเบียงบางชั้น
		if h > 16 and BK.rng:NextNumber() > 0.4 then
			local by = y0 + 3 + 6.5
			BK.box("Balcony", cx - 5, cx + 5, by, by + 0.4, cz + d / 2, cz + d / 2 + 2.2, hex("C9CED6"), model, Enum.Material.Concrete)
			BK.box("BalconyRail", cx - 5, cx + 5, by + 0.4, by + 1.6, cz + d / 2 + 2, cz + d / 2 + 2.2, hex("2B2D42"), model, Enum.Material.Metal)
		end
	end
	if o.Windows ~= false then
		local cols = math.max(1, math.floor((w - 3) / 7))
		local rows = math.max(1, math.floor((h - 3) / 6.5))
		local glass = o.GlassColor or hex("BFE9FF")
		for r = 0, rows - 1 do
			local wy = y0 + 4.5 + r * 6.5
			if wy + 2 < y0 + h then
				for c = 0, cols - 1 do
					local wx = cx - w / 2 + (c + 0.5) * (w / cols)
					for _, side in { -1, 1 } do
						local gw = BK.part("Window", Vector3.new(4, 3.4, 0.2), Vector3.new(wx, wy, cz + side * (d / 2 + 0.05)), glass, model, Enum.Material.Glass)
						gw.Transparency = 0.3
						gw.CanCollide = false
					end
				end
				local sideCols = math.max(1, math.floor((d - 3) / 7))
				for c = 0, sideCols - 1 do
					local wz = cz - d / 2 + (c + 0.5) * (d / sideCols)
					for _, side in { -1, 1 } do
						local gw = BK.part("Window", Vector3.new(0.2, 3.4, 4), Vector3.new(cx + side * (w / 2 + 0.05), wy, wz), glass, model, Enum.Material.Glass)
						gw.Transparency = 0.3
						gw.CanCollide = false
					end
				end
			end
		end
	end
	if o.SignText then
		-- ป้ายหันไปทางถนน (o.Facing = +1 หัน +Z, -1 หัน -Z)
		local facing: number = o.Facing or 1
		BK.sign(model, o.SignText, Vector3.new(math.min(w - 2, 12), 2.6, 0.4), Vector3.new(cx, y0 + 8.8, cz + facing * (d / 2 + 0.3)), if facing == 1 then 180 else 0, o.SignBg or hex("2B2D42"), o.SignFg or hex("FFE066"))
	end
	if o.Awning then
		local facing: number = o.Facing or 1
		local aw = BK.box("Awning", cx - w / 2 + 0.5, cx + w / 2 - 0.5, y0 + 6.6, y0 + 7.1, cz + facing * (d / 2), cz + facing * (d / 2 + 4.5), o.Awning :: Color3, model)
		aw.Name = "Awning"
	end
	return model
end

-- ถนนแนวแกน: ลาดยาง + เส้นกลางประ + ขอบทาง
function BK.road(parent: Instance, x1: number, z1: number, x2: number, z2: number, width: number)
	local ax1, ax2 = math.min(x1, x2), math.max(x1, x2)
	local az1, az2 = math.min(z1, z2), math.max(z1, z2)
	local horizontal = (ax2 - ax1) >= (az2 - az1)
	local asphalt = hex("4A4D5C")
	if horizontal then
		BK.box("Road", ax1, ax2, 0, 0.3, az1 - width / 2, az1 + width / 2, asphalt, parent, Enum.Material.Asphalt)
		for _, side in { -1, 1 } do
			BK.box("Curb", ax1, ax2, 0, 0.55, az1 + side * (width / 2) - (if side == 1 then 0 else -0.4), az1 + side * (width / 2) + (if side == 1 then 0.4 else 0), hex("D8D8E0"), parent)
		end
		for x = ax1 + 6, ax2 - 6, 12 do
			BK.box("Dash", x, x + 5, 0.3, 0.34, az1 - 0.2, az1 + 0.2, hex("FFE066"), parent)
		end
	else
		BK.box("Road", ax1 - width / 2, ax1 + width / 2, 0, 0.3, az1, az2, asphalt, parent, Enum.Material.Asphalt)
		for _, side in { -1, 1 } do
			BK.box("Curb", ax1 + side * (width / 2) - (if side == 1 then 0 else -0.4), ax1 + side * (width / 2) + (if side == 1 then 0.4 else 0), 0, 0.55, az1, az2, hex("D8D8E0"), parent)
		end
		for z = az1 + 6, az2 - 6, 12 do
			BK.box("Dash", ax1 - 0.2, ax1 + 0.2, 0.3, 0.34, z, z + 5, hex("FFE066"), parent)
		end
	end
end

-- ประตูโทริอิ
function BK.torii(parent: Instance, x: number, y: number, z: number, yaw: number, scale: number)
	local red = hex("E8352E")
	local model = Instance.new("Model")
	model.Name = "Torii"
	model.Parent = parent
	local function piece(size: Vector3, offset: Vector3, color: Color3)
		local p = BK.part("ToriiPart", size * scale, Vector3.zero, color, model)
		p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(offset * scale)
	end
	piece(Vector3.new(1.4, 12, 1.4), Vector3.new(-5, 6, 0), red)
	piece(Vector3.new(1.4, 12, 1.4), Vector3.new(5, 6, 0), red)
	piece(Vector3.new(14, 1.2, 1.6), Vector3.new(0, 11, 0), red)
	piece(Vector3.new(16, 0.8, 2), Vector3.new(0, 12.6, 0), hex("2B2D42"))
	piece(Vector3.new(10, 0.9, 1), Vector3.new(0, 8.2, 0), red)
end

-- เกลาตำแหน่งบนพื้น: คืนค่าตำแหน่งบนพื้นที่เสมอ y=0
function BK.groundPos(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

return BK
