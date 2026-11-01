--!nocheck
-- รันใน Roblox Studio (โหมด Edit, command bar หรือผ่าน MCP) แล้วกด Ctrl+S เพื่อบันทึกใน Place
-- โทน: โตเกียวยามเย็น (golden hour) โทนอุ่น หมองเล็กน้อย คอนทราสต์สูง ไม่สว่างแบน
-- Lighting.Technology ตั้งจากสคริปต์ตอนเล่นไม่ได้ ต้องตั้งตอน Edit (ถ้าตั้งผ่านสคริปต์ไม่ได้ ให้ตั้งใน Properties ของ Lighting)
-- ค่าอื่นทั้งหมดซ้ำอยู่ใน src/server/MapBuilder.server.luau + DayNight.server.luau ซึ่งตั้งตอนเล่นเสมอ
local Lighting = game:GetService("Lighting")

local okSet = pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)
if not okSet then
	warn("[RealisticLighting] ตั้ง Technology ผ่านสคริปต์ไม่ได้ — ให้ตั้งเองใน Properties: Lighting > Technology = Future")
end
Lighting.Brightness = 2.3
Lighting.ShadowSoftness = 0.3
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.GlobalShadows = true
Lighting.ExposureCompensation = 0
Lighting.GeographicLatitude = 35
Lighting.ClockTime = 16.2
Lighting.OutdoorAmbient = Color3.fromRGB(125, 118, 112)
Lighting.Ambient = Color3.fromRGB(78, 76, 80)
Lighting.ColorShift_Top = Color3.fromHex("FFD9A8")

local function ensure(className, props)
	local e = Lighting:FindFirstChildOfClass(className)
	if not e then
		e = Instance.new(className)
		e.Parent = Lighting
	end
	for k, v in props do
		e[k] = v
	end
end

ensure("Atmosphere", { Density = 0.32, Offset = 0.2, Color = Color3.fromHex("C9B9A6"), Decay = Color3.fromHex("D9A070"), Glare = 0.15, Haze = 1.6 })
ensure("BloomEffect", { Intensity = 0.22, Size = 22, Threshold = 1.2 })
ensure("SunRaysEffect", { Intensity = 0.04, Spread = 0.6 })
ensure("ColorCorrectionEffect", { Saturation = -0.12, Contrast = 0.12, Brightness = -0.02, TintColor = Color3.fromHex("FFF0E0") })
-- ไม่ใช้ DepthOfField (ทำให้ภาพเบลอตอนต่อสู้)
local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then
	dof:Destroy()
end
local okT, tech = pcall(function()
	return Lighting.Technology.Name
end)
print("[RealisticLighting] Technology =", okT and tech or "อ่านไม่ได้จากสคริปต์ — ตรวจใน Properties ของ Lighting")
