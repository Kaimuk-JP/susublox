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
	StunImmuneUntil: number,
	MoveLock: boolean,
	SlowUntil: number,
	SlowFactor: number,
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
		StunImmuneUntil = 0,
		MoveLock = false,
		SlowUntil = 0,
		SlowFactor = 0,
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

-- ผู้เล่นที่ถูกมอนรุมต้องไม่ติดสตันตลอด: หลังหลุดสตัน/ลุกจากล้มมีช่วงภูมิคุ้มกันสตัน (กันสตันล็อก)
local STUN_IMMUNITY = 0.7
local KNOCKDOWN_IMMUNITY = 1.2

local function isPlayer(self: CombatState): boolean
	return game:GetService("Players"):GetPlayerFromCharacter(self.Character) ~= nil
end

function CombatState.Stun(self: CombatState, duration: number)
	local now = os.clock()
	if isPlayer(self) and now < self.StunImmuneUntil then
		return
	end
	if self.State == "Ragdoll" and now < self.StunUntil then
		return -- ล้มอยู่ ไม่ให้โดนตีแล้วลุกเร็วกว่ากำหนด
	end
	local d = duration * Passives.StunRecoveryMultiplier(self.Equipped)
	self.State = "Stunned"
	self.MoveLock = d >= 0.35 -- สะดุ้งสั้นๆ ยังเดินได้ สตันนานเดินไม่ได้
	self.StunUntil = now + d
	if isPlayer(self) then
		self.StunImmuneUntil = now + d + STUN_IMMUNITY
	end
	self.Combo = 0
end

function CombatState.Knockdown(self: CombatState, duration: number)
	local now = os.clock()
	if self.State == "Ragdoll" and now < self.StunUntil then
		return
	end
	-- ล้มลง + ช่วงลุกขึ้น 0.3 วินาที (ระหว่างนี้เดิน/กระโดด/ใช้ท่าไม่ได้)
	local d = duration * Passives.StunRecoveryMultiplier(self.Equipped) + 0.3
	self.State = "Ragdoll"
	self.MoveLock = true
	self.StunUntil = now + d
	if isPlayer(self) then
		self.StunImmuneUntil = now + d + KNOCKDOWN_IMMUNITY
	end
	self.Combo = 0
end

function CombatState.Root(self: CombatState, duration: number)
	self.RootUntil = math.max(self.RootUntil, os.clock() + duration)
end

function CombatState.Slow(self: CombatState, fraction: number, duration: number)
	self.SlowUntil = math.max(self.SlowUntil, os.clock() + duration)
	self.SlowFactor = math.max(self.SlowFactor, fraction)
end

-- ควบคุมการเดิน/กระโดดจากที่เดียว: ล้ม/ตรึง/สตันนานเดินไม่ได้ ช้าลงตามผลหน่วง คำนวณจากความเร็วพื้นฐาน (BaseWalkSpeed)
-- (เดิมต่างคนต่างตั้ง WalkSpeed ทำให้ตอนล้มยังเดินได้ และค่าที่คืนอาจผิด)
function CombatState.ApplyMovement(self: CombatState)
	local now = os.clock()
	-- หมดเวลาสตัน/ล้มแล้วกลับสู่ปกติ (ไม่รอให้มีคนเรียก CanAct)
	if (self.State == "Stunned" or self.State == "Ragdoll") and now >= self.StunUntil then
		self.State = "Idle"
		self.MoveLock = false
	end
	if now >= self.SlowUntil then
		self.SlowFactor = 0
	end
	local hum = self.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local locked = self.State == "Ragdoll" or (self.State == "Stunned" and self.MoveLock) or now < self.RootUntil
	local base = (self.Character:GetAttribute("BaseWalkSpeed") :: number?) or 16
	local speed = if locked then 0 else base * (1 - self.SlowFactor)
	if hum.WalkSpeed ~= speed then
		hum.WalkSpeed = speed
	end
	if hum.UseJumpPower then
		local jump = if locked then 0 else ((self.Character:GetAttribute("BaseJumpPower") :: number?) or 50)
		if hum.JumpPower ~= jump then
			hum.JumpPower = jump
		end
	else
		local height = if locked then 0 else ((self.Character:GetAttribute("BaseJumpHeight") :: number?) or 7.2)
		if hum.JumpHeight ~= height then
			hum.JumpHeight = height
		end
	end
end

function CombatState.AddUlt(self: CombatState, amount: number)
	self.Ult = math.min(Config.UltMax, self.Ult + amount * Passives.UltChargeMultiplier(self.Equipped))
end

function CombatState.Regen(self: CombatState, dt: number)
	self:ApplyMovement()
	if self.State ~= "Blocking" then
		local max = (self.Character:GetAttribute("MaxStamina") :: number?) or Config.BaseStamina
		self.Stamina = math.min(max, self.Stamina + Config.StaminaRegen * dt)
	end
end

return CombatState
