--!strict
-- Battle Pass: ได้ XP ซีซันจากการชนะและเควส รับรางวัลตามขั้นฝั่ง server
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BP = require(ReplicatedStorage.Shared.BattlePass)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "BattlePassRemote"
remote.Parent = ReplicatedStorage

local XP_PER_KILL = 40

local function publish(player: Player)
	local p = PlayerData.Get(player)
	if p then
		player:SetAttribute("BP_Xp", p.BattlePass.Xp)
		player:SetAttribute("BP_Tier", BP.TierOf(p.BattlePass.Xp))
		player:SetAttribute("BP_Premium", p.Passes.BattlePassPremium == true)
	end
end

-- ซีซันใหม่: รีเซ็ต XP และรางวัลที่รับแล้ว
local function checkSeason(player: Player)
	local p = PlayerData.Get(player)
	if p and p.BattlePass.Season ~= BP.Season then
		p.BattlePass = { Season = BP.Season, Xp = 0, ClaimedFree = {}, ClaimedPremium = {} }
	end
end

Combat.OnKill(function(killer)
	local player = Players:GetPlayerFromCharacter(killer.Character)
	local p = player and PlayerData.Get(player)
	if player and p then
		checkSeason(player)
		p.BattlePass.Xp += XP_PER_KILL
		publish(player)
	end
end)

local function grant(p: any, reward: BP.Reward)
	if reward.Yen then
		p.Yen += reward.Yen
	end
	if reward.Outfit and not table.find(p.Owned, reward.Outfit) then
		table.insert(p.Owned, reward.Outfit)
	end
	if reward.ExpBoost then
		p.ExpBoostUntil = math.max(os.time(), p.ExpBoostUntil) + reward.ExpBoost
	end
end

remote.OnServerEvent:Connect(function(player: Player, track: unknown, tier: unknown)
	local p = PlayerData.Get(player)
	if not p or typeof(tier) ~= "number" or (track ~= "Free" and track ~= "Premium") then
		return
	end
	checkSeason(player)
	tier = math.floor(tier)
	if tier < 1 or tier > BP.Tiers or BP.TierOf(p.BattlePass.Xp) < tier then
		return
	end
	local key = tostring(tier)
	if track == "Free" then
		if p.BattlePass.ClaimedFree[key] then
			return
		end
		p.BattlePass.ClaimedFree[key] = true
		grant(p, BP.Free[tier])
	else
		if not p.Passes.BattlePassPremium or p.BattlePass.ClaimedPremium[key] then
			return
		end
		p.BattlePass.ClaimedPremium[key] = true
		grant(p, BP.Premium[tier])
	end
	player:SetAttribute("Yen", p.Yen)
	publish(player)
end)

Players.PlayerAdded:Connect(function(player)
	for _ = 1, 100 do
		if PlayerData.Get(player) then
			break
		end
		task.wait(0.2)
	end
	checkSeason(player)
	publish(player)
end)
