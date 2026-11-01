--!strict
-- ตัวเลขทั้งหมดเป็นค่าเริ่มต้นสำหรับทดสอบ ปรับตามผลอัลฟ่า
return table.freeze({
	BaseHealth = 100,
	BaseStamina = 100,
	CharScale = 0.88, -- สเกลตัวละครทุกตัว (ผู้เล่น/NPC/คนขี่) ให้ได้สัดส่วนกับรถและเมือง: 5.2 studs -> ~4.6 studs (~1.6 m)
	M1Damage = 5,
	ComboLength = 4,
	ComboResetTime = 1.0,
	M1Cooldown = 0.35,
	FinisherKnockback = 40,
	HitboxSize = Vector3.new(7, 6, 7), -- ขยายให้ตีโดนง่ายขึ้น (ชดเชยความหน่วงและตำแหน่งที่เหลื่อมกันระหว่างเครื่องกับ server)
	HitboxForward = 4,
	MaxHitRange = 12, -- server ตรวจระยะซ้ำ กัน client โกง
	BlockReduction = 0.8,
	BlockStaminaCost = 10,
	PerfectBlockWindow = 0.2,
	PerfectBlockStun = 1.5,
	DashCooldown = 2,
	DashStaminaCost = 20,
	DashSpeed = 60,
	DashTime = 0.18,
	StaminaRegen = 15, -- ต่อวินาที
	HitStop = 0.05,
	RemoteRateLimit = 20, -- ครั้งต่อวินาที
	UltMax = 100,
	UltPerHit = 4, -- ท่าไม้ตายชาร์จจากการโจมตีโดน
	UltPerDamageTaken = 0.2, -- ต่อ 1 ดาเมจที่โดน
	SkillHitbox = Vector3.new(9, 7, 9),
})
