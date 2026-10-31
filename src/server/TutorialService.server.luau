--!strict
-- บทสอน: จบเมื่อล้ม NPC ตัวแรกได้ (ฝั่ง client แสดงขั้นตอน)
local Players = game:GetService("Players")

local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

Combat.OnKill(function(killer)
	local player = Players:GetPlayerFromCharacter(killer.Character)
	local p = player and PlayerData.Get(player)
	if player and p and not p.TutorialDone then
		p.TutorialDone = true
		player:SetAttribute("TutorialDone", true)
		p.Yen += 50 -- รางวัลจบบทสอน
		player:SetAttribute("Yen", p.Yen)
	end
end)

Players.PlayerAdded:Connect(function(player)
	for _ = 1, 100 do
		if PlayerData.Get(player) then
			break
		end
		task.wait(0.2)
	end
	local p = PlayerData.Get(player)
	player:SetAttribute("TutorialDone", p ~= nil and p.TutorialDone)
end)
