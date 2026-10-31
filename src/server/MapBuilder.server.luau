--!strict
-- สร้างแมพ greybox ตามขนาดในแผน เพื่อทดสอบการต่อสู้ก่อนมีงานโมเดลจริง
-- (แทนที่ด้วยแมพจริงภายหลังโดยไม่เปลี่ยนขนาดพื้นที่)
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local PALETTE = {
	ground = Color3.fromHex("B8C0CC"),
	wall = Color3.fromHex("FFFFFF"),
	safe = Color3.fromHex("7EC8E3"),
	arena = Color3.fromHex("FFB7C5"),
}

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

local function block(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or map
	return p
end

-- โซน: ชื่อ, ขนาด(x,z), ศูนย์กลาง(x,z), สี
local zones = {
	{ "SchoolYard", Vector2.new(160, 120), Vector2.new(0, 0), PALETTE.safe },
	{ "Cafeteria", Vector2.new(60, 50), Vector2.new(-130, 0), PALETTE.ground },
	{ "Gym", Vector2.new(100, 70), Vector2.new(130, 0), PALETTE.ground },
	{ "BackLot", Vector2.new(60, 40), Vector2.new(0, 110), PALETTE.ground },
}

for _, z in zones do
	local name, size, center, color = z[1], z[2], z[3], z[4]
	local floor = block(name, Vector3.new(size.X, 2, size.Y), Vector3.new(center.X, -1, center.Y), color)
	CollectionService:AddTag(floor, "Outline")
end

-- อาคารเรียน 3 ชั้น: ชั้นละสูง 16 ทางเดินกว้าง 15
local building = Instance.new("Folder")
building.Name = "Building"
building.Parent = map
for floorIndex = 1, 3 do
	local y = (floorIndex - 1) * 16
	block(`Floor{floorIndex}`, Vector3.new(120, 1, 40), Vector3.new(0, y + 16, -90), PALETTE.wall, building)
	block(`Corridor{floorIndex}`, Vector3.new(120, 0.2, 15), Vector3.new(0, y + 16.6, -90), PALETTE.ground, building)
end

-- ดาดฟ้า 80x60: อารีน่า PvP หลัก
local roof = block("Rooftop", Vector3.new(80, 1, 60), Vector3.new(0, 48, -90), PALETTE.arena)
CollectionService:AddTag(roof, "Outline")
for _, side in { -1, 1 } do
	block("RoofRailX", Vector3.new(80, 3, 1), Vector3.new(0, 50, -90 + side * 30), PALETTE.wall)
	block("RoofRailZ", Vector3.new(1, 3, 60), Vector3.new(side * 40, 50, -90), PALETTE.wall)
end

-- จุดเกิดอยู่สนามหน้าโรงเรียน (โซนปลอดภัย)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 0.5, 0)
spawn.Neutral = true
spawn.Parent = map

-- โซนปลอดภัย: ตั้ง Attribute ให้ระบบต่อสู้อ่าน
local safe = block("SafeZone", Vector3.new(160, 30, 120), Vector3.new(0, 14, 0), PALETTE.safe)
safe.Transparency = 1
safe.CanCollide = false
safe.CanQuery = false
safe:SetAttribute("SafeZone", true)

-- บรรยากาศพาสเทล
local atmosphere = Instance.new("Atmosphere")
atmosphere.Color = Color3.fromHex("FFE9F0")
atmosphere.Density = 0.25
atmosphere.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.3
bloom.Parent = Lighting
Lighting.ClockTime = 14

-- โฟลเดอร์ NPC และ NPC ทดสอบหลังโรงเรียน
local npcs = Instance.new("Folder")
npcs.Name = "Npcs"
npcs.Parent = workspace

local function spawnDummy(position: Vector3, level: number, boss: boolean)
	local ok, desc = pcall(function()
		return game:GetService("Players"):GetHumanoidDescriptionFromUserId(1)
	end)
	local rig = if ok and desc then game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) else nil
	if not rig then
		return
	end
	rig.Name = if boss then "Boss" else "Gangster"
	rig:SetAttribute("NpcLevel", level)
	rig:SetAttribute("IsBoss", boss)
	rig:PivotTo(CFrame.new(position))
	rig.Parent = npcs
end

task.spawn(function()
	for i = 1, 4 do
		spawnDummy(Vector3.new(-15 + i * 8, 4, 110), 1, false)
	end
end)
