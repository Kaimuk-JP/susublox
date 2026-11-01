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

local LotGen = require(script.Parent.LotGen)

local function inSchool(x: number, z: number): boolean
	return x > -228 and x < 228 and z > -188 and z < 348
end

-- ทางเท้าทุกถนนกว้าง >= 10: สุ่มวางชุดตู้กดน้ำ/ถังรีไซเคิล/ที่จอดจักรยาน/ตู้ไปรษณีย์ กลางช่วง (ไม่ใกล้แยก ไม่ทับตึก)
local zebras = 0
for i, r in World.Roads do
	local w, kind = r[5], r[6]
	if kind == "T" or w < 10 then
		continue
	end
	local horizontal = math.abs(r[3] - r[1]) >= math.abs(r[4] - r[2])
	local fixed = if horizontal then r[2] else r[1]
	local sw = if w >= 14 then 3.9 else 2.4
	local step = if w >= 14 then 70 else 90
	for _, side in { -1, 1 } do
		if rng:NextNumber() < (if w >= 14 then 0.9 else 0.55) then
			local off = side * (w / 2 + 0.4 + sw / 2)
			local intervals = World.FreeIntervals(i, off)
			for _, iv in intervals do
				local t = iv[1] + rng:NextNumber(10, step)
				while t < iv[2] - 12 do
					local x = if horizontal then t else fixed + off
					local z = if horizontal then fixed + off else t
					if not inSchool(x, z) and not LotGen.Hit(x, z, 1.2) and not LotGen.Hit(if horizontal then x + 6 else x, if horizontal then z else z + 6, 1) and not LotGen.Hit(if horizontal then x - 4 else x, if horizontal then z else z - 4, 1) then
						local yaw = if horizontal then (if side == 1 then 0 else 180) else (if side == 1 then 90 else -90)
						cluster(rng:NextInteger(0, 2), x, z, yaw, horizontal)
					end
					t += step + rng:NextNumber(0, step)
				end
			end
		end
	end
end

-- ทางม้าลาย + เสาสัญญาณที่ปากทางแยกของถนนกว้าง >= 14
for i, r in World.Roads do
	local w = r[5]
	if w >= 14 and r[6] ~= "T" then
		local horizontal = math.abs(r[3] - r[1]) >= math.abs(r[4] - r[2])
		local fixed = if horizontal then r[2] else r[1]
		local ivs = World.FreeIntervals(i, 0)
		for k = 1, #ivs - 1 do
			local gapStart, gapEnd = ivs[k][2], ivs[k + 1][1]
			if gapEnd - gapStart >= 8 and zebras < 70 and rng:NextNumber() < 0.7 then
				local t = if rng:NextNumber() < 0.5 then gapStart - 2.5 else gapEnd + 2.5
				local x = if horizontal then t else fixed
				local z = if horizontal then fixed else t
				if not inSchool(x, z) and math.abs(z - 420) > 40 then
					SP.zebra(f, x, z, horizontal, w)
					for _, side in { -1, 1 } do
						local px = if horizontal then x - 5 else fixed + side * (w / 2 + 1.2)
						local pz = if horizontal then fixed + side * (w / 2 + 1.2) else z - 5
						if not LotGen.Hit(px, pz, 0.8) then
							SP.crossingSignal(f, px, pz, if horizontal then (if side == 1 then 0 else 180) else (if side == 1 then 90 else -90))
						end
					end
					zebras += 1
					tally(3)
				end
			end
		end
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
