--!strict
-- วาดฝน/หิมะรอบกล้อง + ฟ้าแลบ ตามสภาพอากาศจาก server (workspace Attribute "Weather", "Lightning")
-- ใต้หลังคา/อาเขตจะลดอนุภาคลง (ยิงเรย์ขึ้นฟ้าเช็ก)
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local camera = workspace.CurrentCamera

local emitterPart = Instance.new("Part")
emitterPart.Name = "WeatherEmitter"
emitterPart.Size = Vector3.new(90, 1, 90)
emitterPart.Transparency = 1
emitterPart.Anchored = true
emitterPart.CanCollide, emitterPart.CanQuery, emitterPart.CanTouch = false, false, false
emitterPart.Parent = workspace

local rain = Instance.new("ParticleEmitter")
rain.Name = "Rain"
rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
rain.Color = ColorSequence.new(Color3.fromRGB(190, 205, 225))
rain.Transparency = NumberSequence.new(0.45)
rain.Size = NumberSequence.new(0.12)
rain.Squash = NumberSequence.new(-14)
rain.Orientation = Enum.ParticleOrientation.VelocityParallel
rain.Lifetime = NumberRange.new(0.9, 1.1)
rain.Speed = NumberRange.new(70, 85)
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Acceleration = Vector3.new(-6, -40, 0)
rain.LightInfluence = 0.5
rain.Rate = 0
rain.Parent = emitterPart

local snow = Instance.new("ParticleEmitter")
snow.Name = "Snow"
snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
snow.Color = ColorSequence.new(Color3.fromRGB(245, 248, 255))
snow.Transparency = NumberSequence.new(0.1)
snow.Size = NumberSequence.new(0.22)
snow.Lifetime = NumberRange.new(5, 7)
snow.Speed = NumberRange.new(5, 9)
snow.EmissionDirection = Enum.NormalId.Bottom
snow.SpreadAngle = Vector2.new(25, 25)
snow.Acceleration = Vector3.new(2, -1, 1)
snow.Drag = 1
snow.RotSpeed = NumberRange.new(-60, 60)
snow.LightInfluence = 0.3
snow.Rate = 0
snow.Parent = emitterPart

local flash = Instance.new("ColorCorrectionEffect")
flash.Name = "LightningFlash"
flash.Brightness = 0
flash.Parent = Lighting

local RATES = {
	Rain = { rain = 420, snow = 0 },
	Storm = { rain = 800, snow = 0 },
	Snow = { rain = 0, snow = 160 },
}

local occlusion = 1 -- 1 = โล่ง, 0.1 = อยู่ใต้หลังคา
local nextCheck = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.RenderStepped:Connect(function()
	camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local pos = camera.CFrame.Position
	emitterPart.CFrame = CFrame.new(pos + Vector3.new(0, 42, 0))
	local now = os.clock()
	if now >= nextCheck then
		nextCheck = now + 0.25
		local character = (game:GetService("Players").LocalPlayer :: Player).Character
		rayParams.FilterDescendantsInstances = if character then { character, emitterPart } else { emitterPart }
		local hit = workspace:Raycast(pos, Vector3.new(0, 60, 0), rayParams)
		occlusion = if hit then 0.08 else 1
	end
	local weather = (workspace:GetAttribute("Weather") :: string?) or "Clear"
	local r = RATES[weather]
	rain.Rate = if r then r.rain * occlusion else 0
	snow.Rate = if r then r.snow * occlusion else 0
	-- พายุมีลมแรง ฝนเฉียง
	rain.Acceleration = Vector3.new(if weather == "Storm" then -22 else -6, -40, if weather == "Storm" then 8 else 0)
end)

-- ฟ้าแลบ: จอสว่างวาบ 2 จังหวะ
local lastLightning = workspace:GetAttribute("Lightning")
workspace:GetAttributeChangedSignal("Lightning"):Connect(function()
	local v = workspace:GetAttribute("Lightning")
	if v == lastLightning then
		return
	end
	lastLightning = v
	flash.Brightness = 0.55
	TweenService:Create(flash, TweenInfo.new(0.12), { Brightness = 0.05 }):Play()
	task.delay(0.16, function()
		flash.Brightness = 0.4
		TweenService:Create(flash, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	end)
end)
