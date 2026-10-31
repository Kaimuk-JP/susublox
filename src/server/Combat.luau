--!strict
-- แกนต่อสู้ที่ผู้เล่นและ NPC ใช้ร่วมกัน (ไม่ผูกกับ Remote)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Passives = require(ReplicatedStorage.Shared.Passives)
local CombatState = require(script.Parent.CombatState)

export type HitOpts = {
	Pierce: boolean?,
	Stun: number?,
	Knockdown: number?,
	Knockback: number?,
	Root: number?,
	Slow: number?,
	SlowTime: number?,
	Final: boolean?,
}

local Combat = {}

local states: { [Model]: CombatState.CombatState } = {}
local feedback: RemoteEvent? = nil
local hitListeners: { (CombatState.CombatState, CombatState.CombatState, number) -> () } = {}
local killListeners: { (CombatState.CombatState, CombatState.CombatState) -> () } = {}

function Combat.SetFeedbackRemote(remote: RemoteEvent)
	feedback = remote
end

function Combat.OnHit(fn: (CombatState.CombatState, CombatState.CombatState, number) -> ())
	table.insert(hitListeners, fn)
end

function Combat.OnKill(fn: (CombatState.CombatState, CombatState.CombatState) -> ())
	table.insert(killListeners, fn)
end

function Combat.Register(character: Model): CombatState.CombatState
	local s = CombatState.new(character)
	states[character] = s
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Once(function()
		states[character] = nil
		local killer = s.LastAttacker and states[s.LastAttacker]
		if killer then
			for _, fn in killListeners do
				task.spawn(fn, killer, s)
			end
		end
	end)
	return s
end

function Combat.Get(character: Model?): CombatState.CombatState?
	return character and states[character] or nil
end

function Combat.All(): { [Model]: CombatState.CombatState }
	return states
end

local function rootOf(s: CombatState.CombatState): BasePart?
	return s.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function notify(attacker: CombatState.CombatState, position: Vector3, amount: number, tag: string?)
	local owner = Players:GetPlayerFromCharacter(attacker.Character)
	if owner and feedback then
		feedback:FireClient(owner, tag or "Hit", position, amount)
	end
end

-- โจมตี 1 ครั้ง ผ่านระบบบล็อก/สวน/เบี่ยง/พาสซีฟ
function Combat.Hit(attacker: CombatState.CombatState, victim: CombatState.CombatState, amount: number, opts: HitOpts?)
	local o: HitOpts = opts or {}
	local hum = victim.Character:FindFirstChildOfClass("Humanoid")
	local vroot, aroot = rootOf(victim), rootOf(attacker)
	if not hum or not vroot or not aroot or hum.Health <= 0 then
		return
	end

	if os.clock() < victim.DeflectUntil then
		return -- ปัด/หลอกการโจมตีทั้งหมด
	end
	local counter = victim.Counter
	if counter and os.clock() < counter.Until then
		victim.Counter = nil
		Combat.Hit(victim, attacker, counter.Damage, { Pierce = true })
		return
	end

	local hpFraction = hum.Health / hum.MaxHealth
	local ahum = attacker.Character:FindFirstChildOfClass("Humanoid")
	local aFraction = ahum and ahum.Health / ahum.MaxHealth or 1
	amount *= Passives.DamageMultiplier(attacker.Equipped, aFraction, victim.IsBoss)
	amount *= (attacker.Character:GetAttribute("DamageMult") :: number?) or 1

	if victim.State == "Blocking" and not o.Pierce then
		if os.clock() - victim.BlockStart <= Config.PerfectBlockWindow then
			attacker:Stun(Config.PerfectBlockStun)
			notify(victim, vroot.Position, 0, "PerfectBlock")
			return
		end
		amount *= 1 - Config.BlockReduction
		victim.Stamina =
			math.max(0, victim.Stamina - Config.BlockStaminaCost * Passives.BlockCostMultiplier(victim.Equipped))
		if victim.Stamina <= 0 then
			victim:Stun(1)
		end
	else
		if victim.State == "Blocking" then
			victim.State = "Idle"
		end
		if o.Knockdown then
			victim:Knockdown(o.Knockdown)
		else
			victim:Stun(o.Stun or 0.4)
		end
		local push = o.Knockback or (o.Final and Config.FinisherKnockback) or 0
		if push > 0 then
			vroot.AssemblyLinearVelocity = aroot.CFrame.LookVector * push + Vector3.new(0, 25, 0)
		end
		if o.Root then
			victim:Root(o.Root)
		end
		if o.Slow then
			victim:Slow(o.Slow, o.SlowTime or 2)
		end
	end

	victim.LastAttacker = attacker.Character
	hum:TakeDamage(amount)
	attacker:AddUlt(Config.UltPerHit)
	victim:AddUlt(amount * Config.UltPerDamageTaken)
	notify(attacker, vroot.Position, amount)
	for _, fn in hitListeners do
		task.spawn(fn, attacker, victim, amount)
	end
end

-- หาเป้าหมายใน hitbox (กล่อง) ที่ผ่านการตรวจระยะฝั่ง server
function Combat.QueryBox(
	attacker: CombatState.CombatState,
	cf: CFrame,
	size: Vector3,
	maxRange: number
): { CombatState.CombatState }
	local root = rootOf(attacker)
	local found: { CombatState.CombatState } = {}
	if not root then
		return found
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker.Character }
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(cf, size, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local v = model and states[model]
		if model and v and not seen[model] then
			local vroot = rootOf(v)
			if vroot and (vroot.Position - root.Position).Magnitude <= maxRange then
				seen[model] = true
				table.insert(found, v)
			end
		end
	end
	return found
end

-- หาเป้าหมายในรัศมี
function Combat.QueryRadius(attacker: CombatState.CombatState, radius: number): { CombatState.CombatState }
	local root = rootOf(attacker)
	local found: { CombatState.CombatState } = {}
	if not root then
		return found
	end
	for model, v in states do
		local vroot = rootOf(v)
		if v ~= attacker and vroot and (vroot.Position - root.Position).Magnitude <= radius then
			table.insert(found, v)
		end
	end
	return found
end

function Combat.M1(s: CombatState.CombatState)
	local now = os.clock()
	if not s:CanAct() or now - s.LastM1 < Config.M1Cooldown then
		return
	end
	if now - s.LastM1 > Config.ComboResetTime then
		s.Combo = 0
	end
	s.Combo += 1
	s.LastM1 = now
	local final = s.Combo >= Config.ComboLength
	if final then
		s.Combo = 0
	end

	local root = rootOf(s)
	if not root then
		return
	end
	s.State = "Attacking"
	local cf = root.CFrame * CFrame.new(0, 0, -Config.HitboxForward)
	for _, v in Combat.QueryBox(s, cf, Config.HitboxSize, Config.MaxHitRange) do
		Combat.Hit(s, v, Config.M1Damage, { Final = final })
	end
	task.delay(Config.M1Cooldown, function()
		if s.State == "Attacking" then
			s.State = "Idle"
		end
	end)
end

function Combat.BlockStart(s: CombatState.CombatState)
	if s:CanAct() and s.Stamina > 0 then
		s.State = "Blocking"
		s.BlockStart = os.clock()
	end
end

function Combat.BlockEnd(s: CombatState.CombatState)
	if s.State == "Blocking" then
		s.State = "Idle"
	end
end

function Combat.Dash(s: CombatState.CombatState)
	local now = os.clock()
	local root = rootOf(s)
	local cooldown = Config.DashCooldown * Passives.DashCooldownMultiplier(s.Equipped)
	if not root or not s:CanAct() or now - s.LastDash < cooldown or s.Stamina < Config.DashStaminaCost then
		return
	end
	s.LastDash = now
	s.Stamina -= Config.DashStaminaCost
	root.AssemblyLinearVelocity = root.CFrame.LookVector * Config.DashSpeed
end

RunService.Heartbeat:Connect(function(dt)
	for _, s in states do
		s:Regen(dt)
	end
end)

return Combat
