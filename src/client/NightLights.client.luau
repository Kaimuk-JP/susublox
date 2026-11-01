--!strict
-- ไฟยามค่ำของเมือง (ฝั่งผู้เล่นเท่านั้น เปลี่ยนเฉพาะสิ่งที่สตรีมมาใกล้ตัว ไม่สร้าง PointLight เพิ่มต่อบานหน้าต่าง):
--  * หน้าต่างตึก: ตอนเย็น/กลางคืนสุ่มคงที่ (ตามพิกัด) 35-50% เรืองแสงนีออน (ตึกสูง ~70%) สีขาวอุ่น/เหลือง/ขาวเย็น
--  * เสาไฟ (LampLight) + แอ่งแสงบนถนน (LampPool) + ไฟรถ (CarLight) เปิดเฉพาะเย็น/คืน
--  * ไฟเตือนบนตึกสูง (BeaconBulb/BeaconLight) กะพริบช้า ๆ
local RunService = game:GetService("RunService")

local WINDOW_COLORS = {
	{ 0.55, Color3.fromHex("FFC873") }, -- ขาวอุ่น/ส้มอ่อน
	{ 0.75, Color3.fromHex("FFE3A3") }, -- เหลืองนวล
	{ 0.87, Color3.fromHex("FFA94D") }, -- ส้มอำพัน
	{ 1.00, Color3.fromHex("BFDDFF") }, -- ขาวเย็น (ไฟฟลูออเรสเซนต์)
}

local mode = "Day" -- "Day" | "Evening" | "Night"
local nightFactor = 0 -- 0 กลางวัน, 0.6 เย็น, 1 คืน (สัดส่วนหน้าต่างที่เปิด)

type WinInfo = { Color: Color3, Material: Enum.Material, Transparency: number, Roll: number, Hue: Color3 }
local windows: { [BasePart]: WinInfo } = {}
local lamps: { [Instance]: boolean } = {}
local pools: { [BasePart]: boolean } = {}
local carLights: { [Instance]: boolean } = {}
local beaconBulbs: { [BasePart]: boolean } = {}
local beaconLights: { [Instance]: boolean } = {}

local function hash01(p: Vector3): number
	local h = bit32.bxor(math.floor(p.X * 7.3) * 73856093, math.floor(p.Y * 3.1) * 19349663, math.floor(p.Z * 7.3) * 83492791)
	return (h % 10007) / 10007
end

local function pickColor(r: number): Color3
	local t = (r * 7.31) % 1
	for _, e in WINDOW_COLORS do
		if t <= e[1] then
			return e[2]
		end
	end
	return WINDOW_COLORS[1][2]
end

local function applyWindow(part: BasePart, info: WinInfo)
	local ratio = nightFactor * (if part.Position.Y > 28 then 1.45 else 1) * 0.5 -- คืน 50% / ตึกสูง ~72%
	local lit = info.Roll < ratio
	if lit then
		part.Material = Enum.Material.Neon
		part.Color = info.Hue
		part.Transparency = 0
	else
		part.Material = info.Material
		part.Color = info.Color
		part.Transparency = info.Transparency
	end
end

local function register(inst: Instance)
	if not inst:IsA("BasePart") then
		if inst:IsA("PointLight") then
			if inst.Name == "LampLight" then
				lamps[inst] = true
				inst.Enabled = mode ~= "Day"
			elseif inst.Name == "CarLight" then
				carLights[inst] = true
				inst.Enabled = mode ~= "Day"
			elseif inst.Name == "BeaconLight" then
				beaconLights[inst] = true
			end
		end
		return
	end
	local name = inst.Name
	if name == "Window" then
		if inst.Material == Enum.Material.Glass then
			local roll = hash01(inst.Position)
			local info: WinInfo = { Color = inst.Color, Material = inst.Material, Transparency = inst.Transparency, Roll = roll, Hue = pickColor(roll) }
			windows[inst] = info
			if nightFactor > 0 then
				applyWindow(inst, info)
			end
		end
	elseif name == "LampPool" then
		pools[inst] = true
		inst.Transparency = if mode == "Day" then 1 else 0.86
	elseif name == "BeaconBulb" then
		beaconBulbs[inst] = true
	end
end

local function unregister(inst: Instance)
	windows[inst :: any] = nil
	lamps[inst] = nil
	pools[inst :: any] = nil
	carLights[inst] = nil
	beaconBulbs[inst :: any] = nil
	beaconLights[inst] = nil
end

local function setMode(tod: string)
	mode = if tod == "Night" then "Night" elseif tod == "Evening" then "Evening" else "Day"
	nightFactor = if mode == "Night" then 1 elseif mode == "Evening" then 0.75 else 0
	for l in lamps do
		(l :: PointLight).Enabled = mode ~= "Day"
	end
	for l in carLights do
		(l :: PointLight).Enabled = mode ~= "Day"
	end
	for p in pools do
		p.Transparency = if mode == "Day" then 1 else 0.86
	end
	-- หน้าต่างหลายพันบาน: ทำทีละชุดต่อเฟรม
	task.spawn(function()
		local snapshot = mode
		local n = 0
		for part, info in windows do
			if mode ~= snapshot then
				return
			end
			if part.Parent then
				applyWindow(part, info)
			end
			n += 1
			if n % 400 == 0 then
				RunService.Heartbeat:Wait()
			end
		end
	end)
end

workspace.DescendantAdded:Connect(register)
workspace.DescendantRemoving:Connect(unregister)
task.spawn(function()
	local n = 0
	for _, d in workspace:GetDescendants() do
		register(d)
		n += 1
		if n % 3000 == 0 then
			RunService.Heartbeat:Wait()
		end
	end
end)

setMode((workspace:GetAttribute("TimeOfDay") :: string?) or "Day")
workspace:GetAttributeChangedSignal("TimeOfDay"):Connect(function()
	setMode((workspace:GetAttribute("TimeOfDay") :: string?) or "Day")
end)

-- ไฟเตือนกะพริบช้า: ติด 0.5 วิ ทุก 2 วิ (เฉพาะกลางคืน/เย็น)
task.spawn(function()
	while true do
		local on = mode ~= "Day" and (os.clock() % 2) < 0.5
		for b in beaconBulbs do
			b.Material = if on then Enum.Material.Neon else Enum.Material.Metal
			b.Color = if on then Color3.fromHex("FF2A2A") else Color3.fromHex("5A1414")
		end
		for l in beaconLights do
			(l :: PointLight).Enabled = on
		end
		task.wait(0.25)
	end
end)
