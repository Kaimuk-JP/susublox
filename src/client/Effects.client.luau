--!strict
-- VFX แบบโค้ดล้วน (อนิเมะ: ดาวเด้ง เส้นความเร็ว แสงวาบ) + เสียง/แอนิเมชันที่เล่นเมื่อมี asset ID
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local feedback = ReplicatedStorage:WaitForChild("CombatFeedback") :: RemoteEvent

local function play(name: string)
	local id = Assets.Sounds[name]
	if id and id ~= 0 then
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id
		s.Volume = 0.6
		s.Parent = SoundService
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
end

-- ดาวระเบิด ณ จุดที่โดน
local function starBurst(position: Vector3, color: Color3, count: number)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.Transparency = true, false, false, 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Speed = NumberRange.new(14, 26)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Rate = 0
	e.Parent = anchor
	e:Emit(count)
	task.delay(0.6, function()
		anchor:Destroy()
	end)
end

-- แสงวาบเต็มจอเมื่อคริติคอล/ไม้ตาย
local function flash(color: Color3, duration: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = color
	cc.Brightness = 0.25
	cc.Parent = game:GetService("Lighting")
	TweenService:Create(cc, TweenInfo.new(duration), { Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	task.delay(duration + 0.1, function()
		cc:Destroy()
	end)
end

feedback.OnClientEvent:Connect(function(kind: string, position: Vector3, amount: number)
	if kind == "Hit" then
		local big = amount >= 15
		starBurst(position, if big then Color3.fromHex("FFE066") else Color3.fromHex("FFFFFF"), if big then 14 else 7)
		play("Punch")
		if big then
			flash(Color3.fromHex("FFF3B0"), 0.2)
		end
	elseif kind == "Crit" then
		starBurst(position, Color3.fromHex("FF4D4D"), 22)
		play("Punch")
		flash(Color3.fromHex("FFD0D0"), 0.25)
	elseif kind == "PerfectBlock" then
		starBurst(position, Color3.fromHex("7EC8E3"), 16)
		play("PerfectBlock")
		flash(Color3.fromHex("BFE9FF"), 0.25)
	end
end)

-- เสียงวูบตอนออกท่าของเรา (ชก/พุ่ง/สกิล) และเสียงบล็อก
local function watchOwnAnim(character: Model)
	character:GetAttributeChangedSignal("Anim"):Connect(function()
		local value = character:GetAttribute("Anim")
		if typeof(value) ~= "string" then
			return
		end
		local name = value:split(":")[1]
		if name == "Block" then
			play("Block")
		elseif name ~= "BlockEnd" and name ~= "Hit" and name ~= "Knockdown" and name ~= "BlockHit" then
			play("Whoosh")
		end
	end)
end
local localPlayer = Players.LocalPlayer
if localPlayer.Character then
	watchOwnAnim(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(watchOwnAnim)

-- เสียงเมื่อเลเวลขึ้น
local lastLevel = 0
Players.LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
	local level = (Players.LocalPlayer:GetAttribute("Level") :: number?) or 0
	if level > lastLevel and lastLevel ~= 0 then
		play("LevelUp")
		flash(Color3.fromHex("FFB7C5"), 0.4)
	end
	lastLevel = level
end)
