--!strict
-- Live ops: อีเวนต์ตามตารางเวลา + feature flag เปิด/ปิดจากเซิร์ฟเวอร์ (ไม่ต้องอัปเดตเกม)
local Players = game:GetService("Players")

local LiveOps = {}

-- เปิด/ปิดอีเวนต์ด้วย flag (เปลี่ยนค่าได้โดยไม่แก้ตรรกะ ต่อยอดไปอ่านจาก MessagingService/DataStore ได้)
LiveOps.Flags = {
	WeekendBoost = true,
	LaunchWeek = false, -- EXP x2 ช่วงเปิดตัว 7 วัน
	WanderingBoss = true,
} :: { [string]: boolean }

-- รายวัน: สลับ EXP x2 / เงิน x2 ตามวันที่ (เสาร์-อาทิตย์ UTC+7)
local function thaiDayOfWeek(): number
	return os.date("!*t", os.time() + 7 * 3600).wday -- 1=อาทิตย์ .. 7=เสาร์
end

function LiveOps.ExpMultiplier(): number
	local m = 1
	if LiveOps.Flags.LaunchWeek then
		m *= 2
	end
	local d = thaiDayOfWeek()
	if LiveOps.Flags.WeekendBoost and (d == 1 or d == 7) and os.date("!*t", os.time() + 7 * 3600).yday % 2 == 0 then
		m *= 2
	end
	return m
end

function LiveOps.YenMultiplier(): number
	local d = thaiDayOfWeek()
	if LiveOps.Flags.WeekendBoost and (d == 1 or d == 7) and os.date("!*t", os.time() + 7 * 3600).yday % 2 == 1 then
		return 2
	end
	return 1
end

-- บอสพเนจรทุกวัน 20:00 (เวลาไทย) นาน 15 นาที
function LiveOps.WanderingBossActive(): boolean
	if not LiveOps.Flags.WanderingBoss then
		return false
	end
	local t = os.date("!*t", os.time() + 7 * 3600)
	return t.hour == 20 and t.min < 15
end

-- ประกาศให้ผู้เล่นเห็นผ่าน Attribute ของ Workspace (HUD/เมนูอ่านได้)
task.spawn(function()
	while true do
		workspace:SetAttribute("ExpMultiplier", LiveOps.ExpMultiplier())
		workspace:SetAttribute("YenMultiplier", LiveOps.YenMultiplier())
		workspace:SetAttribute("WanderingBoss", LiveOps.WanderingBossActive())
		task.wait(30)
	end
end)

return LiveOps
