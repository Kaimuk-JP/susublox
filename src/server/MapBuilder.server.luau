--!strict
-- แมพโรงเรียนสไตล์การ์ตูนพาสเทล สร้างจากโค้ด (Terrain หญ้า/น้ำ + ชิ้นส่วนตกแต่ง)
-- ขนาดโซนตามแผนและพิกัดที่ระบบเกมอ้างอิง (Spawn, SafeZone, Gym, ดาดฟ้า ฯลฯ) ห้ามขยับ:
-- สนามหน้าโรงเรียน x±80 z±60 | อาคารเรียน x±60 z-120..-60 | โรงยิม x80..180 z±35
-- โรงอาหาร x-160..-100 z±25 | หลังโรงเรียน x±30 z90..130 | อารีน่าสงคราม x±50 z210..310
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local RigFactory = require(script.Parent.RigFactory)
local BK = require(script.Parent.BuildKit)
local ArenaKit = require(script.Parent.ArenaKit)
local PitchKit = require(script.Parent.PitchKit)
local ClassroomKit = require(script.Parent.ClassroomKit)

local C = {
	paving = Color3.fromHex("B8AE9C"),
	pavingAlt = Color3.fromHex("8C857A"),
	concrete = Color3.fromHex("A3A5A6"),
	darkConcrete = Color3.fromHex("6E7175"),
	wall = Color3.fromHex("D6CDBA"),
	white = Color3.fromHex("E4E0D6"),
	trim = Color3.fromHex("6B5646"),
	glass = Color3.fromHex("86A0AA"),
	wood = Color3.fromHex("8A6A4C"),
	darkWood = Color3.fromHex("5E4632"),
	roof = Color3.fromHex("4A5560"),
	navy = Color3.fromHex("2A2D33"),
	red = Color3.fromHex("9A3A32"),
	blue = Color3.fromHex("3E5A78"),
	yellow = Color3.fromHex("D2AC48"),
	trunk = Color3.fromHex("5A4636"),
	hedge = Color3.fromHex("4A6B3E"),
	grassField = Color3.fromHex("7A9A5A"),
	track = Color3.fromHex("8F6248"),
	petal = Color3.fromHex("E2B2BA"),
	petalLight = Color3.fromHex("EDCBD0"),
	stone = Color3.fromHex("928F88"),
	water = Color3.fromHex("4F7F8F"),
}

local rng = Random.new(42)

-- สัญญาณให้ WorldBuilder รอ: โรงเรียนยังสร้างไม่เสร็จ (ห้ามใช้ Npcs เป็นสัญญาณ เพราะค้างอยู่ใน Place จากโหมด Edit)
local __mapT0 = os.clock()
workspace:SetAttribute("SchoolMapReady", false)

-- ล้างของเดิม (Baseplate เทาของ Studio, แมพรอบก่อน) แล้วสร้างใหม่ทุกครั้ง
for _, name in { "Baseplate", "Map", "Npcs" } do
	local old = workspace:FindFirstChild(name)
	if old and name ~= "Npcs" then
		old:Destroy()
	end
end
for _, child in workspace:GetChildren() do
	if child:IsA("SpawnLocation") then
		child:Destroy() -- จุดเกิดเริ่มต้นของเทมเพลต Studio (มีลายดาว) ใช้ Map.Spawn แทน
	end
end
local terrain = workspace.Terrain
-- ภูมิประเทศที่ปั้นไว้ล่วงหน้าใน Edit (tools/TerrainBake.luau) ห้ามล้าง/ปูทับ
local baked = workspace:GetAttribute("TerrainBaked") == true
if not baked then
	terrain:Clear()
end

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = map
	return f
end

---------------------------------------------------------------- ตัวช่วยสร้างชิ้นส่วน
-- ไม่ระบุวัสดุ = เลือกจากสี (น้ำตาล = ไม้, อื่น ๆ = คอนกรีต)
local function autoMaterial(c: Color3): Enum.Material
	local h, sat, v = c:ToHSV()
	if sat > 0.22 and (h < 0.12 or h > 0.97) and v < 0.7 and v > 0.2 then
		return Enum.Material.Wood
	end
	return Enum.Material.Concrete
end

local function part(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance, material: Enum.Material?): Part
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

-- กล่องระบุช่วง x1..x2, y1..y2, z1..z2
local function box(name: string, x1: number, x2: number, y1: number, y2: number, z1: number, z2: number, color: Color3, parent: Instance, material: Enum.Material?): Part
	return part(name, Vector3.new(x2 - x1, y2 - y1, z2 - z1), Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), color, parent, material)
end

-- ทรงกระบอกตั้งตรง (จุดกลาง position)
local function cylinder(name: string, radius: number, height: number, position: Vector3, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = part(name, Vector3.new(height, radius * 2, radius * 2), position, color, parent, material)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

local function ball(name: string, diameter: number, position: Vector3, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = part(name, Vector3.one * diameter, position, color, parent, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function noCollide(p: BasePart)
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
end

-- ป้ายข้อความ (หันหน้าไปทิศ yaw องศา: 0 = หันไป -Z, 180 = หันไป +Z, 90/-90 = ข้าง)
local function sign(parent: Instance, text: string, size: Vector3, position: Vector3, yaw: number, bg: Color3, fg: Color3): Part
	local p = part("Sign", size, position, bg, parent)
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

local function pointLight(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness
	l.Parent = p
end

-- ทางลาด/บันไดเอียงตามแกน X จาก (x1,y1) ไป (x2,y2) ที่ศูนย์กลาง z กว้าง width
local function ramp(name: string, x1: number, y1: number, x2: number, y2: number, zc: number, width: number, parent: Instance, supports: boolean?)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	local mid = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, zc)
	local p = part(name, Vector3.new(length, 1, width), mid, C.concrete, parent)
	p.CFrame = CFrame.new(mid - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.atan2(dy, dx))
	for _, side in { -1, 1 } do
		local rail = part(name .. "Rail", Vector3.new(length, 2.4, 0.4), mid, C.trim, parent)
		rail.CFrame = CFrame.new(mid + Vector3.new(0, 1.2, side * (width / 2 - 0.2))) * CFrame.Angles(0, 0, math.atan2(dy, dx))
	end
	-- เส้นขั้นบันไดตกแต่งบนทางลาด (ไม่ชน) และเสาค้ำยันถึงพื้น
	local angle = math.atan2(dy, dx)
	for i = 1, math.floor(length / 3) - 1 do
		local t = (i * 3) / length
		local c = Vector3.new(x1 + dx * t, y1 + dy * t, zc)
		local tread = part(name .. "Tread", Vector3.new(0.3, 0.05, width - 0.6), c, C.white, parent)
		tread.CFrame = CFrame.new(c + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, angle)
		noCollide(tread)
	end
	if supports then
		for i = 1, math.floor(length / 12) do
			local t = (i * 12) / length
			local py = y1 + dy * t - 1
			if py > 1.5 then
				for _, side in { -1, 1 } do
					box(name .. "Post", x1 + dx * t - 0.4, x1 + dx * t + 0.4, 0, py, zc + side * (width / 2 - 0.5) - 0.4, zc + side * (width / 2 - 0.5) + 0.4, C.stone, parent)
				end
			end
		end
	end
end

-- หน้าต่าง: กรอบ + กระจก + ขอบล่าง วางบนผนังหน้า (axis "x" = ผนังตามแกน X, "z" = ผนังตามแกน Z)
local function window(parent: Instance, axis: string, a: number, y: number, fixed: number, outward: number)
	local w, h = 6, 4.4
	local frameSize, glassSize, sillSize
	local pos
	if axis == "x" then -- ผนังยาวตามแกน X ที่ z = fixed, ยื่นออกทาง outward (+1/-1)
		frameSize, glassSize, sillSize = Vector3.new(w + 0.8, h + 0.8, 0.3), Vector3.new(w, h, 0.2), Vector3.new(w + 1.4, 0.35, 0.9)
		pos = Vector3.new(a, y, fixed + outward * 0.15)
	else -- ผนังยาวตามแกน Z ที่ x = fixed
		frameSize, glassSize, sillSize = Vector3.new(0.3, h + 0.8, w + 0.8), Vector3.new(0.2, h, w), Vector3.new(0.9, 0.35, w + 1.4)
		pos = Vector3.new(fixed + outward * 0.15, y, a)
	end
	part("WindowFrame", frameSize, pos, C.navy, parent)
	local g = part("WindowGlass", glassSize, pos + (if axis == "x" then Vector3.new(0, 0, outward * 0.12) else Vector3.new(outward * 0.12, 0, 0)), C.glass, parent, Enum.Material.Glass)
	g.Transparency = 0.35
	g.CanCollide = false
	local s = part("WindowSill", sillSize, pos + Vector3.new(0, -(h / 2 + 0.3), 0) + (if axis == "x" then Vector3.new(0, 0, outward * 0.4) else Vector3.new(outward * 0.4, 0, 0)), C.white, parent)
	s.CanCollide = false
end

---------------------------------------------------------------- Terrain: หญ้า น้ำ เนินเขา
-- ผิว Terrain จริงสูงกว่าขอบบนของบล็อก ~2 stud (voxel 4 stud) จึงวางที่ -8 ให้ผิวหญ้าอยู่ที่ y≈0 เสมอกับพื้นชิ้นส่วน
-- สีวัสดุภูมิประเทศธรรมชาติ (ตั้งตอนเล่นเสมอ ชุดเดียวกับ tools/TerrainBake.luau) ไม่มีสีเขียวสด
for mat, col in {
	[Enum.Material.Grass] = Color3.fromRGB(92, 128, 62),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(74, 108, 52),
	[Enum.Material.Ground] = Color3.fromRGB(112, 94, 68),
	[Enum.Material.Mud] = Color3.fromRGB(88, 72, 54),
	[Enum.Material.Rock] = Color3.fromRGB(116, 113, 106),
	[Enum.Material.Asphalt] = Color3.fromRGB(64, 65, 68),
	[Enum.Material.Pavement] = Color3.fromRGB(138, 136, 131),
	[Enum.Material.Cobblestone] = Color3.fromRGB(140, 132, 120),
	[Enum.Material.Concrete] = Color3.fromRGB(134, 132, 127),
	[Enum.Material.Sand] = Color3.fromRGB(201, 184, 143),
} do
	terrain:SetMaterialColor(mat, col)
end
if not baked then
	terrain:FillBlock(CFrame.new(0, -8, 110), Vector3.new(760, 12, 800), Enum.Material.LeafyGrass)

	-- เนินเขารอบฉากย้ายไปเป็นแนวเขานอกขอบโลกใน WorldBuilder (เนินกลางโลกเคยทับสวน ถนน บ้าน)
end

-- สระน้ำฝั่งตะวันออก (125, 95) รัศมี 17
terrain:FillCylinder(CFrame.new(125, -2, 95), 4, 21, Enum.Material.Sand) -- ชายหาดรอบสระ
terrain:FillCylinder(CFrame.new(125, -1.5, 95), 9, 17, Enum.Material.Air) -- ขุดแอ่ง
terrain:FillCylinder(CFrame.new(125, -6, 95), 6, 17, Enum.Material.Water)
terrain.WaterColor = Color3.fromHex("4F7F8F")
terrain.WaterTransparency = 0.45
terrain.WaterWaveSize = 0.12
terrain.WaterReflectance = 0.5

for _, old in terrain:GetChildren() do
	if old:IsA("Clouds") then
		old:Destroy() -- กันเมฆซ้ำเมื่อรันซ้ำ (Terrain:Clear ไม่ลบ Clouds)
	end
end
local clouds = Instance.new("Clouds")
clouds.Cover = 0.55
clouds.Density = 0.55
clouds.Color = Color3.fromHex("E8E4DC")
clouds.Parent = terrain

---------------------------------------------------------------- พื้นและทางเดิน
-- ขุด Terrain ใต้พื้นปูทุกโซนทิ้ง (เว้นขอบ 1 stud) กันใบหญ้าโผล่ทะลุแผ่นพื้นบาง
for _, z in {
	{ -80, 80, -60, 60 }, { -160, -100, -25, 25 }, { 80, 180, -35, 35 }, { -30, 30, 90, 130 }, { -50, 50, 210, 310 },
	{ -100, -80, -10, 10 }, { -10, 10, 60, 90 }, { -10, 10, 130, 210 }, { -142, -48, 52, 128 }, { -61, 61, -121, -59 },
} do
	terrain:FillBlock(CFrame.new((z[1] + z[2]) / 2, -1.5, (z[3] + z[4]) / 2), Vector3.new(z[2] - z[1] - 2, 9, z[4] - z[3] - 2), Enum.Material.Air)
end

local ground = folder("Ground")
box("SchoolYard", -80, 80, -3, 0.3, -60, 60, C.paving, ground)
box("Cafeteria_Floor", -160, -100, -3, 0.3, -25, 25, C.paving, ground)
box("Gym_Floor", 80, 180, -3, 0.3, -35, 35, C.wood, ground, Enum.Material.WoodPlanks)
box("BackLot", -10, 10, -3, 0.3, 90, 130, C.concrete, ground) -- ซอยหลังโรงเรียนถูกรื้อ เหลือแค่ทางเดินต่อไปอารีน่า
box("War_Floor_Red", -50, 50, -3, 0.3, 210, 260, Color3.fromHex("9A6A66"), ground)
box("War_Floor_Blue", -50, 50, -3, 0.3, 260, 310, Color3.fromHex("66798F"), ground)
box("Path_Cafeteria", -100, -80, -3, 0.3, -10, 10, C.concrete, ground)
box("Path_BackLot", -10, 10, -3, 0.3, 60, 90, C.concrete, ground)
box("Path_War", -10, 10, -3, 0.32, 130, 210, C.concrete, ground)
-- ขอบทางเดิน
for _, z in { -10.4, 10.4 } do
	box("PathEdge", -100, -80, 0, 0.45, z - 0.3, z + 0.3, C.white, ground)
end
for _, x in { -10.4, 10.4 } do
	box("PathEdge", x - 0.3, x + 0.3, 0, 0.45, 60, 90, C.white, ground)
	box("PathEdge", x - 0.3, x + 0.3, 0, 0.45, 130, 210, C.white, ground)
end

-- ลานกระเบื้องลายหมากรุกชมพู-ครีมกลางสนาม
local yard = folder("Yard")
for ix = -8, 7 do
	for iz = -5, 4 do
		local alt = (ix + iz) % 2 == 0
		box("Tile", ix * 4, ix * 4 + 4, 0.3, 0.38, iz * 4, iz * 4 + 4, if alt then C.paving else C.pavingAlt, yard)
	end
end

---------------------------------------------------------------- อาคารเรียน (x -60..60, z -120..-60)
local school = folder("School")
local X1, X2, Z1, Z2 = -60, 60, -120, -60

box("Plinth", X1 - 1, X2 + 1, -3, 0.32, Z1 - 1, Z2 + 1, C.darkConcrete, school)

for level = 0, 2 do
	local y0 = level * 16
	local y1 = y0 + 16
	-- ผนังนอก 4 ด้านเจาะหน้าต่างจริง (ประตูหน้าชั้นล่าง x -7..7, ประตูหนีไฟตะวันตกชั้น 2 z -108..-98) ดู ClassroomKit
	ClassroomKit.BuildShell(school, level, C.wall, C.navy, C.glass)
	-- แถบสีชมพูคั่นชั้น
	box("Band" .. level, X1 - 0.4, X2 + 0.4, y1 - 1.2, y1, Z2, Z2 + 0.5, C.trim, school)
	box("BandBack" .. level, X1 - 0.4, X2 + 0.4, y1 - 1.2, y1, Z1 - 0.5, Z1, C.trim, school)
end
box("Slab_Floor2", X1, X2, 15.5, 16, Z1, Z2, C.wall, school)
box("Slab_Floor3", X1, X2, 31.5, 32, Z1, Z2, C.wall, school)
box("Slab_Roof", X1, X2, 47.5, 48, Z1, Z2, C.roof, school)

-- ภายใน: ทางเดินกว้าง 15, แสงเพดาน, ตู้ล็อกเกอร์ตามผนังหลัง
for level = 0, 2 do
	local y0 = level * 16 + (if level == 0 then 0.3 else 0)
	box("ClassFloor" .. level, X1 + 1, X2 - 1, y0, y0 + 0.1, Z1 + 1, Z2 - 1, C.wood, school, Enum.Material.WoodPlanks)
	box("Corridor" .. level, X1 + 1, X2 - 1, y0 + 0.05, y0 + 0.2, -97.5, -82.5, Color3.fromHex("E8E4D8"), school, Enum.Material.SmoothPlastic) -- พื้นกระเบื้องสว่าง
	for _, lx in { -40, 0, 40 } do
		local strip = part("CeilingLight", Vector3.new(14, 0.25, 1.6), Vector3.new(lx, level * 16 + 15.1, -90), C.white, school, Enum.Material.Neon)
		noCollide(strip)
		if lx ~= 0 then
			pointLight(strip, Color3.fromHex("FFF3E0"), 34, 1.0) -- 2 ดวงต่อชั้น (ห้องเรียนมีดวงละห้องใน ClassroomKit รวมทั้งอาคาร < 40)
		end
	end
	for lx = -56, 52, 4 do
		if ClassroomKit.PartitionHitsX(lx, lx + 3) then
			continue -- ผนังกั้นห้องผ่านตำแหน่งนี้
		end
		local alt = (math.floor(lx / 4)) % 2 == 0
		box("Locker", lx, lx + 3, level * 16 + 0.3, level * 16 + 6.3, Z1 + 1, Z1 + 3, if alt then C.blue else C.trim, school)
	end
end

-- ห้องเรียนญี่ปุ่น: ผนังกั้นห้อง ประตูบานเลื่อน กระดาน โต๊ะเรียน ฯลฯ (ดู ClassroomKit.luau)
do
	local t0 = os.clock()
	local st = ClassroomKit.Build(school)
	print(string.format("[Classroom] %d parts, %d lights, %d SurfaceGui, %.2fs", st.parts, st.lights, st.guis, os.clock() - t0))
end

-- ดาดฟ้า: อารีน่า PvP 80x60 + ราวกันตกสูง 3 + ถังน้ำ + เสาอากาศ
box("Rooftop", -40, 40, 48, 48.2, Z1, Z2, C.trim, school)
cylinder("RoofCircle", 14, 0.1, Vector3.new(0, 48.25, -90), C.white, school)
cylinder("RoofCircleInner", 13.4, 0.12, Vector3.new(0, 48.27, -90), C.trim, school)
box("RailFront", X1, X2, 48, 51, Z2 - 0.6, Z2, C.white, school)
box("RailBack", X1, X2, 48, 51, Z1, Z1 + 0.6, C.white, school)
box("RailEast", X2 - 0.6, X2, 48, 51, Z1, Z2, C.white, school)
box("RailWestA", X1, X1 + 0.6, 48, 51, Z1, -91, C.white, school)
box("RailWestB", X1, X1 + 0.6, 48, 51, -83, Z2, C.white, school)
cylinder("WaterTank", 4, 7, Vector3.new(52, 52, -112), C.stone, school)
box("WaterTankLeg", 49, 55, 48, 48.6, -115, -109, C.darkConcrete, school)
cylinder("Antenna", 0.3, 14, Vector3.new(-52, 55, -112), C.navy, school)
ball("AntennaLight", 1.2, Vector3.new(-52, 62.4, -112), C.red, school, Enum.Material.Neon)

-- บันไดหนีไฟด้านตะวันตก 3 ช่วง: ชั้น1 -> ชั้น2 -> ดาดฟ้า
ramp("EscapeF1", -116, 0, -68, 16, -105, 8, school, true)
box("EscapeLanding1", -68, -60, 15.5, 16, -109, -92, C.concrete, school)
ramp("EscapeF2", -68, 16, -116, 32, -96, 8, school, true)
box("EscapeLanding2", -124, -116, 31.5, 32, -100, -83, C.concrete, school)
ramp("EscapeF3", -116, 32, -68, 48, -87, 8, school, true)
box("EscapeLanding3", -68, -60, 47.5, 48, -91, -83, C.concrete, school)
for _, post in { { -124, -100, 31.5 }, { -124, -83.8, 31.5 }, { -68, -109, 15.5 }, { -68, -92.8, 15.5 }, { -68, -91, 47.5 }, { -68, -83.8, 47.5 } } do
	box("LandingPost", post[1], post[1] + 0.8, 0, post[3], post[2], post[2] + 0.8, C.stone, school)
end

-- หอนาฬิกา + ซุ้มประตูทางเข้า (ยื่นออกหน้าอาคาร z -60..-50)
local tower = folder("ClockTower")
box("PorchWallW", -10, -9, 0, 16, -60, -50, C.wall, tower)
box("PorchWallE", 9, 10, 0, 16, -60, -50, C.wall, tower)
box("PorchRoof", -11, 11, 16, 17, -61, -49, C.trim, tower)
box("TowerBody", -8, 8, 17, 58, -59, -51, C.wall, tower)
box("TowerTrimA", -8.6, 8.6, 30, 31, -59.6, -50.4, C.trim, tower)
box("TowerTrimB", -8.6, 8.6, 45, 46, -59.6, -50.4, C.trim, tower)
-- นาฬิกา
cylinder("ClockRim", 5.7, 0.4, Vector3.new(0, 50, -50.5), C.navy, tower).CFrame = CFrame.new(0, 50, -50.5) * CFrame.Angles(0, math.rad(90), 0)
cylinder("ClockFace", 5, 0.5, Vector3.new(0, 50, -50.2), C.white, tower).CFrame = CFrame.new(0, 50, -50.2) * CFrame.Angles(0, math.rad(90), 0)
local hourHand = box("ClockHour", -0.25, 0.25, 50, 53.2, -49.9, -49.6, C.navy, tower)
local minuteHand = box("ClockMinute", 0, 3.8, 49.75, 50.25, -49.9, -49.6, C.navy, tower)
hourHand.Name, minuteHand.Name = "ClockHour", "ClockMinute"
-- หลังคาเป็นขั้น + ยอดแหลม
box("TowerRoof1", -10, 10, 58, 60, -61, -49, C.roof, tower)
box("TowerRoof2", -7.5, 7.5, 60, 62, -58.5, -51.5, C.roof, tower)
box("TowerRoof3", -5, 5, 62, 64, -56, -53, C.roof, tower)
cylinder("Spire", 0.35, 9, Vector3.new(0, 68.5, -54.5), C.yellow, tower)
ball("SpireBall", 1.6, Vector3.new(0, 73.2, -54.5), C.yellow, tower, Enum.Material.Neon)
sign(tower, "SUSUBLOX HIGH", Vector3.new(16, 3, 0.4), Vector3.new(0, 13.2, -49.7), 180, C.navy, C.yellow)
-- ขั้นบันไดหน้าประตู
for i = 1, 3 do
	box("Step" .. i, -9 - (3 - i) * 0.6, 9 + (3 - i) * 0.6, 0.3, 0.3 + (4 - i) * 0.4, -50 + i * 1.4 - 1.4, -50 + i * 1.4, C.stone, tower)
end
for _, x in { -6, 6 } do
	local lamp = ball("PorchLamp", 1.2, Vector3.new(x, 11, -49.6), C.yellow, tower, Enum.Material.Neon)
	pointLight(lamp, C.yellow, 20, 1)
end

---------------------------------------------------------------- โรงยิม (x 80..180, z -35..35)
local gym = folder("Gym")
box("GymWallN", 80, 180, 0, 20, -35, -34, C.wall, gym)
box("GymWallS", 80, 180, 0, 20, 34, 35, C.wall, gym)
box("GymWallE", 179, 180, 0, 20, -35, 35, C.wall, gym)
box("GymWallWa", 80, 81, 0, 20, -35, -7, C.wall, gym)
box("GymWallWb", 80, 81, 0, 20, 7, 35, C.wall, gym)
box("GymDoorTop", 80, 81, 11, 20, -7, 7, C.wall, gym)
box("GymStripeN", 80, 180, 8, 10, -35, -34.6, C.trim, gym)
box("GymStripeS", 80, 180, 8, 10, 34.6, 35, C.trim, gym)
box("GymRim", 79, 181, 20, 21, -36, 36, C.roof, gym)
-- หน้าต่างแถบสูงใต้ขอบหลังคา
for wx = 86, 174, 11 do
	for _, wz in { -35.1, 35.1 } do
		local g = part("GymWindow", Vector3.new(7, 3, 0.2), Vector3.new(wx, 16, wz), C.glass, gym, Enum.Material.Glass)
		g.Transparency = 0.35
		g.CanCollide = false
	end
end
for _, z in { -20, 0, 20 } do
	box("GymRoofStripe", 82, 178, 21, 21.12, z - 1.2, z + 1.2, C.trim, gym)
end
sign(gym, "GYM", Vector3.new(14, 4, 0.4), Vector3.new(79.4, 15, 0), 90, C.navy, C.yellow)
-- เส้นสนามบาส
cylinder("CourtCircle", 8, 0.1, Vector3.new(130, 0.36, 0), C.white, gym)
cylinder("CourtCircleInner", 7.6, 0.12, Vector3.new(130, 0.38, 0), C.wood, gym, Enum.Material.WoodPlanks)
box("CenterLine", 129.7, 130.3, 0.38, 0.42, -33, 33, C.white, gym)
for _, x in { 86, 174 } do
	box("EndLine", x - 0.3, x + 0.3, 0.38, 0.42, -26, 26, C.white, gym)
end
-- แป้นบาส 2 ฝั่ง
for _, side in { 1, -1 } do
	local x = if side == 1 then 88 else 172
	box("HoopPole", x - 0.4, x + 0.4, 0.3, 10, -0.4, 0.4, C.navy, gym)
	box("Backboard", x + side * 0.4 - 0.2, x + side * 0.4 + 0.2, 8.5, 13, -3, 3, C.white, gym)
	local ring = cylinder("HoopRing", 1.4, 0.3, Vector3.new(x + side * 1.8, 10.2, 0), C.red, gym, Enum.Material.Neon)
	ring.CanCollide = false
end
-- ป้ายแขวนธงสี + ไฟเพดานโรงยิม
for i, color in { C.red, C.blue, C.yellow, C.trim } do
	box("Banner", 95 + i * 18, 99 + i * 18, 11, 17, -33.9, -33.7, color, gym)
end
for i = 0, 3 do
	local lamp = part("GymLight", Vector3.new(10, 0.4, 2), Vector3.new(100 + i * 27, 19.5, 0), C.white, gym, Enum.Material.Neon)
	noCollide(lamp)
	pointLight(lamp, Color3.fromHex("FFF3E0"), 40, 1.4)
end
for i = 1, 4 do
	box("Bleacher" .. i, 90, 170, 0.3, 0.3 + i * 1.2, -34 + i * 2, -32 + i * 2, C.navy, gym)
end

---------------------------------------------------------------- โรงอาหาร (x -160..-100, z -25..25)
local cafe = folder("Cafeteria")
box("CafeWallN", -160, -100, 0, 12, -25, -24, C.wall, cafe)
box("CafeWallS", -160, -100, 0, 12, 24, 25, C.wall, cafe)
box("CafeWallW", -160, -159, 0, 12, -25, 25, C.wall, cafe)
box("CafeWallEa", -101, -100, 0, 12, -25, -7, C.wall, cafe)
box("CafeWallEb", -101, -100, 0, 12, 7, 25, C.wall, cafe)
box("CafeDoorTop", -101, -100, 9, 12, -7, 7, C.wall, cafe)
box("CafeRoof", -161, -99, 12, 13, -26, 26, C.roof, cafe)
box("CafeRoofTrim", -161.5, -98.5, 12, 12.8, -26.5, 26.5, C.trim, cafe)
for _, z in { -12, 0, 12 } do
	box("CafeRoofStripe", -158, -102, 13, 13.12, z - 1, z + 1, C.trim, cafe)
end
sign(cafe, "CAFETERIA", Vector3.new(16, 3.2, 0.4), Vector3.new(-99.4, 10.5, 0), -90, C.red, C.white)
-- กระจกหน้าต่างยาว ผนังเหนือ-ใต้
for wx = -152, -108, 11 do
	for _, wz in { -25.1, 25.1 } do
		local g = part("CafeWindow", Vector3.new(7, 4, 0.2), Vector3.new(wx, 7, wz), C.glass, cafe, Enum.Material.Glass)
		g.Transparency = 0.35
		g.CanCollide = false
	end
end
-- โต๊ะ + เก้าอี้สตูล
for row = -1, 1 do
	for col = 0, 2 do
		local x, z = -145 + col * 16, row * 11
		box("Table", x - 3, x + 3, 2.6, 3.1, z - 1.6, z + 1.6, C.wood, cafe, Enum.Material.Wood)
		cylinder("TableLeg", 0.4, 2.5, Vector3.new(x, 1.5, z), C.navy, cafe)
		for _, off in { { -2.2, -2.4 }, { 2.2, -2.4 }, { -2.2, 2.4 }, { 2.2, 2.4 } } do
			cylinder("Stool", 0.7, 1.6, Vector3.new(x + off[1], 1.1, z + off[2]), C.trim, cafe)
		end
	end
end
-- เคาน์เตอร์ขายอาหาร + ตู้กดน้ำ
box("Counter", -158, -154, 0.3, 4, -20, 12, C.wood, cafe, Enum.Material.Wood)
box("CounterTop", -158.5, -153.5, 4, 4.5, -20.5, 12.5, C.white, cafe)
for i, color in { C.red, C.blue } do
	local z = 16 + i * 4
	box("VendingMachine", -158.5, -155.5, 0.3, 6.8, z, z + 3, color, cafe)
	local panel = part("VendingPanel", Vector3.new(0.2, 4, 2.2), Vector3.new(-155.4, 4, z + 1.5), C.white, cafe, Enum.Material.Neon)
	noCollide(panel)
	pointLight(panel, C.white, 10, 0.8)
end
local cafeLight = part("CafeLight", Vector3.new(30, 0.3, 2), Vector3.new(-130, 11.6, 0), C.white, cafe, Enum.Material.Neon)
noCollide(cafeLight)
pointLight(cafeLight, Color3.fromHex("FFF3E0"), 40, 1.2)

---------------------------------------------------------------- สนามประลอง (x±52 z208..312): ภายนอกโคลอสเซียมกรีก + ลานหน้าสนาม
-- ตัวสนามจริงเป็น instance ไกลเมือง (ArenaManager/ArenaKit) ที่นี่คือทางเข้า คีออสก์ผู้ตัดสิน และกระดาน
local war = folder("WarArena")
do
	local exterior = ArenaKit.BuildExterior(war)
	exterior:PivotTo(CFrame.new(ArenaKit.SITE))
	-- ลานหน้าสนามเป็นโซนปลอดภัย (ใครก็สู้กันไม่ได้ก่อนเข้าแมตช์)
	local zone = part("ArenaLobbySafe", Vector3.new(104, 40, 34), Vector3.new(0, 18, 225), C.roof, war)
	zone.Transparency = 1
	noCollide(zone)
	zone:SetAttribute("SafeZone", true)
end

---------------------------------------------------------------- ของตกแต่งสนามหน้าโรงเรียน
local props = folder("Props")

-- ต้นซากุระ: ใช้โมเดลนำเข้าจริงผ่าน BuildKit (ไม่มีโมเดลจะใช้ต้นไม้สำรองแบบกิ่งก้านเล็ก ไม่ใช่ลูกบอลก้อนใหญ่)
local function sakura(x: number, z: number, scale: number)
	BK.sakura(props, x, z, scale)
end
for _, p in {
	{ -62, -40 }, { -42, -40 }, { 42, -40 }, { 62, -40 }, { -62, 38 }, { -42, 38 }, { 42, 38 }, { 62, 38 },
} do
	sakura(p[1], p[2], 1)
end
-- ต้นซากุระฉากหลัง (ใหญ่กว่า)
for _, p in { { -100, 40 }, { 100, 60 }, { -170, 50 }, { 20, 160 }, { -20, 180 }, { 70, 25 } } do
	sakura(p[1], p[2], 1.15)
end

-- กลีบซากุระโปรยทั่วสนาม
local petalSky = part("PetalSky", Vector3.new(170, 1, 130), Vector3.new(0, 40, 0), C.white, props)
petalSky.Transparency = 1
noCollide(petalSky)
local petals = Instance.new("ParticleEmitter")
petals.Texture = "rbxasset://textures/particles/sparkles_main.dds"
petals.Color = ColorSequence.new(C.petal, C.petalLight)
petals.Size = NumberSequence.new(0.45)
petals.Lifetime = NumberRange.new(10, 14)
petals.Speed = NumberRange.new(0, 0.5)
petals.Acceleration = Vector3.new(2, -3, 0.8)
petals.RotSpeed = NumberRange.new(-80, 80)
petals.EmissionDirection = Enum.NormalId.Bottom
petals.Rate = 30
petals.LightEmission = 0.3
petals.Parent = petalSky

-- น้ำพุกลางลาน (ด้านหน้าอาคาร): สระวงกลมมีขอบหิน + ชามน้ำพุ 3 ชั้น + น้ำไหลลงทีละชั้น
local FOUNTAIN = Vector3.new(0, 0, -30)
local stoneDark = Color3.fromHex("8A857B")
local waterColor = Color3.fromHex("5F8F9A")
local function fountainPart(p: Part, material: Enum.Material?)
	p.Material = material or Enum.Material.Marble
	return p
end
-- สระฐาน: ขอบหิน 2 ชั้น (นอก/ใน) + ผิวน้ำ
fountainPart(cylinder("FountainRimOuter", 8.6, 1.6, FOUNTAIN + Vector3.new(0, 1.1, 0), C.stone, props))
fountainPart(cylinder("FountainRimStep", 9.6, 0.5, FOUNTAIN + Vector3.new(0, 0.55, 0), stoneDark, props))
local pool = cylinder("FountainWater", 7.6, 0.2, FOUNTAIN + Vector3.new(0, 1.75, 0), waterColor, props, Enum.Material.Glass)
pool.Transparency = 0.45
pool.CanCollide = false
-- ชามชั้นล่าง/กลาง/บน
local tiers = {
	{ r = 4.6, y = 3.0, h = 0.7 },
	{ r = 3.0, y = 5.2, h = 0.6 },
	{ r = 1.6, y = 7.0, h = 0.5 },
}
fountainPart(cylinder("FountainColumnLow", 1.1, 2.4, FOUNTAIN + Vector3.new(0, 2.6, 0), C.stone, props))
fountainPart(cylinder("FountainColumnMid", 0.8, 2.2, FOUNTAIN + Vector3.new(0, 4.7, 0), C.stone, props))
fountainPart(cylinder("FountainColumnTop", 0.5, 2.0, FOUNTAIN + Vector3.new(0, 6.6, 0), C.stone, props))
for _, t in tiers do
	fountainPart(cylinder("FountainBowl", t.r, t.h, FOUNTAIN + Vector3.new(0, t.y, 0), C.stone, props))
	fountainPart(cylinder("FountainBowlLip", t.r + 0.25, 0.25, FOUNTAIN + Vector3.new(0, t.y + t.h / 2, 0), stoneDark, props))
	local w = cylinder("FountainBowlWater", t.r - 0.35, 0.12, FOUNTAIN + Vector3.new(0, t.y + t.h / 2 + 0.1, 0), waterColor, props, Enum.Material.Glass)
	w.Transparency = 0.4
	w.CanCollide = false
	-- น้ำล้นขอบชามไหลลงชั้นล่าง: ตัวปล่อยอนุภาคเรียงรอบขอบ
	local spill = Instance.new("Attachment")
	spill.Parent = w
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	ring.Color = ColorSequence.new(Color3.fromHex("AEC4C8"), waterColor)
	ring.Size = NumberSequence.new(0.28)
	ring.Lifetime = NumberRange.new(0.7, 1.0)
	ring.Speed = NumberRange.new(t.r * 0.9, t.r * 1.2)
	ring.Acceleration = Vector3.new(0, -30, 0)
	ring.SpreadAngle = Vector2.new(180, 8) -- กระจายรอบแนวนอน
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Rate = 36
	ring.LightEmission = 0.5
	ring.Parent = spill
end
fountainPart(ball("FountainFinial", 1.5, FOUNTAIN + Vector3.new(0, 8.3, 0), C.white, props))
local fountainTop = ball("FountainJetSource", 0.4, FOUNTAIN + Vector3.new(0, 8.8, 0), waterColor, props, Enum.Material.Glass)
fountainTop.Transparency = 1
fountainTop.CanCollide = false
local jet = Instance.new("ParticleEmitter")
jet.Texture = "rbxasset://textures/particles/sparkles_main.dds"
jet.Color = ColorSequence.new(Color3.fromHex("AEC4C8"), waterColor)
jet.Size = NumberSequence.new(0.35)
jet.Lifetime = NumberRange.new(1.0, 1.5)
jet.Speed = NumberRange.new(10, 14)
jet.Acceleration = Vector3.new(0, -26, 0)
jet.SpreadAngle = Vector2.new(14, 14)
jet.EmissionDirection = Enum.NormalId.Top
jet.Rate = 60
jet.LightEmission = 0.5
jet.Parent = fountainTop

-- แถวพุ่มไม้ + ดอกไม้
local function hedge(x1: number, x2: number, z1: number, z2: number)
	box("Hedge", x1, x2, 0.3, 3.2, z1, z2, C.hedge, props, Enum.Material.Grass)
	local length = math.max(x2 - x1, z2 - z1)
	for i = 0, math.floor(length / 3) do
		local fx = if x2 - x1 > z2 - z1 then x1 + i * 3 + rng:NextNumber(0, 1.4) else (x1 + x2) / 2 + (if rng:NextNumber() > 0.5 then 1.8 else -1.8)
		local fz = if x2 - x1 > z2 - z1 then (z1 + z2) / 2 + (if rng:NextNumber() > 0.5 then 1.8 else -1.8) else z1 + i * 3 + rng:NextNumber(0, 1.4)
		local color = ({ C.trim, C.yellow, C.white, Color3.fromHex("C98A97") })[rng:NextInteger(1, 4)]
		ball("Flower", 1.1, Vector3.new(fx, 0.9, fz), color, props, Enum.Material.Grass)
	end
end
hedge(-46, -14, 57, 59) -- ขอบใต้ซ้าย (เปิดช่อง x -78..-46 ให้ทางเข้าสนามกีฬา)
hedge(14, 78, 57, 59) -- ขอบใต้ขวา
hedge(-79, -77, 12, 56) -- ขอบตะวันตก
hedge(-79, -77, -50, -12)
hedge(77, 79, 12, 56) -- ขอบตะวันออก
hedge(77, 79, -50, -12)
hedge(-78, -14, -49, -47) -- แถวหน้าอาคาร
hedge(14, 78, -49, -47)

-- ประตูโรงเรียน (ทางไปหลังโรงเรียน)
for _, x in { -12, 12 } do
	box("GatePillar", x - 1.5, x + 1.5, 0.3, 10, 58, 61, C.wall, props)
	box("GatePillarCap", x - 2, x + 2, 10, 11, 57.5, 61.5, C.trim, props)
end
box("GateBar", -12, 12, 9, 10.5, 58.5, 60.5, C.wall, props)
-- ป้ายประตู: ตัวหนังสือทั้งสองด้าน (ด้านถนน +Z และด้านโรงเรียน -Z) ชื่ออังกฤษบน ญี่ปุ่นล่าง
do
	local board = part("GateSign", Vector3.new(21, 5, 0.6), Vector3.new(0, 13.1, 59.6), C.navy, props)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = board
		for _, row in { { "SUSUBLOX HIGH", 0.08, 0.5, C.yellow }, { "私立スースーブロックス高等学校", 0.58, 0.3, Color3.new(1, 1, 1) } } do
			local label = Instance.new("TextLabel")
			label.Position = UDim2.fromScale(0.04, row[2])
			label.Size = UDim2.fromScale(0.92, row[3])
			label.BackgroundTransparency = 1
			label.Text = row[1]
			label.TextColor3 = row[4]
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.Parent = gui
		end
	end
end

-- ม้านั่ง
local function bench(x: number, z: number, yaw: number)
	local model = Instance.new("Model")
	model.Name = "Bench"
	model.Parent = props
	local function piece(size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?)
		local p = part("BenchPart", size, Vector3.zero, color, model, material)
		p.CFrame = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(offset)
	end
	piece(Vector3.new(6, 0.5, 2), Vector3.new(0, 1.85, 0), C.wood, Enum.Material.Wood)
	piece(Vector3.new(6, 1.8, 0.4), Vector3.new(0, 2.9, -0.8), C.wood, Enum.Material.Wood)
	piece(Vector3.new(0.4, 1.6, 1.8), Vector3.new(-2.6, 1, 0), C.navy)
	piece(Vector3.new(0.4, 1.6, 1.8), Vector3.new(2.6, 1, 0), C.navy)
end
for _, p in { { -40, 44 }, { 40, 44 }, { -40, -35 }, { 40, -35 }, { -20, 30 }, { 20, 30 } } do
	bench(p[1], p[2], if p[2] > 0 then 180 else 0)
end

-- เสาไฟ
local function lamp(x: number, z: number)
	cylinder("Pole", 0.4, 12, Vector3.new(x, 6.3, z), C.navy, props)
	cylinder("PoleBase", 0.9, 0.8, Vector3.new(x, 0.7, z), C.darkConcrete, props)
	local bulb = ball("Bulb", 2, Vector3.new(x, 12.8, z), C.yellow, props, Enum.Material.Neon)
	pointLight(bulb, C.yellow, 30, 1.2)
end
for _, p in { { -20, 20 }, { 20, 20 }, { -20, -30 }, { 20, -30 }, { -50, 0 }, { 50, 0 }, { 8, 75 }, { -8, 150 }, { -90, 8 }, { 8, 190 } } do
	lamp(p[1], p[2])
end

-- เสาธง
cylinder("FlagPole", 0.5, 26, Vector3.new(0, 13.3, 30), C.concrete, props)
ball("FlagPoleTop", 1.6, Vector3.new(0, 26.6, 30), C.yellow, props, Enum.Material.Neon)
box("Flag", 0.5, 10.5, 20, 26, 29.85, 30.15, C.red, props, Enum.Material.Fabric)
-- วงกลมขาว (ธงญี่ปุ่น) ตามผ้าไปเมื่อธงพลิ้ว
local flagDisc = cylinder("FlagDisc", 1.7, 0.1, Vector3.new(5.5, 23, 30), C.white, props, Enum.Material.Fabric)
flagDisc.CFrame = CFrame.new(5.5, 23, 30) * CFrame.Angles(0, math.rad(90), 0)
flagDisc.Size = Vector3.new(0.6, 3.4, 3.4)
noCollide(flagDisc)

-- ตู้กดน้ำริมทางเดินโรงอาหาร + ที่จอดจักรยาน + ถังขยะ
for i, color in { C.red, C.blue } do
	local z = -22 - i * 3.2
	box("YardVending", -77, -74, 0.3, 6.8, z, z + 2.8, color, props)
	local panel = part("YardVendingPanel", Vector3.new(0.2, 4, 2), Vector3.new(-73.9, 4, z + 1.4), C.white, props, Enum.Material.Neon)
	noCollide(panel)
	pointLight(panel, C.white, 10, 0.7)
end
for i = 0, 5 do
	box("BikeRack", 62 + i * 2, 62.3 + i * 2, 0.3, 2.5, -45, -41, C.navy, props)
end
box("BikeRackBar", 62, 74, 0.3, 0.6, -45, -44.7, C.navy, props)
for _, p in { { -30, -45 }, { 30, -45 }, { -70, 50 }, { 70, 50 } } do
	cylinder("Bin", 1.2, 2.6, Vector3.new(p[1], 1.6, p[2]), C.blue, props)
	cylinder("BinLid", 1.3, 0.3, Vector3.new(p[1], 3, p[2]), C.navy, props)
end

---------------------------------------------------------------- สนามกีฬา (ฝั่งตะวันตกเฉียงใต้) x -140..-50, z 55..125
local field = folder("Field")
PitchKit.Build(field) -- สนามฟุตบอลมาตรฐาน + ลู่วิ่ง + อัฒจันทร์ (ดู PitchKit.luau) ลูกบอล/บอทจาก SoccerPitch.server

---------------------------------------------------------------- สระน้ำ + สะพานไม้ (ฝั่งตะวันออก)
local pond = folder("Pond")
for i = 1, 14 do
	local a = (i / 14) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
	local r = 17.5 + rng:NextNumber(-0.5, 1.5)
	local size = rng:NextNumber(2.2, 4.2)
	local rock = ball("Rock", size, Vector3.new(125 + math.cos(a) * r, size * 0.25, 95 + math.sin(a) * r), C.stone, pond, Enum.Material.Slate)
	rock.Size = Vector3.new(size, size * 0.65, size * 0.9)
end
-- สะพานโค้งข้ามสระ (แกน X ที่ z=95)
ramp("BridgeRampW", 104, 0.3, 110, 2.2, 95, 5, pond)
box("BridgeDeck", 110, 140, 1.7, 2.2, 92.5, 97.5, C.darkWood, pond, Enum.Material.WoodPlanks)
ramp("BridgeRampE", 140, 2.2, 146, 0.3, 95, 5, pond)
for _, z in { 92.7, 97.3 } do
	box("BridgeRail", 110, 140, 2.2, 4.2, z - 0.15, z + 0.15, C.trim, pond)
end
for x = 112, 138, 8 do
	cylinder("BridgePier", 0.5, 4, Vector3.new(x, 0.2, 92.8), C.darkWood, pond, Enum.Material.Wood)
	cylinder("BridgePier", 0.5, 4, Vector3.new(x, 0.2, 97.2), C.darkWood, pond, Enum.Material.Wood)
end
for _, x in { 110, 140 } do
	local bulb = ball("BridgeLamp", 1.2, Vector3.new(x, 5, 92.7), C.yellow, pond, Enum.Material.Neon)
	pointLight(bulb, C.yellow, 24, 1)
	cylinder("BridgeLampPole", 0.2, 3, Vector3.new(x, 3.6, 92.7), C.navy, pond)
end
-- ใบบัว
for i = 1, 9 do
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(2, 13)
	local pad = cylinder("LilyPad", 1.2, 0.08, Vector3.new(125 + math.cos(a) * r, 0.06, 95 + math.sin(a) * r), Color3.fromHex("4F7358"), pond)
	pad.CanCollide = false
	if i % 3 == 0 then
		local flower = ball("Lotus", 0.9, Vector3.new(pad.Position.X, 0.3, pad.Position.Z), C.trim, pond)
		flower.CanCollide = false
	end
end

---------------------------------------------------------------- ฉากหลัง: ต้นสนบนเนิน + กำแพงล่องหนรอบแมพ
local scenery = folder("Scenery")
for i = 1, 60 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(300, 380)
	local x, z = math.cos(angle) * dist, 100 + math.sin(angle) * dist * 1.25
	local h = rng:NextNumber(10, 18)
	cylinder("PineTrunk", 0.9, h * 0.35, Vector3.new(x, h * 0.17, z), C.trunk, scenery)
	for layer = 0, 2 do
		local s = (3 - layer) * 3.2
		local cone = ball("PineLeaves", s, Vector3.new(x, h * 0.35 + layer * h * 0.2 + s * 0.3, z), Color3.fromHex("3F6B45"), scenery, Enum.Material.Grass)
		cone.Size = Vector3.new(s, s * 1.3, s)
	end
end
-- ขอบโลก (กำแพงล่องหน) สร้างโดย WorldBuilder เท่านั้น เพื่อให้ขนาดโลกใหญ่ได้ (±1050) ห้ามสร้างซ้ำที่นี่
-- เดิมมีกำแพงที่ x=±340 ซึ่งขังผู้เล่นไว้ในโรงเรียนเมื่อ WorldBuilder รื้อไม่ทัน

---------------------------------------------------------------- จุดเกิดและโซนปลอดภัย (สนามหน้าโรงเรียน)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 0.4, 12)
spawn.Position = Vector3.new(0, 0.55, 0)
spawn.Color = C.trim
spawn.Material = Enum.Material.Concrete
spawn.Neutral = true
spawn.Transparency = 1 -- แผ่นสีน้ำตาลใหญ่กลางลานดูเหมือนพรมแปลก ซ่อนไว้ (ยังใช้เป็นจุดเกิด/พื้นได้)
spawn.Parent = map
for _, d in spawn:GetChildren() do
	if d:IsA("Decal") then
		d:Destroy()
	end
end

local safe = part("SafeZone", Vector3.new(160, 30, 120), Vector3.new(0, 14, 0), C.roof, map)
safe.Transparency = 1
safe.CanCollide = false
safe.CanQuery = false
safe.CanTouch = false
safe:SetAttribute("SafeZone", true)

---------------------------------------------------------------- แสง: โตเกียวยามเย็น โทนอุ่น หมองลงเล็กน้อย คอนทราสต์สูง (DayNight ปรับต่อตามช่วงเวลา)
-- Lighting.Technology = Future ตั้งจากสคริปต์ตอนเล่นไม่ได้ ต้องตั้งใน Edit (tools/RealisticLighting.luau) แล้วเซฟ Place
-- ค่าอื่นทั้งหมดตั้งจากสคริปต์ตอนเล่นเสมอ จึงไม่ขึ้นกับ Properties ที่บันทึกใน Place
for _, name in { "Atmosphere", "BloomEffect", "SunRaysEffect", "ColorCorrectionEffect", "DepthOfFieldEffect" } do
	for _, e in Lighting:GetChildren() do
		if e.ClassName == name then
			e:Destroy()
		end
	end
end
Lighting.Brightness = 2.3
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.OutdoorAmbient = Color3.fromRGB(125, 118, 112)
Lighting.Ambient = Color3.fromRGB(78, 76, 80)
Lighting.ColorShift_Top = Color3.fromHex("FFD9A8")
Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
Lighting.ExposureCompensation = 0
Lighting.GeographicLatitude = 35
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.3
Lighting.ClockTime = 16.2

local atmosphere = Instance.new("Atmosphere")
atmosphere.Color = Color3.fromHex("C9B9A6")
atmosphere.Decay = Color3.fromHex("D9A070")
atmosphere.Density = 0.13
atmosphere.Offset = 0.08
atmosphere.Haze = 0.1
atmosphere.Glare = 0.15
atmosphere.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.22
bloom.Size = 22
bloom.Threshold = 1.2
bloom.Parent = Lighting
local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.04
sunRays.Spread = 0.6
sunRays.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = -0.03
cc.Contrast = 0.12
cc.Brightness = -0.02
cc.TintColor = Color3.fromHex("FFFDF8")
cc.Parent = Lighting

---------------------------------------------------------------- NPC ทดสอบหลังโรงเรียน
local npcs = workspace:FindFirstChild("Npcs") or Instance.new("Folder")
npcs.Name = "Npcs"
npcs.Parent = workspace

-- มอนทดสอบหลังโรงเรียนถูกย้ายออก: ศัตรูอยู่ที่ค่ายแก๊งของแต่ละย่านแทน (CampService)

-- แท็กให้ไฮไลต์/ระบบอื่นเรียกใช้ภายหลังได้
CollectionService:AddTag(map, "SchoolMap")
print(string.format("[Build] MapBuilder %.1fs", os.clock() - __mapT0))
workspace:SetAttribute("SchoolMapReady", true)
