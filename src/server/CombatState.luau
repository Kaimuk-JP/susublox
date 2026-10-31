--!strict
-- State machine ต่อผู้เล่น/NPC หนึ่งตัว (ใช้ชุดเดียวกัน)
local Config = require(game.ReplicatedStorage.Shared.CombatConfig)
local Types = require(game.ReplicatedStorage.Shared.CombatTypes)

local CombatState = {}
CombatState.__index = CombatState

export type CombatState = typeof(setmetatable(
	{} :: {
		Character: Model,
		State: Types.State,
		Stamina: number,
		Combo: number,
		LastM1: number,
		LastDash: number,
		BlockStart: number,
		StunUntil: number,
	},
	CombatState
))

function CombatState.new(character: Model): CombatState
	return setmetatable({
		Character = character,
		State = "Idle" :: Types.State,
		Stamina = Config.BaseStamina,
		Combo = 0,
		LastM1 = 0,
		LastDash = 0,
		BlockStart = 0,
		StunUntil = 0,
	}, CombatState)
end

function CombatState.CanAct(self: CombatState): boolean
	if self.State == "Stunned" and os.clock() >= self.StunUntil then
		self.State = "Idle"
	end
	return self.State == "Idle"
end

function CombatState.Stun(self: CombatState, duration: number)
	self.State = "Stunned"
	self.StunUntil = os.clock() + duration
	self.Combo = 0
end

function CombatState.Regen(self: CombatState, dt: number)
	if self.State ~= "Blocking" then
		self.Stamina = math.min(Config.BaseStamina, self.Stamina + Config.StaminaRegen * dt)
	end
end

return CombatState
