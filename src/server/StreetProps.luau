--!strict
-- เฟอร์นิเจอร์ริมถนนแบบญี่ปุ่น ประกอบจากชิ้นส่วน: ตู้กดน้ำ (jihanki) ถังขยะแยกประเภท ตู้ไปรษณีย์ ที่จอดจักรยาน
-- ทางม้าลาย + แผ่นนำทางสีเหลือง ราวกันตก เสาสัญญาณข้ามถนน ศาลเล็ก (hokora) + โทริอิ + เชือกชิเมนาวะ โคมหิน และรูปปั้นจิโซ
-- พิกัดทั้งหมด y=0 = ระดับพื้น; yaw: 0 = หันหน้าไป -Z, 180 = หันไป +Z (เหมือน BK.sign)
local BK = require(script.Parent.BuildKit)

local SP = {}
local hex = Color3.fromHex

-- วางชิ้นส่วนในพิกัดท้องถิ่นของของชิ้นนั้น (หมุนตาม yaw รอบจุด x,z)
local function placer(parent: Instance, x: number, y: number, z: number, yaw: number)
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)
	return function(name: string, size: Vector3, offset: Vector3, color: Color3, mat: Enum.Material?): Part
		local p = BK.part(name, size, Vector3.zero, color, parent, mat)
		p.CFrame = base * CFrame.new(offset)
		return p
	end, base
end

local DRINK_COLORS = { "9E3B33", "3F566E", "D6D3CA", "4F7358", "B8944A" }

-- ตู้กดน้ำ 1 ตู้ (ด้านหน้า = -Z ท้องถิ่น)
function SP.jihanki(parent: Instance, x: number, z: number, yaw: number, colorIdx: number)
	local piece = placer(parent, x, 0.45, z, yaw)
	local body = hex(DRINK_COLORS[(colorIdx % #DRINK_COLORS) + 1])
	piece("JihankiBody", Vector3.new(2.7, 6.2, 2.3), Vector3.new(0, 3.1, 0), body, Enum.Material.Metal)
	local panel = piece("JihankiPanel", Vector3.new(2.1, 3.4, 0.15), Vector3.new(-0.15, 3.9, -1.2), hex("F0E3C0"), Enum.Material.Neon)
	BK.noCollide(panel)
	-- แถวสินค้า (แถบสีเล็ก ๆ) หน้าตู้
	for row = 0, 2 do
		for col = 0, 3 do
			local item = piece("JihankiItem", Vector3.new(0.35, 0.8, 0.1), Vector3.new(-0.9 + col * 0.55, 4.9 - row * 1.0, -1.28), hex(DRINK_COLORS[((row * 4 + col + colorIdx) % #DRINK_COLORS) + 1]), Enum.Material.SmoothPlastic)
			BK.noCollide(item)
		end
	end
	piece("JihankiOutlet", Vector3.new(1.6, 0.7, 0.15), Vector3.new(-0.2, 1.0, -1.2), hex("15161A"), Enum.Material.Metal)
	piece("JihankiCoin", Vector3.new(0.5, 0.9, 0.12), Vector3.new(0.95, 2.4, -1.22), hex("2A2C32"), Enum.Material.Metal)
	BK.light(panel, hex("FFE6B0"), 12, 0.6)
end

-- ถังรีไซเคิล 3 ช่อง (กระป๋อง/ขวด/ทั่วไป)
function SP.recycleBins(parent: Instance, x: number, z: number, yaw: number)
	local piece = placer(parent, x, 0.45, z, yaw)
	for i, c in { "3F566E", "B8944A", "6A6D72" } do
		piece("RecycleBin", Vector3.new(1.3, 2.6, 1.3), Vector3.new((i - 2) * 1.5, 1.3, 0), hex(c), Enum.Material.Metal)
		piece("RecycleLid", Vector3.new(1.4, 0.2, 1.4), Vector3.new((i - 2) * 1.5, 2.7, 0), hex("2A2C32"), Enum.Material.Metal)
		BK.noCollide(piece("RecycleSlot", Vector3.new(0.7, 0.35, 0.1), Vector3.new((i - 2) * 1.5, 2.1, -0.68), hex("101114"), Enum.Material.Metal))
	end
end

-- ตู้ไปรษณีย์สีแดง (ทรงกล่อง ปากช่องทางด้านหน้า)
function SP.mailbox(parent: Instance, x: number, z: number, yaw: number)
	local piece = placer(parent, x, 0.45, z, yaw)
	piece("MailboxLegs", Vector3.new(0.8, 1.2, 0.8), Vector3.new(0, 0.6, 0), hex("2A2C32"), Enum.Material.Metal)
	piece("MailboxBody", Vector3.new(1.4, 2.4, 1.4), Vector3.new(0, 2.4, 0), hex("A33128"), Enum.Material.Metal)
	piece("MailboxCap", Vector3.new(1.5, 0.3, 1.5), Vector3.new(0, 3.75, 0), hex("8A2820"), Enum.Material.Metal)
	BK.noCollide(piece("MailboxSlot", Vector3.new(0.9, 0.2, 0.1), Vector3.new(0, 3.0, -0.72), hex("101114"), Enum.Material.Metal))
	BK.noCollide(piece("MailboxMark", Vector3.new(0.5, 0.5, 0.05), Vector3.new(0, 2.1, -0.72), hex("E4E0D6"), Enum.Material.Metal))
end

-- ที่จอดจักรยาน n คันตามแนว x ท้องถิ่น (มีจักรยานจอด)
function SP.bikeRack(parent: Instance, x: number, z: number, yaw: number, n: number, rng: Random)
	local piece = placer(parent, x, 0.45, z, yaw)
	local frameColors = { "3F566E", "6A6D72", "4F7358", "9E3B33", "2A2C32" }
	piece("BikeRackBar", Vector3.new(n * 1.6 + 0.4, 0.2, 0.2), Vector3.new(0, 0.7, 0.9), hex("6A6D72"), Enum.Material.Metal)
	for i = 0, n - 1 do
		local bx = (i - (n - 1) / 2) * 1.6
		local fc = hex(frameColors[rng:NextInteger(1, #frameColors)])
		for _, wz in { -1.4, 1.4 } do
			local w = piece("BikeWheel", Vector3.new(0.18, 2.2, 2.2), Vector3.new(bx, 1.1, wz), hex("1A1B20"), Enum.Material.Metal)
			w.Shape = Enum.PartType.Cylinder
			BK.noCollide(w)
		end
		BK.noCollide(piece("BikeFrame", Vector3.new(0.14, 0.14, 2.9), Vector3.new(bx, 1.9, 0), fc, Enum.Material.Metal))
		BK.noCollide(piece("BikeSeatPost", Vector3.new(0.12, 1.1, 0.12), Vector3.new(bx, 2.1, 0.9), fc, Enum.Material.Metal))
		BK.noCollide(piece("BikeSeat", Vector3.new(0.4, 0.15, 0.7), Vector3.new(bx, 2.7, 0.9), hex("15161A"), Enum.Material.Metal))
		BK.noCollide(piece("BikeStem", Vector3.new(0.12, 1.3, 0.12), Vector3.new(bx, 2.2, -1.35), fc, Enum.Material.Metal))
		BK.noCollide(piece("BikeBar", Vector3.new(1.0, 0.12, 0.12), Vector3.new(bx, 2.9, -1.35), hex("15161A"), Enum.Material.Metal))
		if rng:NextNumber() < 0.6 then
			BK.noCollide(piece("BikeBasket", Vector3.new(0.9, 0.55, 0.7), Vector3.new(bx, 2.6, -1.75), hex("8F8E88"), Enum.Material.DiamondPlate))
		end
	end
end

-- ทางม้าลาย: horizontal=true = ถนนวิ่งตามแกน X (ตัดข้ามในแกน Z) ที่ตำแหน่ง x กลางทางม้าลาย
-- (cx, cz) = กึ่งกลางถนนตรงจุดข้าม, roadW = ความกว้างถนน มีแผ่นนำทางสีเหลืองที่ขอบทางเท้าทั้งสองฝั่ง
function SP.zebra(parent: Instance, cx: number, cz: number, horizontal: boolean, roadW: number)
	local stripes = 7
	for i = 0, stripes - 1 do
		local o = (i - (stripes - 1) / 2) * 1.7
		if horizontal then
			BK.box("ZebraStripe", cx + o - 0.45, cx + o + 0.45, 0.3, 0.38, cz - roadW / 2 + 0.6, cz + roadW / 2 - 0.6, hex("E4E0D6"), parent, Enum.Material.Concrete)
		else
			BK.box("ZebraStripe", cx - roadW / 2 + 0.6, cx + roadW / 2 - 0.6, 0.3, 0.38, cz + o - 0.45, cz + o + 0.45, hex("E4E0D6"), parent, Enum.Material.Concrete)
		end
	end
	for _, side in { -1, 1 } do
		-- แผ่นนำทางสีเหลืองผิวนูน (เส้นนูนเป็นแถบเล็กด้านบน)
		local edge = roadW / 2 + 0.9
		for k = 0, 5 do
			local o = (k - 2.5) * 0.9
			if horizontal then
				BK.box("TactileStrip", cx + o - 0.35, cx + o + 0.35, 0.3, 0.5, cz + side * edge - 0.7, cz + side * edge + 0.7, hex("C9A640"), parent, Enum.Material.Concrete)
			else
				BK.box("TactileStrip", cx + side * edge - 0.7, cx + side * edge + 0.7, 0.3, 0.5, cz + o - 0.35, cz + o + 0.35, hex("C9A640"), parent, Enum.Material.Concrete)
			end
		end
	end
end

-- แถบนำทางสีเหลืองตามขอบทางเท้า (ยาว len) เริ่มที่ (x,z) ตามแกน X
function SP.tactileLine(parent: Instance, x1: number, x2: number, z: number)
	BK.box("TactileLine", x1, x2, 0.45, 0.58, z - 0.45, z + 0.45, hex("C9A640"), parent, Enum.Material.Concrete)
end

-- ราวกันตกริมทางเท้า (เสาเหล็ก + ราวขาว/เทา 2 ชั้น)
function SP.guardRail(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local len = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	local steps = math.max(1, math.floor(len / 4))
	local mid = Vector3.new((x1 + x2) / 2, 0, (z1 + z2) / 2)
	for _, ry in { 2.0, 2.9 } do
		local r = BK.part("GuardRail", Vector3.new(len, 0.2, 0.2), mid + Vector3.new(0, 0.45 + ry, 0), hex("A5A7A8"), parent, Enum.Material.Metal)
		r.CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.45 + ry, 0), Vector3.new(x2, 0.45 + ry, z2)) * CFrame.Angles(0, math.rad(90), 0)
	end
	for i = 0, steps do
		local t = i / steps
		BK.cylinder("GuardRailPost", 0.14, 3.4, Vector3.new(x1 + (x2 - x1) * t, 0.45 + 1.7, z1 + (z2 - z1) * t), hex("6A6D72"), parent, Enum.Material.Metal)
	end
end

-- เสาสัญญาณคนข้าม: กล่องสัญญาณ (แดง/เขียวหรี่) + ปุ่มกด
function SP.crossingSignal(parent: Instance, x: number, z: number, yaw: number)
	local piece = placer(parent, x, 0.45, z, yaw)
	piece("SignalPole", Vector3.new(0.4, 9, 0.4), Vector3.new(0, 4.5, 0), hex("6A6D72"), Enum.Material.Metal)
	piece("SignalBox", Vector3.new(1.4, 2.6, 0.8), Vector3.new(0, 9.4, -0.3), hex("1C1D21"), Enum.Material.Metal)
	local red = piece("SignalRed", Vector3.new(0.8, 0.8, 0.1), Vector3.new(0, 10.2, -0.72), hex("C23A2E"), Enum.Material.Neon)
	local green = piece("SignalGreen", Vector3.new(0.8, 0.8, 0.1), Vector3.new(0, 8.8, -0.72), hex("3E7A55"), Enum.Material.Neon)
	BK.noCollide(red)
	BK.noCollide(green)
	BK.light(red, hex("C23A2E"), 10, 0.5)
	BK.noCollide(piece("PushButton", Vector3.new(0.5, 0.8, 0.3), Vector3.new(0, 4.0, -0.35), hex("B8944A"), Enum.Material.Metal))
end

-- โคมหิน (tōrō): ฐาน เสา กล่องไฟ (ส่องสว่างอุ่น) หลังคา ยอดกลม
function SP.stoneLantern(parent: Instance, x: number, y: number, z: number, scale: number)
	local piece = placer(parent, x, y, z, 0)
	local stone, dark = hex("8F8E88"), hex("6F6B62")
	piece("ToroBase", Vector3.new(1.6, 0.5, 1.6) * scale, Vector3.new(0, 0.25, 0) * scale, dark, Enum.Material.Granite)
	piece("ToroShaft", Vector3.new(0.7, 2.0, 0.7) * scale, Vector3.new(0, 1.5, 0) * scale, stone, Enum.Material.Granite)
	piece("ToroBand", Vector3.new(1.3, 0.3, 1.3) * scale, Vector3.new(0, 2.65, 0) * scale, dark, Enum.Material.Granite)
	local fire = piece("ToroLight", Vector3.new(1.0, 1.0, 1.0) * scale, Vector3.new(0, 3.3, 0) * scale, hex("F2C878"), Enum.Material.Neon)
	fire.Transparency = 0.15
	BK.light(fire, hex("FFB466"), 14, 0.8)
	for _, s in { { 0.6, 0 }, { -0.6, 0 }, { 0, 0.6 }, { 0, -0.6 } } do
		piece("ToroPost", Vector3.new(0.15, 1.0, 0.15) * scale, Vector3.new(s[1], 3.3, s[2]) * scale, stone, Enum.Material.Granite)
	end
	piece("ToroRoof", Vector3.new(2.2, 0.5, 2.2) * scale, Vector3.new(0, 4.05, 0) * scale, dark, Enum.Material.Slate)
	piece("ToroRoofTop", Vector3.new(1.3, 0.4, 1.3) * scale, Vector3.new(0, 4.5, 0) * scale, dark, Enum.Material.Slate)
	local top = piece("ToroTop", Vector3.new(0.6, 0.6, 0.6) * scale, Vector3.new(0, 4.95, 0) * scale, stone, Enum.Material.Granite)
	top.Shape = Enum.PartType.Ball
end

-- รูปปั้นจิโซ: ฐานหิน ตัวทรงกระบอก หัวกลม ผ้ากันเปื้อนแดง หมวกเล็ก + ของถวาย
function SP.jizo(parent: Instance, x: number, z: number, yaw: number)
	local piece = placer(parent, x, 0, z, yaw)
	local stone = hex("8A8880")
	piece("JizoPlinth", Vector3.new(2.4, 0.8, 2.0), Vector3.new(0, 0.4, 0), hex("6F6B62"), Enum.Material.Granite)
	local body = piece("JizoBody", Vector3.new(1.5, 2.2, 1.2), Vector3.new(0, 1.9, 0), stone, Enum.Material.Granite)
	body.Shape = Enum.PartType.Cylinder
	body.CFrame = body.CFrame * CFrame.Angles(0, 0, math.rad(90))
	body.Size = Vector3.new(2.2, 1.5, 1.2)
	local head = piece("JizoHead", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 3.5, 0), stone, Enum.Material.Granite)
	head.Shape = Enum.PartType.Ball
	piece("JizoBib", Vector3.new(1.2, 0.7, 0.2), Vector3.new(0, 2.8, -0.65), hex("9E3B33"), Enum.Material.Fabric)
	local hat = piece("JizoHat", Vector3.new(1.3, 0.5, 1.3), Vector3.new(0, 4.2, 0), hex("9E3B33"), Enum.Material.Fabric)
	hat.Shape = Enum.PartType.Ball
	piece("JizoOffering", Vector3.new(0.5, 0.4, 0.5), Vector3.new(-0.8, 0.95, -1.0), hex("D8CDB4"), Enum.Material.Concrete)
end

-- ศาลเล็ก (hokora) บนฐานหิน + โทริอิเล็กพร้อมเชือกชิเมนาวะและกระดาษสายฟ้า (shide) + โคมหิน 1 คู่ ด้านหน้า = -Z ท้องถิ่น
function SP.hokora(parent: Instance, x: number, z: number, yaw: number)
	local piece, base = placer(parent, x, 0, z, yaw)
	local red, wood, dark = hex("9E3B33"), hex("5C4637"), hex("34363C")
	piece("HokoraBase", Vector3.new(4.4, 0.9, 4.0), Vector3.new(0, 0.45, 0), hex("8A8880"), Enum.Material.Granite)
	piece("HokoraBody", Vector3.new(3.0, 2.8, 2.6), Vector3.new(0, 2.3, 0.2), wood, Enum.Material.Wood)
	BK.noCollide(piece("HokoraDoor", Vector3.new(1.4, 2.0, 0.12), Vector3.new(0, 2.1, -1.15), hex("3A2A20"), Enum.Material.Wood))
	for _, sx in { -1, 1 } do
		piece("HokoraPost", Vector3.new(0.3, 3.0, 0.3), Vector3.new(sx * 1.55, 2.4, -1.15), red, Enum.Material.Wood)
	end
	-- หลังคาทรงปั้นหยาซ้อน 3 ชั้นด้วยกล่องเรียวขึ้น
	piece("HokoraRoof1", Vector3.new(4.4, 0.45, 3.9), Vector3.new(0, 3.95, 0.1), dark, Enum.Material.Slate)
	piece("HokoraRoof2", Vector3.new(3.2, 0.45, 2.8), Vector3.new(0, 4.4, 0.1), dark, Enum.Material.Slate)
	piece("HokoraRoof3", Vector3.new(1.8, 0.45, 1.6), Vector3.new(0, 4.85, 0.1), dark, Enum.Material.Slate)
	-- โทริอิเล็กด้านหน้า
	local tz = -4.2
	for _, sx in { -1.8, 1.8 } do
		piece("HokoraToriiPost", Vector3.new(0.45, 4.6, 0.45), Vector3.new(sx, 2.3, tz), red, Enum.Material.Wood)
	end
	piece("HokoraToriiKasagi", Vector3.new(5.0, 0.4, 0.7), Vector3.new(0, 4.8, tz), dark, Enum.Material.Wood)
	piece("HokoraToriiNuki", Vector3.new(4.0, 0.3, 0.4), Vector3.new(0, 3.8, tz), red, Enum.Material.Wood)
	-- ชิเมนาวะ: เชือกฟางโค้งหย่อน + ชิเดะกระดาษขาว
	local rope = piece("Shimenawa", Vector3.new(3.4, 0.3, 0.3), Vector3.new(0, 3.55, tz - 0.2), hex("B9A57A"), Enum.Material.Fabric)
	BK.noCollide(rope)
	for k = -2, 2 do
		BK.noCollide(piece("Shide", Vector3.new(0.35, 0.8, 0.05), Vector3.new(k * 0.7, 3.0, tz - 0.25), hex("E8E4DC"), Enum.Material.Fabric))
	end
	-- โคมหินคู่ + ที่ถวาย
	for _, sx in { -3.4, 3.4 } do
		local wp = base * CFrame.new(sx, 0, -2.2)
		SP.stoneLantern(parent, wp.X, 0, wp.Z, 0.75)
	end
	piece("OfferingBox", Vector3.new(1.4, 0.7, 0.9), Vector3.new(0, 1.2, -1.6), wood, Enum.Material.Wood)
end

return SP
