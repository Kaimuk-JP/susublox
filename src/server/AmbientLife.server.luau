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
local function buildCar(parent: Instance, cf: CFrame, moving: boolean): (Model, BasePart)
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
	for _, wx in { -2.15, 2.15 } do
		for _, wz in { -2.9, 2.9 } do
			local wheel = piece("Wheel", Vector3.new(0.8, 1.8, 1.8), Vector3.new(wx, 0.9, wz), hex("1A1A22"), nil, Enum.PartType.Cylinder)
			wheel.CanCollide = false
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
for _, r in World.Roads do
	local x1, z1, x2, z2, w = r[1], r[2], r[3], r[4], r[5]
	local horizontal = math.abs(x2 - x1) >= math.abs(z2 - z1)
	local length = if horizontal then math.abs(x2 - x1) else math.abs(z2 - z1)
	if w >= 14 then
		for t = 40, length - 40, 55 do
			if rng:NextNumber() < 0.55 then
				local side = if rng:NextNumber() > 0.5 then 1 else -1
				local along = (if horizontal then math.min(x1, x2) else math.min(z1, z2)) + t + rng:NextNumber(-10, 10)
				local lane = side * (w / 2 - 3.2)
				local x = if horizontal then along else x1 + lane
				local z = if horizontal then z1 + lane else along
				if not inSchoolZone(x, z) and math.abs(z - 420) > 36 then
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
			local colors = { "FFE9F0", "D6F0FF", "E3F8D8", "FFE2C9", "F3DCFF" }
			local rig = RigFactory.Create("คนเดินถนน", pos + Vector3.new(0, 3, 0), npcFolder, nil, hex(colors[rng:NextInteger(1, #colors)]))
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
			if nearest < d.Radius + 120 and #spawned[d.Id] == 0 then
				task.spawn(spawnPedestrians, d)
			elseif nearest > d.Radius + 380 and #spawned[d.Id] > 0 then
				despawn(d.Id)
			end
		end
	end
end)
