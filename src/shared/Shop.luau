--!strict
-- สินค้าในร้าน (ซื้อด้วยเยน) และ ID ของ Robux
-- ขายเฉพาะความสะดวกและของตกแต่ง ไม่ขายพลังโจมตีตรง ๆ
-- ตั้ง ID จริงหลังสร้าง Game Pass / Developer Product ใน Creator Hub (0 = ยังไม่เปิดขาย)
local Shop = {}

-- ตั้งราคาจากรายได้ต่อชั่วโมงประมาณ 600 เยน ของชิ้นใหญ่ = เล่น 3–5 ชั่วโมง
Shop.YenPerHour = 600

Shop.Items = {
	Uniform_Sakura = { Name = "ชุดนักเรียนซากุระ", Price = 400, Kind = "Outfit" },
	Uniform_Night = { Name = "ชุดนักเรียนกลางคืน", Price = 900, Kind = "Outfit" },
	Jacket_Gang = { Name = "แจ็กเกตหัวหน้าแก๊ง", Price = 1800, Kind = "Outfit" },
	Aura_Sparkle = { Name = "ออร่าประกาย", Price = 2400, Kind = "Outfit" },
	StatReset = { Name = "รีเซ็ตสเตตัส", Price = 300, Kind = "Service" },
} :: { [string]: { Name: string, Price: number, Kind: string } }

Shop.GangCreateCost = 500

Shop.GamePasses = {
	Exp2x = 0, -- EXP x2 ถาวร
	ExtraStorage = 0,
	TauntDance = 0,
} :: { [string]: number }

Shop.Products = {
	ExpBoost30 = 0, -- บูสต์ EXP 30 นาที
	GangRename = 0,
} :: { [string]: number }

Shop.ExpBoostSeconds = 1800

return Shop
