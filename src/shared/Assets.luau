--!strict
-- รวม asset ID ของแอนิเมชัน/เสียง ใส่ ID จริงที่สร้างหรืออัปโหลดเอง (Moon Animator 2 / Creator Store)
-- 0 = ยังไม่มี asset ระบบจะข้ามเงียบ ๆ ไม่ error (ไม่ใส่ ID ที่เดาเอา)
return {
	Animations = {
		M1_1 = 0, M1_2 = 0, M1_3 = 0, M1_4 = 0,
		Block = 0, Dash = 0, Hit = 0, Stunned = 0, Knockdown = 0, GetUp = 0,
		-- สกิลใช้ชื่อ "<Style>_<Key>" เช่น StreetBrawl_Z, Karate_Ultimate
		StreetBrawl_Z = 0, StreetBrawl_X = 0, StreetBrawl_C = 0, StreetBrawl_V = 0, StreetBrawl_Ultimate = 0,
	} :: { [string]: number },
	Sounds = {
		Punch = 0, Kick = 0, Block = 0, PerfectBlock = 0, UltReady = 0,
		LevelUp = 0, Quest = 0, ZoneYard = 0, ZoneGym = 0, BossMusic = 0,
	} :: { [string]: number },
}
