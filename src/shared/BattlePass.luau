--!strict
-- Battle Pass ต่อซีซัน: สายฟรี + สายพรีเมียม ไม่ขายพลังโจมตี (เยน ชุด บูสต์ EXP เท่านั้น)
export type Reward = { Yen: number?, Outfit: string?, ExpBoost: number? }

local TIERS = 30
local XP_PER_TIER = 500

local free: { [number]: Reward } = {}
local premium: { [number]: Reward } = {}

for tier = 1, TIERS do
	free[tier] = { Yen = 20 + tier * 5 }
	premium[tier] = { Yen = 40 + tier * 10 }
end
-- รางวัลพิเศษตามขั้น
free[10] = { Yen = 200 }
free[30] = { Outfit = "Uniform_Sakura" }
premium[5] = { ExpBoost = 1800 }
premium[15] = { Outfit = "Uniform_Night" }
premium[25] = { ExpBoost = 3600 }
premium[30] = { Outfit = "Jacket_Gang" }

return {
	Season = 1,
	Tiers = TIERS,
	XpPerTier = XP_PER_TIER,
	Free = free,
	Premium = premium,
	TierOf = function(xp: number): number
		return math.min(TIERS, xp // XP_PER_TIER)
	end,
}
