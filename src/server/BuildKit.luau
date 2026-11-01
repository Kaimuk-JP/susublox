--!strict
-- ชุดตัวช่วยสร้างฉากจากชิ้นส่วน ใช้โดย WorldBuilder (ต้นไม้ อาคาร ถนน ป้าย ไฟ ฯลฯ)
local BK = {}

BK.rng = Random.new(1234)

-- ไม่ระบุวัสดุ = เลือกจากสี (น้ำตาล = ไม้, อื่น ๆ = คอนกรีต) ไม่ใช้ SmoothPlastic แบบของเล่น
local function autoMaterial(c: Color3): Enum.Material
	local h, sat, v = c:ToHSV()
	if sat > 0.22 and (h < 0.12 or h > 0.97) and v < 0.7 and v > 0.2 then
		return Enum.Material.Wood
	end
	return Enum.Material.Concrete
end

function BK.part(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or autoMaterial(color)
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
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	return p
end

local hex = Color3.fromHex

-- ป้ายตัวอักษรญี่ปุ่น: ใช้ฟอนต์ที่มีอักษรจีน-ญี่ปุ่น (GothamBold ไม่มี จึงถูกแทนที่ด้วยฟอนต์สำรองตัวเล็กเพี้ยน)
function BK.jpFont(p: Part)
	local gui = p:FindFirstChildWhichIsA("SurfaceGui")
	local label = gui and gui:FindFirstChildWhichIsA("TextLabel")
	if gui and label then
		label.Font = Enum.Font.SourceSansBold
		gui.LightInfluence = 0.25 -- ฝั่งเงาอ่านออก
		gui.Brightness = 1.4
	end
end

local function jitter(c: Color3, amt: number): Color3
	local h, sat, v = c:ToHSV()
	return Color3.fromHSV(h, math.clamp(sat + BK.rng:NextNumber(-amt, amt), 0, 1), math.clamp(v + BK.rng:NextNumber(-amt, amt), 0, 1))
end
BK.jitter = jitter

---------------------------------------------------------------- ป้ายร้านญี่ปุ่น: ป้ายตั้งแนวตั้ง โคมแดง ผ้านอเรน ไฟลายแถบร้านสะดวกซื้อ ป้ายปาจิงโกะกะพริบ
-- ชนิดร้าน -> ข้อความ (ญี่ปุ่นเป็นหลัก + อังกฤษตัวเล็ก) สีไฟป้ายโทนอุ่น ไม่ใช้โลโก้/เครื่องหมายการค้าจริง
BK.SHOPS = {
	ramen = { jp = "ラーメン", en = "RAMEN", fg = "F0B24A" },
	izakaya = { jp = "居酒屋", en = "IZAKAYA", fg = "E8643C" },
	pharmacy = { jp = "薬局", en = "PHARMACY", fg = "7FD1A0" },
	konbini = { jp = "コンビニ", en = "24H", fg = "F2F0E6" },
	books = { jp = "書店", en = "BOOKS", fg = "E6C27A" },
	game = { jp = "ゲーム", en = "GAME", fg = "E0707A" },
	pachinko = { jp = "パチンコ", en = "PACHINKO", fg = "F0D060" },
	karaoke = { jp = "カラオケ", en = "KARAOKE", fg = "D98AB0" },
	kissaten = { jp = "喫茶", en = "COFFEE", fg = "D8A36A" },
}

local function glowGui(p: BasePart, face: Enum.NormalId, text: string, color: Color3, pps: number): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Parent = gui
	return label
end

-- ป้ายตั้งแนวตั้งยื่นออกจากผนัง (อ่านจากริมถนนทั้งสองทิศ) ตัวอักษรเรียงบนลงล่าง
function BK.verticalSign(parent: Instance, jp: string, en: string, pos: Vector3, height: number, fg: Color3)
	local chars = {}
	for _, cp in utf8.codes(jp) do
		table.insert(chars, utf8.char(cp))
	end
	local p = BK.part("VerticalSign", Vector3.new(0.5, height, 2.4), pos, Color3.fromHex("1C1D21"), parent, Enum.Material.Metal)
	BK.noCollide(p)
	glowGui(p, Enum.NormalId.Right, table.concat(chars, "\n"), fg, 50)
	glowGui(p, Enum.NormalId.Left, table.concat(chars, "\n"), fg, 50)
	local rim = BK.part("VerticalSignRim", Vector3.new(0.35, height + 0.3, 2.7), pos, fg:Lerp(Color3.new(0, 0, 0), 0.55), parent, Enum.Material.Neon)
	BK.noCollide(rim)
	BK.light(p, fg, 14, 0.5)
	local enPart = BK.part("VerticalSignEn", Vector3.new(0.5, 0.9, 2.4), pos - Vector3.new(0, height / 2 + 0.55, 0), Color3.fromHex("1C1D21"), parent, Enum.Material.Metal)
	BK.noCollide(enPart)
	glowGui(enPart, Enum.NormalId.Right, en, fg, 40)
	glowGui(enPart, Enum.NormalId.Left, en, fg, 40)
end

-- โคมแดงห้อยหน้าร้าน (chochin) เรียง n ใบตามแกน x
function BK.chochin(parent: Instance, x: number, y: number, z: number, n: number, spacing: number)
	for i = 0, n - 1 do
		local lx = x + (i - (n - 1) / 2) * spacing
		BK.noCollide(BK.cylinder("ChochinCord", 0.05, 0.8, Vector3.new(lx, y + 0.5, z), Color3.fromHex("1C1D21"), parent, Enum.Material.Metal))
		local lamp = BK.cylinder("Chochin", 0.75, 1.7, Vector3.new(lx, y - 0.5, z), Color3.fromHex("B03A2E"), parent, Enum.Material.Neon)
		lamp.Transparency = 0.1
		BK.noCollide(lamp)
		for _, dy in { 0.88, -0.88 } do
			BK.noCollide(BK.cylinder("ChochinCap", 0.6, 0.18, Vector3.new(lx, y - 0.5 + dy, z), Color3.fromHex("15161A"), parent, Enum.Material.Metal))
		end
		if i == math.floor((n - 1) / 2) then
			BK.light(lamp, Color3.fromHex("FF8A4A"), 14, 0.7)
		end
	end
end

-- ผ้านอเรน (ผ้าแขวนหน้าประตูแบ่งเป็นแถบ)
function BK.noren(parent: Instance, cx: number, y: number, z: number, width: number, color: Color3)
	BK.box("NorenBar", cx - width / 2 - 0.2, cx + width / 2 + 0.2, y, y + 0.2, z - 0.15, z + 0.15, Color3.fromHex("3A2A20"), parent, Enum.Material.Wood)
	local strips = 4
	local sw = width / strips
	for i = 0, strips - 1 do
		local sx = cx - width / 2 + i * sw
		BK.noCollide(BK.box("Noren", sx + 0.06, sx + sw - 0.06, y - 2.2, y, z - 0.08, z + 0.08, color, parent, Enum.Material.Fabric))
		BK.noCollide(BK.box("NorenMark", sx + sw * 0.3, sx + sw * 0.7, y - 1.4, y - 0.7, z - 0.1, z + 0.1, Color3.fromHex("E4E0D6"), parent, Enum.Material.Fabric))
	end
end

-- แถบไฟขาว/เขียว/น้ำเงินหน้าร้านสะดวกซื้อ (แบบทั่วไป ไม่ลอกโลโก้ร้านจริง)
function BK.konbiniStripes(parent: Instance, cx: number, y: number, z: number, width: number)
	local cols = { Color3.fromHex("3E9A5B"), Color3.fromHex("F2F0E6"), Color3.fromHex("2F6FB5") }
	for i, c in cols do
		local y1 = y + (i - 1) * 0.55
		local bar = BK.box("KonbiniStripe", cx - width / 2, cx + width / 2, y1, y1 + 0.4, z - 0.15, z + 0.15, c, parent, Enum.Material.Neon)
		BK.noCollide(bar)
		if i == 2 then
			BK.light(bar, Color3.fromHex("F2F0E6"), 18, 0.8)
		end
	end
end

-- ป้ายปาจิงโกะ: ไฟล้อมกรอบกะพริบ (ลูปเดียวทั้งโลก สลับสีไฟทุก 0.4 วินาที)
local flashing: { BasePart } = {}
local flashStarted = false
local FLASH = { Color3.fromHex("F0D060"), Color3.fromHex("E0707A"), Color3.fromHex("7FD1E0") }
function BK.flashLights(parent: Instance, cx: number, y: number, z: number, width: number, height: number)
	local n = math.max(6, math.floor(width / 1.1))
	for i = 0, n do
		local t = i / n
		for _, yy in { y - height / 2, y + height / 2 } do
			local bx = cx - width / 2 + t * width
			local b = BK.box("PachinkoBulb", bx - 0.18, bx + 0.18, yy - 0.18, yy + 0.18, z - 0.18, z + 0.18, FLASH[1 + (i % 3)], parent, Enum.Material.Neon)
			BK.noCollide(b)
			b:SetAttribute("Phase", i)
			table.insert(flashing, b)
		end
	end
	if not flashStarted then
		flashStarted = true
		task.spawn(function()
			local tick = 0
			while true do
				task.wait(0.4)
				tick += 1
				for k = #flashing, 1, -1 do
					local b = flashing[k]
					if b.Parent == nil then
						table.remove(flashing, k)
					else
						local ph = (b:GetAttribute("Phase") :: number) + tick
						b.Color = FLASH[1 + (ph % 3)]
						b.Material = if ph % 2 == 0 then Enum.Material.Neon else Enum.Material.Metal
					end
				end
			end
		end)
	end
end

-- ติดป้ายตามชนิดร้าน: ป้ายหน้าร้านแนวนอน (ญี่ปุ่น + อังกฤษเล็ก) + ป้ายตั้ง + ของประกอบตามชนิด
function BK.shopFront(model: Instance, kind: string, cx: number, cz: number, w: number, d: number, y0: number, h: number, facing: number)
	local info = BK.SHOPS[kind]
	if not info then
		return
	end
	local fg = Color3.fromHex(info.fg)
	local dark = Color3.fromHex("1C1D21")
	local fz = cz + facing * (d / 2)
	local yaw = if facing == 1 then 180 else 0
	local sw = math.min(w - 4, 9)
	BK.sign(model, info.jp, Vector3.new(sw, 2.2, 0.35), Vector3.new(cx - 1, y0 + math.min(10, h - 1.8), fz + facing * 0.3), yaw, dark, fg).Material = Enum.Material.Metal
	BK.sign(model, info.en, Vector3.new(sw, 0.9, 0.3), Vector3.new(cx - 1, y0 + math.min(8.6, h - 3.2), fz + facing * 0.3), yaw, dark, fg).Material = Enum.Material.Metal
	local hv = math.min(7, (utf8.len(info.jp) :: number) * 1.4 + 1, h - 6)
	if hv >= 3 then
		BK.verticalSign(model, info.jp, info.en, Vector3.new(cx + w / 2 - 0.2, y0 + h - 2.2 - hv / 2, fz + facing * 1.4), hv, fg)
	end
	if kind == "izakaya" or kind == "ramen" then
		BK.chochin(model, cx - 1.5, y0 + 6.6, fz + facing * 1.6, 3, 3)
		BK.noren(model, cx + w / 2 - 2.7, y0 + 5.9, fz + facing * 0.4, 3, if kind == "izakaya" then Color3.fromHex("1E2A44") else Color3.fromHex("7A2E2A"))
	elseif kind == "konbini" then
		BK.konbiniStripes(model, cx, y0 + 6.9, fz + facing * 0.35, w - 2)
	elseif kind == "pachinko" then
		BK.flashLights(model, cx - 1, y0 + math.min(10, h - 1.8), fz + facing * 0.55, sw + 0.8, 2.6)
	elseif kind == "kissaten" or kind == "karaoke" then
		BK.chochin(model, cx - 1.5, y0 + 6.6, fz + facing * 1.6, 2, 3.5)
	end
end

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

local PINE_TREES = { "Tree_Pine1", "Tree_Pine2", "Tree_Pine3" }
-- Tree_Sakura1 ตรวจแล้วใบออกสีเขียว ไม่ใช้เป็นซากุระ
local SAKURA_TREES = { "Tree_Sakura2", "Tree_Sakura3", "Tree_SakuraPark" }

function BK.pine(parent: Instance, x: number, z: number, h: number)
	if BK.importedTree(parent, x, z, h / 12, PINE_TREES, h * 0.55) then
		return
	end
	local bark = jitter(hex("6B4E3B"), 0.04)
	BK.cylinder("PineTrunk", h * 0.045 + 0.35, h * 0.5, Vector3.new(x, h * 0.25, z), bark, parent, Enum.Material.Wood)
	local green = jitter(hex("35603B"), 0.05)
	for i = 0, 4 do
		local d = h * 0.46 * (1 - i * 0.18)
		BK.blob(parent, Vector3.new(x, h * 0.22 + i * h * 0.15 + d * 0.2, z), d, jitter(green, 0.03))
	end
	BK.blob(parent, Vector3.new(x, h * 0.98, z), h * 0.12, jitter(green, 0.03))
end

-- ต้นไม้จริงที่นำเข้าและตรวจแล้ว (ServerStorage.ImportedAssets.Trees) ข้อตกลง: Pivot = โคนต้นที่พื้น สูงราว 12 studs ไม่มีสคริปต์
-- ถ้ามีจะใช้แทนต้นไม้ที่ประกอบจากก้อนกลม; ถ้าไม่มีก็ใช้แบบเดิม
function BK.importedTree(parent: Instance, x: number, z: number, scale: number, names: { string }?, maxCrown: number?): boolean
	local assets = game:GetService("ServerStorage"):FindFirstChild("ImportedAssets")
	local folder = assets and assets:FindFirstChild("Trees")
	local list = folder and folder:GetChildren() or {}
	if names and folder then
		list = {}
		for _, n in names do
			local c = folder:FindFirstChild(n)
			if c then
				table.insert(list, c)
			end
		end
	end
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
	-- ปรับตามขนาดจริงของโมเดล (ไม่เชื่อว่าสูง 12 studs): เป้าหมายสูง 12*scale และเรือนยอดกว้างไม่เกิน maxCrown
	local _, size = model:GetBoundingBox()
	local factor = (12 * math.max(0.5, scale) * BK.rng:NextNumber(0.9, 1.1)) / math.max(size.Y, 0.1)
	if maxCrown then
		factor = math.min(factor, maxCrown / math.max(size.X, size.Z, 0.1))
	end
	model:ScaleTo(model:GetScale() * factor)
	model:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, BK.rng:NextNumber(0, 6.28), 0))
	model.Parent = parent
	return true
end

-- ต้นไม้สำรองเมื่อไม่มีโมเดลนำเข้า: ลำต้นเรียว กิ่งหลายแขนง ใบเป็นกระจุกเล็กๆ กระจายไม่สมมาตร (ไม่เป็นลูกบอลใหญ่)
function BK.roundTree(parent: Instance, x: number, z: number, scale: number, leaf: Color3?, names: { string }?, maxCrown: number?)
	if BK.importedTree(parent, x, z, scale, names, maxCrown) then
		return
	end
	local s = math.min(scale, 1.1)
	local bark = jitter(hex("5E4A3A"), 0.04)
	local h = 9 * s
	BK.cylinder("TrunkBase", 0.9 * s, 1.2 * s, Vector3.new(x, 0.6 * s, z), bark, parent, Enum.Material.Wood)
	local top = Vector3.new(x + BK.rng:NextNumber(-0.5, 0.5) * s, h * 0.8, z + BK.rng:NextNumber(-0.5, 0.5) * s)
	BK.branch(parent, Vector3.new(x, 0.8 * s, z), top, 0.4 * s, bark)
	-- ใบสีเขียวธรรมชาติ: บังคับ hue ช่วงเขียว-เหลืองเขียว ไม่ให้ส้ม/น้ำตาล
	local base = leaf or hex("587A3E")
	local hh, ss, vv = base:ToHSV()
	if hh < 0.17 or hh > 0.45 then
		base = Color3.fromHSV(0.25, 0.42, math.max(vv, 0.45))
	else
		base = Color3.fromHSV(hh, math.min(ss, 0.55), vv)
	end
	local arms = BK.rng:NextInteger(4, 6)
	for i = 1, arms do
		local a = i / arms * 6.28 + BK.rng:NextNumber(-0.4, 0.4)
		local y0 = h * BK.rng:NextNumber(0.5, 0.72)
		local reach = BK.rng:NextNumber(1.8, 3.2) * s
		local tip = Vector3.new(x + math.cos(a) * reach, y0 + BK.rng:NextNumber(0.8, 2.2) * s, z + math.sin(a) * reach)
		BK.branch(parent, Vector3.new(x, y0 - 1.2 * s, z), tip, 0.16 * s, bark)
		for _ = 1, 4 do
			local o = Vector3.new(BK.rng:NextNumber(-1.1, 1.1), BK.rng:NextNumber(-0.7, 1.2), BK.rng:NextNumber(-1.1, 1.1)) * s
			BK.blob(parent, tip + o, BK.rng:NextNumber(1.5, 2.5) * s, jitter(base, 0.08))
		end
	end
	for _ = 1, 5 do
		local o = Vector3.new(BK.rng:NextNumber(-1.2, 1.2), BK.rng:NextNumber(0.2, 2.4), BK.rng:NextNumber(-1.2, 1.2)) * s
		BK.blob(parent, top + o, BK.rng:NextNumber(1.6, 2.6) * s, jitter(base, 0.08))
	end
end

function BK.sakura(parent: Instance, x: number, z: number, scale: number)
	local s = math.min(scale, 1.3)
	local imported = BK.importedTree(parent, x, z, s * 1.1, SAKURA_TREES, 13)
	local center
	if not imported then
		local bark = jitter(hex("5E4A3A"), 0.03)
		BK.cylinder("TrunkBase", 1.0 * s, 1.0 * s, Vector3.new(x, 0.5 * s, z), bark, parent, Enum.Material.Wood)
		local lean = Vector3.new(BK.rng:NextNumber(-0.8, 0.8) * s, 0, BK.rng:NextNumber(-0.8, 0.8) * s)
		local fork = Vector3.new(x, 4.5 * s, z) + lean
		BK.branch(parent, Vector3.new(x, 0.8 * s, z), fork, 0.55 * s, bark)
		local crownC = fork + Vector3.new(0, 2 * s, 0)
		-- กระจุกดอกเล็กๆ หลายก้อนบนกิ่งแยก ไม่ใช่ลูกบอลใหญ่
		local pinks = { hex("F0B8C8"), hex("E8A7BB"), hex("F6CAD6"), hex("DE9AB0") }
		for i = 1, 8 do
			local a = i / 8 * 6.28 + BK.rng:NextNumber(-0.4, 0.4)
			local r = BK.rng:NextNumber(2.2, 3.6) * s
			local tip = crownC + Vector3.new(math.cos(a) * r, BK.rng:NextNumber(-0.8, 1.6) * s, math.sin(a) * r)
			BK.branch(parent, fork, tip, 0.2 * s, bark)
			for _ = 1, 10 do
				local o = Vector3.new(BK.rng:NextNumber(-1.6, 1.6), BK.rng:NextNumber(-1.0, 1.4), BK.rng:NextNumber(-1.6, 1.6)) * s
				local b = BK.blob(parent, tip + o, BK.rng:NextNumber(0.7, 1.3) * s, jitter(pinks[BK.rng:NextInteger(1, 4)], 0.03), Enum.Material.SmoothPlastic)
				center = center or b
			end
		end
	end
	if not center then
		center = Instance.new("Part")
		center.Name = "PetalAnchor"
		center.Size = Vector3.one
		center.Transparency = 1
		center.Anchored = true
		center.CanCollide = false
		center.CanQuery = false
		center.Position = Vector3.new(x, 9 * s, z)
		center.Parent = parent
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(hex("D9AEB6"), hex("E6C8CE"))
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
	local base = color or hex("486F3C")
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
	local base = BK.blob(parent, Vector3.new(x, 0.4, z), radius * 1.8, hex("56803F"))
	base.Size = Vector3.new(radius * 1.8, 0.8, radius * 1.8)
	for _ = 1, 7 do
		local a, r = BK.rng:NextNumber(0, 6.28), BK.rng:NextNumber(0, radius)
		local fx, fz = x + math.cos(a) * r, z + math.sin(a) * r
		BK.cylinder("Stem", 0.06, 1, Vector3.new(fx, 0.9, fz), hex("3E7D3E"), parent)
		BK.ball("Flower", 0.7, Vector3.new(fx, 1.5, fz), jitter(color, 0.04), parent)
	end
end

-- ความสูงชั้น (stud): 1 stud ~0.35 m, ชั้นจริง ~2.9 m = ~8.3 stud
local SH = 8

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
		BK.noCollide(piece("Headlight", Vector3.new(0.9, 0.45, 0.2), Vector3.new(sx * 1.4, 1.9, -4.55), hex("F0D9A0"), Enum.Material.Neon))
		BK.noCollide(piece("Taillight", Vector3.new(0.9, 0.4, 0.2), Vector3.new(sx * 1.4, 1.9, 4.55), hex("A8352C"), Enum.Material.Neon))
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
		piece(Vector3.new(0.3, 1.6, 1.5), Vector3.new(sx, 0.8, 0), hex("2A2C32"), Enum.Material.Metal)
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
	BK.cylinder("PoleBase", 0.7, 0.8, Vector3.new(x, 0.4, z), hex("34363C"), parent, Enum.Material.Metal)
	BK.cylinder("Pole", 0.3, 15.4, Vector3.new(x, 8.1, z), hex("2A2C32"), parent, Enum.Material.Metal)
	BK.box("LampArm", x - 0.15, x + 0.15, 15.6, 15.9, z - 1.4, z + 0.2, hex("2A2C32"), parent, Enum.Material.Metal)
	BK.box("LampHousing", x - 0.7, x + 0.7, 15.3, 15.7, z - 2.1, z - 0.7, hex("34363C"), parent, Enum.Material.Metal)
	local bulb = BK.box("Bulb", x - 0.5, x + 0.5, 15.15, 15.3, z - 1.9, z - 0.9, glow, parent, Enum.Material.Neon)
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
	local wallMat: Enum.Material = o.Material
	if not wallMat then
		local r = BK.rng:NextNumber()
		wallMat = if r < 0.45 then Enum.Material.Plaster elseif r < 0.8 or h > 18 then Enum.Material.Concrete else Enum.Material.Brick
	end
	BK.box("Walls", cx - w / 2, cx + w / 2, y0, y0 + h, cz - d / 2, cz + d / 2, wall, model, wallMat)
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
		local floors = math.max(1, math.floor((h - 3) / SH))
		for r = 1, floors - 1 do
			local by = y0 + r * SH + 1.5
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
			BK.box("RoofVent", vx - 1.2, vx + 1.2, py, py + 1.8, vz - 1.2, vz + 1.2, hex("70747A"), model, Enum.Material.Metal)
		end
		if h > 14 and BK.rng:NextNumber() > 0.45 then
			local tx = cx + BK.rng:NextNumber(-w / 4, w / 4)
			local tz = cz + BK.rng:NextNumber(-d / 4, d / 4)
			for _, lx in { -1.4, 1.4 } do
				for _, lz in { -1.4, 1.4 } do
					BK.cylinder("TankLeg", 0.18, 2, Vector3.new(tx + lx, py + 1, tz + lz), hex("44464D"), model, Enum.Material.Metal)
				end
			end
			BK.cylinder("WaterTank", 2.2, 3.6, Vector3.new(tx, py + 3.8, tz), hex("8E6F55"), model, Enum.Material.Wood)
			BK.cylinder("TankCap", 2.3, 0.4, Vector3.new(tx, py + 5.8, tz), hex("44464D"), model, Enum.Material.Metal)
		end
		if h > 20 then
			BK.cylinder("Antenna", 0.12, 7, Vector3.new(cx + BK.rng:NextNumber(-w / 3, w / 3), py + 3.5, cz + BK.rng:NextNumber(-d / 3, d / 3)), hex("2A2C32"), model, Enum.Material.Metal)
		end
		-- เครื่องปรับอากาศใต้หน้าต่างบางบาน
		local acRows = math.max(1, math.floor((h - 3) / SH))
		for r = 0, acRows - 1 do
			if BK.rng:NextNumber() > 0.55 then
				local ax = cx + BK.rng:NextNumber(-w / 2 + 4, w / 2 - 4)
				local side = if BK.rng:NextNumber() > 0.5 then 1 else -1
				local ay = y0 + 3.6 + r * SH
				BK.box("AirCon", ax - 1.4, ax + 1.4, ay, ay + 1.6, math.min(cz + side * (d / 2), cz + side * (d / 2 + 1.1)), math.max(cz + side * (d / 2), cz + side * (d / 2 + 1.1)), hex("B8BABA"), model, Enum.Material.Metal)
			end
		end
		for _, sx in { -1, 1 } do
			BK.cylinder("Drainpipe", 0.25, h - 1, Vector3.new(cx + sx * (w / 2 - 1.2), y0 + h / 2, cz - facing * (d / 2 + 0.35)), hex("6B7280"), model, Enum.Material.Metal)
		end
		if h > 16 and BK.rng:NextNumber() > 0.4 then
			local by = y0 + 3.6 + SH
			local fz = cz + facing * (d / 2)
			BK.box("Balcony", cx - 5, cx + 5, by, by + 0.4, math.min(fz, fz + facing * 2.2), math.max(fz, fz + facing * 2.2), hex("A5A7A8"), model, Enum.Material.Concrete)
			BK.box("BalconyRail", cx - 5, cx + 5, by + 0.4, by + 1.6, math.min(fz + facing * 2, fz + facing * 2.2), math.max(fz + facing * 2, fz + facing * 2.2), hex("2A2C32"), model, Enum.Material.Metal)
		end
	end
	if o.Windows ~= false then
		local cols = math.max(1, math.floor((w - 3) / 8))
		local rows = math.max(1, math.floor((h - 3) / SH))
		local glass = o.GlassColor or hex("6F8C9C")
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
			local wy = y0 + 5.4 + r * SH
			if wy + 2.4 < y0 + h - 0.9 then
				for c = 0, cols - 1 do
					local wx = cx - w / 2 + (c + 0.5) * (w / cols)
					for _, side in { -1, 1 } do
						if o.Storefront and side == facing then
							continue
						end
						pane(Vector3.new(4.6, 4.0, 0.2), Vector3.new(wx, wy, cz + side * (d / 2 + 0.05)), BK.rng:NextNumber() < 0.16)
					end
				end
				local sideCols = math.max(1, math.floor((d - 3) / 8))
				for c = 0, sideCols - 1 do
					local wz = cz - d / 2 + (c + 0.5) * (d / sideCols)
					for _, side in { -1, 1 } do
						pane(Vector3.new(0.2, 4.0, 4.6), Vector3.new(cx + side * (w / 2 + 0.05), wy, wz), BK.rng:NextNumber() < 0.16)
					end
				end
			end
		end
		if o.Storefront then
			-- หน้าร้านชั้นล่าง: กระจกบานใหญ่ + ประตู + เสาคั่น
			local fz = cz + facing * (d / 2 + 0.06)
			local g = BK.part("ShopGlass", Vector3.new(w - 5, 4.6, 0.2), Vector3.new(cx - 1.5, y0 + 3.5, fz), hex("5F7F96"), model, Enum.Material.Glass)
			g.Transparency = 0.35
			g.CanCollide = false
			BK.box("ShopDoor", cx + w / 2 - 4.6, cx + w / 2 - 1.4, y0 + 0.3, y0 + 6.8, fz - 0.15 * facing - 0.15, fz + 0.15, hex("5A4636"), model, Enum.Material.Wood)
			-- ม้วนชัตเตอร์เหล็กลูกฟูกปิดครึ่งหน้าร้านบางร้าน (ร้านปิดแล้ว)
			if BK.rng:NextNumber() < 0.4 then
				local sx1 = cx - w / 2 + 2.5
				BK.box("ShutterDoor", sx1, sx1 + (w - 5) * 0.55, y0 + 0.3, y0 + 6.4, fz - 0.05 * facing - 0.2, fz + 0.2, hex("7C8084"), model, Enum.Material.Metal)
				BK.box("ShutterBox", sx1 - 0.2, sx1 + (w - 5) * 0.55 + 0.2, y0 + 6.4, y0 + 7.0, fz - 0.3, fz + 0.3, hex("5A5D62"), model, Enum.Material.Metal)
			end
			for i = 0, 2 do
				BK.box("ShopMullion", cx - w / 2 + 2.5 + i * ((w - 5) / 2) - 0.2, cx - w / 2 + 2.5 + i * ((w - 5) / 2) + 0.2, y0 + 1.2, y0 + 5.8, fz - 0.2, fz + 0.2, trim, model, Enum.Material.Concrete)
			end
		end
	end
	if o.Kind then
		BK.shopFront(model, o.Kind, cx, cz, w, d, y0, h, facing)
	elseif o.SignText then
		-- ป้ายหันไปทางถนน (o.Facing = +1 หัน +Z, -1 หัน -Z)
		BK.sign(model, o.SignText, Vector3.new(math.min(w - 2, 12), 2.6, 0.4), Vector3.new(cx, y0 + math.min(9.8, h - 1.6), cz + facing * (d / 2 + 0.3)), if facing == 1 then 180 else 0, o.SignBg or hex("2A2C32"), o.SignFg or hex("FFE066"))
	end
	if o.Awning then
		local aw = BK.box("Awning", cx - w / 2 + 0.5, cx + w / 2 - 0.5, y0 + 7.4, y0 + 7.9, cz + facing * (d / 2), cz + facing * (d / 2 + 4.5), o.Awning :: Color3, model, Enum.Material.Fabric)
		aw.Name = "Awning"
	end
	return model
end

-- ถนนแนวแกน: ลาดยางแอสฟัลต์ + เส้นกลางประ + ขอบทาง (เส้นขอบเลนอยู่ใน StreetScape)
function BK.road(parent: Instance, x1: number, z1: number, x2: number, z2: number, width: number)
	local ax1, ax2 = math.min(x1, x2), math.max(x1, x2)
	local az1, az2 = math.min(z1, z2), math.max(z1, z2)
	local horizontal = (ax2 - ax1) >= (az2 - az1)
	local asphalt = hex("3A3B3F")
	local curbColor = hex("9C9A94")
	if horizontal then
		BK.box("Road", ax1, ax2, 0, 0.3, az1 - width / 2, az1 + width / 2, asphalt, parent, Enum.Material.Asphalt)
		for _, side in { -1, 1 } do
			BK.box("Curb", ax1, ax2, 0, 0.55, az1 + side * (width / 2) - (if side == 1 then 0 else -0.4), az1 + side * (width / 2) + (if side == 1 then 0.4 else 0), curbColor, parent, Enum.Material.Concrete)
		end
		for x = ax1 + 6, ax2 - 6, 12 do
			BK.box("Dash", x, x + 5, 0.3, 0.34, az1 - 0.2, az1 + 0.2, hex("CDB454"), parent)
		end
	else
		BK.box("Road", ax1 - width / 2, ax1 + width / 2, 0, 0.3, az1, az2, asphalt, parent, Enum.Material.Asphalt)
		for _, side in { -1, 1 } do
			BK.box("Curb", ax1 + side * (width / 2) - (if side == 1 then 0 else -0.4), ax1 + side * (width / 2) + (if side == 1 then 0.4 else 0), 0, 0.55, az1, az2, curbColor, parent, Enum.Material.Concrete)
		end
		for z = az1 + 6, az2 - 6, 12 do
			BK.box("Dash", ax1 - 0.2, ax1 + 0.2, 0.3, 0.34, z, z + 5, hex("CDB454"), parent)
		end
	end
end

-- ทางเท้า (ปูแผ่นคอนกรีต) แนวแกน
function BK.sidewalk(parent: Instance, x1: number, x2: number, z1: number, z2: number)
	BK.box("Sidewalk", math.min(x1, x2), math.max(x1, x2), 0, 0.45, math.min(z1, z2), math.max(z1, z2), hex("A9A59B"), parent, Enum.Material.Concrete)
end

-- ประตูโทริอิ (ไม้ทาแดง + ฐานหิน)
function BK.torii(parent: Instance, x: number, y: number, z: number, yaw: number, scale: number)
	local red = hex("A9372D")
	local model = Instance.new("Model")
	model.Name = "Torii"
	model.Parent = parent
	local function piece(size: Vector3, offset: Vector3, color: Color3, mat: Enum.Material?)
		local p = BK.part("ToriiPart", size * scale, Vector3.zero, color, model, mat or Enum.Material.Wood)
		p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(offset * scale)
	end
	for _, sx in { -5, 5 } do
		piece(Vector3.new(1.8, 1.2, 1.8), Vector3.new(sx, 0.6, 0), hex("555960"), Enum.Material.Slate)
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

---------------------------------------------------------------- ตึกแบบโตเกียว (ใช้กับล็อตจาก LotGen)
-- หลายยุคในบล็อกเดียว: wood (บ้านไม้เตี้ย) / postwar (คอนกรีตหลังสงคราม) / showa (กระเบื้อง-อิฐยุค 80 + ระเบียงแอร์) / modern (ผนังกระจก)
-- สร้างในแบบ "หน้าตึกหัน +Z" แล้วหมุนทั้งชุดรอบจุดกลางล็อตตาม lot.Yaw; ของที่ยื่นออกนอกผนัง (ระเบียง บันได แอร์) ไม่ชน
local ERA_WALL = {
	postwar = { "A9A59B", "B3AB9B", "9C9488", "A8A296", "98958C" },
	showa = { "A58A74", "B09A84", "9A7F6E", "BFA98F", "A89078" },
	modern = { "D2D4D4", "C5C9CC", "BCC3C8", "CFCBC2" },
	wood = { "C9BDA6", "B7A488", "BFB095", "AD9F86" },
}
local ROOF_COLORS = { "4A525C", "2A2C32", "70747A", "5B5D6B" }
local AWNING_COLORS = { "9E3B33", "3F566E", "7A5A50", "4F7358", "B8944A", "A8643A" }
local CLOTH = { "E4E0D6", "C98A97", "7FA0B8", "D8C27A", "9AB88A", "B0605A" }
local CONTAINER_COLORS = { "9E3B33", "3F566E", "B8944A", "4F7358", "A8643A", "7A6A9A", "8C8F93" }

local function noc(p: BasePart): BasePart
	p.CanCollide, p.CanTouch = false, false
	return p
end

-- หมุนทุกชิ้นใน model รอบแกน Y ผ่าน (cx, cz)
local function rotateModel(model: Instance, cx: number, cz: number, yaw: number)
	if yaw == 0 then
		return
	end
	local pivot = CFrame.new(cx, 0, cz)
	local rot = pivot * CFrame.Angles(0, math.rad(yaw), 0) * pivot:Inverse()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = rot * d.CFrame
		end
	end
end
BK.rotateModel = rotateModel

---------------------------------------------------------------- ท่าเรือ: ตู้คอนเทนเนอร์ / โฟล์คลิฟต์ / พาเลท / ถังน้ำมัน
-- 1 stud ~ 0.35 m: ตู้ 20ft = 17 x 7 x 7.4 stud (ยาว x กว้าง x สูง) ตู้ 40ft = 35
local CONTAINER_PAINT = { "8F4B3A", "A25A3E", "3D5E80", "2F4D6B", "4C6E58", "3F5F4C", "8E3A36", "A04440", "AEB0AB", "A58B4A" }
local CONTAINER_OWNER = { "SSLU", "SUSU", "KMTU", "NYKU", "TLLU" }
local CONTAINER_BRAND = { "SUSU LINE", "MARUKO", "KISO", "SUSU MARINE", "HAMA" }
local CONTAINER_H = 7.4

local function stencilGui(p: BasePart, face: Enum.NormalId, code: string, brand: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 14
	gui.MaxDistance = 110
	gui.Parent = p
	local c = Instance.new("TextLabel")
	c.BackgroundTransparency = 1
	c.Size = UDim2.fromScale(0.44, 0.1)
	c.Position = UDim2.fromScale(0.52, 0.05)
	c.Text = code
	c.TextColor3 = hex("ECE8DA")
	c.Font = Enum.Font.SourceSansBold
	c.TextScaled = true
	c.TextXAlignment = Enum.TextXAlignment.Right
	c.Parent = gui
	if brand then
		local b = Instance.new("TextLabel")
		b.BackgroundTransparency = 1
		b.Size = UDim2.fromScale(0.7, 0.3)
		b.Position = UDim2.fromScale(0.15, 0.4)
		b.Text = brand
		b.TextColor3 = hex("ECE8DA")
		b.Font = Enum.Font.SourceSansBold
		b.TextScaled = true
		b.Parent = gui
	end
end

-- ตู้คอนเทนเนอร์ 1 ใบ (สีหม่นสุ่ม ผนังลูกฟูก ประตูท้ายตู้ เลขรหัสสเตนซิล) rng ต้องเป็นของเราเอง ไม่ใช่ lotRng
function BK.container(parent: Instance, cx: number, y0: number, cz: number, alongX: boolean, len: number, rng: Random, stencil: boolean): Part
	local sx, sz = if alongX then len else 7, if alongX then 7 else len
	local h0, s0, v0 = hex(CONTAINER_PAINT[rng:NextInteger(1, #CONTAINER_PAINT)]):ToHSV()
	local col = Color3.fromHSV(h0, s0, math.clamp(v0 * rng:NextNumber(0.86, 1.08), 0, 1))
	local body = BK.box("Container", cx - sx / 2, cx + sx / 2, y0, y0 + CONTAINER_H, cz - sz / 2, cz + sz / 2, col, parent, Enum.Material.Metal)
	local sgn = if rng:NextNumber() < 0.5 then -1 else 1
	local dark = col:Lerp(Color3.new(0, 0, 0), 0.25)
	if alongX then
		local ex = cx + sgn * sx / 2
		BK.box("ContainerDoor", math.min(ex, ex + sgn * 0.2), math.max(ex, ex + sgn * 0.2), y0 + 0.4, y0 + CONTAINER_H - 0.4, cz - sz / 2 + 0.35, cz + sz / 2 - 0.35, dark, parent, Enum.Material.Metal)
	else
		local ez = cz + sgn * sz / 2
		BK.box("ContainerDoor", cx - sx / 2 + 0.35, cx + sx / 2 - 0.35, y0 + 0.4, y0 + CONTAINER_H - 0.4, math.min(ez, ez + sgn * 0.2), math.max(ez, ez + sgn * 0.2), dark, parent, Enum.Material.Metal)
	end
	if stencil then
		local code = string.format("%s %06d %d", CONTAINER_OWNER[rng:NextInteger(1, #CONTAINER_OWNER)], rng:NextInteger(100000, 999999), rng:NextInteger(0, 9))
		local brand = if rng:NextNumber() < 0.5 then CONTAINER_BRAND[rng:NextInteger(1, #CONTAINER_BRAND)] else nil
		if alongX then
			stencilGui(body, Enum.NormalId.Front, code, brand)
			stencilGui(body, Enum.NormalId.Back, code, brand)
		else
			stencilGui(body, Enum.NormalId.Right, code, brand)
			stencilGui(body, Enum.NormalId.Left, code, brand)
		end
	end
	return body
end

-- ส่วนประกอบเล็กตามพิกัดท้องถิ่นของ origin (หน้า = +Z)
local function lpart(origin: CFrame, parent: Instance, name: string, size: Vector3, lp: Vector3, color: Color3, mat: Enum.Material?): Part
	local p = BK.part(name, size, origin.Position, color, parent, mat or Enum.Material.Metal)
	p.CFrame = origin * CFrame.new(lp)
	return p
end

-- พาเลทไม้ + ลังกระดาษ (วางตามแกน x ของ origin)
function BK.pallet(parent: Instance, origin: CFrame, loaded: boolean)
	lpart(origin, parent, "Pallet", Vector3.new(3.4, 0.5, 2.4), Vector3.new(0, 0.25, 0), hex("A9885A"), Enum.Material.WoodPlanks)
	if loaded then
		lpart(origin, parent, "Cartons", Vector3.new(3.1, 2.3, 2.1), Vector3.new(0, 1.65, 0), hex("B99B6B"), Enum.Material.Fabric)
		lpart(origin, parent, "Wrap", Vector3.new(3.15, 0.5, 2.15), Vector3.new(0, 2.0, 0), hex("D8D8D0"), Enum.Material.Fabric).Transparency = 0.35
	end
end

-- ถังน้ำมัน 200L (สูง ~2.6 stud)
function BK.drum(parent: Instance, x: number, z: number, y0: number, color: Color3)
	BK.cylinder("Drum", 0.8, 2.6, Vector3.new(x, y0 + 1.3, z), color, parent, Enum.Material.Metal)
	BK.cylinder("DrumRim", 0.84, 0.18, Vector3.new(x, y0 + 2.2, z), color:Lerp(Color3.new(0, 0, 0), 0.3), parent, Enum.Material.Metal)
end

-- โฟล์คลิฟต์ง่าย ๆ (ยาว ~8 กว้าง ~3.2 สูง ~6.4 stud) หน้า = +Z ของ origin
function BK.forklift(parent: Instance, origin: CFrame, body: Color3)
	local m = Instance.new("Folder")
	m.Name = "Forklift"
	m.Parent = parent
	local dark = hex("2A2C32")
	lpart(origin, m, "FLBody", Vector3.new(3.2, 2.0, 5.2), Vector3.new(0, 2.0, -0.6), body)
	lpart(origin, m, "FLWeight", Vector3.new(3.2, 2.6, 1.6), Vector3.new(0, 2.3, -3.2), body:Lerp(Color3.new(0, 0, 0), 0.2))
	lpart(origin, m, "FLSeat", Vector3.new(1.8, 0.7, 1.6), Vector3.new(0, 3.35, -1.2), dark, Enum.Material.Fabric)
	for _, sx in { -1.35, 1.35 } do
		for _, sz in { -2.4, 0.6 } do
			lpart(origin, m, "FLPost", Vector3.new(0.25, 3.2, 0.25), Vector3.new(sx, 4.6, sz), dark)
		end
		local w1 = lpart(origin, m, "FLWheel", Vector3.new(1.0, 1.9, 1.9), Vector3.new(sx * 1.05, 0.95, 1.1), dark, Enum.Material.Rubber)
		w1.Shape = Enum.PartType.Cylinder
		local w2 = lpart(origin, m, "FLWheel", Vector3.new(1.0, 1.6, 1.6), Vector3.new(sx * 1.05, 0.8, -2.3), dark, Enum.Material.Rubber)
		w2.Shape = Enum.PartType.Cylinder
	end
	lpart(origin, m, "FLRoof", Vector3.new(3.2, 0.25, 3.4), Vector3.new(0, 6.3, -0.9), dark)
	for _, sx in { -0.7, 0.7 } do
		lpart(origin, m, "FLMast", Vector3.new(0.35, 6.2, 0.35), Vector3.new(sx, 3.4, 2.6), hex("5E6168"))
		lpart(origin, m, "FLFork", Vector3.new(0.45, 0.35, 3.8), Vector3.new(sx * 1.1, 0.45, 4.2), hex("4A4C52"))
	end
	lpart(origin, m, "FLCarriage", Vector3.new(2.6, 1.6, 0.3), Vector3.new(0, 1.3, 2.9), hex("5E6168"))
end

local function exteriorStairs(model: Instance, cx: number, cz: number, w: number, d: number, h: number, rng: Random)
	local steel = hex("5E6168")
	local bz = cz - d / 2 - 1.3
	local x0 = cx + rng:NextNumber(-w / 2 + 3.5, w / 2 - 3.5)
	local floors = math.floor((h - 2) / SH)
	for f = 0, floors - 1 do
		local y = f * SH
		local dir = if f % 2 == 0 then 1 else -1
		local xa, xb = x0 - dir * 2.6, x0 + dir * 2.6
		local mid = Vector3.new((xa + xb) / 2, y + SH / 2, bz)
		local run = math.abs(xb - xa)
		local flight = noc(BK.part("StairFlight", Vector3.new(math.sqrt(run * run + SH * SH), 0.3, 2), mid, steel, model, Enum.Material.Metal))
		flight.CFrame = CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(SH, run) * dir)
		noc(BK.box("StairLanding", xb - 1.5, xb + 1.5, y + SH, y + SH + 0.3, bz - 1.2, bz + 1.2, steel, model, Enum.Material.Metal))
		noc(BK.box("StairRail", math.min(xa, xb), math.max(xa, xb), y + SH + 0.5, y + SH + 0.7, bz - 1.1, bz - 0.9, steel, model, Enum.Material.Metal))
	end
	noc(BK.box("StairDoor", x0 - 1.3, x0 + 1.3, 0.3, 6.6, cz - d / 2 - 0.2, cz - d / 2 + 0.1, hex("3A3D44"), model, Enum.Material.Metal))
end

local function balconies(model: Instance, cx: number, cz: number, w: number, d: number, h: number, rng: Random, modern: boolean)
	local fz = cz + d / 2
	local rows = math.floor((h - 3) / SH)
	for r = 1, rows - 1 do
		local y = 3.2 + r * SH
		if y + 3 < h then
			noc(BK.box("Balcony", cx - w / 2 + 1, cx + w / 2 - 1, y, y + 0.35, fz, fz + 1.7, hex("A5A7A8"), model, Enum.Material.Concrete))
			local rail = noc(BK.box("BalconyRail", cx - w / 2 + 1, cx + w / 2 - 1, y + 0.35, y + 1.5, fz + 1.55, fz + 1.7, if modern then hex("8FA3AB") else hex("D2CFC6"), model, if modern then Enum.Material.Glass else Enum.Material.Concrete))
			if modern then
				rail.Transparency = 0.5
			end
			local n = math.max(1, math.floor(w / 6))
			for k = 1, n do
				if rng:NextNumber() < 0.6 then
					local ax = cx - w / 2 + 1.5 + (k - 0.5) * ((w - 3) / n)
					noc(BK.box("BalconyAC", ax - 1.2, ax + 1.2, y + 0.35, y + 1.7, fz + 0.2, fz + 1.2, hex("B8BABA"), model, Enum.Material.Metal))
				elseif rng:NextNumber() < 0.5 then
					local ax = cx - w / 2 + 2 + rng:NextNumber(0, math.max(0.1, w - 5))
					noc(BK.box("Laundry", ax - 0.8, ax + 0.8, y + 0.9, y + 2.5, fz + 1.35, fz + 1.5, hex(CLOTH[rng:NextInteger(1, #CLOTH)]), model, Enum.Material.Fabric))
				end
			end
		end
	end
end

local function roofClutter(model: Instance, cx: number, cz: number, w: number, d: number, h: number, rng: Random)
	local py = h + 1.2 -- ยอดราวกันตก/แผ่นหลังคา
	if rng:NextNumber() < 0.6 then
		local px, pz = cx + rng:NextNumber(-w / 3, w / 3), cz + rng:NextNumber(-d / 3, d / 3)
		BK.box("StairHead", px - 1.6, px + 1.6, py - 0.6, py + 3, pz - 1.6, pz + 1.6, hex("A8A598"), model, Enum.Material.Concrete)
	end
	for _ = 1, rng:NextInteger(1, 3) do
		local px, pz = cx + rng:NextNumber(-w / 2 + 2.5, w / 2 - 2.5), cz + rng:NextNumber(-d / 2 + 2, d / 2 - 2)
		BK.box("RoofAC", px - 1.2, px + 1.2, py - 0.6, py + 1, pz - 1, pz + 1, hex("B8BABA"), model, Enum.Material.Metal)
	end
	if h < 30 and rng:NextNumber() < 0.35 then -- ราวตากผ้า
		local lz = cz + rng:NextNumber(-d / 4, d / 4)
		local x1, x2 = cx - math.min(w / 2 - 1.5, 4), cx + math.min(w / 2 - 1.5, 4)
		for _, x in { x1, x2 } do
			BK.cylinder("LaundryPole", 0.1, 3.4, Vector3.new(x, py + 1.1, lz), hex("8A8D91"), model, Enum.Material.Metal)
		end
		BK.box("LaundryLine", x1, x2, py + 2.7, py + 2.78, lz - 0.04, lz + 0.04, hex("2A2C32"), model)
		for k = 0, 3 do
			local x = x1 + 0.8 + k * ((x2 - x1 - 1.6) / 3)
			noc(BK.box("Cloth", x - 0.5, x + 0.5, py + 1.2, py + 2.7, lz - 0.05, lz + 0.05, hex(CLOTH[rng:NextInteger(1, #CLOTH)]), model, Enum.Material.Fabric))
		end
	end
	if rng:NextNumber() < 0.06 then -- ศาลเล็กบนดาดฟ้า
		local sx, sz = cx + rng:NextNumber(-w / 4, w / 4), cz + rng:NextNumber(-d / 4, d / 4)
		BK.box("RoofShrineBase", sx - 1, sx + 1, py - 0.6, py + 0.3, sz - 0.9, sz + 0.9, hex("8F8E88"), model, Enum.Material.Slate)
		BK.box("RoofShrine", sx - 0.8, sx + 0.8, py + 0.3, py + 2, sz - 0.7, sz + 0.7, hex("6F5236"), model, Enum.Material.Wood)
		BK.box("RoofShrineRoof", sx - 1.2, sx + 1.2, py + 2, py + 2.4, sz - 1, sz + 1, hex("9E3B33"), model)
	end
end

local function gableRoof(model: Instance, cx: number, cz: number, w: number, d: number, h: number, color: Color3)
	local rise = math.clamp(w * 0.22, 1.8, 3.2)
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "GableRoof"
		wedge.Anchored = true
		wedge.Size = Vector3.new(w / 2 + 0.9, rise, d + 1.8)
		wedge.Color = color
		wedge.Material = Enum.Material.Slate
		wedge.CFrame = CFrame.new(cx + side * (w / 4 + 0.45), h + 0.6 + rise / 2, cz) * (if side == -1 then CFrame.Angles(0, math.rad(180), 0) else CFrame.identity)
		wedge.Parent = model
	end
end

local function houseGround(model: Instance, cx: number, cz: number, w: number, d: number, rng: Random)
	local fz = cz + d / 2
	local dx = cx + rng:NextNumber(-w / 2 + 2, w / 2 - 2)
	noc(BK.box("Door", dx - 1.5, dx + 1.5, 0.3, 6.4, fz, fz + 0.25, hex("4A3A2E"), model, Enum.Material.Wood))
	noc(BK.box("DoorStep", dx - 1.8, dx + 1.8, 0, 0.35, fz, fz + 1.2, hex("8F8B83"), model, Enum.Material.Concrete))
	noc(BK.box("Mailbox", dx + 1.9, dx + 2.5, 3.8, 4.3, fz, fz + 0.4, hex("7A2E2A"), model, Enum.Material.Metal))
	for k = 1, rng:NextInteger(1, 3) do
		local px = cx - w / 2 + 1 + rng:NextNumber(0, math.max(0.1, w - 2))
		if math.abs(px - dx) > 1.8 then
			noc(BK.cylinder("BonsaiPot", 0.5, 0.9, Vector3.new(px, 0.45, fz + 0.7 + k * 0.1), hex("7A5A4A"), model, Enum.Material.Concrete))
			noc(BK.ball("Bonsai", 1.3, Vector3.new(px, 1.5, fz + 0.7 + k * 0.1), hex("55784B"), model, Enum.Material.Grass))
		end
	end
	if rng:NextNumber() < 0.35 then -- จักรยานพิงกำแพง
		local bx = cx + rng:NextNumber(-w / 2 + 1.5, w / 2 - 1.5)
		for _, o in { -1.6, 1.6 } do -- จักรยานยาว ~4.6 สูง ~3 (ล้อสูง 2.0 studs)
			local wheel = BK.cylinder("BikeWheel", 1.0, 0.14, Vector3.new(bx + o, 1.0, fz + 0.5), hex("2A2C32"), model, Enum.Material.Metal)
			wheel.CFrame = CFrame.new(bx + o, 1.0, fz + 0.5) * CFrame.Angles(0, math.rad(90), math.rad(90))
			noc(wheel)
		end
		noc(BK.box("BikeFrame", bx - 1.6, bx + 1.6, 1.6, 1.75, fz + 0.45, fz + 0.55, hex("4F7358"), model, Enum.Material.Metal))
	end
end

-- ลานตู้คอนเทนเนอร์ (ล็อตท่าเรือ): ตู้ 20ft ขนาดจริง กองซ้อน 1-3 ชั้น สีหม่นต่างกัน เลขรหัส รั้วลวดตาข่ายพร้อมประตู โฟล์คลิฟต์
-- ใช้ rng ของตัวเองสำหรับรายละเอียด แต่ดึงเลขจาก lotRng เท่าเดิมทุกครั้ง (ผังล็อตอื่นไม่เลื่อน)
local function containerYard(parent: Instance, lot: any, rng: Random)
	local model = Instance.new("Folder")
	model.Name = "Yard"
	model.Parent = parent
	do -- ดึงเลขตามอัลกอริทึมเดิม (ตู้ 11x5)
		local ax = lot.Yaw == 0 or lot.Yaw == 180
		local osx, osz = if ax then 11 else 5, if ax then 5 else 11
		local oc = math.max(1, math.floor((lot.Fx2 - lot.Fx1) / (osx + 1.5)))
		local orr = math.max(1, math.floor((lot.Fz2 - lot.Fz1) / (osz + 1.5)))
		for _ = 0, oc - 1 do
			for _ = 0, orr - 1 do
				if rng:NextNumber() < 0.8 then
					for _ = 0, rng:NextInteger(0, 2) do
						rng:NextInteger(1, #CONTAINER_COLORS)
					end
				end
			end
		end
	end
	local prng = Random.new(math.floor(lot.X * 31 + lot.Z * 17))
	local ex, ez = lot.Fx2 - lot.Fx1, lot.Fz2 - lot.Fz1
	local U = 17
	local alongX, cols, rows = true, 0, 0
	for _ = 1, 2 do
		local ca, ra = math.floor((ex - 0.6 + 1.0) / (U + 1.0)), math.floor((ez - 0.6 + 1.0) / 8)
		local cb, rb = math.floor((ex - 0.6 + 1.0) / 8), math.floor((ez - 0.6 + 1.0) / (U + 1.0))
		if ca * ra >= cb * rb then
			alongX, cols, rows = true, ca, ra
		else
			alongX, cols, rows = false, cb, rb
		end
		if cols * rows > 0 then
			break
		end
		U = 8.5 -- ล็อตแคบ: ตู้ 10ft
	end
	local emptyCell: Vector3? = nil
	for c = 0, cols - 1 do
		for r = 0, rows - 1 do
			local px = lot.Fx1 + (c + 0.5) * (ex / cols)
			local pz = lot.Fz1 + (r + 0.5) * (ez / rows)
			if prng:NextNumber() < 0.78 then
				local q = prng:NextNumber()
				local tiers = if q < 0.4 then 1 elseif q < 0.8 then 2 else 3
				for s = 0, tiers - 1 do
					BK.container(model, px, 0.1 + s * (CONTAINER_H + 0.05), pz, alongX, U, prng, true)
				end
			elseif not emptyCell then
				emptyCell = Vector3.new(px, 0, pz)
			end
		end
	end
	if emptyCell and prng:NextNumber() < 0.7 then
		BK.forklift(model, CFrame.new(emptyCell) * CFrame.Angles(0, math.rad(prng:NextInteger(0, 3) * 90 + prng:NextInteger(-12, 12)), 0), hex(if prng:NextNumber() < 0.5 then "C9722A" else "B8962E"))
		BK.pallet(model, CFrame.new(emptyCell + Vector3.new(0, 0, 6)) * CFrame.Angles(0, math.rad(90), 0), true)
	end
	-- รั้วลวดตาข่ายด้านหน้า (ด้านติดถนน) เว้นประตู 9 stud ตรงกลาง
	local yaw = lot.Yaw
	local fx1, fz1, fx2, fz2
	if yaw == 0 then
		fx1, fz1, fx2, fz2 = lot.Fx1, lot.Fz2 - 0.3, lot.Fx2, lot.Fz2 - 0.3
	elseif yaw == 180 then
		fx1, fz1, fx2, fz2 = lot.Fx1, lot.Fz1 + 0.3, lot.Fx2, lot.Fz1 + 0.3
	elseif yaw == 90 then
		fx1, fz1, fx2, fz2 = lot.Fx2 - 0.3, lot.Fz1, lot.Fx2 - 0.3, lot.Fz2
	else
		fx1, fz1, fx2, fz2 = lot.Fx1 + 0.3, lot.Fz1, lot.Fx1 + 0.3, lot.Fz2
	end
	local mx, mz = (fx1 + fx2) / 2, (fz1 + fz2) / 2
	local len = math.sqrt((fx2 - fx1) ^ 2 + (fz2 - fz1) ^ 2)
	if len > 14 then
		local ux, uz = (fx2 - fx1) / len, (fz2 - fz1) / len
		BK.fence(model, fx1, fz1, mx - ux * 4.5, mz - uz * 4.5, 6.5)
		BK.fence(model, mx + ux * 4.5, mz + uz * 4.5, fx2, fz2, 6.5)
		for _, s in { -1, 1 } do
			BK.cylinder("GatePost", 0.35, 7.5, Vector3.new(mx + s * ux * 4.5, 3.75, mz + s * uz * 4.5), hex("44464D"), model, Enum.Material.Metal)
		end
	end
	return model
end

---------------------------------------------------------------- โกดังท่าเรือ: ผนังเหล็กลูกฟูก ประตูม้วน ท่าขนของ หน้าต่างเล็ก ป้าย ปล่องหลังคา
-- ทำในพิกัดท้องถิ่น (หน้า = +Z) ก่อนหมุนตาม lot.Yaw; prng เป็นของเราเอง
local WH_ACCENT = { "3F566E", "4F7358", "9E3B33", "B8944A" }
local WH_DOOR = { "5C7A96", "6E8F6E", "A0584A", "B8B2A2", "C4A24F" }
local WH_KANJI = { "一", "二", "三", "四", "五", "六", "七", "八" }
local WH_EN = { "SUSU LOGISTICS", "SUSU MARINE", "SUSU CARGO", "KISO WAREHOUSE" }

local function warehouseDetail(model: Instance, cx: number, cz: number, w: number, d: number, h: number, prng: Random)
	for _, c in model:GetChildren() do
		local n = c.Name
		if n == "Window" or n == "WindowFrame" or n == "AirCon" or n == "RoofVent" or n == "WaterTank" or n == "TankLeg" or n == "TankCap" or n == "Antenna" or n == "Balcony" or n == "BalconyRail" or n == "Sign" or string.sub(n, 1, 7) == "Parapet" then
			c:Destroy()
		end
	end
	local walls = model:FindFirstChild("Walls") :: Part?
	if walls then
		walls.Material = Enum.Material.Metal
	end
	local accent = hex(WH_ACCENT[prng:NextInteger(1, #WH_ACCENT)])
	local doorCol = hex(WH_DOOR[prng:NextInteger(1, #WH_DOOR)])
	local steel = hex("5E6168")
	local z0 = cz + d / 2
	local x0 = cx - w / 2
	-- แถบสีรอบอาคาร
	local sy1, sy2 = h - 3.2, h - 2.5
	BK.box("WhStripe", x0 - 0.15, cx + w / 2 + 0.15, sy1, sy2, z0, z0 + 0.15, accent, model, Enum.Material.Metal)
	BK.box("WhStripe", x0 - 0.15, cx + w / 2 + 0.15, sy1, sy2, cz - d / 2 - 0.15, cz - d / 2, accent, model, Enum.Material.Metal)
	BK.box("WhStripe", x0 - 0.15, x0, sy1, sy2, cz - d / 2, z0, accent, model, Enum.Material.Metal)
	BK.box("WhStripe", cx + w / 2, cx + w / 2 + 0.15, sy1, sy2, cz - d / 2, z0, accent, model, Enum.Material.Metal)
	-- ซี่ลูกฟูกแนวนอนของผนังเหล็ก (เส้นเงาเข้มทุก 3.2 stud)
	local rib = walls and walls.Color:Lerp(Color3.new(0, 0, 0), 0.18) or hex("7A7E80")
	local by = 1.6
	while by < sy1 - 0.5 do
		BK.box("WhRib", x0 - 0.08, cx + w / 2 + 0.08, by, by + 0.35, z0, z0 + 0.08, rib, model, Enum.Material.Metal)
		BK.box("WhRib", x0 - 0.08, cx + w / 2 + 0.08, by, by + 0.35, cz - d / 2 - 0.08, cz - d / 2, rib, model, Enum.Material.Metal)
		BK.box("WhRib", x0 - 0.08, x0, by, by + 0.35, cz - d / 2, z0, rib, model, Enum.Material.Metal)
		BK.box("WhRib", cx + w / 2, cx + w / 2 + 0.08, by, by + 0.35, cz - d / 2, z0, rib, model, Enum.Material.Metal)
		by += 3.2
	end
	local occ: { { number } } = {}
	local function rollerDoor(xc: number, y0: number, width: number, height: number, label: string)
		BK.box("DoorFrame", xc - width / 2 - 0.4, xc + width / 2 + 0.4, y0 - 0.3, y0 + height + 0.5, z0, z0 + 0.2, hex("3A3D42"), model, Enum.Material.Metal)
		local door = BK.box("RollerDoor", xc - width / 2, xc + width / 2, y0, y0 + height, z0, z0 + 0.45, doorCol, model, Enum.Material.Metal)
		local sl = y0 + 1.5
		while sl < y0 + height - 0.6 do
			BK.box("DoorSlat", xc - width / 2, xc + width / 2, sl, sl + 0.18, z0 + 0.45, z0 + 0.52, doorCol:Lerp(Color3.new(0, 0, 0), 0.3), model, Enum.Material.Metal)
			sl += 1.5
		end
		BK.box("DoorHood", xc - width / 2 - 0.3, xc + width / 2 + 0.3, y0 + height, y0 + height + 0.9, z0, z0 + 0.7, hex("3A3D42"), model, Enum.Material.Metal)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.MaxDistance = 140
		gui.Parent = door
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.42, 0.34)
		t.Position = UDim2.fromScale(0.29, 0.1)
		t.Text = label
		t.TextColor3 = hex("F2F0E6")
		t.Font = Enum.Font.SourceSansBold
		t.TextScaled = true
		t.Parent = gui
		-- โคมไฟติดผนังเหนือประตู
		BK.box("WallLamp", xc - 0.6, xc + 0.6, y0 + height + 1.2, y0 + height + 1.8, z0, z0 + 0.9, hex("2A2C32"), model, Enum.Material.Metal)
		BK.box("WallLampGlass", xc - 0.45, xc + 0.45, y0 + height + 1.05, y0 + height + 1.2, z0 + 0.1, z0 + 0.8, hex("F2E4B0"), model, Enum.Material.Glass)
		table.insert(occ, { xc - width / 2 - 0.4, xc + width / 2 + 0.4 })
	end
	local doorH = math.min(8.6, h - 3.8)
	local bay = prng:NextInteger(1, 4)
	local gx = x0 + 2 + 4
	rollerDoor(gx, 0.3, 8, doorH, tostring(bay))
	BK.cylinder("Drum", 0.8, 2.6, Vector3.new(x0 + 0.95, 1.3, z0 + 0.95), hex(if prng:NextNumber() < 0.5 then "3F5F8A" else "9E3B33"), model, Enum.Material.Metal)
	if w >= 22 then
		-- ท่าขนของยกสูง + หลังคากันฝน + พาเลท
		local dx = cx + w / 2 - 6.5
		local dockH = math.min(6.5, h - 6.2)
		BK.box("LoadingDock", dx - 5.2, dx + 5.2, 0, 1.4, z0, z0 + 2.6, hex("9A9890"), model, Enum.Material.Concrete)
		BK.box("DockEdge", dx - 5.2, dx + 5.2, 1.4, 1.46, z0 + 2.25, z0 + 2.6, hex("E0B93A"), model, Enum.Material.Concrete)
		for _, s in { -3, 3 } do
			BK.box("DockBumper", dx + s - 0.6, dx + s + 0.6, 0.2, 1.2, z0 + 2.6, z0 + 2.95, hex("1C1D21"), model, Enum.Material.Rubber)
		end
		rollerDoor(dx, 1.4, 7.4, dockH, tostring(bay + 1))
		BK.box("DockCanopy", dx - 5.2, dx + 5.2, 1.4 + dockH + 0.55, 1.4 + dockH + 0.85, z0, z0 + 3.4, steel, model, Enum.Material.Metal)
		for _, s in { -4.9, 4.9 } do
			BK.cylinder("DockPost", 0.18, dockH + 0.55, Vector3.new(dx + s, 1.4 + (dockH + 0.55) / 2, z0 + 3.2), steel, model, Enum.Material.Metal)
		end
		BK.pallet(model, CFrame.new(dx - 2.4, 1.46, z0 + 1.25), true)
		BK.pallet(model, CFrame.new(dx + 2.5, 1.46, z0 + 1.25), prng:NextNumber() < 0.6)
		table.insert(occ, { dx - 5.6, dx + 5.6 })
	end
	-- ประตูคนเข้าที่ผนังด้านข้าง (-X)
	local mdz = z0 - 4.5
	BK.box("ManDoor", x0 - 0.25, x0, 0.3, 6.6, mdz - 1.5, mdz + 1.5, hex("3C5A48"), model, Enum.Material.Metal)
	BK.box("ManDoorStep", x0 - 1.2, x0, 0, 0.4, mdz - 1.8, mdz + 1.8, hex("8F8B83"), model, Enum.Material.Concrete)
	BK.box("WallLamp", x0 - 0.7, x0, 7.2, 7.8, mdz - 0.5, mdz + 0.5, hex("2A2C32"), model, Enum.Material.Metal)
	-- ป้าย 第N倉庫 + ชื่อบริษัท (หน้าตึก)
	local jp = "第" .. WH_KANJI[prng:NextInteger(1, #WH_KANJI)] .. "倉庫"
	local en = WH_EN[prng:NextInteger(1, #WH_EN)]
	local sy = h - 1.9
	local jpSign = BK.sign(model, jp, Vector3.new(7.2, 2.5, 0.35), Vector3.new(x0 + 4.4, sy, z0 + 0.2), 180, accent, hex("F2F0E6"))
	jpSign.Material = Enum.Material.Metal
	BK.jpFont(jpSign)
	local ew = math.min(9.5, w - 9.5)
	local enSign = BK.sign(model, en, Vector3.new(ew, 1.9, 0.35), Vector3.new(cx + w / 2 - 1.5 - ew / 2, sy, z0 + 0.2), 180, hex("ECE8DA"), accent:Lerp(Color3.new(0, 0, 0), 0.25))
	enSign.Material = Enum.Material.Metal
	BK.jpFont(enSign)
	-- หน้าต่างบานเล็กสูง (ข้ามช่วงประตู)
	local wy = h - 5.6
	local function win(x: number, z: number, onX: boolean, sign: number)
		local fs = if onX then Vector3.new(0.2, 1.9, 3.4) else Vector3.new(3.4, 1.9, 0.2)
		local gs = if onX then Vector3.new(0.3, 1.5, 3.0) else Vector3.new(3.0, 1.5, 0.3)
		local ox, oz = if onX then sign else 0, if onX then 0 else sign
		local f = BK.part("WhWindowFrame", fs, Vector3.new(x + ox * 0.08, wy, z + oz * 0.08), hex("BFC2C0"), model, Enum.Material.Metal)
		local g = BK.part("WhWindow", gs, Vector3.new(x + ox * 0.12, wy, z + oz * 0.12), hex("5E7F98"), model, Enum.Material.Glass)
		g.Transparency = 0.25
		f.CanCollide, g.CanCollide = false, false
	end
	local function blocked(x: number): boolean
		for _, o in occ do
			if x > o[1] - 1.9 and x < o[2] + 1.9 then
				return true
			end
		end
		return false
	end
	local x = x0 + 3
	while x < cx + w / 2 - 2.5 do
		if not blocked(x) then
			win(x, z0, false, 1)
		end
		win(x, cz - d / 2, false, -1)
		x += 6.2
	end
	local z = cz - d / 2 + 3.5
	while z < z0 - 2.5 do
		win(cx + w / 2, z, true, 1)
		if math.abs(z - mdz) > 3.4 then
			win(x0, z, true, -1)
		end
		z += 7
	end
	-- สันหลังคา + ปล่องระบายอากาศแบบเทอร์ไบน์
	local rise = math.clamp(w * 0.22, 1.8, 3.2)
	local ry = h + 0.6 + rise
	BK.box("RidgeCap", cx - 0.6, cx + 0.6, ry - 0.1, ry + 0.4, cz - d / 2 - 0.9, z0 + 0.9, hex("4A525C"), model, Enum.Material.Metal)
	local nv = math.max(2, math.floor(d / 8))
	for k = 1, nv do
		local vz = cz - d / 2 + (k - 0.5) * (d / nv)
		BK.cylinder("RoofVentBase", 0.6, 0.9, Vector3.new(cx, ry + 0.8, vz), hex("8C8F93"), model, Enum.Material.Metal)
		BK.ball("RoofVent", 2.1, Vector3.new(cx, ry + 2.0, vz), hex("B8BABA"), model, Enum.Material.Metal)
	end
end

local function scaffold(model: Instance, cx: number, cz: number, w: number, d: number, h: number)
	local fz = cz + d / 2 + 1.4
	local top = math.min(h - 1, 24)
	local step = math.max(3, (w - 1) / math.ceil((w - 1) / 3.5))
	local x = cx - w / 2 + 0.5
	while x < cx + w / 2 - 0.4 do
		noc(BK.box("ScaffoldPost", x - 0.12, x + 0.12, 0, top, fz - 0.12, fz + 0.12, hex("A5A7A8"), model, Enum.Material.Metal))
		x += step
	end
	for y = 4, top, 4 do
		noc(BK.box("ScaffoldBar", cx - w / 2 + 0.4, cx + w / 2 - 0.4, y, y + 0.2, fz - 0.15, fz + 0.15, hex("A5A7A8"), model, Enum.Material.Metal))
	end
	local net = noc(BK.box("GreenNet", cx - w / 2 + 0.4, cx + w / 2 - 0.4, 0.5, top, fz + 0.15, fz + 0.2, hex("4F6E55"), model, Enum.Material.Fabric))
	net.Transparency = 0.25
end

local function tokyoBuild(parent: Instance, lot: any, rng: Random): Instance
	if lot.Ground == "yard" then
		return containerYard(parent, lot, rng)
	end
	local pal = ERA_WALL[lot.Era] or ERA_WALL.postwar
	local wall = jitter(hex(pal[rng:NextInteger(1, #pal)]), 0.03)
	local roof = hex(ROOF_COLORS[rng:NextInteger(1, #ROOF_COLORS)])
	local h: number, w: number, d: number = lot.H, lot.W, lot.D
	local cx, cz = lot.X, lot.Z
	local o: { [string]: any } = { Facing = 1 }
	if lot.Era == "postwar" then
		o.Material = Enum.Material.Concrete
	elseif lot.Era == "showa" then
		o.Material = if h <= 22 then Enum.Material.Brick else Enum.Material.Concrete
	elseif lot.Era == "modern" then
		o.Material = Enum.Material.Concrete
		o.GlassColor = hex("5E7F98")
	else
		o.Material = Enum.Material.Plaster
	end
	if lot.Ground == "shop" then
		o.Kind = lot.Kind
		o.Storefront = true
		if lot.Kind ~= "konbini" and (lot.Zone == "shop" or lot.Era == "wood" or rng:NextNumber() < 0.3) then
			o.Awning = hex(AWNING_COLORS[rng:NextInteger(1, #AWNING_COLORS)])
		end
	elseif lot.Ground == "ind" then
		o.Material = Enum.Material.Metal
		wall = hex(({ "A5A7A8", "9AA09E", "8E9498" })[rng:NextInteger(1, 3)])
		o.SignText = ({ "WAREHOUSE", "LOGISTICS", "SUSU MARINE", "CARGO" })[rng:NextInteger(1, 4)]
		o.SignBg = hex("2A2C32")
		o.SignFg = hex("A8643A")
	end
	if lot.Ground == "house" and h < 12 then
		o.Detail = false
	end
	local model = BK.building(parent, cx, cz, w, d, h, wall, roof, o)
	if lot.Ground == "ind" or lot.Era == "wood" then
		gableRoof(model, cx, cz, w, d, h, hex(({ "4A525C", "5B5D6B", "6B4F44" })[rng:NextInteger(1, 3)]))
	end
	if lot.Ground == "ind" then
		warehouseDetail(model, cx, cz, w, d, h, Random.new(math.floor(cx * 13 + cz * 29)))
	end
	if lot.Ground == "house" then
		houseGround(model, cx, cz, w, d, rng)
	end
	if h >= 11 and lot.Ground ~= "ind" and rng:NextNumber() < 0.5 then
		exteriorStairs(model, cx, cz, w, d, h, rng)
	end
	if h >= 16 and (lot.Era == "showa" or lot.Era == "modern") and rng:NextNumber() < 0.75 then
		balconies(model, cx, cz, w, d, h, rng, lot.Era == "modern")
	end
	if h > 8 and lot.Ground ~= "ind" and lot.Era ~= "wood" then
		roofClutter(model, cx, cz, w, d, h, rng)
	end
	if rng:NextNumber() < 0.05 and h >= 10 then
		scaffold(model, cx, cz, w, d, h)
	end
	rotateModel(model, cx, cz, lot.Yaw)
	return model
end

-- สร้างตึกในโฟลเดอร์ชั่วคราวนอก workspace (หมุน/วางชิ้นส่วนถูกกว่ามาก) แล้วค่อยย้ายเข้าจริงครั้งเดียว
function BK.tokyo(parent: Instance, lot: any, rng: Random): Instance
	local stage = Instance.new("Folder")
	local model = tokyoBuild(stage, lot, rng)
	model.Parent = parent
	stage:Destroy()
	return model
end

return BK
