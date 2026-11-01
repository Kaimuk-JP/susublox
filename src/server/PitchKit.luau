--!strict
-- สนามกีฬาโรงเรียน (ฝั่งตะวันตกเฉียงใต้) x -142..-48, z 52..128: ลู่วิ่งสีแดงน้ำตาล + สนามฟุตบอลหญ้าตัดลาย + ประตู/ตาข่าย
-- ม้านั่งสำรอง กระดานคะแนน เสาไฟ รั้วหลังประตู อัฒจันทร์ ฯลฯ  สนามใช้พื้นหญ้าแบบ Part (ไม่มี Terrain Decoration สูง)
-- ค่าคงที่ของ Layout ใช้ร่วมกับ SoccerPitch.server (ตำแหน่งประตู ขนาดสนาม)
local PhysicsService = game:GetService("PhysicsService")

local BK = require(script.Parent.BuildKit)

local PitchKit = {}

local hex = Color3.fromHex

-- พิกัดในโลก: กลางสนาม (CX, CZ) ยาวตามแกน X; HL/HW = ครึ่งความยาว/ความกว้างของพื้นที่เล่น (เส้นขาว)
PitchKit.Layout = table.freeze({
	CX = -95,
	CZ = 90,
	HL = 35, -- เส้นประตู x = CX ± 35 (สนามยาว 70)
	HW = 26, -- เส้นข้าง z = CZ ± 26 (กว้าง 52)
	GrassHX = 39, -- ขอบหญ้า (มีที่ว่างหลังเส้น 4 stud)
	GrassHZ = 30,
	GoalW = 21, -- ประตูมาตรฐาน 7.32 m = 21 studs
	GoalH = 7, -- 2.44 m = 7 studs
	GoalD = 3.5,
	Floor = 0.66, -- ผิวพื้นสนาม (Part ล่องหนที่ชน) ชิ้นหญ้าตัดลายอยู่สูงกว่าเล็กน้อย
	Track = 0.5,
})

local L = PitchKit.Layout
local CX, CZ = L.CX, L.CZ

local COL = {
	track = hex("9A5A40"),
	trackLine = hex("E6E1D6"),
	line = hex("ECEAE0"),
	grassA = hex("6F9A55"),
	grassB = hex("628C4A"),
	frame = hex("EEEEEA"),
	net = hex("D8D8D4"),
	curb = hex("B4AEA2"),
	metal = hex("5A5F66"),
	dark = hex("2A2C32"),
	wood = hex("8A6A4C"),
	roof = hex("3E5A78"),
	sand = hex("D8C79A"),
	mat = hex("3E6FA8"),
}

local function registerGroups()
	for _, g in { "PitchBall", "PitchWall" } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(g)
		end)
	end
	pcall(function()
		-- ผู้เล่น/บอทเดินทะลุกำแพงล่องหนได้ มีแค่ลูกบอลที่ชน
		PhysicsService:CollisionGroupSetCollidable("PitchWall", "Default", false)
	end)
end

local function plain(p: BasePart): BasePart
	BK.noCollide(p)
	return p
end

local function floorProps(p: BasePart)
	p.CustomPhysicalProperties = PhysicalProperties.new(1, 0.7, 0.3, 100, 1)
end

-- เส้นบนสนาม: แถบบางเรียบ ๆ จาก (x1,z1) ไป (x2,z2) สูง y..y+0.02 (ไม่ซ้อนกับเส้นอื่นในระดับเดียวกัน)
local function seg(parent: Instance, x1: number, z1: number, x2: number, z2: number, y: number, width: number, color: Color3, name: string?)
	local len = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	local mid = Vector3.new((x1 + x2) / 2, y, (z1 + z2) / 2)
	local p = BK.part(name or "FieldLine", Vector3.new(len + 0.02, 0.03, width), mid, color, parent, Enum.Material.SmoothPlastic)
	p.CFrame = CFrame.lookAt(mid, Vector3.new(x2, y, z2)) * CFrame.Angles(0, math.rad(90), 0)
	plain(p)
end

local function arc(parent: Instance, cx: number, cz: number, r: number, a1: number, a2: number, n: number, y: number, keep: ((number, number) -> boolean)?)
	local px, pz
	for i = 0, n do
		local a = math.rad(a1 + (a2 - a1) * i / n)
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		if px and (not keep or keep((px + x) / 2, (pz + z) / 2)) then
			seg(parent, px, pz, x, z, y, 0.5, COL.line)
		end
		px, pz = x, z
	end
end

---------------------------------------------------------------- ลู่วิ่ง + พื้นสนาม + เส้น
local function buildGround(f: Folder)
	local Y = L.Track
	BK.box("TrackBase", -142, -48, -3, Y, 52, 128, COL.track, f, Enum.Material.Pavement)
	-- เส้นแบ่งเลนวิ่ง 3 เลน (ลู่กว้าง 8): วงสี่เหลี่ยมซ้อนใน 2 วง + ขอบนอก
	local ty = Y + 0.02
	for _, inset in { 0.4, 2.67, 5.33 } do
		local x1, x2, z1, z2 = -142 + inset, -48 - inset, 52 + inset, 128 - inset
		seg(f, x1, z1, x2, z1, ty, 0.25, COL.trackLine, "LaneLine")
		seg(f, x1, z2, x2, z2, ty, 0.25, COL.trackLine, "LaneLine")
		seg(f, x1, z1, x1, z2, ty, 0.25, COL.trackLine, "LaneLine")
		seg(f, x2, z1, x2, z2, ty, 0.25, COL.trackLine, "LaneLine")
	end
	-- เส้นสตาร์ท/เส้นชัยข้ามลู่ด้านใต้ (z 120..128) ที่ x = -75
	seg(f, -75, 120.2, -75, 127.8, ty + 0.01, 0.5, COL.trackLine, "StartLine")
	-- ขอบคันหินรอบหญ้า
	local gx1, gx2, gz1, gz2 = CX - L.GrassHX, CX + L.GrassHX, CZ - L.GrassHZ, CZ + L.GrassHZ
	BK.box("Curb", gx1 - 0.6, gx2 + 0.6, Y, Y + 0.28, gz1 - 0.6, gz1, COL.curb, f)
	BK.box("Curb", gx1 - 0.6, gx2 + 0.6, Y, Y + 0.28, gz2, gz2 + 0.6, COL.curb, f)
	BK.box("Curb", gx1 - 0.6, gx1, Y, Y + 0.28, gz1, gz2, COL.curb, f)
	BK.box("Curb", gx2, gx2 + 0.6, Y, Y + 0.28, gz1, gz2, COL.curb, f)
	-- พื้นชนล่องหน (ลูกบอลกลิ้งเรียบไม่สะดุดรอยต่อลายหญ้า) + หญ้าตัดลายเป็นแถบ ไม่ชน
	local floor = BK.box("PitchFloor", gx1, gx2, 0.2, L.Floor, gz1, gz2, COL.grassA, f, Enum.Material.Grass)
	floor.Transparency = 1
	floorProps(floor)
	local stripes = 13
	local w = (gx2 - gx1) / stripes
	for i = 0, stripes - 1 do
		local p = BK.box("FieldGrass", gx1 + i * w, gx1 + (i + 1) * w, L.Floor - 0.04, L.Floor + 0.02, gz1, gz2, if i % 2 == 0 then COL.grassA else COL.grassB, f, Enum.Material.Grass)
		plain(p)
	end
	-- ผนังล่องหนรอบหญ้า (เฉพาะลูกบอลชน) สูง 22 + เพดานกันบอลลอยออก
	local function wall(x1: number, x2: number, z1: number, z2: number)
		local p = BK.box("BallWall", x1, x2, 0, 22, z1, z2, COL.grassA, f)
		p.Transparency = 1
		p.CanQuery = false
		p.CollisionGroup = "PitchWall"
	end
	wall(gx1 - 1, gx2 + 1, gz1 - 1, gz1)
	wall(gx1 - 1, gx2 + 1, gz2, gz2 + 1)
	wall(gx1 - 1, gx1, gz1, gz2)
	wall(gx2, gx2 + 1, gz1, gz2)
	local roof = BK.box("BallCeiling", gx1, gx2, 22, 23, gz1, gz2, COL.grassA, f)
	roof.Transparency = 1
	roof.CanQuery = false
	roof.CollisionGroup = "PitchWall"

	-- เส้นสนาม (สูง 0.69)
	local ly = L.Floor + 0.045
	local x1, x2, z1, z2 = CX - L.HL, CX + L.HL, CZ - L.HW, CZ + L.HW
	seg(f, x1, z1, x2, z1, ly, 0.5, COL.line, "Touchline")
	seg(f, x1, z2, x2, z2, ly, 0.5, COL.line, "Touchline")
	seg(f, x1, z1, x1, z2, ly, 0.5, COL.line, "GoalLine")
	seg(f, x2, z1, x2, z2, ly, 0.5, COL.line, "GoalLine")
	seg(f, CX, z1, CX, z2, ly, 0.5, COL.line, "HalfwayLine")
	-- วงกลางสนาม (r 7.5) + จุดกลาง
	arc(f, CX, CZ, 7.5, 0, 360, 40, ly)
	local spot = BK.cylinder("CentreSpot", 0.6, 0.03, Vector3.new(CX, ly, CZ), COL.line, f, Enum.Material.SmoothPlastic)
	plain(spot)
	-- กรอบเขตโทษ (ลึก 12 กว้าง 40) กรอบประตู (ลึก 5 กว้าง 30) จุดโทษห่าง 9 + ครึ่งวงโทษ r 7
	for _, side in { -1, 1 } do
		local gl = CX + side * L.HL
		local function X(depth: number): number
			return gl - side * depth
		end
		seg(f, X(12), CZ - 20, X(12), CZ + 20, ly, 0.5, COL.line, "PenaltyBox")
		seg(f, gl, CZ - 20, X(12), CZ - 20, ly, 0.5, COL.line, "PenaltyBox")
		seg(f, gl, CZ + 20, X(12), CZ + 20, ly, 0.5, COL.line, "PenaltyBox")
		seg(f, X(5), CZ - 15, X(5), CZ + 15, ly, 0.5, COL.line, "GoalArea")
		seg(f, gl, CZ - 15, X(5), CZ - 15, ly, 0.5, COL.line, "GoalArea")
		seg(f, gl, CZ + 15, X(5), CZ + 15, ly, 0.5, COL.line, "GoalArea")
		plain(BK.cylinder("PenaltySpot", 0.5, 0.03, Vector3.new(X(9), ly, CZ), COL.line, f, Enum.Material.SmoothPlastic))
		-- ครึ่งวงโทษอยู่นอกกรอบเขตโทษเท่านั้น
		local spotX = X(9)
		local startA = if side == 1 then 180 - 55 else -55
		local endA = if side == 1 then 180 + 55 else 55
		arc(f, spotX, CZ, 7, startA, endA, 14, ly, function(mx: number): boolean
			return (mx - X(12)) * -side > 0
		end)
	end
	-- ส่วนโค้งมุมสนาม (r 1.6)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local cx, cz = CX + sx * L.HL, CZ + sz * L.HW
			local a0 = if sx == -1 then (if sz == -1 then 0 else 270) else (if sz == -1 then 90 else 180)
			arc(f, cx, cz, 1.6, a0, a0 + 90, 5, ly)
			-- ธงมุม
			plain(BK.cylinder("CornerFlagPole", 0.07, 4, Vector3.new(cx, L.Floor + 2, cz), hex("E8E8E0"), f, Enum.Material.Metal))
			local flag = BK.part("CornerFlagCloth", Vector3.new(1, 0.7, 0.04), Vector3.new(cx + 0.5, L.Floor + 3.6, cz), hex("D6402F"), f, Enum.Material.Fabric)
			plain(flag)
		end
	end
end

---------------------------------------------------------------- ประตูฟุตบอล: โครงท่อ + ตาข่ายเส้นบาง (ไม่ชนยกเว้นโครงกรอบหน้า)
local function net(f: Folder, a: Vector3, b: Vector3)
	local len = (b - a).Magnitude
	local p = BK.part("Net", Vector3.new(0.05, 0.05, len), (a + b) / 2, COL.net, f, Enum.Material.SmoothPlastic)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Transparency = 0.25
	plain(p)
end

local function tube(f: Folder, a: Vector3, b: Vector3, r: number, collide: boolean)
	local len = (b - a).Magnitude
	local p = BK.part("GoalFrame", Vector3.new(len, r * 2, r * 2), (a + b) / 2, COL.frame, f, Enum.Material.Metal)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	if not collide then
		plain(p)
	end
end

local function buildGoal(f: Folder, side: number)
	local gx = CX + side * L.HL -- เส้นประตู
	local bx = gx + side * L.GoalD -- ด้านหลังประตู
	local y0 = L.Floor
	local H, HB = L.GoalH, L.GoalH - 1
	local z1, z2 = CZ - L.GoalW / 2, CZ + L.GoalW / 2
	local model = Instance.new("Folder")
	model.Name = "Goal"
	model.Parent = f
	-- กรอบหน้า (ชน): เสา 2 ต้น + คานบน
	tube(model, Vector3.new(gx, y0, z1), Vector3.new(gx, y0 + H, z1), 0.28, true)
	tube(model, Vector3.new(gx, y0, z2), Vector3.new(gx, y0 + H, z2), 0.28, true)
	tube(model, Vector3.new(gx, y0 + H, z1), Vector3.new(gx, y0 + H, z2), 0.28, true)
	-- โครงหลัง (ไม่ชน)
	tube(model, Vector3.new(bx, y0, z1), Vector3.new(bx, y0 + HB, z1), 0.2, false)
	tube(model, Vector3.new(bx, y0, z2), Vector3.new(bx, y0 + HB, z2), 0.2, false)
	tube(model, Vector3.new(bx, y0 + HB, z1), Vector3.new(bx, y0 + HB, z2), 0.2, false)
	for _, z in { z1, z2 } do
		tube(model, Vector3.new(gx, y0 + H, z), Vector3.new(bx, y0 + HB, z), 0.2, false)
		tube(model, Vector3.new(gx, y0, z), Vector3.new(bx, y0, z), 0.15, false)
	end
	-- ตาข่าย: หลัง (เส้นตั้ง/นอน) บน (ขวางแกน X/Z) ข้าง
	local step = 1.75
	local nz = math.floor(L.GoalW / step + 0.5)
	for i = 0, nz do
		local z = z1 + L.GoalW * i / nz
		net(model, Vector3.new(bx, y0, z), Vector3.new(bx, y0 + HB, z)) -- หลัง ตั้ง
		net(model, Vector3.new(gx, y0 + H, z), Vector3.new(bx, y0 + HB, z)) -- บน ตามยาว
	end
	for j = 1, 5 do
		local y = y0 + HB * j / 6
		net(model, Vector3.new(bx, y, z1), Vector3.new(bx, y, z2)) -- หลัง นอน
	end
	for k = 1, 3 do
		local t = k / 4
		local x = gx + side * L.GoalD * t
		net(model, Vector3.new(x, y0 + H + (HB - H) * t, z1), Vector3.new(x, y0 + H + (HB - H) * t, z2)) -- บน ขวาง
	end
	for _, z in { z1, z2 } do
		for k = 1, 3 do
			local x = gx + side * L.GoalD * k / 4
			net(model, Vector3.new(x, y0, z), Vector3.new(x, y0 + H + (HB - H) * k / 4, z))
		end
		for j = 1, 5 do
			local t = j / 6
			net(model, Vector3.new(gx, y0 + H * t, z), Vector3.new(bx, y0 + HB * t, z))
		end
	end
end

---------------------------------------------------------------- รั้วหลังประตู + ป้ายแบนเนอร์ 全国大会出場!
local function buildBackstops(f: Folder)
	for _, side in { -1, 1 } do
		local x = CX + side * (L.GrassHX - 0.5)
		BK.fence(f, x, CZ - 28, x, CZ + 28, 12, hex("4C5560"))
		-- ลวดตาข่ายต่ำ ๆ ต่อไปตามเส้นข้างหลังประตู (กันบอลลงลู่)
	end
	-- แบนเนอร์บนรั้วฝั่งตะวันตก หันเข้าสนาม (+X)
	local banner = BK.sign(f, "全国大会出場!", Vector3.new(22, 3.6, 0.2), Vector3.new(CX - L.GrassHX + 0.9, 9.8, CZ), -90, hex("B8322A"), hex("F4F0E4"))
	BK.jpFont(banner)
	banner.Name = "SchoolBanner"
	-- แบนเนอร์ฝั่งตะวันออก (ชื่อโรงเรียน)
	local b2 = BK.sign(f, "SUSUBLOX HIGH 頑張れ!", Vector3.new(22, 3.6, 0.2), Vector3.new(CX + L.GrassHX - 0.9, 9.8, CZ), 90, hex("2F4F8A"), hex("F4F0E4"))
	BK.jpFont(b2)
	b2.Name = "SchoolBanner"
end

---------------------------------------------------------------- ม้านั่งสำรองมีหลังคา + กระดานคะแนน + เสาไฟ
local function benchShelter(f: Folder, cx: number, color: Color3, name: string)
	local z = CZ + L.GrassHZ - 1.4 -- ริมหญ้าด้านใต้ นอกเส้นข้าง
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = f
	BK.box("Seat", cx - 6, cx + 6, 1.4, 1.7, z - 0.9, z + 0.3, COL.wood, m, Enum.Material.WoodPlanks)
	BK.box("SeatBack", cx - 6, cx + 6, 1.7, 3.2, z + 0.3, z + 0.55, COL.wood, m, Enum.Material.WoodPlanks)
	for _, dx in { -5.6, 5.6 } do
		BK.box("Leg", cx + dx - 0.15, cx + dx + 0.15, L.Floor, 1.4, z - 0.7, z + 0.1, COL.dark, m, Enum.Material.Metal)
		BK.box("Post", cx + dx - 0.15, cx + dx + 0.15, L.Floor, 7.2, z + 0.65, z + 0.95, COL.metal, m, Enum.Material.Metal)
	end
	BK.box("Roof", cx - 7, cx + 7, 7.2, 7.5, z - 1.8, z + 1.2, color, m, Enum.Material.Metal)
	local back = BK.box("BackPanel", cx - 6, cx + 6, 2.4, 7.2, z + 0.95, z + 1.05, hex("C8D8DC"), m, Enum.Material.Glass)
	back.Transparency = 0.6
	-- ถุงลูกบอล + กรวย
	local bag = BK.ball("BallBag", 1.9, Vector3.new(cx + 4.2, 2.65, z - 0.3), hex("D9D4C6"), m, Enum.Material.Fabric)
	bag.Size = Vector3.new(1.9, 1.8, 1.9)
	BK.noCollide(bag)
end

local function buildScoreboard(f: Folder)
	local z = CZ - L.GrassHZ + 0.9 -- ขอบหญ้าด้านเหนือ หันหน้าไป +Z (อัฒจันทร์ฝั่งใต้ + กลางสนาม)
	local m = Instance.new("Model")
	m.Name = "ScoreboardStand"
	m.Parent = f
	for _, dx in { -7, 7 } do
		BK.box("BoardPost", CX + dx - 0.3, CX + dx + 0.3, L.Floor, 8, z - 0.3, z + 0.3, COL.metal, m, Enum.Material.Metal)
	end
	local p = BK.part("Scoreboard", Vector3.new(18, 6.5, 0.6), Vector3.new(CX, 11, z), hex("14181C"), m, Enum.Material.Metal)
	p.CFrame = CFrame.new(CX, 11, z) * CFrame.Angles(0, math.rad(180), 0)
	for _, dx in { -7, 7 } do
		BK.box("BoardPost", CX + dx - 0.3, CX + dx + 0.3, 8, 8.3, z - 0.3, z + 0.3, COL.metal, m, Enum.Material.Metal)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ScoreGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = p
	local function label(name: string, text: string, pos: UDim2, size: UDim2, color: Color3)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Position, l.Size = pos, size
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextColor3 = color
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.Parent = gui
	end
	local function chip(name: string, pos: UDim2, color: Color3)
		local c = Instance.new("Frame")
		c.Name = name
		c.Position, c.Size = pos, UDim2.fromScale(0.04, 0.34)
		c.BackgroundColor3 = color
		c.BorderSizePixel = 0
		c.Parent = gui
	end
	chip("HomeChip", UDim2.fromScale(0.03, 0.12), hex("F2F2EE"))
	chip("AwayChip", UDim2.fromScale(0.93, 0.12), hex("D6402F"))
	label("HomeName", "HOME", UDim2.fromScale(0.08, 0.1), UDim2.fromScale(0.22, 0.38), hex("F2F2EE"))
	label("HomeScore", "0", UDim2.fromScale(0.3, 0.05), UDim2.fromScale(0.14, 0.5), hex("FFD35A"))
	label("AwayScore", "0", UDim2.fromScale(0.56, 0.05), UDim2.fromScale(0.14, 0.5), hex("FFD35A"))
	label("AwayName", "AWAY", UDim2.fromScale(0.71, 0.1), UDim2.fromScale(0.22, 0.38), hex("F2F2EE"))
	label("Clock", "05:00", UDim2.fromScale(0.36, 0.52), UDim2.fromScale(0.28, 0.4), hex("7CE08A"))
	label("Status", "1st HALF", UDim2.fromScale(0.05, 0.6), UDim2.fromScale(0.28, 0.28), hex("B8C0C8"))
	label("Half", "", UDim2.fromScale(0.67, 0.6), UDim2.fromScale(0.28, 0.28), hex("B8C0C8"))
	-- ด้านหลังกระดาน
	local back = Instance.new("SurfaceGui")
	back.Face = Enum.NormalId.Back
	back.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	back.PixelsPerStud = 30
	back.Parent = p
	local bl = Instance.new("TextLabel")
	bl.Size = UDim2.fromScale(1, 1)
	bl.BackgroundTransparency = 1
	bl.Text = "SUSUBLOX HIGH"
	bl.TextColor3 = hex("C8CED4")
	bl.Font = Enum.Font.GothamBold
	bl.TextScaled = true
	bl.Parent = back
end

local function floodlight(f: Folder, x: number, z: number)
	local m = Instance.new("Model")
	m.Name = "Floodlight"
	m.Parent = f
	BK.cylinder("Pole", 0.45, 24, Vector3.new(x, 12.5, z), COL.metal, m, Enum.Material.Metal)
	BK.cylinder("PoleBase", 1, 1.2, Vector3.new(x, 0.9, z), COL.dark, m, Enum.Material.Metal)
	local dir = Vector3.new(CX - x, 0, CZ - z).Unit
	local head = CFrame.new(x, 24.6, z) * CFrame.new(dir * 1.2)
	local frame = BK.part("LampBank", Vector3.new(4.4, 2.6, 0.5), head.Position, COL.dark, m, Enum.Material.Metal)
	frame.CFrame = CFrame.lookAt(head.Position, head.Position + dir) * CFrame.Angles(0, 0, 0)
	BK.noCollide(frame)
	for r = 0, 1 do
		for c = 0, 2 do
			local lens = BK.part("Lens", Vector3.new(1.1, 1, 0.2), Vector3.zero, hex("E8E2CC"), m, Enum.Material.SmoothPlastic)
			lens.CFrame = frame.CFrame * CFrame.new(-1.4 + c * 1.4, -0.55 + r * 1.1, -0.34)
			BK.noCollide(lens)
		end
	end
	-- ไฟโซนอุ่น: ชื่อ LampLight ให้ NightLights ฝั่ง client เปิดเฉพาะเย็น/คืน
	local l = Instance.new("PointLight")
	l.Name = "LampLight"
	l.Color = hex("FFE2B0")
	l.Range = 48
	l.Brightness = 2.2
	l.Shadows = false
	l.Parent = frame
end

---------------------------------------------------------------- อัฒจันทร์ 4 แถว + ของประกอบโรงเรียน (ฝั่งใต้ z 130..)
local function buildStands(f: Folder)
	local m = Instance.new("Model")
	m.Name = "Bleachers"
	m.Parent = f
	local x1, x2 = -121, -69
	local y0 = L.Track
	for r = 0, 3 do
		local z1 = 131 + r * 2.2
		local top = y0 + 1.2 * (r + 1)
		BK.box("Step", x1, x2, y0, top, z1, z1 + 2.2, COL.curb, m, Enum.Material.Concrete)
		BK.box("Seat", x1 + 0.2, x2 - 0.2, top, top + 0.2, z1 + 0.2, z1 + 1.5, if r % 2 == 0 then COL.mat else hex("E4E0D6"), m, Enum.Material.WoodPlanks)
	end
	BK.box("StandBack", x1, x2, y0, y0 + 6.2, 139.8, 140.1, COL.dark, m, Enum.Material.Metal)
	for i = 0, 8 do
		local x = x1 + (x2 - x1) * i / 8
		BK.box("StandPost", x - 0.15, x + 0.15, y0 + 1, y0 + 9, 129.6, 129.9, COL.metal, m, Enum.Material.Metal)
		BK.box("StandPostBack", x - 0.15, x + 0.15, y0, y0 + 9, 140, 140.3, COL.metal, m, Enum.Material.Metal)
	end
	BK.box("StandRoof", x1 - 1, x2 + 1, y0 + 9, y0 + 9.3, 129, 141.2, COL.roof, m, Enum.Material.Metal)
	BK.box("StandRail", x1, x2, y0 + 1, y0 + 2.3, 129.7, 129.85, COL.metal, m, Enum.Material.Metal).Transparency = 0.5
end

local function buildProps(f: Folder)
	local y0 = L.Track
	-- หลุมทราย (กระโดดไกล) ฝั่งตะวันตกเฉียงใต้ + ทางวิ่งยก
	local pit = Instance.new("Model")
	pit.Name = "LongJumpPit"
	pit.Parent = f
	BK.box("SandFrame", -141, -123, y0, y0 + 0.5, 131, 136, hex("8A6A4C"), pit, Enum.Material.Wood)
	local sand = BK.box("Sand", -140.6, -123.4, y0 + 0.2, y0 + 0.55, 131.4, 135.6, COL.sand, pit, Enum.Material.Sand)
	sand.CanCollide = true
	BK.box("Runway", -122, -108, y0, y0 + 0.08, 132, 135, COL.track, pit, Enum.Material.Pavement)
	-- เบาะกระโดดสูง + เสา + คาน
	local hj = Instance.new("Model")
	hj.Name = "HighJump"
	hj.Parent = f
	BK.box("Mat", -62, -52, y0, y0 + 1.6, 131, 137, COL.mat, hj, Enum.Material.Fabric)
	for _, z in { 131.5, 136.5 } do
		BK.box("Standard", -53.2, -52.8, y0, y0 + 6, z - 0.1, z + 0.1, COL.metal, hj, Enum.Material.Metal)
	end
	BK.box("Bar", -53.1, -52.9, y0 + 4.5, y0 + 4.65, 131.5, 136.5, hex("D8D2C0"), hj, Enum.Material.Metal).CanCollide = false
	-- ก๊อกน้ำดื่ม (ล้างมือ) 4 ก๊อกข้างอัฒจันทร์
	local tap = Instance.new("Model")
	tap.Name = "WaterTaps"
	tap.Parent = f
	BK.box("Trough", -66, -64, y0, y0 + 0.9, 129.5, 133.5, COL.curb, tap, Enum.Material.Concrete)
	BK.box("TroughBasin", -65.9, -64.1, y0 + 0.9, y0 + 1.1, 129.6, 133.4, hex("5B6870"), tap, Enum.Material.Metal)
	for i = 0, 3 do
		local z = 130 + i * 1.1
		BK.cylinder("Tap", 0.12, 1.4, Vector3.new(-65, y0 + 1.7, z), hex("A8B0B8"), tap, Enum.Material.Metal)
		BK.box("Spout", -65.15, -64.85, y0 + 2.3, y0 + 2.45, z - 0.1, z + 0.1, hex("A8B0B8"), tap, Enum.Material.Metal)
	end
	-- ที่จอดจักรยาน 2 แถว
	for row = 0, 1 do
		for i = 0, 7 do
			local x = -52 - i * 1.8
			BK.box("BikeRack", x, x + 0.25, y0, y0 + 2.2, 144 + row * 4, 144.3 + row * 4, COL.dark, f, Enum.Material.Metal)
		end
		BK.box("BikeRackBar", -66.2, -52, y0, y0 + 0.3, 144 + row * 4, 144.4 + row * 4, COL.dark, f, Enum.Material.Metal)
	end
	-- กรวยซ้อมและหัวสปริงเกอร์ตามริมหญ้า
	for i = 0, 9 do
		local x = CX - 30 + i * 6.6
		local c = BK.cylinder("Cone", 0.5, 1.1, Vector3.new(x, L.Floor + 0.55, CZ - L.HW - 2.2), hex("E86A2A"), f, Enum.Material.SmoothPlastic)
		c.Size = Vector3.new(1.1, 0.5, 0.5)
		BK.noCollide(c)
	end
	for _, p in { { -125, 62 }, { -65, 62 }, { -125, 118 }, { -65, 118 }, { -95, 61.5 } } do
		BK.noCollide(BK.cylinder("Sprinkler", 0.25, 0.3, Vector3.new(p[1], L.Floor + 0.1, p[2]), hex("2A2C32"), f, Enum.Material.Metal))
	end
	-- ฉากหลังประตูเทนนิสแบบสนามซ้อม: โต๊ะผู้ตัดสินสำรองข้างม้านั่ง
	BK.box("RefTable", CX - 1.5, CX + 1.5, L.Floor, L.Floor + 1.5, CZ + L.GrassHZ - 2.4, CZ + L.GrassHZ - 1.2, COL.wood, f, Enum.Material.WoodPlanks)
	-- ซากุระริมสนาม + ต้นไม้หลังอัฒจันทร์
	for _, p in { { -147, 58 }, { -147, 90 }, { -147, 122 }, { -43, 66 }, { -43, 96 }, { -43, 124 }, { -95, 148 }, { -130, 146 } } do
		BK.sakura(f, p[1], p[2], 1.1)
	end
end

function PitchKit.Build(f: Folder)
	registerGroups()
	buildGround(f)
	buildGoal(f, -1)
	buildGoal(f, 1)
	buildBackstops(f)
	benchShelter(f, CX - 22, hex("3E5A78"), "BenchHome")
	benchShelter(f, CX + 22, hex("9A3A32"), "BenchAway")
	buildScoreboard(f)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			floodlight(f, CX + sx * 49, CZ + sz * 40)
		end
	end
	buildStands(f)
	buildProps(f)
	f:SetAttribute("PitchReady", true)
end

return PitchKit
