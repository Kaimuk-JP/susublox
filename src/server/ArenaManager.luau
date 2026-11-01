--!strict
-- จัดการสนามประลองแบบ instance: สร้างฉากจากแม่แบบ (ArenaKit) ไกลจากเมือง, วาร์ปเข้า-ออก, กันหลุดขอบ, เก็บกวาด
-- ใช้ร่วมกันโดยดวล 1v1 / สงครามแก๊ง 4v4 / ศึกฝึกซ้อมบอท (เซิร์ฟเวอร์เป็นผู้ตัดสินทั้งหมด)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Kit = require(script.Parent.ArenaKit)

local countdownRemote = Instance.new("RemoteEvent")
countdownRemote.Name = "ArenaCountdown"
countdownRemote.Parent = ReplicatedStorage

export type Inst = {
	Id: number,
	Kind: string,
	Label: string,
	Theme: string,
	Model: Model,
	Origin: CFrame,
	Radius: number,
	Markers: Folder,
	Members: { [Player]: string }, -- "fighter" | "spec"
	Over: boolean,
	OuterRadius: number,
	Locked: boolean, -- ช่วงนับถอยหลัง: ล็อกนักสู้
	CountdownCancel: boolean,
	OnLeave: ((Player) -> ())?,
}

local Arena = {}

local MAX_INSTANCES = 8
local SPACING = 640
local BASE = Vector3.new(-600, 600, 3000)
local Z_ROWS = 4 -- ช่อง 4 คอลัมน์ x 2 แถว
local BUDGET = 26 -- งบขนาดรวม: sum((R/40)^2) ของ instance ที่เปิดอยู่ (กันหน่วยความจำ/จำนวน part บวม)
local MAX_TEMPLATES = 6

local instances: { [number]: Inst } = {}
local slotOf: { [Inst]: number } = {}
local of: { [Player]: Inst } = {}
local nextId = 0
local rng = Random.new()

local container = Instance.new("Folder")
container.Name = "ArenaInstances"
container.Parent = workspace

local templates = Instance.new("Folder")
templates.Name = "ArenaTemplates"
templates.Parent = ServerStorage

-- แม่แบบ cache ตามธีม+รัศมี (สร้างตอนต้องใช้ เก็บไว้ไม่เกิน MAX_TEMPLATES อันล่าสุด)
local function template(theme: string, R: number): Model?
	local key = `{theme}_{R}`
	local t = templates:FindFirstChild(key) :: Model?
	if not t then
		t = Kit.BuildTemplate(theme, R)
		if t then
			t.Name = key
			t:SetAttribute("UsedAt", os.clock())
			t.Parent = templates
			local list = templates:GetChildren()
			if #list > MAX_TEMPLATES then
				table.sort(list, function(a, b)
					return (a:GetAttribute("UsedAt") or 0) < (b:GetAttribute("UsedAt") or 0)
				end)
				list[1]:Destroy()
			end
		end
	elseif t then
		t:SetAttribute("UsedAt", os.clock())
	end
	return t
end

-- สร้างแม่แบบล่วงหน้าหลังเกมพร้อม (กระจายเวลา ไม่ให้ช้าตอนเข้าเกม)
task.defer(function()
	task.wait(8)
	for _, theme in Kit.THEMES do
		template(theme, Kit.MIN_R)
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- ลานหน้าสนาม (จุดกลับ)
local LOBBY_X, LOBBY_Z0, LOBBY_Z1 = 50, 209, 241
function Arena.InLobby(position: Vector3): boolean
	return math.abs(position.X) <= LOBBY_X and position.Z >= LOBBY_Z0 and position.Z <= LOBBY_Z1 and position.Y < 30
end

local function lobbySpot(): CFrame
	local x = if rng:NextNumber() < 0.5 then rng:NextNumber(-36, -14) else rng:NextNumber(-8, 8)
	local z = rng:NextNumber(214, 222)
	return CFrame.lookAt(Vector3.new(x, 4.5, z), Vector3.new(x, 4.5, 260))
end

---------------------------------------------------------------- วาร์ป
local function rootOf(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- วาร์ปแบบรอให้พื้นที่ปลายทางสตรีมถึงเครื่องผู้เล่นก่อน (กันตกพื้น)
local function warp(player: Player, cf: CFrame): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 4)
	end)
	root = rootOf(player)
	if not root or not player.Parent then
		return false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	;(player.Character :: Model):PivotTo(cf)
	return true
end

local function setStatus(player: Player, inst: Inst?, role: string?)
	player:SetAttribute("ArenaRole", role)
	player:SetAttribute("ArenaKind", if inst then inst.Kind else nil)
	local char = player.Character
	if char then
		char:SetAttribute("ArenaId", if inst and role == "fighter" then inst.Id else nil)
		char:SetAttribute("ArenaSpec", if inst and role == "spec" then true else nil)
	end
end

---------------------------------------------------------------- สร้าง/ทำลาย
function Arena.Create(kind: string, label: string, theme: string?, players: number?): Inst?
	local slot: number? = nil
	for i = 0, MAX_INSTANCES - 1 do
		local used = false
		for _, inst in instances do
			if slotOf[inst] == i then
				used = true
			end
		end
		if not used then
			slot = i
			break
		end
	end
	if not slot then
		return nil
	end
	local themeName = theme or Kit.THEMES[rng:NextInteger(1, #Kit.THEMES)]
	local R = Kit.RadiusFor(players or 2)
	local used = (R / 40) ^ 2
	for _, other in instances do
		used += (other.Radius / 40) ^ 2
	end
	if used > BUDGET then
		return nil
	end
	local t = template(themeName, R)
	if not t then
		return nil
	end
	nextId += 1
	local model = t:Clone()
	model.Name = "Arena_" .. nextId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local origin = CFrame.new(BASE + Vector3.new((slot % 4) * SPACING, 0, (slot // 4) * SPACING))
	model:PivotTo(origin)
	model.Parent = container
	model:SetAttribute("BState", "wait")
	model:SetAttribute("BTitle", label)
	local inst: Inst = {
		Id = nextId,
		Kind = kind,
		Label = label,
		Theme = themeName,
		Model = model,
		Origin = origin,
		Radius = (model:GetAttribute("Radius") :: number?) or 30,
		OuterRadius = (model:GetAttribute("OuterRadius") :: number?) or 75,
		Locked = false,
		CountdownCancel = false,
		Markers = model:WaitForChild("Markers") :: Folder,
		Members = {},
		Over = false,
	}
	instances[inst.Id] = inst
	slotOf[inst] = slot
	return inst
end

function Arena.Get(id: number): Inst?
	return instances[id]
end

function Arena.Of(player: Player): Inst?
	return of[player]
end

function Arena.List(): { Inst }
	local list = {}
	for _, inst in instances do
		if not inst.Over then
			table.insert(list, inst)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

-- ป้ายคะแนน: เซิร์ฟเวอร์เซ็ต Attribute บนโมเดล ไคลเอนต์ (ArenaBoard) วาดข้อความและนับเวลาเองจาก BEnds
-- fields: State("wait"|"countdown"|"live"|"over"), Title, NameA, NameB, Mid, LeadA, LeadB, Note, Ends (เวลาเซิร์ฟเวอร์ GetServerTimeNow)
function Arena.SetBoard(inst: Inst, fields: { [string]: any })
	for k, v in fields do
		inst.Model:SetAttribute("B" .. k, v)
	end
end

-- เข้ากันได้กับโค้ดเดิม: ข้อความอิสระบรรทัดเดียวลงช่อง Note/Title
function Arena.SetScore(inst: Inst, text: string)
	inst.Model:SetAttribute("BNote", (text:gsub("<[^>]+>", ""):gsub("
", " · ")))
end

function Arena.FighterCount(inst: Inst): number
	local n = 0
	for _, role in inst.Members do
		if role == "fighter" then
			n += 1
		end
	end
	return n
end

function Arena.MarkerPos(inst: Inst, name: string): Vector3?
	local m = inst.Markers:FindFirstChild(name) :: BasePart?
	return m and m.Position
end

local function seatCf(inst: Inst): CFrame
	local seats = {}
	for _, m in inst.Markers:GetChildren() do
		if m.Name:sub(1, 4) == "Spec" then
			table.insert(seats, m)
		end
	end
	local seat = seats[rng:NextInteger(1, math.max(#seats, 1))] :: BasePart?
	local pos = if seat then seat.Position + Vector3.new(0, 3, 0) else inst.Origin.Position + Vector3.new(0, 12, 0)
	return CFrame.lookAt(pos, Vector3.new(inst.Origin.X, pos.Y, inst.Origin.Z))
end

-- เข้าสนามที่จุด marker (เช่น SpawnA4) เป็นนักสู้ หรือที่นั่งชม (marker = nil, role = "spec")
function Arena.Enter(inst: Inst, player: Player, markerName: string?, role: string): boolean
	if inst.Over or of[player] or not rootOf(player) then
		return false
	end
	of[player] = inst
	inst.Members[player] = role
	setStatus(player, inst, role)
	local cf: CFrame
	local pos = if markerName then Arena.MarkerPos(inst, markerName) else nil
	if pos then
		local target = pos + Vector3.new(0, 4, 0)
		cf = CFrame.lookAt(target, Vector3.new(inst.Origin.X, target.Y, inst.Origin.Z))
	else
		cf = seatCf(inst)
	end
	if not warp(player, cf) then
		of[player] = nil
		inst.Members[player] = nil
		setStatus(player, nil, nil)
		return false
	end
	local hum = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
	if hum and role == "fighter" then
		hum.Health = hum.MaxHealth
	end
	return true
end

-- ออกจากสนามกลับลานหน้าสนาม (เรียกซ้ำได้ ปลอดภัย)
function Arena.Exit(player: Player)
	local inst = of[player]
	if not inst then
		return
	end
	of[player] = nil
	inst.Members[player] = nil
	setStatus(player, nil, nil)
	local char = player.Character
	if char then
		char:SetAttribute("Team", nil)
		char:SetAttribute("ArenaLocked", nil)
		if rootOf(player) then
			warp(player, lobbySpot())
		end
	end
end

-- ผู้เล่นกดออกเอง: นักสู้ = ยอมแพ้ (บริการแต่ละโหมดจัดการผ่าน OnLeave)
function Arena.Leave(player: Player)
	local inst = of[player]
	if not inst then
		return
	end
	if inst.Members[player] == "fighter" and inst.OnLeave then
		pcall(inst.OnLeave, player)
	end
	Arena.Exit(player)
end

-- นับถอยหลังก่อนเริ่มแมตช์ (เรียกหลังนักสู้ทุกคนเข้าสนามแล้ว): ล็อกการเดิน/โจมตีและกันดาเมจ (Attribute ArenaLocked)
-- ไคลเอนต์รับเวลาจบแบบเวลาเซิร์ฟเวอร์ (ArenaCountdown "Start", endsAt) จึงซิงก์กัน
-- คืน true = นับครบ แล้วปลดล็อก; false = ยกเลิก (มีคนออก/ตาย/หลุด หรือ aborted() เป็นจริง) ปลดล็อกทุกคนก่อนคืนค่า
function Arena.RunCountdown(inst: Inst, secs: number, aborted: (() -> boolean)?): boolean
	local fighters: { Player } = {}
	for player, role in inst.Members do
		if role == "fighter" then
			table.insert(fighters, player)
		end
	end
	if #fighters == 0 then
		return false
	end
	local endsAt = workspace:GetServerTimeNow() + secs
	inst.Locked = true
	Arena.SetBoard(inst, { State = "countdown", Ends = endsAt })
	for player in inst.Members do
		countdownRemote:FireClient(player, "Start", endsAt)
	end
	local ok = true
	while ok and workspace:GetServerTimeNow() < endsAt do
		if inst.Over or (aborted and aborted()) then
			ok = false
			break
		end
		for _, player in fighters do
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if player.Parent ~= Players or inst.Members[player] ~= "fighter" or not char or not hum or hum.Health <= 0 then
				ok = false
			else
				char:SetAttribute("ArenaLocked", true)
				hum.WalkSpeed = 0
			end
		end
		task.wait(0.1)
	end
	inst.Locked = false
	for _, player in fighters do
		local char = player.Character
		if char then
			char:SetAttribute("ArenaLocked", nil)
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum.WalkSpeed = (char:GetAttribute("BaseWalkSpeed") :: number?) or 16
			end
		end
	end
	for player in inst.Members do
		countdownRemote:FireClient(player, if ok then "Fight" else "Cancel")
	end
	return ok
end

-- จบการต่อสู้: ถอนสถานะนักสู้ (ตีกันไม่ได้แล้ว) แต่ยังอยู่ในสนามรอส่งกลับ
function Arena.EndFight(inst: Inst)
	for player, role in inst.Members do
		if role == "fighter" then
			inst.Members[player] = "spec"
			setStatus(player, inst, "spec")
			if player.Character then
				player.Character:SetAttribute("Team", nil)
			end
		end
	end
end

function Arena.Destroy(inst: Inst)
	if instances[inst.Id] ~= inst then
		return
	end
	inst.Over = true
	local pending = 0
	for player in inst.Members do
		pending += 1
		task.spawn(function()
			Arena.Exit(player)
			pending -= 1
		end)
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 10 do
		task.wait(0.1)
	end
	-- กันค้าง: ใครยังอยู่ใน model (วาร์ปไม่สำเร็จ) ดึงกลับตรง ๆ
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and root:IsDescendantOf(workspace) and (root.Position - inst.Origin.Position).Magnitude < 150 then
			(player.Character :: Model):PivotTo(lobbySpot())
		end
	end
	local npcs = workspace:FindFirstChild("Npcs")
	if npcs then
		for _, n in npcs:GetChildren() do
			if n:GetAttribute("ArenaId") == inst.Id then
				n:SetAttribute("Despawned", true)
				n:Destroy()
			end
		end
	end
	instances[inst.Id] = nil
	slotOf[inst] = nil
	inst.Model:Destroy()
end

function Arena.CountInstances(): number
	local n = 0
	for _ in instances do
		n += 1
	end
	return n
end

---------------------------------------------------------------- เหตุการณ์ผู้เล่น
local function onCharacter(player: Player)
	player.CharacterAdded:Connect(function(char)
		local inst = of[player]
		if not inst or inst.Over then
			return
		end
		-- ตายในสนามแล้วเกิดใหม่ = ไปนั่งชมจนจบแมตช์
		inst.Members[player] = "spec"
		task.spawn(function()
			char:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.3)
			if of[player] == inst and not inst.Over and player.Character == char then
				setStatus(player, inst, "spec")
				warp(player, seatCf(inst))
			end
		end)
	end)
end
Players.PlayerAdded:Connect(onCharacter)
for _, p in Players:GetPlayers() do
	onCharacter(p)
end

Players.PlayerRemoving:Connect(function(player)
	local inst = of[player]
	of[player] = nil
	if inst then
		inst.Members[player] = nil
	end
end)

-- ยามตรวจทุกวินาที: นักสู้/ผู้ชมที่หลุดขอบหรือตกพื้นถูกดึงกลับ
task.spawn(function()
	while true do
		task.wait(1)
		for _, inst in instances do
			if inst.Over then
				continue
			end
			for player, role in inst.Members do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 then
					local rel = root.Position - inst.Origin.Position
					local flat = Vector2.new(rel.X, rel.Z).Magnitude
					local limit = if role == "fighter" then inst.Radius + 2 else inst.OuterRadius
					if flat > limit or rel.Y < -25 or rel.Y > 80 then
						if role == "fighter" then
							local p = Arena.MarkerPos(inst, "SpawnA4")
							if p then
								(player.Character :: Model):PivotTo(CFrame.new(p + Vector3.new(0, 4, 0)))
							end
						else
							warp(player, seatCf(inst))
						end
					end
				end
			end
		end
	end
end)

return Arena
