--!strict
-- ฉากริมถนนสายหลักให้เหมือนถนนญี่ปุ่นยามเย็น: กำแพงหินยาว + เสา + โคมแดง, ต้นไม้ริมทาง,
-- เสาไฟฟ้าพาดสาย (เส้นโค้งหย่อน), ป้ายรถเมล์, เส้นขอบเลนถนน (เว้นพื้นที่โรงเรียน/ย่านที่มีของตกแต่งเอง)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.World)
local BK = require(script.Parent.BuildKit)

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

local function skip(x: number): boolean
	if math.abs(x) < 235 then
		return true -- พื้นที่โรงเรียน
	end
	if math.abs(x - -560) < 18 or math.abs(x - -370) < 18 or math.abs(x - 570) < 18 then
		return true -- ทางแยกขึ้นเหนือ
	end
	for _, d in World.Districts do
		if math.abs(MAIN_Z - d.Center.Z) < d.Radius + 10 and math.abs(x - d.Center.X) < d.Radius + 10 then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- กำแพงหิน + เสา + โคมแดง
local STREET_TREES = { "Tree_Zelkova", "Tree_Zelkova", "Tree_GinkgoYellow", "Tree_GoldGreen" } -- ต้นใบกว้างธรรมชาติ (เซลโคว่า/แปะก๊วยเหลือง) ริมถนน
local STONE, STONE_DARK, PLASTER, TILE = hex("9A9488"), hex("6F6B62"), hex("B3AB9B"), hex("5B5D6B")

for _, side in { -1, 1 } do
	local baseZ = MAIN_Z + side * 15
	for x = B.MinX + 30, B.MaxX - 40, 10 do
		if not skip(x) and not skip(x + 10) then
			BK.box("Pillar", x - 1.2, x + 1.2, 0, 4.6, baseZ - 1.2, baseZ + 1.2, STONE, f, Enum.Material.Concrete)
			BK.box("PillarCap", x - 1.5, x + 1.5, 4.6, 5.3, baseZ - 1.5, baseZ + 1.5, STONE_DARK, f, Enum.Material.Concrete)
			BK.box("WallPanel", x + 1.2, x + 8.8, 0, 3, baseZ - 0.6, baseZ + 0.6, PLASTER, f, Enum.Material.Concrete)
			BK.box("WallTile", x + 1, x + 9, 3, 3.7, baseZ - 0.9, baseZ + 0.9, TILE, f, Enum.Material.Slate)
			if (x / 10) % 2 == 0 then
				local lantern = BK.ball("Lantern", 1.7, Vector3.new(x, 4.1, baseZ - side * 1.7), hex("A8352C"), f, Enum.Material.Neon)
				lantern.Size = Vector3.new(1.4, 2, 1.4)
				BK.light(lantern, hex("FF6A3D"), 22, 1.1)
				BK.cylinder("LanternCord", 0.08, 1.2, Vector3.new(x, 5, baseZ - side * 1.7), hex("2A2C32"), f)
			end
		end
	end
	-- ต้นไม้ใหญ่หลังกำแพง
	for x = B.MinX + 60, B.MaxX - 60, 26 do
		if not skip(x) then
			BK.roundTree(f, x + rng:NextNumber(-4, 4), MAIN_Z + side * (24 + rng:NextNumber(0, 10)), rng:NextNumber(1.1, 1.7), if rng:NextNumber() > 0.7 then hex("6E8E50") else nil, STREET_TREES)
		end
	end
end

---------------------------------------------------------------- เสาไฟฟ้า + สายไฟโค้งหย่อน
local POLE_STEP = 42
local POLE_SIDE_Z = MAIN_Z + 11.5
local poles: { number } = {}
for x = B.MinX + 50, B.MaxX - 50, POLE_STEP do
	if not skip(x) then
		table.insert(poles, x)
		BK.cylinder("UtilityPole", 0.45, 19, Vector3.new(x, 9.5, POLE_SIDE_Z), hex("6B5A47"), f, Enum.Material.Wood)
		BK.box("CrossArm", x - 3.2, x + 3.2, 17.4, 17.9, POLE_SIDE_Z - 0.25, POLE_SIDE_Z + 0.25, hex("5A4A3A"), f, Enum.Material.Wood)
		for _, ox in { -2.6, 0, 2.6 } do
			BK.cylinder("Insulator", 0.22, 0.7, Vector3.new(x + ox, 18.2, POLE_SIDE_Z), hex("A5A7A8"), f)
		end
		for _, oz in { -0.9, 0.9 } do
			BK.cylinder("Transformer", 0.7, 2.2, Vector3.new(x + 1.5, 14.2, POLE_SIDE_Z + oz), hex("70747A"), f, Enum.Material.Metal)
		end
		BK.box("PoleCableBox", x - 0.8, x + 0.8, 10.4, 12.4, POLE_SIDE_Z - 0.8, POLE_SIDE_Z - 0.45, hex("44464D"), f, Enum.Material.Metal)
	end
end

local function wire(p1: Vector3, p2: Vector3, sag: number, thick: number?)
	local segments = 8
	local prev = p1
	for i = 1, segments do
		local t = i / segments
		local pos = p1:Lerp(p2, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		local mid = (prev + pos) / 2
		local length = (pos - prev).Magnitude
		local w = BK.part("Wire", Vector3.new(thick or 0.12, thick or 0.12, length), mid, hex("1B1C20"), f)
		w.CFrame = CFrame.lookAt(mid, pos)
		w.CanCollide, w.CanQuery, w.CanTouch = false, false, false
		prev = pos
	end
end

for i = 1, #poles - 1 do
	if poles[i + 1] - poles[i] <= POLE_STEP + 1 then
		for _, ox in { -2.6, 0, 2.6 } do
			wire(Vector3.new(poles[i] + ox, 18.5, POLE_SIDE_Z), Vector3.new(poles[i + 1] + ox, 18.5, POLE_SIDE_Z), 1.6)
		end
	end
end

-- สายสื่อสาร/เคเบิลทีวีรวมเป็นมัดหนา หย่อนกว่าสายไฟ ห้อยอยู่ใต้สายไฟสามเส้น
for i = 1, #poles - 1 do
	if poles[i + 1] - poles[i] <= POLE_STEP + 1 then
		for _, oz in { -0.3, 0.3 } do
			wire(Vector3.new(poles[i], 12.3, POLE_SIDE_Z - 0.7 + oz), Vector3.new(poles[i + 1], 12.3, POLE_SIDE_Z - 0.7 + oz), 2.6, 0.32)
		end
	end
end

---------------------------------------------------------------- ป้ายรถเมล์
local function busStop(x: number, side: number)
	local z = MAIN_Z + side * 11
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
	if not skip(spec[1]) then
		busStop(spec[1], spec[2])
	end
end

---------------------------------------------------------------- เส้นขอบเลนถนน (ขาว ทึบ) ตามถนนทุกสาย
for _, r in World.Roads do
	local x1, z1, x2, z2, w = r[1], r[2], r[3], r[4], r[5]
	local horizontal = math.abs(x2 - x1) >= math.abs(z2 - z1)
	for _, side in { -1, 1 } do
		if horizontal then
			local z = z1 + side * (w / 2 - 1.1)
			BK.box("EdgeLine", math.min(x1, x2), math.max(x1, x2), 0.3, 0.37, z - 0.15, z + 0.15, hex("E4E0D6"), f)
		else
			local x = x1 + side * (w / 2 - 1.1)
			BK.box("EdgeLine", x - 0.15, x + 0.15, 0.3, 0.37, math.min(z1, z2), math.max(z1, z2), hex("E4E0D6"), f)
		end
	end
end
