--!strict
-- แกนต่อสู้ที่ผู้เล่นและ NPC ใช้ร่วมกัน (ไม่ผูกกับ Remote)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local CombatState = require(script.Parent.CombatState)

local Combat = {}

local states: { [Model]: CombatState.CombatState } = {}
local feedback: RemoteEvent? = nil

function Combat.SetFeedbackRemote(remote: RemoteEvent)
	feedback = remote
end

function Combat.Register(character: Model): CombatState.CombatState
	local s = CombatState.new(character)
	states[character] = s
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Once(function()
		states[character] = nil
	end)
	return s
end

function Combat.Get(character: Model?): CombatState.CombatState?
	return character and states[character] or nil
end

local function damage(attacker: CombatState.CombatState, victim: CombatState.CombatState, amount: number, final: boolean)
	local hum = victim.Character:FindFirstChildOfClass("Humanoid")
	local root = victim.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local aroot = attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or not aroot then
		return
	end

	if victim.State == "Blocking" then
		if os.clock() - victim.BlockStart <= Config.PerfectBlockWindow then
			attacker:Stun(Config.PerfectBlockStun)
			return
		end
		amount *= 1 - Config.BlockReduction
		victim.Stamina = math.max(0, victim.Stamina - Config.BlockStaminaCost)
		if victim.Stamina <= 0 then
			victim:Stun(1)
		end
	else
		victim:Stun(0.4)
		if final then
			root.AssemblyLinearVelocity = aroot.CFrame.LookVector * Config.FinisherKnockback + Vector3.new(0, 25, 0)
		end
	end
	hum:TakeDamage(amount)
	local owner = Players:GetPlayerFromCharacter(attacker.Character)
	if owner and feedback then
		feedback:FireClient(owner, "Hit", root.Position, amount)
	end
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

	local root = s.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	s.State = "Attacking"
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { s.Character }
	local cf = root.CFrame * CFrame.new(0, 0, -Config.HitboxForward)
	local hit: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(cf, Config.HitboxSize, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local v = model and states[model]
		if model and v and not hit[model] then
			local vroot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if vroot and (vroot.Position - root.Position).Magnitude <= Config.MaxHitRange then
				hit[model] = true
				damage(s, v, Config.M1Damage, final)
			end
		end
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
	local root = s.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not s:CanAct() or now - s.LastDash < Config.DashCooldown or s.Stamina < Config.DashStaminaCost then
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
