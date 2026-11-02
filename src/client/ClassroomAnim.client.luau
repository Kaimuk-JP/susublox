--!strict
-- ขยับนักเรียน/ครูในห้องเรียน (ClassroomLife.server สร้างตัวไว้ท่านั่งด้วย C0 และ Anchored ทั้งตัว) — ทำฝั่ง client ล้วน ไม่ replicate
-- rig Anchored ไม่มีฟิสิกส์ข้อต่อ -> คำนวณ forward kinematics เองด้วย RigFK แล้ว BulkMoveTo ครั้งเดียวต่อรอบ (เฉพาะ subtree ของข้อต่อที่เปลี่ยน)
-- เฉพาะตัวที่อยู่ในระยะ ACTIVE_R จากกล้อง, อัปเดต ~16 Hz, เขียนเฉพาะข้อต่อที่ค่าเปลี่ยนจริง (นักเรียน 4 ข้อต่อ ครู ≤ 8 ข้อต่อ)
-- นักเรียน: เขียน / เงยหน้ามองกระดาน / หันคุยเพื่อน / ยกมือตอบ (ตอนครูถาม) / หาว-เอนตัว ; ครู: เขียนกระดาน / หันหาชั้น / ถาม+ชี้ / เดินช้า ๆ ในกรอบที่ server กำหนด
-- ทุกคนใช้ Random ของตัวเอง (Seed) และเวลาเริ่มสุ่ม จึงไม่ซิงก์กัน
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RigFK = require(ReplicatedStorage.Shared.RigFK)

local MAX_APPLY = 24 -- ตัวต่อรอบที่ย้ายชิ้นส่วนได้ (กันเฟรมกระชากถ้าคนเยอะ)
local ACTIVE_R = 40 -- ห้องที่ผู้เล่นอยู่ + ห้องติดกันที่เห็นผ่านประตู
local STEP = 1 / 16
local rad, sin, cos, exp = math.rad, math.sin, math.cos, math.exp

local people = workspace:WaitForChild("ClassroomPeople")

type Room = { askId: number }
type Rec = {
	model: Model,
	role: string,
	rng: Random,
	fk: RigFK.Rig,
	dirty: { [RigFK.Edge]: boolean },
	rootCf: CFrame?,
	cur: { [string]: number },
	last: { [string]: number },
	mode: string,
	untilT: number,
	phase: number,
	room: Room,
	-- นักเรียน
	eager: boolean,
	seenAsk: number,
	handAt: number?,
	chatSide: number,
	-- ครู
	pos: Vector3,
	yaw: number,
	goal: Vector3?,
	after: string,
	walkPhase: number,
	lastApplied: number,
	box: { number },
}

local rooms: { [Instance]: Room } = setmetatable({}, { __mode = "k" }) :: any
local recs: { [Model]: Rec } = {}
local nRecs = 0
local conn: RBXScriptConnection? = nil
local steps, totalMs, maxMs = 0, 0, 0
local applyMs, nParts = 0, 0

local function lerpTo(rec: Rec, k: string, target: number, a: number)
	local c = rec.cur[k] or 0
	rec.cur[k] = c + (target - c) * a
end

-- เขียน Transform เมื่อมุมเปลี่ยน > 0.004 rad (~0.2°)
local function setJoint(rec: Rec, name: string, x: number, y: number, z: number)
	local j = rec.fk.byName[name]
	if not j then
		return
	end
	local key = name
	local sig = x * 1.0 + y * 3.1 + z * 7.3
	local prev = rec.last[key]
	if prev and math.abs(prev - sig) < 0.004 then
		return
	end
	rec.last[key] = sig
	rec.fk.xf[j] = CFrame.Angles(x, y, z)
	rec.dirty[j] = true
end

---------------------------------------------------------------- นักเรียน
local function studentNext(rec: Rec, now: number)
	local r = rec.rng
	local roll = r:NextNumber() * 100
	local m: string
	if roll < 48 then
		m = "write"
	elseif roll < 74 then
		m = "look"
	elseif roll < 87 then
		m = "chat"
	elseif roll < 92 then
		m = "yawn"
	elseif roll < 94 and rec.mode ~= "hand" then
		m = "hand"
	else
		m = "write"
	end
	if m == rec.mode and m ~= "write" then
		m = "write"
	end
	rec.mode = m
	local d = if m == "write" then r:NextNumber(3, 9)
		elseif m == "look" then r:NextNumber(1.6, 3.6)
		elseif m == "chat" then r:NextNumber(2.5, 5)
		elseif m == "yawn" then r:NextNumber(2.4, 3.6)
		else r:NextNumber(3, 5)
	rec.untilT = now + d
	if m == "chat" then
		rec.chatSide = if r:NextNumber() < 0.5 then -1 else 1
	end
end

local function studentStep(rec: Rec, now: number, dt: number)
	local room = rec.room
	if room.askId ~= rec.seenAsk then
		rec.seenAsk = room.askId
		if rec.eager and rec.rng:NextNumber() < 0.85 then
			rec.handAt = now + rec.rng:NextNumber(0.5, 2.2)
		end
	end
	if rec.handAt and now >= rec.handAt then
		rec.handAt = nil
		rec.mode = "hand"
		rec.untilT = now + rec.rng:NextNumber(3, 5)
	elseif now >= rec.untilT then
		studentNext(rec, now)
	end
	local m = rec.mode
	local nx, ny, wx, wy, rs, re = 0, 0, 0, 0, 0, 0
	local rate = 6
	if m == "write" then
		-- เขียนเป็นช่วงสั้น ๆ มีหยุดคิด
		local gate = math.clamp(sin(now * 0.9 + rec.phase) * 2 + 0.7, 0, 1)
		local w = sin(now * 11 + rec.phase * 3)
		-- เขียนด้วยข้อศอกอย่างเดียว (ย้ายแค่ 2-3 ชิ้นต่อรอบ) ไม่ขยับคอ/ไหล่ระหว่างเขียน
		re = rad(9) * w * gate
	elseif m == "look" then
		nx = rad(17)
		ny = rad(4) * sin(now * 0.7 + rec.phase)
	elseif m == "chat" then
		ny = rad(40) * rec.chatSide
		nx = rad(8)
		wy = rad(9) * rec.chatSide
	elseif m == "yawn" then
		nx = rad(24)
		wx = rad(8)
		rs = rad(6)
		rate = 3.5
	elseif m == "hand" then
		rs = rad(118)
		re = rad(-52) + rad(5) * sin(now * 3.2 + rec.phase)
		nx = rad(14)
		rate = 5
	end
	local a = 1 - exp(-dt * rate)
	lerpTo(rec, "nx", nx, a)
	lerpTo(rec, "ny", ny, a)
	lerpTo(rec, "wx", wx, a)
	lerpTo(rec, "wy", wy, a)
	-- การเขียนต้องตามจังหวะเร็ว ไม่หน่วงด้วยตัวกรอง
	if m == "write" then
		rec.cur.rs, rec.cur.re = rs, re
	else
		lerpTo(rec, "rs", rs, a)
		lerpTo(rec, "re", re, a)
	end
	local c = rec.cur
	setJoint(rec, "Neck", c.nx, c.ny, 0)
	setJoint(rec, "Waist", c.wx, c.wy, 0)
	setJoint(rec, "RightShoulder", c.rs, 0, 0)
	setJoint(rec, "RightElbow", c.re, 0, 0)
end

---------------------------------------------------------------- ครู
local function angleDelta(target: number, cur: number): number
	return (target - cur + math.pi) % (2 * math.pi) - math.pi
end

local function teacherPick(rec: Rec, now: number)
	local r = rec.rng
	local m = rec.mode
	if m == "board" then
		rec.mode = "turn"
		rec.untilT = now + r:NextNumber(0.9, 1.4)
		rec.after = if r:NextNumber() < 0.5 then "ask" else "talk"
	elseif m == "turn" then
		rec.mode = rec.after
		rec.untilT = now + (if rec.after == "ask" then r:NextNumber(3, 4.5) else r:NextNumber(3, 6))
		if rec.after == "ask" then
			rec.room.askId += 1
		end
	elseif m == "talk" or m == "ask" then
		if r:NextNumber() < 0.55 then
			-- เดิน 2-3 ก้าวในกรอบ แล้วกลับไปหน้ากระดาน
			local b = rec.box
			local p = rec.pos
			local tx = p.X + r:NextNumber(-1, 1) * 3
			local tz = p.Z + r:NextNumber(-1, 1) * 1.2
			rec.goal = Vector3.new(math.clamp(tx, b[1], b[2]), p.Y, math.clamp(tz, b[3], b[4]))
			rec.mode = "walk"
			rec.after = "back"
			rec.untilT = now + 8
		else
			rec.mode = "board"
			rec.untilT = now + r:NextNumber(4, 8)
		end
	elseif m == "walk" then
		if rec.after == "back" then
			local b = rec.box
			rec.goal = Vector3.new(b[1], rec.pos.Y, rec.pos.Z)
			rec.after = "board"
			rec.untilT = now + 8
		else
			rec.goal = nil
			rec.mode = "board"
			rec.untilT = now + r:NextNumber(4, 8)
		end
	end
end

local function teacherStep(rec: Rec, now: number, dt: number)
	if now >= rec.untilT then
		teacherPick(rec, now)
	end
	local m = rec.mode
	local targetYaw = rec.yaw
	local rs, re, nx, ny, swing = 0, 0, 0, 0, 0
	local a = 1 - exp(-dt * 5)
	if m == "board" then
		targetYaw = rad(90)
		rs = rad(98) + rad(5) * sin(now * 6 + rec.phase)
		re = rad(18) + rad(14) * sin(now * 6 + rec.phase + 1.2)
		nx = rad(6)
	elseif m == "turn" then
		targetYaw = rad(-90)
	elseif m == "talk" then
		targetYaw = rad(-90)
		rs = rad(22) + rad(8) * sin(now * 1.6 + rec.phase)
		re = rad(38) + rad(10) * sin(now * 1.6 + rec.phase + 1)
		ny = rad(14) * sin(now * 0.5 + rec.phase)
	elseif m == "ask" then
		targetYaw = rad(-90)
		rs = rad(86)
		re = rad(8)
		ny = rad(18) * sin(now * 0.8 + rec.phase)
	elseif m == "walk" then
		local g = rec.goal
		if g then
			local d = Vector3.new(g.X - rec.pos.X, 0, g.Z - rec.pos.Z)
			if d.Magnitude < 0.12 then
				rec.untilT = 0
			else
				targetYaw = math.atan2(-d.X, -d.Z)
				if math.abs(angleDelta(targetYaw, rec.yaw)) < rad(35) then
					local step = math.min(1.8 * dt, d.Magnitude)
					rec.pos += d.Unit * step
					rec.walkPhase += dt * 3.8
				end
			end
		else
			rec.untilT = 0
		end
		swing = 1
	end
	rec.yaw += angleDelta(targetYaw, rec.yaw) * (1 - exp(-dt * 4))
	-- ท่าเดิน: ขาสลับ แขนแกว่งสวน ; หยุดแล้วกลับท่ายืน
	local w = sin(rec.walkPhase) * swing
	local k = math.max(0, sin(rec.walkPhase + 1.2)) * swing
	local kl = math.max(0, -sin(rec.walkPhase + 1.2)) * swing
	lerpTo(rec, "rs", rs + (if m == "walk" then rad(-22) * w else 0), a)
	lerpTo(rec, "re", re, a)
	lerpTo(rec, "nx", nx, a)
	lerpTo(rec, "ny", ny, a)
	lerpTo(rec, "hr", rad(26) * w, 0.7)
	lerpTo(rec, "hl", -rad(26) * w, 0.7)
	lerpTo(rec, "kr", -rad(32) * k, 0.7)
	lerpTo(rec, "kl", -rad(32) * kl, 0.7)
	local c = rec.cur
	setJoint(rec, "RightShoulder", c.rs, 0, 0)
	setJoint(rec, "RightElbow", c.re, 0, 0)
	setJoint(rec, "Neck", c.nx, c.ny, 0)
	setJoint(rec, "RightHip", c.hr, 0, 0)
	setJoint(rec, "LeftHip", c.hl, 0, 0)
	setJoint(rec, "RightKnee", c.kr, 0, 0)
	setJoint(rec, "LeftKnee", c.kl, 0, 0)
	setJoint(rec, "LeftShoulder", if m == "walk" then rad(22) * w else 0, 0, 0)
	if m == "walk" or math.abs(angleDelta(targetYaw, rec.yaw)) > rad(0.5) then
		rec.rootCf = CFrame.new(rec.pos) * CFrame.Angles(0, rec.yaw, 0)
	end
end

---------------------------------------------------------------- ลงทะเบียน / ลูปหลัก
local function stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

local function loop()
	local acc = 0
	local cam = workspace.CurrentCamera
	conn = RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < STEP then
			return
		end
		local d = acc
		acc = 0
		cam = workspace.CurrentCamera or cam
		if not cam then
			return
		end
		local cp = cam.CFrame.Position
		local t0 = os.clock()
		local now = t0
		local nAct = 0
		local activeR = (script:GetAttribute("ActiveR") :: number?) or ACTIVE_R
		local parts: { BasePart }, cfs: { CFrame } = {}, {}
		local pending: { Rec } = {}
		for model, rec in recs do
			local root = model.PrimaryPart
			if root and (root.Position - cp).Magnitude < activeR then
				nAct += 1
				if rec.role == "Teacher" then
					teacherStep(rec, now, math.min(d, 0.25))
				else
					studentStep(rec, now, math.min(d, 0.25))
				end
				if rec.rootCf or next(rec.dirty) then
					table.insert(pending, rec)
				end
			end
		end
		-- งบประมาณ: ย้ายชิ้นส่วนได้ไม่เกิน MAX_APPLY ตัวต่อรอบ (ตัวที่ไม่ได้ย้ายนานสุดก่อน ครูมาก่อน) ที่เหลือค้าง dirty ไว้รอบหน้า
				if #pending > MAX_APPLY then
			table.sort(pending, function(a, b)
				if (a.role == "Teacher") ~= (b.role == "Teacher") then
					return a.role == "Teacher"
				end
				return a.lastApplied < b.lastApplied
			end)
		end
		for i = 1, math.min(#pending, MAX_APPLY) do
			local rec = pending[i]
			rec.lastApplied = now
			local rc = rec.rootCf
			if rc then
				rec.rootCf = nil
				table.clear(rec.dirty)
				RigFK.MoveRoot(rec.fk, rc, parts, cfs)
			else
				RigFK.PlaceDirty(rec.fk, rec.dirty, parts, cfs)
				table.clear(rec.dirty)
			end
		end
		local ta = os.clock()
		RigFK.Apply(parts, cfs)
		applyMs += (os.clock() - ta) * 1000
		nParts += #parts
		-- สถิติสำหรับวัดประสิทธิภาพ: Attribute บน LocalScript นี้ (อยู่ฝั่ง client ไม่ replicate)
		local el = (os.clock() - t0) * 1000
		steps += 1
		totalMs += el
		maxMs = math.max(maxMs, el)
		if steps % 32 == 0 then
			script:SetAttribute("Steps", steps)
			script:SetAttribute("AvgMs", totalMs / steps)
			script:SetAttribute("MaxMs", maxMs)
			script:SetAttribute("Active", nAct)
			script:SetAttribute("PartsPerStep", nParts / steps)
			script:SetAttribute("ApplyMs", applyMs / steps)
		end
	end)
end

local NEEDED = { "Neck", "Waist", "RightShoulder", "RightElbow", "LeftShoulder", "RightHip", "LeftHip", "RightKnee", "LeftKnee" }

local function register(model: Model)
	local role = model:GetAttribute("ClassroomRole")
	if type(role) ~= "string" or recs[model] then
		return
	end
	task.spawn(function()
		-- Streaming: ชิ้นส่วนอาจมาไม่ครบทันที รอสูงสุด ~10 วินาที
		local fk: RigFK.Rig? = nil
		for _ = 1, 20 do
			if not model:IsDescendantOf(workspace) then
				return
			end
			local f = RigFK.Build(model)
			if f then
				local ok = true
				for _, n in NEEDED do
					ok = ok and f.byName[n] ~= nil
				end
				if ok then
					fk = f
					break
				end
			end
			task.wait(0.5)
		end
		local root = model.PrimaryPart
		if not root or not fk then
			return
		end
		local parent = model.Parent
		if not parent then
			return
		end
		local room = rooms[parent]
		if not room then
			room = { askId = 0 }
			rooms[parent] = room
		end
		local seed = (model:GetAttribute("Seed") :: number?) or 1
		local r = Random.new(seed)
		local now = os.clock()
		local _, yaw = root.CFrame:ToOrientation()
		local rec: Rec = {
			model = model,
			role = role,
			rng = r,
			fk = fk,
			dirty = {},
			rootCf = nil,
			cur = {},
			last = {},
			mode = if role == "Teacher" then "board" else "write",
			untilT = now + r:NextNumber(0.2, 6),
			phase = r:NextNumber(0, 6.28),
			room = room,
			eager = r:NextNumber() < 0.2,
			seenAsk = room.askId,
			handAt = nil,
			chatSide = 1,
			pos = root.Position,
			yaw = yaw,
			goal = nil,
			after = "ask",
			walkPhase = 0,
			lastApplied = 0,
			box = {
				(model:GetAttribute("WanderMinX") :: number?) or root.Position.X,
				(model:GetAttribute("WanderMaxX") :: number?) or root.Position.X,
				(model:GetAttribute("WanderMinZ") :: number?) or root.Position.Z,
				(model:GetAttribute("WanderMaxZ") :: number?) or root.Position.Z,
			},
		}
		if role == "Teacher" then
			rec.untilT = now + r:NextNumber(1, 5)
		end
		recs[model] = rec
		nRecs += 1
		-- สำคัญ: ทำลาย Motor6D/Weld ฝั่ง client หลังสร้าง FK แล้ว (ข้อมูลข้อต่อเก็บใน RigFK) — ถ้าเหลือไว้ การย้ายชิ้นส่วน Anchored ที่มีข้อต่อต่อกัน
		-- ทำให้ engine ลาก assembly ทั้งตัวต่อการย้าย 1 ชิ้น: Heartbeat ~95 ms ที่ 110 ตัว, ทำลายข้อต่อแล้ว ~17 ms (วัดแล้ว)
		for _, jd in model:GetDescendants() do
			if jd:IsA("Motor6D") or jd:IsA("Weld") then
				jd:Destroy()
			end
		end
		model.Destroying:Once(function()
			if recs[model] then
				recs[model] = nil
				nRecs -= 1
				if nRecs <= 0 then
					stop()
				end
			end
		end)
		if not conn then
			loop()
		end
	end)
end

local function unregister(model: Model)
	if recs[model] then
		recs[model] = nil
		nRecs -= 1
		if nRecs <= 0 then
			stop()
		end
	end
end

people.DescendantAdded:Connect(function(d)
	if d:IsA("Model") then
		-- Attribute อาจมาหลังตัว model ถึง client เล็กน้อย
		task.defer(register, d)
	end
end)
people.DescendantRemoving:Connect(function(d)
	if d:IsA("Model") then
		unregister(d)
	end
end)
for _, d in people:GetDescendants() do
	if d:IsA("Model") then
		register(d)
	end
end
