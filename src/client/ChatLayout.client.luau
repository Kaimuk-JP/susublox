--!strict
-- ย้ายหน้าต่างแชทของ Roblox ไปมุมซ้ายล่าง ไม่ให้ทับหลอดเลือด/พลังงาน (HUD อยู่มุมซ้ายบน)
local TextChatService = game:GetService("TextChatService")

local function apply()
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if window then
		window.HorizontalAlignment = Enum.HorizontalAlignment.Left
		window.VerticalAlignment = Enum.VerticalAlignment.Bottom
		window.WidthScale = 0.28
		window.HeightScale = 0.22
	end
end

apply()
TextChatService.ChildAdded:Connect(function(child)
	if child:IsA("ChatWindowConfiguration") then
		apply()
	end
end)
