--!strict
-- ของดร็อปจากการตีแก๊งทั่วไป: ศัตรูมีโอกาสทิ้งเหรียญเงินตกพื้น ยิ่งเลเวลสูงยิ่งได้มาก
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)

local rng = Random.new()

Combat.OnKill(function(_killer, victim)
	if victim.Character:GetAttribute("Trial") then
		return
	end
	local level = victim.Character:GetAttribute("NpcLevel")
	local root = victim.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if typeof(level) ~= "number" or not root then
		return
	end
	if victim.Character:GetAttribute("WorldBoss") == true or victim.IsBoss then
		return -- บอสมีระบบดร็อปของตัวเอง
	end
	-- โอกาสดร็อป 40% ศัตรู Brute ดร็อปมากกว่า
	local npcType = victim.Character:GetAttribute("NpcType")
	local chance = if npcType == "Brute" then 0.7 else 0.4
	if rng:NextNumber() <= chance then
		local total = level * (if npcType == "Brute" then 8 else 4)
		Loot.Coins(root.Position, total, rng:NextInteger(2, 4))
	end
end)
