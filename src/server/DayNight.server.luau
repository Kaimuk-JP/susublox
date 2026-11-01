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
	{ From = 20, Name = "Night", Brightness = 0.9, Outdoor = Color3.fromRGB(74, 82, 112), Ambient = Color3.fromRGB(52, 58, 80),
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

local lastName = ""
local start = os.clock()

RunService.Heartbeat:Connect(function()
	local hour = (15.4 + (os.clock() - start) / DAY_SECONDS * 24) % 24 -- เริ่มเกมตอนแสงยามเย็น
	local frozen = workspace:GetAttribute("FreezeHour") -- ทดสอบ/ถ่ายภาพ: ล็อกเวลา
	if type(frozen) == "number" then
		hour = frozen
	end
	Lighting.ClockTime = hour
	local phase = phaseAt(hour)
	if phase.Name ~= lastName then
		lastName = phase.Name
		workspace:SetAttribute("TimeOfDay", phase.Name)
		local info = TweenInfo.new(5)
		TweenService:Create(Lighting, info, { Brightness = phase.Brightness, OutdoorAmbient = phase.Outdoor, Ambient = phase.Ambient }):Play()
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then
			TweenService:Create(atmosphere, info, { Color = phase.HazeColor, Decay = phase.Decay, Density = phase.Density }):Play()
		end
		local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if cc then
			TweenService:Create(cc, info, { TintColor = phase.Tint, Saturation = phase.Sat, Contrast = phase.Contrast }):Play()
		end
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
		if bloom then
			TweenService:Create(bloom, info, { Intensity = phase.Bloom }):Play()
		end
	end
end)
