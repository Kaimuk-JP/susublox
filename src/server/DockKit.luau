--!strict
-- ท่าเรือคอนเทนเนอร์ (ย่าน Docks): คีย์ท่า เครนยกตู้ (ship-to-shore) เรือบรรทุกตู้ เรือประมง สะพานปลา โรงเรือสำนักงานท่า ไฟส่องสว่าง รั้ว
-- สเกล 1 stud ~ 0.35 m ตัวละครสูง 4.8 stud; พื้นที่คีย์ x 628..687, z 440..840; น้ำอ่าว x >= 685 ผิวน้ำ y ~ -0.8
local BK = require(script.Parent.BuildKit)

local DockKit = {}
local hex = Color3.fromHex
local dark = hex("2A2C32")

local QUAY_X1, QUAY_X2 = 628, 687
local QUAY_Z1, QUAY_Z2 = 440, 840
local HX1, HX2 = 689.1, 713.1 -- ตัวเรือ (กว้าง 24)
local HC = (HX1 + HX2) / 2
local STERN_Z, BOW_Z, TIP_Z = 572, 675, 712

local function nc(p: BasePart): BasePart
	p.CanCollide, p.CanTouch = false, false
	return p
end

local function rope(parent: Instance, a: Vector3, b: Vector3, r: number, color: Color3?, mat: Enum.Material?): Part
	local p = nc(BK.branch(parent, a, b, r, color or hex("6B5A47"), mat or Enum.Material.Fabric)) :: Part
	p.Name = "Rope"
	return p
end

-- ลิ่มผังแนวราบ (หัวเรือ): แนวตรงอยู่ด้าน straightAtMax (x มาก) ปลายแหลมไปทาง +z กว้างสุดที่ z1
local function bowWedge(parent: Instance, xa: number, xb: number, y1: number, y2: number, z1: number, z2: number, straightAtMax: boolean, color: Color3, mat: Enum.Material)
	local w = Instance.new("WedgePart")
	w.Name = "Bow"
	w.Anchored = true
	w.Size = Vector3.new(y2 - y1, xb - xa, z2 - z1)
	w.Color = color
	w.Material = mat
	w.CFrame = CFrame.new((xa + xb) / 2, (y1 + y2) / 2, (z1 + z2) / 2) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, if straightAtMax then -math.pi / 2 else math.pi / 2)
	w.Parent = parent
end

-- ลิ่มผังแนวราบในพิกัดท้องถิ่นของ origin (หน้า +Z)
local function localBow(parent: Instance, origin: CFrame, xa: number, xb: number, y1: number, y2: number, z1: number, z2: number, straightAtMax: boolean, color: Color3, mat: Enum.Material)
	local w = Instance.new("WedgePart")
	w.Name = "Bow"
	w.Anchored = true
	w.Size = Vector3.new(y2 - y1, xb - xa, z2 - z1)
	w.Color = color
	w.Material = mat
	w.CFrame = origin * CFrame.new((xa + xb) / 2, (y1 + y2) / 2, (z1 + z2) / 2) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, if straightAtMax then -math.pi / 2 else math.pi / 2)
	w.Parent = parent
end

local function lbox(origin: CFrame, parent: Instance, name: string, size: Vector3, lp: Vector3, color: Color3, mat: Enum.Material?): Part
	local p = BK.part(name, size, origin.Position, color, parent, mat or Enum.Material.Metal)
	p.CFrame = origin * CFrame.new(lp)
	return p
end

---------------------------------------------------------------- เรือบรรทุกตู้
local function ship(f: Folder)
	local s = Instance.new("Folder")
	s.Name = "CargoShip"
	s.Parent = f
	local red, navy, white = hex("7A2E2A"), hex("26364C"), hex("E4E0D4")
	local deckCol = hex("5F6B5F")
	local mid = Vector3.new(HC, 0, 0)
	-- ตัวเรือ (ท้ายเรือตัดเรียบ หัวเรือเรียวแหลม)
	BK.box("ShipHullLow", HX1, HX2, -5, 0, STERN_Z, BOW_Z, red, s, Enum.Material.Metal)
	BK.box("ShipHull", HX1, HX2, 0, 13.4, STERN_Z, BOW_Z, navy, s, Enum.Material.Metal)
	BK.box("ShipDeck", HX1, HX2, 13.4, 14.4, STERN_Z, BOW_Z, deckCol, s, Enum.Material.Metal)
	bowWedge(s, HX1, HC, -5, 0, BOW_Z, TIP_Z, true, red, Enum.Material.Metal)
	bowWedge(s, HC, HX2, -5, 0, BOW_Z, TIP_Z, false, red, Enum.Material.Metal)
	bowWedge(s, HX1, HC, 0, 13.4, BOW_Z, TIP_Z, true, navy, Enum.Material.Metal)
	bowWedge(s, HC, HX2, 0, 13.4, BOW_Z, TIP_Z, false, navy, Enum.Material.Metal)
	bowWedge(s, HX1, HC, 13.4, 14.4, BOW_Z, TIP_Z, true, deckCol, Enum.Material.Metal)
	bowWedge(s, HC, HX2, 13.4, 14.4, BOW_Z, TIP_Z, false, deckCol, Enum.Material.Metal)
	-- ราวกันตก (แผงทึบเตี้ย) + แถบขาว + เลขท้ายเรือ
	BK.box("ShipBulwark", HX1, HX1 + 0.35, 14.4, 15.6, STERN_Z, BOW_Z + 8, hex("C9C6BA"), s, Enum.Material.Metal)
	BK.box("ShipBulwark", HX2 - 0.35, HX2, 14.4, 15.6, STERN_Z, BOW_Z + 8, hex("C9C6BA"), s, Enum.Material.Metal)
	BK.box("ShipBulwark", HX1, HX2, 14.4, 15.6, STERN_Z, STERN_Z + 0.35, hex("C9C6BA"), s, Enum.Material.Metal)
	nc(BK.box("ShipStripe", HX1 - 0.06, HX1, 11.4, 12.2, STERN_Z, BOW_Z, white, s, Enum.Material.Metal))
	nc(BK.box("ShipStripe", HX2, HX2 + 0.06, 11.4, 12.2, STERN_Z, BOW_Z, white, s, Enum.Material.Metal))
	BK.jpFont(nc(BK.sign(s, "スス丸  SUSU MARU", Vector3.new(30, 3.6, 0.25), Vector3.new(HX1 - 0.1, 8, 640), 90, navy, white)) :: Part)
	BK.jpFont(nc(BK.sign(s, "スス丸  SUSU MARU", Vector3.new(30, 3.6, 0.25), Vector3.new(HX2 + 0.1, 8, 640), -90, navy, white)) :: Part)
	nc(BK.sign(s, "SUSU MARU\nTOKYO", Vector3.new(14, 4.4, 0.25), Vector3.new(HC, 8, STERN_Z - 0.1), 0, navy, white))
	-- ตัวเรือนท้ายเรือ: 5 ชั้น แถบหน้าต่าง ปีกสะพานเดินเรือ ปล่อง เสาเรดาร์ เรือชูชีพ
	BK.box("ShipHouse", HC - 8.5, HC + 8.5, 14.4, 34.4, STERN_Z + 5, STERN_Z + 25, white, s, Enum.Material.Metal)
	for k = 0, 4 do
		local yb = 14.4 + k * 4 + 1.5
		nc(BK.box("ShipGlass", HC - 7.6, HC + 7.6, yb, yb + 1.4, STERN_Z + 25, STERN_Z + 25.15, hex("27394A"), s, Enum.Material.Glass))
		for _, sx in { -1, 1 } do
			nc(BK.box("ShipGlass", HC + sx * 8.5 - (if sx > 0 then 0 else 0.15), HC + sx * 8.5 + (if sx > 0 then 0.15 else 0), yb, yb + 1.4, STERN_Z + 7, STERN_Z + 23, hex("27394A"), s, Enum.Material.Glass))
		end
		if k > 0 then
			BK.box("ShipLedge", HC - 9.2, HC + 9.2, 14.4 + k * 4 - 0.3, 14.4 + k * 4, STERN_Z + 4.4, STERN_Z + 25.8, hex("B8B5A8"), s, Enum.Material.Metal)
		end
	end
	BK.box("ShipBridge", HC - 11.4, HC + 11.4, 34.4, 37.4, STERN_Z + 16, STERN_Z + 26.4, white, s, Enum.Material.Metal)
	nc(BK.box("ShipGlass", HC - 10.4, HC + 10.4, 35.4, 36.8, STERN_Z + 26.4, STERN_Z + 26.55, hex("27394A"), s, Enum.Material.Glass))
	BK.box("ShipBridgeRoof", HC - 11.8, HC + 11.8, 37.4, 37.9, STERN_Z + 15.4, STERN_Z + 27, hex("6B6F73"), s, Enum.Material.Metal)
	BK.cylinder("ShipFunnel", 2.8, 9, Vector3.new(HC, 38.9, STERN_Z + 10), navy, s, Enum.Material.Metal)
	BK.cylinder("ShipFunnelBand", 2.85, 1.8, Vector3.new(HC, 40.4, STERN_Z + 10), white, s, Enum.Material.Metal)
	BK.cylinder("ShipFunnelCap", 2.7, 0.5, Vector3.new(HC, 43.65, STERN_Z + 10), hex("1C1D21"), s, Enum.Material.Metal)
	BK.cylinder("ShipMast", 0.25, 9, Vector3.new(HC, 42.4, STERN_Z + 21), hex("C9C6BA"), s, Enum.Material.Metal)
	BK.box("ShipRadar", HC - 2.2, HC + 2.2, 46.7, 47.0, STERN_Z + 20.8, STERN_Z + 21.2, hex("8C8F93"), s, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		BK.box("Lifeboat", HC + sx * 9.9 - 1.1, HC + sx * 9.9 + 1.1, 23.2, 25.0, STERN_Z + 8, STERN_Z + 16, hex("D9832B"), s, Enum.Material.Metal)
	end
	-- ตู้บนดาดฟ้า: 4 ช่องตามยาว x 3 แถว กองสูง 1-2 ชั้น
	local prng = Random.new(5150)
	for _, bz in { 608, 626, 644, 662 } do
		for _, bx in { HC - 7.6, HC, HC + 7.6 } do
			if prng:NextNumber() < 0.92 then
				local tiers = if prng:NextNumber() < 0.55 then 2 else 1
				for t = 0, tiers - 1 do
					BK.container(s, bx, 14.5 + t * 7.45, bz, false, 17, prng, prng:NextNumber() < 0.3)
				end
			end
		end
	end
	-- หัวเรือ: เครื่องกว้าน บิตผูกเชือก
	BK.box("ShipWindlass", HC - 2, HC + 2, 14.4, 16.6, 686, 691, hex("5E6168"), s, Enum.Material.Metal)
	for _, p in { Vector3.new(HX1 + 1.6, 0, 680), Vector3.new(HX2 - 1.6, 0, 680), Vector3.new(HC, 0, 697) } do
		BK.cylinder("ShipBitt", 0.6, 1.4, Vector3.new(p.X, 15.1, p.Z), hex("2A2C32"), s, Enum.Material.Metal)
		BK.cylinder("ShipBittCap", 0.85, 0.35, Vector3.new(p.X, 15.9, p.Z), hex("2A2C32"), s, Enum.Material.Metal)
	end
	-- เชือกผูกเรือ ไปที่บอลลาร์ดบนท่า
	for _, r in { { 584, 604 }, { 598, 590 }, { 676, 674 }, { 664, 688 } } do
		rope(s, Vector3.new(HX1 + 0.2, 15.4, r[1]), Vector3.new(684.6, 1.5, r[2]), 0.2)
	end
end

---------------------------------------------------------------- เครนยกตู้ ship-to-shore (สูง ~50 stud)
local function crane(f: Folder, zc: number, idx: number)
	local c = Instance.new("Folder")
	c.Name = "GantryCrane" .. idx
	c.Parent = f
	local xl, xw = 663, 681 -- ขาฝั่งบก / ฝั่งน้ำ (รางห่าง 18)
	local steel, boomCol, dark = hex("AEB8BF"), hex("C25B45"), hex("2A2C32")
	local legH = 36.4
	for _, x in { xl, xw } do
		for _, dz in { -7, 7 } do
			BK.box("CraneLeg", x - 0.9, x + 0.9, 0.7, legH, zc + dz - 0.9, zc + dz + 0.9, steel, c, Enum.Material.Metal)
			BK.box("CraneBogie", x - 1.4, x + 1.4, 0.35, 1.5, zc + dz - 2.6, zc + dz + 2.6, dark, c, Enum.Material.Metal)
		end
		BK.box("CraneSill", x - 0.6, x + 0.6, 1.5, 2.6, zc - 7.9, zc + 7.9, steel, c, Enum.Material.Metal)
		BK.box("CraneStrut", x - 0.5, x + 0.5, 17, 18, zc - 7, zc + 7, steel, c, Enum.Material.Metal)
		BK.box("CranePortalBeam", x - 0.9, x + 0.9, 33.8, legH, zc - 7.9, zc + 7.9, steel, c, Enum.Material.Metal)
		rope(c, Vector3.new(x, 3, zc - 7), Vector3.new(x, 17, zc + 7), 0.3, steel, Enum.Material.Metal)
		rope(c, Vector3.new(x, 3, zc + 7), Vector3.new(x, 17, zc - 7), 0.3, steel, Enum.Material.Metal)
		rope(c, Vector3.new(x, 18, zc - 7), Vector3.new(x, 33, zc + 7), 0.3, steel, Enum.Material.Metal)
		rope(c, Vector3.new(x, 18, zc + 7), Vector3.new(x, 33, zc - 7), 0.3, steel, Enum.Material.Metal)
	end
	for _, dz in { -7, 7 } do
		BK.box("CraneCrossBeam", xl - 0.9, xw + 0.9, 33.8, legH, zc + dz - 0.9, zc + dz + 0.9, steel, c, Enum.Material.Metal)
		BK.box("CraneCrossSill", xl - 0.9, xw + 0.9, 1.5, 2.6, zc + dz - 0.6, zc + dz + 0.6, steel, c, Enum.Material.Metal)
	end
	BK.jpFont(nc(BK.sign(c, "SUSU PORT  No." .. idx, Vector3.new(11, 1.7, 0.3), Vector3.new((xl + xw) / 2, 35.1, zc + 7.95), 180, hex("B8473A"), hex("F2F0E6"))) :: Part)
	BK.jpFont(nc(BK.sign(c, "SUSU PORT  No." .. idx, Vector3.new(11, 1.7, 0.3), Vector3.new((xl + xw) / 2, 35.1, zc - 7.95), 0, hex("B8473A"), hex("F2F0E6"))) :: Part)
	-- บูม (ทรัสส์สองด้าน) ยื่นออกเหนือเรือ + แขนหลังยื่นเหนือฝั่งบก
	local bx1, bx2 = 648, 714.4
	local yb1, yb2, yt1, yt2 = legH, legH + 1.0, legH + 4.2, legH + 5.2
	local segs = 8
	local step = (bx2 - bx1) / segs
	for _, zs in { zc - 2.3, zc + 2.3 } do
		BK.box("BoomChordLow", bx1, bx2, yb1, yb2, zs - 0.45, zs + 0.45, boomCol, c, Enum.Material.Metal)
		BK.box("BoomChordTop", bx1, bx2, yt1, yt2, zs - 0.45, zs + 0.45, boomCol, c, Enum.Material.Metal)
		for i = 0, segs do
			local x = bx1 + i * step
			BK.box("BoomPost", x - 0.25, x + 0.25, yb2, yt1, zs - 0.25, zs + 0.25, boomCol, c, Enum.Material.Metal)
			if i < segs then
				local a, b = Vector3.new(x, yb2, zs), Vector3.new(x + step, yt1, zs)
				if i % 2 == 1 then
					a, b = Vector3.new(x, yt1, zs), Vector3.new(x + step, yb2, zs)
				end
				rope(c, a, b, 0.22, boomCol, Enum.Material.Metal).Name = "BoomDiag"
			end
		end
	end
	for _, x in { 660, 684, 706 } do
		BK.box("BoomTie", x - 0.3, x + 0.3, yb1, yb2, zc - 2.3, zc + 2.3, boomCol, c, Enum.Material.Metal)
	end
	BK.box("CraneCounterweight", 646, 653, yb1 + 0.2, yt2, zc - 3.2, zc + 3.2, hex("4A4E54"), c, Enum.Material.Concrete)
	-- ห้องเครื่อง + โครง A-frame + สายสเตย์
	BK.box("CraneMachineHouse", 664, 677, yt2, yt2 + 4.2, zc - 3.4, zc + 3.4, steel, c, Enum.Material.Metal)
	BK.box("CraneMachineRoof", 663.6, 677.4, yt2 + 4.2, yt2 + 4.6, zc - 3.8, zc + 3.8, hex("6B6F73"), c, Enum.Material.Metal)
	local ax, ay = 671, 50.2
	for _, dz in { -3, 3 } do
		rope(c, Vector3.new(665.5, yt2 + 4.4, zc + dz), Vector3.new(ax, ay, zc), 0.5, steel, Enum.Material.Metal).Name = "CraneAFrame"
		rope(c, Vector3.new(676, yt2 + 4.4, zc + dz), Vector3.new(ax, ay, zc), 0.5, steel, Enum.Material.Metal).Name = "CraneAFrame"
	end
	BK.box("CraneApex", ax - 1, ax + 1, ay, ay + 0.8, zc - 1, zc + 1, hex("B8473A"), c, Enum.Material.Metal)
	for _, dz in { -2.3, 2.3 } do
		rope(c, Vector3.new(ax, ay + 0.3, zc + dz * 0.4), Vector3.new(bx2 - 0.5, yt2, zc + dz), 0.17, dark)
		rope(c, Vector3.new(ax, ay + 0.3, zc + dz * 0.4), Vector3.new(647.5, yt2, zc + dz), 0.17, dark)
	end
	-- รถเข็นบนบูม + ห้องคนขับ + สเปรดเดอร์ห้อยด้วยสลิง
	local tx = 700 + (idx - 1) * 3
	BK.box("CraneTrolley", tx - 4, tx + 4, yb1 - 2.2, yb1, zc - 3.2, zc + 3.2, boomCol, c, Enum.Material.Metal)
	BK.box("CraneCab", tx - 9.6, tx - 4, yb1 - 4.4, yb1, zc - 2.2, zc + 2.2, hex("E4E0D4"), c, Enum.Material.Metal)
	for _, dz in { -2.25, 2.25 } do
		nc(BK.box("CraneCabGlass", tx - 9, tx - 4.6, yb1 - 3.2, yb1 - 1.4, zc + dz - 0.05, zc + dz + 0.05, hex("27394A"), c, Enum.Material.Glass))
	end
	local sy = 30.6
	BK.box("CraneSpreader", tx - 2, tx + 2, sy, sy + 1.0, zc - 8.5, zc + 8.5, hex("2F5F8A"), c, Enum.Material.Metal)
	for _, dx in { -1.6, 1.6 } do
		for _, dz in { -2.4, 2.4 } do
			rope(c, Vector3.new(tx + dx, yb1 - 2.2, zc + dz), Vector3.new(tx + dx * 0.9, sy + 1.0, zc + dz * 3), 0.13, dark)
		end
	end
end

---------------------------------------------------------------- เรือเล็ก (หน้าเรือ = +Z ของ origin)
local function boat(parent: Instance, origin: CFrame, L: number, B: number, hullCol: Color3, houseCol: Color3, tug: boolean)
	local m = Instance.new("Folder")
	m.Name = if tug then "Tugboat" else "FishingBoat"
	m.Parent = parent
	local straight = L - 7
	lbox(origin, m, "BoatHull", Vector3.new(B, 4.4, straight), Vector3.new(0, 0.4, -L / 2 + straight / 2), hullCol)
	localBow(m, origin, -B / 2, 0, -1.8, 2.6, L / 2 - 7, L / 2, true, hullCol, Enum.Material.Metal)
	localBow(m, origin, 0, B / 2, -1.8, 2.6, L / 2 - 7, L / 2, false, hullCol, Enum.Material.Metal)
	lbox(origin, m, "BoatDeck", Vector3.new(B - 0.5, 0.2, straight - 0.2), Vector3.new(0, 2.65, -L / 2 + straight / 2), hex("8F7352"), Enum.Material.WoodPlanks)
	lbox(origin, m, "BoatStripe", Vector3.new(B + 0.1, 0.5, straight), Vector3.new(0, 2.0, -L / 2 + straight / 2), hex("E4E0D4"))
	local hz = -L / 2 + (if tug then 6 else 4.5)
	local hw = B - (if tug then 3 else 2.4)
	lbox(origin, m, "BoatHouse", Vector3.new(hw, 3.4, 5.2), Vector3.new(0, 4.4, hz), houseCol)
	lbox(origin, m, "BoatHouseRoof", Vector3.new(hw + 0.6, 0.25, 6), Vector3.new(0, 6.2, hz + 0.1), hex("5E6168"))
	nc(lbox(origin, m, "BoatGlass", Vector3.new(hw - 0.8, 1.3, 0.12), Vector3.new(0, 4.9, hz + 2.65), hex("27394A"), Enum.Material.Glass))
	for _, sx in { -1, 1 } do
		nc(lbox(origin, m, "BoatGlass", Vector3.new(0.12, 1.3, 3.4), Vector3.new(sx * (hw / 2 + 0.02), 4.9, hz + 0.3), hex("27394A"), Enum.Material.Glass))
	end
	if tug then
		lbox(origin, m, "TugFunnel", Vector3.new(2.2, 3.6, 2.2), Vector3.new(0, 8.2, hz - 0.6), hex("B8473A"))
		lbox(origin, m, "TugFunnelTop", Vector3.new(2.3, 0.6, 2.3), Vector3.new(0, 10.2, hz - 0.6), dark)
		for _, sx in { -1, 1 } do
			local t = BK.cylinder("TugFender", 0.8, 1.6, origin.Position, hex("1C1D21"), m, Enum.Material.Rubber)
			t.CFrame = origin * CFrame.new(sx * (B / 2 + 0.3), 1.0, L / 2 - 5) * CFrame.Angles(0, 0, math.pi / 2)
			nc(t)
		end
	else
		BK.cylinder("BoatMast", 0.22, 9, (origin * CFrame.new(0, 7.2, 1.5)).Position, hex("C9C6BA"), m, Enum.Material.Metal)
		lbox(origin, m, "BoatBoom", Vector3.new(0.3, 0.3, 7), Vector3.new(0, 8.4, 1.5 - 3.4), hex("5E6168"))
		for i, dz in { 1.5, 3.5, 5.0 } do
			if -L / 2 + straight - 1 > dz then
				lbox(origin, m, "FishCrate", Vector3.new(1.5, 0.9, 1.1), Vector3.new((i - 2) * 1.6, 3.2, dz), hex(if i % 2 == 0 then "3F6F9A" else "D8D8D0"), Enum.Material.Plastic)
			end
		end
		lbox(origin, m, "FishNet", Vector3.new(2.2, 1.2, 2.0), Vector3.new(1.2, 3.3, -L / 2 + straight - 2.4), hex("7F8F6E"), Enum.Material.Fabric)
	end
	-- ผูกเชือกจากยอดเสา/หัวเรือ
	if not tug then
		rope(m, (origin * CFrame.new(0, 11.7, 1.5)).Position, (origin * CFrame.new(0, 2.8, L / 2 - 0.3)).Position, 0.08, hex("2A2C32"))
		rope(m, (origin * CFrame.new(0, 11.7, 1.5)).Position, (origin * CFrame.new(0, 3.0, -L / 2 + 0.5)).Position, 0.08, hex("2A2C32"))
	end
end

---------------------------------------------------------------- สะพานปลา + เรือประมง
local function fishingPier(f: Folder)
	local p = Instance.new("Folder")
	p.Name = "FishingPier"
	p.Parent = f
	local pz = 800
	BK.box("PierDeck", 689, 742, 0, 1.0, pz - 3.5, pz + 3.5, hex("6F5236"), p, Enum.Material.WoodPlanks)
	for x = 692, 740, 8 do
		for _, dz in { -3.2, 3.2 } do
			BK.cylinder("PierPost", 0.5, 7, Vector3.new(x, -2.6, pz + dz), hex("5B4A38"), p, Enum.Material.Wood)
			BK.cylinder("PierPostTop", 0.5, 1.6, Vector3.new(x, 1.8, pz + dz), hex("5B4A38"), p, Enum.Material.Wood)
		end
		BK.box("PierBeam", x - 0.3, x + 0.3, -0.4, 0, pz - 3.5, pz + 3.5, hex("4F3F2E"), p, Enum.Material.Wood)
	end
	BK.lamp(p, 741, pz - 2.5, hex("FFB36B"))
	BK.lamp(p, 702, pz + 2.5, hex("FFB36B"))
	for _, d in { Vector3.new(715, 1, pz - 1.5), Vector3.new(716.8, 1, pz - 1.5), Vector3.new(716, 1, pz - 3) } do
		BK.drum(p, d.X, d.Z, d.Y, hex("3F5F8A"))
	end
	BK.pallet(p, CFrame.new(727, 1, pz + 1.5) * CFrame.Angles(0, math.rad(15), 0), true)
	BK.pallet(p, CFrame.new(731, 1, pz - 1.8), true)
	local b = Instance.new("Folder")
	b.Name = "Boats"
	b.Parent = f
	local y = -1.6
	local quarter = math.pi / 2
	boat(b, CFrame.new(706, y, 791.5) * CFrame.Angles(0, quarter, 0), 20, 6.4, hex("2F5F8A"), hex("E4E0D4"), false)
	boat(b, CFrame.new(730, y, 791.5) * CFrame.Angles(0, -quarter, 0), 18, 6, hex("8E3A36"), hex("E4E0D4"), false)
	boat(b, CFrame.new(711, y, 808.5) * CFrame.Angles(0, quarter, 0), 22, 6.6, hex("3F6B55"), hex("D8D2BE"), false)
	-- เรือประมง/เรือลากจูงจอดริมท่า
	boat(b, CFrame.new(692.3, -2.2, 520), 26, 9, hex("26364C"), hex("E4E0D4"), true)
	boat(b, CFrame.new(691.2, y, 765) * CFrame.Angles(0, math.pi, 0), 18, 6, hex("B8473A"), hex("E4E0D4"), false)
	for _, r in { { 520 - 8, 8 }, { 520 + 8, 8 } } do
		rope(b, Vector3.new(692.3, 3.2, r[1]), Vector3.new(684.6, 1.5, r[1] + (if r[1] < 520 then -2 else 2)), 0.15)
	end
end

---------------------------------------------------------------- สำนักงานท่าเรือ + เสาธง
local function harborOffice(f: Folder)
	local cx, cz = 646, 530
	local model = BK.building(f, cx, cz, 16, 11, 16, hex("E4DFD0"), hex("5B5D6B"), {
		Facing = 1, Material = Enum.Material.Plaster, SignText = "港湾事務所", SignBg = hex("1F3A5F"), SignFg = hex("F2F0E6"),
	})
	model.Name = "HarborOffice"
	BK.jpFont(BK.sign(model, "SUSU PORT  HARBOR OFFICE", Vector3.new(9.5, 1.0, 0.3), Vector3.new(cx, 8.0, cz + 5.8), 180, hex("E4DFD0"), hex("1F3A5F")))
	BK.box("OfficeDoor", cx + 3, cx + 6, 0.3, 6.6, cz + 5.5, cz + 5.78, hex("3C4A5A"), model, Enum.Material.Metal)
	BK.box("OfficeStep", cx + 2.6, cx + 6.4, 0, 0.4, cz + 5.5, cz + 6.8, hex("8F8B83"), model, Enum.Material.Concrete)
	BK.rotateModel(model, cx, cz, 90) -- หน้าตึกหัน +X (ทางท่า)
	local fx, fz = cx + 5.5 + 6, cz - 6
	BK.cylinder("FlagPole", 0.25, 20, Vector3.new(fx, 10, fz), hex("C9C6BA"), f, Enum.Material.Metal)
	BK.box("Flag", fx - 0.05, fx + 0.05, 14.5, 18.5, fz, fz + 6, hex("F2F0E6"), f, Enum.Material.Fabric)
	local disc = BK.part("FlagDisc", Vector3.new(0.14, 2.6, 2.6), Vector3.new(fx + 0.09, 16.5, fz + 3), hex("C0302E"), f, Enum.Material.Fabric)
	disc.Shape = Enum.PartType.Cylinder
	for _, d in { Vector3.new(cx + 8, 0, cz + 11), Vector3.new(cx + 9.8, 0, cz + 11.4), Vector3.new(cx + 8.8, 0, cz + 13.1) } do
		BK.drum(f, d.X, d.Z, 0, hex("9E3B33"))
	end
end

---------------------------------------------------------------- ไฟส่องสว่างท่า (เสาไฟสูง)
local function floodMast(f: Folder, x: number, z: number)
	BK.cylinder("MastBase", 0.9, 1.2, Vector3.new(x, 0.6, z), hex("5E6168"), f, Enum.Material.Concrete)
	BK.cylinder("FloodMast", 0.4, 26, Vector3.new(x, 13.5, z), hex("5E6168"), f, Enum.Material.Metal)
	BK.box("FloodBar", x - 3, x + 3, 26.8, 27.4, z - 0.5, z + 0.5, hex("2A2C32"), f, Enum.Material.Metal)
	for i, dx in { -2.2, 0, 2.2 } do
		local lamp = BK.box("FloodLamp", x + dx - 0.7, x + dx + 0.7, 26.0, 26.8, z - 0.8, z + 0.3, hex("F4EBC8"), f, Enum.Material.Glass)
		nc(lamp)
		if i == 2 then
			BK.light(lamp, hex("FFE9B0"), 60, 0.9)
		end
	end
end

---------------------------------------------------------------- ท่าเรือทั้งหมด
function DockKit.build(f: Folder)
	local q = Instance.new("Folder")
	q.Name = "Quay"
	q.Parent = f
	-- พื้นคีย์ + กำแพงคีย์ลงน้ำ + ขอบกันตก + เส้นเหลืองขอบท่า
	BK.box("Quay", QUAY_X1, QUAY_X2, 0, 0.35, QUAY_Z1, QUAY_Z2, hex("8F8B83"), q, Enum.Material.Concrete)
	BK.box("QuayWall", 686, 687.2, -9.5, 0.35, QUAY_Z1, QUAY_Z2, hex("6E6C66"), q, Enum.Material.Concrete)
	BK.box("QuayKerb", 686.2, 687.2, 0.35, 1.0, QUAY_Z1, QUAY_Z2, hex("A8A59C"), q, Enum.Material.Concrete)
	nc(BK.box("QuayLine", 684.6, 685.2, 0.35, 0.39, QUAY_Z1, QUAY_Z2, hex("D6B63A"), q, Enum.Material.Concrete))
	for _, xr in { 663, 681 } do
		BK.box("CraneRail", xr - 0.3, xr + 0.3, 0.35, 0.7, 566, 706, hex("5E6168"), q, Enum.Material.Metal)
	end
	-- ป้ายพื้น (ทาสี) หมายเลขท่า
	for _, s in { { "BERTH 3  第3岸壁", 648 }, { "BERTH 3  第3岸壁", 622 } } do
		local plate = BK.part("BerthPaint", Vector3.new(11, 2.6, 0.08), Vector3.new(638, 0.37, s[2]), hex("8F8B83"), q, Enum.Material.Concrete)
		plate.CFrame = CFrame.new(638, 0.4, s[2]) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi / 2, 0, 0)
		nc(plate)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = plate
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = s[1]
		t.TextColor3 = hex("F2F0E6")
		t.Font = Enum.Font.SourceSansBold
		t.TextScaled = true
		t.Parent = gui
	end
	-- บอลลาร์ด + เฟนเดอร์ยาง (ทุก 14 stud)
	for z = 450, 830, 14 do
		BK.cylinder("Bollard", 0.6, 1.6, Vector3.new(684.6, 1.15, z), hex("2A2C32"), q, Enum.Material.Metal)
		BK.cylinder("BollardCap", 0.85, 0.4, Vector3.new(684.6, 2.1, z), hex("2A2C32"), q, Enum.Material.Metal)
	end
	for z = 456, 836, 12 do
		nc(BK.cylinder("Fender", 0.9, 4.2, Vector3.new(688.1, -0.4, z), hex("1C1D21"), q, Enum.Material.Rubber))
	end
	-- ตู้สต็อกบนคีย์ (สองกอง) พร้อมโฟล์คลิฟต์ พาเลท ถังน้ำมัน
	local prng = Random.new(8128)
	for _, zs in { { 462, 480 }, { 762, 780 }, { 812, 830 } } do
		for _, x in { 650, 657.5, 665 } do
			for _, z in zs do
				if prng:NextNumber() < 0.88 then
					local q3 = prng:NextNumber()
					local tiers = if q3 < 0.4 then 1 elseif q3 < 0.8 then 2 else 3
					for t = 0, tiers - 1 do
						BK.container(q, x, 0.4 + t * 7.45, z, false, 17, prng, true)
					end
				end
			end
		end
	end
	BK.forklift(q, CFrame.new(636, 0.35, 515) * CFrame.Angles(0, math.rad(70), 0), hex("C9722A"))
	BK.forklift(q, CFrame.new(676, 0.35, 474) * CFrame.Angles(0, math.rad(200), 0), hex("B8962E"))
	BK.forklift(q, CFrame.new(672, 0.35, 768) * CFrame.Angles(0, math.rad(-40), 0), hex("C9722A"))
	for i, p in { Vector3.new(678, 0, 520), Vector3.new(681, 0, 525), Vector3.new(676, 0, 530), Vector3.new(643, 0, 508), Vector3.new(674, 0, 770) } do
		BK.pallet(q, CFrame.new(p.X, 0.35, p.Z) * CFrame.Angles(0, math.rad(i * 37), 0), i % 2 == 1)
	end
	for r = 0, 1 do
		for k = 0, 2 do
			BK.drum(q, 672 + k * 1.9, 735 + r * 1.9, 0.35, hex(({ "3F5F8A", "9E3B33", "6F7A80" })[(k + r) % 3 + 1]))
		end
	end
	-- รั้วลวดตาข่ายริมที่ดิน เว้นช่องทางเข้า (ปลายถนน + ทางไปลานตั้งแคมป์/จุดสำรวจ)
	for _, s in { { 441, 481 }, { 501, 543 }, { 563, 583 }, { 617, 646 }, { 674, 725 }, { 746, 839 } } do
		BK.fence(q, 631, s[1], 631, s[2], 7, hex("6B7280"))
	end
	-- ไฟถนนท่า + เสาไฟสูง
	for z = 450, 830, 55 do
		BK.lamp(q, 640, z, hex("FFB36B"))
	end
	for _, z in { 470, 535, 740, 800 } do
		BK.lamp(q, 682.5, z, hex("FFB36B"))
	end
	floodMast(q, 638, 468)
	floodMast(q, 646, 628)
	floodMast(q, 638, 748)
	ship(f)
	crane(f, 615, 1)
	crane(f, 655, 2)
	fishingPier(f)
	harborOffice(f)
end

return DockKit
