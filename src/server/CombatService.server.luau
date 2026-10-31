--!strict
-- เชื่อม RemoteEvent ของผู้เล่นเข้ากับแกนต่อสู้
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Combat = require(script.Parent.Combat)

local remote = Instance.new("RemoteEvent")
remote.Name = "CombatRemote"
remote.Parent = ReplicatedStorage

local feedback = Instance.new("RemoteEvent") -- server -> client: hit-stop, เลขดาเมจ
feedback.Name = "CombatFeedback"
feedback.Parent = ReplicatedStorage
Combat.SetFeedbackRemote(feedback)

local rate: { [Player]: { count: number, window: number } } = {}

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

remote.OnServerEvent:Connect(function(player: Player, action: unknown)
	if overRate(player) or typeof(action) ~= "string" then
		return
	end
	local s = Combat.Get(player.Character)
	if not s then
		return
	end
	if action == "M1" then
		Combat.M1(s)
	elseif action == "BlockStart" then
		Combat.BlockStart(s)
	elseif action == "BlockEnd" then
		Combat.BlockEnd(s)
	elseif action == "Dash" then
		Combat.Dash(s)
	end
end)

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(Combat.Register)
	if player.Character then
		task.spawn(Combat.Register, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(player)
	rate[player] = nil
end)
