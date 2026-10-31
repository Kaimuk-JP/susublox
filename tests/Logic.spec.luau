--!strict
-- เทสต์ตรรกะล้วน รันได้ทั้งใน Studio command bar (วางโค้ดหรือ require ผ่าน ModuleScript) และ Luau CLI/Lune
-- ตั้ง package.path ให้ชี้ src/shared ถ้ารันนอก Studio
local function load(name: string): any
	local ok, rs = pcall(function()
		return game:GetService("ReplicatedStorage")
	end)
	if ok and rs and rs:FindFirstChild("Shared") then
		return require(rs.Shared[name])
	end
	return require(`../src/shared/{name}`)
end

local Progression = load("Progression")
local Passives = load("Passives")
local ProfileTemplate = load("ProfileTemplate")

local failures = 0
local function check(name: string, cond: boolean)
	if not cond then
		failures += 1
		print(`FAIL: {name}`)
	else
		print(`ok:   {name}`)
	end
end

-- Progression
check("ExpForLevel(1) = 100", Progression.ExpForLevel(1) == 100)
check("ExpForLevel(4) = 800", Progression.ExpForLevel(4) == 800)
local lv, exp, pts = Progression.AddExp(1, 0, 100, 0)
check("100 EXP: level 1 -> 2, 3 stat points", lv == 2 and exp == 0 and pts == 3)
lv, exp, pts = Progression.AddExp(1, 0, 99, 0)
check("99 EXP: ยังไม่ขึ้นเลเวล", lv == 1 and exp == 99 and pts == 0)
lv = Progression.AddExp(1, 0, 100, 1) -- Prestige 1 = +10% -> 110 EXP
check("Prestige bonus +10%", lv == 2)
lv, exp = Progression.AddExp(99, 0, 1e9, 0)
check("เลเวลไม่เกิน 100 และ EXP รีเซ็ต", lv == 100 and exp == 0)
local _, _, multi = Progression.AddExp(1, 0, 100 + 283, 0) -- 100 + floor(100*2^1.5)=282 -> 2 เลเวล
check("ขึ้นหลายเลเวลในครั้งเดียว ได้แต้มรวม", multi == 6)

-- Passives
check("ใจสู้ ต้องเลือด <30%", Passives.DamageMultiplier({ "FightingSpirit" }, 0.2, false) == 1.15)
check("ใจสู้ ไม่ทำงานที่เลือดเต็ม", Passives.DamageMultiplier({ "FightingSpirit" }, 1, false) == 1)
check("นักล่าบอส +20% เฉพาะบอส", Passives.DamageMultiplier({ "BossHunter" }, 1, true) == 1.2)
check("เท้าไฟ -25% คูลดาวน์", Passives.DashCooldownMultiplier({ "FireFeet" }) == 0.75)
check("ปลดล็อกตามเลเวล", not Passives.CanEquip(4, "FightingSpirit") and Passives.CanEquip(5, "FightingSpirit"))

-- ProfileTemplate
local migrated = ProfileTemplate.Migrate({ Level = 7, Stats = { Strength = 2 } })
check("Migrate คงค่าเดิม", migrated.Level == 7 and migrated.Stats.Strength == 2)
check("Migrate เติมฟิลด์ที่ขาด", migrated.Stats.Speed == 0 and migrated.EquippedStyle == "StreetBrawl")
check("Migrate ตั้งเวอร์ชันล่าสุด", migrated.Version == ProfileTemplate.CurrentVersion)

print(if failures == 0 then "ทุกเทสต์ผ่าน" else `{failures} เทสต์ไม่ผ่าน`)
return failures
