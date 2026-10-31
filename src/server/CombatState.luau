--!strict
-- State machine ต่อผู้เล่น/NPC หนึ่งตัว (ใช้ชุดเดียวกัน)
local Config = require(game.ReplicatedStorage.Shared.CombatConfig)
local Types = require(game.ReplicatedStorage.Shared.CombatTypes)
local Passives = require(game.ReplicatedStorage.Shared.Passives)

local CombatState = {}
CombatState.__index = CombatState

export type Data = {
	Character: Model,
	State: Types.State,
	Stamina: number,
	Ult: number, -- 0..UltMax
	Combo: number,
	LastM1: number,
	LastDash: number,
	BlockStart: number,
	StunUntil: number,
	RootUntil: number,
	Equipped: { string }, -- passive ที่ใส่อยู่
	IsBoss: boolean,
	Counter: { Damage: number, Until: number }?,
	DeflectUntil: number,
	SkillReady: { [string]: number }, -- ปุ่ม -> เวลาที่ใช้ได้อีกครั้ง
	LastAttacker: Model?,
}
export type CombatState = typeof(setmetatable({} :: Data, CombatState))

function CombatState.new(character: Model): CombatState
	return setmetatable({
		Character = character,
		State = "Idle" :: Types.State,
		Stamina = Config.BaseStamina,
		Ult = 0,
		Combo = 0,
		LastM1 = 0,
		LastDash = 0,
		BlockStart = 0,
		StunUntil = 0,
		RootUntil = 0,
		Equipped = {},
		IsBoss = false,
		Counter = nil,
		DeflectUntil = 0,
		SkillReady = {},
		LastAttacker = nil,
	} :: Data, CombatState)
end

function CombatState.CanAct(self: CombatState): boolean
	if (self.State == "Stunned" or self.State == "Ragdoll") and os.clock() >= self.StunUntil then
		self.State = "Idle"
	end
	return self.State == "Idle" and os.clock() >= self.RootUntil
end

function CombatState.Stun(self: CombatState, duration: number)
	self.State = "Stunned"
	self.StunUntil = os.clock() + duration * Passives.StunRecoveryMultiplier(self.Equipped)
	self.Combo = 0
end

function CombatState.Knockdown(self: CombatState, duration: number)
	self.State = "Ragdoll"
	self.StunUntil = os.clock() + duration * Passives.StunRecoveryMultiplier(self.Equipped)
	self.Combo = 0
end

function CombatState.Root(self: CombatState, duration: number)
	self.RootUntil = math.max(self.RootUntil, os.clock() + duration)
	local hum = self.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local base = hum.WalkSpeed
		hum.WalkSpeed = 0
		task.delay(duration, function()
			if hum.Parent then
				hum.WalkSpeed = base
			end
		end)
	end
end

function CombatState.Slow(self: CombatState, fraction: number, duration: number)
	local hum = self.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.WalkSpeed > 0 then
		local base = hum.WalkSpeed
		hum.WalkSpeed = base * (1 - fraction)
		task.delay(duration, function()
			if hum.Parent and hum.WalkSpeed > 0 then
				hum.WalkSpeed = base
			end
		end)
	end
end

function CombatState.AddUlt(self: CombatState, amount: number)
	self.Ult = math.min(Config.UltMax, self.Ult + amount * Passives.UltChargeMultiplier(self.Equipped))
end

function CombatState.Regen(self: CombatState, dt: number)
	if self.State ~= "Blocking" then
		local max = (self.Character:GetAttribute("MaxStamina") :: number?) or Config.BaseStamina
		self.Stamina = math.min(max, self.Stamina + Config.StaminaRegen * dt)
	end
end

return CombatState
