--!strict
-- ดวลดาดฟ้า/โรงยิม 1v1: ท้า -> รับ -> วาร์ปเข้าอารีน่า -> ผู้ชนะได้แต้มแรงก์
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "DuelRemote"
remote.Parent = ReplicatedStorage

local WIN_POINTS, LOSE_POINTS = 25, 10
local DUEL_TIMEOUT = 180
local CHALLENGE_TIMEOUT = 15
local SPAWN_A, SPAWN_B = Vector3.new(110, 5, 0), Vector3.new(150, 5, 0)

local challenges: { [Player]: { from: Player, at: number } } = {} -- ผู้ถูกท้า -> ผู้ท้า
local inDuel: { [Player]: Player } = {}

local function endDuel(winner: Player?, loser: Player?)
	for _, pl in { winner, loser } do
		if pl then
			inDuel[pl] = nil
			pl:SetAttribute("InDuel", false)
		end
	end
	if winner then
		local pw = PlayerData.Get(winner)
		if pw then
			pw.RankPoints += WIN_POINTS
			winner:SetAttribute("RankPoints", pw.RankPoints)
			local storyEvent = game:GetService("ServerStorage"):FindFirstChild("StoryEvent") :: BindableEvent?
			if storyEvent then
				storyEvent:Fire(winner, "DuelWin")
			end
		end
	end
	if loser then
		local pl = PlayerData.Get(loser)
		if pl then
			pl.RankPoints = math.max(0, pl.RankPoints - LOSE_POINTS)
			loser:SetAttribute("RankPoints", pl.RankPoints)
		end
	end
end

local function start(a: Player, b: Player)
	local ca, cb = a.Character, b.Character
	if not ca or not cb then
		return
	end
	inDuel[a], inDuel[b] = b, a
	a:SetAttribute("InDuel", true)
	b:SetAttribute("InDuel", true)
	ca:PivotTo(CFrame.lookAt(SPAWN_A, SPAWN_B))
	cb:PivotTo(CFrame.lookAt(SPAWN_B, SPAWN_A))
	task.delay(DUEL_TIMEOUT, function()
		if inDuel[a] == b then
			endDuel(nil, nil) -- หมดเวลา เสมอ ไม่เปลี่ยนแต้ม
			inDuel[a], inDuel[b] = nil, nil
			a:SetAttribute("InDuel", false)
			b:SetAttribute("InDuel", false)
		end
	end)
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown, targetId: unknown)
	if typeof(action) ~= "string" or typeof(targetId) ~= "number" or inDuel[player] then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player or inDuel[target] then
		return
	end
	if action == "Challenge" then
		challenges[target] = { from = player, at = os.clock() }
		remote:FireClient(target, "Challenged", player.UserId, player.Name)
	elseif action == "Accept" then
		local c = challenges[player]
		if c and c.from == target and os.clock() - c.at <= CHALLENGE_TIMEOUT then
			challenges[player] = nil
			start(target, player)
		end
	end
end)

Combat.OnKill(function(killer, victim)
	local a, b = Players:GetPlayerFromCharacter(killer.Character), Players:GetPlayerFromCharacter(victim.Character)
	if a and b and inDuel[a] == b then
		endDuel(a, b)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	challenges[player] = nil
	local other = inDuel[player]
	if other then
		endDuel(other, nil)
	end
	inDuel[player] = nil
end)
