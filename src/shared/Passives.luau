--!strict
-- สกิลติดตัว ใส่ได้ 2 ช่อง ปลดล็อกตามเลเวลหลัก
export type Passive = { Name: string, UnlockLevel: number, Desc: string }

local Passives: { [string]: Passive } = {
	FightingSpirit = { Name = "ใจสู้", UnlockLevel = 5, Desc = "เลือดต่ำกว่า 30% ดาเมจ +15%" },
	QuickRecovery = { Name = "ฟื้นตัวไว", UnlockLevel = 15, Desc = "ลุกจากการล้ม/มึนเร็วขึ้น 40%" },
	FireFeet = { Name = "เท้าไฟ", UnlockLevel = 25, Desc = "คูลดาวน์การหลบ (Dash) ลด 25%" },
	IronWall = { Name = "กำแพงเหล็ก", UnlockLevel = 40, Desc = "บล็อกเสียพลังงานน้อยลง 30%" },
	BossHunter = { Name = "นักล่าบอส", UnlockLevel = 60, Desc = "ดาเมจต่อบอสเพิ่ม 20%" },
	King = { Name = "ราชันย์", UnlockLevel = 80, Desc = "หลอดท่าไม้ตายชาร์จเร็วขึ้น 20%" },
}

local MAX_SLOTS = 2

local function has(equipped: { string }, id: string): boolean
	return table.find(equipped, id) ~= nil
end

local M = {}
M.All = Passives
M.MaxSlots = MAX_SLOTS

function M.CanEquip(level: number, id: string): boolean
	local p = Passives[id]
	return p ~= nil and level >= p.UnlockLevel
end

function M.DamageMultiplier(equipped: { string }, healthFraction: number, victimIsBoss: boolean): number
	local m = 1
	if has(equipped, "FightingSpirit") and healthFraction < 0.3 then
		m *= 1.15
	end
	if has(equipped, "BossHunter") and victimIsBoss then
		m *= 1.20
	end
	return m
end

function M.DashCooldownMultiplier(equipped: { string }): number
	return has(equipped, "FireFeet") and 0.75 or 1
end

function M.BlockCostMultiplier(equipped: { string }): number
	return has(equipped, "IronWall") and 0.7 or 1
end

function M.StunRecoveryMultiplier(equipped: { string }): number
	return has(equipped, "QuickRecovery") and 0.6 or 1
end

function M.UltChargeMultiplier(equipped: { string }): number
	return has(equipped, "King") and 1.2 or 1
end

return M
