--!strict
-- แสงยามค่ำคืนแบบมหานคร: เสาไฟริมถนนเพิ่มตามถนนสายหลัก/รอง (ทุก ~35 studs ต่อสองฝั่ง) พร้อมแอ่งแสงบนถนน,
-- ไฟสัญญาณเตือนอากาศยานสีแดงบนตึกสูง, ป้ายนีออนบนดาดฟ้าหลากสี
-- ชิ้นส่วนไฟเปิด/ปิดตามเวลาโดยสคริปต์ฝั่งผู้เล่น (NightLights.client): LampLight / LampPool / BeaconLight / BeaconBulb
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.World)
local BK = require(script.Parent.BuildKit)
local LotGen = require(script.Parent.LotGen)

local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end
local BuildSync = require(script.Parent.BuildSync)
local __t0 = os.clock()

local rng = Random.new(777) -- สตรีมแยก ไม่กระทบการสุ่มของ builder อื่น
local hex = Color3.fromHex
local root = Instance.new("Folder")
root.Name = "NightCity"
root.Parent = worldFolder

local MAX_LAMPS = 480
local LAMP_COLORS = { hex("FFD9A0"), hex("FFE2B0"), hex("FFCF8A"), hex("F4F0DC") } -- โทนโซเดียมอุ่น + ขาวนวลบางต้น

local function inSchool(x: number, z: number): boolean
	return x > -228 and x < 228 and z > -188 and z < 348
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { worldFolder:FindFirstChild("Roads") or worldFolder, worldFolder:FindFirstChild("Sidewalks") or worldFolder }

local function groundY(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 12, z), Vector3.new(0, -30, 0), rayParams)
	return if hit then hit.Position.Y else 0.3
end

---------------------------------------------------------------- เสาไฟริมถนน
local lampFolder = Instance.new("Folder")
lampFolder.Name = "StreetLamps"
lampFolder.Parent = root
local lampCount = 0

-- (x, z) = ตำแหน่งเสา, (dx, dz) = ทิศชี้เข้าหากลางถนน
local function placeLamp(x: number, z: number, dx: number, dz: number)
	local color = LAMP_COLORS[rng:NextInteger(1, #LAMP_COLORS)]
	local gy = groundY(x, z)
	local f = Instance.new("Model")
	f.Name = "NightLamp"
	BK.noCollide(BK.cylinder("PoleBase", 0.9, 0.8, Vector3.new(x, gy + 0.4, z), hex("34363C"), f, Enum.Material.Metal))
	local pole = BK.cylinder("Pole", 0.34, 14.4, Vector3.new(x, gy + 7.6, z), hex("2A2C32"), f, Enum.Material.Metal)
	pole.CanCollide = false
	local ax, az = x + dx * 2.2, z + dz * 2.2
	local arm = BK.part("LampArm", Vector3.new(math.abs(dx) * 4.4 + 0.3, 0.3, math.abs(dz) * 4.4 + 0.3), Vector3.new(x + dx * 1.1, gy + 14.9, z + dz * 1.1), hex("2A2C32"), f, Enum.Material.Metal)
	BK.noCollide(arm)
	local bulb = BK.part("Bulb", Vector3.new(1.5, 0.35, 1.5), Vector3.new(ax, gy + 14.6, az), color, f, Enum.Material.Neon)
	BK.noCollide(bulb)
	local l = Instance.new("PointLight")
	l.Name = "LampLight"
	l.Color, l.Range, l.Brightness = color, 34, 1.5
	l.Shadows = false
	l.Parent = bulb
	-- แอ่งแสงบนถนน (แผ่นแบนนีออนโปร่งใส เปิดตอนกลางคืนฝั่งผู้เล่น)
	local pool = BK.part("LampPool", Vector3.new(0.1, 26, 26), Vector3.new(x + dx * 6, gy + 0.12, z + dz * 6), color, f, Enum.Material.Neon)
	pool.Shape = Enum.PartType.Cylinder
	pool.CFrame = CFrame.new(x + dx * 6, gy + 0.12, z + dz * 6) * CFrame.Angles(0, 0, math.pi / 2)
	pool.Transparency = 1
	pool.CastShadow = false
	BK.noCollide(pool)
	f.Parent = lampFolder
	lampCount += 1
end

local sidesOffset = 0
for i, r in World.Roads do
	local w, kind = r[5], r[6]
	if kind == "T" or w < 10 or lampCount >= MAX_LAMPS then
		continue
	end
	local horizontal = math.abs(r[3] - r[1]) >= math.abs(r[4] - r[2])
	local fixed = if horizontal then r[2] else r[1]
	local step = if w >= 14 then 70 else 80 -- ต่อฝั่ง; สองฝั่งสลับกันจึงห่างกันจริง ~35-40
	for k, side in { -1, 1 } do
		local off = side * (w / 2 + 0.9)
		for _, iv in World.FreeIntervals(i, off) do
			local t = iv[1] + 8 + (if k == 2 then step / 2 else 0) + rng:NextNumber(0, 6)
			while t < iv[2] - 8 and lampCount < MAX_LAMPS do
				local x = if horizontal then t else fixed + off
				local z = if horizontal then fixed + off else t
				if not inSchool(x, z) and not LotGen.Hit(x, z, 1.5) then
					placeLamp(x, z, if horizontal then 0 else -side, if horizontal then -side else 0)
				end
				t += step
			end
		end
	end
	sidesOffset += 1
	if sidesOffset % 8 == 0 then
		task.wait()
	end
end

---------------------------------------------------------------- ตึกสูง: ไฟเตือนบนดาดฟ้า + ป้ายนีออน
local beaconFolder = Instance.new("Folder")
beaconFolder.Name = "Beacons"
beaconFolder.Parent = root
local signFolder = Instance.new("Folder")
signFolder.Name = "RoofSigns"
signFolder.Parent = root

local NEON = { hex("FF4FA3"), hex("4FE0FF"), hex("FF4A4A"), hex("5CFF8A"), hex("FFF2C8"), hex("FFB347") }
local WORDS = { "ホテル", "HOTEL", "BAR", "カラオケ", "ゲーム", "24H", "酒場", "CLUB", "SUSU", "ラーメン", "薬局", "TOKYO" }

local tall, beacons, signs = {}, 0, 0
for _, b in worldFolder.Buildings:GetChildren() do
	local walls = b:FindFirstChild("Walls")
	if walls and walls:IsA("BasePart") and walls.Size.Y >= 38 then
		table.insert(tall, walls)
	end
end
table.sort(tall, function(a, c)
	return a.Size.Y > c.Size.Y
end)
for idx, walls in tall do
	local top = walls.Position.Y + walls.Size.Y / 2
	local cx, cz = walls.Position.X, walls.Position.Z
	if walls.Size.Y >= 50 or idx <= 40 then
		-- ไฟเตือนแดงกะพริบช้า ๆ (ฝั่งผู้เล่นคุมจังหวะ)
		local mast = BK.cylinder("BeaconMast", 0.4, 5, Vector3.new(cx, top + 2.9, cz), hex("2A2C32"), beaconFolder, Enum.Material.Metal)
		BK.noCollide(mast)
		local bulb = BK.ball("BeaconBulb", 1.8, Vector3.new(cx, top + 5.6, cz), hex("FF2A2A"), beaconFolder, Enum.Material.Neon)
		BK.noCollide(bulb)
		local l = Instance.new("PointLight")
		l.Name = "BeaconLight"
		l.Color, l.Range, l.Brightness = hex("FF3030"), 24, 2
		l.Shadows = false
		l.Parent = bulb
		beacons += 1
	elseif rng:NextNumber() < 0.55 and signs < 60 then
		-- ป้ายนีออนบนดาดฟ้า หันหน้า ±Z (อ่านได้จากถนน)
		local width = math.clamp(walls.Size.X * 0.85, 6, 12)
		local color = NEON[rng:NextInteger(1, #NEON)]
		local word = WORDS[rng:NextInteger(1, #WORDS)]
		local y = top + 3.4
		for _, dz in { -1, 1 } do
			local face = BK.part("RoofSign", Vector3.new(width, 3, 0.4), Vector3.new(cx, y, cz), hex("17181C"), signFolder, Enum.Material.Metal)
			BK.noCollide(face)
			face.CFrame = CFrame.new(cx, y, cz + dz * 0.02) * CFrame.Angles(0, if dz == 1 then math.pi else 0, 0)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.LightInfluence = 0
			gui.Brightness = 2
			gui.Parent = face
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = word
			label.TextColor3 = color
			label.Font = Enum.Font.SourceSansBold
			label.TextScaled = true
			label.Parent = gui
		end
		local rim = BK.part("RoofSignRim", Vector3.new(width + 0.6, 3.6, 0.2), Vector3.new(cx, y, cz), color:Lerp(Color3.new(0, 0, 0), 0.35), signFolder, Enum.Material.Neon)
		BK.noCollide(rim)
		for _, lx in { -width / 2 + 0.5, width / 2 - 0.5 } do
			BK.noCollide(BK.box("RoofSignLeg", cx + lx - 0.15, cx + lx + 0.15, top, top + 1.8, cz - 0.15, cz + 0.15, hex("2A2C32"), signFolder, Enum.Material.Metal))
		end
		local l = Instance.new("PointLight")
		l.Name = "SignGlow"
		l.Color, l.Range, l.Brightness = color, 20, 1
		l.Shadows = false
		l.Parent = rim
		signs += 1
	end
end

worldFolder:SetAttribute("NightLamps", lampCount)
print(`[NightCity] เสาไฟ {lampCount}, ไฟเตือนตึกสูง {beacons}, ป้ายดาดฟ้า {signs}`)
BuildSync.finish("NightCity", __t0)
