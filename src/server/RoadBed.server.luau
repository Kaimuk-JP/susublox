--!strict
-- ใต้ถนน/ทางเท้าเป็นดินหญ้า → ใบหญ้า (Terrain decoration) แทงทะลุแผ่นถนนบางๆ: เปลี่ยนวัสดุ Terrain ใต้แผ่นเป็น Pavement (ไม่มีหญ้า)
local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end

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

bed(worldFolder:WaitForChild("Roads"), "Road")
bed(worldFolder:WaitForChild("Sidewalks"), nil)
print(string.format("[RoadBed] ปรับวัสดุใต้ถนน/ทางเท้า %d ชิ้น", count))
