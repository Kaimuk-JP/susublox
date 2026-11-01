--!strict
-- สภาพอากาศสุ่ม: ฟ้าใส / ครึ้ม / ฝน / พายุ / หมอก / หิมะ เปลี่ยนทุก 2.5-5 นาที
-- ตั้ง workspace Attribute "Weather" (DayNight ปรับแสง/หมอก/เมฆ, client WeatherFX วาดฝน/หิมะ/ฟ้าแลบ)
-- ทดสอบ: ตั้ง workspace Attribute "ForceWeather" เป็นชื่อสภาพอากาศเพื่อบังคับ (ลบทิ้งเพื่อกลับไปสุ่ม)
local WEATHERS = {
	{ Name = "Clear", Weight = 34 },
	{ Name = "Cloudy", Weight = 20 },
	{ Name = "Rain", Weight = 20 },
	{ Name = "Storm", Weight = 8 },
	{ Name = "Fog", Weight = 8 },
	{ Name = "Snow", Weight = 10 },
}
local rng = Random.new()

local function pick(current: string): string
	local total = 0
	for _, w in WEATHERS do
		if w.Name ~= current then
			total += w.Weight
		end
	end
	local roll = rng:NextNumber(0, total)
	for _, w in WEATHERS do
		if w.Name ~= current then
			roll -= w.Weight
			if roll <= 0 then
				return w.Name
			end
		end
	end
	return "Clear"
end

workspace:SetAttribute("Weather", "Clear")

local function set(name: string)
	if workspace:GetAttribute("Weather") ~= name then
		workspace:SetAttribute("Weather", name)
	end
end

-- ฟ้าแลบตอนพายุ: เพิ่มเลขนับ client เห็นแล้วกะพริบจอ
task.spawn(function()
	while true do
		task.wait(rng:NextNumber(5, 14))
		if workspace:GetAttribute("Weather") == "Storm" then
			workspace:SetAttribute("Lightning", ((workspace:GetAttribute("Lightning") :: number?) or 0) + 1)
		end
	end
end)

task.spawn(function()
	task.wait(30) -- เริ่มเกมด้วยฟ้าใสครู่หนึ่ง
	while true do
		local forced = workspace:GetAttribute("ForceWeather")
		if type(forced) == "string" then
			set(forced)
			task.wait(2)
		else
			set(pick((workspace:GetAttribute("Weather") :: string?) or "Clear"))
			local remain = rng:NextNumber(150, 300)
			while remain > 0 and type(workspace:GetAttribute("ForceWeather")) ~= "string" do
				task.wait(2)
				remain -= 2
			end
		end
	end
end)
