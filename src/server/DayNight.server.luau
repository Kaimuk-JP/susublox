--!strict
-- วงจรกลางวัน/เย็น/กลางคืน (1 วันในเกม = 12 นาทีจริง) เปลี่ยนโทนบรรยากาศแบบพาสเทล
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DAY_SECONDS = 720

local phases = {
	{ From = 6, Name = "Day", Ambient = Color3.fromHex("FFE9F0"), Haze = 0.25 },
	{ From = 17, Name = "Evening", Ambient = Color3.fromHex("FFC8A2"), Haze = 0.35 },
	{ From = 20, Name = "Night", Ambient = Color3.fromHex("8C9AD0"), Haze = 0.4 },
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

local lastName = ""
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local start = os.clock()

RunService.Heartbeat:Connect(function()
	local hour = (6 + (os.clock() - start) / DAY_SECONDS * 24) % 24
	Lighting.ClockTime = hour
	local phase = phaseAt(hour)
	if phase.Name ~= lastName then
		lastName = phase.Name
		workspace:SetAttribute("TimeOfDay", phase.Name)
		atmosphere = atmosphere or Lighting:FindFirstChildOfClass("Atmosphere")
		-- กลางคืนยังต้องมองเห็นพื้นที่ต่อสู้ได้: ลดความสว่างแต่ไม่มืดสนิท
		local night = phase.Name == "Night"
		TweenService:Create(Lighting, TweenInfo.new(5), {
			Brightness = if night then 1.2 else 2.5,
			OutdoorAmbient = if night then Color3.fromRGB(110, 120, 170) else Color3.fromRGB(150, 150, 170),
		}):Play()
		if atmosphere then
			TweenService:Create(atmosphere, TweenInfo.new(5), { Color = phase.Ambient, Density = phase.Haze }):Play()
		end
	end
end)
