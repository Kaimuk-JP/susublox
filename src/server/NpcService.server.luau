--!strict
-- NPC ศัตรูพื้นฐาน: ใช้ระบบต่อสู้ชุดเดียวกับผู้เล่น ต่างกันแค่ AI เลือกท่า
local Players = game:GetService("Players")

local Combat = require(script.Parent.Combat)

local AGGRO_RANGE = 40
local ATTACK_RANGE = 6
local BLOCK_CHANCE = 0.2
local THINK_INTERVAL = 0.25

local function nearestPlayerRoot(from: Vector3): BasePart?
	local best: BasePart?, bestDist = nil, AGGRO_RANGE
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local d = (root.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best
end

local function runAI(npc: Model)
	local s = Combat.Register(npc)
	local hum = npc:WaitForChild("Humanoid") :: Humanoid
	local root = npc:WaitForChild("HumanoidRootPart") :: BasePart
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
end

-- NPC ที่วางใน Workspace.Npcs (ต้องมี Humanoid + HumanoidRootPart) จะถูกใส่ AI อัตโนมัติ
local folder = workspace:FindFirstChild("Npcs")
if folder then
	for _, npc in folder:GetChildren() do
		if npc:IsA("Model") then
			runAI(npc)
		end
	end
	folder.ChildAdded:Connect(function(npc)
		if npc:IsA("Model") then
			runAI(npc)
		end
	end)
end
