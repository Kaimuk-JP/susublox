--!strict
-- รายการชุด: ทุกคนเริ่มด้วยชุดนักเรียน (ฟรี) ชุดอื่นซื้อจากร้านด้วยเยน/ได้จากบอส/Battle Pass
local Shop = require(script.Parent.Shop)

local DEFAULT = "Uniform_School"

local list: { string } = { DEFAULT, "Uniform_Sakura", "Uniform_Night", "Jacket_Gang", "Aura_Sparkle" }

return {
	Default = DEFAULT,
	Order = list,
	Name = function(id: string): string
		if id == DEFAULT then
			return "ชุดนักเรียน"
		end
		local item = Shop.Items[id]
		return if item then item.Name else id
	end,
	Price = function(id: string): number
		local item = Shop.Items[id]
		return if item then item.Price else 0
	end,
}
