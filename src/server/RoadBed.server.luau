--!strict
-- ใต้ถนน/ทางเท้าเป็นดินหญ้า → ใบหญ้า (Terrain decoration) แทงทะลุแผ่นถนนบางๆ: เปลี่ยนวัสดุ Terrain ใต้แผ่นเป็น Pavement (ไม่มีหญ้า)
local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end
local BuildSync = require(script.Parent.BuildSync)
local __t0 = os.clock()

local terrain = workspace.Terrain
local count = 0

local function bed(folder: Instance, onlyName: string?)
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") and (onlyName == nil or p.Name == onlyName) then
			local s, c = p.Size, p.Position
			local region = Region3.new(Vector3.new(c.X - s.X / 2, -4, c.Z - s.Z / 2), Vector3.new(c.X + s.X / 2, 4, c.Z + s.Z / 2)):ExpandToGrid(4)
			terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Pavement)
			count += 1
			if count % 120 == 0 then
				task.wait()
			end
		end
	end
end

-- ถนนต่างสี (ต่างชนิด) ที่ทับกันตรงสี่แยกมีผิวบนระดับเดียวกัน (0.30) → z-fighting กะพริบ: ลดผิวลงชิ้นละ 0.004 ตามลำดับสี (แพตช์/เส้นอยู่ที่ 0.315 ยังอยู่เหนือ)
do
	local rank: { [string]: number } = {}
	local nextRank = 0
	for _, p in worldFolder:WaitForChild("Roads"):GetChildren() do
		if p:IsA("BasePart") and p.Name == "Road" then
			local key = p.Color:ToHex() .. p.Material.Name
			if not rank[key] then
				rank[key] = nextRank
				nextRank += 1
			end
			p.Position -= Vector3.new(0, rank[key] * 0.004, 0)
		end
	end
end

-- ทางเท้าต่างสีที่ซ้อนกันตามมุม (Pave/Pave) ก็ผิวบนเท่ากัน (0.45): ลดตามลำดับสีเช่นเดียวกัน
do
	local rank: { [string]: number } = {}
	local nextRank = 0
	for _, p in worldFolder:WaitForChild("Sidewalks"):GetChildren() do
		if p:IsA("BasePart") and p.Name == "Pave" then
			local key = p.Color:ToHex() .. p.Material.Name
			if not rank[key] then
				rank[key] = nextRank
				nextRank += 1
			end
			p.Position -= Vector3.new(0, math.min(rank[key], 7) * 0.003, 0)
		end
	end
end

bed(worldFolder:WaitForChild("Roads"), "Road")
bed(worldFolder:WaitForChild("Sidewalks"), nil)
print(string.format("[RoadBed] ปรับวัสดุใต้ถนน/ทางเท้า %d ชิ้น", count))
BuildSync.finish("RoadBed", __t0)
