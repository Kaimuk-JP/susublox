--!strict
-- Forward kinematics ของ rig ที่ "Anchored ทุกชิ้น" (ตัวประกอบในห้องเรียน): engine ไม่คำนวณข้อต่อให้ จึงวางชิ้นส่วนเองด้วย BulkMoveTo
-- เหตุผล: rig ที่มี Motor6D + ชิ้นไม่ Anchored 111 ตัว (~2,400 ชิ้น) ทำให้ Heartbeat ทั้ง server/client ช้า ~100 ms ส่วน Anchored ทั้งหมด ~19 ms (วัดแล้ว)
-- ใช้ได้ทั้ง server (วางท่าตั้งต้นครั้งเดียว) และ client (ขยับเฉพาะข้อต่อที่เปลี่ยน ~16 Hz)
-- Edge = Motor6D หรือ Weld (ผม/ปกเสื้อ/กระโปรงเป็น Weld) ลูก = parent * pre * xf * post ; xf = Transform ของ Motor6D (Weld = identity)
local RigFK = {}

export type Edge = {
	parent: BasePart,
	child: BasePart,
	pre: CFrame,
	post: CFrame,
	motor: Motor6D?,
	kids: { Edge },
	up: Edge?,
}
export type Rig = {
	root: BasePart,
	cf: { [BasePart]: CFrame },
	xf: { [Edge]: CFrame },
	byName: { [string]: Edge },
	top: { Edge },
}

local IDENT = CFrame.new()

function RigFK.Build(model: Model): Rig?
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	-- adjacency ของข้อต่อทั้งหมด
	local adj: { [BasePart]: { JointInstance } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("Weld") then
			local j = d :: JointInstance
			local p0, p1 = j.Part0, j.Part1
			if p0 and p1 then
				adj[p0] = adj[p0] or {}
				table.insert(adj[p0], j)
				adj[p1] = adj[p1] or {}
				table.insert(adj[p1], j)
			end
		end
	end
	local rig: Rig = { root = root, cf = { [root] = root.CFrame }, xf = {}, byName = {}, top = {} }
	-- ตำแหน่งปัจจุบันของทุกชิ้น (ใช้เป็นฐานเมื่อวางเฉพาะ subtree)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			rig.cf[d] = d.CFrame
		end
	end
	local seen: { [BasePart]: boolean } = { [root] = true }
	local queue: { BasePart } = { root }
	local qi = 1
	local upEdge: { [BasePart]: Edge } = {}
	while qi <= #queue do
		local cur = queue[qi]
		qi += 1
		for _, j in adj[cur] or {} do
			local p0, p1 = j.Part0 :: BasePart, j.Part1 :: BasePart
			local child: BasePart
			local edge: Edge
			if p0 == cur then
				child = p1
				edge = { parent = cur, child = child, pre = j.C0, post = j.C1:Inverse(), motor = if j:IsA("Motor6D") then j else nil, kids = {}, up = upEdge[cur] }
			else
				child = p0
				edge = { parent = cur, child = child, pre = j.C1, post = j.C0:Inverse(), motor = nil, kids = {}, up = upEdge[cur] }
			end
			if not seen[child] then
				seen[child] = true
				upEdge[child] = edge
				if edge.up then
					table.insert((edge.up :: Edge).kids, edge)
				else
					table.insert(rig.top, edge)
				end
				if edge.motor then
					rig.byName[(edge.motor :: Motor6D).Name] = edge
				end
				table.insert(queue, child)
			end
		end
	end
	return rig
end

local function place(rig: Rig, e: Edge, parts: { BasePart }, cfs: { CFrame })
	local cf = rig.cf[e.parent] * e.pre * (rig.xf[e] or IDENT) * e.post
	rig.cf[e.child] = cf
	table.insert(parts, e.child)
	table.insert(cfs, cf)
	for _, k in e.kids do
		place(rig, k, parts, cfs)
	end
end

-- วางทั้งตัวใหม่จาก cf[root] (ใช้ตอนเริ่มและตอนครูขยับ/หมุนทั้งตัว)
function RigFK.PlaceAll(rig: Rig, parts: { BasePart }, cfs: { CFrame })
	rig.cf[rig.root] = rig.root.CFrame
	for _, e in rig.top do
		place(rig, e, parts, cfs)
	end
end

-- ตั้งราก (ครูเดิน/หมุน) แล้ววางทั้งตัว
function RigFK.MoveRoot(rig: Rig, cf: CFrame, parts: { BasePart }, cfs: { CFrame })
	rig.cf[rig.root] = cf
	table.insert(parts, rig.root)
	table.insert(cfs, cf)
	for _, e in rig.top do
		place(rig, e, parts, cfs)
	end
end

-- วางเฉพาะ subtree ใต้ข้อต่อที่เปลี่ยน (ข้ามข้อต่อที่บรรพบุรุษก็เปลี่ยนด้วย เพราะถูกวางซ้ำอยู่แล้ว)
function RigFK.PlaceDirty(rig: Rig, dirty: { [Edge]: boolean }, parts: { BasePart }, cfs: { CFrame })
	for e in dirty do
		local skip = false
		local u = e.up
		while u do
			if dirty[u] then
				skip = true
				break
			end
			u = u.up
		end
		if not skip then
			place(rig, e, parts, cfs)
		end
	end
end

local CHUNK = 48

function RigFK.Apply(parts: { BasePart }, cfs: { CFrame })
	local n = #parts
	if n <= CHUNK then
		if n > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
		return
	end
	-- แบ่งเป็นก้อนเล็ก: BulkMoveTo ก้อนใหญ่ (~300+ ชิ้นในห้องเดียว) แพงแบบไม่เป็นเส้นตรง (วัดแล้ว)
	local i = 1
	while i <= n do
		local j = math.min(i + CHUNK - 1, n)
		workspace:BulkMoveTo(table.move(parts, i, j, 1, {}), table.move(cfs, i, j, 1, {}), Enum.BulkMoveMode.FireCFrameChanged)
		i = j + 1
	end
end

return RigFK
