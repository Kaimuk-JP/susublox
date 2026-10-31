--!strict
-- ข้อมูลโลกเปิด: ย่านต่าง ๆ รอบโรงเรียน ถนน และภารกิจ (พิกัดโรงเรียนอยู่ที่ศูนย์กลาง ห้ามขยับโซนเดิม)
export type District = {
	Id: string,
	Name: string,
	Theme: string,
	Center: Vector3,
	Radius: number,
	Levels: { number }, -- {ต่ำสุด, สูงสุด}
	EnemyName: string,
	EnemyColor: string,
	BossName: string,
	BossOffset: Vector3, -- ตำแหน่งบอสเทียบศูนย์กลางย่าน
	GiverName: string,
	GiverOffset: Vector3,
	Pois: { Vector3 }, -- จุดสำรวจ (เทียบศูนย์กลาง)
}

local Districts: { District } = {
	{
		Id = "SakuraPark", Name = "สวนซากุระ", Theme = "park", Center = Vector3.new(-420, 0, 170), Radius = 130,
		Levels = { 3, 7 }, EnemyName = "นักเลงสวน", EnemyColor = "FF8FAB", BossName = "เจ้าพ่อสวนซากุระ",
		BossOffset = Vector3.new(-30, 0, -70), GiverName = "มิกะ", GiverOffset = Vector3.new(40, 0, -48),
		Pois = { Vector3.new(-80, 0, -20), Vector3.new(60, 0, -90), Vector3.new(90, 0, 60) },
	},
	{
		Id = "Shotengai", Name = "ถนนการค้า", Theme = "town", Center = Vector3.new(420, 0, 170), Radius = 130,
		Levels = { 7, 13 }, EnemyName = "นักเลงตลาด", EnemyColor = "FFB36B", BossName = "หัวหน้าอีกาไฟนีออน",
		BossOffset = Vector3.new(40, 0, 60), GiverName = "คุณลุงร้านราเมน", GiverOffset = Vector3.new(-10, 0, 10.5),
		Pois = { Vector3.new(-90, 0, 40), Vector3.new(80, 0, -40), Vector3.new(0, 0, 90) },
	},
	{
		Id = "ForestCamp", Name = "ค่ายในป่า", Theme = "forest", Center = Vector3.new(-700, 0, -100), Radius = 130,
		Levels = { 9, 15 }, EnemyName = "โจรป่า", EnemyColor = "4FA06A", BossName = "หัวหน้าโจรป่า",
		BossOffset = Vector3.new(30, 0, -10), GiverName = "ลุงนักสำรวจ", GiverOffset = Vector3.new(60, 0, 70),
		Pois = { Vector3.new(-70, 0, -60), Vector3.new(20, 0, 80), Vector3.new(-30, 0, 20) },
	},
	{
		Id = "Downtown", Name = "ย่านสถานีรถไฟ", Theme = "city", Center = Vector3.new(0, 0, 600), Radius = 190,
		Levels = { 12, 20 }, EnemyName = "แก๊งสถานี", EnemyColor = "7EC8E3", BossName = "เจ้าแห่งสถานี",
		BossOffset = Vector3.new(170, 0, 15), GiverName = "เจ้าหน้าที่สถานี", GiverOffset = Vector3.new(100, 0, -9),
		Pois = { Vector3.new(-150, 0, 0), Vector3.new(60, 0, -60), Vector3.new(260, 0, 0) },
	},
	{
		Id = "TempleHill", Name = "ศาลเจ้าบนเนิน", Theme = "temple", Center = Vector3.new(700, 0, -150), Radius = 120,
		Levels = { 16, 24 }, EnemyName = "นักรบศาลเจ้า", EnemyColor = "EF233C", BossName = "ผู้พิทักษ์ศาลเจ้า",
		BossOffset = Vector3.new(0, 27, -16), GiverName = "แม่ชีศาลเจ้า", GiverOffset = Vector3.new(0, 0, 78),
		Pois = { Vector3.new(15, 27, 0), Vector3.new(-70, 0, 20), Vector3.new(70, 0, 20) },
	},
	{
		Id = "Kurogane", Name = "โรงเรียนคุโรกาเนะ", Theme = "rivalSchool", Center = Vector3.new(-750, 0, 600), Radius = 150,
		Levels = { 20, 30 }, EnemyName = "นักเรียนคุโรกาเนะ", EnemyColor = "9B7BFF", BossName = "ประธานแก๊งคุโรกาเนะ",
		BossOffset = Vector3.new(0, 0, 10), GiverName = "นักเรียนผู้ทรยศ", GiverOffset = Vector3.new(-60, 0, 70),
		Pois = { Vector3.new(-90, 0, -30), Vector3.new(90, 0, -30), Vector3.new(0, 0, -70) },
	},
	{
		Id = "Docks", Name = "ท่าเรืออุตสาหกรรม", Theme = "industrial", Center = Vector3.new(750, 0, 620), Radius = 150,
		Levels = { 28, 40 }, EnemyName = "คนงานแก๊งท่าเรือ", EnemyColor = "FFE066", BossName = "ราชาแห่งท่าเรือ",
		BossOffset = Vector3.new(60, 0, -20), GiverName = "กัปตันเรือ", GiverOffset = Vector3.new(-80, 0, 70),
		Pois = { Vector3.new(-80, 0, -35), Vector3.new(90, 0, 40), Vector3.new(0, 0, -100) },
	},
}

-- ถนนเชื่อมย่าน (แนวแกน): {x1, z1, x2, z2, กว้าง}
local Roads = {
	{ -1000, 170, 1000, 170, 16 }, -- ถนนสายหลัก ผ่านสวนซากุระ-โรงเรียน-ถนนการค้า
	{ -90, 170, -90, 600, 14 }, -- ลงใต้ไปย่านสถานี
	{ -800, 600, 800, 600, 14 }, -- ถนนย่านสถานี-คุโรกาเนะ-ท่าเรือ
	{ -560, -100, -560, 170, 14 }, -- ขึ้นเหนือไปค่ายในป่า
	{ -700, -100, -560, -100, 14 },
	{ 560, -150, 560, 170, 14 }, -- ขึ้นเหนือไปศาลเจ้า
	{ 560, -86, 700, -86, 14 }, -- ต่อถึงเชิงบันไดศาลเจ้า (ฐานเนินอยู่ที่ z=-90)
}

-- พื้นที่ปูแข็งของแต่ละย่าน (Terrain ใต้เป็นวัสดุเมือง ไม่ใช่หญ้า): {x1, x2, z1, z2, วัสดุ}
local Paved = {
	{ 285, 555, 130, 212, "Cobblestone" }, -- ถนนการค้า
	{ -300, 300, 555, 645, "Pavement" }, -- ย่านสถานี แถวตึกตะวันออก-ตะวันตก
	{ -135, -45, 230, 560, "Pavement" }, -- ย่านสถานี แถวตึกเหนือ-ใต้
	{ 100, 240, 640, 730, "Pavement" }, -- สถานี + ชานชาลา
	{ 625, 872, 490, 745, "Concrete" }, -- ท่าเรือ (ลานตู้คอนเทนเนอร์)
	{ -860, -640, 520, 715, "Pavement" }, -- โรงเรียนคุโรกาเนะ
}

-- เนินที่ปั้นด้วย Terrain: ลาดชันคงที่ r0..r1 ยอดราบสูง top (บันไดศาลเจ้าวิ่งตามแนวลาดนี้)
local Hills = {
	{ x = 700, z = -150, r0 = 22, r1 = 58, top = 27 },
}

-- แอ่งน้ำ (ขุด Terrain แล้วเติมน้ำ): กล่อง {x1, x2, z1, z2}
local Water = {
	{ 875, 985, 430, 850 }, -- อ่าวท่าเรือ
}

local Bounds = { MinX = -1050, MaxX = 1050, MinZ = -450, MaxZ = 960 }

return {
	Districts = Districts,
	Roads = Roads,
	Paved = Paved,
	Hills = Hills,
	Water = Water,
	Bounds = Bounds,
	-- ความสูงเนินที่ระยะ r จากศูนย์กลาง (ใช้ทั้ง TerrainBake และตอนวางบันได/ต้นไม้)
	HillHeight = function(h: { x: number, z: number, r0: number, r1: number, top: number }, r: number): number
		if r <= h.r0 then
			return h.top
		elseif r >= h.r1 then
			return 0
		end
		return h.top * (h.r1 - r) / (h.r1 - h.r0)
	end,
	ById = function(id: string): District?
		for _, d in Districts do
			if d.Id == id then
				return d
			end
		end
		return nil
	end,
}
