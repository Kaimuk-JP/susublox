--!strict
-- ผังเมืองซูซูฮาระรุ่นใหม่: แม่น้ำคิโซ (z=420) + สะพาน 3 แห่ง + ริมตลิ่ง, หอคอยซูซู (จุดสังเกต), สถานีรถไฟแทนหินเดินทาง
-- รันหลัง WorldBuilder สร้างโลกเสร็จ (World.Built) ใช้พิกัดจาก World.luau (ขอบโลก/ถนน)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.World)
local BK = require(script.Parent.BuildKit)

local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end

local hex = Color3.fromHex
local terrain = workspace.Terrain
local f = Instance.new("Folder")
f.Name = "CityDressing"
f.Parent = worldFolder

local B = World.Bounds
local RIVER_Z, RIVER_W = 420, 40
local BRIDGE_X = { -370, -90, 570 }
local width = B.MaxX - B.MinX
local cx = (B.MinX + B.MaxX) / 2

---------------------------------------------------------------- แม่น้ำคิโซ: ขุดดิน ใส่ทราย แล้วเติมน้ำ
terrain:FillBlock(CFrame.new(cx, -6, RIVER_Z), Vector3.new(width, 12, RIVER_W), Enum.Material.Air)
terrain:FillBlock(CFrame.new(cx, -8, RIVER_Z), Vector3.new(width, 8, RIVER_W), Enum.Material.Sand)
terrain:FillBlock(CFrame.new(cx, -2.4, RIVER_Z), Vector3.new(width, 4.8, RIVER_W), Enum.Material.Water)

-- ต้นสนฉากหลังของโรงเรียน (MapBuilder) ที่บังเอิญตกอยู่กลางแม่น้ำ ให้เอาออก
local mapFolder = workspace:FindFirstChild("Map")
local scenery = mapFolder and mapFolder:FindFirstChild("Scenery")
if scenery then
	for _, c in scenery:GetChildren() do
		if (c.Name == "PineTrunk" or c.Name == "PineLeaves") and c:IsA("BasePart") and math.abs(c.Position.Z - RIVER_Z) < RIVER_W / 2 + 6 then
			c:Destroy()
		end
	end
end

---------------------------------------------------------------- ตลิ่ง: กำแพงเตี้ยหินริมน้ำ เว้นช่องสะพาน + เสาไฟริมตลิ่งฝั่งใต้
local function nearBridge(x: number, margin: number): boolean
	for _, bx in BRIDGE_X do
		if math.abs(x - bx) < margin then
			return true
		end
	end
	return false
end

for _, side in { -1, 1 } do
	local z = RIVER_Z + side * (RIVER_W / 2 + 0.8)
	local x = B.MinX + 5
	while x < B.MaxX - 10 do
		local segmentEnd = math.min(x + 10, B.MaxX - 5)
		if not nearBridge(x + 5, 13) then
			BK.box("Embankment", x, segmentEnd, 0, 1.4, z - 0.8, z + 0.8, hex("B5B8C2"), f, Enum.Material.Concrete)
			BK.box("EmbankmentCap", x - 0.1, segmentEnd + 0.1, 1.4, 1.8, z - 1.1, z + 1.1, hex("8F8A7F"), f, Enum.Material.Concrete)
		end
		x = segmentEnd
	end
end
for lampX = B.MinX + 40, B.MaxX - 40, 60 do
	if not nearBridge(lampX, 16) then
		BK.lamp(f, lampX, RIVER_Z + RIVER_W / 2 + 6, hex("FFD9A0"))
	end
end

---------------------------------------------------------------- สะพาน 3 แห่ง
for _, bx in BRIDGE_X do
	local z1, z2 = RIVER_Z - RIVER_W / 2 - 3, RIVER_Z + RIVER_W / 2 + 3
	BK.box("BridgeDeck", bx - 8, bx + 8, 0, 0.5, z1, z2, hex("8E94A3"), f, Enum.Material.Concrete)
	BK.box("BridgeRoad", bx - 7, bx + 7, 0.5, 0.58, z1, z2, hex("4A4D5C"), f, Enum.Material.Asphalt)
	for _, side in { -1, 1 } do
		local rx = bx + side * 8
		BK.box("BridgeRail", rx - 0.3, rx + 0.3, 0.5, 3.2, z1, z2, hex("D9D2C4"), f, Enum.Material.Concrete)
		BK.box("BridgeRailTop", rx - 0.5, rx + 0.5, 3.2, 3.6, z1, z2, hex("2B2D42"), f, Enum.Material.Metal)
	end
	for k = 0, 3 do
		local pz = z1 + (z2 - z1) * (k / 3)
		for _, side in { -1, 1 } do
			local lamp = BK.ball("BridgeLamp", 1.4, Vector3.new(bx + side * 8, 5.4, pz), hex("FFE066"), f, Enum.Material.Neon)
			BK.light(lamp, hex("FFE066"), 22, 1)
			BK.cylinder("BridgeLampPole", 0.2, 4, Vector3.new(bx + side * 8, 2.6, pz), hex("2B2D42"), f)
		end
	end
	-- เสาสะพานลงน้ำ
	for _, pz in { RIVER_Z - 10, RIVER_Z + 10 } do
		for _, side in { -1, 1 } do
			BK.cylinder("BridgePier", 0.9, 8, Vector3.new(bx + side * 6, -3.5, pz), hex("8E94A3"), f, Enum.Material.Concrete)
		end
	end
	BK.sign(f, "สะพาน", Vector3.new(7, 1.6, 0.3), Vector3.new(bx, 7.5, z1 - 0.5), 0, hex("2B2D42"), hex("FFE066"))
end

---------------------------------------------------------------- หอคอยซูซู: จุดสังเกตที่เห็นได้จากทั้งเมือง (ฝั่งใต้ของแม่น้ำ)
do
	local tx, tz = 40, 500
	BK.cylinder("TowerPlaza", 24, 0.5, Vector3.new(tx, 0.3, tz), hex("F1E4D3"), f, Enum.Material.Concrete)
	BK.box("TowerBase", tx - 8, tx + 8, 0, 8, tz - 8, tz + 8, hex("E8E4DC"), f, Enum.Material.Concrete)
	BK.cylinder("TowerShaft", 4.2, 72, Vector3.new(tx, 44, tz), hex("F7F1E5"), f, Enum.Material.Concrete)
	BK.cylinder("TowerShaftBand", 4.6, 1.2, Vector3.new(tx, 30, tz), hex("EF233C"), f)
	BK.cylinder("TowerShaftBand", 4.6, 1.2, Vector3.new(tx, 56, tz), hex("EF233C"), f)
	BK.cylinder("ObservationDeck", 11, 4, Vector3.new(tx, 84, tz), hex("2B2D42"), f, Enum.Material.Metal)
	local ring = BK.cylinder("DeckGlass", 11.2, 2.6, Vector3.new(tx, 84, tz), hex("BFE9FF"), f, Enum.Material.Glass)
	ring.Transparency = 0.45
	local neon = BK.cylinder("DeckNeon", 11.6, 0.6, Vector3.new(tx, 86.6, tz), hex("FF4D8D"), f, Enum.Material.Neon)
	BK.light(neon, hex("FF4D8D"), 60, 1.2)
	BK.cylinder("TowerMast", 0.9, 44, Vector3.new(tx, 110, tz), hex("C9CED6"), f, Enum.Material.Metal)
	local beacon = BK.ball("TowerBeacon", 3, Vector3.new(tx, 133, tz), hex("EF233C"), f, Enum.Material.Neon)
	BK.light(beacon, hex("EF233C"), 90, 1.8)
	BK.sign(f, "SUSU TOWER", Vector3.new(14, 3, 0.4), Vector3.new(tx, 12, tz - 8.4), 0, hex("2B2D42"), hex("FFE066"))
end

---------------------------------------------------------------- สถานีรถไฟประจำย่าน (แทนหินเดินทาง; จุดเทเลพอร์ตเดิม StonePos ไม่เปลี่ยน)
local districtsFolder = worldFolder:FindFirstChild("Districts")
if districtsFolder then
	for _, d in World.Districts do
		local folder = districtsFolder:FindFirstChild(d.Id)
		local stonePos = folder and folder:GetAttribute("StonePos")
		if folder and typeof(stonePos) == "Vector3" then
			for _, name in { "TravelStone", "TravelCrystal", "StoneSign" } do
				for _, child in folder:GetChildren() do
					if child.Name == name then
						child:Destroy()
					end
				end
			end
			local px, pz = stonePos.X, stonePos.Z - 6 -- StonePos ถูกตั้งไว้ที่ z+6 ของฐานเดิม
			BK.box("StationPlatform", px - 8, px + 8, 0, 0.9, pz - 3.5, pz + 3.5, hex("C9CED6"), folder, Enum.Material.Concrete)
			BK.box("StationEdge", px - 8, px + 8, 0.9, 1, pz + 3.1, pz + 3.5, hex("FFE066"), folder)
			for _, ox in { -7, 7 } do
				BK.cylinder("StationPost", 0.3, 8, Vector3.new(px + ox, 4.9, pz - 2.8), hex("2B2D42"), folder, Enum.Material.Metal)
			end
			BK.box("StationRoof", px - 9, px + 9, 8.8, 9.4, pz - 4.2, pz + 3.5, hex("4D7CFE"), folder, Enum.Material.Metal)
			BK.sign(folder, `สถานี{d.Name}`, Vector3.new(14, 2.2, 0.3), Vector3.new(px, 7.4, pz - 3.1), 180, hex("2B2D42"), hex("FFE066"))
			local gate = BK.ball("StationGate", 1.4, Vector3.new(px, 2.4, pz + 0.5), hex("7EC8E3"), folder, Enum.Material.Neon)
			BK.light(gate, hex("7EC8E3"), 22, 1.2)
			BK.box("StationBench", px + 3, px + 7, 1.4, 1.9, pz - 2.4, pz - 1.4, hex("9C7A54"), folder, Enum.Material.Wood)
		end
	end
end
