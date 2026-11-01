--!strict
-- ชีวิตในซอย + ลานโล่ง: โยโกะโจะ (โคมกระดาษพาดซอย หลอดไฟต่ำ ผ้านอเรน ลังเบียร์ จักรยาน ตู้กดน้ำ กรวยส้ม ถังโพรเพน),
-- สวนสาธารณะกระเป๋า (ม้านั่ง สไลด์ ตู้กดน้ำ ต้นไม้) / ที่จอดรถเหรียญ / ลานตู้ ตามขอบ World.Plazas (กลางลานเว้นโล่ง 26x26 ให้ค่ายศัตรู),
-- ร้านสะดวกซื้อหน้าสถานี; ใช้ World.FreeIntervals + LotGen.Hit ให้ของอยู่ติดกำแพงตึกจริงและไม่ขวางทางแยก
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.World)
local BK = require(script.Parent.BuildKit)
local SP = require(script.Parent.StreetProps)
local LotGen = require(script.Parent.LotGen)

local worldFolder = workspace:WaitForChild("World")
while not worldFolder:GetAttribute("Built") do
	task.wait(0.5)
end
local BuildSync = require(script.Parent.BuildSync)
local __t0 = os.clock()

local hex = Color3.fromHex
local rng = Random.new(5150)
local f = Instance.new("Folder")
f.Name = "AlleyLife"
f.Parent = worldFolder

local lights, props = 0, 0
local MAX_LIGHTS = 260

local function noc(p: BasePart): BasePart
	p.CanCollide, p.CanTouch = false, false
	return p
end

local function glow(pos: Vector3, color: Color3, range: number, brightness: number)
	local bulb = BK.ball("LowBulb", 0.7, pos, color, f, Enum.Material.Neon)
	noc(bulb)
	if lights < MAX_LIGHTS then
		lights += 1
		BK.light(bulb, color, range, brightness)
	end
end

local function crateStack(x: number, z: number)
	local n = rng:NextInteger(2, 4)
	local colors = { "7A2E2A", "3F566E", "B8944A", "4F7358" }
	for k = 0, n - 1 do
		local ox, oz = rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.25, 0.25)
		BK.box("BeerCrate", x + ox - 0.9, x + ox + 0.9, k * 1.1 + 0.05, k * 1.1 + 1.1, z + oz - 0.6, z + oz + 0.6, hex(colors[rng:NextInteger(1, #colors)]), f, Enum.Material.Plastic)
	end
	props += 1
end

local function bicycle(x: number, z: number, alongX: boolean)
	local dx, dz = if alongX then 1 else 0, if alongX then 0 else 1
	for _, o in { -0.9, 0.9 } do
		local wheel = BK.cylinder("BikeWheel", 0.55, 0.12, Vector3.new(x + dx * o, 0.55, z + dz * o), hex("2A2C32"), f, Enum.Material.Metal)
		wheel.CFrame = CFrame.new(x + dx * o, 0.55, z + dz * o) * CFrame.Angles(0, if alongX then 0 else math.rad(90), math.rad(90))
		noc(wheel)
	end
	noc(BK.box("BikeFrame", x - (if alongX then 0.9 else 0.06), x + (if alongX then 0.9 else 0.06), 0.9, 1.0, z - (if alongX then 0.06 else 0.9), z + (if alongX then 0.06 else 0.9), hex(({ "4F7358", "3F566E", "9E3B33" })[rng:NextInteger(1, 3)]), f, Enum.Material.Metal))
	props += 1
end

local function cone(x: number, z: number)
	local c = BK.cylinder("Cone", 0.35, 1.1, Vector3.new(x, 0.55, z), hex("C8642A"), f, Enum.Material.Plastic)
	c.CFrame = CFrame.new(x, 0.55, z) * CFrame.Angles(0, 0, math.rad(90))
	BK.cylinder("ConeBand", 0.37, 0.25, Vector3.new(x, 0.65, z), hex("E4E0D6"), f, Enum.Material.Plastic)
	props += 1
end

local function propane(x: number, z: number)
	for k = 0, 1 do
		BK.cylinder("PropaneTank", 0.45, 1.5, Vector3.new(x + k * 1.1, 0.95, z), hex("8A8D91"), f, Enum.Material.Metal)
	end
	props += 1
end

---------------------------------------------------------------- ซอย (Y = โยโกะโจะ, B ที่กว้างไม่เกิน 9)
local alleyCount = 0
for i, r in World.Roads do
	local w, kind = r[5], r[6]
	if not (kind == "Y" or (kind == "B" and w <= 9)) then
		continue
	end
	local horizontal = math.abs(r[3] - r[1]) >= math.abs(r[4] - r[2])
	local fixed = if horizontal then r[2] else r[1]
	local lo = if horizontal then math.min(r[1], r[3]) else math.min(r[2], r[4])
	local hi = if horizontal then math.max(r[1], r[3]) else math.max(r[2], r[4])
	local yoko = kind == "Y"
	local intervals = World.FreeIntervals(i, 0)
	local function pt(t: number, off: number): (number, number)
		if horizontal then
			return t, fixed + off
		end
		return fixed + off, t
	end
	local function wallAt(t: number, side: number): boolean
		local x, z = pt(t, side * (w / 2 + 1.2))
		return LotGen.Hit(x, z, 0.3) ~= nil
	end
	local any = false
	for _, iv in intervals do
		local t = iv[1] + rng:NextNumber(5, 10)
		while t < iv[2] - 5 do
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			if not wallAt(t, side) then
				side = -side
			end
			if wallAt(t, side) then
				any = true
				local wx, wz = pt(t, side * (w / 2 - 0.9))
				local roll = rng:NextNumber()
				if roll < 0.2 then
					crateStack(wx, wz)
				elseif roll < 0.36 then
					bicycle(wx, wz, horizontal)
				elseif roll < 0.5 then
					propane(wx, wz)
				elseif roll < 0.6 then
					cone(wx, wz)
				elseif roll < 0.75 and w >= 6 then
					local yaw = if horizontal then (if side == 1 then 0 else 180) else (if side == 1 then 90 else -90)
					SP.jihanki(f, wx, wz, yaw, rng:NextInteger(0, 4))
					props += 1
				else
					BK.cylinder("BonsaiPot", 0.5, 0.9, Vector3.new(wx, 0.45, wz), hex("7A5A4A"), f, Enum.Material.Concrete).CanCollide = false
					noc(BK.ball("Bonsai", 1.4, Vector3.new(wx, 1.6, wz), hex("55784B"), f, Enum.Material.Grass))
					props += 1
				end
				-- หลอดไฟต่ำสีส้มอุ่นติดผนัง + ผ้านอเรนหน้าร้านเล็ก ๆ
				if yoko or rng:NextNumber() < 0.4 then
					local bx, bz = pt(t + rng:NextNumber(3, 6), side * (w / 2 - 0.3))
					glow(Vector3.new(bx, 3.2, bz), hex(if rng:NextNumber() < 0.7 then "FFB366" else "FF6A3D"), 13, 0.55)
				end
				if yoko and rng:NextNumber() < 0.55 then
					local nx, nz = pt(t + 2, side * (w / 2 - 0.15))
					local c = ({ "7A2E2A", "1E2A44", "E4E0D6" })[rng:NextInteger(1, 3)]
					local norenBox = if horizontal then BK.box("Noren", nx - 1.4, nx + 1.4, 2.4, 4.4, nz - 0.08, nz + 0.08, hex(c), f, Enum.Material.Fabric) else BK.box("Noren", nx - 0.08, nx + 0.08, 2.4, 4.4, nz - 1.4, nz + 1.4, hex(c), f, Enum.Material.Fabric)
					noc(norenBox)
				end
			end
			t += rng:NextNumber(11, 20)
		end
		-- โคมกระดาษพาดข้ามซอย (เฉพาะที่มีตึกทั้งสองฝั่ง)
		if yoko then
			local t2 = iv[1] + rng:NextNumber(8, 14)
			while t2 < iv[2] - 8 do
				if wallAt(t2, -1) and wallAt(t2, 1) then
					local ax, az = pt(t2, 0)
					if horizontal then
						noc(BK.box("LanternCord", ax - 0.04, ax + 0.04, 7.2, 7.26, az - w / 2 - 1, az + w / 2 + 1, hex("1B1C20"), f))
					else
						noc(BK.box("LanternCord", ax - w / 2 - 1, ax + w / 2 + 1, 7.2, 7.26, az - 0.04, az + 0.04, hex("1B1C20"), f))
					end
					for k = -1, 1 do
						local lx, lz = pt(t2, k * (w / 3))
						local lantern = BK.ball("Chochin", 1.5, Vector3.new(lx, 6.4, lz), hex("B8342A"), f, Enum.Material.Neon)
						lantern.Size = Vector3.new(1.2, 1.6, 1.2)
						noc(lantern)
						if k == 0 and lights < MAX_LIGHTS then
							lights += 1
							BK.light(lantern, hex("FF7A3D"), 16, 0.8)
						end
					end
					props += 1
				end
				t2 += rng:NextNumber(14, 24)
			end
		end
	end
	if any then
		alleyCount += 1
	end
end

---------------------------------------------------------------- ลานโล่ง: สวนกระเป๋า / ที่จอดรถเหรียญ / ลานตู้ (ของวางตามขอบ กลางลานโล่ง)
local pocketParks, lotsDressed = 0, 0
for _, p in World.Plazas do
	local x1, x2, z1, z2, kind = p[1], p[2], p[3], p[4], p[6]
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	if kind == "park" then
		pocketParks += 1
		BK.box("PocketPavement", x1, x2, 0, 0.3, z1, z2, hex("9C978C"), f, Enum.Material.Pavement)
		-- ม้านั่ง + ตู้กดน้ำ + ที่เล่น (ริมขอบ)
		BK.bench(f, x1 + 4, z1 + 4, 90)
		BK.bench(f, x2 - 4, z2 - 4, -90)
		SP.jihanki(f, x1 + 3, z2 - 3, 90, 2)
		SP.jihanki(f, x1 + 3, z2 - 6, 90, 3)
		BK.box("SlideTower", x2 - 6, x2 - 2, 0.3, 5, z1 + 2, z1 + 6, hex("9E3B33"), f)
		local slide = BK.box("SlideChute", x2 - 5.5, x2 - 2.5, 0.3, 0.7, z1 + 6, z1 + 13, hex("B8944A"), f)
		slide.CFrame = CFrame.new(slide.Position + Vector3.new(0, 2.2, 0)) * CFrame.Angles(math.rad(-22), 0, 0)
		BK.box("SandBox", x1 + 2, x1 + 8, 0.3, 0.8, z1 + 2, z1 + 8, hex("C9B48A"), f, Enum.Material.Sand)
		for _, o in { { 4, 14 }, { 34, 6 }, { 36, 34 }, { 6, 36 } } do
			BK.roundTree(f, x1 + o[1], z1 + o[2], rng:NextNumber(0.8, 1.1))
		end
	elseif kind == "lot" then
		lotsDressed += 1
		BK.box("ParkingLot", x1, x2, 0, 0.3, z1, z2, hex("4C4D52"), f, Enum.Material.Asphalt)
		for k = 0, 6 do
			BK.box("ParkingLine", x1 + 3 + k * 5.5, x1 + 3.2 + k * 5.5, 0.3, 0.34, z1 + 2, z1 + 9, hex("E4E0D6"), f)
		end
		-- รั้วตาข่ายเขียวหลังลาน + ป้ายที่จอดเหรียญ + เครื่องจ่ายเหรียญ
		BK.box("MeshFence", x1, x2, 0, 4, z2 - 0.2, z2, hex("4F6E55"), f, Enum.Material.Fabric).Transparency = 0.35
		for x = x1, x2, 8 do
			BK.cylinder("FencePost", 0.15, 4, Vector3.new(x, 2, z2 - 0.1), hex("8A8D91"), f, Enum.Material.Metal)
		end
		BK.sign(f, "P 24H", Vector3.new(3, 2.4, 0.2), Vector3.new(x2 - 3, 6, z2 - 1), 180, hex("2A4A7A"), hex("E4E0D6"))
		SP.jihanki(f, x1 + 2, z1 + 10, 90, 1)
	elseif kind == "yard" then
		lotsDressed += 1
		BK.box("YardPad", x1, x2, 0, 0.3, z1, z2, hex("8F8B83"), f, Enum.Material.Concrete)
		for k = 0, 3 do
			BK.box("Container", x1 + 2 + k * 5.5, x1 + 7 + k * 5.5, 0.3, 5.5, z1 + 1, z1 + 12, hex(({ "9E3B33", "3F566E", "B8944A", "4F7358" })[k + 1]), f, Enum.Material.Metal)
		end
		BK.lamp(f, x2 - 2, z2 - 2, hex("FFB36B"))
	end
end

---------------------------------------------------------------- ร้านสะดวกซื้อทางออกสถานี (มุมลานหน้าสถานีฝั่งตะวันออก) + ตู้กดน้ำ + ป้ายแท็กซี่
do
	local kx, kz = 236, 619
	BK.building(f, kx, kz, 14, 9, 8, hex("D2D4D4"), hex("4A525C"), { Kind = "konbini", Storefront = true, Facing = -1, Detail = false })
	SP.jihanki(f, kx - 11, 612.5, 0, 0)
	SP.jihanki(f, kx - 13.8, 612.5, 0, 2)
	SP.bikeRack(f, 150, 612.8, 0, 6, rng)
	BK.sign(f, "TAXI", Vector3.new(4, 1.6, 0.2), Vector3.new(112, 7, 614), 180, hex("2A2C32"), hex("F0D060"))
	BK.cylinder("TaxiPole", 0.12, 7, Vector3.new(112, 3.5, 614), hex("A5A7A8"), f, Enum.Material.Metal)
end

worldFolder:SetAttribute("AlleysDressed", alleyCount)
worldFolder:SetAttribute("PocketParks", pocketParks)
print(`[AlleyLife] ซอยตกแต่ง {alleyCount} เส้น, ของวาง {props}, ไฟ {lights}, สวนกระเป๋า {pocketParks}, ลานอื่น {lotsDressed}`)
BuildSync.finish("AlleyLife", __t0)
