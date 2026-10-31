--!strict
-- ของดร็อปบนพื้น: เหรียญเงินเรืองแสง ใครเดินไปแตะก่อนได้เยน (ทุกคนในเซิร์ฟเวอร์เห็น) หายเองเมื่อไม่มีใครเก็บ
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local PlayerData = require(script.Parent.PlayerData)

local Loot = {}

local lootFolder = Instance.new("Folder")
lootFolder.Name = "Loot"
lootFolder.Parent = workspace

local rng = Random.new()
local changed = ServerStorage:WaitForChild("ProfileChanged", 30) :: BindableEvent?

local function groundY(x: number, z: number, from: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { lootFolder, workspace:FindFirstChild("Npcs") :: Instance? }
	local res = workspace:Raycast(Vector3.new(x, from + 30, z), Vector3.new(0, -120, 0), params)
	return if res then res.Position.Y else from
end

-- โปรยเหรียญรอบตำแหน่ง รวมมูลค่า totalYen แบ่งเป็น count เหรียญ
function Loot.Coins(position: Vector3, totalYen: number, count: number)
	count = math.max(1, count)
	local each = math.max(1, math.floor(totalYen / count))
	for i = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(2, 3 + math.sqrt(count) * 2)
		local x, z = position.X + math.cos(a) * r, position.Z + math.sin(a) * r
		local y = groundY(x, z, position.Y) + 1.4

		local coin = Instance.new("Part")
		coin.Name = "Coin"
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.3, 1.8, 1.8)
		coin.Anchored = true
		coin.CanCollide = false
		coin.Material = Enum.Material.Neon
		coin.Color = Color3.fromHex("FFE066")
		coin.CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		coin.Parent = lootFolder
		local light = Instance.new("PointLight")
		light.Color = coin.Color
		light.Range = 10
		light.Brightness = 0.8
		light.Parent = coin
		coin:SetAttribute("Yen", each)

		TweenService:Create(coin, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)),
		}):Play()

		local taken = false
		coin.Touched:Connect(function(hit)
			if taken then
				return
			end
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local p = player and PlayerData.Get(player)
			if player and p then
				taken = true
				p.Yen += each
				player:SetAttribute("Yen", p.Yen)
				coin:Destroy()
			end
		end)
		Debris:AddItem(coin, 60)
	end
end

return Loot
