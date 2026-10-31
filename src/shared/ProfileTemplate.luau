--!strict
-- โครงข้อมูลผู้เล่น + migration ตามหมายเลขเวอร์ชัน
export type Profile = {
	Version: number,
	Level: number,
	Exp: number,
	Yen: number,
	Fame: number,
	StatPoints: number,
	Stats: { Strength: number, Health: number, Stamina: number, Speed: number },
	UnlockedStyles: { string },
	EquippedStyle: string,
	Mastery: { [string]: { Level: number, Exp: number } },
	Passives: { string },
	Outfits: { string },
	Prestige: number,
	Wins: number,
	Losses: number,
	Quests: { DailyReset: number, WeeklyReset: number, Progress: { [string]: number }, Claimed: { [string]: boolean } },
	Login: { Streak: number, Last: number },
	RankPoints: number,
	Gang: string,
	Owned: { string },
	Passes: { [string]: boolean },
	ExpBoostUntil: number,
	Receipts: { [string]: boolean },
	BattlePass: { Season: number, Xp: number, ClaimedFree: { [string]: boolean }, ClaimedPremium: { [string]: boolean } },
	TutorialDone: boolean,
}

local CURRENT_VERSION = 1

local ProfileTemplate = {}
ProfileTemplate.CurrentVersion = CURRENT_VERSION

function ProfileTemplate.new(): Profile
	return {
		Version = CURRENT_VERSION,
		Level = 1,
		Exp = 0,
		Yen = 0,
		Fame = 0,
		StatPoints = 0,
		Stats = { Strength = 0, Health = 0, Stamina = 0, Speed = 0 },
		UnlockedStyles = { "StreetBrawl" }, -- เคนโด้ปลดล็อกจากบอสหัวหน้าชมรม
		EquippedStyle = "StreetBrawl",
		Mastery = {},
		Passives = {},
		Outfits = {},
		Prestige = 0,
		Wins = 0,
		Losses = 0,
		Quests = { DailyReset = 0, WeeklyReset = 0, Progress = {}, Claimed = {} },
		Login = { Streak = 0, Last = 0 },
		RankPoints = 0,
		Gang = "",
		Owned = {},
		Passes = {},
		ExpBoostUntil = 0,
		Receipts = {},
		BattlePass = { Season = 1, Xp = 0, ClaimedFree = {}, ClaimedPremium = {} },
		TutorialDone = false,
	}
end

-- แต่ละ migration ยกเวอร์ชัน n -> n+1 เพิ่มเมื่อเปลี่ยนโครงข้อมูล
local migrations: { [number]: (data: any) -> () } = {}

-- เติมฟิลด์ที่ขาด (ลึก 1 ชั้นสำหรับ Stats) แล้วรัน migration ตามลำดับ
function ProfileTemplate.Migrate(data: any): Profile
	local template: any = ProfileTemplate.new()
	for k, v in template do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and k == "Stats" then
			for sk, sv in v do
				if data[k][sk] == nil then
					data[k][sk] = sv
				end
			end
		end
	end
	local version: number = data.Version or 0
	while version < CURRENT_VERSION do
		local step = migrations[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.Version = CURRENT_VERSION
	return data
end

return ProfileTemplate
