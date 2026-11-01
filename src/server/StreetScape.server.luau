--!strict
-- ฉากริมถนนญี่ปุ่นยามเย็น: เสาไฟฟ้าพาดสายหย่อนตามถนนทุกสาย (ถี่ในซอย) + กำแพงหินช่วงชานเมือง (ขาดเป็นช่วง ไม่ต่อเนื่อง),
-- ต้นไม้ริมทาง, ป้ายรถเมล์, เส้นขอบเลน (เว้นตรงแยก) — ทุกอย่างหลบตึก/ทางแยกด้วย World.FreeIntervals + LotGen.Hit
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.World)
local BK = require(script.Parent.BuildKit)
local LotGen = require(script.Parent.LotGen)

local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end

local hex = Color3.fromHex
local rng = Random.new(77)
local f = Instance.new("Folder")
f.Name = "Streetscape"
f.Parent = worldFolder

local MAIN_Z = 170
local B = World.Bounds

local function inSchool(x: number, z: number): boolean
	return x > -226 and x < 226 and z > -186 and z < 346
end

local function inZone(x: number, z: number): boolean
	for _, zn in World.Zones do
		if x >= zn[1] and x <= zn[2] and z >= zn[3] and z <= zn[4] then
			return true
		end
	end
	return false
end

local function free(intervals: { { number } }, t: number, margin: number): boolean
	for _, iv in intervals do
		if t >= iv[1] + margin and t <= iv[2] - margin then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- กำแพงหิน + เสา + โคมแดง (ช่วงชานเมืองริมถนนสายหลัก z=170 เท่านั้น)
local STREET_TREES = { "Tree_Zelkova", "Tree_Zelkova", "Tree_GinkgoYellow", "Tree_GoldGreen" }
local STONE, STONE_DARK, PLASTER, TILE = hex("9A9488"), hex("6F6B62"), hex("B3AB9B"), hex("5B5D6B")

local function wallOk(x: number, z: number): boolean
	return not inSchool(x, z) and not inZone(x, z) and not World.OnRoad(x, z, 4, true) and not World.OnRoad(x + 10, z, 4, true)
end

for _, side in { -1, 1 } do
	local baseZ = MAIN_Z + side * 17
	local x = B.MinX + 30
	while x < B.MaxX - 40 do
		local run = rng:NextInteger(2, 5) * 10 -- ช่วงกำแพงยาวไม่เท่ากัน แล้วเว้นช่องเป็นประตู/ที่ว่าง
		local gap = rng:NextNumber(8, 26)
		for sx = x, x + run - 10, 10 do
			if wallOk(sx, baseZ) then
				BK.box("Pillar", sx - 1.2, sx + 1.2, 0, 4.6, baseZ - 1.2, baseZ + 1.2, STONE, f, Enum.Material.Concrete)
				BK.box("PillarCap", sx - 1.5, sx + 1.5, 4.6, 5.3, baseZ - 1.5, baseZ + 1.5, STONE_DARK, f, Enum.Material.Concrete)
				BK.box("WallPanel", sx + 1.2, sx + 8.8, 0, 3, baseZ - 0.6, baseZ + 0.6, PLASTER, f, Enum.Material.Concrete)
				BK.box("WallTile", sx + 1, sx + 9, 3, 3.7, baseZ - 0.9, baseZ + 0.9, TILE, f, Enum.Material.Slate)
				if rng:NextNumber() < 0.35 then
					local lantern = BK.ball("Lantern", 1.7, Vector3.new(sx, 4.1, baseZ - side * 1.7), hex("A8352C"), f, Enum.Material.Neon)
					lantern.Size = Vector3.new(1.4, 2, 1.4)
					BK.light(lantern, hex("FF6A3D"), 22, 1.1)
				end
				if rng:NextNumber() < 0.5 then
					BK.roundTree(f, sx + rng:NextNumber(-4, 4), MAIN_Z + side * (25 + rng:NextNumber(0, 10)), rng:NextNumber(0.7, 1.0), if rng:NextNumber() > 0.7 then hex("6E8E50") else nil, STREET_TREES, 9)
				end
			end
		end
		x += run + gap
	end
end

---------------------------------------------------------------- เสาไฟฟ้า + สายไฟโค้งหย่อน (ทุกถนนที่กว้าง >= 8)
local function wire(p1: Vector3, p2: Vector3, sag: number, thick: number?, segments: number?)
	local n = segments or 6
	local prev = p1
	for i = 1, n do
		local t = i / n
		local pos = p1:Lerp(p2, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		local mid = (prev + pos) / 2
		local length = (pos - prev).Magnitude
		local w = BK.part("Wire", Vector3.new(thick or 0.12, thick or 0.12, length), mid, hex("1B1C20"), f)
		w.CFrame = CFrame.lookAt(mid, pos)
		w.CanCollide, w.CanQuery, w.CanTouch = false, false, false
		prev = pos
	end
end

local poleCount = 0
for i, r in World.Roads do
	local w, kind = r[5], r[6]
	if kind == "T" or w < 8 then
		continue
	end
	local horizontal = math.abs(r[3] - r[1]) >= math.abs(r[4] - r[2])
	local lo = if horizontal then math.min(r[1], r[3]) else math.min(r[2], r[4])
	local hi = if horizontal then math.max(r[1], r[3]) else math.max(r[2], r[4])
	local fixed = if horizontal then r[2] else r[1]
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local off = side * (w / 2 + (if w >= 14 then 1.2 else if w >= 10 then 1.1 else 0.45))
	local intervals = World.FreeIntervals(i, off)
	local step = if kind == "A" or kind == "L" then 40 else 52
	local prevPos: Vector3? = nil
	local t = lo + rng:NextNumber(8, 24)
	while t < hi - 6 do
		local px = if horizontal then t else fixed + off
		local pz = if horizontal then fixed + off else t
		if free(intervals, t, 2) and not inSchool(px, pz) and not LotGen.Hit(px, pz, 0.6) and poleCount < 600 then
			poleCount += 1
			local tall = if kind == "A" or kind == "L" then 19 else 14
			BK.cylinder("UtilityPole", 0.45, tall, Vector3.new(px, tall / 2, pz), hex("6B5A47"), f, Enum.Material.Wood)
			if kind == "A" or kind == "L" then
				local armLen = 3.2
				if horizontal then
					BK.box("CrossArm", px - armLen, px + armLen, tall - 1.6, tall - 1.1, pz - 0.25, pz + 0.25, hex("5A4A3A"), f, Enum.Material.Wood)
				else
					BK.box("CrossArm", px - 0.25, px + 0.25, tall - 1.6, tall - 1.1, pz - armLen, pz + armLen, hex("5A4A3A"), f, Enum.Material.Wood)
				end
				BK.cylinder("Transformer", 0.7, 2.2, Vector3.new(px + 1.2, tall - 4.8, pz + 0.6), hex("70747A"), f, Enum.Material.Metal)
			end
			BK.box("PoleCableBox", px - 0.7, px + 0.7, 9, 11, pz - 0.7, pz + 0.7, hex("44464D"), f, Enum.Material.Metal)
			local top = Vector3.new(px, tall - 1.3, pz)
			if prevPos and (top - prevPos).Magnitude <= step + 14 then
				local nwires = if kind == "A" or kind == "L" then 3 else 2
				for k = 1, nwires do
					local sp = (k - (nwires + 1) / 2) * 0.8
					local d = if horizontal then Vector3.new(0, 0, sp) else Vector3.new(sp, 0, 0)
					wire(prevPos + d, top + d, 1.5)
				end
				-- สายสื่อสาร/เคเบิลทีวี หย่อนกว่า ห้อยใต้สายไฟ
				wire(prevPos - Vector3.new(0, 5.5, 0), top - Vector3.new(0, 5.5, 0), 2.4, 0.3, 5)
			end
			prevPos = top
		else
			prevPos = nil
		end
		t += step + rng:NextNumber(-8, 8)
	end
end

---------------------------------------------------------------- ป้ายรถเมล์ (ถนนสายหลักช่วงชานเมือง)
local function busStop(x: number, side: number)
	local z = MAIN_Z + side * 14
	BK.box("ShelterRoof", x - 4, x + 4, 7, 7.5, z - 2, z + 2, hex("3F566E"), f, Enum.Material.Metal)
	for _, ox in { -3.6, 3.6 } do
		BK.cylinder("ShelterPost", 0.2, 7, Vector3.new(x + ox, 3.5, z + side * 1.8), hex("2A2C32"), f, Enum.Material.Metal)
	end
	local glass = BK.box("ShelterGlass", x - 3.6, x + 3.6, 1.2, 6.8, z + side * 1.9 - 0.1, z + side * 1.9 + 0.1, hex("8FA3AB"), f, Enum.Material.Glass)
	glass.Transparency = 0.6
	BK.box("ShelterBench", x - 2.5, x + 2.5, 1.6, 2, z + side * 1.2 - 0.5, z + side * 1.2 + 0.5, hex("6F5236"), f, Enum.Material.Wood)
	BK.cylinder("BusSignPole", 0.15, 8, Vector3.new(x + 5.5, 4, z), hex("A5A7A8"), f, Enum.Material.Metal)
	BK.sign(f, "BUS", Vector3.new(2.4, 2.4, 0.2), Vector3.new(x + 5.5, 8.4, z), if side == 1 then 180 else 0, hex("3F566E"), hex("E4E0D6"))
end
for _, spec in { { -700, 1 }, { -300, -1 }, { 300, 1 }, { 700, -1 }, { -250, 1 }, { 250, -1 } } do
	local x, side = spec[1], spec[2]
	if not inSchool(x, MAIN_Z) and not inZone(x, MAIN_Z + side * 14) and not World.OnRoad(x, MAIN_Z + side * 14, 3, true) and not World.OnRoad(x + 6, MAIN_Z + side * 14, 3, true) then
		busStop(x, side)
	end
end

---------------------------------------------------------------- เส้นขอบเลนถนน (ขาว ทึบ) เฉพาะถนนกว้าง >= 14 เว้นตรงแยก
for i, r in World.Roads do
	local w = r[5]
	if w >= 14 and r[6] ~= "T" then
		local horizontal = math.abs(r[3] - r[1]) >= math.abs(r[4] - r[2])
		for _, side in { -1, 1 } do
			local off = side * (w / 2 - 1.1)
			for _, iv in World.FreeIntervals(i, off) do
				if horizontal then
					BK.box("EdgeLine", iv[1], iv[2], 0.3, 0.37, r[2] + off - 0.15, r[2] + off + 0.15, hex("E4E0D6"), f)
				else
					BK.box("EdgeLine", r[1] + off - 0.15, r[1] + off + 0.15, 0.3, 0.37, iv[1], iv[2], hex("E4E0D6"), f)
				end
			end
		end
	end
end

worldFolder:SetAttribute("UtilityPoles", poleCount)
print(`[StreetScape] เสาไฟฟ้า {poleCount} ต้น`)
