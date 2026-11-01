--!strict
-- สร้างโลกเปิดรอบโรงเรียน: ขยาย Terrain, ถนน, 7 ย่านต่างธีม, จุดเดินทาง (Stone) และขอบโลก
-- รอให้ MapBuilder สร้างโรงเรียนเสร็จก่อน (ดูจากโฟลเดอร์ Npcs ที่ถูกสร้างตอนท้าย) แล้วค่อยต่อ
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World = require(ReplicatedStorage.Shared.World)
local BK = require(script.Parent.BuildKit)

-- เพิ่มเลขนี้ทุกครั้งที่แก้โลก: ถ้าใน Place มีโลกที่สร้างไว้ล่วงหน้า (รันใน Edit) เวอร์ชันตรงกัน ตอนเล่นจะข้ามการสร้างใหม่
local VERSION = 5
local running = RunService:IsRunning()
local prebuilt = workspace:FindFirstChild("World")
if running and prebuilt and prebuilt:GetAttribute("Built") and prebuilt:GetAttribute("Version") == VERSION then
	-- โลกสร้างไว้แล้ว แต่ถ้าไม่ได้ปั้นภูมิประเทศ MapBuilder จะล้าง Terrain ตอนเริ่ม ต้องปูหญ้าเรียบใหม่ไม่งั้นไม่มีพื้น
	if workspace:GetAttribute("TerrainBaked") ~= true then
		task.wait(2)
		local started = os.clock()
		while workspace:GetAttribute("SchoolMapReady") ~= true and os.clock() - started < 240 do
			task.wait(0.5)
		end
		local B = World.Bounds
		local tile = 400
		for x = B.MinX - 400, B.MaxX + 399, tile do
			for z = B.MinZ - 400, B.MaxZ + 399, tile do
				workspace.Terrain:FillBlock(CFrame.new(x + tile / 2, -8, z + tile / 2), Vector3.new(tile, 12, tile), Enum.Material.LeafyGrass)
			end
			task.wait()
		end
	end
	return true
end

-- ตอนเล่นจริงรอให้ MapBuilder สร้างโรงเรียนเสร็จก่อน; ตอนรันใน Edit (สร้างล่วงหน้า) ข้ามการรอ
if running then
	-- ห้ามใช้ Npcs เป็นสัญญาณ (ค้างอยู่ใน Place จากโหมด Edit ทำให้ไม่รอ แล้วกำแพง ±340 ของแมพเก่าถูกสร้างทับทีหลัง)
	-- รอให้ MapBuilder ตั้ง SchoolMapReady=false ตอนเริ่ม แล้วรอจน true
	task.wait(2)
	local started = os.clock()
	while workspace:GetAttribute("SchoolMapReady") ~= true and os.clock() - started < 240 do
		task.wait(0.5)
	end
	task.wait(0.5)
end

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
	-- ปูหญ้าเกินขอบโลก 400 studs (เป็นฉากด้านนอกกำแพงล่องหน)
	for x = B.MinX - 400, B.MaxX + 399, tile do
		for z = B.MinZ - 400, B.MaxZ + 399, tile do
			terrain:FillBlock(CFrame.new(x + tile / 2, -8, z + tile / 2), Vector3.new(tile, 12, tile), Enum.Material.LeafyGrass)
		end
		task.wait()
	end
	-- แนวเขาล้อมเมืองอยู่นอกขอบโลกทั้งหมด (ผู้เล่นเข้าไม่ถึง) ใช้เป็นฉากหลังให้สุดสายตาไม่โล่ง
	local function mountain(x: number, z: number, r: number)
		terrain:FillBall(Vector3.new(x, -r * 0.45, z), r, Enum.Material.LeafyGrass)
		terrain:FillBall(Vector3.new(x, -r * 0.45 + r * 0.55, z), r * 0.55, Enum.Material.Rock) -- ยอดเขาเป็นหิน
	end
	-- แนวเขาล้อม 3 ชั้นนอกขอบโลก (pad 80/150/250) ถี่ทุก 100 studs; ชั้นใน r<=80 -> ผิวเขาไม่ล้ำเข้าขอบโลก
	local function ring(pad: number, rBase: number, rVar: number, offset: number)
		local i = 0
		for x = B.MinX - pad, B.MaxX + pad, 100 do
			mountain(x + offset, B.MinZ - pad, rBase + (i % 3) * rVar)
			mountain(x + offset, B.MaxZ + pad, rBase + ((i + 1) % 3) * rVar)
			i += 1
		end
		for z = B.MinZ - pad, B.MaxZ + pad, 100 do
			mountain(B.MinX - pad, z + offset, rBase + (i % 3) * rVar)
			mountain(B.MaxX + pad, z + offset, rBase + ((i + 1) % 3) * rVar)
			i += 1
		end
	end
	ring(80, 70, 5, 0)
	ring(150, 85, 12, 50)
	ring(250, 90, 10, 0)
end

---------------------------------------------------------------- ถนน
local roads = sub(worldFolder, "Roads")
local sidewalks = sub(worldFolder, "Sidewalks")
do
	local roadRng = Random.new(4242)
	local ASPHALT = { A = "3A3B3F", L = "3E3F43", B = "48484B", Y = "4C4A48", T = "6B5A47" }
	local paveColors = { "A9A59B", "B3ADA0", "9C978C", "B9B2A2", "A39C8F", "8F8B83" }
	local paveMats = { Enum.Material.Concrete, Enum.Material.Concrete, Enum.Material.Pavement, Enum.Material.Brick, Enum.Material.Slate }
	local function strip(name: string, horizontal: boolean, a: number, b: number, fixed: number, half: number, y1: number, y2: number, color: Color3, parent: Instance, mat: Enum.Material)
		if horizontal then
			return BK.box(name, a, b, y1, y2, fixed - half, fixed + half, color, parent, mat)
		end
		return BK.box(name, fixed - half, fixed + half, y1, y2, a, b, color, parent, mat)
	end
	for i, r in World.Roads do
		local x1, z1, x2, z2, w, kind = r[1], r[2], r[3], r[4], r[5], r[6]
		local horizontal = math.abs(x2 - x1) >= math.abs(z2 - z1)
		local a1, a2 = if horizontal then math.min(x1, x2) else math.min(z1, z2), if horizontal then math.max(x1, x2) else math.max(z1, z2)
		local fixed = if horizontal then z1 else x1
		local base = strip("Road", horizontal, a1, a2, fixed, w / 2, 0, 0.3, hex(ASPHALT[kind] or "3A3B3F"), roads, if kind == "T" then Enum.Material.Ground else Enum.Material.Asphalt)
		-- ผิวถนนเป็นแผ่นปะ (ซ่อมแซม) ไม่เรียบเนียนเสมอกัน
		if kind ~= "T" and (a2 - a1) > 30 then
			for _ = 1, math.floor((a2 - a1) / 45) do
				local pa = roadRng:NextNumber(a1 + 4, a2 - 10)
				local pw = roadRng:NextNumber(2, 6)
				local ph = roadRng:NextNumber(1.5, math.min(w - 2, 5))
				local po = roadRng:NextNumber(-w / 2 + ph / 2 + 0.5, w / 2 - ph / 2 - 0.5)
				strip("Patch", horizontal, pa, pa + pw, fixed + po, ph / 2, 0.3, 0.33, hex("33343A"), roads, Enum.Material.Asphalt)
			end
		end
		if w >= 14 then
			for _, iv in World.FreeIntervals(i, 0) do
				for t = iv[1] + 3, iv[2] - 8, 12 do
					strip("Dash", horizontal, t, t + 5, fixed, 0.2, 0.3, 0.34, hex("CDB454"), roads, Enum.Material.SmoothPlastic)
				end
			end
		end
		if w >= 10 and kind ~= "T" then
			local sw = if w >= 14 then 3.5 else 2
			for _, side in { -1, 1 } do
				-- ขอบถนน (Curb) + ทางเท้าปูแผ่นเปลี่ยนวัสดุทุกไม่กี่ studs; เว้นตรงแยก
				for _, iv in World.FreeIntervals(i, side * (w / 2)) do
					strip("Curb", horizontal, iv[1], iv[2], fixed + side * (w / 2 + 0.2), 0.2, 0, 0.5, hex("9C9A94"), roads, Enum.Material.Concrete)
					local t = iv[1]
					while t < iv[2] - 0.5 do
						local len = math.min(roadRng:NextNumber(3.5, 9), iv[2] - t)
						local k = roadRng:NextInteger(1, #paveColors)
						local tile = strip("Pave", horizontal, t, t + len, fixed + side * (w / 2 + 0.4 + sw / 2), sw / 2, 0, 0.45, hex(paveColors[k]), sidewalks, paveMats[roadRng:NextInteger(1, #paveMats)])
						tile.Name = "Pave"
						if roadRng:NextNumber() < 0.16 then -- แผ่นนำทางสีเหลือง
							strip("Tactile", horizontal, t, t + len, fixed + side * (w / 2 + 0.9), 0.3, 0.45, 0.5, hex("C9A93C"), sidewalks, Enum.Material.Concrete)
						elseif roadRng:NextNumber() < 0.08 then -- ฝาท่อโลหะ
							local cx = if horizontal then t + len / 2 else fixed + side * (w / 2 + 0.4 + sw / 2)
							local cz = if horizontal then fixed + side * (w / 2 + 0.4 + sw / 2) else t + len / 2
							BK.box("ManholeCover", cx - 1, cx + 1, 0.45, 0.5, cz - 1, cz + 1, hex("55575C"), sidewalks, Enum.Material.Metal)
						end
						t += len
					end
				end
			end
		end
		base.Name = "Road"
	end
end

---------------------------------------------------------------- ตัวช่วยร่วม
local function ramp(parent: Instance, x1: number, y1: number, x2: number, y2: number, zc: number, w: number, color: Color3)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	local mid = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, zc)
	local p = BK.part("Ramp", Vector3.new(length, 1, w), mid, color, parent)
	p.CFrame = CFrame.new(mid - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.atan2(dy, dx))
end

local function onRoadBand(x: number, z: number, margin: number): boolean
	return World.OnRoad(x, z, margin, true)
end

local function randomIn(cx: number, cz: number, radius: number): (number, number)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = radius * math.sqrt(rng:NextNumber())
	return cx + math.cos(a) * r, cz + math.sin(a) * r
end

local function stone(d: World.District, folder: Instance, _pos: Vector3?)
	local pos = World.Stones[d.Id]
	local base = BK.cylinder("TravelStone", 2.6, 0.6, pos + Vector3.new(0, 0.5, 0), hex("8F8E88"), folder, Enum.Material.Marble)
	local crystal = BK.ball("TravelCrystal", 2.2, pos + Vector3.new(0, 3.2, 0), hex("6C8E96"), folder, Enum.Material.Neon)
	crystal.Transparency = 0.2
	BK.light(crystal, hex("6C8E96"), 24, 1.2)
	BK.sign(folder, d.Name, Vector3.new(8, 1.6, 0.3), pos + Vector3.new(0, 6, 0), 180, hex("2A2C32"), hex("B8944A")).Name = "StoneSign"
	base.Name = "TravelStone"
	folder:SetAttribute("StonePos", pos + Vector3.new(0, 3, 6))
end

---------------------------------------------------------------- สวนซากุระ
local function buildPark(d: World.District, f: Folder)
	local cx, cz = d.Center.X, d.Center.Z
	-- สระน้ำ + สะพาน
	local px, pz = cx - 60, cz - 75
	terrain:FillCylinder(CFrame.new(px, -2, pz), 4, 27, Enum.Material.Sand) -- ชายหาดรอบสระ
	terrain:FillCylinder(CFrame.new(px, -1.5, pz), 9, 22, Enum.Material.Air) -- ขุดแอ่ง (ผิว Terrain จริงสูงกว่าที่เขียน ~2 studs)
	terrain:FillCylinder(CFrame.new(px, -6, pz), 6, 22, Enum.Material.Water)
	ramp(f, px - 34, 0.3, px - 26, 2.2, pz, 5, hex("6F5236"))
	BK.box("BridgeDeck", px - 26, px + 26, 1.7, 2.2, pz - 2.5, pz + 2.5, hex("6F5236"), f, Enum.Material.WoodPlanks)
	ramp(f, px + 26, 2.2, px + 34, 0.3, pz, 5, hex("6F5236"))
	for _, z in { pz - 2.3, pz + 2.3 } do
		BK.box("BridgeRail", px - 26, px + 26, 2.2, 4, z - 0.15, z + 0.15, hex("7A5A50"), f)
	end
	for i = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local s = rng:NextNumber(2.5, 4)
		local rock = BK.ball("Rock", s, Vector3.new(px + math.cos(a) * 23.5, s * 0.25, pz + math.sin(a) * 23.5), hex("8F8E88"), f, Enum.Material.Slate)
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
	BK.cylinder("PlazaDisc", 14, 0.4, Vector3.new(gx, 0.2, gz), hex("B5AA98"), f)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		BK.cylinder("GazeboPost", 0.5, 9, Vector3.new(gx + math.cos(a) * 8, 4.5, gz + math.sin(a) * 8), hex("E4E0D6"), f)
	end
	BK.cylinder("GazeboRoof", 10.5, 0.8, Vector3.new(gx, 9.4, gz), hex("7A5A50"), f)
	BK.ball("GazeboTop", 3, Vector3.new(gx, 10.8, gz), hex("B8944A"), f, Enum.Material.Neon)
	-- ที่เล่นเด็ก
	local sx, sz = cx + 80, cz + 70
	BK.box("SlideTower", sx - 2, sx + 2, 0, 6, sz - 2, sz + 2, hex("9E3B33"), f)
	ramp(f, sx + 2, 6, sx + 14, 0.4, sz, 3, hex("B8944A"))
	BK.box("SandBox", sx - 12, sx - 4, 0, 0.8, sz - 4, sz + 4, hex("C9B48A"), f, Enum.Material.Sand)
	for _, x in { sx - 22, sx - 16 } do
		BK.cylinder("SwingPost", 0.3, 7, Vector3.new(x, 3.5, sz + 10), hex("2A2C32"), f)
		BK.cylinder("SwingPost", 0.3, 7, Vector3.new(x, 3.5, sz + 14), hex("2A2C32"), f)
	end
	BK.box("SwingBar", sx - 22.2, sx - 15.8, 6.6, 7, sz + 11.9, sz + 12.1, hex("2A2C32"), f)
	-- ผ้าปิกนิก + ดอกไม้
	for i = 1, 6 do
		local x, z = randomIn(cx, cz, d.Radius * 0.8)
		if not onRoadBand(x, z, 8) then
			BK.box("Picnic", x - 3, x + 3, 0, 0.2, z - 2.5, z + 2.5, if i % 2 == 0 then hex("9E3B33") else hex("E4E0D6"), f)
		end
	end
	for _ = 1, 10 do
		local x, z = randomIn(cx, cz, d.Radius * 0.9)
		if not onRoadBand(x, z, 8) then
			local color = ({ hex("7A5A50"), hex("B8944A"), hex("E4E0D6"), hex("C98A97") })[rng:NextInteger(1, 4)]
			for _ = 1, 9 do
				BK.ball("Flower", 1, Vector3.new(x + rng:NextNumber(-3, 3), 0.7, z + rng:NextNumber(-3, 3)), color, f)
			end
		end
	end
	for x = cx - 120, cx + 120, 40 do
		if not World.OnRoad(x, 170 - 14, 1) then
			BK.lamp(f, x, 170 - 14)
		end
		if not World.OnRoad(x + 20, 170 + 14, 1) then
			BK.lamp(f, x + 20, 170 + 14)
		end
	end
	stone(d, f)
end

---------------------------------------------------------------- ถนนการค้า
-- ถนนสายกลาง z=170 (กว้าง 16) มีหลังคาอาเขตเหล็ก+แผงโปร่งแสง เสาตั้งบนทางเท้า ตึกแถวติดกันสองฝั่งสร้างโดย LotGen
local function buildTown(d: World.District, f: Folder)
	local cx = d.Center.X
	local x1, x2 = cx - 126, cx + 126
	local steel, panelColor = hex("3F4349"), hex("B9C9C4")
	for x = x1, x2, 12 do
		for _, side in { -1, 1 } do
			BK.cylinder("ArcadePost", 0.3, 11, Vector3.new(x, 5.7, 170 + side * 11.7), steel, f, Enum.Material.Metal)
		end
		BK.box("ArcadeRib", x - 0.3, x + 0.3, 11, 12.1, 170 - 12.6, 170 + 12.6, steel, f, Enum.Material.Metal)
		if rng:NextNumber() < 0.5 then
			local lantern = BK.ball("Lantern", 1.6, Vector3.new(x + 6, 9.4, 170 + (if rng:NextNumber() < 0.5 then -5.5 else 5.5)), hex("A8643A"), f, Enum.Material.Neon)
			BK.light(lantern, hex("FFB36B"), 18, 0.9)
			BK.cylinder("LanternCord", 0.06, 1.8, Vector3.new(lantern.Position.X, 10.8, lantern.Position.Z), hex("2A2C32"), f)
		end
	end
	for x = x1, x2 - 12, 12 do
		if rng:NextNumber() < 0.82 then -- บางช่องเปิดโล่ง เห็นฟ้า
			for _, side in { -1, 1 } do
				local p = BK.box("ArcadePanel", x + 0.4, x + 11.6, 11.1, 11.35, 170 + (if side == 1 then 0.2 else -12.4), 170 + (if side == 1 then 12.4 else -0.2), panelColor, f, Enum.Material.Glass)
				p.Transparency = 0.45
				p.CanCollide, p.CanQuery = false, false
			end
		end
	end
	for _, x in { x1 + 6, x2 - 30, cx + 6 } do
		BK.sign(f, "SHOTENGAI", Vector3.new(14, 2.2, 0.4), Vector3.new(x, 9, 170 + (if x > cx then 11.2 else -11.2)), if x > cx then 180 else 0, hex("2A2C32"), hex("B8944A"))
	end
	-- ซุ้มประตูหัวท้ายถนน
	for _, x in { x1 - 8, x2 + 8 } do
		for _, z in { 170 - 12, 170 + 12 } do
			BK.box("ArchPillar", x - 1, x + 1, 0, 12, z - 1, z + 1, hex("9E3B33"), f)
		end
		BK.box("ArchBeam", x - 1.4, x + 1.4, 11, 13, 170 - 13.4, 170 + 13.4, hex("9E3B33"), f)
		BK.sign(f, "SHOTENGAI", Vector3.new(16, 2.2, 0.4), Vector3.new(x, 14.2, 170), if x < cx then -90 else 90, hex("2A2C32"), hex("B8944A"))
	end
	stone(d, f)
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
	BK.cylinder("FireRing", 3, 0.6, Vector3.new(cx, 0.4, cz), hex("555960"), f, Enum.Material.Slate)
	local fire = BK.ball("Campfire", 2.4, Vector3.new(cx, 1.6, cz), hex("A8643A"), f, Enum.Material.Neon)
	BK.light(fire, hex("A8643A"), 40, 1.8)
	local flame = Instance.new("ParticleEmitter")
	flame.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	flame.Color = ColorSequence.new(hex("B8944A"), hex("FF4D2E"))
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
		local log = BK.cylinder("Log", 0.8, 5, Vector3.new(cx + math.cos(a) * 7, 0.8, cz + math.sin(a) * 7), hex("5C4637"), f, Enum.Material.Wood)
		log.CFrame = CFrame.new(log.Position) * CFrame.Angles(0, -a, math.rad(90)) * CFrame.Angles(0, 0, 0)
	end
	-- เต็นท์ (กล่อง + หลังคาลาด ด้วยลิ่ม)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.4
		local tx, tz = cx + math.cos(a) * 32, cz + math.sin(a) * 32
		local color = ({ hex("A8643A"), hex("3F566E"), hex("4F7358"), hex("7A5A50") })[(i % 4) + 1]
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
		BK.cylinder("TowerLeg", 0.6, 16, Vector3.new(wx + o[1], 8, wz + o[2]), hex("5C4637"), f, Enum.Material.Wood)
	end
	BK.box("TowerDeck", wx - 4.5, wx + 4.5, 16, 16.6, wz - 4.5, wz + 4.5, hex("6F5236"), f, Enum.Material.WoodPlanks)
	BK.box("TowerRoof", wx - 5.5, wx + 5.5, 21, 21.8, wz - 5.5, wz + 5.5, hex("4A525C"), f)
	for _, o in { { -4.2, -4.2 }, { 4.2, -4.2 }, { -4.2, 4.2 }, { 4.2, 4.2 } } do
		BK.cylinder("TowerPost", 0.3, 5, Vector3.new(wx + o[1], 18.8, wz + o[2]), hex("5C4637"), f)
	end
	-- รั้วซุง
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		BK.cylinder("FencePost", 0.6, 5, Vector3.new(cx + math.cos(a) * 55, 2.5, cz + math.sin(a) * 55), hex("5C4637"), f, Enum.Material.Wood)
	end
	stone(d, f)
end

---------------------------------------------------------------- ย่านสถานีรถไฟ
-- ตึกทั้งย่านสร้างโดย LotGen; ที่นี่เหลือสถานี ชานชาลา ราง และขบวนรถ (ในพื้นที่ KeepOut "station")
local function buildCity(d: World.District, f: Folder)
	local cx = d.Center.X
	local sx, sz = cx + 170, 600 + 52
	BK.building(f, sx, sz, 110, 50, 18, hex("D9D0BE"), hex("2A2C32"), { SignText = "STATION", Facing = -1, SignBg = hex("2A2C32"), SignFg = hex("B8944A"), Awning = hex("3F566E") })
	-- ลานหน้าสถานี (ปูกระเบื้อง) + ที่จอดแท็กซี่
	BK.box("StationPlaza", sx - 70, sx + 70, 0, 0.35, 610, sz - 25, hex("A39C8F"), f, Enum.Material.Pavement)
	BK.box("Platform", sx - 55, sx + 55, 0, 1.2, sz + 25, sz + 45, hex("A5A7A8"), f)
	BK.box("PlatformEdge", sx - 55, sx + 55, 1.2, 1.35, sz + 44, sz + 45, hex("B8944A"), f)
	for k = 0, 40 do
		BK.box("Sleeper", sx - 60 + k * 3, sx - 59 + k * 3, 0.1, 0.4, sz + 47, sz + 57, hex("6B5A47"), f)
	end
	for _, z in { sz + 49, sz + 55 } do
		BK.box("Rail", sx - 60, sx + 60, 0.4, 0.7, z - 0.2, z + 0.2, hex("70747A"), f)
	end
	for i = 0, 4 do
		local x = sx - 50 + i * 22
		BK.box("Carriage", x - 10, x + 10, 1, 8.5, sz + 49.5, sz + 54.5, hex("D9D0BE"), f)
		BK.box("CarriageStripe", x - 10, x + 10, 4, 5.2, sz + 49.4, sz + 54.6, hex("3F566E"), f)
		for w = -1, 1 do
			local win = BK.box("CarriageWindow", x + w * 6 - 1.8, x + w * 6 + 1.8, 5.6, 7.6, sz + 49.35, sz + 49.5, hex("F0D9A0"), f, Enum.Material.Neon)
			win.CanCollide = false
		end
	end
	BK.box("Canopy", sx - 55, sx + 55, 10, 10.6, sz + 25, sz + 46, hex("3F566E"), f)
	for x = sx - 50, sx + 50, 25 do
		BK.cylinder("CanopyPost", 0.4, 10, Vector3.new(x, 5.6, sz + 40), hex("2A2C32"), f)
	end
	stone(d, f)
end

---------------------------------------------------------------- ศาลเจ้าบนเนิน
local function buildTemple(d: World.District, f: Folder)
	local cx, cz = d.Center.X, d.Center.Z
	-- เนินเป็นชั้น ๆ (ลานสูงสุด y=27)
	for i = 0, 8 do
		BK.cylinder("HillTier", 62 - i * 5, 3, Vector3.new(cx, 1.5 + i * 3, cz), hex("5E8050"), f, Enum.Material.Grass)
	end
	-- บันไดขึ้นเนินด้านใต้ พร้อมโทริอิ 3 ชุด
	for i = 1, 19 do
		local z1, z2 = cz + 60 - i * 2, cz + 60 - (i - 1) * 2
		local top = i * 1.42
		BK.box("Step", cx - 5, cx + 5, 0, top, z1, z2, hex("A5A7A8"), f)
		if i == 3 or i == 9 or i == 15 then
			BK.torii(f, cx, top, (z1 + z2) / 2, 0, 1)
		end
	end
	for i = 1, 19, 3 do
		local top = i * 1.42
		for _, side in { -1, 1 } do
			local zc = cz + 59 - i * 2
			BK.box("StoneLantern", cx + side * 7 - 0.6, cx + side * 7 + 0.6, top, top + 3, zc - 0.6, zc + 0.6, hex("8F8E88"), f, Enum.Material.Slate)
			local glow = BK.ball("LanternGlow", 1.2, Vector3.new(cx + side * 7, top + 3.4, zc), hex("B8944A"), f, Enum.Material.Neon)
			BK.light(glow, hex("B8944A"), 16, 0.9)
		end
	end
	-- ศาลเจ้าบนยอด
	local topY = 27
	BK.box("ShrineBase", cx - 11, cx + 11, topY, topY + 1.2, cz - 10, cz + 10, hex("8F8E88"), f, Enum.Material.Slate)
	BK.box("ShrineHall", cx - 8, cx + 8, topY + 1.2, topY + 9, cz - 6, cz + 6, hex("5C4637"), f, Enum.Material.Wood)
	for _, o in { { -8, 6 }, { 8, 6 }, { -8, -6 }, { 8, -6 } } do
		BK.cylinder("ShrinePillar", 0.7, 8.4, Vector3.new(cx + o[1], topY + 5.4, cz + o[2]), hex("A8352C"), f)
	end
	BK.box("ShrineRoof1", cx - 11, cx + 11, topY + 9, topY + 10.2, cz - 9, cz + 9, hex("2A2C32"), f)
	BK.box("ShrineRoof2", cx - 8, cx + 8, topY + 10.2, topY + 11.4, cz - 6.5, cz + 6.5, hex("2A2C32"), f)
	BK.box("ShrineRoof3", cx - 4, cx + 4, topY + 11.4, topY + 12.6, cz - 3.5, cz + 3.5, hex("2A2C32"), f)
	BK.ball("ShrineOrb", 2, Vector3.new(cx, topY + 13.6, cz), hex("B8944A"), f, Enum.Material.Neon)
	local bell = BK.ball("Bell", 2.2, Vector3.new(cx, topY + 5, cz + 8.5), hex("B8944A"), f, Enum.Material.Metal)
	BK.light(bell, hex("B8944A"), 18, 0.8)
	-- ต้นซากุระรอบเนิน + ตะเกียง
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local x, z = cx + math.cos(a) * 82, cz + math.sin(a) * 82
		if not onRoadBand(x, z, 10) then
			BK.sakura(f, x, z, 1.2)
		end
	end
	stone(d, f)
end

---------------------------------------------------------------- โรงเรียนคุโรกาเนะ
-- รั้วเหล็กดำล้อมลานกระเบื้อง อยู่ใต้ถนน z=600 (ประตูหันเข้าถนน); พื้นที่นี้อยู่ใน KeepOut "kurogane"
local function buildRivalSchool(d: World.District, f: Folder)
	local cx, cz = d.Center.X, d.Center.Z
	local dark, darker = hex("4A4D68"), hex("1A1A28")
	local z0, z1 = cz + 12, cz + 145 -- ลาน: z 612..745
	BK.building(f, cx, z1 - 20, 112, 36, 34, dark, darker, { SignText = "KUROGANE HIGH", Facing = -1, SignBg = hex("14141E"), SignFg = hex("7A6A9A") })
	for _, x in { cx - 70, cx + 70 } do
		BK.building(f, x, z1 - 46, 22, 24, 22, dark, darker, { Windows = true, Facing = -1 })
	end
	BK.box("Courtyard", cx - 95, cx + 95, 0, 0.32, z0, z1, hex("3A3D5C"), f)
	for ix = -9, 9 do
		for iz = 0, 11 do
			if (ix + iz) % 2 == 0 then
				BK.box("CourtyardTile", cx + ix * 10 - 5, cx + ix * 10 + 5, 0.32, 0.38, z0 + iz * 10, z0 + 10 + iz * 10, hex("4A4D68"), f)
			end
		end
	end
	for _, sidex in { -95, 95 } do
		BK.box("FenceSide", cx + sidex - 0.5, cx + sidex + 0.5, 0, 7, z0, z1, darker, f)
	end
	BK.box("FenceBack", cx - 95, cx + 95, 0, 7, z1 - 0.5, z1 + 0.5, darker, f)
	BK.box("FenceFrontL", cx - 95, cx - 12, 0, 7, z0 - 0.5, z0 + 0.5, darker, f)
	BK.box("FenceFrontR", cx + 12, cx + 95, 0, 7, z0 - 0.5, z0 + 0.5, darker, f)
	for _, x in { cx - 11, cx + 11 } do
		BK.box("GatePillar", x - 1.5, x + 1.5, 0, 11, z0 - 1.5, z0 + 1.5, hex("14141E"), f)
	end
	BK.box("GateBar", cx - 11, cx + 11, 10, 11.4, z0 - 1, z0 + 1, hex("14141E"), f)
	BK.sign(f, "KUROGANE", Vector3.new(14, 2.2, 0.4), Vector3.new(cx, 12.8, z0 - 1.4), 0, hex("14141E"), hex("7A6A9A"))
	for _, x in { cx - 40, cx + 40 } do
		BK.cylinder("FlagPole", 0.3, 18, Vector3.new(x, 9, z0 + 30), hex("A5A7A8"), f)
		BK.box("Flag", x + 0.3, x + 6.5, 12, 17, z0 + 29.8, z0 + 30.2, hex("7B5BDF"), f)
	end
	for _, x in { cx - 60, cx, cx + 60 } do
		BK.lamp(f, x, z0 + 50, hex("7A6A9A"))
	end
	for i = 0, 5 do
		BK.box("BikeRack", cx + 60 + i * 2, cx + 60.3 + i * 2, 0.3, 2.5, z0 + 70, z0 + 74, hex("2A2C32"), f)
	end
	stone(d, f)
end

---------------------------------------------------------------- ท่าเรืออุตสาหกรรม
-- อ่าว+ท่าเทียบ+เรือ+เครนอยู่ในพื้นที่ x>=628 (KeepOut "bay"); โกดังและลานตู้คอนเทนเนอร์สร้างโดย LotGen
local function buildDocks(d: World.District, f: Folder)
	local cx, cz = d.Center.X, d.Center.Z
	terrain:FillBlock(CFrame.new(cx + 180, -2, cz + 20), Vector3.new(110, 20, 420), Enum.Material.Air) -- ขุดอ่าว
	terrain:FillBlock(CFrame.new(cx + 180, -10.5, cz + 20), Vector3.new(110, 3, 420), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(cx + 180, -5, cz + 20), Vector3.new(110, 8, 420), Enum.Material.Water)
	BK.box("Quay", 628, 686, 0, 0.35, 440, 840, hex("8F8B83"), f, Enum.Material.Concrete)
	local pz = 705
	BK.box("Pier", cx + 70, cx + 135, 0, 1.2, pz - 5, pz + 5, hex("6F5236"), f, Enum.Material.WoodPlanks)
	for x = cx + 75, cx + 135, 10 do
		BK.cylinder("PierPost", 0.6, 4, Vector3.new(x, -0.5, pz - 5.4), hex("6B5A47"), f, Enum.Material.Wood)
		BK.cylinder("PierPost", 0.6, 4, Vector3.new(x, -0.5, pz + 5.4), hex("6B5A47"), f, Enum.Material.Wood)
	end
	local sx, sz = cx + 165, pz
	BK.box("ShipHull", sx - 14, sx + 14, -1, 9, sz - 45, sz + 45, hex("8E2B2B"), f)
	BK.box("ShipDeck", sx - 14, sx + 14, 9, 9.6, sz - 45, sz + 45, hex("4A525C"), f)
	BK.box("ShipCabin", sx - 10, sx + 10, 9.6, 20, sz + 18, sz + 38, hex("D9D0BE"), f)
	for _, z in { sz + 20, sz + 28, sz + 36 } do
		local win = BK.box("ShipWindow", sx - 10.1, sx + 10.1, 14, 16, z - 1.5, z + 1.5, hex("F0D9A0"), f, Enum.Material.Neon)
		win.CanCollide = false
	end
	BK.cylinder("ShipFunnel", 2, 6, Vector3.new(sx, 23, sz + 28), hex("9E3B33"), f)
	-- เครนยักษ์ริมท่า (คร่อมทางขนส่ง)
	for _, x in { 648, 672 } do
		for _, z in { 622, 638 } do
			BK.cylinder("CraneLeg", 0.8, 28, Vector3.new(x, 14, z), hex("A8643A"), f)
		end
		BK.box("CraneBeam", x - 1, x + 1, 27, 29, 614, 650, hex("A8643A"), f)
	end
	for z = 450, 830, 55 do
		BK.lamp(f, 640, z, hex("FFB36B"))
	end
	stone(d, f)
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

---------------------------------------------------------------- ตึกทั้งเมือง: ล็อตแคบริมถนนทุกสาย (LotGen) ไม่ทับถนน
do
	local LotGen = require(script.Parent.LotGen)
	local buildings = sub(worldFolder, "Buildings")
	local lots = LotGen.generate()
	local lotRng = Random.new(777)
	for i, lot in lots do
		local ok, err = pcall(BK.tokyo, buildings, lot, lotRng)
		if not ok then
			warn(`[WorldBuilder] ตึกล็อต {i} สร้างไม่สำเร็จ: {err}`)
		end
		if i % 20 == 0 then
			task.wait()
		end
	end
	local st = LotGen.Stats()
	worldFolder:SetAttribute("BuildingCount", st.Placed)
	worldFolder:SetAttribute("BuildingRoadOverlaps", st.Overlaps)
	worldFolder:SetAttribute("LotsShiftedByRoad", st.RoadHits)
	print(`[WorldBuilder] ตึก {st.Placed} หลัง (ลานตู้ {st.Yards}), ล็อตที่ชนถนนแล้วถูกย่อ/เลื่อน {st.RoadHits}, ตึกทับถนนหลังตรวจ {st.Overlaps}`)
end

worldFolder:SetAttribute("Version", VERSION)
worldFolder:SetAttribute("Built", true)
return true
