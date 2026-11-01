--!strict
-- ชีวิตในเมือง: รถจอดริมถนน + รถวิ่งวนตามถนน + คนเดินถนนในย่าน (ไม่ถูกตี ไม่ใช่ศัตรู)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage.Shared.World)
local BK = require(script.Parent.BuildKit)
local RigFactory = require(script.Parent.RigFactory)

local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end

local hex = Color3.fromHex
local rng = Random.new(31)
local life = Instance.new("Folder")
life.Name = "AmbientLife"
life.Parent = worldFolder

local paint = { "EF233C", "4D7CFE", "FFE066", "FFFFFF", "2B2D42", "5FBF7A", "FF8A3D", "C9CED6", "FF8FAB" }

---------------------------------------------------------------- รถ: โมเดลง่ายๆ (ตัวถัง ห้องโดยสาร ล้อ ไฟหน้า) หันไปตามแกน Z ของ Model
-- โมเดลรถจริงที่นำเข้าและตรวจแล้ว (ServerStorage.ImportedAssets.Cars) ข้อตกลง: Pivot = กึ่งกลางใต้ล้อ หน้ารถหัน -Z ไม่มีสคริปต์
-- ถ้ามีจะใช้แทนรถที่สร้างด้วยชิ้นส่วนเอง; ถ้าไม่มีก็ใช้โมเดลโค้ดด้านล่าง (ไม่พัง)
local ServerStorage = game:GetService("ServerStorage")
local function importedCar(parent: Instance, cf: CFrame, moving: boolean): (Model?, BasePart?)
	local assets = ServerStorage:FindFirstChild("ImportedAssets")
	local folder = assets and assets:FindFirstChild("Cars")
	local list = folder and folder:GetChildren() or {}
	if #list == 0 then
		return nil
	end
	local src = list[rng:NextInteger(1, #list)]
	if not src:IsA("Model") then
		return nil
	end
	local model = src:Clone()
	model.Name = if moving then "TrafficCar" else "ParkedCar"
	-- สีตัวถังของโมเดลนำเข้าบางคันเป็นสีดิบ (#00FF00 / #FF0000) ให้เปลี่ยนเป็นสีรถจริงหม่น ๆ (ตัวถัง) หรือดำด้าน (ชิ้นแต่ง)
	local paints = { "D8D6D0", "2E3036", "8A8D91", "3F566E", "7A2E2A", "B8B2A4" }
	local paint = Color3.fromHex(paints[rng:NextInteger(1, #paints)])
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local hexColor = d.Color:ToHex():upper()
			if hexColor == "00FF00" then
				d.Color = if d.Name:find("trim") or d.Name:find("Weight") or d.Name:find("bumper_glass") then Color3.fromHex("1C1D21") else paint
			elseif hexColor == "FF0000" then
				d.Color = Color3.fromHex("1C1D21")
			end
		end
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Sound") then
			d:Destroy() -- กันไว้อีกชั้น ไม่เอาสคริปต์/เสียงจากโมเดลภายนอก
		end
	end
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = primary
	model:PivotTo(cf)
	-- วางให้ท้องรถ/ล้อล่างสุดแตะพื้นพอดี (บางโมเดลจุดหมุนไม่ได้อยู่ใต้ล้อ รถเลยลอย เช่นสกูตเตอร์)
	local bbCf, bbSize = model:GetBoundingBox()
	local lift = cf.Position.Y - (bbCf.Position.Y - bbSize.Y / 2)
	if math.abs(lift) > 0.05 and math.abs(lift) < 6 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	end
	model.Parent = parent
	if not moving then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanTouch = false
			end
		end
		-- โมเดลนำเข้าถูกปิดการชนไว้ทั้งคัน ผู้เล่นเลยเดินทะลุ: ใส่กล่องชนล่องหนครอบตัวรถจอด
		local bbCf, bbSize = model:GetBoundingBox()
		local collider = Instance.new("Part")
		collider.Name = "Collider"
		collider.Size = bbSize * Vector3.new(0.95, 1, 0.97)
		collider.CFrame = bbCf
		collider.Transparency = 1
		collider.Anchored = true
		collider.CanCollide = true
		collider.CanQuery = false
		collider.CanTouch = false
		collider.Parent = model
		return model, primary
	end
	-- รถวิ่ง: ตัวขยับล่องหนที่ Anchored ตัวเดียว ชิ้นอื่นเชื่อมตามด้วย Weld ไม่ชนผู้เล่น
	local mover = Instance.new("Part")
	mover.Name = "Mover"
	mover.Size = Vector3.one
	mover.Transparency = 1
	mover.Anchored = true
	mover.CanCollide, mover.CanQuery, mover.CanTouch = false, false, false
	mover.CFrame = cf
	mover.Parent = model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= mover then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			if d ~= primary then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = primary, d
				w.Parent = d
			end
		end
	end
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = mover, primary
	w.Parent = primary
	return model, mover
end

local function buildCar(parent: Instance, cf: CFrame, moving: boolean): (Model, BasePart)
	local imported, importedBody = importedCar(parent, cf, moving)
	if imported and importedBody then
		return imported, importedBody
	end
	local model = Instance.new("Model")
	model.Name = if moving then "TrafficCar" else "ParkedCar"
	local color = hex(paint[rng:NextInteger(1, #paint)])
	local function piece(name: string, size: Vector3, offset: Vector3, c: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.CFrame = cf * CFrame.new(offset)
		p.Anchored = not moving
		p.CanCollide = not moving -- รถวิ่งไม่ชนผู้เล่น (กันถูกผลักแปลกๆ) รถจอดชนได้
		p.CanTouch = false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local body = piece("Body", Vector3.new(4.2, 1.5, 9), Vector3.new(0, 1.7, 0), color, Enum.Material.Metal)
	local cabin = piece("Cabin", Vector3.new(3.6, 1.3, 4.6), Vector3.new(0, 3.0, -0.4), hex("1A1A22"), Enum.Material.Glass)
	cabin.Transparency = 0.25
	piece("Roof", Vector3.new(3.7, 0.25, 4.7), Vector3.new(0, 3.75, -0.4), color, Enum.Material.Metal)
	-- ล้อใหญ่โผล่พ้นข้างตัวถัง + ดุมสีเงิน (เดิมล้อดำเล็กกลืนไปกับถนน มองไม่เห็น)
	for _, side in { -1, 1 } do
		for _, wz in { -2.9, 2.9 } do
			local wheel = piece("Wheel", Vector3.new(1.0, 2.4, 2.4), Vector3.new(side * 2.3, 1.2, wz), hex("2A2B31"), nil, Enum.PartType.Cylinder)
			wheel.CanCollide = false
			local hub = piece("Hubcap", Vector3.new(0.2, 1.3, 1.3), Vector3.new(side * 2.85, 1.2, wz), hex("C9CCD3"), Enum.Material.Metal, Enum.PartType.Cylinder)
			hub.CanCollide = false
		end
	end
	for _, lx in { -1.4, 1.4 } do
		local head = piece("Headlight", Vector3.new(0.9, 0.5, 0.2), Vector3.new(lx, 1.9, -4.55), hex("FFF3C9"), Enum.Material.Neon)
		head.CanCollide = false
		local tail = piece("Taillight", Vector3.new(0.9, 0.4, 0.2), Vector3.new(lx, 1.9, 4.55), hex("EF233C"), Enum.Material.Neon)
		tail.CanCollide = false
	end
	if moving then
		body.Anchored = true -- ตัวถังคุมตำแหน่ง (tween) ชิ้นอื่นเชื่อมตามด้วย Weld
		for _, p in model:GetChildren() do
			if p ~= body and p:IsA("BasePart") then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = body, p
				w.Parent = p
			end
		end
	end
	model.PrimaryPart = body
	model.Parent = parent
	return model, body
end

local function inSchoolZone(x: number, z: number): boolean
	return math.abs(x) < 240 and z > -200 and z < 360
end

-- รถจอดริมถนนสุ่มตามความยาวถนน
local parked = Instance.new("Folder")
parked.Name = "Parked"
parked.Parent = life
for ri, r in World.Roads do
	local x1, z1, x2, z2, w = r[1], r[2], r[3], r[4], r[5]
	local horizontal = math.abs(x2 - x1) >= math.abs(z2 - z1)
	local length = if horizontal then math.abs(x2 - x1) else math.abs(z2 - z1)
	if w >= 14 and r[6] ~= "T" then
		for _, side in { -1, 1 } do
			local lane = side * (w / 2 - 3.2)
			local intervals = World.FreeIntervals(ri, lane)
			for t = 40, length - 40, 55 do
				if rng:NextNumber() < 0.3 then
					local along = (if horizontal then math.min(x1, x2) else math.min(z1, z2)) + t + rng:NextNumber(-10, 10)
					local ok = false
					for _, iv in intervals do
						if along >= iv[1] + 8 and along <= iv[2] - 8 then
							ok = true
						end
					end
					local x = if horizontal then along else x1 + lane
					local z = if horizontal then z1 + lane else along
					if ok and not inSchoolZone(x, z) and math.abs(z - 420) > 36 then
						local heading = if horizontal then math.rad(90) else 0
						if rng:NextNumber() > 0.5 then
							heading += math.pi
						end
						buildCar(parked, CFrame.new(x, 0.3, z) * CFrame.Angles(0, heading, 0), false)
					end
				end
			end
		end
	end
end

-- รถวิ่งวนตามถนนสายหลัก/ถนนใต้แม่น้ำ (ไม่ชนผู้เล่น วิ่งช้าๆ เพื่อให้เมืองมีชีวิต)
local traffic = Instance.new("Folder")
traffic.Name = "Traffic"
traffic.Parent = life
local routes = {
	{ Vector3.new(-760, 0.3, 170 + 3.5), Vector3.new(760, 0.3, 170 + 3.5), 25 },
	{ Vector3.new(760, 0.3, 170 - 3.5), Vector3.new(-760, 0.3, 170 - 3.5), 25 },
	{ Vector3.new(-660, 0.3, 600 + 3), Vector3.new(680, 0.3, 600 + 3), 22 },
	{ Vector3.new(680, 0.3, 600 - 3), Vector3.new(-660, 0.3, 600 - 3), 22 },
}
for i, route in routes do
	local a: Vector3, b: Vector3, speed: number = route[1], route[2], route[3]
	for k = 0, 1 do
		task.spawn(function()
			local start = a:Lerp(b, k * 0.5)
			local dir = (b - a).Unit
			local heading = math.atan2(-dir.X, -dir.Z)
			local model, body = buildCar(traffic, CFrame.new(start) * CFrame.Angles(0, heading, 0), true)
			while model.Parent do
				local from = body.Position
				local toTarget = b
				local duration = (toTarget - from).Magnitude / speed
				local tween = TweenService:Create(body, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
					CFrame = CFrame.new(toTarget) * CFrame.Angles(0, heading, 0),
				})
				tween:Play()
				tween.Completed:Wait()
				body.CFrame = CFrame.new(a) * CFrame.Angles(0, heading, 0) -- วนกลับจุดเริ่ม
			end
		end)
	end
end

-- ถูกรถวิ่งชน: กระเด็น ล้มลง เสียเลือดเล็กน้อย (รถวิ่งไม่มีแรงชนทางฟิสิกส์ จึงตรวจด้วยกล่องรอบตัวรถ)
do
	local Players = game:GetService("Players")
	local Combat = require(script.Parent.Combat)
	local hitAt: { [Player]: number } = {}
	local HALF = Vector3.new(2.6, 3, 5.2) -- ครึ่งหนึ่งของกล่องชน (กว้าง สูง ยาว) รวมระยะตัวละครแล้ว
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			for _, car in traffic:GetChildren() do
				if car:IsA("Model") then
					local cf = car:GetPivot()
					for _, player in Players:GetPlayers() do
						local char = player.Character
						local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if root and hum and hum.Health > 0 and now - (hitAt[player] or 0) > 2 then
							local p = cf:PointToObjectSpace(root.Position)
							if math.abs(p.X) < HALF.X and math.abs(p.Y - 2) < HALF.Y and math.abs(p.Z) < HALF.Z then
								hitAt[player] = now
								local s = Combat.Get(char)
								local forward = cf.LookVector
								local side = cf.RightVector * (if p.X >= 0 then 1 else -1)
								local push = (forward * 1.0 + side * 0.7).Unit
								if s then
									s:Knockdown(1.6)
									Combat.Impulse(s, push * 38 + Vector3.new(0, 20, 0), 0.35)
									Combat.PlayAnim(char, "Knockdown")
								end
								hum:TakeDamage(math.max(10, hum.MaxHealth * 0.12))
							end
						end
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------- คนเดินถนน (เกิดเมื่อมีผู้เล่นเข้าใกล้ย่าน)
local PEDESTRIANS = 6
local npcFolder = Instance.new("Folder")
npcFolder.Name = "Pedestrians"
npcFolder.Parent = workspace

local spawned: { [string]: { Model } } = {}
for _, d in World.Districts do
	spawned[d.Id] = {}
end

local function randomSpot(d: World.District): Vector3?
	for _ = 1, 20 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = d.Radius * 0.8 * math.sqrt(rng:NextNumber())
		local x, z = d.Center.X + math.cos(a) * r, d.Center.Z + math.sin(a) * r
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { npcFolder, workspace:FindFirstChild("Npcs") :: Instance? }
		local res = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
		if res and res.Material ~= Enum.Material.Water and res.Position.Y < 2 then
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Exclude
			overlap.FilterDescendantsInstances = { npcFolder }
			local clear = true
			for _, p in workspace:GetPartBoundsInBox(CFrame.new(x, res.Position.Y + 4, z), Vector3.new(3, 6, 3), overlap) do
				if p.CanCollide then
					clear = false
					break
				end
			end
			if clear then
				return res.Position
			end
		end
	end
	return nil
end

local function spawnPedestrians(d: World.District)
	for _ = 1, PEDESTRIANS do
		local pos = randomSpot(d)
		if pos then
			local rig = RigFactory.Create("คนเดินถนน", pos + Vector3.new(0, 3, 0), npcFolder)
			if rig then
				table.insert(spawned[d.Id], rig)
				local hum = rig:FindFirstChildOfClass("Humanoid")
				local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hum and root then
					hum.WalkSpeed = rng:NextNumber(5, 8)
					hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					task.spawn(function()
						while rig.Parent and hum.Health > 0 do
							local target = randomSpot(d)
							if target then
								hum:MoveTo(target)
								hum.MoveToFinished:Wait()
							end
							task.wait(rng:NextNumber(2, 7))
						end
					end)
				end
			end
		end
	end
end

local function despawn(id: string)
	for _, m in spawned[id] do
		m:Destroy()
	end
	table.clear(spawned[id])
end

task.spawn(function()
	while true do
		task.wait(4)
		for _, d in World.Districts do
			local nearest = math.huge
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					nearest = math.min(nearest, Vector2.new(root.Position.X - d.Center.X, root.Position.Z - d.Center.Z).Magnitude)
				end
			end
			if nearest < d.Radius + 220 and #spawned[d.Id] == 0 then
				task.spawn(spawnPedestrians, d)
			elseif nearest > d.Radius + 380 and #spawned[d.Id] > 0 then
				despawn(d.Id)
			end
		end
	end
end)
