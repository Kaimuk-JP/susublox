--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local CombatState = require(script.Parent.CombatState)

local remote = Instance.new("RemoteEvent")
remote.Name = "CombatRemote"
remote.Parent = ReplicatedStorage

local feedback = Instance.new("RemoteEvent") -- server -> client: hit-stop, เลขดาเมจ
feedback.Name = "CombatFeedback"
feedback.Parent = ReplicatedStorage

local states: { [Model]: CombatState.CombatState } = {}
local rate: { [Player]: { count: number, window: number } } = {}

local function register(character: Model)
	states[character] = CombatState.new(character)
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Once(function()
		states[character] = nil
	end)
end

local function overRate(player: Player): boolean
	local r = rate[player]
	local now = os.clock()
	if not r or now - r.window >= 1 then
		rate[player] = { count = 1, window = now }
		return false
	end
	r.count += 1
	if r.count > Config.RemoteRateLimit then
		if r.count == Config.RemoteRateLimit + 1 then
			warn(`[AntiCheat] rate limit {player.Name}`)
		end
		return true
	end
	return false
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
	if owner then
		feedback:FireClient(owner, "Hit", root.Position, amount)
	end
end

local function m1(s: CombatState.CombatState)
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

local function dash(s: CombatState.CombatState)
	local now = os.clock()
	local root = s.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not s:CanAct() or now - s.LastDash < Config.DashCooldown or s.Stamina < Config.DashStaminaCost then
		return
	end
	s.LastDash = now
	s.Stamina -= Config.DashStaminaCost
	root.AssemblyLinearVelocity = root.CFrame.LookVector * Config.DashSpeed
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown)
	if overRate(player) or typeof(action) ~= "string" then
		return
	end
	local char = player.Character
	local s = char and states[char]
	if not s then
		return
	end
	if action == "M1" then
		m1(s)
	elseif action == "BlockStart" then
		if s:CanAct() and s.Stamina > 0 then
			s.State = "Blocking"
			s.BlockStart = os.clock()
		end
	elseif action == "BlockEnd" then
		if s.State == "Blocking" then
			s.State = "Idle"
		end
	elseif action == "Dash" then
		dash(s)
	end
end)

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(register)
	if player.Character then
		task.spawn(register, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(player)
	rate[player] = nil
end)

RunService.Heartbeat:Connect(function(dt)
	for _, s in states do
		s:Regen(dt)
	end
end)
