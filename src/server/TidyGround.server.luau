--!strict
-- โรงเรียนและย่านเมือง (ตลาด/สถานี/คุโรกาเนะ/ท่าเรือ) ไม่ควรมีหญ้าป่ารก: Terrain Decoration (ใบหญ้าสูง 3-4 stud) ขึ้นเฉพาะวัสดุ Grass/LeafyGrass
-- เปลี่ยนผิว Terrain ในโซนเหล่านี้เป็น Pavement (ไม่มีใบหญ้า) เหมือน RoadBed; สวนซากุระ ค่ายป่า ศาลเจ้าบนเนิน และพื้นที่นอกเมืองยังเป็นหญ้า
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(ReplicatedStorage.Shared.World)
local BuildSync = require(script.Parent.BuildSync)

local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end
local __t0 = os.clock()

local terrain = workspace.Terrain
local STRIP = 8
local calls = 0

local function strip(x1: number, x2: number, z1: number, z2: number)
	local region = Region3.new(Vector3.new(x1, -12, z1), Vector3.new(x2, 8, z2)):ExpandToGrid(4)
	terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Pavement)
	terrain:ReplaceMaterial(region, 4, Enum.Material.LeafyGrass, Enum.Material.Pavement)
	calls += 1
	if calls % 40 == 0 then
		task.wait()
	end
end

-- ลานโรงเรียนทั้งบริเวณ (ห้องอาหาร x=-160 ถึงยิม x=180 + หลังโรงเรียน/สนามรบ)
for z = -135, 145, STRIP do
	strip(-175, 195, z, z + STRIP)
end

local URBAN = { Shotengai = true, Downtown = true, Kurogane = true, Docks = true }
for _, d in World.Districts do
	if URBAN[d.Id] then
		local c, r = d.Center, d.Radius
		for z = c.Z - r, c.Z + r - 1, STRIP do
			local dz = math.min(math.abs(z - c.Z), math.abs(z + STRIP - c.Z))
			local half = math.sqrt(math.max(r * r - dz * dz, 0))
			strip(c.X - half, c.X + half, z, z + STRIP)
		end
	end
end

print(string.format("[TidyGround] %d strips", calls))
BuildSync.finish("TidyGround", __t0)
