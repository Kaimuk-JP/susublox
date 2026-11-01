--!strict
-- วางเฟอร์นิเจอร์ริมถนนแบบญี่ปุ่นทั่วเมือง (ตู้กดน้ำ ถังรีไซเคิล ตู้ไปรษณีย์ ที่จอดจักรยาน ทางม้าลาย ราวกันตก ศาลเล็ก โคมหิน จิโซ)
-- ใช้ชิ้นส่วนจาก StreetProps; รันหลัง WorldBuilder สร้างโลกเสร็จ (World.Built)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.World)
local BK = require(script.Parent.BuildKit)
local SP = require(script.Parent.StreetProps)

local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end

local rng = Random.new(2024)
local f = Instance.new("Folder")
f.Name = "StreetFurniture"
f.Parent = worldFolder

local count = 0
local function tally(n: number)
	count += n
end

-- ชุดของริมทางเท้า 1 จุด: kind 0 = ตู้กดน้ำเป็นกลุ่ม + ถังรีไซเคิล, 1 = ที่จอดจักรยาน, 2 = ตู้ไปรษณีย์ + ถังรีไซเคิล
-- (x,z) = กึ่งกลางจุด; yaw ตามทิศที่หันหน้าไปทางถนน; along = เวกเตอร์ชี้ไปตามแนวทางเท้า (ฝั่งแกน X หรือ Z)
local function cluster(kind: number, x: number, z: number, yaw: number, alongX: boolean)
	local function at(o: number): (number, number)
		if alongX then
			return x + o, z
		end
		return x, z + o
	end
	if kind == 0 then
		for i = 0, 2 do
			local px, pz = at((i - 1) * 2.8)
			SP.jihanki(f, px, pz, yaw, rng:NextInteger(0, 4))
		end
		local bx, bz = at(6)
		SP.recycleBins(f, bx, bz, yaw)
		tally(2)
	elseif kind == 1 then
		SP.bikeRack(f, x, z, yaw + 90, 4, rng)
		tally(1)
	else
		SP.mailbox(f, x, z, yaw)
		local bx, bz = at(3.5)
		SP.recycleBins(f, bx, bz, yaw)
		tally(2)
	end
end

local main = 170
local B = World.Bounds
local function skipMain(x: number): boolean
	if math.abs(x) < 235 then
		return true
	end
	if math.abs(x - -560) < 18 or math.abs(x - -370) < 18 or math.abs(x - 570) < 18 then
		return true
	end
	for _, d in World.Districts do
		if math.abs(main - d.Center.Z) < d.Radius + 10 and math.abs(x - d.Center.X) < d.Radius + 10 then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- ถนนสายหลัก (z=170): ทางเท้าระหว่างขอบถนน z±8 กับกำแพง z±15
local k = 0
for x = B.MinX + 100, B.MaxX - 100, 85 do
	if not skipMain(x) and not skipMain(x + 15) and not skipMain(x - 15) then
		local side = if k % 2 == 0 then 1 else -1
		cluster(k % 3, x, main + side * 10.2, if side == 1 then 0 else 180, true)
		k += 1
	end
end
-- ทางม้าลาย + เสาสัญญาณ + ราวกันตกข้างทาง
for _, zx in { -500, -300, 300, 700 } do
	if not skipMain(zx) and not skipMain(zx + 14) and not skipMain(zx - 14) then
		SP.zebra(f, zx, main, true, 16)
		for _, side in { -1, 1 } do
			SP.crossingSignal(f, zx - 7.5, main + side * 9.4, if side == 1 then 0 else 180)
			SP.guardRail(f, zx + 6, main + side * 8.8, zx + 20, main + side * 8.8)
			SP.guardRail(f, zx - 20, main + side * 8.8, zx - 9, main + side * 8.8)
		end
		tally(3)
	end
end

---------------------------------------------------------------- ถนนการค้า (ศูนย์กลาง x=420): ทางเท้า z≈157-162 (หันหน้า +Z) และ 178-183 (หันหน้า -Z)
do
	local d = World.ById("Shotengai") :: World.District
	local cx = d.Center.X
	local kinds = { 0, 1, 2, 0, 1, 0, 2 }
	for i, off in { -110, -70, -30, 10, 50, 90, 120 } do
		local side = if i % 2 == 0 then 1 else -1
		if side == 1 then
			cluster(kinds[i], cx + off + 20 * 0, main + 10.4, 0, true)
		else
			cluster(kinds[i], cx + off, main - 10.4, 180, true)
		end
	end
	for _, zx in { cx - 80, cx + 62 } do
		SP.zebra(f, zx, main, true, 16)
		for _, side in { -1, 1 } do
			SP.crossingSignal(f, zx - 7.5, main + side * 9.4, if side == 1 then 0 else 180)
		end
		tally(3)
	end
end

---------------------------------------------------------------- ย่านสถานี: ทางเท้าแถบ z=600 (ใต้ตึก z 587-593 / 607-613) และแถบ x=-90
do
	for i, x in { -260, -215, -170, -50, -10, 30, 70, 110, 150, 195, 240 } do
		local side = if i % 2 == 0 then 1 else -1
		if not (side == 1 and x > 100) then
			cluster(i % 3, x, 600 + side * 10, if side == 1 then 0 else 180, true)
		end
	end
	for _, zx in { -20, -180 } do
		SP.zebra(f, zx, 600, true, 14)
		for _, side in { -1, 1 } do
			SP.crossingSignal(f, zx - 7, 600 + side * 8.8, if side == 1 then 0 else 180)
			SP.guardRail(f, zx + 6, 600 + side * 8.2, zx + 18, 600 + side * 8.2)
		end
		tally(3)
	end
	for i, z in { 270, 320, 370, 470, 520 } do
		local west = i % 2 == 0
		cluster(i % 3, if west then -100 else -80, z, if west then -90 else 90, false)
	end
end

---------------------------------------------------------------- สวนซากุระ + ศาลเจ้าบนเนิน: ศาลเล็ก โคมหิน จิโซ
do
	local park = World.ById("SakuraPark") :: World.District
	local pcx, pcz = park.Center.X, park.Center.Z
	SP.hokora(f, pcx - 95, pcz - 35, -90)
	SP.hokora(f, pcx + 90, pcz - 95, 0)
	for _, o in { { 14, -62 }, { 17.5, -62 }, { 21, -62 } } do
		SP.jizo(f, pcx + o[1], pcz + o[2], 180)
	end
	for _, o in { { 24, -34 }, { 56, -34 }, { 24, -62 }, { 56, -62 } } do
		SP.stoneLantern(f, pcx + o[1], 0, pcz + o[2], 1)
	end
	local tp = World.ById("TempleHill") :: World.District
	local tcx, tcz = tp.Center.X, tp.Center.Z
	SP.hokora(f, tcx - 38, tcz + 74, 180)
	for _, dx in { -14, -10.5, -7 } do
		SP.jizo(f, tcx + dx, tcz + 82, 180)
	end
	for _, dx in { -16, 16 } do
		SP.stoneLantern(f, tcx + dx, 0, tcz + 76, 1.1)
	end
	tally(10)
end

worldFolder:SetAttribute("FurnitureSets", count)
print(`[StreetFurniture] วางชุดเฟอร์นิเจอร์ริมถนน {count} ชุด`)
