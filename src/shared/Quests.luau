--!strict
-- นิยามเควสรายวัน/รายสัปดาห์ และรางวัลล็อกอินต่อเนื่อง
export type Quest = { Id: string, Name: string, Event: string, Goal: number, Yen: number, Exp: number }

local Daily: { Quest } = {
	{ Id = "d_win5", Name = "ชนะ 5 ครั้ง", Event = "Win", Goal = 5, Yen = 50, Exp = 100 },
	{ Id = "d_ult3", Name = "ใช้ท่าไม้ตาย 3 ครั้ง", Event = "Ultimate", Goal = 3, Yen = 60, Exp = 120 },
	{ Id = "d_hit50", Name = "ตีโดน 50 ครั้ง", Event = "Hit", Goal = 50, Yen = 40, Exp = 80 },
}

local Weekly: { Quest } = {
	{ Id = "w_win40", Name = "ชนะ 40 ครั้ง", Event = "Win", Goal = 40, Yen = 400, Exp = 800 },
	{ Id = "w_ult20", Name = "ใช้ท่าไม้ตาย 20 ครั้ง", Event = "Ultimate", Goal = 20, Yen = 350, Exp = 700 },
	{ Id = "w_hit500", Name = "ตีโดน 500 ครั้ง", Event = "Hit", Goal = 500, Yen = 300, Exp = 600 },
	{ Id = "w_win10pvp", Name = "ชนะผู้เล่น 10 คน", Event = "PvpWin", Goal = 10, Yen = 500, Exp = 900 },
	{ Id = "w_boss3", Name = "ล้มบอส 3 ตัว", Event = "BossKill", Goal = 3, Yen = 600, Exp = 1000 },
}

-- รางวัลล็อกอินวันที่ 1..7 (วันที่ 7 ของหายาก)
local LoginYen = { 20, 30, 40, 50, 60, 80, 200 }

return {
	Daily = Daily,
	Weekly = Weekly,
	LoginYen = LoginYen,
	DayLength = 86400,
	WeekLength = 604800,
}
