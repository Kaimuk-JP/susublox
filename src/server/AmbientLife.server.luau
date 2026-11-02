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
-- คนขี่นั่งบนมอเตอร์ไซค์ (ตำแหน่งสะโพกอ่านจาก Attribute RiderY/RiderZ ของโมเดลต้นฉบับ แกนหน้ารถ -Z) ถูก weld เข้ากับตัวรถ ไม่ชน ลบพร้อมรถ
local function addRider(model: Model, primary: BasePart, src: Instance, s: number)
	local y, z, pose = src:GetAttribute("RiderY"), src:GetAttribute("RiderZ"), src:GetAttribute("RiderPose")
	if type(y) ~= "number" or type(z) ~= "number" then
		return
	end
	local rider = RigFactory.CreateRider(model, if type(pose) == "string" then pose else "scooter")
	if not rider then
		return
	end
	rider:PivotTo(model:GetPivot() * CFrame.new(0, y * s, z * s)) -- ตำแหน่งสะโพกอ่านจากโมเดลต้นฉบับ คูณสเกลรถ (คนขี่สเกลตาม CharScale จาก RigFactory เอง)
	local root = rider:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = primary, root
		w.Parent = root
	end
end

-- โมเดลนำเข้าปิด CanQuery ไว้ raycast เลยมองไม่เห็นตัวถัง: เปิดชั่วคราวตอนสแกนแล้วคืนค่าเดิม
local function enableQuery(parts: { BasePart }): () -> ()
	local saved = {}
	for _, p in parts do
		saved[p] = p.CanQuery
		p.CanQuery = true
	end
	return function()
		for p, v in saved do
			p.CanQuery = v
		end
	end
end

-- ชิ้นกระจกที่โมเดลนำเข้าทาสีทึบ: สีเข้มมาก, ไม่ใช่เปลือกตัวถังทั้งคัน (สูงไม่เกิน 55% ของรถ) และอยู่ในครึ่งบนของรถ
local function isDarkWindowPart(part: BasePart, size: Vector3, groundY: number): boolean
	local c = part.Color
	local lum = c.R * 0.3 + c.G * 0.59 + c.B * 0.11
	return lum < 0.16
		and part.Size.Y < size.Y * 0.55
		and part.Size.Magnitude > 1.2
		and part.Position.Y - groundY > size.Y * 0.55
end

-- หาแนวหน้าต่างด้านข้างฝั่งคนขับด้วย raycast ตามแนวนอนที่ความสูงต่าง ๆ: ช่วงที่รังสีทะลุตัวรถ (ชิ้นโปร่งใส >= 0.5 ถือว่ามองทะลุ) = ช่องกระจก
-- คืน (ขอบล่าง, ขอบบน) เหนือพื้นเป็น studs หรือ nil ถ้าตัวถังทึบ (เช่นโมเดลก้อนเดียวที่หน้าต่างเป็นแค่ texture)
local function findWindowBand(model: Model, pivot: CFrame, local0: Vector3, size: Vector3, zLocal: number): (number?, number?)
	local solid = {}
	local groundY = (pivot * local0).Y
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and d.Transparency < 0.5
			and d.Name ~= "Collider"
			and d.Name ~= "Mover"
			and not isDarkWindowPart(d, size, groundY)
		then
			table.insert(solid, d)
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = solid
	local restore = enableQuery(solid)
	local out = size.X / 2 + 0.6
	local dir = -pivot.RightVector * (size.X + 1.2)
	local bestLo, bestHi, runLo = nil, nil, nil
	local step = size.Y * 0.03
	local y = size.Y * 0.35
	while y <= size.Y + step do
		local origin = (pivot * CFrame.new(local0.X + out, local0.Y + y, zLocal)).Position
		local hit = workspace:Raycast(origin, dir, rp)
		local open = y <= size.Y and (hit == nil or hit.Distance > 1.6) -- ชนเฉพาะเปลือกนอกฝั่งใกล้ (ราว 1 stud แรก) ไม่นับเบาะ/ของภายในห้อง
		if open then
			runLo = runLo or y
		elseif runLo then
			if not bestLo or (y - runLo) > (bestHi :: number) - bestLo then
				bestLo, bestHi = runLo, y - step
			end
			runLo = nil
		end
		y += step
	end
	restore()
	if bestLo and bestHi and bestHi - bestLo >= size.Y * 0.1 then
		return bestLo, bestHi
	end
	return nil, nil
end

-- ช่วงห้องโดยสารตามแนวยาวรถ (หน้ารถ = -Z): ยิง raycast ลงจากเหนือรถ ตำแหน่งไหนมีหลังคา/กระจกสูงเกิน 78% ของรถถือว่าเป็นห้องโดยสาร
-- (ไม่งั้นช่วงเหนือฝากระโปรงที่โล่งจะถูกมองเป็นช่องกระจก แล้วคนขับไปลอยเหนือรถ)
local function cabinRange(model: Model, pivot: CFrame, local0: Vector3, size: Vector3, x: number): (number?, number?, number)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "Collider" and d.Name ~= "Mover" then
			table.insert(parts, d)
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = parts
	local restore = enableQuery(parts)
	local groundY = (pivot * local0).Y
	local zMin, zMax, roofTop = nil, nil, 0
	local zf = -0.5
	while zf <= 0.5 do
		local z = local0.Z + size.Z * zf
		local origin = (pivot * CFrame.new(x, local0.Y + size.Y + 1, z)).Position
		local hit = workspace:Raycast(origin, Vector3.new(0, -(size.Y + 2), 0), rp)
		if hit and hit.Position.Y - groundY >= size.Y * 0.78 then
			zMin = zMin or z
			zMax = z
			roofTop = math.max(roofTop, hit.Position.Y - groundY)
		end
		zf += 0.02
	end
	restore()
	return zMin, zMax, roofTop
end

-- เลือกจุดนั่ง: นั่งที่ ~30% ของห้องโดยสารนับจากหน้า (แถวหน้า) แล้ววัดแนวกระจกข้างตรงจุดนั้น (ต้องโปร่งทั้ง -0.45/0/+0.45 stud ไม่ให้หัวไปหลบหลังเสา)
-- ผลวัดเก็บเป็นสัดส่วนของขนาดรถ แคชตามชื่อโมเดลต้นฉบับ (โมเดลเดียวกันสเกลเท่ากันเสมอ) จึงยิง raycast แค่ครั้งแรกของแต่ละรุ่น
local seatCache: { [string]: any } = {}

local function findSeat(model: Model, pivot: CFrame, local0: Vector3, size: Vector3): (number?, number?, number)
	local key = model:GetAttribute("Src")
	local cached = if type(key) == "string" then seatCache[key] else nil
	if cached then
		return cached.lo and cached.lo * size.Y, cached.hi and cached.hi * size.Y, local0.Z + cached.z * size.Z
	end
	local zMin, zMax, roofTop = cabinRange(model, pivot, local0, size, local0.X + size.X * 0.17)
	local z, lo, hi = local0.Z - size.Z * 0.06, nil, nil
	-- ตัวถังก้อนเดียวที่หน้าต่างเป็นแค่ texture (ไม่มีชิ้นกระจก/โปร่งแสง/กระจกสีทึบเลย) raycast วัดช่องกระจกไม่ได้: ถือเป็นตัวถังทึบ
	local groundY = (pivot * local0).Y
	local hasGlass = false
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Collider" and d.Name ~= "Mover" and d.Size.Magnitude > 1.2 then
			if
				d.Material == Enum.Material.Glass
				or (d.Transparency > 0.05 and d.Transparency < 0.95)
				or isDarkWindowPart(d, size, groundY)
			then
				hasGlass = true
				break
			end
		end
	end
	if zMin and zMax then
		z = zMin + (zMax - zMin) * 0.25 -- ค่าเริ่มต้นถ้าวัดช่องกระจกไม่ได้: แถวหน้าสุดของห้องโดยสาร (ตรงพวงมาลัย)
	end
	if zMin and zMax and hasGlass then
		local bestScore = -1
		for _, frac in { 0.18, 0.24, 0.3, 0.36, 0.42 } do
			local zc = zMin + (zMax - zMin) * frac
			local l, h = 0, math.min(size.Y, roofTop - 0.25) -- เหนือหลังคาโล่งเหมือนกัน ต้องไม่นับเป็นช่องกระจก
			local ok = true
			for _, dz in { -0.4, 0, 0.4 } do
				local bl, bh = findWindowBand(model, pivot, local0, size, zc + dz)
				if bl and bh then
					l, h = math.max(l, bl), math.min(h, bh)
				else
					ok = false
					break
				end
			end
			if ok and h - l >= size.Y * 0.08 then
				local score = (h - l) / size.Y - math.abs(frac - 0.3) * 0.5
				if score > bestScore then
					bestScore, z, lo, hi = score, zc, l, h
				end
			end
		end
	end
	if type(key) == "string" then
		seatCache[key] = { lo = lo and lo / size.Y, hi = hi and hi / size.Y, z = (z - local0.Z) / size.Z }
	end
	return lo, hi, z
end

-- ทำชิ้นกระจกสีทึบที่บังหัวคนขับให้โปร่งใส (ยิง raycast จากข้างรถไปที่ตำแหน่งหัว เอาเฉพาะชิ้นที่เป็นกระจกมืด ไม่แตะตัวถัง)
local function revealDriver(model: Model, pivot: CFrame, local0: Vector3, size: Vector3, zLocal: number, headY: number)
	local groundY = (pivot * local0).Y
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.5 and d.Name ~= "Collider" and d.Name ~= "Mover" then
			table.insert(parts, d)
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = parts
	local restore = enableQuery(parts)
	local dir = -pivot.RightVector * (size.X + 1.2)
	local found = {}
	for dy = -0.8, 0.8, 0.2 do
		for dz = -0.7, 0.7, 0.2 do
			local origin = (pivot * CFrame.new(local0.X + size.X / 2 + 0.6, local0.Y + headY + dy, zLocal + dz)).Position
			local hit = workspace:Raycast(origin, dir, rp)
			if hit and isDarkWindowPart(hit.Instance :: BasePart, size, groundY) then
				found[hit.Instance :: BasePart] = true
			end
		end
	end
	restore()
	for p in found do
		p.Transparency = 0.6
		p.Material = Enum.Material.Glass
	end
end

-- คนขับในรถยนต์: นั่งฝั่งขวา (รถญี่ปุ่นพวงมาลัยขวา หน้ารถ -Z) หัวอยู่กลางแนวกระจกข้างที่วัดจริงด้วย raycast
-- ย่อสเกลให้หัวไม่ทะลุหลังคา weld เข้าตัวรถ ไม่ชน ลบพร้อมรถ
-- ตัวถังทึบไม่มีช่องหน้าต่าง: ไม่ใส่คนขับ (เห็นได้ก็ต่อเมื่อตัวทะลุออกนอกรถ)
local function addDriver(model: Model, primary: BasePart)
	local cf, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local groundY = (cf.Position.Y - size.Y / 2)
	local local0 = pivot:PointToObjectSpace(Vector3.new(cf.Position.X, groundY, cf.Position.Z))
	local lo, hi, zLocal = findSeat(model, pivot, local0, size)
	revealDriver(model, pivot, local0, size, zLocal, if lo and hi then (lo + hi) / 2 else size.Y * 0.7)
	local rider = RigFactory.CreateRider(model, "car")
	if not rider then
		return
	end
	local headPart = rider:FindFirstChild("Head") :: BasePart?
	local rootPart = rider:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (headPart and rootPart) then
		rider:Destroy()
		return
	end
	local headY = size.Y * 0.7 -- ไม่เจอช่องกระจก: ใช้ค่ากลาง ๆ ของโมเดลนำเข้า
	local topLimit = size.Y * 0.96
	if lo and hi then
		headY = (lo + hi) / 2
		topLimit = math.min(topLimit, hi + 0.15)
	end
	local s = math.clamp((topLimit - headY) / (headPart.Size.Y / 2), 0.55, 1)
	local headDy = (headPart.Position.Y - rootPart.Position.Y) * s -- ระยะหัวเหนือสะโพก หลังย่อสเกล
	local hipY = headY - headDy
	rider:ScaleTo(rider:GetScale() * s)
	local x = local0.X + size.X * 0.13 -- ชิดกลางรถ แขนไม่ทะลุประตู
	local solidBody = lo == nil
	if solidBody then
		-- ตัวถังทึบ: เห็นคนขับได้ก็ต่อเมื่อให้ตัวทะลุออกนอกรถ ซึ่งดูผิดธรรมชาติ จึงไม่ใส่คนขับในรถรุ่นนี้
		rider:Destroy()
		return
	end
	local seat = pivot * CFrame.new(x, local0.Y + hipY, zLocal)
	rider:PivotTo(seat)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = primary, rootPart
	w.Parent = rootPart
end

-- ป้ายไฟแท็กซี่บนหลังคา (ไม่มีโลโก้/ตัวอักษรยี่ห้อ)
local function addTaxiLamp(model: Model, primary: BasePart, moving: boolean)
	local _, size = model:GetBoundingBox()
	local lamp = Instance.new("Part")
	lamp.Name = "TaxiLamp"
	lamp.Size = Vector3.new(1.3, 0.45, 0.7)
	lamp.Color = Color3.fromHex("F2E8B8")
	lamp.Material = Enum.Material.Neon
	lamp.CFrame = model:GetPivot() * CFrame.new(0, size.Y + 0.2, -0.3)
	lamp.CanCollide, lamp.CanQuery, lamp.CanTouch = false, false, false
	lamp.Massless = true
	lamp.Anchored = not moving
	lamp.Parent = model
	if moving then
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = primary, lamp
		w.Parent = lamp
	end
end

-- ไฟหน้าขาว/ไฟท้ายแดงของรถวิ่ง (ชิ้นนีออนเล็ก + PointLight ที่ฝั่งผู้เล่นเปิดเฉพาะกลางคืน) เชื่อมติดตัวรถ หน้ารถ = -Z
local function addCarLights(model: Model, primary: BasePart, isBike: boolean)
	local cf, size = model:GetBoundingBox()
	local xs = if isBike then { 0 } else { -size.X * 0.32, size.X * 0.32 }
	local y = -size.Y / 2 + size.Y * 0.32
	local function lamp(name: string, color: Color3, off: CFrame, ww: number)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(ww, 0.5, 0.25)
		p.Color = color
		p.Material = Enum.Material.Neon
		p.CFrame = cf * off
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.Massless = true
		p.Anchored = false
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = primary, p
		w.Parent = p
		return p
	end
	for i, x in xs do
		local head = lamp("Headlight", Color3.fromHex("FFF6D8"), CFrame.new(x, y, -size.Z / 2), if isBike then 0.7 else 1.0)
		local tail = lamp("Taillight", Color3.fromHex("FF2A2A"), CFrame.new(x, y, size.Z / 2), if isBike then 0.5 else 0.9)
		if i == 1 then
			local hl = Instance.new("PointLight")
			hl.Name = "CarLight"
			hl.Color, hl.Range, hl.Brightness = Color3.fromHex("FFF1CC"), 16, 1.2
			hl.Shadows = false
			hl.Enabled = false
			hl.Parent = head
			local tl = Instance.new("PointLight")
			tl.Name = "CarLight"
			tl.Color, tl.Range, tl.Brightness = Color3.fromHex("FF3030"), 8, 0.8
			tl.Shadows = false
			tl.Enabled = false
			tl.Parent = tail
		end
	end
end

-- ความยาวเป้าหมาย (studs; 1 stud ~ 0.35 m) ต่อชนิด: kei 3.4 m ~10, เก๋ง 4.5 m ~13, รถตู้/กระบะ kei (Hijet/Sambar) ~10.5, แท็กซี่ Crown ~13, มอเตอร์ไซค์ 1.9 m ~5.5
local TARGET_LENGTH: { [string]: number } = { kei = 10, sedan = 13, van = 10.5, taxi = 13, bike = 5.5 }

local function importedCar(parent: Instance, cf: CFrame, moving: boolean): (Model?, BasePart?)
	local assets = ServerStorage:FindFirstChild("ImportedAssets")
	local folder = assets and assets:FindFirstChild("Cars")
	local list = folder and folder:GetChildren() or {}
	if #list == 0 then
		return nil
	end
	-- สัดส่วนยุค ~1985-2005: เล็ก/kei 40%, เก๋ง 20%, ตู้/กระบะ 15%, มอเตอร์ไซค์ 15% (มีคนขี่), แท็กซี่ 10% (Crown จริง)
	local byKind: { [string]: { Instance } } = {}
	for _, c in list do
		local k = c:GetAttribute("Kind")
		local key = if type(k) == "string" then k else "sedan"
		byKind[key] = byKind[key] or {}
		table.insert(byKind[key], c)
	end
	local roll, kind = rng:NextNumber(), "kei"
	if roll < 0.4 then
		kind = "kei"
	elseif roll < 0.6 then
		kind = "sedan"
	elseif roll < 0.75 then
		kind = "van"
	elseif roll < 0.9 then
		kind = "bike"
	else
		kind = "taxi"
	end
	-- แท็กซี่: ใช้โมเดล Crown จริง (Kind=taxi) ถ้าไม่มีก็ถอยไปใช้เก๋งธรรมดา + ป้ายไฟหลังคา
	local isTaxi = false
	if kind == "taxi" and not byKind.taxi then
		kind = "sedan"
		isTaxi = true
	end
	local pool = byKind[kind] or list
	local src = pool[rng:NextInteger(1, #pool)]
	if not src:IsA("Model") then
		return nil
	end
	local model = src:Clone()
	model.Name = if moving then "TrafficCar" else "ParkedCar"
	model:SetAttribute("Src", src.Name)
	-- สีตัวถังของโมเดลนำเข้าบางคันเป็นสีดิบ (#00FF00 / #FF0000) ให้เปลี่ยนเป็นสีรถจริงหม่น ๆ (ตัวถัง) หรือดำด้าน (ชิ้นแต่ง)
	local paints = { "D8D6D0", "2E3036", "8A8D91", "3F566E", "7A2E2A", "B8B2A4" }
	local paint = Color3.fromHex(paints[rng:NextInteger(1, #paints)])
	local isRealTaxi = src:GetAttribute("Kind") == "taxi"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			-- แท็กซี่ Crown ต้นฉบับเป็นสีขาวลายแถบ: ตัวถังขาว/เทาอ่อนทาเหลืองแท็กซี่ แถบน้ำเงิน/แดงขนาดใหญ่ทาดำ (ไฟท้าย/ไฟหน้าชิ้นเล็กไม่แตะ)
			if isRealTaxi then
				local c = d.Color
				local big = d.Size.Magnitude > 1.2
				local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
				if big and mn > 0.8 and d.Transparency < 0.3 then
					d.Color = Color3.fromHex("F2B705")
				elseif big and mx - mn > 0.45 and (c.B > c.R or c.R > 0.6) and d.Transparency < 0.3 then
					d.Color = Color3.fromHex("1C1D21")
				end
			end
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
	local primary = model.PrimaryPart
	if not primary then
		local bestVol = -1
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Size.X * d.Size.Y * d.Size.Z > bestVol then
				primary, bestVol = d, d.Size.X * d.Size.Y * d.Size.Z
			end
		end
	end
	if not primary then
		model:Destroy()
		return nil
	end
	model:PivotTo(cf) -- ไม่ตั้ง PrimaryPart ทับ: จะเปลี่ยนทิศ pivot ของโมเดลที่ปรับ WorldPivot ไว้แล้ว
	-- โมเดลที่ยาวตามแกน X (หันข้างถนน เช่นสกูตเตอร์) หมุน 90 องศาให้ยาวตามแกน Z (ทิศวิ่ง) ก่อน แล้วค่อยวางพื้น
	-- ทิศหน้า/หลัง (180 องศา) ตั้งด้วย Attribute FrontYaw บนโมเดลต้นฉบับ (องศา) ถ้าหน้ารถหันกลับด้าน
	local _, firstSize = model:GetBoundingBox()
	if firstSize.X > firstSize.Z * 1.15 then
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
	end
	local frontYaw = src:GetAttribute("FrontYaw")
	if type(frontYaw) == "number" then
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(frontYaw), 0))
	end
	-- ปรับขนาดให้ได้ความยาวตามมาตรฐานของชนิดนั้น (Pivot อยู่ใต้ล้อ ScaleTo จึงไม่ลอย/จม)
	local _, lenSize = model:GetBoundingBox()
	local scaleF = (TARGET_LENGTH[if isRealTaxi then "taxi" else kind] or 13) / math.max(lenSize.Z, 0.1)
	scaleF = math.min(scaleF, 6.4 / math.max(lenSize.X, 0.1)) -- กว้างไม่เกิน 6.4 (ไม่ล้ำขอบถนนกว้าง 16; กันโมเดลกว้างผิดสัดส่วน เช่น Hijet Truck ต้นฉบับ 5.7 x 7.8)
	model:ScaleTo(model:GetScale() * scaleF)
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
		if isTaxi then
			addTaxiLamp(model, primary, false)
		end
		if kind == "bike" and rng:NextNumber() < 0.5 then
			addRider(model, primary, src, scaleF)
		elseif kind ~= "bike" and rng:NextNumber() < 0.35 then
			addDriver(model, primary)
		end
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
	if isTaxi then
		addTaxiLamp(model, primary, true)
	end
	if kind == "bike" then
		addRider(model, primary, src, scaleF)
	else
		addDriver(model, primary)
	end
	addCarLights(model, primary, kind == "bike")
	-- ให้ pivot ของโมเดลตามตัวขยับ (ถ้าไม่มี PrimaryPart GetPivot จะค้างที่ตำแหน่งเกิด ทำให้ตรวจรถชนผู้เล่นพลาด)
	local _, moveSize = model:GetBoundingBox()
	model:SetAttribute("HalfX", moveSize.X / 2)
	model:SetAttribute("HalfZ", moveSize.Z / 2)
	model.PrimaryPart = mover
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
	-- ถนนที่รถวิ่ง (z=170 / z=600 แนวนอน) ไม่วางรถจอด กันซ้อนเลนรถวิ่ง
	local onRoute = horizontal and (z1 == 170 or z1 == 600)
	if w >= 14 and r[6] ~= "T" and not onRoute then
		for _, side in { -1, 1 } do
			local lane = side * (w / 2 - 3.8) -- รถกว้างสุด ~6.4 studs ชิดขอบถนนไม่ล้ำขอบทางเท้า
			local intervals = World.FreeIntervals(ri, lane)
			for t = 40, length - 40, 60 do
				if rng:NextNumber() < 0.5 then
					local along = (if horizontal then math.min(x1, x2) else math.min(z1, z2)) + t + rng:NextNumber(-10, 10)
					local ok = false
					for _, iv in intervals do
						if along >= iv[1] + 10 and along <= iv[2] - 10 then
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

-- รถจอดซอย/ถนนรอง (กว้าง 10-13): ชิดขอบข้างเดียว ห่างกัน ~50 stud ไม่ซ้อนเลนถนนสายหลักที่รถวิ่ง
local sideRng = Random.new(77)
for ri, r in World.Roads do
	local x1, z1, x2, z2, w = r[1], r[2], r[3], r[4], r[5]
	local horizontal = math.abs(x2 - x1) >= math.abs(z2 - z1)
	local length = if horizontal then math.abs(x2 - x1) else math.abs(z2 - z1)
	local onRoute = horizontal and (z1 == 170 or z1 == 600)
	if w >= 10 and w < 14 and r[6] ~= "T" and r[6] ~= "A" and not onRoute then
		local side = if sideRng:NextNumber() > 0.5 then 1 else -1
		local lane = side * (w / 2 - 3.2)
		local intervals = World.FreeIntervals(ri, lane)
		for t = 30, length - 30, 50 do
			if sideRng:NextNumber() < 0.4 then
				local along = (if horizontal then math.min(x1, x2) else math.min(z1, z2)) + t + sideRng:NextNumber(-8, 8)
				local ok = false
				for _, iv in intervals do
					if along >= iv[1] + 10 and along <= iv[2] - 10 then
						ok = true
					end
				end
				local x = if horizontal then along else x1 + lane
				local z = if horizontal then z1 + lane else along
				if ok and not inSchoolZone(x, z) and math.abs(z - 420) > 36 then
					local heading = if horizontal then math.rad(90) else 0
					if sideRng:NextNumber() > 0.5 then
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
	-- เลนห่างกึ่งกลาง 4.2 (รถกว้างสุด ~6.4 บนถนนกว้าง 16-22): ความเร็วต่างกันตามเส้นทาง คันในเส้นทางเดียวกันความเร็วเท่ากัน (ไม่ทะลุกัน)
	{ Vector3.new(-760, 0.3, 170 + 4.2), Vector3.new(760, 0.3, 170 + 4.2), 34 },
	{ Vector3.new(760, 0.3, 170 - 4.2), Vector3.new(-760, 0.3, 170 - 4.2), 38 },
	{ Vector3.new(-660, 0.3, 600 + 4.2), Vector3.new(680, 0.3, 600 + 4.2), 30 },
	{ Vector3.new(680, 0.3, 600 - 4.2), Vector3.new(-660, 0.3, 600 - 4.2), 33 },
}
for i, route in routes do
	local a: Vector3, b: Vector3, speed: number = route[1], route[2], route[3]
	for k = 0, 2 do
		task.spawn(function()
			local start = a:Lerp(b, k / 3 + rng:NextNumber(-0.04, 0.04))
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
	local MARGIN = Vector3.new(1.2, 3.5, 1.2) -- กล่องชน = ครึ่งตัวรถ (Attribute HalfX/HalfZ ตามขนาดจริงหลังสเกล) + ระยะตัวละคร
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			for _, car in traffic:GetChildren() do
				if car:IsA("Model") then
					local cf = car:GetPivot()
						local HALF = Vector3.new((car:GetAttribute("HalfX") or 2.2) + MARGIN.X, MARGIN.Y, (car:GetAttribute("HalfZ") or 4.5) + MARGIN.Z)
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
