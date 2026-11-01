--!strict
-- NPC ศัตรู: ใช้ระบบต่อสู้ชุดเดียวกับผู้เล่น ต่างกันแค่ AI เลือกท่า
local Players = game:GetService("Players")

local Combat = require(script.Parent.Combat)

-- ศัตรูไม่วิ่งไล่ผู้เล่นเอง จะสู้เมื่อ (1) ถูกตี (2) ผู้เล่นเดินเข้าใกล้เกิน PROVOKE_RANGE (หาเรื่อง)
-- (3) เป็นศัตรูแบบ Aggressive เช่นบอสสุ่ม/ศึกชิงถนน ที่บุกเข้ามาเอง เมื่อสู้แล้วไล่ต่อ CHASE_MEMORY วินาที
-- เพื่อนในค่ายเดียวกัน/ใกล้กันช่วยสู้เมื่อมีคนถูกตี พอเลิกสู้แล้วเดินกลับจุดเดิม
local AGGRO_RANGE = 40 -- ระยะมองเห็นของศัตรูแบบ Aggressive
local PROVOKE_RANGE = 9
local CHASE_MEMORY = 12
local LEASH = 90
local GROUP_ALERT = 35
local ATTACK_RANGE = 6
local BLOCK_CHANCE = 0.2
local THINK_INTERVAL = 0.25
local RESPAWN_TIME = 15

local provoked: { [Model]: { Player: Player, Until: number } } = {}

local function nearestPlayerRoot(from: Vector3, range: number): BasePart?
	local best: BasePart?, bestDist = nil, range
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and not Combat.InSafeZone(root.Position) and not p.Character:GetAttribute("ArenaSpec") then
			local d = (root.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best
end

local function runAI(npc: Model)
	local template = npc:Clone() -- เก็บสำเนาที่ยังมีชีวิตไว้ใช้เกิดใหม่
	local s = Combat.Register(npc)
	local hum = npc:WaitForChild("Humanoid") :: Humanoid
	local root = npc:WaitForChild("HumanoidRootPart") :: BasePart
	-- ให้เซิร์ฟเวอร์เป็นเจ้าของฟิสิกส์ NPC (ไม่ให้เครื่องผู้เล่นที่อยู่ใกล้ต้องคำนวณมอนเป็นสิบตัว ทำให้เครื่องแลค)
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local level = (npc:GetAttribute("NpcLevel") :: number?) or 1
	s.IsBoss = npc:GetAttribute("IsBoss") == true
	-- ชนิดศัตรู: Grunt ธรรมดา / Speedy เร็วเลือดน้อย / Brute ช้าเลือดเยอะตีแรง
	local npcType = (npc:GetAttribute("NpcType") :: string?) or "Grunt"
	-- HpMult (Attribute) ใช้แทนตัวคูณตามชนิด เช่น บอสสุ่มของโลก
	local hpMult = (npc:GetAttribute("HpMult") :: number?) or ({ Grunt = 1, Speedy = 0.7, Brute = 2.5 } :: { [string]: number })[npcType] or 1
	local walk = ({ Grunt = 14, Speedy = 24, Brute = 10 } :: { [string]: number })[npcType] or 14
	npc:SetAttribute("BaseWalkSpeed", walk)
	hum.WalkSpeed = walk
	hum.MaxHealth = (100 + 20 * (level - 1)) * (if s.IsBoss then 8 else 1) * hpMult
	hum.Health = hum.MaxHealth
	local dmgMult = ({ Grunt = 1, Speedy = 0.8, Brute = 1.6 } :: { [string]: number })[npcType] or 1
	npc:SetAttribute("DamageMult", (1 + 0.1 * (level - 1)) * dmgMult)
	local home = root.CFrame
	local parent = npc.Parent -- ต้องจำไว้ก่อน เพราะ npc:Destroy() จะทำให้ Parent เป็น nil

	task.spawn(function()
		task.wait(math.random() * THINK_INTERVAL) -- กระจายเวลาคิดของมอน ไม่ให้ทำงานพร้อมกันทีเดียวทั้งฝูง
		local aggressive = npc:GetAttribute("Aggressive") == true
		while hum.Health > 0 and npc.Parent do
			local target: BasePart? = nil
			local entry = provoked[npc]
			if entry then
				local char = entry.Player.Character
				local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local h = char and char:FindFirstChildOfClass("Humanoid")
				if
					os.clock() < entry.Until
					and r
					and h
					and h.Health > 0
					and not Combat.InSafeZone(r.Position)
					and (r.Position - root.Position).Magnitude < LEASH
				then
					target = r
				else
					provoked[npc] = nil
				end
			end
			if not target then
				-- ผู้เล่นเดินเข้ามาใกล้เกินไป = หาเรื่อง (หรือศัตรูแบบ Aggressive ที่มองเห็นไกลกว่า)
				target = nearestPlayerRoot(root.Position, if aggressive then AGGRO_RANGE else PROVOKE_RANGE)
				local tp = target and Players:GetPlayerFromCharacter(target.Parent)
				if tp then
					provoked[npc] = { Player = tp, Until = os.clock() + CHASE_MEMORY }
				end
			end
			if not target then
				-- ไม่มีใครให้สู้ ยืนอยู่ที่จุดของตัวเอง ถ้าถูกไล่ไปไกลให้เดินกลับ
				Combat.BlockEnd(s)
				if (root.Position - home.Position).Magnitude > 8 then
					hum:MoveTo(home.Position)
				end
			else
				local dist = (target.Position - root.Position).Magnitude
				if dist > ATTACK_RANGE then
					Combat.BlockEnd(s)
					hum:MoveTo(target.Position)
				else
					hum:MoveTo(root.Position)
					root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.Position.X, root.Position.Y, target.Position.Z))
					if math.random() < BLOCK_CHANCE then
						Combat.BlockStart(s)
					else
						Combat.BlockEnd(s)
						Combat.M1(s)
					end
				end
			end
			task.wait(THINK_INTERVAL)
		end
	end)

	-- เกิดใหม่ที่เดิมหลังตาย
	hum.Died:Once(function()
		provoked[npc] = nil
		-- ศัตรูที่ถูกเก็บออกเพราะไม่มีผู้เล่นอยู่ใกล้ (Despawned) ไม่เกิดใหม่
		if npc:GetAttribute("Despawned") ~= true then
			local wait = (npc:GetAttribute("RespawnTime") :: number?) or RESPAWN_TIME
			task.delay(wait, function()
				local district = npc:GetAttribute("District")
				if typeof(district) == "string" and parent:GetAttribute("Active_" .. district) == false then
					return -- ย่านนี้ถูกเก็บออกไปแล้วระหว่างรอ
				end
				template:PivotTo(home)
				template.Parent = parent
			end)
		end
		task.delay(3, function()
			npc:Destroy()
		end)
	end)
end

local folder = workspace:WaitForChild("Npcs", 15)

-- ผู้เล่นตีศัตรู -> ศัตรูตัวนั้นหันมาสู้ และเพื่อนในค่ายเดียวกัน/ใกล้กันช่วยสู้ด้วย
Combat.OnHit(function(attacker, victim)
	local player = Players:GetPlayerFromCharacter(attacker.Character)
	local model = victim.Character
	if not player or not folder or model:GetAttribute("NpcLevel") == nil then
		return
	end
	local untilAt = os.clock() + CHASE_MEMORY
	provoked[model] = { Player = player, Until = untilAt }
	local camp = model:GetAttribute("Camp")
	local district = model:GetAttribute("District")
	local pos = model:GetPivot().Position
	for _, other in folder:GetChildren() do
		if other ~= model and other:IsA("Model") and other:GetAttribute("NpcLevel") ~= nil then
			local sameCamp = camp ~= nil and other:GetAttribute("Camp") == camp
			local near = district ~= nil
				and other:GetAttribute("District") == district
				and (other:GetPivot().Position - pos).Magnitude < GROUP_ALERT
			if sameCamp or near then
				provoked[other] = { Player = player, Until = untilAt }
			end
		end
	end
end)

if folder then
	for _, npc in folder:GetChildren() do
		if npc:IsA("Model") then
			task.spawn(runAI, npc)
		end
	end
	folder.ChildAdded:Connect(function(npc)
		if npc:IsA("Model") then
			task.spawn(runAI, npc)
		end
	end)
end
