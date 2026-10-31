--!strict
-- เล่นแอนิเมชันตามชื่อท่าที่ server ตั้งใน Attribute "Anim" ของตัวละครทุกตัว (ข้ามถ้ายังไม่มี asset ID)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)

local cache: { [Animator]: { [string]: AnimationTrack } } = {}

-- ตัวแทนชั่วคราวเมื่อยังไม่มี asset แอนิเมชัน: วงฟันสั้น ๆ หน้าตัวละคร ให้เห็นว่ากดท่าแล้ว
local function fallbackSlash(character: Model, name: string)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or name == "Block" then
		return
	end
	local slash = Instance.new("Part")
	slash.Anchored, slash.CanCollide, slash.CanQuery, slash.CanTouch = true, false, false, false
	slash.Material = Enum.Material.Neon
	slash.Color = if name == "Dash" then Color3.fromHex("7EC8E3") else Color3.fromHex("FFFFFF")
	slash.Size = Vector3.new(0.2, 1, 4)
	slash.CFrame = root.CFrame * CFrame.new(0, 0.5, -3.5) * CFrame.Angles(0, 0, math.rad(35))
	slash.Parent = workspace
	local tween = game:GetService("TweenService"):Create(
		slash,
		TweenInfo.new(0.18),
		{ Transparency = 1, Size = Vector3.new(0.2, 4, 6) }
	)
	tween:Play()
	game:GetService("Debris"):AddItem(slash, 0.25)
end

local function playOn(character: Model, name: string)
	local id = Assets.Animations[name]
	if not id or id == 0 then
		return -- ท่าทางสำรองทำโดย ProceduralAnim.client.luau
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local tracks = cache[animator]
	if not tracks then
		tracks = {}
		cache[animator] = tracks
		animator.Destroying:Once(function()
			cache[animator] = nil
		end)
	end
	local track = tracks[name]
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. id
		track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action
		tracks[name] = track
	end
	track:Play()
end

local function watch(character: Model)
	character:GetAttributeChangedSignal("Anim"):Connect(function()
		local value = character:GetAttribute("Anim")
		if typeof(value) == "string" then
			playOn(character, (value:split(":")[1]))
		end
	end)
end

local function onWorkspaceChild(inst: Instance)
	if inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") then
		watch(inst)
	end
end

for _, p in Players:GetPlayers() do
	if p.Character then
		watch(p.Character)
	end
end
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(watch)
end)
for _, p in Players:GetPlayers() do
	p.CharacterAdded:Connect(watch)
end
for _, folderName in { "Npcs", "Bosses" } do
	local f = workspace:WaitForChild(folderName, 30)
	if f then
		for _, c in f:GetChildren() do
			onWorkspaceChild(c)
		end
		f.ChildAdded:Connect(onWorkspaceChild)
	end
end
