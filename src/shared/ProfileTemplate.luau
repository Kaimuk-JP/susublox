--!strict
-- โครงข้อมูลผู้เล่น + migration ตามหมายเลขเวอร์ชัน (เสียบเข้า ProfileStore ภายหลัง)
export type Profile = {
	Version: number,
	Level: number,
	Exp: number,
	Yen: number,
	StatPoints: number,
	Stats: { Strength: number, Health: number, Stamina: number, Speed: number },
	UnlockedStyles: { string },
	Outfits: { string },
	Prestige: number,
	Wins: number,
	Losses: number,
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
		StatPoints = 0,
		Stats = { Strength = 0, Health = 0, Stamina = 0, Speed = 0 },
		UnlockedStyles = { "StreetBrawl" },
		Outfits = {},
		Prestige = 0,
		Wins = 0,
		Losses = 0,
	}
end

-- แต่ละ migration ยกเวอร์ชัน n -> n+1 เพิ่มเมื่อเปลี่ยนโครงข้อมูล
local migrations: { [number]: (data: any) -> () } = {}

function ProfileTemplate.Migrate(data: any): Profile
	local template = ProfileTemplate.new()
	for k, v in template :: any do
		if data[k] == nil then
			data[k] = v
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
