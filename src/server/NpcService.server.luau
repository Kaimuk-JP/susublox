--!strict
-- NPC ศัตรู: ใช้ระบบต่อสู้ชุดเดียวกับผู้เล่น ต่างกันแค่ AI เลือกท่า
local Players = game:GetService("Players")

local Combat = require(script.Parent.Combat)

local AGGRO_RANGE = 40
local ATTACK_RANGE = 6
local BLOCK_CHANCE = 0.2
local THINK_INTERVAL = 0.25
local RESPAWN_TIME = 15

local function nearestPlayerRoot(from: Vector3): BasePart?
	local best: BasePart?, bestDist = nil, AGGRO_RANGE
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and not Combat.InSafeZone(root.Position) then
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
	local level = (npc:GetAttribute("NpcLevel") :: number?) or 1
	s.IsBoss = npc:GetAttribute("IsBoss") == true
	-- ชนิดศัตรู: Grunt ธรรมดา / Speedy เร็วเลือดน้อย / Brute ช้าเลือดเยอะตีแรง
	local npcType = (npc:GetAttribute("NpcType") :: string?) or "Grunt"
	local hpMult = ({ Grunt = 1, Speedy = 0.7, Brute = 2.5 } :: { [string]: number })[npcType] or 1
	hum.WalkSpeed = ({ Grunt = 14, Speedy = 24, Brute = 10 } :: { [string]: number })[npcType] or 14
	hum.MaxHealth = (100 + 20 * (level - 1)) * (if s.IsBoss then 8 else 1) * hpMult
	hum.Health = hum.MaxHealth
	local dmgMult = ({ Grunt = 1, Speedy = 0.8, Brute = 1.6 } :: { [string]: number })[npcType] or 1
	npc:SetAttribute("DamageMult", (1 + 0.1 * (level - 1)) * dmgMult)
	local home = root.CFrame
	local parent = npc.Parent -- ต้องจำไว้ก่อน เพราะ npc:Destroy() จะทำให้ Parent เป็น nil

	task.spawn(function()
		while hum.Health > 0 and npc.Parent do
			local target = nearestPlayerRoot(root.Position)
			if target then
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
		task.delay(RESPAWN_TIME, function()
			template:PivotTo(home)
			template.Parent = parent
		end)
		task.delay(3, function()
			npc:Destroy()
		end)
	end)
end

local folder = workspace:WaitForChild("Npcs", 15)
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
