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

local flatCircles = {}
for _, d in World.Districts do
	table.insert(flatCircles, { d.Center.X, d.Center.Z, d.Radius + 70 })
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
	m = math.min(m, smooth((distanceToRoad(x, z) - 25) / 60))
	return m
end

local function height(x, z)
	local m = naturalMask(x, z)
	if m <= 0 then
		return 0
	end
	local n = math.noise(x / 180, z / 180, 3) * 22 + math.noise(x / 70, z / 70, 9) * 8 + math.noise(x / 28, z / 28, 17) * 2.5
	return math.max(n, -1) * m
end

terrain:Clear()
local count = 0
for cx = B.MinX, B.MaxX - 1, CHUNK do
	for cz = B.MinZ, B.MaxZ - 1, CHUNK do
		local nx, nz = math.ceil(CHUNK / RES), math.ceil(CHUNK / RES)
		local ny = math.ceil((MAX_Y - MIN_Y) / RES)
		local materials, occupancy = {}, {}
		for ix = 1, nx do
			materials[ix], occupancy[ix] = {}, {}
			local x = cx + (ix - 0.5) * RES
			for iy = 1, ny do
				materials[ix][iy], occupancy[ix][iy] = {}, {}
				local y = MIN_Y + (iy - 0.5) * RES
				for iz = 1, nz do
					local z = cz + (iz - 0.5) * RES
					local h = height(x, z)
					local occ = math.clamp((h - (y - RES / 2)) / RES, 0, 1)
					local mat = Enum.Material.Grass
					if occ > 0 then
						-- ชัน = หิน, สูงมาก = หินล้วน, ที่ราบ = หญ้า/ดิน/โคลนเป็นหย่อม
						local slope = math.abs(height(x + RES, z) - h) + math.abs(height(x, z + RES) - h)
						local patch = math.noise(x / 40, z / 40, 5)
						if slope > 5.5 or h > 22 then
							mat = Enum.Material.Rock
						elseif slope > 3 then
							mat = Enum.Material.Ground
						elseif patch > 0.35 then
							mat = Enum.Material.LeafyGrass
						elseif patch < -0.4 then
							mat = Enum.Material.Mud
						end
						if y < -0.5 - RES then
							mat = Enum.Material.Ground -- ชั้นดินใต้ผิว
						end
					end
					materials[ix][iy][iz] = mat
					occupancy[ix][iy][iz] = occ
				end
			end
		end
		local region = Region3.new(Vector3.new(cx, MIN_Y, cz), Vector3.new(cx + nx * RES, MIN_Y + ny * RES, cz + nz * RES)):ExpandToGrid(RES)
		terrain:WriteVoxels(region, RES, materials, occupancy)
		count += 1
		task.wait()
	end
end
workspace:SetAttribute("TerrainBaked", true)
print(`[TerrainBake] เสร็จ {count} chunk — ภูมิประเทศธรรมชาติพร้อมแล้ว อย่าลืมบันทึก Place`)
