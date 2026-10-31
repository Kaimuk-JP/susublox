--!strict
-- ภารกิจในโลกเปิด: ผู้ให้ภารกิจประจำย่านให้ภารกิจตามลำดับ (ต้องทำเสร็จข้อก่อนหน้า + เลเวลถึง)
-- Kind: Kill (ล้มศัตรูในย่าน), Collect (เก็บของในย่าน), Explore (ไปยังจุดสำรวจ), Boss (ล้มบอสประจำย่าน)
export type Quest = {
	Id: string,
	District: string,
	Name: string,
	Desc: string,
	Kind: string,
	Count: number,
	ReqLevel: number,
	Reward: { Yen: number, Exp: number, Fame: number, Outfit: string? },
}

local list: { Quest } = {
	-- สวนซากุระ
	{ Id = "sp1", District = "SakuraPark", Name = "กลีบซากุระที่หายไป", Desc = "ลมพัดกลีบซากุระวิเศษหายไป ช่วยเก็บกลับมา 5 กลีบ (ของเรืองแสงในสวน)", Kind = "Collect", Count = 5, ReqLevel = 1, Reward = { Yen = 120, Exp = 200, Fame = 5 } },
	{ Id = "sp2", District = "SakuraPark", Name = "ไล่นักเลงสวน", Desc = "นักเลงมารังแกคนเดินเล่น ล้มนักเลงในสวน 8 คน", Kind = "Kill", Count = 8, ReqLevel = 3, Reward = { Yen = 220, Exp = 350, Fame = 10 } },
	{ Id = "sp3", District = "SakuraPark", Name = "สำรวจสวนซากุระ", Desc = "ไปดูจุดเรืองแสง 3 จุดในสวน เพื่อหาร่องรอยหัวหน้า", Kind = "Explore", Count = 3, ReqLevel = 4, Reward = { Yen = 200, Exp = 300, Fame = 10 } },
	{ Id = "sp4", District = "SakuraPark", Name = "เจ้าพ่อสวนซากุระ", Desc = "ล้มเจ้าพ่อสวนซากุระ หัวหน้านักเลงแถวนี้", Kind = "Boss", Count = 1, ReqLevel = 5, Reward = { Yen = 600, Exp = 900, Fame = 40, Outfit = "Uniform_Sakura" } },
	-- ถนนการค้า
	{ Id = "st1", District = "Shotengai", Name = "พัสดุตกหล่น", Desc = "กล่องพัสดุของร้านค้าหล่นกระจาย เก็บให้ครบ 6 กล่อง", Kind = "Collect", Count = 6, ReqLevel = 7, Reward = { Yen = 350, Exp = 700, Fame = 10 } },
	{ Id = "st2", District = "Shotengai", Name = "ปราบนักเลงตลาด", Desc = "ล้มนักเลงตลาด 12 คน", Kind = "Kill", Count = 12, ReqLevel = 8, Reward = { Yen = 500, Exp = 1000, Fame = 15 } },
	{ Id = "st3", District = "Shotengai", Name = "ลาดตระเวนถนนการค้า", Desc = "เดินสำรวจ 3 จุดบนถนนการค้า", Kind = "Explore", Count = 3, ReqLevel = 9, Reward = { Yen = 420, Exp = 800, Fame = 10 } },
	{ Id = "st4", District = "Shotengai", Name = "หัวหน้าอีกาไฟนีออน", Desc = "ล้มหัวหน้าอีกาไฟนีออน ผู้คุมถนนการค้า", Kind = "Boss", Count = 1, ReqLevel = 10, Reward = { Yen = 1200, Exp = 2200, Fame = 60 } },
	-- ค่ายในป่า
	{ Id = "fc1", District = "ForestCamp", Name = "ร่องรอยในป่า", Desc = "ตามหาจุดต้องสงสัย 3 จุดในป่า", Kind = "Explore", Count = 3, ReqLevel = 9, Reward = { Yen = 450, Exp = 1000, Fame = 10 } },
	{ Id = "fc2", District = "ForestCamp", Name = "กวาดล้างโจรป่า", Desc = "ล้มโจรป่า 14 คน", Kind = "Kill", Count = 14, ReqLevel = 10, Reward = { Yen = 700, Exp = 1500, Fame = 20 } },
	{ Id = "fc3", District = "ForestCamp", Name = "หัวหน้าโจรป่า", Desc = "ล้มหัวหน้าโจรป่าที่ค่ายกลางป่า", Kind = "Boss", Count = 1, ReqLevel = 12, Reward = { Yen = 1800, Exp = 3200, Fame = 70 } },
	-- ย่านสถานีรถไฟ
	{ Id = "dt1", District = "Downtown", Name = "ของหายที่สถานี", Desc = "เก็บกระเป๋าที่ผู้โดยสารทำหล่น 8 ใบ", Kind = "Collect", Count = 8, ReqLevel = 12, Reward = { Yen = 800, Exp = 1800, Fame = 15 } },
	{ Id = "dt2", District = "Downtown", Name = "เคลียร์สถานี", Desc = "ล้มแก๊งสถานี 16 คน", Kind = "Kill", Count = 16, ReqLevel = 14, Reward = { Yen = 1100, Exp = 2600, Fame = 25 } },
	{ Id = "dt3", District = "Downtown", Name = "ตรวจชานชาลา", Desc = "ไปตรวจจุดน่าสงสัย 3 จุดรอบสถานี", Kind = "Explore", Count = 3, ReqLevel = 15, Reward = { Yen = 900, Exp = 2000, Fame = 15 } },
	{ Id = "dt4", District = "Downtown", Name = "เจ้าแห่งสถานี", Desc = "ล้มเจ้าแห่งสถานี หัวหน้าแก๊งย่านนี้", Kind = "Boss", Count = 1, ReqLevel = 17, Reward = { Yen = 2800, Exp = 5000, Fame = 90, Outfit = "Uniform_Night" } },
	-- ศาลเจ้าบนเนิน
	{ Id = "th1", District = "TempleHill", Name = "ขึ้นบันไดศาลเจ้า", Desc = "ขึ้นไปถึงยอดเนิน และสำรวจ 3 จุดของศาลเจ้า", Kind = "Explore", Count = 3, ReqLevel = 16, Reward = { Yen = 1000, Exp = 2800, Fame = 20 } },
	{ Id = "th2", District = "TempleHill", Name = "ปราบนักรบศาลเจ้า", Desc = "ล้มนักรบศาลเจ้า 14 คน", Kind = "Kill", Count = 14, ReqLevel = 18, Reward = { Yen = 1500, Exp = 3800, Fame = 30 } },
	{ Id = "th3", District = "TempleHill", Name = "ผู้พิทักษ์ศาลเจ้า", Desc = "ล้มผู้พิทักษ์ศาลเจ้าที่ยอดเนิน", Kind = "Boss", Count = 1, ReqLevel = 20, Reward = { Yen = 3500, Exp = 6500, Fame = 110 } },
	-- โรงเรียนคุโรกาเนะ
	{ Id = "kg1", District = "Kurogane", Name = "ลอบเข้าคุโรกาเนะ", Desc = "สำรวจ 3 จุดในโรงเรียนคู่แข่ง", Kind = "Explore", Count = 3, ReqLevel = 20, Reward = { Yen = 1600, Exp = 4200, Fame = 25 } },
	{ Id = "kg2", District = "Kurogane", Name = "ล้มนักเรียนคุโรกาเนะ", Desc = "ล้มนักเรียนคุโรกาเนะ 20 คน", Kind = "Kill", Count = 20, ReqLevel = 22, Reward = { Yen = 2400, Exp = 6000, Fame = 40 } },
	{ Id = "kg3", District = "Kurogane", Name = "ประธานแก๊งคุโรกาเนะ", Desc = "ล้มประธานแก๊งคุโรกาเนะ ศัตรูตัวฉกาจของโรงเรียนเรา", Kind = "Boss", Count = 1, ReqLevel = 25, Reward = { Yen = 6000, Exp = 10000, Fame = 160, Outfit = "Jacket_Gang" } },
	-- ท่าเรืออุตสาหกรรม
	{ Id = "dk1", District = "Docks", Name = "ลังสินค้าสูญหาย", Desc = "เก็บลังสินค้า 10 ลังที่ตกหล่นแถวท่าเรือ", Kind = "Collect", Count = 10, ReqLevel = 28, Reward = { Yen = 2800, Exp = 8000, Fame = 30 } },
	{ Id = "dk2", District = "Docks", Name = "กวาดล้างท่าเรือ", Desc = "ล้มคนงานแก๊งท่าเรือ 25 คน", Kind = "Kill", Count = 25, ReqLevel = 30, Reward = { Yen = 4000, Exp = 11000, Fame = 50 } },
	{ Id = "dk3", District = "Docks", Name = "ราชาแห่งท่าเรือ", Desc = "ล้มราชาแห่งท่าเรือ บอสสุดท้ายของโลกนี้", Kind = "Boss", Count = 1, ReqLevel = 34, Reward = { Yen = 12000, Exp = 20000, Fame = 300, Outfit = "Aura_Sparkle" } },
}

local byId: { [string]: Quest } = {}
for _, q in list do
	byId[q.Id] = q
end

return {
	List = list,
	ById = byId,
	MaxActive = 4,
	-- ภารกิจของย่านตามลำดับ
	ForDistrict = function(district: string): { Quest }
		local out = {}
		for _, q in list do
			if q.District == district then
				table.insert(out, q)
			end
		end
		return out
	end,
}
