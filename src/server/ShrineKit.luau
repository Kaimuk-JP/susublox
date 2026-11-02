--!strict
-- ศาลเจ้าญี่ปุ่นบนยอดเนิน (เรียกจาก WorldBuilder.buildTemple) พิกัดเทียบศูนย์กลางเนิน: +x = ตะวันออก, +z = ใต้ (ทางขึ้นบันได), ยอดราบสูง topY
-- ผัง (แกน x=0 จากใต้ไปเหนือ): ปลายบันได z+22 -> ซันโด (โคมาอินุ, โคมหิน) -> บอสยืนที่ (0,-16) ต้องโล่งเหนือหัว
--   -> ไฮเด็ง z-30..-45 (ยกฐานหิน 2 ชั้น + บันไดไม้ 6 ขั้น, หลังคาคิริซึมะ) -> ทางเดินมีหลังคา -> ฮนเด็ง z-52..-61 (นางาเระซึคุริ)
--   ข้างซันโด: เทมิซุยะ (ตะวันออก z+12), ซุ้มเอมะ/แผงโอมิคุจิ (ตะวันตก), ร้านโอมาโมริ (ตะวันออก z-6), ต้นไม้รอบลาน
-- ห้ามวางสิ่งใดเหนือ (0,-16) รัศมี 5 (บอสวางด้วย raycast ลงจากบน) และให้โล่งรอบ POI (15,0) (ตรวจระยะแนวราบ 14)
-- งบ: ~1,300 ชิ้น, PointLight ไม่เกิน 10 ดวง (ตั้งผ่าน lamp()), ชิ้นเล็ก CastShadow=false
local BK = require(script.Parent.BuildKit)

local ShrineKit = {}

local hex = Color3.fromHex
local Mat = Enum.Material

local C = {
	vermilion = hex("C2352A"),
	vermilionDark = hex("9E2A22"),
	woodDark = hex("4E3526"),
	wood = hex("A58560"),
	woodPale = hex("C4A67C"),
	plaster = hex("E6E0D0"),
	kawara = hex("2C2E34"),
	copper = hex("5B9A86"),
	copperDark = hex("3F7A68"),
	gold = hex("D8B040"),
	stone = hex("9C9B94"),
	stoneLight = hex("B9B8B0"),
	stoneDark = hex("77766F"),
	gravel = hex("C9C6BC"),
	straw = hex("D9C58A"),
	strawDark = hex("B89F5E"),
	paper = hex("F4F1E8"),
	glow = hex("FFB45A"),
	water = hex("7FC4E8"),
}

local lightCount = 0
local partCount = 0

type Ctx = { f: Instance, cx: number, cz: number, y: number }

---------------------------------------------------------------- ตัวช่วยพื้นฐาน (พิกัดเทียบศูนย์กลางเนิน/ยอดราบ)
local function finish(p: BasePart)
	partCount += 1
	local s = p.Size
	if math.max(s.X, s.Y, s.Z) < 3 then
		p.CastShadow = false
	end
end

-- กล่องตามช่วงพิกัดท้องถิ่น
local function box(c: Ctx, parent: Instance, name: string, x1: number, x2: number, y1: number, y2: number, z1: number, z2: number, color: Color3, mat: Enum.Material?): Part
	local p = BK.box(name, c.cx + x1, c.cx + x2, c.y + y1, c.y + y2, c.cz + z1, c.cz + z2, color, parent, mat)
	finish(p)
	return p
end

-- ชิ้นส่วนมีทิศ: frame เทียบท้องถิ่น (ตำแหน่ง + หมุน)
local function part(c: Ctx, parent: Instance, name: string, size: Vector3, frame: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = BK.part(name, size, Vector3.zero, color, parent, mat)
	p.CFrame = CFrame.new(c.cx, c.y, c.cz) * frame
	finish(p)
	return p
end

local function cyl(c: Ctx, parent: Instance, name: string, radius: number, height: number, x: number, y: number, z: number, color: Color3, mat: Enum.Material?): Part
	local p = BK.cylinder(name, radius, height, Vector3.new(c.cx + x, c.y + y, c.cz + z), color, parent, mat)
	finish(p)
	return p
end

-- ทรงกระบอกแนวนอน แกนไปตาม +x (rotY หมุนรอบแกน y)
local function cylH(c: Ctx, parent: Instance, name: string, radius: number, length: number, pos: Vector3, rotY: number, color: Color3, mat: Enum.Material?): Part
	local p = BK.part(name, Vector3.new(length, radius * 2, radius * 2), Vector3.zero, color, parent, mat)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(c.cx + pos.X, c.y + pos.Y, c.cz + pos.Z) * CFrame.Angles(0, rotY, 0)
	finish(p)
	return p
end

local function ball(c: Ctx, parent: Instance, name: string, d: number, x: number, y: number, z: number, color: Color3, mat: Enum.Material?): Part
	local p = BK.ball(name, d, Vector3.new(c.cx + x, c.y + y, c.cz + z), color, parent, mat)
	finish(p)
	return p
end

local function lamp(p: BasePart, color: Color3, range: number, brightness: number)
	lightCount += 1
	BK.light(p, color, range, brightness)
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- เชือก/ท่อนยาวระหว่างจุด a-b (พิกัดท้องถิ่น)
local function rod(c: Ctx, parent: Instance, name: string, a: Vector3, b: Vector3, radius: number, color: Color3, mat: Enum.Material?): Part
	local len = (b - a).Magnitude
	local p = BK.part(name, Vector3.new(len, radius * 2, radius * 2), Vector3.zero, color, parent, mat)
	p.Shape = Enum.PartType.Cylinder
	local base = Vector3.new(c.cx, c.y, c.cz)
	p.CFrame = CFrame.lookAt(base + (a + b) / 2, base + b) * CFrame.Angles(0, math.rad(90), 0)
	finish(p)
	return p
end

---------------------------------------------------------------- หลังคาโค้งเว้า (ชั้นเอียงต่อกัน)
-- local frame: สันหลังคาขนานแกน z ที่ x=0 โปรไฟล์ในระนาบ x-y; origin = จุดสันหลังคา; segs = { {dx, dy}, ... } วัดจากสันออกไปด้านนอก (dy ลบ = ลดลง)
type Seg = { number }
local function roofSide(c: Ctx, parent: Instance, origin: CFrame, side: number, segs: { Seg }, zLen: number, zMid: number, thick: number, color: Color3, mat: Enum.Material?): ({ Vector3 }, number)
	local pts: { Vector3 } = { Vector3.new(0, 0, 0) }
	local x, y = 0, 0
	for _, s in segs do
		x += s[1]
		y += s[2]
		table.insert(pts, Vector3.new(x * side, y, 0))
	end
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local d = b - a
		local len = d.Magnitude + 0.5
		local ang = math.atan2(d.Y, d.X)
		local nrm = Vector3.new(-d.Y, d.X, 0).Unit
		if side < 0 then
			nrm = -nrm
		end
		-- ผิวบนอยู่ตามเส้นโปรไฟล์ แผ่นหนาลงด้านล่าง
		local mid = (a + b) / 2 - nrm * (thick / 2)
		part(c, parent, "RoofSlab", Vector3.new(len, thick, zLen), origin * CFrame.new(mid.X, mid.Y, zMid) * CFrame.Angles(0, 0, ang), color, mat)
	end
	return pts, x
end

-- ผนังจั่ว (หน้า/หลัง) ถมด้วยกล่องเรียงชั้นใต้โปรไฟล์ที่ระนาบ z
local function gableFill(c: Ctx, parent: Instance, origin: CFrame, ptsL: { Vector3 }, ptsR: { Vector3 }, z: number, thick: number, color: Color3, maxL: number?, maxR: number?)
	-- ชั้นแนวนอนหนา ~1.2 จากสันลงมา ความกว้างตามโปรไฟล์ (ใช้ด้านแคบกว่าของ 2 ข้าง) ลดลงเล็กน้อยให้ซ่อนใต้แผ่นหลังคา
	local function widthAt(pts: { Vector3 }, y: number): number
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			if y <= a.Y and y >= b.Y then
				local t = (a.Y - y) / math.max(a.Y - b.Y, 1e-4)
				return math.abs(a.X + (b.X - a.X) * t)
			end
		end
		return math.abs(pts[#pts].X)
	end
	local bottom = math.min(ptsL[#ptsL].Y, ptsR[#ptsR].Y) + 0.2
	local step = 1.2
	local y = -step
	while y > bottom - step do
		local ytop = y + step
		local wl = math.min(widthAt(ptsL, ytop - 0.3) - 0.5, maxL or 1e9)
		local wr = math.min(widthAt(ptsR, ytop - 0.3) - 0.5, maxR or 1e9)
		if wl > 0 and wr > 0 then
			local lo = math.max(y, bottom)
			part(c, parent, "GableWall", Vector3.new(wl + wr, ytop - lo, thick), origin * CFrame.new((wr - wl) / 2, (ytop + lo) / 2, z), color, Mat.Concrete)
		end
		y -= step
	end
end

---------------------------------------------------------------- 1) ลานหิน + ซันโด
local function buildTerrace(c: Ctx, f: Folder)
	local t = folder(f, "Terrace")
	-- ยกพื้นหินกว้างครอบยอดเนิน (ผนังกันดินหินจรดพื้นด้านนอก, ด้านบนเป็นแผ่นหนา walkable)
	local X, zN, zS = 32, -66, 23
	box(c, t, "TerraceSlab", -X, X, -1.5, 0, zN, zS, C.stoneLight, Mat.Slate)
	local wallMat = Mat.Cobblestone
	box(c, t, "TerraceWallW", -X - 2, -X, -27, 0, zN - 2, zS + 2, C.stoneDark, wallMat)
	box(c, t, "TerraceWallE", X, X + 2, -27, 0, zN - 2, zS + 2, C.stoneDark, wallMat)
	box(c, t, "TerraceWallN", -X, X, -27, 0, zN - 2, zN, C.stoneDark, wallMat)
	box(c, t, "TerraceWallSW", -X, -6, -27, 0, zS, zS + 2, C.stoneDark, wallMat)
	box(c, t, "TerraceWallSE", 6, X, -27, 0, zS, zS + 2, C.stoneDark, wallMat)
	-- ขอบบนของกำแพง (coping) ยื่นเล็กน้อย
	box(c, t, "CopingW", -X - 2.6, -X + 0.4, -1.5, 0.3, zN - 2.6, zS + 2.6, C.stone, Mat.Slate)
	box(c, t, "CopingE", X - 0.4, X + 2.6, -1.5, 0.3, zN - 2.6, zS + 2.6, C.stone, Mat.Slate)
	box(c, t, "CopingN", -X, X, -1.5, 0.3, zN - 2.6, zN + 0.4, C.stone, Mat.Slate)
	-- แนวหินก่อ (ขอบหินยื่นเป็นชั้น ๆ) ให้อ่านเป็นกำแพงหินไม่ใช่กล่อง
	for _, h in { -8, -16 } do
		box(c, t, "WallCourseW", -X - 2.15, -X + 0.1, h, h + 0.5, zN - 2.2, zS + 2.2, C.stone, Mat.Slate)
		box(c, t, "WallCourseE", X - 0.1, X + 2.15, h, h + 0.5, zN - 2.2, zS + 2.2, C.stone, Mat.Slate)
		box(c, t, "WallCourseN", -X, X, h, h + 0.5, zN - 2.15, zN, C.stone, Mat.Slate)
	end
end

local function buildSando(c: Ctx, f: Folder)
	local s = folder(f, "Sando")
	local zS, zN = 22, -22
	box(c, s, "SandoPaving", -4, 4, 0, 0.18, zN, zS, C.gravel, Mat.Slate)
	-- ร่องแผ่นหินขวางทุก 3 studs + แถวกลาง
	for z = zN + 3, zS - 1, 3 do
		box(c, s, "SandoJoint", -4, 4, 0.18, 0.24, z - 0.07, z + 0.07, C.stoneDark, Mat.Slate)
	end
	box(c, s, "SandoJointMid", -0.07, 0.07, 0.18, 0.24, zN, zS, C.stoneDark, Mat.Slate)
	-- ขอบหินสองข้าง + กรวดขาวข้างทาง
	for _, sx in { -1, 1 } do
		box(c, s, "SandoKerb", math.min(sx * 4, sx * 4.7), math.max(sx * 4, sx * 4.7), 0, 0.5, zN, zS, C.stone, Mat.Granite)
		box(c, s, "SandoGravel", math.min(sx * 4.7, sx * 7), math.max(sx * 4.7, sx * 7), 0, 0.1, zN, zS, C.gravel, Mat.Pebble)
	end
end

---------------------------------------------------------------- 2) ชิเมนาวะ + ชิเดะ (โทริอิบนสุด), โคมาอินุ
function ShrineKit.shimenawa(f: Instance, x: number, baseY: number, z: number)
	local c: Ctx = { f = f, cx = x, cz = z, y = baseY }
	local p = folder(f, "Shimenawa")
	-- เสาโทริอิ x ±5 หนา 1.4 -> ช่องในกว้าง ~8.6; เชือกห้อยระหว่างเสา ใต้คานนุกิ (y 8.4) ต่ำสุด ~7.1
	local n = 14
	local span = 4.3
	local prev: Vector3? = nil
	local pts: { Vector3 } = {}
	for i = 0, n do
		local u = i / n * 2 - 1
		local pt = Vector3.new(u * span, 7.75 - 0.9 * (1 - u * u), -0.2)
		table.insert(pts, pt)
		if prev then
			local r = 0.38 + 0.22 * (1 - math.abs(u)) -- กลางเชือกอ้วนกว่าปลาย
			rod(c, p, "Shimenawa", prev, pt, r, if i % 2 == 0 then C.straw else C.strawDark, Mat.Fabric)
		end
		prev = pt
	end
	-- ปลายเชือกชี้ลงเป็นพู่ 2 ข้าง
	for _, s in { -1, 1 } do
		rod(c, p, "ShimenawaTail", Vector3.new(s * span, 7.2, -0.2), Vector3.new(s * (span + 0.1), 5.8, -0.2), 0.22, C.straw, Mat.Fabric)
	end
	-- ชิเดะ: แถบกระดาษขาวซิกแซก ห้อยจากเชือกทุกจังหวะ 3 ชิ้นต่อพวง สลับมุม
	for _, i in { 2, 4, 6, 8, 10, 12 } do
		local top = pts[i + 1]
		for k = 0, 2 do
			local sway = (if k % 2 == 0 then 1 else -1) * 0.35
			part(c, p, "Shide", Vector3.new(0.9, 0.9, 0.06), CFrame.new(top.X + sway, top.Y - 0.9 - k * 0.85, top.Z - 0.3) * CFrame.Angles(0, 0, math.rad(if k % 2 == 0 then 22 else -22)), C.paper, Mat.SmoothPlastic)
		end
	end
end

local function komainu(c: Ctx, parent: Instance, x: number, z: number, openMouth: boolean)
	-- หันหน้า +z (ทางขึ้น) ตั้งบนฐานหิน 2 ชั้น
	local m = folder(parent, "Komainu")
	local s, sd = C.stoneLight, C.stone
	local mat = Mat.Granite
	box(c, m, "KomainuPlinth1", x - 2.4, x + 2.4, 0, 1.2, z - 2.6, z + 2.6, sd, mat)
	box(c, m, "KomainuPlinth2", x - 1.9, x + 1.9, 1.2, 2.2, z - 2.1, z + 2.1, s, mat)
	local y0 = 2.2
	-- ท้ายกับขาหลัง
	ball(c, m, "KomainuHaunch", 3.0, x, y0 + 1.5, z - 0.9, s, mat)
	box(c, m, "KomainuTorso", x - 0.95, x + 0.95, y0 + 0.4, y0 + 2.6, z - 1.2, z + 0.9, s, mat)
	for _, sx in { -0.6, 0.6 } do
		box(c, m, "KomainuForeleg", x + sx - 0.35, x + sx + 0.35, y0, y0 + 2.4, z + 0.8, z + 1.5, s, mat)
		box(c, m, "KomainuPaw", x + sx - 0.45, x + sx + 0.45, y0, y0 + 0.4, z + 0.8, z + 1.9, sd, mat)
	end
	-- อกยื่น คอตั้ง หัว
	ball(c, m, "KomainuChest", 2.2, x, y0 + 2.7, z + 0.7, s, mat)
	box(c, m, "KomainuNeck", x - 0.7, x + 0.7, y0 + 2.8, y0 + 4.0, z + 0.4, z + 1.4, s, mat)
	box(c, m, "KomainuHead", x - 0.95, x + 0.95, y0 + 3.7, y0 + 5.2, z + 0.5, z + 2.3, s, mat)
	box(c, m, "KomainuBrow", x - 1.0, x + 1.0, y0 + 4.6, y0 + 5.0, z + 1.9, z + 2.5, sd, mat)
	if openMouth then
		box(c, m, "KomainuUpperJaw", x - 0.6, x + 0.6, y0 + 4.2, y0 + 4.7, z + 2.3, z + 3.1, s, mat)
		part(c, m, "KomainuLowerJaw", Vector3.new(1.2, 0.4, 1.0), CFrame.new(x, y0 + 3.7, z + 2.7) * CFrame.Angles(math.rad(-22), 0, 0), s, mat)
		box(c, m, "KomainuTongue", x - 0.3, x + 0.3, y0 + 3.9, y0 + 4.1, z + 2.0, z + 2.8, C.vermilionDark, Mat.Concrete)
	else
		box(c, m, "KomainuMuzzle", x - 0.6, x + 0.6, y0 + 3.8, y0 + 4.7, z + 2.3, z + 3.1, s, mat)
	end
	ball(c, m, "KomainuNose", 0.7, x, y0 + 4.5, z + 3.1, sd, mat)
	-- แผงคอ (ขนแผงคอเป็นก้อนกลม) หู ตา
	for _, o in { { -1.1, 4.4, 0.9 }, { 1.1, 4.4, 0.9 }, { -1.15, 3.6, 1.0 }, { 1.15, 3.6, 1.0 }, { 0, 5.35, 0.8 }, { -0.6, 5.3, 1.3 }, { 0.6, 5.3, 1.3 } } do
		ball(c, m, "KomainuMane", 1.0, x + o[1], y0 + o[2], z + o[3], sd, mat)
	end
	for _, sx in { -0.6, 0.6 } do
		ball(c, m, "KomainuEye", 0.35, x + sx, y0 + 4.85, z + 2.35, C.woodDark, Mat.Concrete)
	end
	-- หางตั้งโค้งเป็นเปลว
	ball(c, m, "KomainuTail1", 1.1, x, y0 + 2.8, z - 2.1, sd, mat)
	ball(c, m, "KomainuTail2", 1.3, x + 0.2, y0 + 3.9, z - 1.9, s, mat)
	ball(c, m, "KomainuTail3", 1.0, x - 0.3, y0 + 4.8, z - 1.5, sd, mat)
end

---------------------------------------------------------------- ศาลาคลุม + หลังคาจั่วเรียบง่าย (เทมิซุยะ ร้านโอมาโมริ ทางเดินมีหลังคา)
-- สันหลังคาขนานแกน z; frame = ศูนย์กลางตัวอาคารที่ระดับพื้น; eaveY = ความสูงชายคา
local function simpleGable(c: Ctx, parent: Instance, frame: CFrame, halfW: number, zFront: number, zBack: number, eaveY: number, rise: number, color: Color3, mat: Enum.Material?)
	local run = halfW
	local segs: { Seg } = { { run * 0.45, -rise * 0.55 }, { run * 0.55, -rise * 0.45 } }
	local origin = frame * CFrame.new(0, eaveY + rise, 0)
	local ptsL = roofSide(c, parent, origin, -1, segs, zBack - zFront, (zFront + zBack) / 2, 0.6, color, mat)
	local ptsR = roofSide(c, parent, origin, 1, segs, zBack - zFront, (zFront + zBack) / 2, 0.6, color, mat)
	part(c, parent, "RoofRidge", Vector3.new(0.9, 0.7, zBack - zFront + 0.4), origin * CFrame.new(0, 0.3, (zFront + zBack) / 2), C.kawara, Mat.Slate)
	return ptsL, ptsR, origin
end

local function temizuya(c: Ctx, f: Folder)
	local t = folder(f, "Temizuya")
	local x0, z0 = 19, 12
	-- พื้นหิน + 4 เสาไม้ + คานรอบ
	box(c, t, "TemizuyaFloor", x0 - 5.5, x0 + 5.5, 0, 0.5, z0 - 4.5, z0 + 4.5, C.stone, Mat.Slate)
	local hw, hd = 4.2, 3.2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(c, t, "TemizuyaPost", x0 + sx * hw - 0.35, x0 + sx * hw + 0.35, 0.5, 8.6, z0 + sz * hd - 0.35, z0 + sz * hd + 0.35, C.woodDark, Mat.Wood)
		end
	end
	for _, sz in { -1, 1 } do
		box(c, t, "TemizuyaBeam", x0 - hw - 0.6, x0 + hw + 0.6, 8.3, 9.1, z0 + sz * hd - 0.4, z0 + sz * hd + 0.4, C.woodDark, Mat.Wood)
	end
	for _, sx in { -1, 1 } do
		box(c, t, "TemizuyaTie", x0 + sx * hw - 0.4, x0 + sx * hw + 0.4, 8.3, 9.1, z0 - hd, z0 + hd, C.woodDark, Mat.Wood)
	end
	-- หลังคาจั่ว สันขนาน x (เปิดด้านจั่วออก +-x? ) ใช้ frame หมุน 90 องศา: สันขนาน x, ชายคายื่น 2 stud
	local frame = CFrame.new(x0 - 0, 0, z0) * CFrame.Angles(0, math.rad(90), 0)
	local ptsL, ptsR, origin = simpleGable(c, t, frame, hd + 2.2, -(hw + 2), hw + 2, 9.1, 3.8, C.kawara, Mat.Slate)
	gableFill(c, t, origin, ptsL, ptsR, hw + 1.6, 0.4, C.plaster)
	gableFill(c, t, origin, ptsL, ptsR, -(hw + 1.6), 0.4, C.plaster)
	-- อ่างน้ำหิน + ผิวน้ำโปร่งใส
	box(c, t, "BasinOuter", x0 - 2.6, x0 + 2.6, 0.5, 2.4, z0 - 1.6, z0 + 1.6, C.stoneDark, Mat.Granite)
	box(c, t, "BasinRim", x0 - 2.3, x0 + 2.3, 2.4, 2.6, z0 - 1.3, z0 + 1.3, C.stoneLight, Mat.Granite)
	local w = box(c, t, "BasinWater", x0 - 2.1, x0 + 2.1, 2.2, 2.45, z0 - 1.1, z0 + 1.1, C.water, Mat.Glass)
	w.Transparency = 0.45
	w.CanCollide = false
	-- ท่อไผ่ปล่อยน้ำ + เสาไม้ไผ่พาดกระบวย 4 อัน
	box(c, t, "BasinSpoutPost", x0 + 2.0, x0 + 2.35, 2.6, 4.4, z0 - 0.15, z0 + 0.15, C.strawDark, Mat.Wood)
	cylH(c, t, "BasinSpout", 0.22, 1.6, Vector3.new(x0 + 1.4, 4.3, z0), 0, C.strawDark, Mat.Wood)
	-- ไม้ไผ่พาดกระบวยเหนืออ่าง ไผ่ขนาน x
	local ry = 4.6
	box(c, t, "LadlePost", x0 - 2.6, x0 - 2.3, 2.6, ry, z0 - 1.4, z0 - 1.1, C.strawDark, Mat.Wood)
	box(c, t, "LadlePost", x0 - 2.6, x0 - 2.3, 2.6, ry, z0 + 1.1, z0 + 1.4, C.strawDark, Mat.Wood)
	cylH(c, t, "LadleBamboo", 0.18, 3.0, Vector3.new(x0 - 2.45, ry, z0), math.rad(90), C.strawDark, Mat.Wood)
	for i = 0, 3 do
		local lz = z0 - 1.0 + i * 0.66
		cylH(c, t, "LadleCup", 0.25, 0.5, Vector3.new(x0 - 2.45, ry - 0.2, lz), math.rad(0), C.woodPale, Mat.Wood)
		cylH(c, t, "LadleHandle", 0.07, 2.0, Vector3.new(x0 - 1.45, ry + 0.05, lz), math.rad(0), C.woodPale, Mat.Wood)
	end
	local lampP = ball(c, t, "TemizuyaLantern", 0.8, x0 + 0, 7.4, z0 + hd - 0.4, C.glow, Mat.Neon)
	lampP.Transparency = 0.15
	BK.noCollide(lampP)
	lamp(lampP, C.glow, 18, 0.8)
end

---------------------------------------------------------------- 4) โคมหินโทโร
local function toro(c: Ctx, parent: Instance, x: number, z: number, withLight: boolean)
	local m = folder(parent, "Toro")
	local st, mt = C.stone, Mat.Granite
	box(c, m, "ToroBase", x - 1.4, x + 1.4, 0, 0.6, z - 1.4, z + 1.4, C.stoneDark, mt)
	cyl(c, m, "ToroBaseRound", 1.1, 0.5, x, 0.85, z, st, mt)
	cyl(c, m, "ToroShaft", 0.5, 3.4, x, 2.8, z, st, mt)
	cyl(c, m, "ToroRing", 0.8, 0.35, x, 4.65, z, C.stoneDark, mt)
	box(c, m, "ToroPlatform", x - 1.3, x + 1.3, 4.8, 5.2, z - 1.3, z + 1.3, st, mt)
	box(c, m, "ToroFirebox", x - 0.95, x + 0.95, 5.2, 6.7, z - 0.95, z + 0.95, C.stoneDark, mt)
	for _, o in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
		local gx, gz = o[1] * 0.97, o[2] * 0.97
		local sz = if o[1] ~= 0 then Vector3.new(0.12, 0.8, 0.6) else Vector3.new(0.6, 0.8, 0.12)
		local g = part(c, m, "ToroGlow", sz, CFrame.new(x + gx, 5.95, z + gz), C.glow, Mat.Neon)
		BK.noCollide(g)
		if withLight and o[1] == 0 and o[2] == 1 then
			lamp(g, C.glow, 22, 1)
		end
	end
	box(c, m, "ToroRoofA", x - 1.9, x + 1.9, 6.7, 7.1, z - 1.9, z + 1.9, st, mt)
	part(c, m, "ToroRoofB", Vector3.new(3.1, 0.4, 3.1), CFrame.new(x, 7.3, z) * CFrame.Angles(0, math.rad(45), 0), st, mt)
	part(c, m, "ToroRoofC", Vector3.new(1.9, 0.5, 1.9), CFrame.new(x, 7.7, z) * CFrame.Angles(0, math.rad(45), 0), st, mt)
	ball(c, m, "ToroFinial", 0.9, x, 8.2, z, st, mt)
end

---------------------------------------------------------------- 4) ซุ้มเอมะ, แผงโอมิคุจิ, ร้านโอมาโมริ
local function emaRack(c: Ctx, f: Folder)
	local m = folder(f, "EmaRack")
	local x0, z0 = -19, 6 -- สันหลังคาขนาน x ยาว 14
	local hw = 6.6
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(c, m, "EmaPost", x0 + sx * hw - 0.3, x0 + sx * hw + 0.3, 0, 7.6, z0 + sz * 1.8 - 0.3, z0 + sz * 1.8 + 0.3, C.woodDark, Mat.Wood)
		end
	end
	for _, y in { 1.2, 3.4, 5.6 } do
		-- แถวเอมะ = 1 แผ่นต่อแถว/ด้าน (SurfaceGui ตารางแผ่นไม้) แทนการวางทีละแผ่น
		for _, sz in { -1, 1 } do
			local row = box(c, m, "EmaRow", x0 - hw, x0 + hw, y, y + 1.7, z0 + sz * 1.8 - 0.1, z0 + sz * 1.8 + 0.1, C.woodPale, Mat.Wood)
			local gui = Instance.new("SurfaceGui")
			gui.Face = if sz > 0 then Enum.NormalId.Back else Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 24
			gui.Parent = row
			local grid = Instance.new("UIGridLayout")
			grid.CellSize = UDim2.new(0, 22, 0, 36)
			grid.CellPadding = UDim2.fromOffset(6, 2)
			grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
			grid.Parent = gui
			for i = 1, 11 do
				local fr = Instance.new("Frame")
				fr.BackgroundColor3 = Color3.fromHSV(0.09 + (i % 4) * 0.01, 0.4, 0.78 + (i % 3) * 0.05)
				fr.BorderSizePixel = 0
				fr.Parent = gui
				local ink = Instance.new("Frame")
				ink.Size = UDim2.new(0.6, 0, 0, 2)
				ink.Position = UDim2.fromScale(0.2, 0.35 + (i % 3) * 0.12)
				ink.BackgroundColor3 = C.woodDark
				ink.BorderSizePixel = 0
				ink.Parent = fr
			end
		end
		box(c, m, "EmaBar", x0 - hw, x0 + hw, y + 1.7, y + 1.95, z0 - 2, z0 + 2, C.woodDark, Mat.Wood)
	end
	local ptsL, ptsR, origin = simpleGable(c, m, CFrame.new(x0, 0, z0) * CFrame.Angles(0, math.rad(90), 0), 3.6, -(hw + 0.8), hw + 0.8, 7.6, 2.4, C.kawara, Mat.Slate)
	gableFill(c, m, origin, ptsL, ptsR, hw + 0.4, 0.3, C.plaster)
	gableFill(c, m, origin, ptsL, ptsR, -(hw + 0.4), 0.3, C.plaster)
end

local function omikujiRack(c: Ctx, f: Folder)
	local m = folder(f, "OmikujiRack")
	local x0, z0 = -19, 20
	local hw = 4.6
	for _, sx in { -1, 1 } do
		box(c, m, "OmikujiPost", x0 + sx * hw - 0.3, x0 + sx * hw + 0.3, 0, 6.2, z0 - 0.3, z0 + 0.3, C.woodDark, Mat.Wood)
	end
	box(c, m, "OmikujiTopBeam", x0 - hw - 0.6, x0 + hw + 0.6, 6.2, 6.8, z0 - 0.4, z0 + 0.4, C.woodDark, Mat.Wood)
	for _, y in { 5.4, 4.0 } do
		cylH(c, m, "OmikujiRope", 0.1, hw * 2, Vector3.new(x0, y, z0), 0, C.straw, Mat.Fabric)
		for i = 0, 13 do
			local px = x0 - hw + 0.4 + i * (hw * 2 - 0.8) / 13
			local tilt = if i % 2 == 0 then 4 else -5
			part(c, m, "OmikujiPaper", Vector3.new(0.38, 1.5, 0.06), CFrame.new(px, y - 0.75, z0 - 0.05) * CFrame.Angles(0, 0, math.rad(tilt)), C.paper, Mat.SmoothPlastic)
		end
	end
end

local function omamoriStall(c: Ctx, f: Folder)
	local m = folder(f, "OmamoriStall")
	local x0, z0 = 23, -6
	-- ร้านเล็กหันหน้า -x (สู่ซันโด): พื้นยก ผนังไม้ 3 ด้าน เคาน์เตอร์ด้านหน้ากว้าง ช่องเปิด 7
	box(c, m, "StallFloor", x0 - 4.5, x0 + 4.5, 0, 0.8, z0 - 5.5, z0 + 5.5, C.stoneDark, Mat.Slate)
	box(c, m, "StallBack", x0 + 3.8, x0 + 4.4, 0.8, 9.2, z0 - 5, z0 + 5, C.wood, Mat.WoodPlanks)
	box(c, m, "StallWallN", x0 - 4.4, x0 + 4.4, 0.8, 9.2, z0 - 5, z0 - 4.4, C.wood, Mat.WoodPlanks)
	box(c, m, "StallWallS", x0 - 4.4, x0 + 4.4, 0.8, 9.2, z0 + 4.4, z0 + 5, C.wood, Mat.WoodPlanks)
	for _, sz in { -1, 1 } do
		box(c, m, "StallPost", x0 - 4.4, x0 - 3.7, 0.8, 9.4, z0 + sz * 4.7 - 0.35, z0 + sz * 4.7 + 0.35, C.vermilionDark, Mat.Wood)
	end
	box(c, m, "StallCounter", x0 - 4.4, x0 - 2.6, 0.8, 3.4, z0 - 3.9, z0 + 3.9, C.woodDark, Mat.Wood)
	box(c, m, "StallCounterTop", x0 - 4.6, x0 - 2.4, 3.4, 3.7, z0 - 4.1, z0 + 4.1, C.woodPale, Mat.Wood)
	-- ชั้นโอมาโมริ: ถุงเล็กหลายสี
	box(c, m, "StallShelf", x0 + 3.2, x0 + 3.8, 4.2, 4.5, z0 - 3.8, z0 + 3.8, C.woodDark, Mat.Wood)
	local cols = { hex("C2352A"), hex("E8C14C"), hex("3F7A8C"), hex("EFE6D6"), hex("9A4D8A") }
	for i = 0, 8 do
		local oz = z0 - 3.4 + i * 0.85
		box(c, m, "Omamori", x0 + 3.0, x0 + 3.2, 4.5, 5.6, oz - 0.3, oz + 0.3, cols[i % #cols + 1], Mat.Fabric)
	end
	for i = 0, 7 do
		local oz = z0 - 3.0 + i * 0.85
		box(c, m, "Omamori", x0 + 3.0, x0 + 3.2, 6.1, 7.2, oz - 0.3, oz + 0.3, cols[(i + 2) % #cols + 1], Mat.Fabric)
	end
	local ptsL, ptsR, origin = simpleGable(c, m, CFrame.new(x0, 0, z0), 6.2, -6.2, 6.2, 9.4, 3.2, C.kawara, Mat.Slate)
	gableFill(c, m, origin, ptsL, ptsR, 6.0, 0.4, C.plaster)
	gableFill(c, m, origin, ptsL, ptsR, -6.0, 0.4, C.plaster)
	-- ซันโดของโนเรนแดงหน้าร้าน + โคมกระดาษ
	box(c, m, "StallNoren", x0 - 5.0, x0 - 4.8, 8.0, 9.3, z0 - 3.6, z0 + 3.6, C.vermilion, Mat.Fabric)
	local l = ball(c, m, "StallLantern", 1.1, x0 - 4.9, 7.4, z0 - 4.2, C.vermilion, Mat.Neon)
	l.Transparency = 0.15
	BK.noCollide(l)
	lamp(l, C.glow, 16, 0.7)
end

---------------------------------------------------------------- 5) ไฮเด็ง
local function roofCrestAndOrnament(c: Ctx, p: Folder, origin: CFrame, zFront: number, zBack: number, ridgeLen: number)
	-- คัตสึโอกิ: ท่อนไม้กลมวางขวางสันหลังคา
	local n = math.floor((zBack - zFront) / 2.3)
	for i = 0, n do
		local z = zFront + 1.4 + i * ((zBack - zFront - 2.8) / n)
		part(c, p, "Katsuogi", Vector3.new(3.2, 0.9, 0.9), origin * CFrame.new(0, 1.2, z), C.woodDark, Mat.Wood).Shape = Enum.PartType.Cylinder
	end
	-- ชิกิ: ไม้ไขว้ปลายสันหลังคาทั้งสองด้าน
	for _, z in { zFront + 0.2, zBack - 0.2 } do
		for _, s in { -1, 1 } do
			part(c, p, "Chigi", Vector3.new(0.5, 6.2, 0.7), origin * CFrame.new(0, 3.2, z) * CFrame.Angles(0, 0, math.rad(s * 28)), C.woodPale, Mat.Wood)
			part(c, p, "ChigiTip", Vector3.new(0.55, 0.6, 0.75), origin * CFrame.new(s * -1.45, 5.9, z) * CFrame.Angles(0, 0, math.rad(s * 28)), C.gold, Mat.Metal)
		end
	end
end

local function kamon(c: Ctx, p: Folder, x: number, y: number, z: number, faceZ: number)
	-- ตราดอกไม้ 8 กลีบสีทอง (วงกลม) หันหน้า faceZ (+1 หรือ -1)
	local discs = { { 1.9, 0.12, C.gold }, { 1.55, 0.18, C.vermilionDark }, { 1.25, 0.24, C.gold } }
	for _, d in discs do
		local pp = BK.part("Kamon", Vector3.new(d[2], d[1] * 2, d[1] * 2), Vector3.zero, d[3], p, Mat.Metal)
		pp.Shape = Enum.PartType.Cylinder
		pp.CFrame = CFrame.new(c.cx + x, c.y + y, c.cz + z + faceZ * d[2] / 2) * CFrame.Angles(0, math.rad(90), 0)
		finish(pp)
	end
	for k = 0, 7 do
		local a = k * math.pi / 4
		part(c, p, "KamonPetal", Vector3.new(0.3, 0.28, 0.5), CFrame.new(x + math.cos(a) * 0.82, y + math.sin(a) * 0.82, z + faceZ * 0.35) * CFrame.Angles(0, 0, a), C.vermilionDark, Mat.Metal)
	end
	local center = BK.ball("KamonCenter", 0.7, Vector3.new(c.cx + x, c.y + y, c.cz + z + faceZ * 0.4), C.gold, p, Mat.Metal)
	finish(center)
end

local function suzu(c: Ctx, p: Folder, x: number, y: number, z: number)
	-- ระฆังทอง + เชือกถักหลากสี (แดง ขาว เขียว ... ) ห้อยลงหน้าประตู
	local bell = ball(c, p, "Bell", 1.8, x, y, z, C.gold, Mat.Metal)
	BK.noCollide(bell)
	part(c, p, "BellSlit", Vector3.new(1.4, 0.12, 0.12), CFrame.new(x, y - 0.3, z + 0.88), C.woodDark, Mat.Metal)
	box(c, p, "BellMount", x - 0.6, x + 0.6, y + 0.85, y + 1.25, z - 0.6, z + 0.6, C.gold, Mat.Metal)
	local cols = { C.vermilion, C.paper, hex("3F8F5A"), hex("E8C14C"), C.vermilion, C.paper }
	for i, col in cols do
		local off = (i - 3.5) * 0.28
		local q = box(c, p, "SuzuRope", x + off - 0.12, x + off + 0.12, y - 5.8 + (i % 2) * 0.3, y - 0.85, z + 0.2, z + 0.5, col, Mat.Fabric)
		BK.noCollide(q)
	end
	local tassel = ball(c, p, "SuzuTassel", 0.7, x, y - 5.9, z + 0.35, C.vermilion, Mat.Fabric)
	BK.noCollide(tassel)
	lamp(bell, C.glow, 20, 0.8)
end

local function chochinRed(c: Ctx, p: Folder, x: number, y: number, z: number, red: boolean, withLight: boolean)
	local col = if red then C.vermilion else C.paper
	local l = cyl(c, p, "HangLantern", 0.8, 1.9, x, y, z, col, Mat.Neon)
	l.Transparency = 0.12
	BK.noCollide(l)
	for _, dy in { 1.0, -1.0 } do
		BK.noCollide(cyl(c, p, "HangLanternCap", 0.62, 0.2, x, y + dy, z, C.kawara, Mat.Wood))
	end
	box(c, p, "HangLanternCord", x - 0.05, x + 0.05, y + 1.1, y + 2.4, z - 0.05, z + 0.05, C.woodDark, Mat.Wood)
	if withLight then
		lamp(l, C.glow, 18, 0.8)
	end
end

local function saisenBako(c: Ctx, p: Folder, x: number, z: number)
	local woodD = C.woodDark
	-- กล่องใหญ่ 5 x 3 x 3 ฝาหน้า/บนเป็นซี่ไม้ ช่องบนเว้นห่าง
	box(c, p, "SaisenBody", x - 2.5, x + 2.5, 0, 1.3, z - 1.5, z + 1.5, woodD, Mat.Wood)
	for _, sx in { -2.5, 2.2 } do
		box(c, p, "SaisenLeg", x + sx, x + sx + 0.3, 1.3, 3.0, z - 1.5, z + 1.5, woodD, Mat.Wood)
	end
	for i = 0, 11 do
		local sx = x - 2.35 + i * 0.43
		box(c, p, "SaisenSlat", sx, sx + 0.18, 1.3, 3.0, z + 1.2, z + 1.4, C.wood, Mat.Wood)
	end
	for i = 0, 6 do
		local sz = z - 1.4 + i * 0.4
		box(c, p, "SaisenTopSlat", x - 2.5, x + 2.5, 2.8, 3.0, sz, sz + 0.2, C.wood, Mat.Wood)
	end
	box(c, p, "SaisenBack", x - 2.5, x + 2.5, 1.3, 3.0, z - 1.5, z - 1.3, woodD, Mat.Wood)
end

local function kouran(c: Ctx, p: Folder, x1: number, x2: number, z1: number, z2: number, y: number)
	-- ราวระเบียงไม้แดง: ราวบน ราวล่าง ลูกกรง
	local h = 3.0
	local alongX = (x2 - x1) > (z2 - z1)
	if alongX then
		box(c, p, "RailTop", x1, x2, y + h, y + h + 0.3, z1 - 0.2, z1 + 0.2, C.vermilion, Mat.Wood)
		box(c, p, "RailLow", x1, x2, y + 1.3, y + 1.55, z1 - 0.15, z1 + 0.15, C.vermilion, Mat.Wood)
		local n = math.max(2, math.floor((x2 - x1) / 1.5))
		for i = 0, n do
			local x = x1 + 0.2 + i * ((x2 - x1 - 0.4) / n)
			box(c, p, "RailBaluster", x - 0.12, x + 0.12, y, y + h, z1 - 0.12, z1 + 0.12, C.vermilion, Mat.Wood)
		end
		for _, x in { x1, x2 } do
			ball(c, p, "RailGiboshi", 0.55, x, y + h + 0.5, z1, C.gold, Mat.Metal)
		end
	else
		box(c, p, "RailTop", x1 - 0.2, x1 + 0.2, y + h, y + h + 0.3, z1, z2, C.vermilion, Mat.Wood)
		box(c, p, "RailLow", x1 - 0.15, x1 + 0.15, y + 1.3, y + 1.55, z1, z2, C.vermilion, Mat.Wood)
		local n = math.max(2, math.floor((z2 - z1) / 1.5))
		for i = 0, n do
			local z = z1 + 0.2 + i * ((z2 - z1 - 0.4) / n)
			box(c, p, "RailBaluster", x1 - 0.12, x1 + 0.12, y, y + h, z - 0.12, z + 0.12, C.vermilion, Mat.Wood)
		end
		for _, z in { z1, z2 } do
			ball(c, p, "RailGiboshi", 0.55, x1, y + h + 0.5, z, C.gold, Mat.Metal)
		end
	end
end

local HAIDEN = { zF = -30, zB = -45, hw = 14, colX = 12, colZf = -31, colZb = -44 }

local function buildHaiden(c: Ctx, f: Folder)
	local p = folder(f, "Haiden")
	local H = HAIDEN
	-- ฐานหินสองชั้น: ชั้นล่าง (ยื่นรอบ 1.2, สูง 1.4) ชั้นบน (พื้นระเบียง สูง 3.0)
	local floorY = 3.0
	-- ชั้นล่างแยกซ้าย-ขวา เว้นกลางสำหรับบันได (กว้าง 9)
	for _, s in { -1, 1 } do
		box(c, p, "HaidenBaseLow", math.min(s * 4.8, s * (H.hw + 1.2)), math.max(s * 4.8, s * (H.hw + 1.2)), 0, 1.4, H.zB - 1.2, H.zF + 1.0, C.stoneDark, Mat.Granite)
	end
	box(c, p, "HaidenBaseLowBack", -4.8, 4.8, 0, 1.4, H.zB - 1.2, H.zF - 1, C.stoneDark, Mat.Granite)
	box(c, p, "HaidenBaseHigh", -H.hw, H.hw, 1.4, floorY, H.zB, H.zF, C.stone, Mat.Granite)
	-- ขอบหินยื่น (ชั้นบน) + แผ่นพื้นไม้ระเบียงหน้า
	box(c, p, "HaidenBaseCoping", -H.hw - 0.3, H.hw + 0.3, floorY - 0.35, floorY, H.zB - 0.3, H.zF + 0.3, C.stoneLight, Mat.Granite)
	box(c, p, "HaidenDeck", -H.hw, H.hw, floorY, floorY + 0.25, H.zB + 1, H.zF, C.wood, Mat.WoodPlanks)
	local fy = floorY + 0.25 -- ระดับเท้า
	-- บันไดไม้ 6 ขั้น กว้าง 9 ลึกขั้นละ 1.3: เริ่ม z=-22.2
	local n, run = 6, 1.3
	for i = 1, n do
		local zNear = H.zF + (n - i) * run -- ขั้นล่างสุดอยู่ไกลสุด (z มาก)
		box(c, p, "HaidenStep", -4.5, 4.5, 0, floorY * i / n, zNear, zNear + run, C.woodPale, Mat.WoodPlanks)
	end
	for _, s in { -1, 1 } do
		-- แก้มบันไดหิน (sode-ishi) ลาดตามขั้น
		box(c, p, "HaidenStepCheek", math.min(s * 4.5, s * 5.1), math.max(s * 4.5, s * 5.1), 0, 1.4, H.zF, H.zF + 3.9, C.stone, Mat.Granite)
	end
	-- เสากลม 8 ต้น (แดงชาด) ด้านหน้า x = ±12, ±6 (ช่องกลางกว้าง 12) และเสาหลัง/ข้าง
	local colH = 11.5
	local function column(x: number, z: number)
		cyl(c, p, "HaidenPillar", 0.65, colH, x, fy + colH / 2, z, C.vermilion, Mat.Wood)
		cyl(c, p, "HaidenPillarBase", 0.9, 0.45, x, fy + 0.22, z, C.stoneDark, Mat.Granite)
	end
	for _, x in { -H.colX, -6, 6, H.colX } do
		column(x, H.colZf)
	end
	for _, x in { -H.colX, H.colX } do
		for _, z in { -37.5, H.colZb } do
			column(x, z)
		end
	end
	local beamY = fy + colH
	-- คานหน้า (นุกิ/ซาชิโมโนะ) + คานข้าง
	box(c, p, "HaidenBeamFront", -H.colX - 1.2, H.colX + 1.2, beamY, beamY + 1.1, H.colZf - 0.5, H.colZf + 0.5, C.vermilionDark, Mat.Wood)
	box(c, p, "HaidenBeamFront2", -H.colX - 0.6, H.colX + 0.6, beamY - 1.6, beamY - 0.8, H.colZf - 0.3, H.colZf + 0.3, C.vermilionDark, Mat.Wood)
	for _, sx in { -1, 1 } do
		box(c, p, "HaidenBeamSide", sx * H.colX - 0.5, sx * H.colX + 0.5, beamY, beamY + 1.1, H.colZb, H.colZf, C.vermilionDark, Mat.Wood)
	end
	box(c, p, "HaidenBeamBack", -H.colX - 0.5, H.colX + 0.5, beamY, beamY + 1.1, H.colZb - 0.5, H.colZb + 0.5, C.vermilionDark, Mat.Wood)
	-- ผนังไม้ธรรมชาติ: ข้าง 2 ด้าน + หลัง (เว้นช่องทางเดินมีหลังคากว้าง 6 สูง 9+) + ผนังหน้าห้องด้านใน (มีประตูไม้ซี่ปิด)
	local wallTop = beamY
	for _, sx in { -1, 1 } do
		box(c, p, "HaidenWallSide", sx * H.colX - 0.35, sx * H.colX + 0.35, fy, wallTop, H.colZb + 0.5, -37.5, C.wood, Mat.WoodPlanks)
		-- ผนังไม้ข้างโล่งช่วงระเบียงหน้า = ราว
	end
	for _, s in { -1, 1 } do
		box(c, p, "HaidenWallBack", math.min(s * 3.5, s * H.colX), math.max(s * 3.5, s * H.colX), fy, wallTop, H.colZb - 0.35, H.colZb + 0.35, C.wood, Mat.WoodPlanks)
	end
	box(c, p, "HaidenWallBackLintel", -3.5, 3.5, fy + 9.4, wallTop, H.colZb - 0.35, H.colZb + 0.35, C.wood, Mat.WoodPlanks)
	-- ประตูกลาง (ตรงกลาง) ไม้ซี่แนวตั้งสูง 9.5 กว้าง 12 ปิด: กรอบ + ซี่; ผนังข้างประตู
	local zDoor = -37.5
	box(c, p, "HaidenDoorFrameTop", -6.2, 6.2, fy + 9.3, fy + 10.2, zDoor - 0.45, zDoor + 0.45, C.woodDark, Mat.Wood)
	box(c, p, "HaidenDoorFrameBottom", -6.2, 6.2, fy, fy + 0.5, zDoor - 0.45, zDoor + 0.45, C.woodDark, Mat.Wood)
	for _, sx in { -6.2, 5.8 } do
		box(c, p, "HaidenDoorFrameSide", sx, sx + 0.4, fy, fy + 10.2, zDoor - 0.45, zDoor + 0.45, C.woodDark, Mat.Wood)
	end
	box(c, p, "HaidenDoorBack", -5.8, 5.8, fy + 0.5, fy + 9.3, zDoor - 0.1, zDoor + 0.1, C.woodDark, Mat.Wood)
	for i = 0, 15 do
		local x = -5.6 + i * (11.2 / 15)
		box(c, p, "HaidenDoorLatticeV", x - 0.1, x + 0.1, fy + 0.5, fy + 9.3, zDoor + 0.1, zDoor + 0.25, C.woodPale, Mat.Wood)
	end
	for _, y in { 2.6, 5.0, 7.4 } do
		box(c, p, "HaidenDoorLatticeH", -5.8, 5.8, fy + y, fy + y + 0.22, zDoor + 0.1, zDoor + 0.3, C.woodPale, Mat.Wood)
	end
	box(c, p, "HaidenDoorCenterBar", -0.2, 0.2, fy + 0.5, fy + 9.3, zDoor + 0.1, zDoor + 0.4, C.vermilionDark, Mat.Wood)
	for _, s in { -1, 1 } do
		box(c, p, "HaidenFrontWall", math.min(s * 6.2, s * H.colX), math.max(s * 6.2, s * H.colX), fy, wallTop, zDoor - 0.35, zDoor + 0.35, C.wood, Mat.WoodPlanks)
	end
	-- ราวระเบียง: หน้า 2 ข้างบันได (เว้นช่องบันไดกว้าง 9) + ข้างเข้าหาประตู
	kouran(c, p, -H.hw + 0.4, -4.8, H.zF + 0.1, H.zF + 0.1, fy)
	kouran(c, p, 4.8, H.hw - 0.4, H.zF + 0.1, H.zF + 0.1, fy)
	for _, s in { -1, 1 } do
		kouran(c, p, s * (H.hw - 0.4), s * (H.hw - 0.4), H.zB + 1.2, H.zF + 0.1, fy)
	end
	-- หลังคาคิริซึมะ (จั่วหันหน้าสู่ทางขึ้น): สันขนานแกน z, ชายคายื่น 4 รอบ
	local zFr, zBk = H.colZb - 1.8, H.colZf + 1.8 -- ปลายจั่วท้าย (z -45.8) / หน้า (z -29.2): zFr < zBk เสมอ (ขนาดเป็นบวก)
	local segs: { Seg } = { { 3.0, -4.2 }, { 3.4, -3.1 }, { 3.6, -1.9 }, { 3.6, -1.0 }, { 2.4, -0.2 } }
	local eaveY = beamY + 1.1
	local rise = 4.2 + 3.1 + 1.9 + 1.0 + 0.2
	local lorigin = CFrame.new(0, eaveY + rise, 0)
	local ptsL = roofSide(c, p, lorigin, -1, segs, zBk - zFr, (zFr + zBk) / 2, 0.8, C.kawara, Mat.Slate)
	local ptsR = roofSide(c, p, lorigin, 1, segs, zBk - zFr, (zFr + zBk) / 2, 0.8, C.kawara, Mat.Slate)
	-- เส้นกระเบื้อง (สันตามความลาด) เฉพาะส่วนบนสุดของแต่ละข้าง ไม่เพิ่มชิ้นมาก; สันหลังคาหนา
	part(c, p, "RoofRidge", Vector3.new(1.4, 0.9, zBk - zFr + 0.6), lorigin * CFrame.new(0, 0.3, (zFr + zBk) / 2), C.kawara, Mat.Slate)
	part(c, p, "RoofRidgeCap", Vector3.new(0.6, 0.4, zBk - zFr + 0.4), lorigin * CFrame.new(0, 0.95, (zFr + zBk) / 2), C.gold, Mat.Metal)
	-- แผ่นปิดชายคา (หน้าจั่วยื่น) บนปลายสุดตามโปรไฟล์ 2 ข้าง
	for _, s in { -1, 1 } do
		local pts = if s < 0 then ptsL else ptsR
		local lastp = pts[#pts]
		part(c, p, "EaveBoard", Vector3.new(0.5, 0.9, zBk - zFr), CFrame.new(lastp.X, eaveY + rise + lastp.Y - 0.1, (zFr + zBk) / 2), C.woodDark, Mat.Wood)
	end
	roofCrestAndOrnament(c, p, lorigin, zFr, zBk, zBk - zFr)
	-- ผนังจั่วหน้า/หลัง: สีปูนขาว + ลายไม้ตี + ตรา
	gableFill(c, p, lorigin, ptsL, ptsR, H.colZf - 0.2, 0.45, C.plaster, H.colX + 1.2, H.colX + 1.2)
	gableFill(c, p, lorigin, ptsL, ptsR, H.colZb + 0.2, 0.45, C.plaster, H.colX + 1.2, H.colX + 1.2)
	-- กรอบไม้ลายจั่ว (ขื่อ-ตั้ง)
	local ty = eaveY + 1.0
	box(c, p, "GableTieBeam", -H.colX - 1, H.colX + 1, ty + 0.5, ty + 1.2, H.colZf - 0.5, H.colZf, C.woodDark, Mat.Wood)
	kamon(c, p, 0, eaveY + 6.0, H.colZf + 0.05, 1)
	-- หัวสันหลังคา: ชิดมังกรทอง/โอนิกาวาระแบบเรียบ (กล่อง) ทั้งสองด้าน
	for _, z in { zFr + 0.4, zBk - 0.4 } do
		part(c, p, "ShachiBase", Vector3.new(1.6, 2.4, 1.0), lorigin * CFrame.new(0, 1.5, z), C.kawara, Mat.Slate)
	end
	-- ซองมาซุ (กล่องรับเงินบริจาค) + ระฆังสุซุ + โคมกระดาษ + กระดานชื่อ
	saisenBako(c, p, 0, -34.7)
	box(c, p, "SuzuBeam", -0.6, 0.6, beamY - 1.0, beamY - 0.2, -33.2, H.colZf + 0.3, C.vermilionDark, Mat.Wood)
	suzu(c, p, 0, beamY - 2.25, -32.6)
	for _, x in { -9, 9 } do
		chochinRed(c, p, x, beamY - 3.4, H.colZf + 0.3, true, true)
	end
	for _, x in { -3.2, 3.2 } do
		chochinRed(c, p, x, beamY - 3.4, H.colZf + 0.3, false, false)
	end
	-- กระดานชื่อศาลเจ้า (พื้นไม้ตัวอักษรทอง) แขวนใต้คานหน้า
	local board = box(c, p, "ShrineNameBoard", -3.4, 3.4, fy + 11.8, fy + 14.6, H.colZf, H.colZf + 0.4, C.woodDark, Mat.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- ด้าน +z (หันสู่ทางขึ้น)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "素々神社"
	label.TextColor3 = C.gold
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Parent = gui
	gui.LightInfluence = 0.2
	gui.Brightness = 1.4
	for _, y in { fy + 11.8, fy + 14.6 } do
		box(c, p, "NameBoardRim", -3.5, 3.5, y - 0.1, y + 0.1, H.colZf, H.colZf + 0.5, C.gold, Mat.Metal)
	end
	-- ตัวยึดชายคา (tokyo): ก้อนไม้ซ้อนใต้ชายคา 3 ชั้นที่หัวเสาหน้า
	for _, x in { -H.colX, -6, 6, H.colX } do
		box(c, p, "Bracket1", x - 1.1, x + 1.1, beamY + 1.1, beamY + 1.6, H.colZf - 1.1, H.colZf + 1.1, C.woodDark, Mat.Wood)
		box(c, p, "Bracket2", x - 1.7, x + 1.7, beamY + 1.6, beamY + 2.1, H.colZf - 1.7, H.colZf + 1.7, C.vermilionDark, Mat.Wood)
	end
	return { fy = fy, beamY = beamY }
end

---------------------------------------------------------------- ทางเดินมีหลังคา + ฮนเด็ง + ทามากากิ
local HONDEN = { zF = -52, zB = -61, hw = 5.5, floorY = 6.0 }

local function buildHonden(c: Ctx, f: Folder, hd: { fy: number, beamY: number })
	local p = folder(f, "Honden")
	local H = HONDEN
	-- ทางเดินมีหลังคา (กว้าง 7 สูงภายใน 10) z -45..-52 เสาเล็ก 4 ต้น + หลังคาจั่วแคบ
	local zW1, zW2 = -45, -51
	local fy = hd.fy
	box(c, p, "WalkwayFloor", -3.5, 3.5, 0, fy, -47, zW1, C.wood, Mat.WoodPlanks)
	for _, s in { -1, 1 } do
		for _, z in { -46, -50.2 } do
			box(c, p, "WalkwayPost", s * 3.4 - 0.3, s * 3.4 + 0.3, fy, fy + 10, z - 0.3, z + 0.3, C.vermilion, Mat.Wood)
		end
		box(c, p, "WalkwayBeam", s * 3.4 - 0.4, s * 3.4 + 0.4, fy + 10, fy + 10.7, zW2, zW1, C.vermilionDark, Mat.Wood)
		kouran(c, p, s * 3.4, s * 3.4, zW2 + 0.4, zW1 - 0.4, fy)
	end
	simpleGable(c, p, CFrame.new(0, 0, (zW1 + zW2) / 2), 5.0, -(zW1 - zW2) / 2 - 0.4, (zW1 - zW2) / 2 + 0.4, fy + 10.7, 3.0, C.copper, Mat.Metal)
	-- (หมุนให้สันขนาน z ตามค่าเริ่มต้น: ไม่ต้องหมุน)
	-- บันไดขึ้นฮนเด็ง 5 ขั้น (กว้าง 5)
	local hfy = H.floorY
	local base = 1.4
	box(c, p, "HondenBaseLow", -H.hw - 1.6, H.hw + 1.6, 0, base, H.zB - 1.2, H.zF + 1.5, C.stoneDark, Mat.Granite)
	box(c, p, "HondenBaseHigh", -H.hw - 0.8, H.hw + 0.8, base, hfy - 0.25, H.zB - 0.4, H.zF + 0.8, C.stone, Mat.Granite)
	local steps = 5
	local run = 1.0
	for i = 1, steps do
		local top = fy + (hfy - fy) * i / steps
		local z1 = -47 - (i - 1) * run
		box(c, p, "HondenStep", -2.5, 2.5, 0, top, z1 - run, z1, C.woodPale, Mat.WoodPlanks)
	end
	-- ตัวอาคาร: พื้น + เสากลม 4 + ผนังไม้ + ประตูไม้ปิด + ราวประดับ
	box(c, p, "HondenFloor", -H.hw, H.hw, hfy - 0.25, hfy, H.zB, H.zF, C.wood, Mat.WoodPlanks)
	local ch = 9.6
	for _, x in { -H.hw + 0.4, H.hw - 0.4 } do
		for _, z in { H.zF - 0.4, H.zB + 0.4 } do
			cyl(c, p, "HondenPillar", 0.55, ch, x, hfy + ch / 2, z, C.vermilion, Mat.Wood)
		end
	end
	local topB = hfy + ch
	box(c, p, "HondenBeamFront", -H.hw - 0.4, H.hw + 0.4, topB, topB + 1.0, H.zF - 0.8, H.zF, C.vermilionDark, Mat.Wood)
	box(c, p, "HondenBeamBack", -H.hw - 0.4, H.hw + 0.4, topB, topB + 1.0, H.zB, H.zB + 0.8, C.vermilionDark, Mat.Wood)
	for _, s in { -1, 1 } do
		box(c, p, "HondenWallSide", s * H.hw - 0.3, s * H.hw + 0.3, hfy, topB, H.zB, H.zF, C.wood, Mat.WoodPlanks)
		box(c, p, "HondenBeamSide", s * H.hw - 0.5, s * H.hw + 0.5, topB, topB + 1.0, H.zB, H.zF, C.vermilionDark, Mat.Wood)
	end
	box(c, p, "HondenWallBack", -H.hw, H.hw, hfy, topB, H.zB, H.zB + 0.5, C.wood, Mat.WoodPlanks)
	-- ประตูไม้บานคู่ปิด (กว้าง 5 สูง 9.3) + ซี่ + ที่จับ
	local zd = H.zF - 0.4
	box(c, p, "HondenDoor", -2.5, 2.5, hfy, hfy + 9.3, zd + 0.1, zd + 0.5, C.woodDark, Mat.Wood)
	for i = 0, 9 do
		local x = -2.3 + i * 0.5
		box(c, p, "HondenDoorSlat", x, x + 0.14, hfy + 0.3, hfy + 9.0, zd + 0.5, zd + 0.65, C.woodPale, Mat.Wood)
	end
	box(c, p, "HondenDoorBar", -0.12, 0.12, hfy, hfy + 9.3, zd + 0.5, zd + 0.75, C.vermilionDark, Mat.Wood)
	for _, s in { -1, 1 } do
		box(c, p, "HondenFrontWall", math.min(s * 2.5, s * (H.hw - 0.3)), math.max(s * 2.5, s * (H.hw - 0.3)), hfy, topB, zd + 0.1, zd + 0.5, C.wood, Mat.WoodPlanks)
	end
	-- ราวประดับรอบระเบียงฮนเด็ง (เว้นช่องบันได 5.4)
	kouran(c, p, -H.hw - 0.8, -3.0, H.zF + 0.8, H.zF + 0.8, hfy - 0.2)
	kouran(c, p, 3.0, H.hw + 0.8, H.zF + 0.8, H.zF + 0.8, hfy - 0.2)
	for _, s in { -1, 1 } do
		kouran(c, p, s * (H.hw + 0.8), s * (H.hw + 0.8), H.zB - 0.4, H.zF + 0.8, hfy - 0.2)
	end
	-- หลังคานางาเระซึคุริ: สันขนาน x, ลาดหน้ายาว (+z) ลาดหลังสั้น ทองแดงเขียว
	local ridgeZ = -57
	local rot = CFrame.new(0, 0, ridgeZ) * CFrame.Angles(0, math.rad(90), 0)
	-- หมุน +90: local +x -> world -z; ข้างที่ side=-1 (x ติดลบ) -> world +z (ด้านหน้า)
	local eaveY2 = topB + 1.0
	local segsF: { Seg } = { { 2.2, -2.8 }, { 2.4, -1.9 }, { 2.2, -1.1 }, { 1.7, -0.6 } }
	local segsB: { Seg } = { { 2.4, -3.0 }, { 2.2, -2.0 }, { 1.4, -1.4 } }
	local rise = 6.4
	local o2 = rot * CFrame.new(0, eaveY2 + rise, 0)
	local zLen = (H.hw + 2.6) * 2 -- ยาวตามสัน (world x)
	local pF = roofSide(c, p, o2, -1, segsF, zLen, 0, 0.7, C.copper, Mat.Metal)
	local pB = roofSide(c, p, o2, 1, segsB, zLen, 0, 0.7, C.copper, Mat.Metal)
	part(c, p, "HondenRidge", Vector3.new(1.2, 0.8, zLen + 0.5), o2 * CFrame.new(0, 0.25, 0), C.copperDark, Mat.Metal)
	-- ผนังจั่วข้าง (2 ด้าน x = ±(hw+2.6)) ถมปูนขาว
	for _, s in { -1, 1 } do
		-- ใน local o2 z แกนสัน => world x; gableFill ใช้ z ท้องถิ่น
		gableFill(c, p, o2, pF, pB, s * (H.hw - 0.2), 0.4, C.plaster, H.zF - ridgeZ, ridgeZ - H.zB)
	end
	-- ชิกิ + คัตสึโอกิบนสันฮนเด็ง (แบบเดียวกับไฮเด็ง สั้นกว่า)
	local nK = 5
	for i = 0, nK do
		local z = -zLen / 2 + 1.2 + i * ((zLen - 2.4) / nK)
		part(c, p, "Katsuogi", Vector3.new(2.6, 0.7, 0.7), o2 * CFrame.new(0, 1.0, z), C.woodDark, Mat.Wood).Shape = Enum.PartType.Cylinder
	end
	for _, z in { -zLen / 2 + 0.2, zLen / 2 - 0.2 } do
		for _, s in { -1, 1 } do
			part(c, p, "Chigi", Vector3.new(0.45, 5.2, 0.6), o2 * CFrame.new(0, 2.8, z) * CFrame.Angles(0, 0, math.rad(s * 28)), C.woodPale, Mat.Wood)
			part(c, p, "ChigiTip", Vector3.new(0.5, 0.5, 0.65), o2 * CFrame.new(s * -1.22, 5.1, z) * CFrame.Angles(0, 0, math.rad(s * 28)), C.gold, Mat.Metal)
		end
	end
	local orb = BK.ball("ShrineOrb", 1.6, Vector3.new(c.cx, c.y + eaveY2 + rise + 1.9, c.cz + ridgeZ), C.gold, p, Mat.Metal)
	finish(orb)
	-- โคมไฟข้างบันไดฮนเด็ง
	local l = ball(c, p, "HondenLantern", 0.9, H.hw + 0.3, hfy + 7.3, H.zF + 0.6, C.glow, Mat.Neon)
	l.Transparency = 0.15
	BK.noCollide(l)
	lamp(l, C.glow, 20, 0.8)
end

local function buildTamagaki(c: Ctx, f: Folder)
	local p = folder(f, "Tamagaki")
	-- รั้วไม้ตั้งเตี้ย สูง 4 (ราวบนล่าง + เสาแหลมทุก 3 studs) ล้อม x ±13.5 z -45.5..-62.5 ข้างและหลัง (หน้าติดผนังหลังไฮเด็ง)
	local x0, zB, zA = 13.5, -62.5, -45.5
	local h = 4.0
	local function run(x1: number, z1: number, x2: number, z2: number)
		local len = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
		local n = math.floor(len / 3)
		for i = 0, n do
			local t = i / n
			local x, z = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
			box(c, p, "TamagakiPost", x - 0.25, x + 0.25, 1.4, 1.4 + h + 0.4, z - 0.25, z + 0.25, C.woodPale, Mat.Wood)
			box(c, p, "TamagakiCap", x - 0.12, x + 0.12, 1.4 + h + 0.4, 1.4 + h + 0.8, z - 0.12, z + 0.12, C.woodPale, Mat.Wood)
		end
		for _, y in { 1.4 + 1.1, 1.4 + 2.8 } do
			if math.abs(x2 - x1) > math.abs(z2 - z1) then
				box(c, p, "TamagakiRail", math.min(x1, x2), math.max(x1, x2), y, y + 0.28, z1 - 0.15, z1 + 0.15, C.woodDark, Mat.Wood)
			else
				box(c, p, "TamagakiRail", x1 - 0.15, x1 + 0.15, y, y + 0.28, math.min(z1, z2), math.max(z1, z2), C.woodDark, Mat.Wood)
			end
		end
	end
	run(-x0, zB, x0, zB)
	run(-x0, zB, -x0, zA)
	run(x0, zB, x0, zA)
	-- แนวหินก้อนเตี้ยรองรั้ว
	box(c, p, "TamagakiSill", -x0 - 0.5, x0 + 0.5, 0, 1.4, zB - 0.5, zB + 0.5, C.stoneDark, Mat.Granite)
	for _, s in { -1, 1 } do
		box(c, p, "TamagakiSill", s * x0 - 0.5, s * x0 + 0.5, 0, 1.4, zB, zA, C.stoneDark, Mat.Granite)
	end
	-- กรวดขาวในเขตศักดิ์สิทธิ์
	box(c, p, "TamagakiGravel", -x0 + 0.5, x0 - 0.5, 0, 0.1, zB + 0.5, zA, C.gravel, Mat.Pebble)
end

---------------------------------------------------------------- 7) ต้นไม้ใหญ่รอบลาน
local function trees(c: Ctx, f: Folder)
	local p = folder(f, "Trees")
	local tmp = Instance.new("Folder")
	local spots = {
		{ -27, -6, 24 }, { -27, -28, 28 }, { -27, -52, 24 },
		{ 27, -20, 26 }, { 27, -40, 24 }, { 27, -56, 28 },
	}
	for _, s in spots do
		BK.pine(tmp, c.cx + s[1], c.cz + s[2], s[3])
	end
	for _, ch in tmp:GetChildren() do
		if ch:IsA("Model") then
			ch:PivotTo(ch:GetPivot() + Vector3.new(0, c.y, 0))
		elseif ch:IsA("BasePart") then
			ch.Position += Vector3.new(0, c.y, 0)
			finish(ch)
		end
		ch.Parent = p
	end
	tmp:Destroy()
end

---------------------------------------------------------------- ทั้งศาลเจ้า
function ShrineKit.build(parent: Instance, cx: number, cz: number, topY: number)
	local t0 = os.clock()
	lightCount, partCount = 0, 0
	local f = folder(parent, "Shrine")
	local c: Ctx = { f = f, cx = cx, cz = cz, y = topY }
	buildTerrace(c, f)
	buildSando(c, f)
	local kf = folder(f, "Komainu")
	komainu(c, kf, -8, 12, true)
	komainu(c, kf, 8, 12, false)
	temizuya(c, f)
	local tf = folder(f, "Toro")
	for _, z in { 2, -8, -18 } do
		for _, s in { -1, 1 } do
			toro(c, tf, s * 7.5, z, z == -8)
		end
	end
	emaRack(c, f)
	omikujiRack(c, f)
	omamoriStall(c, f)
	local hd = buildHaiden(c, f)
	buildHonden(c, f, hd)
	buildTamagaki(c, f)
	trees(c, f)
	f:SetAttribute("PartCount", partCount)
	f:SetAttribute("LightCount", lightCount)
	print(string.format("[ShrineKit] ศาลเจ้า %d ชิ้น, PointLight %d ดวง, %.2fs", partCount, lightCount, os.clock() - t0))
end

return ShrineKit
