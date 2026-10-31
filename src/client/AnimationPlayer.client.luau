--!strict
-- เล่นแอนิเมชันตามชื่อท่าที่ server ตั้งใน Attribute "Anim" ของตัวละครทุกตัว (ข้ามถ้ายังไม่มี asset ID)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)

local cache: { [Animator]: { [string]: AnimationTrack } } = {}

local function playOn(character: Model, name: string)
	local id = Assets.Animations[name]
	if not id or id == 0 then
		return
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
