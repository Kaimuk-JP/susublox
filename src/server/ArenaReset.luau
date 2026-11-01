--!strict
-- รีเซ็ตสถานะนักสู้ทุกอย่างให้เริ่มรอบ/แมตช์ใหม่แบบยุติธรรม (ใช้ร่วมกันโดยดวล / สงครามแก๊ง / ศึกฝึกซ้อม)
-- ล้าง: เลือด, พลังงาน (stamina) เต็ม, ult = 0 (แมตช์ยุติธรรมไม่ยกชาร์จข้ามรอบ), คูลดาวน์สกิลทุกปุ่ม (+ attribute CD_* ที่ UI อ่าน),
--        สตัน/ล้ม/ตรึง/หน่วง/บล็อก/คอมโบ/ตั้งรับสวนกลับ/ปัดโจมตี, ForceField, PlatformStand/Anchored, ผู้โจมตีล่าสุด
local Combat = require(script.Parent.Combat)
local Config = require(game.ReplicatedStorage.Shared.CombatConfig)

local ArenaReset = {}

local function clearAttributes(target: Instance, prefixes: { string })
	for name in target:GetAttributes() do
		for _, prefix in prefixes do
			if name:sub(1, #prefix) == prefix then
				target:SetAttribute(name, nil)
				break
			end
		end
	end
end

-- opts.respawn: ตายอยู่ให้เกิดใหม่ (LoadCharacter) ก่อนรีเซ็ต; คืน true ถ้าตัวละครพร้อม (มีชีวิต)
function ArenaReset.apply(player: Player, opts: { respawn: boolean? }?): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if (not char or not hum or hum.Health <= 0) and opts and opts.respawn then
		pcall(function()
			player:LoadCharacter()
		end)
		char = player.Character
		if char then
			char:WaitForChild("HumanoidRootPart", 10)
		end
		hum = char and char:FindFirstChildOfClass("Humanoid")
		task.wait(0.3) -- ให้ Combat.Register ลงทะเบียนตัวละครใหม่
	end
	if not char or not hum or hum.Health <= 0 then
		return false
	end
	hum.Health = hum.MaxHealth
	hum.PlatformStand = false
	hum.Sit = false
	for _, d in char:GetDescendants() do
		if d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") and d.Anchored and d.Name == "HumanoidRootPart" then
			d.Anchored = false
		end
	end
	local s = Combat.Get(char)
	if s then
		local maxStamina = (char:GetAttribute("MaxStamina") :: number?) or Config.BaseStamina
		s.State = "Idle"
		s.Stamina = maxStamina
		s.Ult = 0
		s.Combo = 0
		s.LastM1 = 0
		s.LastDash = 0
		s.BlockStart = 0
		s.StunUntil = 0
		s.StunImmuneUntil = 0
		s.MoveLock = false
		s.SlowUntil = 0
		s.SlowFactor = 0
		s.RootUntil = 0
		s.Counter = nil
		s.DeflectUntil = 0
		s.SkillReady = {}
		s.LastAttacker = nil
		char:SetAttribute("Stamina", maxStamina)
		char:SetAttribute("Ult", 0)
		s:ApplyMovement()
	end
	-- UI แถบสกิลอ่านคูลดาวน์จาก attribute ของผู้เล่น: ล้างให้ขึ้น "พร้อมใช้"
	clearAttributes(player, { "CD_", "CDLen_" })
	clearAttributes(char, { "Buff", "Debuff", "Status", "Burn", "Poison", "Bleed" })
	return true
end

return ArenaReset
