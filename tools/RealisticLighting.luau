--!nocheck
-- รันใน Roblox Studio (โหมด Edit, command bar หรือผ่าน MCP) เพื่อเปิดแสงสมจริง แล้วบันทึก Place
-- Lighting.Technology ตั้งจากสคริปต์ตอนเล่นไม่ได้ ต้องตั้งตอนแก้ไขแล้วเซฟไว้ใน Place
local Lighting = game:GetService("Lighting")

pcall(function()
	Lighting.Technology = Enum.Technology.Future -- เงา/แสงสะท้อนสมจริง
end)
Lighting.Brightness = 3
Lighting.ShadowSoftness = 0.25
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.GlobalShadows = true
Lighting.ExposureCompensation = 0.1
Lighting.OutdoorAmbient = Color3.fromRGB(110, 118, 140)
Lighting.Ambient = Color3.fromRGB(70, 74, 90)

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

ensure("Atmosphere", { Density = 0.3, Offset = 0.25, Color = Color3.fromRGB(199, 213, 232), Decay = Color3.fromRGB(106, 112, 125), Glare = 0.3, Haze = 1.2 })
ensure("BloomEffect", { Intensity = 0.35, Size = 28, Threshold = 1.2 })
ensure("SunRaysEffect", { Intensity = 0.08, Spread = 0.9 })
ensure("ColorCorrectionEffect", { Saturation = 0.08, Contrast = 0.08, TintColor = Color3.fromRGB(255, 250, 245) })
ensure("DepthOfFieldEffect", { FarIntensity = 0.12, FocusDistance = 120, InFocusRadius = 80, NearIntensity = 0 })
print("[RealisticLighting] Technology =", Lighting.Technology.Name)
