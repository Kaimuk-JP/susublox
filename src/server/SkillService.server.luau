--!strict
-- ใช้สกิล Z X C V และท่าไม้ตาย (U) ของสไตล์ที่สวมอยู่ ตรวจทุกอย่างฝั่ง server
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local StyleData = require(ReplicatedStorage.Shared.Styles)
local Combat = require(script.Parent.Combat)
local CombatState = require(script.Parent.CombatState)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "SkillRemote"
remote.Parent = ReplicatedStorage

local VALID_KEYS = { Z = true, X = true, C = true, V = true, U = true }
local ACTION_LOCK = 0.35
local rate: { [Player]: { count: number, window: number } } = {}

local function rootOf(s: CombatState.CombatState): BasePart?
	return s.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function optsOf(skill: StyleData.Skill, final: boolean?): Combat.HitOpts
	return {
		Pierce = skill.Pierce,
		Stun = skill.Stun,
		Knockdown = skill.Knockdown,
		Knockback = skill.Knockback,
		Root = skill.Root,
		Slow = skill.Slow,
		SlowTime = skill.SlowTime,
		Final = final,
	}
end

local function hitFront(s: CombatState.CombatState, skill: StyleData.Skill, damage: number, final: boolean?)
	local root = rootOf(s)
	if not root then
		return
	end
	local length = skill.Range or 6
	local cf = root.CFrame * CFrame.new(0, 0, -length / 2)
	local size = Vector3.new(Config.SkillHitbox.X, Config.SkillHitbox.Y, length)
	for _, v in Combat.QueryBox(s, cf, size, length + 4) do
		Combat.Hit(s, v, damage, optsOf(skill, final))
	end
end

local function alive(s: CombatState.CombatState): boolean
	return s.Character.Parent ~= nil and s.State ~= "Stunned" and s.State ~= "Ragdoll"
end

local function nearestEnemy(s: CombatState.CombatState, range: number): CombatState.CombatState?
	local best, bestDist = nil, range
	local root = rootOf(s)
	if not root then
		return nil
	end
	for _, v in Combat.QueryRadius(s, range) do
		local vroot = rootOf(v)
		if vroot then
			local d = (vroot.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = v, d
			end
		end
	end
	return best
end

local executors: { [string]: (CombatState.CombatState, StyleData.Skill) -> () } = {}

executors.Melee = function(s, skill)
	hitFront(s, skill, skill.Damage, skill.Knockback ~= nil)
end

local function dashHit(s: CombatState.CombatState, skill: StyleData.Skill)
	local root = rootOf(s)
	if not root then
		return
	end
	local time = 0.2
	root.AssemblyLinearVelocity = root.CFrame.LookVector * ((skill.Range or 10) / time)
	task.delay(time, function()
		if alive(s) then
			hitFront(s, skill, skill.Damage, false)
		end
	end)
end
executors.Dash = dashHit
executors.Charge = dashHit

executors.AoE = function(s, skill)
	for _, v in Combat.QueryRadius(s, skill.Radius or 8) do
		Combat.Hit(s, v, skill.Damage, optsOf(skill))
	end
end

executors.Multi = function(s, skill)
	local hits = skill.Hits or 3
	task.spawn(function()
		for i = 1, hits do
			if not alive(s) then
				return
			end
			s.State = "Attacking"
			hitFront(s, skill, skill.Damage / hits, i == hits)
			task.wait(0.15)
		end
		if s.State == "Attacking" then
			s.State = "Idle"
		end
	end)
end

executors.Counter = function(s, skill)
	s.Counter = { Damage = skill.Damage, Until = os.clock() + (skill.Duration or 1) }
end

executors.Deflect = function(s, skill)
	s.DeflectUntil = os.clock() + (skill.Duration or 1)
end

executors.Teleport = function(s, skill)
	local root = rootOf(s)
	if not root then
		return
	end
	local target = nearestEnemy(s, skill.Range or 30)
	local troot = target and rootOf(target)
	if troot then
		root.CFrame = CFrame.lookAt(troot.Position + troot.CFrame.LookVector * -4, troot.Position)
	else
		root.CFrame = root.CFrame * CFrame.new(0, 0, -15)
	end
end

executors.Grapple = function(s, skill)
	local root = rootOf(s)
	local target = nearestEnemy(s, skill.Range or 15)
	local troot = target and rootOf(target)
	if not root or not target or not troot then
		return
	end
	troot.CFrame = root.CFrame * CFrame.new(0, 0, -4)
	Combat.Hit(s, target, skill.Damage, optsOf(skill))
end

local function activate(player: Player, key: string)
	local s = Combat.Get(player.Character)
	local profile = PlayerData.Get(player)
	if not s or not profile or not s:CanAct() then
		return
	end
	local style = StyleData.Styles[profile.EquippedStyle]
	if not style then
		return
	end
	local isUlt = key == "U"
	local skill: StyleData.Skill = if isUlt then style.Ultimate else (style.Skills :: any)[key]
	local mastery = profile.Mastery[profile.EquippedStyle]
	local masteryLevel = mastery and mastery.Level or 1
	if masteryLevel < StyleData.MasteryUnlock[if isUlt then "Ultimate" else key] then
		return
	end
	local now = os.clock()
	if now < (s.SkillReady[key] or 0) then
		return
	end
	if isUlt then
		if s.Ult < Config.UltMax then
			return
		end
		s.Ult = 0
	end
	s.SkillReady[key] = now + skill.Cooldown
	s.State = "Attacking"
	executors[skill.Kind](s, skill)
	task.delay(ACTION_LOCK, function()
		if s.State == "Attacking" then
			s.State = "Idle"
		end
	end)
	player:SetAttribute("CD_" .. key, now + skill.Cooldown)
end

remote.OnServerEvent:Connect(function(player: Player, key: unknown)
	if typeof(key) ~= "string" or not VALID_KEYS[key] then
		return
	end
	local r = rate[player]
	local now = os.clock()
	if not r or now - r.window >= 1 then
		rate[player] = { count = 1, window = now }
	else
		r.count += 1
		if r.count > Config.RemoteRateLimit then
			return
		end
	end
	activate(player, key)
end)

Players.PlayerRemoving:Connect(function(player)
	rate[player] = nil
end)
