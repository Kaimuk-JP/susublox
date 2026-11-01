--!nocheck
-- รันใน Roblox Studio โหมด Edit เพื่อ "ปั้นภูมิประเทศธรรมชาติ" แล้วเซฟลง Place (ไม่ต้องคำนวณตอนเล่น)
-- พื้นที่เล่นหลัก (โรงเรียน ถนน ย่าน) บังคับเรียบที่ y=0 ส่วนรอบนอกเป็นเนินลอนคลื่น + หินตามไหล่เขา
-- หลังรันเสร็จจะตั้ง workspace:SetAttribute("TerrainBaked", true) เพื่อให้เกมไม่ล้าง/ทับ Terrain ตอนเริ่ม
local terrain = workspace.Terrain
local World = require(game.ReplicatedStorage.Shared.World)

local B = World.Bounds
local RES = 4 -- ขนาด voxel ของ Roblox Terrain
local CHUNK = 128 -- studs ต่อ chunk (ด้านราบ)
local MIN_Y, MAX_Y = -24, 48
local SURFACE_OFFSET = 2 -- ผิว Terrain ที่ render จริงสูงกว่าขอบบน voxel เต็ม ~2 stud ลบออกให้พื้นราบอยู่ที่ y=0 พอดี

local flatCircles = {}
for _, d in World.Districts do
	table.insert(flatCircles, { d.Center.X, d.Center.Z, d.Radius + 40 })
end
local flatBoxes = {
	{ -200, 200, -150, 340 }, -- โรงเรียน + อารีน่า (x1, x2, z1, z2)
}

local function distanceToRoad(x, z)
	local best = math.huge
	for _, r in World.Roads do
		local x1, z1, x2, z2 = math.min(r[1], r[3]), math.min(r[2], r[4]), math.max(r[1], r[3]), math.max(r[2], r[4])
		local dx = math.max(x1 - x, 0, x - x2)
		local dz = math.max(z1 - z, 0, z - z2)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

-- พื้นเมืองไม่ใช้หญ้า: Terrain Decoration (ใบหญ้า) ขึ้นเฉพาะวัสดุ Grass จึงโผล่ทะลุถนน/ทางเท้า
local pavedMats = {
	Cobblestone = Enum.Material.Cobblestone,
	Pavement = Enum.Material.Pavement,
	Concrete = Enum.Material.Concrete,
}
local function urbanMaterial(x, z)
	for _, r in World.Roads do
		local x1, z1, x2, z2 = math.min(r[1], r[3]), math.min(r[2], r[4]), math.max(r[1], r[3]), math.max(r[2], r[4])
		local dx = math.max(x1 - x, 0, x - x2)
		local dz = math.max(z1 - z, 0, z - z2)
		if math.sqrt(dx * dx + dz * dz) < r[5] / 2 + 4 then
			return Enum.Material.Asphalt
		end
	end
	for _, p in World.Paved do
		if x >= p[1] and x <= p[2] and z >= p[3] and z <= p[4] then
			return pavedMats[p[5]]
		end
	end
	return nil
end

local WATER_BED, WATER_TOP, SHORE = -9, 1, 18
local function waterAmount(x, z) -- 1 = กลางแอ่งน้ำ, 0 = พ้นขอบลาด
	local best = 0
	for _, b in World.Water do
		local dx = math.max(b[1] - x, 0, x - b[2])
		local dz = math.max(b[3] - z, 0, z - b[4])
		best = math.max(best, 1 - math.clamp(math.sqrt(dx * dx + dz * dz) / SHORE, 0, 1))
	end
	return best
end

local function hillAt(x, z)
	local best, inside = 0, false
	for _, h in World.Hills do
		local r = math.sqrt((x - h.x) ^ 2 + (z - h.z) ^ 2)
		best = math.max(best, World.HillHeight(h, r))
		inside = inside or r < h.r1 + 6
	end
	return best, inside
end

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 = บังคับเรียบ, 1 = เป็นธรรมชาติเต็มที่
local function naturalMask(x, z)
	local m = 1
	for _, c in flatCircles do
		local d = math.sqrt((x - c[1]) ^ 2 + (z - c[2]) ^ 2)
		m = math.min(m, smooth((d - c[3]) / 90))
	end
	for _, b in flatBoxes do
		local dx = math.max(b[1] - x, 0, x - b[2])
		local dz = math.max(b[3] - z, 0, z - b[4])
		m = math.min(m, smooth((math.sqrt(dx * dx + dz * dz) - 20) / 80))
	end
	m = math.min(m, smooth((distanceToRoad(x, z) - 35) / 45))
	-- แนวแม่น้ำคิโซ (z=420, กว้าง 40; CityDressing ขุดตอนเริ่มเกม) ต้องเรียบ ไม่มีเนินค้างกลางน้ำ
	m = math.min(m, smooth((math.abs(z - 420) - 45) / 60))
	return m
end

local function height(x, z)
	local m = naturalMask(x, z)
	local h = 0
	if m > 0 then
		local n = math.noise(x / 180, z / 180, 3) * 34 + math.noise(x / 70, z / 70, 9) * 10 + math.noise(x / 28, z / 28, 17) * 2.5
		h = math.max(n, -1) * m
	end
	h = math.max(h, (hillAt(x, z)))
	local w = waterAmount(x, z)
	if w > 0 then
		local t = smooth(w * 1.6)
		h = h * (1 - t) + WATER_BED * t
	end
	return h
end

terrain:Clear()
-- สีวัสดุภูมิประเทศให้เป็นธรรมชาติ (ค่าเริ่มต้นออกฟ้า-ซีด)
for mat, col in {
	[Enum.Material.Grass] = Color3.fromRGB(96, 140, 62),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(78, 120, 50),
	[Enum.Material.Ground] = Color3.fromRGB(118, 96, 66),
	[Enum.Material.Mud] = Color3.fromRGB(92, 74, 54),
	[Enum.Material.Rock] = Color3.fromRGB(118, 116, 110),
	[Enum.Material.Asphalt] = Color3.fromRGB(74, 77, 92),
	[Enum.Material.Pavement] = Color3.fromRGB(150, 150, 158),
	[Enum.Material.Cobblestone] = Color3.fromRGB(150, 140, 128),
	[Enum.Material.Concrete] = Color3.fromRGB(140, 142, 150),
} do
	terrain:SetMaterialColor(mat, col)
end
local count = 0
local nx, nz = math.ceil(CHUNK / RES), math.ceil(CHUNK / RES)
local ny = math.ceil((MAX_Y - MIN_Y) / RES)
for cx = math.floor(B.MinX / RES) * RES, B.MaxX - 1, CHUNK do -- ต้องชิดกริด voxel
	for cz = math.floor(B.MinZ / RES) * RES, B.MaxZ - 1, CHUNK do
		-- คำนวณความสูง/วัสดุต่อคอลัมน์ครั้งเดียว (เร็วกว่าคำนวณทุก voxel มาก)
		local colH, colMat, colWater = {}, {}, {}
		for ix = 1, nx do
			colH[ix], colMat[ix], colWater[ix] = {}, {}, {}
			local x = cx + (ix - 0.5) * RES
			for iz = 1, nz do
				local z = cz + (iz - 0.5) * RES
				local h = height(x, z)
				local slope = math.abs(height(x + RES, z) - h) + math.abs(height(x, z + RES) - h)
				local patch = math.noise(x / 40, z / 40, 5)
				local mat = Enum.Material.Grass
				if slope > 5.5 or h > 22 then
					mat = Enum.Material.Rock
				elseif slope > 3 then
					mat = Enum.Material.Ground
				elseif patch > 0.35 then
					mat = Enum.Material.LeafyGrass
				elseif patch < -0.55 then
					mat = Enum.Material.Ground
				end
				local _, onHill = hillAt(x, z)
				if onHill then
					mat = Enum.Material.Grass -- เนินศาลเจ้าเป็นหญ้า ไม่ใช่หิน
				elseif h == 0 then
					mat = urbanMaterial(x, z) or mat
				end
				local wet = waterAmount(x, z) > 0 and h < WATER_TOP - 1
				if wet then
					mat = Enum.Material.Sand
				end
				colH[ix][iz], colMat[ix][iz], colWater[ix][iz] = h, mat, wet
			end
		end
		local materials, occupancy = {}, {}
		for ix = 1, nx do
			materials[ix], occupancy[ix] = {}, {}
			for iy = 1, ny do
				materials[ix][iy], occupancy[ix][iy] = {}, {}
				local y = MIN_Y + (iy - 0.5) * RES
				for iz = 1, nz do
					local occ = math.clamp((colH[ix][iz] - SURFACE_OFFSET - (y - RES / 2)) / RES, 0, 1)
					local mat = colMat[ix][iz]
					if occ > 0 and y < -4 * RES - 0.5 then
						mat = Enum.Material.Ground -- ชั้นดินใต้ผิว
					end
					if occ <= 0 and colWater[ix][iz] then
						local wocc = math.clamp((WATER_TOP - SURFACE_OFFSET - (y - RES / 2)) / RES, 0, 1)
						if wocc > 0 then
							mat, occ = Enum.Material.Water, wocc
						end
					end
					materials[ix][iy][iz] = occ > 0 and mat or Enum.Material.Air
					occupancy[ix][iy][iz] = occ
				end
			end
		end
		local region = Region3.new(Vector3.new(cx, MIN_Y, cz), Vector3.new(cx + nx * RES, MIN_Y + ny * RES, cz + nz * RES)):ExpandToGrid(RES)
		terrain:WriteVoxels(region, RES, materials, occupancy)
		count += 1
		if count % 4 == 0 then
			task.wait()
		end
	end
end
-- ปูหญ้าเกินขอบโลก 400 studs + แนวเขาล้อมนอกขอบโลก (WorldBuilder ข้ามส่วนนี้เมื่อ TerrainBaked)
do
	local tile = 400
	for x = B.MinX - 400, B.MaxX + 399, tile do
		for z = B.MinZ - 400, B.MaxZ + 399, tile do
			local inside = x >= B.MinX and x + tile <= B.MaxX and z >= B.MinZ and z + tile <= B.MaxZ
			if not inside then
				terrain:FillBlock(CFrame.new(x + tile / 2, -8, z + tile / 2), Vector3.new(tile, 12, tile), Enum.Material.LeafyGrass)
			end
		end
		task.wait()
	end
	local function mountain(x, z, r)
		terrain:FillBall(Vector3.new(x, -r * 0.45, z), r, Enum.Material.LeafyGrass)
		terrain:FillBall(Vector3.new(x, -r * 0.45 + r * 0.55, z), r * 0.55, Enum.Material.Rock)
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
workspace:SetAttribute("TerrainBaked", true)
print("[TerrainBake] done chunks=" .. count .. " - save the Place")
