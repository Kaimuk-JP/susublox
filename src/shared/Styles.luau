--!strict
-- ข้อมูลสไตล์และสกิลทั้งหมด (data-driven) ตัวเลขเป็นค่าเริ่มต้นสำหรับทดสอบ ปรับตามอัลฟ่า
export type Skill = {
	Name: string,
	Kind: string, -- Melee | Dash | AoE | Multi | Counter | Deflect | Teleport | Charge | Grapple
	Damage: number,
	Cooldown: number,
	Range: number?, -- ระยะ hitbox / ระยะพุ่ง
	Radius: number?,
	Hits: number?,
	Stun: number?,
	Knockdown: number?,
	Knockback: number?,
	Pierce: boolean?, -- ทะลุบล็อก
	Root: number?,
	Slow: number?, -- เศษส่วนที่ลดความเร็ว
	SlowTime: number?,
	Duration: number?,
}

export type Style = {
	Name: string,
	UnlockLevel: number?,
	Skills: { Z: Skill, X: Skill, C: Skill, V: Skill },
	Ultimate: Skill,
}

local Styles: { [string]: Style } = {
	StreetBrawl = {
		Name = "ต่อยข้างถนน",
		Skills = {
			Z = { Name = "หมัดพุ่ง", Kind = "Dash", Damage = 12, Cooldown = 6, Range = 10 },
			X = { Name = "เตะตัดขา", Kind = "Melee", Damage = 8, Cooldown = 8, Knockdown = 1 },
			C = { Name = "หัวโขก", Kind = "Melee", Damage = 15, Cooldown = 12, Pierce = true, Stun = 1.5 },
			V = { Name = "รัวหมัด", Kind = "Multi", Damage = 24, Cooldown = 15, Hits = 8 },
		},
		Ultimate = { Name = "หมัดเดือดข้างถนน", Kind = "Melee", Damage = 45, Cooldown = 0, Knockback = 60 },
	},
	Karate = {
		Name = "คาราเต้",
		UnlockLevel = 10,
		Skills = {
			Z = { Name = "ชกตรงสายฟ้า", Kind = "Melee", Damage = 10, Cooldown = 4 },
			X = { Name = "เตะหมุน", Kind = "AoE", Damage = 12, Cooldown = 8, Radius = 8 },
			C = { Name = "ท่ารับสวน", Kind = "Counter", Damage = 20, Cooldown = 14, Duration = 1 },
			V = { Name = "คอมโบลมกรด", Kind = "Multi", Damage = 25, Cooldown = 16, Hits = 5 },
		},
		Ultimate = { Name = "ทะลวงอิฐสิบก้อน", Kind = "Melee", Damage = 50, Cooldown = 0, Pierce = true },
	},
	Judo = {
		Name = "ยูโด",
		UnlockLevel = 20,
		Skills = {
			Z = { Name = "คว้าคอเสื้อ", Kind = "Grapple", Damage = 6, Cooldown = 7, Range = 20, Pierce = true },
			X = { Name = "ทุ่มข้ามไหล่", Kind = "Melee", Damage = 18, Cooldown = 10, Pierce = true, Knockdown = 1 },
			C = { Name = "ปัดขา", Kind = "Melee", Damage = 10, Cooldown = 9, Knockdown = 1.5 },
			V = { Name = "ล็อกพื้น", Kind = "Melee", Damage = 20, Cooldown = 18, Root = 2 },
		},
		Ultimate = { Name = "ทุ่มพายุ", Kind = "AoE", Damage = 55, Cooldown = 0, Radius = 12, Knockdown = 1 },
	},
	Wrestling = {
		Name = "มวยปล้ำ",
		UnlockLevel = 30,
		Skills = {
			Z = { Name = "กระแทกไหล่", Kind = "Charge", Damage = 15, Cooldown = 8, Range = 16 },
			X = { Name = "ฟาดแขน", Kind = "Melee", Damage = 16, Cooldown = 10, Knockback = 45 },
			C = { Name = "ยกทุ่มหลัง", Kind = "Melee", Damage = 22, Cooldown = 12, Pierce = true, Knockdown = 1 },
			V = { Name = "กระโดดทับ", Kind = "AoE", Damage = 18, Cooldown = 14, Radius = 10 },
		},
		Ultimate = { Name = "ทุ่มสะเทือนโรงยิม", Kind = "AoE", Damage = 60, Cooldown = 0, Radius = 14, Knockdown = 2 },
	},
	Kendo = {
		Name = "เคนโด้",
		Skills = {
			Z = { Name = "ฟันศีรษะ", Kind = "Melee", Damage = 14, Cooldown = 5, Range = 8 },
			X = { Name = "ฟันผ่านลำตัว", Kind = "Dash", Damage = 12, Cooldown = 7, Range = 14 },
			C = { Name = "แทงทะลวง", Kind = "Melee", Damage = 16, Cooldown = 10, Range = 12, Knockback = 30 },
			V = { Name = "ท่าเบี่ยงดาบ", Kind = "Deflect", Damage = 0, Cooldown = 15, Duration = 1.5 },
		},
		Ultimate = { Name = "พันดาบซากุระ", Kind = "AoE", Damage = 50, Cooldown = 0, Radius = 15 },
	},
	ShadowFist = {
		Name = "หมัดเงา",
		Skills = {
			Z = { Name = "ก้าวเงา", Kind = "Teleport", Damage = 0, Cooldown = 8, Range = 40 },
			X = { Name = "ฝ่ามือเงา", Kind = "Melee", Damage = 15, Cooldown = 9, Slow = 0.3, SlowTime = 3 },
			C = { Name = "ร่างแยก", Kind = "Deflect", Damage = 0, Cooldown = 16, Duration = 3 },
			V = { Name = "เงาพันธนาการ", Kind = "Melee", Damage = 18, Cooldown = 18, Root = 1.5 },
		},
		Ultimate = { Name = "ราตรีนิรันดร์", Kind = "Multi", Damage = 65, Cooldown = 0, Hits = 5 },
	},
}

-- Mastery ที่ต้องมีเพื่อใช้สกิลแต่ละปุ่ม (ทุกสไตล์เหมือนกัน)
local MasteryUnlock = table.freeze({ Z = 1, X = 10, C = 25, V = 40, Ultimate = 60 })

return {
	Styles = Styles,
	MasteryUnlock = MasteryUnlock,
	MaxMastery = 100,
	-- Mastery EXP ที่ต้องใช้ขึ้นจากเลเวลนี้
	MasteryExp = function(level: number): number
		return 50 + level * 25
	end,
}
