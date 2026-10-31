--!strict
-- สูตรเลเวลและสเตตัส (ตัวเลขเริ่มต้น ปรับตามอัลฟ่า)
local Progression = {}

Progression.MaxLevel = 100
Progression.StatPointsPerLevel = 3
Progression.PrestigeExpBonus = 0.10
Progression.Stats = table.freeze({ "Strength", "Health", "Stamina", "Speed" })

-- EXP ที่ต้องใช้เพื่อขึ้นจากเลเวลนี้ไปเลเวลถัดไป
function Progression.ExpForLevel(level: number): number
	return math.floor(100 * level ^ 1.5)
end

-- คืนค่าเลเวลและ EXP คงเหลือหลังเพิ่ม EXP (รวมโบนัส Prestige)
function Progression.AddExp(level: number, exp: number, gained: number, prestige: number): (number, number, number)
	exp += gained * (1 + Progression.PrestigeExpBonus * prestige)
	local points = 0
	while level < Progression.MaxLevel and exp >= Progression.ExpForLevel(level) do
		exp -= Progression.ExpForLevel(level)
		level += 1
		points += Progression.StatPointsPerLevel
	end
	if level >= Progression.MaxLevel then
		exp = 0
	end
	return level, exp, points
end

return Progression
