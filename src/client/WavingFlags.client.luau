--!strict
-- ธงพลิ้วลม: แทนแผ่นธงแข็ง (ชิ้นส่วนชื่อ "Flag"/"CampFlag") ด้วยแถบผ้าหลายชิ้นที่ขยับเป็นคลื่นตามลม ทำเฉพาะธงที่อยู่ใกล้ผู้เล่น
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local STRIPS = 20
local ACTIVE_RANGE = 160 -- ใกล้กว่านี้ถึงจะสร้างผ้า/ขยับ
local WAVE_SPEED = 3.2
local WAVE_LENGTH = 6 -- ความยาวคลื่นเป็น studs

type Flag = {
	Part: BasePart,
	Cloth: Folder?,
	Strips: { BasePart },
	Long: Vector3, -- แกนยาวของผืนผ้า (หน่วยโลคัล)
	Thin: Vector3, -- แกนความหนา (ทิศที่ผ้าพลิ้ว)
	LongSize: number,
	Height: number,
	Thick: number,
	Dir: number, -- +1 ถ้าปลายผ้าอยู่ด้านบวกของแกนยาว (ขอบผูกเสาอยู่ด้านลบ)
	Phase: number,
	Up: Vector3,
	Disc: BasePart?, -- ตราวงกลม (FlagDisc) ที่ต้องพลิ้วไปกับผ้า: วาดด้วยแถบบางๆ ซ้อนบนแถบผ้า
	DiscU: number, -- ตำแหน่งกลางวงกลมตามความยาวผ้า (0 = ขอบผูกเสา, 1 = ปลาย)
	DiscV: number, -- ระยะกลางวงกลมตามแกนความสูงจากกลางผ้า
	DiscR: number,
	Emblem: { BasePart? },
}

local WEATHER_WIND = { Clear = 1.0, Cloudy = 1.1, Rain = 1.5, Storm = 2.2 }
local wind = 1 -- ตัวคูณลมที่ค่อยๆ ไล่ตามสภาพอากาศ
local flags: { [BasePart]: Flag } = {}

local function axisOf(size: Vector3): (Vector3, Vector3, Vector3, number, number, number)
	-- แกนบางสุด = ความหนา; แกนยาวสุดในสองแกนที่เหลือ = ทิศผ้า; แกนที่เหลือ = ความสูงผ้า
	local dims = { { size.X, Vector3.xAxis }, { size.Y, Vector3.yAxis }, { size.Z, Vector3.zAxis } }
	table.sort(dims, function(a, b)
		return a[1] < b[1]
	end)
	local thin, mid, long = dims[1], dims[2], dims[3]
	-- ผ้าที่สูงกว่ายาวก็ยังถือว่าแกน Y เป็นความสูง
	if mid[2] == Vector3.yAxis then
		return long[2], thin[2], mid[2], long[1], mid[1], thin[1]
	end
	if long[2] == Vector3.yAxis then
		return mid[2], thin[2], long[2], mid[1], long[1], thin[1]
	end
	return long[2], thin[2], mid[2], long[1], mid[1], thin[1]
end

local function register(part: Instance)
	if not part:IsA("BasePart") or flags[part] then
		return
	end
	if part.Name ~= "Flag" and part.Name ~= "CampFlag" then
		return
	end
	local long, thin, up, longSize, height, thick = axisOf(part.Size)
	-- ด้านที่ติดเสา: ปลายของแกนยาวที่ใกล้เสาที่สุดในโฟลเดอร์เดียวกัน (ไกลเกินความยาวผ้าถือว่าไม่ใช่เสาของธงนี้ -> ใช้ปลายด้านลบ)
	local dir = -1
	local parent = part.Parent
	local best, bestD = nil, longSize
	local disc: BasePart? = nil
	if parent then
		for _, sib in parent:GetChildren() do
			if sib:IsA("BasePart") then
				if sib.Name == "FlagPole" or sib.Name == "CampPole" or sib.Name == "CampSignPost" then
					local d = (sib.Position - part.Position).Magnitude
					if d < bestD then
						best, bestD = sib, d
					end
				elseif sib.Name == "FlagDisc" and (sib.Position - part.Position).Magnitude < longSize then
					disc = sib
				end
			end
		end
	end
	if best then
		local rel = part.CFrame:PointToObjectSpace(best.Position)
		dir = if rel:Dot(long) > 0 then 1 else -1
	end
	local discU, discV, discR = 0.5, 0, 0
	if disc then
		local rel = part.CFrame:PointToObjectSpace(disc.Position)
		discU = 0.5 - dir * rel:Dot(long) / longSize
		discV = rel:Dot(up)
		discR = math.max(disc.Size.Y, disc.Size.Z) / 2
	end
	flags[part] = {
		Part = part,
		Cloth = nil,
		Strips = {},
		Long = long,
		Thin = thin,
		LongSize = longSize,
		Height = height,
		Thick = math.max(thick, 0.15),
		Dir = dir,
		Phase = (part.Position.X * 0.13 + part.Position.Z * 0.07) % 6.28,
		Up = up,
		Disc = disc,
		DiscU = discU,
		DiscV = discV,
		DiscR = discR,
		Emblem = {},
	}
end

local function activate(f: Flag)
	local part = f.Part
	local folder = Instance.new("Folder")
	folder.Name = "FlagCloth"
	folder.Parent = part
	local segLen = f.LongSize / STRIPS
	for _ = 1, STRIPS do
		local s = Instance.new("Part")
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.Material = Enum.Material.Fabric
		s.Color = part.Color
		s.Size = Vector3.new(segLen + 0.06, f.Height, f.Thick) -- แกนโลคัลของแถบ: X = ยาว, Y = สูง, Z = หนา
		s.Parent = folder
		table.insert(f.Strips, s)
	end
	if f.Disc then
		local d = f.Disc
		for i = 1, STRIPS do
			local dx = ((i - 0.5) / STRIPS - f.DiscU) * f.LongSize
			if math.abs(dx) < f.DiscR then
				local e = Instance.new("Part")
				e.Anchored = true
				e.CanCollide = false
				e.CanQuery = false
				e.CanTouch = false
				e.CastShadow = false
				e.Material = d.Material
				e.Color = d.Color
				e.Size = Vector3.new(segLen + 0.06, 2 * math.sqrt(f.DiscR ^ 2 - dx ^ 2), f.Thick + 0.1)
				e.Parent = folder
				f.Emblem[i] = e
			end
		end
		d.LocalTransparencyModifier = 1
	end
	f.Cloth = folder
	part.LocalTransparencyModifier = 1
end

local function deactivate(f: Flag)
	if f.Cloth then
		if f.Disc then
			f.Disc.LocalTransparencyModifier = 0
			table.clear(f.Emblem)
		end
		f.Cloth:Destroy()
		f.Cloth = nil
		table.clear(f.Strips)
		f.Part.LocalTransparencyModifier = 0
	end
end

local function update(f: Flag, t: number, wp: number)
	local windMul = wind
	local base = f.Part.CFrame
	local longW = base:VectorToWorldSpace(f.Long)
	local thinW = base:VectorToWorldSpace(f.Thin)
	local upW = base:VectorToWorldSpace(f.Up)
	local n = #f.Strips
	local segLen = f.LongSize / n
	local gust = (0.85 + 0.25 * math.sin(t * 0.7 + f.Phase)) * windMul
	local prevOff = 0
	for i, strip in f.Strips do
		local u = (i - 0.5) / n -- 0 = ขอบผูกเสา, 1 = ปลายผ้า
		local along = f.Dir * f.LongSize * (0.5 - u)
		local amp = math.min((0.1 + 0.9 * u) * f.LongSize * 0.1 * gust, f.LongSize * 0.3 * u + 0.1)
		local off = amp * math.sin(u * f.LongSize / WAVE_LENGTH * 6.283 - wp + f.Phase)
		local sag = -0.05 * u * f.Height * math.sin(t * 1.9 + u * 3)
		local center = f.Part.Position + longW * along + thinW * off + upW * sag
		-- ทิศของแถบตามความชันของคลื่น (จากปลายผูกไปปลายผ้า) ให้แถบต่อกันเนียน
		local step = -f.Dir * segLen -- ทิศการเพิ่ม u ตามแกนยาว
		local vx = (longW * step + thinW * (off - prevOff)).Unit
		prevOff = off
		local vz = vx:Cross(upW).Unit
		local vy = vz:Cross(vx).Unit
		local cf = CFrame.fromMatrix(center, vx, vy, vz)
		strip.CFrame = cf
		local e = f.Emblem[i]
		if e then
			e.CFrame = cf * CFrame.new(0, f.DiscV, 0)
		end
	end
end

-- รวบรวมธงที่มีอยู่และที่สตรีมเข้ามาทีหลัง
task.spawn(function()
	local list = workspace:GetDescendants()
	for i, d in list do
		register(d)
		if i % 4000 == 0 then
			task.wait()
		end
	end
end)
workspace.DescendantAdded:Connect(register)
workspace.DescendantRemoving:Connect(function(d)
	local f = flags[d :: any]
	if f then
		deactivate(f)
		flags[d :: any] = nil
	end
end)

local acc = 0
local windPhase = 0
RunService.Heartbeat:Connect(function(dt)
	local target = WEATHER_WIND[(workspace:GetAttribute("Weather") or "Clear") :: string] or 1
	acc += dt
	wind += (target - wind) * math.min(dt * 0.5, 1)
	windPhase += dt * WAVE_SPEED * wind
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = workspace.CurrentCamera
	local origin = if cam then cam.CFrame.Position elseif root then root.Position else nil
	if not origin then
		return
	end
	local t = os.clock()
	for part, f in flags do
		local near = (part.Position - origin).Magnitude < ACTIVE_RANGE
		if near then
			if not f.Cloth then
				activate(f)
			end
			update(f, t, windPhase)
		elseif f.Cloth then
			deactivate(f)
		end
	end
end)
