--!strict
-- สร้างโลกเปิดรอบโรงเรียน: ขยาย Terrain, ถนน, 7 ย่านต่างธีม, จุดเดินทาง (Stone) และขอบโลก
-- รอให้ MapBuilder สร้างโรงเรียนเสร็จก่อน (ดูจากโฟลเดอร์ Npcs ที่ถูกสร้างตอนท้าย) แล้วค่อยต่อ
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.World)
local BK = require(script.Parent.BuildKit)

workspace:WaitForChild("Npcs")
task.wait(1)

local hex = Color3.fromHex
local rng = BK.rng
local terrain = workspace.Terrain

local old = workspace:FindFirstChild("World")
if old then
	old:Destroy()
end
local worldFolder = Instance.new("Folder")
worldFolder.Name = "World"
worldFolder.Parent = workspace

local function sub(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

---------------------------------------------------------------- ขอบโลก + พื้นหญ้ากว้าง
local scenery = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Scenery")
if scenery then
	for _, c in scenery:GetChildren() do
		if c.Name == "WorldBound" then
			c:Destroy()
		end
	end
end

local B = World.Bounds
local width, depth = B.MaxX - B.MinX, B.MaxZ - B.MinZ
local bounds = sub(worldFolder, "Bounds")
for _, wall in {
	{ Vector3.new((B.MinX + B.MaxX) / 2, 40, B.MinZ), Vector3.new(width, 120, 2) },
	{ Vector3.new((B.MinX + B.MaxX) / 2, 40, B.MaxZ), Vector3.new(width, 120, 2) },
	{ Vector3.new(B.MinX, 40, (B.MinZ + B.MaxZ) / 2), Vector3.new(2, 120, depth) },
	{ Vector3.new(B.MaxX, 40, (B.MinZ + B.MaxZ) / 2), Vector3.new(2, 120, depth) },
} do
	local p = BK.part("WorldBound", wall[2], wall[1], hex("FFFFFF"), bounds)
	p.Transparency = 1
	p.CanQuery = false
end

-- ปูหญ้าเป็นแผ่น ๆ (ไม่ทับพื้นที่โรงเรียนที่ MapBuilder เติมไว้แล้ว ซ้ำก็ไม่เสียหาย)
-- ถ้าปั้นภูมิประเทศธรรมชาติไว้ใน Place แล้ว (tools/TerrainBake.luau ตั้ง TerrainBaked) จะไม่ปูทับ
if workspace:GetAttribute("TerrainBaked") ~= true then
	local tile = 400
	for x = B.MinX, B.MaxX - 1, tile do
		for z = B.MinZ, B.MaxZ - 1, tile do
			terrain:FillBlock(CFrame.new(x + tile / 2, -6, z + tile / 2), Vector3.new(tile, 12, tile), Enum.Material.Grass)
		end
		task.wait()
	end
end

---------------------------------------------------------------- ถนน
local roads = sub(worldFolder, "Roads")
for _, r in World.Roads do
	BK.road(roads, r[1], r[2], r[3], r[4], r[5])
end
-- ทางเชื่อมจากโรงเรียนไปถนนสายหลัก: ต่อจากทางหลังโรงเรียน/อารีน่า (x=0) ที่ z=130..210 ถึงถนนที่ z=170 อยู่แล้ว
-- ทางฝั่งตะวันตก/ตะวันออกของถนนสายหลัก ผ่านใต้โรงเรียน
-- (ถนนสายหลักตัดทางเดิน Path_War ที่ z=170 โดยตรง)

---------------------------------------------------------------- ตัวช่วยร่วม
local function ramp(parent: Instance, x1: number, y1: number, x2: number, y2: number, zc: number, w: number, color: Color3)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	local mid = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, zc)
	local p = BK.part("Ramp", Vector3.new(length, 1, w), mid, color, parent)
	p.CFrame = CFrame.new(mid - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.atan2(dy, dx))
end

local function onRoadBand(x: number, z: number, margin: number): boolean
	for _, r in World.Roads do
		local x1, z1, x2, z2, w = r[1], r[2], r[3], r[4], r[5]
		if x >= math.min(x1, x2) - margin and x <= math.max(x1, x2) + margin and z >= math.min(z1, z2) - margin and z <= math.max(z1, z2) + margin then
			local horizontal = math.abs(x2 - x1) >= math.abs(z2 - z1)
			if horizontal and math.abs(z - z1) < w / 2 + margin then
				return true
			elseif not horizontal and math.abs(x - x1) < w / 2 + margin then
				return true
			end
		end
	end
	return false
end

local function randomIn(cx: number, cz: number, radius: number): (number, number)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = radius * math.sqrt(rng:NextNumber())
	return cx + math.cos(a) * r, cz + math.sin(a) * r
end

local function stone(d: World.District, folder: Instance, pos: Vector3)
	local base = BK.cylinder("TravelStone", 2.6, 0.6, pos + Vector3.new(0, 0.5, 0), hex("B5B8C2"), folder, Enum.Material.Marble)
	local crystal = BK.ball("TravelCrystal", 2.2, pos + Vector3.new(0, 3.2, 0), hex("7EC8E3"), folder, Enum.Material.Neon)
	crystal.Transparency = 0.2
	BK.light(crystal, hex("7EC8E3"), 24, 1.2)
	BK.sign(folder, d.Name, Vector3.new(8, 1.6, 0.3), pos + Vector3.new(0, 6, 0), 180, hex("2B2D42"), hex("FFE066")).Name = "StoneSign"
	base.Name = "TravelStone"
	folder:SetAttribute("StonePos", pos + Vector3.new(0, 3, 6))
end

---------------------------------------------------------------- สวนซากุระ
local function buildPark(d: World.District, f: Folder)
	local cx, cz = d.Center.X, d.Center.Z
	-- สระน้ำ + สะพาน
	local px, pz = cx - 60, cz - 75
	terrain:FillCylinder(CFrame.new(px, -3.4, pz), 6, 22, Enum.Material.Water)
	ramp(f, px - 34, 0.3, px - 26, 2.2, pz, 5, hex("9C7A54"))
	BK.box("BridgeDeck", px - 26, px + 26, 1.7, 2.2, pz - 2.5, pz + 2.5, hex("9C7A54"), f, Enum.Material.WoodPlanks)
	ramp(f, px + 26, 2.2, px + 34, 0.3, pz, 5, hex("9C7A54"))
	for _, z in { pz - 2.3, pz + 2.3 } do
		BK.box("BridgeRail", px - 26, px + 26, 2.2, 4, z - 0.15, z + 0.15, hex("FFB7C5"), f)
	end
	for i = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local s = rng:NextNumber(2.5, 4)
		local rock = BK.ball("Rock", s, Vector3.new(px + math.cos(a) * 23.5, s * 0.25, pz + math.sin(a) * 23.5), hex("B5B8C2"), f, Enum.Material.Slate)
		rock.Size = Vector3.new(s, s * 0.65, s * 0.9)
	end
	-- ต้นไม้
	for i = 1, 34 do
		local x, z = randomIn(cx, cz, d.Radius * 0.95)
		if not onRoadBand(x, z, 10) and (Vector2.new(x, z) - Vector2.new(px, pz)).Magnitude > 30 then
			if i % 4 == 0 then
				BK.roundTree(f, x, z, rng:NextNumber(0.9, 1.3))
			else
				BK.sakura(f, x, z, rng:NextNumber(0.9, 1.4))
			end
		end
	end
	-- ลานศาลา (ผู้ให้ภารกิจ) + ศาลาพัก
	local gx, gz = cx + d.GiverOffset.X, cz + d.GiverOffset.Z
	BK.cylinder("PlazaDisc", 14, 0.4, Vector3.new(gx, 0.2, gz), hex("F1E4D3"), f)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		BK.cylinder("GazeboPost", 0.5, 9, Vector3.new(gx + math.cos(a) * 8, 4.5, gz + math.sin(a) * 8), hex("FFFFFF"), f)
	end
	BK.cylinder("GazeboRoof", 10.5, 0.8, Vector3.new(gx, 9.4, gz), hex("FFB7C5"), f)
	BK.ball("GazeboTop", 3, Vector3.new(gx, 10.8, gz), hex("FFE066"), f, Enum.Material.Neon)
	-- ที่เล่นเด็ก
	local sx, sz = cx + 80, cz + 70
	BK.box("SlideTower", sx - 2, sx + 2, 0, 6, sz - 2, sz + 2, hex("EF233C"), f)
	ramp(f, sx + 2, 6, sx + 14, 0.4, sz, 3, hex("FFE066"))
	BK.box("SandBox", sx - 12, sx - 4, 0, 0.8, sz - 4, sz + 4, hex("F2D8A7"), f, Enum.Material.Sand)
	for _, x in { sx - 22, sx - 16 } do
		BK.cylinder("SwingPost", 0.3, 7, Vector3.new(x, 3.5, sz + 10), hex("2B2D42"), f)
		BK.cylinder("SwingPost", 0.3, 7, Vector3.new(x, 3.5, sz + 14), hex("2B2D42"), f)
	end
	BK.box("SwingBar", sx - 22.2, sx - 15.8, 6.6, 7, sz + 11.9, sz + 12.1, hex("2B2D42"), f)
	-- ผ้าปิกนิก + ดอกไม้
	for i = 1, 6 do
		local x, z = randomIn(cx, cz, d.Radius * 0.8)
		if not onRoadBand(x, z, 8) then
			BK.box("Picnic", x - 3, x + 3, 0, 0.2, z - 2.5, z + 2.5, if i % 2 == 0 then hex("EF233C") else hex("FFFFFF"), f)
		end
	end
	for _ = 1, 10 do
		local x, z = randomIn(cx, cz, d.Radius * 0.9)
		if not onRoadBand(x, z, 8) then
			local color = ({ hex("FFB7C5"), hex("FFE066"), hex("FFFFFF"), hex("FF8FAB") })[rng:NextInteger(1, 4)]
			for _ = 1, 9 do
				BK.ball("Flower", 1, Vector3.new(x + rng:NextNumber(-3, 3), 0.7, z + rng:NextNumber(-3, 3)), color, f)
			end
		end
	end
	for x = cx - 120, cx + 120, 40 do
		BK.lamp(f, x, 170 - 11)
		BK.lamp(f, x + 20, 170 + 11)
	end
	stone(d, f, Vector3.new(cx, 0, 170 - 12))
end

---------------------------------------------------------------- ถนนการค้า
local function buildTown(d: World.District, f: Folder)
	local cx = d.Center.X
	local shopNames = { "RAMEN", "ARCADE", "BOOKS", "MART", "CAFE", "TOYS", "SUSHI", "PHARMACY", "GAME", "BAKERY", "KARAOKE", "TEA" }
	local palette = { "FFD6E0", "FFF1C9", "D6F0FF", "E3F8D8", "F3DCFF", "FFE2C9" }
	local awnings = { "EF233C", "4D7CFE", "FFB7C5", "5FBF7A", "FFE066", "FF8A3D" }
	local idx = 0
	for _, side in { -1, 1 } do
		-- ทางเท้า
		BK.box("Sidewalk", cx - 130, cx + 130, 0, 0.45, 170 + side * 8 - (if side == 1 then 0 else 5), 170 + side * 8 + (if side == 1 then 5 else 0), hex("E8E4DC"), f)
		for i = -6, 6 do
			idx += 1
			local x = cx + i * 20
			local h = rng:NextNumber(10, 17)
			local z = 170 + side * (13 + 9)
			BK.building(f, x, z, 17, 18, h, hex(palette[(idx % #palette) + 1]), hex("5B6CA8"), {
				SignText = shopNames[(idx % #shopNames) + 1],
				Facing = -side,
				Awning = hex(awnings[(idx % #awnings) + 1]),
				SignBg = hex("2B2D42"),
				SignFg = hex(awnings[((idx + 2) % #awnings) + 1]),
			})
		end
	end
	-- โคมไฟกระดาษ + เสาไฟ
	for i = -6, 6 do
		local x = cx + i * 20 + 10
		for _, side in { -1, 1 } do
			BK.cylinder("Pole", 0.35, 10, Vector3.new(x, 5, 170 + side * 8.5), hex("2B2D42"), f)
			local lantern = BK.ball("Lantern", 1.8, Vector3.new(x, 10.4, 170 + side * 8.5), hex("FF8A3D"), f, Enum.Material.Neon)
			BK.light(lantern, hex("FFB36B"), 24, 1)
		end
	end
	-- ซุ้มประตูหัวท้ายถนน
	for _, x in { cx - 125, cx + 125 } do
		for _, z in { 170 - 10, 170 + 10 } do
			BK.box("ArchPillar", x - 1, x + 1, 0, 12, z - 1, z + 1, hex("EF233C"), f)
		end
		BK.box("ArchBeam", x - 1.4, x + 1.4, 11, 13, 170 - 11.4, 170 + 11.4, hex("EF233C"), f)
		BK.sign(f, "SHOTENGAI", Vector3.new(16, 2.2, 0.4), Vector3.new(x, 14.2, 170), if x < cx then -90 else 90, hex("2B2D42"), hex("FFE066"))
	end
	-- ตู้กดน้ำและม้านั่งริมทาง
	for i, x in { cx - 50, cx + 30, cx + 90 } do
		BK.box("Vending", x, x + 3, 0.45, 7, 170 - 10.5 - 2.5, 170 - 10.5, if i % 2 == 0 then hex("EF233C") else hex("4D7CFE"), f)
	end
	stone(d, f, Vector3.new(cx + 10, 0, 170 - 10.5))
end

---------------------------------------------------------------- ค่ายในป่า
local function buildForest(d: World.District, f: Folder)
	local cx, cz = d.Center.X, d.Center.Z
	for _ = 1, 90 do
		local x, z = randomIn(cx, cz, d.Radius * 1.05)
		if not onRoadBand(x, z, 9) and (Vector2.new(x, z) - Vector2.new(cx, cz)).Magnitude > 18 then
			BK.pine(f, x, z, rng:NextNumber(12, 22))
		end
	end
	-- กองไฟกลางค่าย + ที่นั่งซุง
	BK.cylinder("FireRing", 3, 0.6, Vector3.new(cx, 0.4, cz), hex("5A5F6E"), f, Enum.Material.Slate)
	local fire = BK.ball("Campfire", 2.4, Vector3.new(cx, 1.6, cz), hex("FF8A3D"), f, Enum.Material.Neon)
	BK.light(fire, hex("FF8A3D"), 40, 1.8)
	local flame = Instance.new("ParticleEmitter")
	flame.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	flame.Color = ColorSequence.new(hex("FFE066"), hex("FF4D2E"))
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	flame.Lifetime = NumberRange.new(0.6, 1.2)
	flame.Speed = NumberRange.new(3, 6)
	flame.Acceleration = Vector3.new(0, 4, 0)
	flame.Rate = 30
	flame.LightEmission = 1
	flame.EmissionDirection = Enum.NormalId.Top
	flame.Parent = fire
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local log = BK.cylinder("Log", 0.8, 5, Vector3.new(cx + math.cos(a) * 7, 0.8, cz + math.sin(a) * 7), hex("8D6E63"), f, Enum.Material.Wood)
		log.CFrame = CFrame.new(log.Position) * CFrame.Angles(0, -a, math.rad(90)) * CFrame.Angles(0, 0, 0)
	end
	-- เต็นท์ (กล่อง + หลังคาลาด ด้วยลิ่ม)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.4
		local tx, tz = cx + math.cos(a) * 32, cz + math.sin(a) * 32
		local color = ({ hex("FF8A3D"), hex("4D7CFE"), hex("5FBF7A"), hex("FFB7C5") })[(i % 4) + 1]
		BK.box("TentBase", tx - 4, tx + 4, 0, 4, tz - 5, tz + 5, color, f, Enum.Material.Fabric)
		local wedgeL = Instance.new("WedgePart")
		wedgeL.Name = "TentRoof"
		wedgeL.Anchored = true
		wedgeL.Size = Vector3.new(5, 3, 10)
		wedgeL.Color = color
		wedgeL.Material = Enum.Material.Fabric
		wedgeL.CFrame = CFrame.new(tx - 2, 5.5, tz) * CFrame.Angles(0, math.rad(180), 0)
		wedgeL.Parent = f
		local wedgeR = wedgeL:Clone()
		wedgeR.CFrame = CFrame.new(tx + 2, 5.5, tz)
		wedgeR.Parent = f
	end
	-- หอคอยไม้
	local wx, wz = cx - 50, cz + 40
	for _, o in { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } } do
		BK.cylinder("TowerLeg", 0.6, 16, Vector3.new(wx + o[1], 8, wz + o[2]), hex("8D6E63"), f, Enum.Material.Wood)
	end
	BK.box("TowerDeck", wx - 4.5, wx + 4.5, 16, 16.6, wz - 4.5, wz + 4.5, hex("9C7A54"), f, Enum.Material.WoodPlanks)
	BK.box("TowerRoof", wx - 5.5, wx + 5.5, 21, 21.8, wz - 5.5, wz + 5.5, hex("5B6CA8"), f)
	for _, o in { { -4.2, -4.2 }, { 4.2, -4.2 }, { -4.2, 4.2 }, { 4.2, 4.2 } } do
		BK.cylinder("TowerPost", 0.3, 5, Vector3.new(wx + o[1], 18.8, wz + o[2]), hex("8D6E63"), f)
	end
	-- รั้วซุง
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		BK.cylinder("FencePost", 0.6, 5, Vector3.new(cx + math.cos(a) * 55, 2.5, cz + math.sin(a) * 55), hex("8D6E63"), f, Enum.Material.Wood)
	end
	stone(d, f, Vector3.new(cx - 20, 0, cz - 20))
end

---------------------------------------------------------------- ย่านสถานีรถไฟ
local function buildCity(d: World.District, f: Folder)
	local cx, cz = d.Center.X, d.Center.Z
	local palette = { "E8E4DC", "D6F0FF", "FFE2C9", "E3F8D8", "F3DCFF", "C9CED6" }
	local roofs = { "5B6CA8", "2B2D42", "8E94A3" }
	local neonNames = { "BAR", "HOTEL", "BANK", "CINEMA", "PIZZA", "SHOP", "SPA", "GYM", "NOODLE", "BOOK" }
	local idx = 0
	local function tower(x: number, z: number, w: number, dpt: number, facing: number)
		idx += 1
		local h = rng:NextNumber(18, 48)
		BK.building(f, x, z, w, dpt, h, hex(palette[(idx % #palette) + 1]), hex(roofs[(idx % #roofs) + 1]), {
			SignText = neonNames[(idx % #neonNames) + 1],
			Facing = facing,
			SignBg = hex("1A1A22"),
			SignFg = ({ hex("FF4D8D"), hex("4DE1FF"), hex("FFE066"), hex("9B7BFF") })[(idx % 4) + 1],
			GlassColor = hex("FFF3C9"),
		})
	end
	-- ตึกริมถนนสายตะวันออก-ตะวันตก (z=600)
	for x = cx - 280, cx + 280, 38 do
		if math.abs(x - (-90)) > 24 then
			tower(x, 600 - (12 + 14), rng:NextNumber(28, 33), 26, 1)
			if not (x > cx + 100 and x < cx + 240) then -- เว้นที่สถานีฝั่งใต้
				tower(x, 600 + (12 + 14), rng:NextNumber(28, 33), 26, -1)
			end
		end
	end
	-- ตึกริมถนนสายเหนือ-ใต้ (x=-90)
	for z = 250, 560, 40 do
		if math.abs(z - 600) > 40 then
			tower(-90 - (12 + 14), z, 26, rng:NextNumber(28, 34), -1)
			tower(-90 + (12 + 14), z, 26, rng:NextNumber(28, 34), -1)
		end
	end
	-- สถานีรถไฟ
	local sx, sz = cx + 170, 600 + 52
	BK.building(f, sx, sz, 110, 50, 18, hex("F7F1E5"), hex("2B2D42"), { SignText = "STATION", Facing = -1, SignBg = hex("2B2D42"), SignFg = hex("FFE066"), Awning = hex("4D7CFE") })
	-- ชานชาลา + ราง + ขบวนรถ
	BK.box("Platform", sx - 55, sx + 55, 0, 1.2, sz + 25, sz + 45, hex("C9CED6"), f)
	BK.box("PlatformEdge", sx - 55, sx + 55, 1.2, 1.35, sz + 44, sz + 45, hex("FFE066"), f)
	for k = 0, 40 do
		BK.box("Sleeper", sx - 60 + k * 3, sx - 59 + k * 3, 0.1, 0.4, sz + 47, sz + 57, hex("6B5A47"), f)
	end
	for _, z in { sz + 49, sz + 55 } do
		BK.box("Rail", sx - 60, sx + 60, 0.4, 0.7, z - 0.2, z + 0.2, hex("8E94A3"), f)
	end
	for i = 0, 4 do
		local x = sx - 50 + i * 22
		BK.box("Carriage", x - 10, x + 10, 1, 8.5, sz + 49.5, sz + 54.5, hex("F7F1E5"), f)
		BK.box("CarriageStripe", x - 10, x + 10, 4, 5.2, sz + 49.4, sz + 54.6, hex("4D7CFE"), f)
		for w = -1, 1 do
			local win = BK.box("CarriageWindow", x + w * 6 - 1.8, x + w * 6 + 1.8, 5.6, 7.6, sz + 49.35, sz + 49.5, hex("FFF3C9"), f, Enum.Material.Neon)
			win.CanCollide = false
		end
	end
	BK.box("Canopy", sx - 55, sx + 55, 10, 10.6, sz + 25, sz + 46, hex("4D7CFE"), f)
	for x = sx - 50, sx + 50, 25 do
		BK.cylinder("CanopyPost", 0.4, 10, Vector3.new(x, 5.6, sz + 40), hex("2B2D42"), f)
	end
	-- ทางม้าลาย + ไฟจราจร
	for i = -3, 3 do
		BK.box("Crosswalk", -90 - 6.5 + (i + 3) * 2, -90 - 5.5 + (i + 3) * 2, 0.3, 0.36, 588, 596, hex("FFFFFF"), f)
	end
	for _, o in { { -99, 592 }, { -81, 608 } } do
		BK.cylinder("TrafficPole", 0.3, 9, Vector3.new(o[1], 4.5, o[2]), hex("2B2D42"), f)
		for k, c in { hex("EF233C"), hex("FFE066"), hex("5FBF7A") } do
			BK.ball("TrafficLight", 1, Vector3.new(o[1], 9.5 + k * 1.1, o[2]), c, f, Enum.Material.Neon)
		end
	end
	for x = cx - 180, cx + 180, 45 do
		BK.lamp(f, x, 600 - 8)
	end
	stone(d, f, Vector3.new(cx + 40, 0, 600 - 9))
end

---------------------------------------------------------------- ศาลเจ้าบนเนิน
local function buildTemple(d: World.District, f: Folder)
	local cx, cz = d.Center.X, d.Center.Z
	-- เนินเป็นชั้น ๆ (ลานสูงสุด y=27)
	for i = 0, 8 do
		BK.cylinder("HillTier", 62 - i * 5, 3, Vector3.new(cx, 1.5 + i * 3, cz), hex("6FC27A"), f, Enum.Material.Grass)
	end
	-- บันไดขึ้นเนินด้านใต้ พร้อมโทริอิ 3 ชุด
	for i = 1, 19 do
		local z1, z2 = cz + 60 - i * 2, cz + 60 - (i - 1) * 2
		local top = i * 1.42
		BK.box("Step", cx - 5, cx + 5, 0, top, z1, z2, hex("C9CED6"), f)
		if i == 3 or i == 9 or i == 15 then
			BK.torii(f, cx, top, (z1 + z2) / 2, 0, 1)
		end
	end
	for i = 1, 19, 3 do
		local top = i * 1.42
		for _, side in { -1, 1 } do
			local zc = cz + 59 - i * 2
			BK.box("StoneLantern", cx + side * 7 - 0.6, cx + side * 7 + 0.6, top, top + 3, zc - 0.6, zc + 0.6, hex("B5B8C2"), f, Enum.Material.Slate)
			local glow = BK.ball("LanternGlow", 1.2, Vector3.new(cx + side * 7, top + 3.4, zc), hex("FFE066"), f, Enum.Material.Neon)
			BK.light(glow, hex("FFE066"), 16, 0.9)
		end
	end
	-- ศาลเจ้าบนยอด
	local topY = 27
	BK.box("ShrineBase", cx - 11, cx + 11, topY, topY + 1.2, cz - 10, cz + 10, hex("B5B8C2"), f, Enum.Material.Slate)
	BK.box("ShrineHall", cx - 8, cx + 8, topY + 1.2, topY + 9, cz - 6, cz + 6, hex("8D6E63"), f, Enum.Material.Wood)
	for _, o in { { -8, 6 }, { 8, 6 }, { -8, -6 }, { 8, -6 } } do
		BK.cylinder("ShrinePillar", 0.7, 8.4, Vector3.new(cx + o[1], topY + 5.4, cz + o[2]), hex("E8352E"), f)
	end
	BK.box("ShrineRoof1", cx - 11, cx + 11, topY + 9, topY + 10.2, cz - 9, cz + 9, hex("2B2D42"), f)
	BK.box("ShrineRoof2", cx - 8, cx + 8, topY + 10.2, topY + 11.4, cz - 6.5, cz + 6.5, hex("2B2D42"), f)
	BK.box("ShrineRoof3", cx - 4, cx + 4, topY + 11.4, topY + 12.6, cz - 3.5, cz + 3.5, hex("2B2D42"), f)
	BK.ball("ShrineOrb", 2, Vector3.new(cx, topY + 13.6, cz), hex("FFE066"), f, Enum.Material.Neon)
	local bell = BK.ball("Bell", 2.2, Vector3.new(cx, topY + 5, cz + 8.5), hex("FFE066"), f, Enum.Material.Metal)
	BK.light(bell, hex("FFE066"), 18, 0.8)
	-- ต้นซากุระรอบเนิน + ตะเกียง
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local x, z = cx + math.cos(a) * 82, cz + math.sin(a) * 82
		if not onRoadBand(x, z, 10) then
			BK.sakura(f, x, z, 1.2)
		end
	end
	stone(d, f, Vector3.new(cx + 12, 0, cz + 66))
end

---------------------------------------------------------------- โรงเรียนคุโรกาเนะ
local function buildRivalSchool(d: World.District, f: Folder)
	local cx, cz = d.Center.X, d.Center.Z
	local dark, darker = hex("4A4D68"), hex("1A1A28")
	BK.building(f, cx, cz - 48, 112, 36, 34, dark, darker, { SignText = "KUROGANE HIGH", Facing = 1, SignBg = hex("14141E"), SignFg = hex("9B7BFF") })
	for _, x in { cx - 70, cx + 70 } do
		BK.building(f, x, cz - 38, 22, 24, 22, dark, darker, { Windows = true })
	end
	-- ลานโรงเรียนกระเบื้องเข้ม + รั้ว
	BK.box("Courtyard", cx - 95, cx + 95, 0, 0.32, cz - 28, cz + 100, hex("3A3D5C"), f)
	for ix = -9, 9 do
		for iz = 0, 11 do
			if (ix + iz) % 2 == 0 then
				BK.box("CourtyardTile", cx + ix * 10 - 5, cx + ix * 10 + 5, 0.32, 0.38, cz - 28 + iz * 10, cz - 18 + iz * 10, hex("4A4D68"), f)
			end
		end
	end
	for _, sidex in { -95, 95 } do
		BK.box("FenceSide", cx + sidex - 0.5, cx + sidex + 0.5, 0, 7, cz - 28, cz - 7, darker, f)
		BK.box("FenceSide", cx + sidex - 0.5, cx + sidex + 0.5, 0, 7, cz + 7, cz + 100, darker, f) -- เว้นช่องถนนที่ z=600
	end
	BK.box("FenceBackL", cx - 95, cx - 8, 0, 7, cz + 100 - 0.5, cz + 100.5, darker, f)
	BK.box("FenceBackR", cx + 8, cx + 95, 0, 7, cz + 100 - 0.5, cz + 100.5, darker, f)
	for _, x in { cx - 10, cx + 10 } do
		BK.box("GatePillar", x - 1.5, x + 1.5, 0, 11, cz + 98.5, cz + 101.5, hex("14141E"), f)
	end
	BK.box("GateBar", cx - 10, cx + 10, 10, 11.4, cz + 99, cz + 101, hex("14141E"), f)
	BK.sign(f, "KUROGANE", Vector3.new(14, 2.2, 0.4), Vector3.new(cx, 12.8, cz + 100.4), 180, hex("14141E"), hex("9B7BFF"))
	-- ธงม่วง + เสาไฟ
	for _, x in { cx - 40, cx + 40 } do
		BK.cylinder("FlagPole", 0.3, 18, Vector3.new(x, 9, cz + 20), hex("C9CED6"), f)
		BK.box("Flag", x + 0.3, x + 6.5, 12, 17, cz + 19.8, cz + 20.2, hex("7B5BDF"), f)
	end
	for _, x in { cx - 60, cx, cx + 60 } do
		BK.lamp(f, x, cz + 55, hex("9B7BFF"))
	end
	for i = 0, 5 do
		BK.box("BikeRack", cx + 60 + i * 2, cx + 60.3 + i * 2, 0.3, 2.5, cz + 80, cz + 84, hex("2B2D42"), f)
	end
	stone(d, f, Vector3.new(cx - 10, 0, cz + 88))
end

---------------------------------------------------------------- ท่าเรืออุตสาหกรรม
local function buildDocks(d: World.District, f: Folder)
	local cx, cz = d.Center.X, d.Center.Z
	-- อ่าวน้ำด้านตะวันออก
	terrain:FillBlock(CFrame.new(cx + 180, -3.4, cz + 20), Vector3.new(110, 6, 420), Enum.Material.Water)
	BK.box("Pier", cx + 70, cx + 135, 0, 1.2, cz + 15, cz + 25, hex("9C7A54"), f, Enum.Material.WoodPlanks)
	for x = cx + 75, cx + 135, 10 do
		BK.cylinder("PierPost", 0.6, 4, Vector3.new(x, -0.5, cz + 14.6), hex("6B5A47"), f, Enum.Material.Wood)
		BK.cylinder("PierPost", 0.6, 4, Vector3.new(x, -0.5, cz + 25.4), hex("6B5A47"), f, Enum.Material.Wood)
	end
	-- เรือบรรทุกสินค้า
	local sx, sz = cx + 165, cz + 20
	BK.box("ShipHull", sx - 14, sx + 14, -1, 9, sz - 45, sz + 45, hex("8E2B2B"), f)
	BK.box("ShipDeck", sx - 14, sx + 14, 9, 9.6, sz - 45, sz + 45, hex("5B6CA8"), f)
	BK.box("ShipCabin", sx - 10, sx + 10, 9.6, 20, sz + 18, sz + 38, hex("F7F1E5"), f)
	for _, z in { sz + 20, sz + 28, sz + 36 } do
		local win = BK.box("ShipWindow", sx - 10.1, sx + 10.1, 14, 16, z - 1.5, z + 1.5, hex("FFF3C9"), f, Enum.Material.Neon)
		win.CanCollide = false
	end
	BK.cylinder("ShipFunnel", 2, 6, Vector3.new(sx, 23, sz + 28), hex("EF233C"), f)
	-- ตู้คอนเทนเนอร์เป็นแถว
	local colors = { "EF233C", "4D7CFE", "FFE066", "5FBF7A", "FF8A3D", "9B7BFF" }
	for row = 0, 3 do
		for col = 0, 7 do
			local x = cx - 60 + col * 13
			local z = cz + 40 + row * 18
			local stack = rng:NextInteger(1, 3)
			for s = 0, stack - 1 do
				BK.box("Container", x - 5.5, x + 5.5, 0.3 + s * 5.2, 5.5 + s * 5.2, z - 2.5, z + 2.5, hex(colors[rng:NextInteger(1, #colors)]), f, Enum.Material.Metal)
			end
		end
	end
	-- คลังสินค้า
	BK.building(f, cx - 90, cz - 70, 60, 36, 18, hex("C9CED6"), hex("5B6CA8"), { SignText = "WAREHOUSE", Facing = 1, SignBg = hex("2B2D42"), SignFg = hex("FF8A3D") })
	BK.building(f, cx + 10, cz - 80, 40, 30, 14, hex("D6F0FF"), hex("5B6CA8"), { Windows = true })
	-- เครนยักษ์
	for _, x in { cx + 40, cx + 70 } do
		for _, z in { cz - 30, cz - 14 } do
			BK.cylinder("CraneLeg", 0.8, 28, Vector3.new(x, 14, z), hex("FF8A3D"), f)
		end
		BK.box("CraneBeam", x - 1, x + 1, 27, 29, cz - 38, cz + 28, hex("FF8A3D"), f)
	end
	for x = cx - 120, cx + 120, 45 do
		BK.lamp(f, x, 600 + 10, hex("FFB36B"))
	end
	stone(d, f, Vector3.new(cx - 100, 0, 600 + 10))
end

---------------------------------------------------------------- ลงมือสร้างทุกย่าน
local builders: { [string]: (World.District, Folder) -> () } = {
	park = buildPark,
	town = buildTown,
	forest = buildForest,
	city = buildCity,
	temple = buildTemple,
	rivalSchool = buildRivalSchool,
	industrial = buildDocks,
}

local districtsFolder = sub(worldFolder, "Districts")
for _, d in World.Districts do
	local f = sub(districtsFolder, d.Id)
	f:SetAttribute("CenterX", d.Center.X)
	f:SetAttribute("CenterZ", d.Center.Z)
	local build = builders[d.Theme]
	if build then
		local ok, err = pcall(build, d, f)
		if not ok then
			warn(`[WorldBuilder] สร้างย่าน {d.Id} ไม่สำเร็จ: {err}`)
		end
	end
	task.wait()
end

worldFolder:SetAttribute("Built", true)
