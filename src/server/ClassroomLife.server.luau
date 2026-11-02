--!strict
-- นักเรียน + ครูในห้องเรียน (ClassroomKit): สร้างเฉพาะห้องที่มีผู้เล่นอยู่ใกล้ (SPAWN_R) ลบเมื่อไกลเกิน DESPAWN_R นาน FAR_SECS วินาที
-- ตัวประกอบล้วน: ไม่มี Humanoid, ไม่ชน, ไม่อยู่ในโฟลเดอร์ Npcs/Bosses (ระบบ NPC/ศัตรู/ชื่อ/แอนิเมชันต่อสู้ดูแค่สองโฟลเดอร์นั้น) -> อยู่ใน workspace.ClassroomPeople
-- ท่านั่ง (seatedDesk) ตั้งครั้งเดียวตอนสร้าง (RigFactory.SnapPose) แล้วทิ้งข้อต่อทั้งหมด: ไม่มีการขยับ ไม่มีลูป/Tween/สคริปต์ฝั่ง client
-- ไม่มีผู้เล่นใกล้ = ลูป 1 วินาทีทำแค่เทียบระยะ ไม่มีการสร้าง/ขยับอะไร
local Players = game:GetService("Players")

local ClassroomKit = require(script.Parent.ClassroomKit)
local RigFactory = require(script.Parent.RigFactory)

local SPAWN_R, DESPAWN_R, FAR_SECS = 70, 110, 5
local MAX_ACTIVE = 60 -- นักเรียน+ครู ที่มีตัวจริงพร้อมกันทั้งแมพ
local FILL_MIN, FILL_MAX = 0.45, 0.55
local DESPAWN_PER_FRAME = 3 -- ลบทีละไม่เกินกี่คนต่อเฟรม
local STAND_SCALE_REF = 1.659 -- ความสูง HumanoidRootPart ของตัวอ้างอิงที่วัดท่า seatedDesk (ตัวละครคูณสเกลได้เท่ากัน)
local SIT_ROOT_UP = 1.22 -- ราก HumanoidRootPart สูงกว่าต้นขาท่อนล่าง (ผิวเก้าอี้) เท่านี้ที่ STAND_SCALE_REF

local rng = Random.new()

type Active = { room: any, folder: Folder, far: number, count: number, spawning: boolean, dead: boolean }

local people = Instance.new("Folder")
people.Name = "ClassroomPeople"
people.Parent = workspace

local active: { [string]: Active } = {}
local PER_ROOM_MAX = 12 -- ครู 1 + นักเรียนสูงสุด 11 (20 ที่นั่ง x 0.55)
local queue: { any } = {}
local queued: { [string]: boolean } = {}

local function shuffle<T>(list: { T })
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function pickLook(): string
	return if rng:NextNumber() < 0.5 then "schoolgirl" else "schoolboy"
end

local function placeStudent(room: any, folder: Folder, u: number, v: number)
	local look = pickLook()
	local rig = RigFactory.CreateClassmate("生徒", look, "seatedDesk", {
		ClassroomRole = "Student",
		Seed = rng:NextInteger(1, 1000000),
	})
	if not rig then
		return nil
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local s = root.Size.Y / STAND_SCALE_REF
	local pos = ClassroomKit.ToWorld(room, u, v + rng:NextNumber(-0.06, 0.06), ClassroomKit.SeatTop + SIT_ROOT_UP * s)
	-- ตัวละครหันหน้า -Z; กระดานอยู่ทางตะวันตก (-X) -> หมุน +90° รอบ Y
	rig:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(90 + rng:NextNumber(-5, 5)), 0))
	RigFactory.SnapPose(rig)
	rig.Parent = folder
	return rig
end

local function placeTeacher(room: any, folder: Folder)
	local look = if rng:NextNumber() < 0.5 then "salaryman" else "officeLady"
	local rig, rootH = RigFactory.CreateClassmate("先生", look, nil, { ClassroomRole = "Teacher", Seed = rng:NextInteger(1, 1000000) })
	if not rig then
		return nil
	end
	-- ยืนหน้ากระดานในช่องว่างระหว่างโต๊ะครู (v<=10.2) กับแท่นพูด (v>=13.4); เดินในกรอบ u 1.9..4.6, v 10.9..12.8
	local u, v = 1.9, 11.8
	local pos = ClassroomKit.ToWorld(room, u, v, rootH + 0.02)
	rig:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0))
	local a = ClassroomKit.ToWorld(room, 1.9, 10.9, 0)
	local b = ClassroomKit.ToWorld(room, 4.6, 12.8, 0)
	RigFactory.SnapPose(rig)
	rig:SetAttribute("WanderMinX", math.min(a.X, b.X))
	rig:SetAttribute("WanderMaxX", math.max(a.X, b.X))
	rig:SetAttribute("WanderMinZ", math.min(a.Z, b.Z))
	rig:SetAttribute("WanderMaxZ", math.max(a.Z, b.Z))
	rig.Parent = folder
	return rig
end

local function spawnRoom(room: any)
	local folder = Instance.new("Folder")
	folder.Name = room.Name
	local rec: Active = { room = room, folder = folder, far = 0, count = 0, spawning = true, dead = false }
	active[room.Name] = rec
	folder.Parent = people

	local seats: { { number } } = {}
	for _, r in ClassroomKit.DeskRows do
		for _, cv in ClassroomKit.DeskCols do
			table.insert(seats, { r + 1.9, cv })
		end
	end
	shuffle(seats)
	local n = math.floor(#seats * rng:NextNumber(FILL_MIN, FILL_MAX) + 0.5)
	local made = 0
	local t = placeTeacher(room, folder)
	if t then
		made += 1
	end
	for i = 1, n do
		if rec.dead then
			break
		end
		if placeStudent(room, folder, seats[i][1], seats[i][2]) then
			made += 1
		end
		task.wait() -- สร้างคนละเฟรม (<= 3 คน/เฟรม ตามเป้า) ไม่สะดุดตอนเดินเข้าห้อง
	end
	rec.count = made
	rec.spawning = false
end

local function despawnRoom(name: string)
	local rec = active[name]
	if not rec then
		return
	end
	rec.dead = true
	active[name] = nil
	-- ทยอยลบ ไม่ลบทั้งห้องในเฟรมเดียว
	task.spawn(function()
		local kids = rec.folder:GetChildren()
		for i, k in kids do
			k:Destroy()
			if i % DESPAWN_PER_FRAME == 0 then
				task.wait()
			end
		end
		rec.folder:Destroy()
	end)
end

-- จำนวนคนที่มีตัวจริงอยู่ (ห้องที่กำลังสร้างนับเต็มโควตาไว้ก่อน)
local function activePeople(): number
	local n = 0
	for _, rec in active do
		n += if rec.spawning then PER_ROOM_MAX else rec.count
	end
	return n
end

local function playerPositions(): { Vector3 }
	local out: { Vector3 } = {}
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(out, root.Position)
		end
	end
	return out
end

local st = { ticks = 0, totalMs = 0, maxMs = 0 } -- วัดเวลา tick (ดู Attribute บนสคริปต์นี้)

local function tick()
	local t0 = os.clock()
	local pos = playerPositions()
	if #pos == 0 then
		return
	end
	local cands: { { room: any, d: number } } = {}
	for _, room in ClassroomKit.Rooms do
		local best = math.huge
		for _, p in pos do
			best = math.min(best, (p - room.Center).Magnitude)
		end
		local rec = active[room.Name]
		if rec then
			rec.far = if best > DESPAWN_R then rec.far + 1 else 0
			if rec.far >= FAR_SECS and not rec.spawning then
				despawnRoom(room.Name)
			end
		elseif best < SPAWN_R then
			table.insert(cands, { room = room, d = best })
		end
	end
	table.sort(cands, function(a, b)
		return a.d < b.d
	end)
	for _, c in cands do
		if activePeople() + PER_ROOM_MAX > MAX_ACTIVE then
			break
		end
		if not queued[c.room.Name] then
			queued[c.room.Name] = true
			table.insert(queue, c.room)
		end
	end
	local el = (os.clock() - t0) * 1000
	st.ticks += 1
	st.totalMs += el
	st.maxMs = math.max(st.maxMs, el)
	script:SetAttribute("TickAvgMs", st.totalMs / st.ticks)
	script:SetAttribute("TickMaxMs", st.maxMs)
end

-- คิวสร้างทีละห้อง (ไม่ให้ห้องหลายห้องแย่งกันสร้างพร้อมกัน)
task.spawn(function()
	while true do
		local room = table.remove(queue, 1)
		if room then
			queued[room.Name] = nil
			if not active[room.Name] and activePeople() + PER_ROOM_MAX <= MAX_ACTIVE then
				spawnRoom(room)
			end
		else
			task.wait(0.25)
		end
	end
end)

-- รอแมพ/ห้องเรียนสร้างเสร็จ (MapBuilder เรียก ClassroomKit.Build) และเมืองพร้อม แล้วเริ่มลูป
local t0 = os.clock()
while #ClassroomKit.Rooms == 0 and os.clock() - t0 < 120 do
	task.wait(1)
end
t0 = os.clock()
while workspace:GetAttribute("GameReady") ~= true and os.clock() - t0 < 120 do
	task.wait(1)
end
task.wait(3)
print(string.format("[ClassroomLife] พร้อม: %d ห้อง", #ClassroomKit.Rooms))
while true do
	task.wait(1)
	tick()
end
