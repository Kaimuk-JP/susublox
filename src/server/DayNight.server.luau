--!strict
-- วงจรกลางวัน/เย็น/กลางคืน (1 วันในเกม = 12 นาทีจริง) โทนเมืองญี่ปุ่นสมจริง: เช้าสีเทาอุ่น เย็นสีส้มหม่น กลางคืนสีน้ำเงินเข้ม + ไฟถนน/ป้ายเด่น
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DAY_SECONDS = 720
local hex = Color3.fromHex

-- Brightness / OutdoorAmbient / Ambient = แสงพื้นฐาน; Haze* = Atmosphere; Cc* = ColorCorrection; Bloom = ความแรงเรืองแสง
local phases = {
	{ From = 6, Name = "Day", Brightness = 2.6, Outdoor = Color3.fromRGB(135, 135, 138), Ambient = Color3.fromRGB(86, 86, 90),
		HazeColor = hex("C4CBCF"), Decay = hex("D2B896"), Density = 0.3, Tint = hex("FFF6EA"), Sat = -0.1, Contrast = 0.1, Bloom = 0.18 },
	{ From = 15, Name = "GoldenHour", Brightness = 2.2, Outdoor = Color3.fromRGB(125, 112, 100), Ambient = Color3.fromRGB(78, 70, 66),
		HazeColor = hex("D3B792"), Decay = hex("DE9A62"), Density = 0.4, Tint = hex("FFE6C8"), Sat = -0.08, Contrast = 0.14, Bloom = 0.24 },
	{ From = 17.5, Name = "Evening", Brightness = 1.7, Outdoor = Color3.fromRGB(104, 88, 90), Ambient = Color3.fromRGB(64, 56, 62),
		HazeColor = hex("B98C78"), Decay = hex("C46A4A"), Density = 0.45, Tint = hex("FFD2B0"), Sat = -0.05, Contrast = 0.16, Bloom = 0.32 },
	-- กลางคืนยังต้องมองเห็นพื้นที่ต่อสู้ได้: ไม่มืดสนิท แต่ให้ไฟถนน/ป้ายร้านเป็นจุดเด่น
	{ From = 20, Name = "Night", Brightness = 1.3, Outdoor = Color3.fromRGB(104, 114, 152), Ambient = Color3.fromRGB(84, 92, 124),
		HazeColor = hex("3C465E"), Decay = hex("2A3048"), Density = 0.42, Tint = hex("D8E0FF"), Sat = -0.12, Contrast = 0.18, Bloom = 0.5 },
}

local function phaseAt(hour: number)
	local current = phases[#phases] -- ก่อน 6 โมงยังเป็นกลางคืน
	for _, p in phases do
		if hour >= p.From then
			current = p
		end
	end
	return current
end

-- รอให้ MapBuilder ตั้งค่าแสงของตัวเองเสร็จก่อน (มันสร้าง Atmosphere/ColorCorrection ใหม่) ไม่งั้นเอฟเฟกต์ที่หาไว้จะถูกลบทิ้ง
local waited = os.clock()
while workspace:GetAttribute("SchoolMapReady") ~= true and os.clock() - waited < 120 do
	task.wait(0.5)
end

-- ท้องฟ้า: ดวงจันทร์ + ดาวตอนกลางคืน (ต้องมี Sky เพียงอันเดียว เปิด CelestialBodiesShown)
for _, sky in Lighting:GetChildren() do
	if sky:IsA("Sky") then
		sky:Destroy() -- ล้างของเดิม (เคยซ้ำ 2 อัน) แล้วสร้างอันเดียวด้านล่าง
	end
end
local sky = Instance.new("Sky")
sky.Name = "NightSky"
sky.CelestialBodiesShown = true
sky.StarCount = 3500
sky.MoonAngularSize = 14
sky.SunAngularSize = 9
sky.Parent = Lighting

-- เมฆ (ใน Terrain) ใช้แสดงฟ้าครึ้ม/พายุ
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
clouds.Cover = 0.45
clouds.Density = 0.5
clouds.Parent = workspace.Terrain

-- สภาพอากาศ (WeatherService ตั้ง workspace Attribute "Weather"): ปรับค่าทับเฟสเวลา
-- Dark = คูณความสว่าง, Fog = บวกความหนาแน่นหมอก, Haze, Grey = ผสมสีหมอกไปทางเทา, Cover/CloudDensity = เมฆ, Sat = ปรับความอิ่มสี
local weatherMods: { [string]: { Dark: number, Fog: number, Haze: number, Grey: number, Cover: number, CloudDensity: number, Sat: number } } = {
	Clear = { Dark = 1, Fog = 0, Haze = 0, Grey = 0, Cover = 0.45, CloudDensity = 0.5, Sat = 0 },
	Cloudy = { Dark = 0.85, Fog = 0.05, Haze = 0.6, Grey = 0.3, Cover = 0.8, CloudDensity = 0.7, Sat = -0.04 },
	Rain = { Dark = 0.7, Fog = 0.2, Haze = 1.4, Grey = 0.5, Cover = 0.95, CloudDensity = 0.85, Sat = -0.08 },
	Storm = { Dark = 0.62, Fog = 0.3, Haze = 2, Grey = 0.65, Cover = 1, CloudDensity = 1, Sat = -0.14 },
	Fog = { Dark = 0.8, Fog = 0.45, Haze = 3, Grey = 0.6, Cover = 0.7, CloudDensity = 0.6, Sat = -0.1 },
	Snow = { Dark = 0.9, Fog = 0.25, Haze = 1.8, Grey = 0.55, Cover = 0.9, CloudDensity = 0.8, Sat = -0.12 },
}
local greyFor = { Day = hex("B9BEC4"), GoldenHour = hex("B3A9A0"), Evening = hex("8F8890"), Night = hex("4A5068") }

local lastName = ""
local lastWeather = ""
local start = os.clock()

local function apply(phase, instant: boolean?)
	local weather = (workspace:GetAttribute("Weather") :: string?) or "Clear"
	local m = weatherMods[weather] or weatherMods.Clear
	local info = TweenInfo.new(if instant then 0.01 else (if weather ~= lastWeather then 8 else 5))
	local grey = greyFor[phase.Name] or hex("B9BEC4")
	TweenService:Create(Lighting, info, {
		Brightness = phase.Brightness * m.Dark,
		OutdoorAmbient = phase.Outdoor:Lerp(grey, m.Grey * 0.35),
		Ambient = phase.Ambient:Lerp(grey, m.Grey * 0.25),
	}):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, {
			Color = phase.HazeColor:Lerp(grey, m.Grey),
			Decay = phase.Decay,
			Density = math.clamp(phase.Density + m.Fog, 0, 0.65),
			Haze = 0.4 + m.Haze,
		}):Play()
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		TweenService:Create(cc, info, { TintColor = phase.Tint, Saturation = phase.Sat + m.Sat, Contrast = phase.Contrast }):Play()
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		TweenService:Create(bloom, info, { Intensity = phase.Bloom }):Play()
	end
	TweenService:Create(clouds, info, { Cover = m.Cover, Density = m.CloudDensity }):Play()
	lastWeather = weather
end

RunService.Heartbeat:Connect(function()
	local hour = (15.4 + (os.clock() - start) / DAY_SECONDS * 24) % 24 -- เริ่มเกมตอนแสงยามเย็น
	local frozen = workspace:GetAttribute("FreezeHour") -- ทดสอบ/ถ่ายภาพ: ล็อกเวลา
	if type(frozen) == "number" then
		hour = frozen
	end
	Lighting.ClockTime = hour
	local phase = phaseAt(hour)
	local weather = (workspace:GetAttribute("Weather") :: string?) or "Clear"
	if phase.Name ~= lastName or weather ~= lastWeather then
		lastName = phase.Name
		workspace:SetAttribute("TimeOfDay", phase.Name)
		apply(phase)
	end
end)
