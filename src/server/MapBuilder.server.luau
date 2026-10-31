--!strict
-- สร้างแมพโรงเรียนจากโค้ด (ก่อนมีงานโมเดลจริงจาก Blender) ขนาดโซนตามแผน:
-- สนามหน้าโรงเรียน 160x120, อาคารเรียน 3 ชั้น (ชั้นละ 16), ดาดฟ้า 80x60, โรงยิม 100x70,
-- หลังโรงเรียน 60x40, โรงอาหาร 60x50 — แทนที่ด้วยโมเดลจริงภายหลังโดยไม่เปลี่ยนขนาดพื้นที่
local Lighting = game:GetService("Lighting")

local RigFactory = require(script.Parent.RigFactory)

local C = {
	grass = Color3.fromHex("BFE3A0"),
	paving = Color3.fromHex("F1E4D3"),
	concrete = Color3.fromHex("C9CED6"),
	wall = Color3.fromHex("FFFFFF"),
	trim = Color3.fromHex("FFB7C5"),
	glass = Color3.fromHex("BFE9FF"),
	wood = Color3.fromHex("D9B382"),
	roof = Color3.fromHex("7EC8E3"),
	dark = Color3.fromHex("2B2D42"),
	red = Color3.fromHex("EF233C"),
	yellow = Color3.fromHex("FFE066"),
	trunk = Color3.fromHex("8D6E63"),
}

-- ล้างของเดิม (Baseplate เทาของ Studio) แล้วสร้างใหม่ทุกครั้ง
local old = workspace:FindFirstChild("Baseplate")
if old then
	old:Destroy()
end
local existing = workspace:FindFirstChild("Map")
if existing then
	existing:Destroy()
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

local function part(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
): Part
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

-- กล่องวางจากมุมล่าง-ซ้าย: ระบุช่วง x1..x2, y1..y2, z1..z2
local function box(name: string, x1: number, x2: number, y1: number, y2: number, z1: number, z2: number, color: Color3, parent: Instance, material: Enum.Material?): Part
	return part(name, Vector3.new(x2 - x1, y2 - y1, z2 - z1), Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), color, parent, material)
end

local function cylinder(name: string, radius: number, height: number, position: Vector3, color: Color3, parent: Instance): Part
	local p = part(name, Vector3.new(height, radius * 2, radius * 2), position, color, parent)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)) -- ตั้งตรง
	return p
end

local function ball(name: string, diameter: number, position: Vector3, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = part(name, Vector3.one * diameter, position, color, parent, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- ทางลาด/บันไดแบบเอียงตามแกน X จาก (x1,y1) ไป (x2,y2) ที่ศูนย์กลาง z กว้าง width
local function ramp(name: string, x1: number, y1: number, x2: number, y2: number, zc: number, width: number, parent: Instance)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	local mid = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, zc)
	local p = part(name, Vector3.new(length, 1, width), mid, C.concrete, parent)
	p.CFrame = CFrame.new(mid - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.atan2(dy, dx))
	-- ราวกันตก
	for _, side in { -1, 1 } do
		local rail = part(name .. "Rail", Vector3.new(length, 3, 0.4), mid, C.trim, parent)
		rail.CFrame = CFrame.new(mid + Vector3.new(0, 1.5, side * (width / 2 - 0.2))) * CFrame.Angles(0, 0, math.atan2(dy, dx))
	end
end

---------------------------------------------------------------- พื้นและทางเดิน
local ground = folder("Ground")
box("Grass", -350, 350, -1, 0, -250, 450, C.grass, ground, Enum.Material.Grass)
box("SchoolYard", -80, 80, 0, 0.3, -60, 60, C.paving, ground)
box("Cafeteria_Floor", -160, -100, 0, 0.3, -25, 25, C.paving, ground)
box("Gym_Floor", 80, 180, 0, 0.3, -35, 35, C.wood, ground, Enum.Material.WoodPlanks)
box("BackLot", -30, 30, 0, 0.3, 90, 130, C.concrete, ground)
box("War_Floor_Red", -50, 50, 0, 0.3, 210, 260, Color3.fromHex("F4B6B6"), ground)
box("War_Floor_Blue", -50, 50, 0, 0.3, 260, 310, Color3.fromHex("B6D4F4"), ground)
box("Path_Cafeteria", -100, -80, 0, 0.3, -10, 10, C.concrete, ground)
box("Path_BackLot", -10, 10, 0, 0.3, 60, 90, C.concrete, ground)
box("Path_War", -10, 10, 0, 0.3, 130, 210, C.concrete, ground)

---------------------------------------------------------------- อาคารเรียน (x -60..60, z -120..-60)
local school = folder("School")
local X1, X2, Z1, Z2 = -60, 60, -120, -60

for level = 0, 2 do
	local y0 = level * 16
	local y1 = y0 + 16
	-- ผนังหน้า (z=-60) ชั้นล่างเจาะประตูกว้าง 14
	if level == 0 then
		box("FrontWallL", X1, -7, y0, y1, Z2 - 1, Z2, C.wall, school)
		box("FrontWallR", 7, X2, y0, y1, Z2 - 1, Z2, C.wall, school)
		box("FrontDoorTop", -7, 7, y0 + 11, y1, Z2 - 1, Z2, C.wall, school)
	else
		box("FrontWall" .. level, X1, X2, y0, y1, Z2 - 1, Z2, C.wall, school)
	end
	box("BackWall" .. level, X1, X2, y0, y1, Z1, Z1 + 1, C.wall, school)
	box("EastWall" .. level, X2 - 1, X2, y0, y1, Z1, Z2, C.wall, school)
	-- ผนังตะวันตก: ชั้น 2 (level 1) เจาะทางเข้าจากบันไดหนีไฟที่ z -108..-98
	if level == 1 then
		box("WestWall1a", X1, X1 + 1, y0, y1, Z1, -108, C.wall, school)
		box("WestWall1b", X1, X1 + 1, y0, y1, -98, Z2, C.wall, school)
		box("WestDoorTop", X1, X1 + 1, y0 + 9, y1, -108, -98, C.wall, school)
	else
		box("WestWall" .. level, X1, X1 + 1, y0, y1, Z1, Z2, C.wall, school)
	end
	-- หน้าต่างด้านหน้า
	if level > 0 then
		for _, wx in { -45, -15, 15, 45 } do
			local w = part("Window", Vector3.new(10, 6, 0.3), Vector3.new(wx, y0 + 9, Z2 + 0.1), C.glass, school, Enum.Material.Glass)
			w.Transparency = 0.35
			w.CanCollide = false
		end
	end
	-- ขอบตกแต่งสีชมพู
	box("Trim" .. level, X1, X2, y1 - 0.6, y1, Z2, Z2 + 0.4, C.trim, school)
end
-- พื้นชั้น 2, 3 และดาดฟ้า
box("Slab_Floor2", X1, X2, 15.5, 16, Z1, Z2, C.concrete, school)
box("Slab_Floor3", X1, X2, 31.5, 32, Z1, Z2, C.concrete, school)
box("Slab_Roof", X1, X2, 47.5, 48, Z1, Z2, C.roof, school)
-- ทางเดินกว้าง 15 ตามแนวยาวของแต่ละชั้น
for level = 0, 2 do
	box("Corridor" .. level, X1 + 1, X2 - 1, level * 16 + 0.05 + (if level == 0 then 0.3 else 0), level * 16 + 0.2 + (if level == 0 then 0.3 else 0.0), -97.5, -82.5, C.paving, school)
end

-- ดาดฟ้า: อารีน่า PvP 80x60 (พื้นชมพูทับ) + ราวกันตกสูง 3
box("Rooftop", -40, 40, 48, 48.2, Z1, Z2, C.trim, school)
box("RailFront", X1, X2, 48, 51, Z2 - 0.6, Z2, C.wall, school)
box("RailBack", X1, X2, 48, 51, Z1, Z1 + 0.6, C.wall, school)
box("RailEast", X2 - 0.6, X2, 48, 51, Z1, Z2, C.wall, school)
box("RailWestA", X1, X1 + 0.6, 48, 51, Z1, -91, C.wall, school) -- เว้นช่อง z -91..-83 ให้บันไดหนีไฟ
box("RailWestB", X1, X1 + 0.6, 48, 51, -83, Z2, C.wall, school)

-- บันไดหนีไฟด้านตะวันตก 3 ช่วง (เอียง ~18 องศา เดินขึ้นได้): ชั้น1 -> ชั้น2 -> ดาดฟ้า
ramp("EscapeF1", -116, 0, -68, 16, -105, 8, school)
box("EscapeLanding1", -68, -60, 15.5, 16, -109, -92, C.concrete, school)
ramp("EscapeF2", -68, 16, -116, 32, -96, 8, school)
box("EscapeLanding2", -124, -116, 31.5, 32, -100, -83, C.concrete, school)
ramp("EscapeF3", -116, 32, -68, 48, -87, 8, school)
box("EscapeLanding3", -68, -60, 47.5, 48, -91, -83, C.concrete, school)

---------------------------------------------------------------- โรงยิม (x 80..180, z -35..35)
local gym = folder("Gym")
box("GymWallN", 80, 180, 0, 20, -35, -34, C.wall, gym)
box("GymWallS", 80, 180, 0, 20, 34, 35, C.wall, gym)
box("GymWallE", 179, 180, 0, 20, -35, 35, C.wall, gym)
box("GymWallWa", 80, 81, 0, 20, -35, -7, C.wall, gym) -- ประตูฝั่งตะวันตกกว้าง 14
box("GymWallWb", 80, 81, 0, 20, 7, 35, C.wall, gym)
box("GymDoorTop", 80, 81, 11, 20, -7, 7, C.wall, gym)
box("GymStripe", 80, 180, 8, 10, -35, -34.6, C.trim, gym)
box("GymStripeS", 80, 180, 8, 10, 34.6, 35, C.trim, gym)
-- สนามกลาง + อัฒจันทร์ขั้นบันไดตามผนังเหนือ
box("CenterLine", 129.5, 130.5, 0.3, 0.4, -34, 34, C.red, gym)
for i = 1, 4 do
	box("Bleacher" .. i, 90, 170, 0, i * 1.2, -34 + i * 2, -32 + i * 2, C.dark, gym)
end

---------------------------------------------------------------- โรงอาหาร (x -160..-100, z -25..25)
local cafe = folder("Cafeteria")
box("CafeWallN", -160, -100, 0, 12, -25, -24, C.wall, cafe)
box("CafeWallS", -160, -100, 0, 12, 24, 25, C.wall, cafe)
box("CafeWallW", -160, -159, 0, 12, -25, 25, C.wall, cafe)
box("CafeWallEa", -101, -100, 0, 12, -25, -7, C.wall, cafe) -- ประตูฝั่งตะวันออก
box("CafeWallEb", -101, -100, 0, 12, 7, 25, C.wall, cafe)
box("CafeDoorTop", -101, -100, 9, 12, -7, 7, C.wall, cafe)
box("CafeRoof", -161, -99, 12, 13, -26, 26, C.roof, cafe)
for row = -1, 1 do
	for col = 0, 2 do
		local x, z = -145 + col * 16, row * 14
		box("Table", x - 3, x + 3, 2.5, 3, z - 1.5, z + 1.5, C.wood, cafe)
		box("TableLeg", x - 0.4, x + 0.4, 0.3, 2.5, z - 0.4, z + 0.4, C.dark, cafe)
	end
end

---------------------------------------------------------------- หลังโรงเรียน (x -30..30, z 90..130)
local lot = folder("BackLot")
box("FenceN", -30, 30, 0, 6, 129.5, 130, C.concrete, lot)
box("FenceW", -30, -29.5, 0, 6, 90, 130, C.concrete, lot)
box("FenceE", 29.5, 30, 0, 6, 90, 130, C.concrete, lot)
for i = 0, 3 do
	box("Crate", -26 + i * 4, -23 + i * 4, 0.3, 3.3 + (i % 2) * 2, 124, 127, C.wood, lot, Enum.Material.Wood)
end

---------------------------------------------------------------- อารีน่าสงครามแก๊ง (x -50..50, z 210..310)
local war = folder("WarArena")
for _, z in { 209, 311 } do
	box("WarWall", -51, 51, 0, 5, z - 1, z + 1, C.dark, war)
end
for _, x in { -51, 51 } do
	box("WarWallSide", x - 1, x + 1, 0, 5, 209, 311, C.dark, war)
end
box("CoverRed", -12, -6, 0.3, 4, 225, 229, C.red, war)
box("CoverRed", 6, 12, 0.3, 4, 225, 229, C.red, war)
box("CoverBlue", -12, -6, 0.3, 4, 291, 295, Color3.fromHex("4D7CFE"), war)
box("CoverBlue", 6, 12, 0.3, 4, 291, 295, Color3.fromHex("4D7CFE"), war)
box("CoverMid", -4, 4, 0.3, 4, 258, 262, C.concrete, war)

---------------------------------------------------------------- ของตกแต่งสนามหน้าโรงเรียน
local props = folder("Props")

local function sakura(x: number, z: number)
	cylinder("Trunk", 1.2, 9, Vector3.new(x, 4.5, z), C.trunk, props)
	ball("Crown", 15, Vector3.new(x, 13, z), C.trim, props, Enum.Material.Grass)
	ball("Crown", 10, Vector3.new(x + 4, 11, z + 3), Color3.fromHex("FFD6E0"), props, Enum.Material.Grass)
end
for _, p in { { -65, 40 }, { 65, 40 }, { -65, -45 }, { 65, -45 }, { -30, 52 }, { 30, 52 } } do
	sakura(p[1], p[2])
end

local function bench(x: number, z: number)
	box("BenchSeat", x - 3, x + 3, 1.6, 2.1, z - 1, z + 1, C.wood, props, Enum.Material.Wood)
	box("BenchBack", x - 3, x + 3, 2.1, 4, z - 1, z - 0.6, C.wood, props, Enum.Material.Wood)
	box("BenchLegL", x - 2.6, x - 2.2, 0.3, 1.6, z - 0.8, z + 0.8, C.dark, props)
	box("BenchLegR", x + 2.2, x + 2.6, 0.3, 1.6, z - 0.8, z + 0.8, C.dark, props)
end
for _, p in { { -40, 40 }, { 40, 40 }, { -40, -35 }, { 40, -35 } } do
	bench(p[1], p[2])
end

local function lamp(x: number, z: number)
	cylinder("Pole", 0.4, 12, Vector3.new(x, 6.3, z), C.dark, props)
	local bulb = ball("Bulb", 2, Vector3.new(x, 12.8, z), C.yellow, props, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 28, 1.2, C.yellow
	light.Parent = bulb
end
for _, p in { { -20, 20 }, { 20, 20 }, { -20, -30 }, { 20, -30 }, { 0, 75 }, { 0, 170 } } do
	lamp(p[1], p[2])
end

-- เสาธงและลานกลาง
cylinder("FlagPole", 0.5, 24, Vector3.new(0, 12.3, 30), C.concrete, props)
box("Flag", 0.5, 8, 19, 25, 29.7, 30.3, C.red, props)

---------------------------------------------------------------- จุดเกิดและโซนปลอดภัย (สนามหน้าโรงเรียน)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 0.4, 12)
spawn.Position = Vector3.new(0, 0.5, 0)
spawn.Color = C.trim
spawn.Neutral = true
spawn.Parent = map

local safe = part("SafeZone", Vector3.new(160, 30, 120), Vector3.new(0, 14, 0), C.roof, map)
safe.Transparency = 1
safe.CanCollide = false
safe.CanQuery = false
safe.CanTouch = false
safe:SetAttribute("SafeZone", true)

---------------------------------------------------------------- แสง บรรยากาศแบบพาสเทล
for _, name in { "Atmosphere", "BloomEffect", "SunRaysEffect", "ColorCorrectionEffect" } do
	local e = Lighting:FindFirstChildOfClass(name)
	if e then
		e:Destroy()
	end
end
Lighting.Brightness = 2.5
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 170)
Lighting.Ambient = Color3.fromRGB(120, 120, 135)
Lighting.ClockTime = 14

local atmosphere = Instance.new("Atmosphere")
atmosphere.Color = Color3.fromHex("FFE9F0")
atmosphere.Density = 0.2
atmosphere.Haze = 0.5
atmosphere.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.25
bloom.Size = 20
bloom.Parent = Lighting
local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.08
sunRays.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.15
cc.Contrast = 0.05
cc.Parent = Lighting

---------------------------------------------------------------- NPC ทดสอบหลังโรงเรียน
local npcs = workspace:FindFirstChild("Npcs") or Instance.new("Folder")
npcs.Name = "Npcs"
npcs.Parent = workspace

task.spawn(function()
	for i = 1, 4 do
		RigFactory.Create("Gangster", Vector3.new(-15 + i * 8, 4, 110), npcs, { NpcLevel = 1 }, C.red)
	end
end)
