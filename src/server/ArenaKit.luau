--!strict
-- ชุดสร้างสนามประลอง: (1) ภายนอกโคลอสเซียมกรีกที่ไซต์ WarArena (ลานหน้าสนาม + ตัวอาคารปิดทึบ)
-- (2) แม่แบบภายใน 3 ธีม (Neon Ring / Greek Sand / Rooftop) สร้างเก็บใน ServerStorage แล้ว clone ต่อแมตช์
-- ทุกแม่แบบใช้พิกัดท้องถิ่น: พื้นสนามผิวบน y=0 ศูนย์กลาง (0,0,0) ทีม A อยู่ฝั่ง -Z ทีม B ฝั่ง +Z
local BK = require(script.Parent.BuildKit)

local Kit = {}

Kit.SITE = Vector3.new(0, 0.3, 276) -- ศูนย์กลางวงรีของตัวอาคาร (ผิวพื้นโลก y≈0.3)
Kit.FORECOURT_Z = 276 - 52 -- แนว z ของลานหน้าสนาม (ที่ตั้งคีออสก์)
Kit.THEMES = { "NeonRing", "GreekSand", "Rooftop" }
Kit.THEME_NAMES = { NeonRing = "นีออนริง โตเกียว", GreekSand = "โคลอสเซียมทรายกรีก", Rooftop = "ดาดฟ้ายามราตรี" }

local hex = Color3.fromHex
local M = Enum.Material
local TAU = math.pi * 2
local rng = Random.new(77)

local MARBLE, LIME, SAND_STONE = hex("E4DFD2"), hex("C8BEA4"), hex("B79B70")
local SLATE, DARK, BRONZE = hex("3A3E46"), hex("202228"), hex("8A6A3A")
local RED, BLUE = hex("A8423A"), hex("38567A")

---------------------------------------------------------------- ตัวช่วย
local function mk(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if collide == false then
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	end
	if math.max(size.X, size.Y, size.Z) < 1.3 then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

local function cyl(parent: Instance, name: string, r: number, h: number, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
	local p = mk(parent, name, Vector3.new(h, r * 2, r * 2), cf * CFrame.Angles(0, 0, math.rad(90)), color, mat, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ecyl(parent: Instance, name: string, rx: number, rz: number, h: number, pos: Vector3, color: Color3, mat: Enum.Material?, collide: boolean?): Part
	local p = mk(parent, name, Vector3.new(h, rx * 2, rz * 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, mat, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
	local p = mk(parent, name, size, cf, color, mat, collide)
	p.Shape = Enum.PartType.Ball
	return p
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if collide == false then
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	end
	p.Parent = parent
	return p
end

local function light(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness
	l.Shadows = false
	l.Parent = p
end

-- วางรอบวงกลมรัศมี R หน้าหันเข้าหาศูนย์กลาง (-Z ชี้เข้า, X ไปตามแนวสัมผัส)
local function ring(n: number, R: number, fn: (i: number, cf: CFrame, a: number) -> ())
	for i = 0, n - 1 do
		local a = i / n * TAU
		local pos = Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
		fn(i, CFrame.lookAt(pos, Vector3.zero), a)
	end
end

local function chord(n: number, R: number): number
	return 2 * R * math.tan(math.pi / n) * 1.04
end

-- ป้ายบนผิวหน้า (Front) ของ part
local function face(p: Part, text: string, color: Color3, font: Enum.Font?, rich: boolean?, ppsd: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppsd or 40
	gui.LightInfluence = 0
	gui.Parent = p
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.Font = font or Enum.Font.SourceSansBold
	l.RichText = rich == true
	l.TextScaled = true
	l.Parent = gui
	return l
end

local function lantern(parent: Instance, pos: Vector3, withLight: boolean)
	local p = cyl(parent, "Lantern", 0.55, 1.5, CFrame.new(pos), hex("C0452E"), M.Neon, false)
	p.Transparency = 0.12
	cyl(parent, "LanternCap", 0.45, 0.16, CFrame.new(pos + Vector3.new(0, 0.82, 0)), DARK, M.Metal, false)
	cyl(parent, "LanternCap", 0.45, 0.16, CFrame.new(pos - Vector3.new(0, 0.82, 0)), DARK, M.Metal, false)
	if withLight then
		light(p, hex("FF9A55"), 16, 0.8)
	end
end

local function column(parent: Instance, cf: CFrame, h: number, r: number, color: Color3?)
	local c = color or MARBLE
	-- cf = จุดกลางฐาน (ผิวพื้น) หันหน้า -Z
	mk(parent, "ColBase", Vector3.new(r * 2.7, 0.7, r * 2.7), cf * CFrame.new(0, 0.35, 0), c, M.Marble)
	cyl(parent, "ColShaft", r, h - 1.9, cf * CFrame.new(0, 0.7 + (h - 1.9) / 2, 0), c, M.Marble)
	for i = 0, 3 do -- ร่องเสาแบบย่อ: แถบบางสีเข้ม 4 ด้าน
		local a = i * math.pi / 2 + math.pi / 4
		mk(parent, "ColFlute", Vector3.new(0.14, h - 2.6, 0.14), cf * CFrame.new(math.cos(a) * r * 0.97, 0.7 + (h - 1.9) / 2, math.sin(a) * r * 0.97), c:Lerp(DARK, 0.25), M.Marble, false)
	end
	cyl(parent, "ColEchinus", r * 1.25, 0.5, cf * CFrame.new(0, h - 1.0, 0), c, M.Marble)
	mk(parent, "ColAbacus", Vector3.new(r * 2.9, 0.6, r * 2.9), cf * CFrame.new(0, h - 0.45, 0), c, M.Marble)
end

local function brazier(parent: Instance, pos: Vector3, scale: number, withLight: boolean): BasePart
	cyl(parent, "BrazierFoot", 0.9 * scale, 0.5 * scale, CFrame.new(pos + Vector3.new(0, 0.25 * scale, 0)), BRONZE, M.Metal)
	cyl(parent, "BrazierStem", 0.35 * scale, 3 * scale, CFrame.new(pos + Vector3.new(0, 2 * scale, 0)), BRONZE, M.Metal)
	local bowl = cyl(parent, "BrazierBowl", 1.7 * scale, 0.9 * scale, CFrame.new(pos + Vector3.new(0, 3.7 * scale, 0)), BRONZE, M.Metal)
	cyl(parent, "BrazierRim", 1.85 * scale, 0.2 * scale, CFrame.new(pos + Vector3.new(0, 4.2 * scale, 0)), hex("B08A4A"), M.Metal)
	local flame = ball(parent, "BrazierFlame", Vector3.new(2 * scale, 2.6 * scale, 2 * scale), CFrame.new(pos + Vector3.new(0, 5.2 * scale, 0)), hex("FF8A2A"), M.Neon, false)
	flame.Transparency = 0.35
	if withLight then
		local f = Instance.new("Fire")
		f.Size, f.Heat = 7 * scale, 8
		f.Color, f.SecondaryColor = hex("FFB347"), hex("E0481C")
		f.Parent = bowl
		f.Parent = flame
		local s = Instance.new("Smoke")
		s.Size, s.Opacity, s.RiseVelocity = 3 * scale, 0.12, 4
		s.Color = hex("5A5650")
		s.Parent = flame
		light(flame, hex("FFA24E"), 42, 2.2)
	end
	return flame
end

local function statue(parent: Instance, cf: CFrame, nike: boolean)
	-- cf = จุดกลางฐานฐานรูปปั้น (ผิวพื้น) หน้าหัน -Z
	local stone = if nike then MARBLE else hex("CFC9BA")
	mk(parent, "Plinth", Vector3.new(5, 1, 5), cf * CFrame.new(0, 0.5, 0), LIME, M.Marble)
	mk(parent, "Plinth", Vector3.new(4, 4.2, 4), cf * CFrame.new(0, 3.1, 0), MARBLE, M.Marble)
	mk(parent, "Plinth", Vector3.new(4.8, 0.7, 4.8), cf * CFrame.new(0, 5.45, 0), LIME, M.Marble)
	local y = 5.8
	for _, sx in { -0.55, 0.55 } do
		mk(parent, "StatueLeg", Vector3.new(0.9, 3.4, 1), cf * CFrame.new(sx, y + 1.7, 0), stone, M.Marble)
	end
	mk(parent, "StatueTorso", Vector3.new(2.6, 3, 1.5), cf * CFrame.new(0, y + 4.9, 0), stone, M.Marble)
	mk(parent, "StatueKilt", Vector3.new(2.8, 1, 1.6), cf * CFrame.new(0, y + 3.5, 0), BRONZE, M.Metal)
	ball(parent, "StatueHead", Vector3.new(1.5, 1.7, 1.5), cf * CFrame.new(0, y + 7.2, 0), stone, M.Marble)
	mk(parent, "StatueHelm", Vector3.new(1.6, 0.9, 1.7), cf * CFrame.new(0, y + 7.9, 0), BRONZE, M.Metal)
	mk(parent, "StatueHelmCrest", Vector3.new(0.35, 0.9, 1.9), cf * CFrame.new(0, y + 8.6, 0), RED, M.Fabric)
	for _, sx in { -1.9, 1.9 } do
		mk(parent, "StatueArm", Vector3.new(0.8, 2.8, 0.9), cf * CFrame.new(sx, y + 4.9, 0), stone, M.Marble)
	end
	if nike then
		for _, sx in { -1, 1 } do -- ปีกนีเก้ (ลิ่มสองข้างหลัง)
			local w = wedge(parent, "NikeWing", Vector3.new(0.35, 5, 3.4), cf * CFrame.new(sx * 1.9, y + 5.6, 1.7) * CFrame.Angles(0, 0, sx * math.rad(-18)), MARBLE, M.Marble)
			w.CFrame = w.CFrame * CFrame.Angles(math.rad(180), 0, 0)
		end
		mk(parent, "NikeWreath", Vector3.new(1.4, 0.2, 1.4), cf * CFrame.new(2.3, y + 6.9, -0.5), hex("6B7F3A"), M.Fabric, false)
	else
		cyl(parent, "StatueShield", 1.5, 0.35, cf * CFrame.new(-2.3, y + 4.6, -0.7) * CFrame.Angles(0, math.rad(90), 0), BRONZE, M.Metal)
		cyl(parent, "StatueSpear", 0.12, 11, cf * CFrame.new(2.4, y + 5.4, -0.2), hex("6A5A44"), M.Wood)
		mk(parent, "StatueSpearHead", Vector3.new(0.35, 1.2, 0.35), cf * CFrame.new(2.4, y + 11.4, -0.2), BRONZE, M.Metal)
	end
end

local function banner(parent: Instance, cf: CFrame, w: number, h: number, color: Color3)
	mk(parent, "BannerRod", Vector3.new(w + 0.6, 0.25, 0.25), cf * CFrame.new(0, 0.1, 0), BRONZE, M.Metal, false)
	mk(parent, "Banner", Vector3.new(w, h, 0.12), cf * CFrame.new(0, -h / 2, 0), color, M.Fabric, false)
	mk(parent, "BannerTrim", Vector3.new(w * 0.7, 0.35, 0.14), cf * CFrame.new(0, -h + 0.9, 0), hex("D9B658"), M.Fabric, false)
	mk(parent, "BannerEmblem", Vector3.new(w * 0.35, w * 0.35, 0.14), cf * CFrame.new(0, -h * 0.4, 0) * CFrame.Angles(0, 0, math.rad(45)), hex("D9B658"), M.Fabric, false)
end

-- ไม้ถูกบอร์ดข้อมูล: โครง 2 เสา + แผ่นป้ายพร้อม TextLabel ชื่อ Text (เซิร์ฟเวอร์อัปเดตข้อความภายหลัง)
local function infoBoard(parent: Instance, name: string, cf: CFrame, w: number, h: number, title: string, accent: Color3)
	for _, sx in { -w / 2 + 0.6, w / 2 - 0.6 } do
		mk(parent, "BoardPost", Vector3.new(1, h + 3, 1), cf * CFrame.new(sx, (h + 3) / 2 - h / 2 - 1, 0.7), MARBLE, M.Marble)
	end
	mk(parent, "BoardFrame", Vector3.new(w + 1, h + 1, 0.8), cf * CFrame.new(0, 0, 0.3), BRONZE, M.Metal)
	local board = mk(parent, name, Vector3.new(w, h, 0.4), cf, hex("14161B"), M.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 36
	gui.LightInfluence = 0.2
	gui.Parent = board
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.Size = UDim2.new(1, 0, 0.2, 0)
	t.BackgroundTransparency = 1
	t.Text = title
	t.TextColor3 = accent
	t.Font = Enum.Font.SourceSansBold
	t.TextScaled = true
	t.Parent = gui
	local b = Instance.new("TextLabel")
	b.Name = "Body"
	b.Position = UDim2.fromScale(0.04, 0.22)
	b.Size = UDim2.fromScale(0.92, 0.74)
	b.BackgroundTransparency = 1
	b.Text = "..."
	b.TextColor3 = hex("EDE6D2")
	b.Font = Enum.Font.SourceSansBold
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextYAlignment = Enum.TextYAlignment.Top
	b.TextSize = 30
	b.TextWrapped = true
	b.Parent = gui
	local glow = mk(parent, "BoardGlow", Vector3.new(w, 0.3, 0.3), cf * CFrame.new(0, h / 2 + 0.4, -0.2), accent, M.Neon, false)
	light(glow, accent, 18, 0.8)
end

---------------------------------------------------------------- ภายนอก: โคลอสเซียมกรีก + ลานหน้าสนาม
-- พิกัดท้องถิ่น: (0,0,0) = ศูนย์กลางวงรี, -Z = ด้านหน้า (ทางเข้าจากทางเดิน), ลานหน้าสนาม z -68..-34
function Kit.BuildExterior(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "WarArenaExterior"
	local RX, RZ = 46, 34
	local function P(a: number): (Vector3, Vector3) -- ตำแหน่งบนวงรี + เวกเตอร์ปกติหันออก
		local pos = Vector3.new(math.cos(a) * RX, 0, math.sin(a) * RZ)
		local n = Vector3.new(RZ * math.cos(a), 0, RX * math.sin(a)).Unit
		return pos, n
	end

	-- ลานปูหินหน้าสนาม + แถบทางเดินกลาง + เหรียญตราพื้น
	mk(m, "Forecourt", Vector3.new(102, 0.6, 36), CFrame.new(0, 0.1, -52), hex("CFC6B0"), M.Slate)
	mk(m, "ForecourtPath", Vector3.new(9, 0.08, 36), CFrame.new(0, 0.42, -52), hex("8B8478"), M.Cobblestone, false)
	for i = -4, 4 do
		mk(m, "PathInlay", Vector3.new(0.3, 0.1, 36), CFrame.new(i * 1.1, 0.43, -52), hex("A99D86"), M.Slate, false)
	end
	for _, sx in { -50, 50 } do
		mk(m, "ForecourtBorder", Vector3.new(1.4, 0.12, 36), CFrame.new(sx * 0.97, 0.43, -52), hex("8A6A3A"), M.Metal, false)
	end
	local medal = Vector3.new(0, 0.5, -50)
	cyl(m, "Medallion", 7.5, 0.1, CFrame.new(medal), MARBLE, M.Marble, false)
	cyl(m, "MedallionRing", 6.4, 0.12, CFrame.new(medal + Vector3.new(0, 0.01, 0)), BRONZE, M.Metal, false)
	cyl(m, "MedallionIn", 6.0, 0.14, CFrame.new(medal + Vector3.new(0, 0.02, 0)), hex("2C3340"), M.Slate, false)
	cyl(m, "MedallionStar", 2.6, 0.16, CFrame.new(medal + Vector3.new(0, 0.03, 0)), hex("D9B658"), M.Metal, false)
	for i = 0, 3 do
		mk(m, "MedallionSpoke", Vector3.new(0.5, 0.17, 11.8), CFrame.new(medal) * CFrame.Angles(0, i * math.pi / 4, 0), hex("D9B658"), M.Metal, false)
	end
	-- ลายกุญแจกรีก (meander) ขอบลาน
	for i = -23, 23 do
		local x = i * 2
		mk(m, "Meander", Vector3.new(1.4, 0.1, 0.35), CFrame.new(x, 0.45, -68.4 + 1), BRONZE, M.Metal, false)
		mk(m, "Meander", Vector3.new(0.35, 0.1, 0.9), CFrame.new(x + (if i % 2 == 0 then 0.5 else -0.5), 0.45, -67.7), BRONZE, M.Metal, false)
	end

	-- กำแพงล้อมลาน (ปิดทางเดินอื่น) + เสาปิลาสเตอร์ + โคมกระดาษ
	local function wallRun(x1: number, z1: number, x2: number, z2: number)
		local len = Vector3.new(x2 - x1, 0, z2 - z1).Magnitude
		local cf = CFrame.lookAt(Vector3.new((x1 + x2) / 2, 3.1, (z1 + z2) / 2), Vector3.new(x2, 3.1, z2))
		mk(m, "CourtWall", Vector3.new(1.6, 6.2, len), cf, LIME, M.Limestone)
		mk(m, "CourtWallCap", Vector3.new(2.3, 0.6, len + 0.4), cf * CFrame.new(0, 3.3, 0), MARBLE, M.Marble)
		mk(m, "CourtWallBase", Vector3.new(2.2, 0.9, len + 0.2), cf * CFrame.new(0, -2.65, 0), SAND_STONE, M.Limestone)
		local n = math.floor(len / 10)
		for i = 0, n do
			local t = i / math.max(n, 1)
			local px, pz = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
			mk(m, "Pilaster", Vector3.new(2.6, 6.8, 2.6), CFrame.new(px, 3.4, pz), MARBLE, M.Marble)
			lantern(m, Vector3.new(px, 8.0, pz), i % 3 == 0)
			mk(m, "LanternPost", Vector3.new(0.18, 1.2, 0.18), CFrame.new(px, 7.1, pz), DARK, M.Metal, false)
		end
	end
	wallRun(-51, -68, -51, 36) -- กำแพงข้างซ้าย
	wallRun(51, -68, 51, 36)
	wallRun(-51, 36, 51, 36) -- กำแพงหลัง
	wallRun(-51, -68, -10, -68) -- ด้านเหนือ เว้นช่องประตูกว้าง 20
	wallRun(10, -68, 51, -68)
	-- ประตูโทริอิหน้าทางเดิน + ป้ายนีออนคันจิ
	BK.torii(m, 0, 0.2, -69, 0, 1.15)
	local tsign = mk(m, "ToriiPlaque", Vector3.new(5.6, 1.8, 0.4), CFrame.new(0, 10.95, -69.8), hex("14161B"), M.SmoothPlastic)
	face(tsign, "闘技場", hex("FF4D8D"), Enum.Font.SourceSansBold)
	light(tsign, hex("FF4D8D"), 22, 1)

	-- วงรีตัวอาคารปิดทึบ: 40 ช่อง (ฐานหิน, ช่องโค้ง 2 ชั้น, เสาครึ่งต้น, บัวชั้น)
	local N = 44
	for i = 0, N - 1 do
		local a = (i + 0.5) / N * TAU
		local pos, n = P(a)
		if not (pos.Z < -10 and math.abs(pos.X) < 21) then -- เว้นที่ให้ซุ้มทางเข้า
			local next = P((i + 1.5) / N * TAU)
			local len = (next - pos).Magnitude * 1.06
			local base = CFrame.lookAt(pos, pos + n)
			mk(m, "BayWall", Vector3.new(len, 22, 3), base * CFrame.new(0, 11, 0), LIME, M.Limestone)
			mk(m, "BayPlinth", Vector3.new(len + 0.4, 1.4, 3.6), base * CFrame.new(0, 0.7, -0.1), SAND_STONE, M.Limestone)
			-- ช่องโค้งล่าง
			mk(m, "ArchLow", Vector3.new(len * 0.5, 6, 0.3), base * CFrame.new(0, 4.6, -1.55), hex("23252B"), M.Slate, false)
			cyl(m, "ArchLowTop", len * 0.25, 0.3, base * CFrame.new(0, 7.6, -1.55) * CFrame.Angles(0, math.rad(90), 0), hex("23252B"), M.Slate, false)
			-- ช่องโค้งบน
			mk(m, "ArchUp", Vector3.new(len * 0.36, 3.6, 0.3), base * CFrame.new(0, 14.6, -1.55), hex("2C2F36"), M.Slate, false)
			cyl(m, "ArchUpTop", len * 0.18, 0.3, base * CFrame.new(0, 16.4, -1.55) * CFrame.Angles(0, math.rad(90), 0), hex("2C2F36"), M.Slate, false)
			-- บัวคั่นชั้น/บัวหลังคา
			mk(m, "Cornice", Vector3.new(len + 0.2, 0.8, 4), base * CFrame.new(0, 10.1, -0.4), MARBLE, M.Marble)
			mk(m, "Cornice", Vector3.new(len + 0.2, 1.1, 4.4), base * CFrame.new(0, 22.4, -0.6), MARBLE, M.Marble)
			mk(m, "Parapet", Vector3.new(len, 1.5, 1.2), base * CFrame.new(0, 23.6, 0.8), LIME, M.Limestone)
			-- เสาครึ่งต้นคั่นช่องล่าง + บน
			local edge = base * CFrame.new(len / 2, 0, -1.6)
			cyl(m, "PierLow", 0.7, 9.2, edge * CFrame.new(0, 5.4, 0), MARBLE, M.Marble)
			cyl(m, "PierUp", 0.55, 8.2, edge * CFrame.new(0, 15.2, 0), MARBLE, M.Marble)
			mk(m, "PierCap", Vector3.new(1.9, 0.5, 1.9), edge * CFrame.new(0, 10.2, 0), MARBLE, M.Marble)
			if i % 2 == 0 then
				lantern(m, (base * CFrame.new(0, 9.2, -2.8)).Position, i % 6 == 0)
			end
			if i % 4 == 1 then
				banner(m, base * CFrame.new(0, 21.6, -2.4), 2.6, 7, if pos.Z < 0 then RED else BLUE)
			end
		end
	end
	-- ชั้นบนสุด: ดาดฟ้าวงรี + ชั้นห้องใต้หลังคาลดหลั่น + เสาธงทีม
	ecyl(m, "RoofDeck", RX - 1, RZ - 1, 1.2, Vector3.new(0, 23.2, 0), LIME, M.Limestone)
	ecyl(m, "AtticDrum", RX - 8, RZ - 8, 5, Vector3.new(0, 26.2, 0), SAND_STONE, M.Limestone)
	ecyl(m, "AtticCap", RX - 7, RZ - 7, 0.8, Vector3.new(0, 29.0, 0), MARBLE, M.Marble)
	for i = 0, 15 do
		local a = i / 16 * TAU
		local ax, az = math.cos(a) * (RX - 8.4), math.sin(a) * (RZ - 8.4)
		mk(m, "AtticPier", Vector3.new(1.4, 5, 1.4), CFrame.new(ax, 26.4, az), MARBLE, M.Marble)
	end
	for _, f in { { -26, -2, RED }, { 26, -2, BLUE } } do
		cyl(m, "FlagPole", 0.3, 16, CFrame.new(f[1], 31, f[2]), hex("D9D3C2"), M.Metal)
		mk(m, "Flag", Vector3.new(6, 3.6, 0.15), CFrame.new(f[1] + 3.2, 36, f[2]), f[3], M.Fabric, false)
	end

	-- ซุ้มทางเข้า (Propylaea): แท่นสามขั้น, เสาดอริก 6 ต้น, หน้าบัน, ป้ายสนาม
	for s = 0, 2 do
		mk(m, "PropylaeaStep", Vector3.new(38 - s * 2, 0.5, 13 - s * 1.5), CFrame.new(0, 0.25 + s * 0.5, -40.5 + s * 0.4), MARBLE, M.Marble)
	end
	mk(m, "FacadeWall", Vector3.new(36, 23, 3), CFrame.new(0, 11.5 + 1.5, -34.2), LIME, M.Limestone)
	mk(m, "FacadeBand", Vector3.new(36.6, 1, 3.4), CFrame.new(0, 25, -34.4), MARBLE, M.Marble)
	for k = 0, 5 do
		column(m, CFrame.new(-12.5 + k * 5, 1.5, -40.8), 16, 1.25)
	end
	-- ประตูทองสัมฤทธิ์ปิดสนิท (2 บาน + กรอบ)
	mk(m, "DoorFrame", Vector3.new(12, 13.4, 1.2), CFrame.new(0, 8.2, -34.2), MARBLE, M.Marble)
	for _, sx in { -2.6, 2.6 } do
		mk(m, "BronzeDoor", Vector3.new(5, 11.6, 0.7), CFrame.new(sx, 7.3, -35.0), BRONZE, M.Metal)
		for r = 0, 2 do
			mk(m, "DoorPanel", Vector3.new(3.6, 2.8, 0.3), CFrame.new(sx, 4 + r * 3.4, -35.45), hex("A67F44"), M.Metal, false)
		end
	end
	mk(m, "DoorRing", Vector3.new(6, 0.5, 0.4), CFrame.new(0, 13.4, -35.0), BRONZE, M.Metal, false)
	-- เหนือเสา: สถาปัตย์เทรฟ + ฟรีซ(ป้าย) + บัว
	mk(m, "Architrave", Vector3.new(34, 2.2, 4), CFrame.new(0, 18 + 1.5, -40.8), MARBLE, M.Marble)
	local frieze = mk(m, "Frieze", Vector3.new(34.2, 3.4, 4.2), CFrame.new(0, 20.7 + 1.5, -40.8), hex("171A20"), M.Slate)
	mk(m, "Cornice", Vector3.new(35.6, 0.9, 5), CFrame.new(0, 22.9 + 1.5, -40.8), MARBLE, M.Marble)
	local plaque = mk(m, "WarArenaSign", Vector3.new(22, 2.8, 0.3), CFrame.new(0, 22.2, -43), hex("1B1D23"), M.Metal)
	face(plaque, "WAR ARENA", hex("E7C46A"), Enum.Font.GothamBold)
	-- หน้าบัน: ลิ่ม 2 ฝั่ง + แผ่นหลัง + ป้ายนีออนคันจิ
	for _, sx in { -1, 1 } do
		local w = wedge(m, "PedimentWedge", Vector3.new(2.4, 7, 17.4), CFrame.new(sx * 8.7, 29.2, -40.8), MARBLE, M.Marble)
		w.CFrame = CFrame.new(sx * 8.7, 29.0, -40.8) * CFrame.Angles(0, if sx > 0 then math.rad(90) else math.rad(-90), 0)
	end
	mk(m, "PedimentBack", Vector3.new(17.4, 5.4, 1.4), CFrame.new(0, 28.4, -39.9), hex("2B2F37"), M.Slate)
	local kanji = mk(m, "KanjiNeon", Vector3.new(8, 3.6, 0.3), CFrame.new(0, 28.6, -41.6), hex("101216"), M.SmoothPlastic)
	face(kanji, "戦場", hex("FF4D8D"), Enum.Font.SourceSansBold)
	light(kanji, hex("FF4D8D"), 28, 1.3)
	for _, sx in { -1, 1 } do -- เสาต้นขอบหน้าบัน
		mk(m, "Acroterion", Vector3.new(1.4, 2.4, 1.4), CFrame.new(sx * 17.2, 26.6, -40.8), BRONZE, M.Metal)
	end
	mk(m, "Acroterion", Vector3.new(1.6, 3, 1.6), CFrame.new(0, 33.2, -40.8), BRONZE, M.Metal)
	-- ธงทีมแขวนระหว่างเสา
	for k = 0, 4 do
		banner(m, CFrame.new(-10 + k * 5, 17.2, -42.4), 2.2, 6.5, if k < 2 then RED elseif k > 2 then BLUE else hex("D9B658"))
	end

	-- กระถางไฟ (มีไฟ+ควัน), รูปปั้น, ม้านั่ง, ไซเปรส
	for _, sx in { -22, 22 } do
		brazier(m, Vector3.new(sx, 0.5, -44), 1.5, true)
		statue(m, CFrame.new(sx * 1.45, 0.5, -37) * CFrame.Angles(0, math.rad(if sx > 0 then 12 else -12), 0), sx > 0)
	end
	for _, sx in { -44, 44 } do
		brazier(m, Vector3.new(sx, 0.5, -60), 1.1, true)
	end
	for _, c in { { -49, -30 }, { 49, -30 }, { -49, 0 }, { 49, 0 }, { -49, 28 }, { 49, 28 }, { -34, -64 }, { 34, -64 } } do
		cyl(m, "CypressTrunk", 0.4, 2, CFrame.new(c[1], 1.1, c[2]), hex("4A3A2A"), M.Wood, false)
		ball(m, "Cypress", Vector3.new(3.6, 12, 3.6), CFrame.new(c[1], 8, c[2]), hex("34502F"), M.Grass, false)
	end
	for _, c in { { -30, -58 }, { 30, -58 } } do
		mk(m, "BenchSeat", Vector3.new(6, 0.5, 1.8), CFrame.new(c[1], 1.5, c[2]), MARBLE, M.Marble)
		for _, sx in { -2.4, 2.4 } do
			mk(m, "BenchLeg", Vector3.new(0.8, 1.3, 1.6), CFrame.new(c[1] + sx, 0.8, c[2]), LIME, M.Marble)
		end
	end

	-- กระดาน: ข้อมูล (คิว/แมตช์) ซ้าย, อันดับ ขวา
	infoBoard(m, "InfoBoard", CFrame.new(-32, 8.2, -41), 15, 8.5, "สนามประลอง · คิว/แมตช์", hex("E7C46A"))
	infoBoard(m, "RankBoard", CFrame.new(32, 8.2, -41), 15, 8.5, "กระดานอันดับ", hex("7EC8E3"))

	-- ศาลาคีออสก์ผู้ตัดสิน: เคาน์เตอร์หินอ่อน + หลังคาโค้ง + ป้ายเงินเข้าสนาม
	local K = CFrame.new(18, 0, -57)
	mk(m, "KioskCounter", Vector3.new(10, 2.4, 2.4), K * CFrame.new(0, 1.5, 0), MARBLE, M.Marble)
	mk(m, "KioskCounterTop", Vector3.new(10.8, 0.4, 3.2), K * CFrame.new(0, 2.9, 0), DARK, M.Granite)
	mk(m, "KioskCounterInlay", Vector3.new(8, 1.2, 0.2), K * CFrame.new(0, 1.5, -1.25), RED, M.Fabric, false)
	for _, sx in { -5.4, 5.4 } do
		cyl(m, "KioskPillar", 0.5, 11, K * CFrame.new(sx, 6.0, 1.2), MARBLE, M.Marble)
	end
	mk(m, "KioskRoof", Vector3.new(13, 0.8, 5), K * CFrame.new(0, 11.8, 1.2), BRONZE, M.Metal)
	mk(m, "KioskRoofCap", Vector3.new(11, 0.6, 3.6), K * CFrame.new(0, 12.5, 1.2), hex("A67F44"), M.Metal)
	local ksign = mk(m, "KioskSign", Vector3.new(9, 1.8, 0.3), K * CFrame.new(0, 10.4, -1.2), hex("14161B"), M.SmoothPlastic)
	face(ksign, "สนามประลอง · คุยกับผู้ตัดสิน", hex("E7C46A"), Enum.Font.SourceSansBold)
	lantern(m, (K * CFrame.new(-4.2, 9.4, -1.5)).Position, true)
	lantern(m, (K * CFrame.new(4.2, 9.4, -1.5)).Position, true)

	m.WorldPivot = CFrame.new() -- จุดอ้างอิงคือศูนย์กลางวงรี (ไม่ใช่กึ่งกลางกรอบ)
	m.Parent = parent
	return m
end

---------------------------------------------------------------- ภายใน: แม่แบบธีมแบบปรับขนาด
-- ทุกธีมสร้างจากรัศมีพื้นสนาม R (สตั๊ด): จำนวนชั้นอัฒจันทร์/เสา/ไฟ/ธง/รูปปั้นเพิ่มตาม R
-- ใช้ส่วนวงแหวนเรียงต่อเนื่อง (ไม่ใช่ที่นั่งทีละตัว) เพื่อคุมจำนวน part ให้ <= ~4,000 ที่ R=130
Kit.MIN_R, Kit.MAX_R = 40, 130

-- รัศมีพื้นสนามจากจำนวนผู้เข้าแข่ง (ปัดเป็นช่วงละ 10 เพื่อ cache แม่แบบ)
function Kit.RadiusFor(players: number): number
	local r = math.clamp(28 + 3.2 * players, Kit.MIN_R, Kit.MAX_R)
	return math.clamp(math.round(r / 10) * 10, Kit.MIN_R, Kit.MAX_R)
end

local function nseg(r: number, spacing: number, minN: number): number
	return math.max(minN, math.ceil(TAU * r / spacing))
end

local function newTemplate(theme: string, R: number): (Model, Folder)
	local m = Instance.new("Model")
	m.Name = `ArenaTemplate_{theme}_{R}`
	m:SetAttribute("Theme", theme)
	m:SetAttribute("FloorRadius", R)
	m:SetAttribute("Radius", R + 2) -- ขอบเขตนักสู้
	local origin = mk(m, "Origin", Vector3.new(1, 1, 1), CFrame.new(0, -0.5, 0), DARK, M.SmoothPlastic, false)
	origin.Transparency = 1
	m.PrimaryPart = origin
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = m
	return m, markers
end

local function marker(markers: Folder, name: string, pos: Vector3)
	local p = mk(markers, name, Vector3.new(1, 1, 1), CFrame.new(pos), DARK, M.SmoothPlastic, false)
	p.Transparency = 1
	p.CastShadow = false
end

-- จุดเกิด: ทีม A ฝั่ง -Z ทีม B ฝั่ง +Z เรียงแถว 8 คอลัมน์ x 2 แถว (สูงสุด 16 ต่อทีม), Bot1..40 กระจายทั่วพื้น, Spec = ที่นั่งชม
local function markSpawns(markers: Folder, R: number, seats: { Vector3 }, outer: number)
	local z0 = R * 0.5
	for i = 1, 16 do
		local col, row = (i - 1) % 8, (i - 1) // 8
		local x = (col - 3.5) * 5
		marker(markers, "SpawnA" .. i, Vector3.new(x, 0, -(z0 + row * 5)))
		marker(markers, "SpawnB" .. i, Vector3.new(-x, 0, z0 + row * 5))
	end
	for i = 1, 40 do
		local rr = math.sqrt((i - 0.5) / 40) * R * 0.78
		marker(markers, "Bot" .. i, Vector3.new(math.cos(i * 2.39996) * rr, 0, math.sin(i * 2.39996) * rr))
	end
	for i, s in seats do
		marker(markers, "Spec" .. i, s)
	end
	local model = markers.Parent :: Model
	model:SetAttribute("OuterRadius", outer)
end

-- ป้ายคะแนน: ลอยเหนือที่นั่ง หันหน้าเข้าสนาม ตัวหนังสือแยกเป็นช่อง (ไคลเอนต์อัปเดตตาม Attribute ของโมเดล)
-- y0..y1 = ช่วงความสูงของเสาที่ค้ำ (ขึ้นหรือห้อยก็ได้)
local function scoreBoard(m: Model, a: number, Rb: number, yBottom: number, w: number, h: number, accent: Color3, y0: number, y1: number)
	local y = yBottom + h / 2
	local pos = Vector3.new(math.cos(a) * Rb, y, math.sin(a) * Rb)
	local p = mk(m, "Score", Vector3.new(w, h, 0.6), CFrame.lookAt(pos, Vector3.new(0, y, 0)), hex("0B0C0F"), M.SmoothPlastic, false)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = math.min(30, 1400 / w)
	gui.LightInfluence = 0
	gui.Parent = p
	local function lab(name: string, x: number, yy: number, sx: number, sy: number, color: Color3, align: Enum.TextXAlignment?)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Position = UDim2.fromScale(x, yy)
		l.Size = UDim2.fromScale(sx, sy)
		l.BackgroundTransparency = 1
		l.Text = ""
		l.TextColor3 = color
		l.Font = Enum.Font.SourceSansBold
		l.TextScaled = true
		l.TextXAlignment = align or Enum.TextXAlignment.Center
		l.TextStrokeTransparency = 0.6
		l.Parent = gui
	end
	local WHITE = hex("F2EEE0")
	lab("Title", 0.02, 0.02, 0.96, 0.2, accent)
	lab("NameA", 0.02, 0.24, 0.36, 0.28, hex("FF8A80"))
	lab("NameB", 0.62, 0.24, 0.36, 0.28, hex("82B1FF"))
	lab("Mid", 0.38, 0.2, 0.24, 0.42, WHITE)
	lab("LeadA", 0.02, 0.53, 0.36, 0.12, hex("E8B0AA"))
	lab("LeadB", 0.62, 0.53, 0.36, 0.12, hex("A9C2EE"))
	lab("Timer", 0.02, 0.68, 0.52, 0.3, hex("FFE066"))
	lab("Note", 0.55, 0.68, 0.43, 0.3, WHITE)
	-- กรอบนีออน + เสาค้ำสองต้น
	for _, s in { -1, 1 } do
		mk(m, "ScoreRim", Vector3.new(w + 0.8, 0.4, 0.7), p.CFrame * CFrame.new(0, s * (h / 2 + 0.2), 0), accent, M.Neon, false)
		mk(m, "ScoreRim", Vector3.new(0.4, h + 0.8, 0.7), p.CFrame * CFrame.new(s * (w / 2 + 0.2), 0, 0), accent, M.Neon, false)
		local lo, hi = math.min(y0, y1), math.max(y0, y1)
		local pp = (CFrame.lookAt(pos, Vector3.new(0, y, 0)) * CFrame.new(s * w * 0.36, 0, 1.0)).Position
		mk(m, "ScorePost", Vector3.new(1.4, hi - lo, 1.4), CFrame.new(pp.X, (lo + hi) / 2, pp.Z), hex("2B2E34"), M.Metal)
	end
end

local function boardSize(R: number, maxH: number?): (number, number)
	local w = math.clamp(26 + (R - 30) * 0.45, 26, 66)
	return w, math.min(w * 0.32, maxH or 99)
end

-- กำแพงกั้นล่องหนรอบสนามกันออก/กันกระโดดข้าม (ทั้งผู้เล่นและผู้ชม)
local function barrier(m: Model, R: number)
	local n = nseg(R, 30, 24)
	ring(n, R, function(_, cf)
		local p = mk(m, "Barrier", Vector3.new(chord(n, R), 70, 1), cf * CFrame.new(0, 35, 0), DARK, M.SmoothPlastic)
		p.Transparency = 1
		p.CanQuery = false
	end)
end

local function floorBand(m: Model, r1: number, r2: number, y: number, color: Color3, base: Color3, mat: Enum.Material?)
	cyl(m, "FloorBand", r1, 0.06, CFrame.new(0, y, 0), color, mat or M.Concrete, false)
	cyl(m, "FloorBandIn", r2, 0.08, CFrame.new(0, y + 0.005, 0), base, M.Concrete, false)
end

-- แถบสีทีมเป็นครึ่งวงกลม (เรียงแผ่นบางตามระยะ z)
local function halfDisc(m: Model, r: number, sign: number, color: Color3, mat: Enum.Material, y: number, sc: number)
	local z = 7.8 * sc -- เริ่มนอกเหรียญกลาง
	local step = 2.1 * sc
	while z < r - 1 do
		local len = 2 * math.sqrt(r * r - z * z)
		mk(m, "TeamStrip", Vector3.new(len, 0.05, step * 0.72), CFrame.new(0, y + 0.07, sign * z), color, mat, false)
		z += step
	end
end

-- เสาไฟรอบขอบพื้น (ไฟกระจายทั่วสนามใหญ่)
local function mast(m: Model, R: number, color: Color3, h: number)
	local n = math.max(4, math.round(TAU * R / 45))
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * TAU
		local pos = Vector3.new(math.cos(a) * (R - 1.2), 0, math.sin(a) * (R - 1.2))
		cyl(m, "MastPole", 0.3, h, CFrame.new(pos + Vector3.new(0, h / 2, 0)), DARK, M.Metal, false)
		local lamp = ball(m, "MastLamp", Vector3.one * 1.6, CFrame.new(pos + Vector3.new(0, h + 0.4, 0)), color, M.Neon, false)
		light(lamp, color, math.clamp(R * 0.6, 36, 60), 1.4)
	end
end

-- ไฟส่องพื้นสนามแบบลอยล่องหน (ไม่มีชิ้นให้เห็น) เป็นวงซ้อนห่างกัน ~70 สตั๊ด ให้ทั้งสนามสว่างพอแม้เป็นกลางคืน
local function flood(m: Model, R: number, color: Color3)
	local function ringLights(r: number, n: number)
		for i = 0, n - 1 do
			local a = i / n * TAU + r
			local p = mk(m, "FloodLight", Vector3.one * 0.5, CFrame.new(math.cos(a) * r, 26, math.sin(a) * r), DARK, M.SmoothPlastic, false)
			p.Transparency = 1
			light(p, color, 60, 1.3)
		end
	end
	ringLights(0, 1)
	local r = R * 0.5
	while r < R * 0.95 do
		ringLights(r, math.max(5, math.ceil(TAU * r / 62)))
		r += math.max(R * 0.4, 30)
	end
end

local function finish(m: Model)
	local n = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	m:SetAttribute("Parts", n)
end

---------------- ธีม Greek Sand Colosseum
local function buildGreek(R: number): Model
	local m, markers = newTemplate("GreekSand", R)
	local s = 1 + (R - 30) / 60
	local sc = math.max(1, R / 60)
	local SAND = hex("D6BC8C")
	local T = 5 + math.floor((R - 30) / 20)
	local hTop = 5.6 + (T - 1) * 1.5
	local platR = R + 4 + T * 3.4 + 3.5
	local colR, wallR = platR - 2.5, platR + 3.5
	local H = hTop + 18.5
	cyl(m, "Ground", wallR + 5, 4, CFrame.new(0, -2.05, 0), hex("8D7A58"), M.Sandstone)
	cyl(m, "Floor", R + 1.8, 2, CFrame.new(0, -1, 0), SAND, M.Sand)
	-- ลวดลายพื้น
	floorBand(m, R - 0.4, R - 1.8, 0.03, MARBLE, SAND, M.Marble)
	floorBand(m, R - 2.4, R - 2.7, 0.04, BRONZE, SAND, M.Metal)
	halfDisc(m, R - 8 * s, -1, hex("B0594B"), M.Concrete, 0.05, sc)
	halfDisc(m, R - 8 * s, 1, hex("46709A"), M.Concrete, 0.05, sc)
	cyl(m, "Medallion", 6 * s, 0.1, CFrame.new(0, 0.06, 0), MARBLE, M.Marble, false)
	cyl(m, "MedallionRing", 5.2 * s, 0.12, CFrame.new(0, 0.07, 0), BRONZE, M.Metal, false)
	cyl(m, "MedallionIn", 4.8 * s, 0.14, CFrame.new(0, 0.08, 0), hex("2C3340"), M.Slate, false)
	cyl(m, "MedallionSun", 2.3 * s, 0.16, CFrame.new(0, 0.09, 0), hex("D9B658"), M.Metal, false)
	for i = 0, 3 do
		mk(m, "MedallionRay", Vector3.new(0.45 * s, 0.17, 9.6 * s), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, i * math.pi / 4, 0), hex("D9B658"), M.Metal, false)
	end
	ring(28, 6.9 * s, function(_, cf)
		ball(m, "Laurel", Vector3.new(1.3 * s, 0.14, 0.55 * s), cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, math.rad(35), 0), hex("66813C"), M.Fabric, false)
	end)
	for _, sgn in { -1, 1 } do -- ตราประจำทีม
		local z, r = sgn * R * 0.47, 3.4 * s
		cyl(m, "Sigil", r, 0.1, CFrame.new(0, 0.07, z), if sgn < 0 then RED else BLUE, M.Metal, false)
		cyl(m, "SigilIn", r * 0.82, 0.12, CFrame.new(0, 0.08, z), SAND, M.Sand, false)
		cyl(m, "SigilCore", r * 0.35, 0.14, CFrame.new(0, 0.09, z), hex("D9B658"), M.Metal, false)
	end
	local nMe = nseg(R - 1.1, 3.5 * sc, 52)
	ring(nMe, R - 1.1, function(i, cf)
		mk(m, "Meander", Vector3.new(1.6 * sc, 0.1, 0.4 * sc), cf * CFrame.new(0, 0.07, 0.3), BRONZE, M.Metal, false)
		mk(m, "Meander", Vector3.new(0.4 * sc, 0.1, 0.9 * sc), cf * CFrame.new(if i % 2 == 0 then 0.6 * sc else -0.6 * sc, 0.07, 0), BRONZE, M.Metal, false)
	end)
	mast(m, R, hex("FFD9A8"), 15)
	flood(m, R, hex("FFE6C0"))
	-- แนวกั้นฐาน + กำแพงล่องหน
	local nPod = nseg(R + 2.2, 7, 36)
	ring(nPod, R + 2.2, function(_, cf)
		local c = chord(nPod, R + 2.2)
		mk(m, "Podium", Vector3.new(c, 5, 1.8), cf * CFrame.new(0, 2.5, 0), MARBLE, M.Marble)
		mk(m, "PodiumCap", Vector3.new(c, 0.5, 2.4), cf * CFrame.new(0, 5.2, 0), LIME, M.Marble)
		mk(m, "PodiumBase", Vector3.new(c, 0.9, 2.3), cf * CFrame.new(0, 0.45, -0.1), SAND_STONE, M.Marble)
	end)
	barrier(m, R + 3.2)
	-- อัฒจันทร์หินอ่อน T ชั้น (ชั้นเพิ่มตามรัศมี)
	local seats: { Vector3 } = {}
	for t = 1, T do
		local r = R + 4 + (t - 1) * 3.4
		local h = 5.6 + (t - 1) * 1.5
		local n = nseg(r + 1.7, 7, 40)
		local step = math.max(5, math.ceil(n / 40))
		ring(n, r + 1.7, function(i, cf)
			mk(m, "Tier", Vector3.new(chord(n, r + 1.7), h, 3.4), cf * CFrame.new(0, h / 2, 0), if t % 2 == 0 then LIME else MARBLE, M.Marble)
			if t == 2 and i % step == 0 then
				table.insert(seats, (cf * CFrame.new(0, h + 3, 0)).Position)
			end
		end)
	end
	-- ชานชั้นบน + เสาดอริก + สถาปัตย์เทรฟ + กำแพงนอก
	local nPl = nseg(platR, 10, 32)
	ring(nPl, platR, function(_, cf)
		mk(m, "Platform", Vector3.new(chord(nPl, platR), hTop, 8.6), cf * CFrame.new(0, hTop / 2, 0), SAND_STONE, M.Limestone)
	end)
	local nCol = nseg(colR, 11, 32)
	ring(nCol, colR, function(i, cf)
		local c = chord(nCol, colR)
		column(m, cf * CFrame.new(0, hTop, 0), 14, 1.1)
		mk(m, "Entablature", Vector3.new(c, 2.0, 3.2), cf * CFrame.new(0, hTop + 15, 0), MARBLE, M.Marble)
		mk(m, "Frieze", Vector3.new(c, 1.5, 3.4), cf * CFrame.new(0, hTop + 16.7, 0), hex("5C3B33"), M.Slate)
		mk(m, "Cornice", Vector3.new(c, 0.7, 3.8), cf * CFrame.new(0, hTop + 17.8, 0), MARBLE, M.Marble)
		if i % 2 == 0 then
			lantern(m, (cf * CFrame.new(0, hTop + 9, -1.4)).Position, i % 4 == 0)
		end
	end)
	local nW = nseg(wallR, 11, 32)
	ring(nW, wallR, function(i, cf, a)
		local c = chord(nW, wallR)
		mk(m, "OuterWall", Vector3.new(c, H, 2.2), cf * CFrame.new(0, H / 2, 0), LIME, M.Limestone)
		mk(m, "OuterWallArch", Vector3.new(c * 0.55, 9, 0.3), cf * CFrame.new(0, hTop + 5.4, -1.2), hex("2B2D33"), M.Slate, false)
		cyl(m, "OuterWallArchTop", c * 0.275, 0.3, cf * CFrame.new(0, hTop + 9.9, -1.2) * CFrame.Angles(0, math.rad(90), 0), hex("2B2D33"), M.Slate, false)
		if i % 2 == 1 then
			banner(m, cf * CFrame.new(0, H - 1.6, -1.5), 3, 11, if math.sin(a) < 0 then RED else BLUE)
		end
	end)
	-- รูปปั้น/กระถางไฟสลับกันบนชาน (กระถางที่ 1-6 มีไฟ+ควัน ที่เหลือมีแค่แสง)
	local N = math.max(12, 2 * math.round(TAU * (platR + 1.2) / 64))
	local nb = 0
	for i = 0, N - 1 do
		local a = i / N * TAU + math.pi / N
		local pos = Vector3.new(math.cos(a) * (platR + 1.2), hTop, math.sin(a) * (platR + 1.2))
		if i % 2 == 0 then
			statue(m, CFrame.lookAt(pos, Vector3.new(0, hTop, 0)), i % 4 == 2)
		else
			nb += 1
			local flame = brazier(m, pos, 1.2, nb <= 6)
			if nb > 6 then
				light(flame, hex("FFA24E"), 42, 1.6)
			end
		end
	end
	local bw, bh = boardSize(R)
	for k = 0, 3 do
		scoreBoard(m, k * math.pi / 2, wallR, H + 4, bw, bh, hex("D9B658"), H, H + 4)
	end
	markSpawns(markers, R, seats, wallR)
	finish(m)
	return m
end

---------------- ธีม Underground Neon Ring
local function buildNeon(R: number): Model
	local m, markers = newTemplate("NeonRing", R)
	local s = 1 + (R - 30) / 60
	local sc = math.max(1, R / 60)
	local PINK, CYAN = hex("FF2E88"), hex("27E1FF")
	local T = 4 + math.floor((R - 30) / 25)
	local hTop = 3.2 + (T - 1) * 1.6
	local wallR = R + 3.6 + T * 3.4 + 5.8
	local CEIL, WALLH = 42, 40
	cyl(m, "Ground", wallR + 6, 4, CFrame.new(0, -2.05, 0), hex("15161A"), M.Concrete)
	cyl(m, "Floor", R + 1.8, 2, CFrame.new(0, -1, 0), hex("3A3E47"), M.Concrete)
	local fl = hex("3A3E47")
	floorBand(m, R - 0.4, R - 0.8, 0.03, PINK, fl, M.Neon)
	floorBand(m, R * 0.75, R * 0.75 - 0.3, 0.03, CYAN, fl, M.Neon)
	halfDisc(m, R - 8.5 * s, -1, hex("6A1E28"), M.SmoothPlastic, 0.04, sc)
	halfDisc(m, R - 8.5 * s, 1, hex("1E3C6A"), M.SmoothPlastic, 0.04, sc)
	mk(m, "CenterLine", Vector3.new(2 * R - 2, 0.07, 0.35 * sc), CFrame.new(0, 0.06, 0), hex("FFE58A"), M.Neon, false)
	cyl(m, "CenterDisc", 7 * s, 0.1, CFrame.new(0, 0.07, 0), hex("14161B"), M.Slate, false)
	floorBand(m, 7.4 * s, 7.1 * s, 0.08, PINK, fl, M.Neon)
	local kz = mk(m, "FloorKanji", Vector3.new(12 * s, 0.05, 12 * s), CFrame.new(0, 0.2, 0), DARK, M.SmoothPlastic, false)
	kz.Transparency = 1
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40 / s
	g.LightInfluence = 0
	g.Parent = kz
	local kl = Instance.new("TextLabel")
	kl.Size = UDim2.fromScale(1, 1)
	kl.BackgroundTransparency = 1
	kl.Text = "戦"
	kl.TextScaled = true
	kl.Font = Enum.Font.SourceSansBold
	kl.TextColor3 = PINK
	kl.Parent = g
	mast(m, R, hex("FFE9C4"), 12)
	flood(m, R, hex("FFD9B0"))
	-- กรงลวด
	local nC = nseg(R + 1.6, 6, 40)
	ring(nC, R + 1.6, function(i, cf)
		cyl(m, "CagePost", 0.22, 13, cf * CFrame.new(0, 6.5, 0), hex("55585F"), M.Metal, false)
		local c = chord(nC, R + 1.6)
		mk(m, "CageMesh", Vector3.new(c, 11, 0.12), cf * CFrame.new(0, 6.2, 0), hex("8E949C"), M.Metal, false).Transparency = 0.72
		local rail = mk(m, "CageRailTop", Vector3.new(c, 0.28, 0.28), cf * CFrame.new(0, 12.6, 0), if i % 2 == 0 then PINK else CYAN, M.Neon, false)
		if i % 5 == 0 then
			light(rail, rail.Color, 48, 1.8)
		end
		mk(m, "CageRailMid", Vector3.new(c, 0.18, 0.18), cf * CFrame.new(0, 6.0, 0), hex("55585F"), M.Metal, false)
		mk(m, "CageFoot", Vector3.new(c, 1.6, 0.9), cf * CFrame.new(0, 0.8, 0), hex("3C3F46"), M.Concrete)
	end)
	barrier(m, R + 2.2)
	-- อัฒจันทร์คอนกรีต T ชั้น + ฝูงชนเงาดำ + แท่งไฟ
	local seats: { Vector3 } = {}
	for t = 1, T do
		local r = R + 3.6 + (t - 1) * 3.4
		local h = 3.2 + (t - 1) * 1.6
		local n = nseg(r + 1.7, 7, 36)
		local cStep = math.max(2, math.ceil(n / 40))
		local sStep = math.max(4, math.ceil(n / 40))
		ring(n, r + 1.7, function(i, cf)
			mk(m, "Tier", Vector3.new(chord(n, r + 1.7), h, 3.4), cf * CFrame.new(0, h / 2, 0), if t % 2 == 0 then hex("3E4148") else hex("33363C"), M.Concrete)
			if i % cStep == 0 then
				local sk = rng:NextNumber(0.9, 1.15)
				local p0 = cf * CFrame.new(rng:NextNumber(-1.2, 1.2), h + 1.0 * sk, 0.2)
				mk(m, "CrowdBody", Vector3.new(1.3, 2.0 * sk, 0.8), p0, hex("0D0E11"), M.Fabric, false)
				ball(m, "CrowdHead", Vector3.new(0.85, 0.95, 0.85), p0 * CFrame.new(0, 1.4 * sk, 0), hex("0D0E11"), M.Fabric, false)
				if rng:NextNumber() < 0.28 then
					mk(m, "Glowstick", Vector3.new(0.14, 1.1, 0.14), p0 * CFrame.new(0.9, 1.9 * sk, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))), if rng:NextNumber() < 0.5 then PINK else CYAN, M.Neon, false)
				end
			end
			if t == 2 and i % sStep == 0 then
				table.insert(seats, (cf * CFrame.new(0, h + 3, 0)).Position)
			end
		end)
	end
	-- กำแพงนอก + โปสเตอร์ + ท่อนีออน
	local posters = { "戦", "闘魂", "喧嘩上等", "TOKYO", "極", "鬼", "勝", "UNDERGROUND", "地下闘技", "魂", "拳", "FIGHT" }
	local nW = nseg(wallR, 7, 36)
	local pStep = math.max(3, math.ceil(nW / 36))
	ring(nW, wallR, function(i, cf)
		local c = chord(nW, wallR)
		mk(m, "OuterWall", Vector3.new(c, WALLH, 2.4), cf * CFrame.new(0, WALLH / 2, 0), hex("26282E"), M.Concrete)
		mk(m, "WallPanel", Vector3.new(c * 0.84, 16, 0.2), cf * CFrame.new(0, 9.5, -1.3), hex("30333A"), M.DiamondPlate, false)
		if i % pStep == 0 then
			local col = if (i // pStep) % 2 == 0 then PINK else CYAN
			local pn = mk(m, "Poster", Vector3.new(7, 9, 0.2), cf * CFrame.new(0, 14, -1.4), hex("0F1014"), M.SmoothPlastic, false)
			face(pn, posters[(i // pStep) % #posters + 1], col, Enum.Font.SourceSansBold)
			mk(m, "PosterRim", Vector3.new(7.4, 9.4, 0.15), cf * CFrame.new(0, 14, -1.3), col, M.Neon, false).Transparency = 0.3
			light(pn, col, 26, 0.7)
		elseif i % pStep == 1 then
			cyl(m, "NeonTube", 0.22, 14, cf * CFrame.new(0, 14, -1.5), if i % 2 == 0 then CYAN else PINK, M.Neon, false)
		end
	end)
	-- เพดาน + ไฟแผงแขวน 1-2 วง (ไฟเพิ่มตามขนาดสนาม)
	cyl(m, "Ceiling", wallR + 5, 1, CFrame.new(0, CEIL, 0), hex("131418"), M.Concrete, false)
	local function lamps(rr: number, y: number)
		local n = math.max(6, math.round(TAU * rr / 30))
		for i = 0, n - 1 do
			local a = i / n * TAU
			local pos = Vector3.new(math.cos(a) * rr, y, math.sin(a) * rr)
			cyl(m, "LampChain", 0.08, CEIL - y - 0.5, CFrame.new(pos + Vector3.new(0, (CEIL - y) / 2 - 0.25, 0)), hex("55585F"), M.Metal, false)
			cyl(m, "LampShade", 2.2, 0.8, CFrame.new(pos), hex("2B2E34"), M.Metal, false)
			local bulb = cyl(m, "LampBulb", 1.8, 0.2, CFrame.new(pos - Vector3.new(0, 0.45, 0)), hex("FFE9C4"), M.Neon, false)
			light(bulb, hex("FFD9A8"), 60, if R > 70 then 1.0 else 1.8)
		end
	end
	lamps(R * 0.57, 34)
	if R > 70 then
		lamps(R * 0.92, 34)
	end
	local bw, bh = boardSize(R, 16)
	for k = 0, 3 do
		scoreBoard(m, k * math.pi / 2, wallR - 3.4, 24, bw, bh, if k % 2 == 0 then PINK else CYAN, 24 + bh, CEIL - 0.5)
	end
	markSpawns(markers, R, seats, wallR)
	finish(m)
	return m
end

---------------- ธีม Rooftop Night
local function buildRooftop(R: number): Model
	local m, markers = newTemplate("Rooftop", R)
	local s = 1 + (R - 30) / 60
	local sc = math.max(1, R / 60)
	local YEL = hex("F2C230")
	local T = 2 + math.floor((R - 30) / 30)
	local width = 3.6 * T + 7.8
	local deckIn = R + 2.5
	local outerR = deckIn + width - 0.5
	cyl(m, "Ground", outerR + 14, 4, CFrame.new(0, -2.05, 0), hex("3A3D43"), M.Concrete)
	cyl(m, "Floor", R + 1.8, 2, CFrame.new(0, -1, 0), hex("5B5E64"), M.Concrete)
	local fl = hex("5B5E64")
	local nH = nseg(R - 0.8, 4 * sc, 48)
	ring(nH, R - 0.8, function(i, cf)
		mk(m, "Hazard", Vector3.new(chord(nH, R - 0.8) * 0.98, 0.07, 1.6), cf * CFrame.new(0, 0.04, 0), if i % 2 == 0 then YEL else hex("17171A"), M.Concrete, false)
	end)
	floorBand(m, R - 2.4, R - 2.7, 0.04, hex("E9E6DC"), fl, M.Concrete)
	halfDisc(m, R - 8.5 * s, -1, hex("7C3A36"), M.Concrete, 0.05, sc)
	halfDisc(m, R - 8.5 * s, 1, hex("36527A"), M.Concrete, 0.05, sc)
	floorBand(m, R - 8.1 * s, R - 8.4 * s, 0.06, hex("E9E6DC"), fl, M.Concrete)
	cyl(m, "CenterDisc", 6 * s, 0.08, CFrame.new(0, 0.07, 0), hex("26282E"), M.Concrete, false)
	floorBand(m, 6.2 * s, 5.9 * s, 0.09, YEL, hex("26282E"), M.Concrete)
	for _, sx in { -2.2, 2.2 } do
		mk(m, "HMark", Vector3.new(0.9 * s, 0.05, 6 * s), CFrame.new(sx * s, 0.16, 0), hex("E9E6DC"), M.Concrete, false)
	end
	mk(m, "HMark", Vector3.new(4.4 * s, 0.05, 0.9 * s), CFrame.new(0, 0.16, 0), hex("E9E6DC"), M.Concrete, false)
	mast(m, R, hex("FFE2A0"), 14)
	flood(m, R, hex("FFE2B8"))
	-- รั้วตาข่าย + ฐานพาราเพ็ต
	local nF = nseg(R + 1.4, 7, 40)
	ring(nF, R + 1.4, function(_, cf)
		local c = chord(nF, R + 1.4)
		mk(m, "Parapet", Vector3.new(c, 3.2, 1.2), cf * CFrame.new(0, 1.6, 0), hex("6C6F76"), M.Concrete)
		cyl(m, "FencePost", 0.16, 9, cf * CFrame.new(0, 7.2, 0), hex("55585F"), M.Metal, false)
		mk(m, "FenceMesh", Vector3.new(c, 6.6, 0.1), cf * CFrame.new(0, 6.7, 0), hex("8E949C"), M.Metal, false).Transparency = 0.7
		mk(m, "FenceRail", Vector3.new(c, 0.2, 0.2), cf * CFrame.new(0, 10.0, 0), hex("55585F"), M.Metal, false)
	end)
	barrier(m, R + 2.2)
	-- ดาดฟ้าผู้ชม: ลังพาเลทเป็นที่นั่ง T แถว + ถังน้ำ + แอร์ + เสาอากาศ
	local seats: { Vector3 } = {}
	local nD = nseg(deckIn + width / 2, 7, 36)
	ring(nD, deckIn + width / 2, function(_, cf)
		mk(m, "Deck", Vector3.new(chord(nD, deckIn + width / 2), 1, width), cf * CFrame.new(0, 0.1, 0), hex("565A60"), M.Concrete)
	end)
	for t = 1, T do
		local r = R + 4.5 + (t - 1) * 3.6
		local n = nseg(r, 7, 30)
		local sStep = math.max(4, math.ceil(n / 40))
		ring(n, r, function(i, cf)
			local hh = 1.4 + t * 0.6
			mk(m, "CrateStep", Vector3.new(chord(n, r) * 0.9, hh, 2.2), cf * CFrame.new(0, hh / 2, 0), if (i + t) % 3 == 0 then hex("8A6A4C") else hex("6E5640"), M.Wood)
			if t == T and i % sStep == 0 then
				table.insert(seats, (cf * CFrame.new(0, hh + 1.2, 0)).Position)
			end
		end)
	end
	local nO = nseg(outerR, 7, 36)
	ring(nO, outerR, function(_, cf)
		local c = chord(nO, outerR)
		mk(m, "OuterParapet", Vector3.new(c, 5, 1.4), cf * CFrame.new(0, 2.5, 0), hex("6C6F76"), M.Concrete)
		cyl(m, "OuterPost", 0.16, 8, cf * CFrame.new(0, 8, 0), hex("55585F"), M.Metal, false)
		mk(m, "OuterMesh", Vector3.new(c, 7, 0.1), cf * CFrame.new(0, 8.5, 0), hex("8E949C"), M.Metal, false).Transparency = 0.7
	end)
	barrier(m, outerR + 1.4)
	for _, a in { 0.4, 2.0, 3.6, 5.2 } do
		local pos = Vector3.new(math.cos(a) * (outerR - 3.8), 0, math.sin(a) * (outerR - 3.8))
		mk(m, "ACUnit", Vector3.new(5, 3.2, 3.4), CFrame.new(pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, a, 0), hex("9A9EA6"), M.Metal)
		cyl(m, "ACFan", 1.2, 0.3, CFrame.new(pos + Vector3.new(0, 3.3, 0)), hex("2A2C31"), M.Metal, false)
	end
	local tank = Vector3.new(0, 0, -(outerR - 3))
	for _, o in { { -2.4, -2.4 }, { 2.4, -2.4 }, { -2.4, 2.4 }, { 2.4, 2.4 } } do
		mk(m, "TankLeg", Vector3.new(0.5, 7, 0.5), CFrame.new(tank + Vector3.new(o[1], 3.5, o[2])), hex("4E4F55"), M.Metal)
	end
	cyl(m, "WaterTank", 3.6, 5.5, CFrame.new(tank + Vector3.new(0, 9.5, 0)), hex("6A4B38"), M.Wood)
	mk(m, "TankRoof", Vector3.new(7.8, 1.2, 7.8), CFrame.new(tank + Vector3.new(0, 13, 0)), hex("4E4F55"), M.Metal)
	local ap = Vector3.new(math.cos(0.9) * (outerR + 4), 0, math.sin(0.9) * (outerR + 4))
	cyl(m, "Antenna", 0.2, 26, CFrame.new(ap + Vector3.new(0, 13, 0)), hex("55585F"), M.Metal)
	local beacon = ball(m, "AntennaLight", Vector3.one * 1.1, CFrame.new(ap + Vector3.new(0, 26.4, 0)), hex("FF3030"), M.Neon, false)
	light(beacon, hex("FF3030"), 30, 1)
	-- สายไฟประดับ (เสา + หลอดไฟ) ห่างกันราว 30 สตั๊ด
	local pr = outerR - 6.5
	local nP = nseg(pr, 30, 8)
	for i = 0, nP - 1 do
		local a = i / nP * TAU
		local pp = Vector3.new(math.cos(a) * pr, 0, math.sin(a) * pr)
		cyl(m, "StringPole", 0.2, 11, CFrame.new(pp + Vector3.new(0, 5.5, 0)), hex("3A3C42"), M.Metal)
		local bulb = ball(m, "Bulb", Vector3.one * 1.1, CFrame.new(pp + Vector3.new(0, 11.4, 0)), hex("FFE2A0"), M.Neon, false)
		light(bulb, hex("FFD08A"), 36, 1.2)
		local a2 = (i + 1) / nP * TAU
		for k = 1, 4 do
			local t = k / 5
			local mid = pp:Lerp(Vector3.new(math.cos(a2) * pr, 0, math.sin(a2) * pr), t)
			ball(m, "Bulb", Vector3.one * 0.6, CFrame.new(mid + Vector3.new(0, 10.6 + math.sin(t * math.pi) * 0.8, 0)), hex("FFE2A0"), M.Neon, false)
		end
	end
	-- ฉากเมืองไกลๆ
	local lo, hi = outerR + 28, math.max(300, outerR + 150)
	cyl(m, "StreetBelow", hi + 120, 2, CFrame.new(0, -140, 0), hex("1B1C21"), M.Asphalt, false)
	for i = 0, 55 + math.floor((R - 30) * 0.4) do
		local a = rng:NextNumber(0, TAU)
		local dist = rng:NextNumber(lo, hi)
		local w, d = rng:NextNumber(14, 34), rng:NextNumber(14, 34)
		local top = rng:NextNumber(-20, 85) + (dist / hi) * 40
		local height = top + 140
		local pos = Vector3.new(math.cos(a) * dist, top - height / 2, math.sin(a) * dist)
		local cf = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
		mk(m, "Tower", Vector3.new(w, height, d), cf, Color3.fromHSV(0.6, 0.18, rng:NextNumber(0.1, 0.22)), M.Concrete, false)
		mk(m, "TowerCap", Vector3.new(w * 0.6, 2.4, d * 0.6), cf * CFrame.new(0, height / 2 + 1.2, 0), hex("26282E"), M.Concrete, false)
		for r = 1, 6 do
			if rng:NextNumber() < 0.8 then
				local wc = if rng:NextNumber() < 0.7 then hex("FFD98A") else hex("9FE3FF")
				mk(m, "Windows", Vector3.new(w * 0.82, 1.2, 0.2), cf * CFrame.new(0, height / 2 - 4 - r * rng:NextNumber(3, 9), -d / 2 - 0.1), wc, M.Neon, false).Transparency = 0.35
			end
		end
		if i % 7 == 0 then
			local col = if i % 2 == 0 then hex("FF2E88") else hex("27E1FF")
			local bb = mk(m, "TowerSign", Vector3.new(w * 0.7, 6, 0.4), cf * CFrame.new(0, height / 2 - 12, -d / 2 - 0.3), hex("0B0C0F"), M.SmoothPlastic, false)
			face(bb, ({ "SUSU", "ラーメン", "カラオケ", "闘" })[i % 4 + 1], col, Enum.Font.SourceSansBold)
			light(bb, col, 40, 1)
		end
		if height > 120 and i % 3 == 0 then
			ball(m, "RedLight", Vector3.one * 1.6, cf * CFrame.new(0, height / 2 + 3, 0), hex("FF3030"), M.Neon, false)
		end
	end
	local bw, bh = boardSize(R)
	for k = 0, 3 do
		scoreBoard(m, k * math.pi / 2, outerR + 1.6, 18, bw, bh, YEL, 0, 18)
	end
	markSpawns(markers, R, seats, outerR + 1)
	finish(m)
	return m
end

local builders: { [string]: (number) -> Model } = { NeonRing = buildNeon, GreekSand = buildGreek, Rooftop = buildRooftop }

function Kit.BuildTemplate(theme: string, R: number?): Model?
	local b = builders[theme]
	return b and b(math.clamp(R or Kit.MIN_R, Kit.MIN_R, Kit.MAX_R))
end

return Kit
