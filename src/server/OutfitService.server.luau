--!strict
-- ชุดตัวละครแบบโค้ดล้วน: เปลี่ยนสีร่างกาย + ชิ้นส่วนตกแต่งเชื่อมกับตัว (ไม่ใช้ asset ภายนอก)
-- ทุกคนเริ่มด้วยชุดนักเรียน; สวมชุดที่ซื้อ/ได้มา ผู้เล่นอื่นเห็นด้วย
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Outfits = require(ReplicatedStorage.Shared.Outfits)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "OutfitRemote"
remote.Parent = ReplicatedStorage

local function hex(c: string): Color3
	return Color3.fromHex(c)
end

type Look = {
	Torso: string,
	Arms: string,
	Legs: string,
	Shoes: string?,
	Decor: ((character: Model, add: (partName: string, size: Vector3, offset: CFrame, color: string, material: Enum.Material?, shape: Enum.PartType?) -> Part?) -> ())?,
	Aura: boolean?,
}

-- ตราโรงเรียนวงกลมปักที่หลังเสื้อกากุรัน (ออกแบบเอง: วงแหวนสองชั้น + อักษรคันจิ "素々高")
type AddFn = (partName: string, size: Vector3, offset: CFrame, color: string, material: Enum.Material?, shape: Enum.PartType?) -> Part?
local function backCrest(add: AddFn, withText: string?)
	local back = add("UpperTorso", Vector3.new(1.85, 1.55, 0.06), CFrame.new(0, -0.05, 0.54), "0B0B0F")
	if not back then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.Parent = back
	local function ring(sizeScale: number, thickness: number, transparency: number?)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(sizeScale * 0.8, sizeScale)
		frame.SizeConstraint = Enum.SizeConstraint.RelativeYY
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
		local stroke = Instance.new("UIStroke")
		stroke.Color = hex("F4F1E8")
		stroke.Thickness = thickness
		stroke.Transparency = transparency or 0
		stroke.Parent = frame
	end
	ring(0.92, 4)
	ring(0.8, 2)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.5, 0.62)
	label.BackgroundTransparency = 1
	label.Text = withText or "素々\n高"
	label.TextColor3 = hex("F4F1E8")
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui
end

-- แผ่นพิมพ์ข้อความที่หลังเสื้อ (ใช้กับชุดที่มีตัวอักษรปัก/สกรีน)
local function backPrint(add: AddFn, text: string, bg: string, fg: string, size: Vector3, y: number, vertical: boolean?)
	local panel = add("UpperTorso", size, CFrame.new(0, y, 0.55), bg)
	if not panel then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = if vertical then table.concat(string.split(text, ""), "\n") else text
	label.TextColor3 = hex(fg)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui
end

local looks: { [string]: Look } = {
	Uniform_School = {
		Torso = "FFFFFF",
		Arms = "FFFFFF",
		Legs = "2B2D42",
		Shoes = "2B2D42",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(0.9, 0.55, 0.25), CFrame.new(0, 0.55, -0.62), "EF233C") -- ริบบิ้น
			add("UpperTorso", Vector3.new(1.9, 0.18, 1.1), CFrame.new(0, 0.95, -0.05), "2B2D42") -- ปกเสื้อ
		end,
	},
	-- กากุรัน: ชุดนักเรียนชายคอตั้งสีดำ กระดุมทอง 5 เม็ด ไหล่เสริม ตราโรงเรียนที่อก
	Gakuran_Standard = {
		Torso = "15151A",
		Arms = "15151A",
		Legs = "1A1A22",
		Shoes = "0F0F14",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(1.9, 0.5, 1.1), CFrame.new(0, 1.0, -0.02), "15151A") -- คอตั้ง
			add("UpperTorso", Vector3.new(0.8, 0.14, 0.12), CFrame.new(0, 1.05, -0.56), "FFFFFF") -- ขอบเสื้อด้านในขาว
			add("UpperTorso", Vector3.new(0.32, 1.6, 0.06), CFrame.new(0, 0, -0.52), "0B0B0F") -- แนวกระดุม
			for i = 0, 4 do
				add("UpperTorso", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.62 - i * 0.32, -0.56), "FFE066", Enum.Material.Neon, Enum.PartType.Ball)
			end
			add("UpperTorso", Vector3.new(0.5, 0.5, 1.2), CFrame.new(-1.15, 0.78, 0), "15151A") -- ไหล่เสริม
			add("UpperTorso", Vector3.new(0.5, 0.5, 1.2), CFrame.new(1.15, 0.78, 0), "15151A")
			add("UpperTorso", Vector3.new(0.42, 0.42, 0.1), CFrame.new(0.6, 0.45, -0.56), "FFE066", Enum.Material.Neon, Enum.PartType.Ball) -- ตราโรงเรียน
			backCrest(add) -- ตราวงกลมปักที่หลัง
		end,
	},
	-- นากะรัน: ตัวยาวถึงเข่า กางเกงขาบาน ปักอักษรที่หลัง
	Gakuran_Nagaran = {
		Torso = "15151A",
		Arms = "15151A",
		Legs = "1A1A22",
		Shoes = "0F0F14",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(1.9, 0.5, 1.1), CFrame.new(0, 1.0, -0.02), "15151A")
			add("UpperTorso", Vector3.new(0.8, 0.14, 0.12), CFrame.new(0, 1.05, -0.56), "FFFFFF")
			add("UpperTorso", Vector3.new(0.32, 1.6, 0.06), CFrame.new(0, 0, -0.52), "0B0B0F")
			for i = 0, 4 do
				add("UpperTorso", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.62 - i * 0.32, -0.56), "FFE066", Enum.Material.Neon, Enum.PartType.Ball)
			end
			-- ชายเสื้อยาวถึงเข่า (ผ่าหลังเป็นสองแผ่น)
			add("LowerTorso", Vector3.new(2.2, 1.9, 1.15), CFrame.new(0, -1.35, 0), "15151A")
			add("LowerTorso", Vector3.new(2.3, 0.18, 1.25), CFrame.new(0, -2.3, 0), "FFE066", Enum.Material.Neon) -- แถบชายเสื้อ
			-- กางเกงขาบาน (บอนตัน)
			for _, leg in { "LeftUpperLeg", "RightUpperLeg" } do
				add(leg, Vector3.new(1.55, 1.3, 1.55), CFrame.new(0, -0.1, 0), "1A1A22")
			end
			for _, leg in { "LeftLowerLeg", "RightLowerLeg" } do
				add(leg, Vector3.new(1.35, 1.2, 1.35), CFrame.new(0, 0.1, 0), "1A1A22")
			end
			-- ปักหลัง: ตราวงกลมโรงเรียน + แขนเสื้อลายคลื่นสีขาวที่ปลายแขน
			backCrest(add, "素々\n高")
			for _, arm in { "LeftLowerArm", "RightLowerArm" } do
				add(arm, Vector3.new(1.15, 0.5, 1.15), CFrame.new(0, -0.35, 0), "DCE3EE") -- ลายคลื่นปลายแขน (ย่อเป็นแถบ)
			end
		end,
	},
	-- ทันรัน: ตัวสั้นเหนือเอว เห็นเสื้อขาวด้านใน กางเกงขาบานมาก เข็มขัดหัวทอง
	Gakuran_Tanran = {
		Torso = "15151A",
		Arms = "15151A",
		Legs = "20202A",
		Shoes = "FFFFFF",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(1.9, 0.5, 1.1), CFrame.new(0, 1.0, -0.02), "15151A")
			add("UpperTorso", Vector3.new(0.32, 1.4, 0.06), CFrame.new(0, 0.1, -0.52), "0B0B0F")
			for i = 0, 3 do
				add("UpperTorso", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.55 - i * 0.32, -0.56), "FFE066", Enum.Material.Neon, Enum.PartType.Ball)
			end
			add("UpperTorso", Vector3.new(0.5, 0.5, 1.2), CFrame.new(-1.15, 0.78, 0), "15151A")
			add("UpperTorso", Vector3.new(0.5, 0.5, 1.2), CFrame.new(1.15, 0.78, 0), "15151A")
			-- เสื้อขาวด้านใน + เข็มขัด
			add("LowerTorso", Vector3.new(2.05, 0.9, 1.05), CFrame.new(0, 0.1, 0), "FFFFFF")
			add("LowerTorso", Vector3.new(2.15, 0.22, 1.12), CFrame.new(0, -0.3, 0), "0B0B0F")
			add("LowerTorso", Vector3.new(0.45, 0.35, 0.1), CFrame.new(0, -0.3, -0.58), "FFE066", Enum.Material.Neon)
			-- กางเกงขาบานพิเศษ ขากว้างที่ต้นขา เรียวที่ข้อเท้า
			for _, leg in { "LeftUpperLeg", "RightUpperLeg" } do
				add(leg, Vector3.new(1.9, 1.4, 1.9), CFrame.new(0, -0.05, 0), "20202A")
			end
			for _, leg in { "LeftLowerLeg", "RightLowerLeg" } do
				add(leg, Vector3.new(1.5, 1.3, 1.5), CFrame.new(0, 0.1, 0), "20202A")
			end
			backCrest(add)
		end,
	},
	Uniform_Sakura = {
		Torso = "FFB7C5",
		Arms = "FFB7C5",
		Legs = "FFFFFF",
		Shoes = "FFFFFF",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(2.1, 0.22, 1.3), CFrame.new(0, 0.95, -0.05), "FFFFFF") -- ปกกะลาสี
			add("UpperTorso", Vector3.new(0.9, 0.55, 0.25), CFrame.new(0, 0.55, -0.62), "EF233C")
			add("Head", Vector3.new(0.5, 0.5, 0.2), CFrame.new(0.55, 0.55, -0.4), "FF8FAB", Enum.Material.SmoothPlastic, Enum.PartType.Ball) -- กิ๊บติดผม
		end,
	},
	Uniform_Night = {
		Torso = "1B1D3A",
		Arms = "1B1D3A",
		Legs = "1B1D3A",
		Shoes = "0F1024",
		Decor = function(_, add)
			for i = 0, 2 do
				add("UpperTorso", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.55 - i * 0.45, -0.58), "FFE066", Enum.Material.Neon, Enum.PartType.Ball) -- กระดุมทอง
			end
			add("UpperTorso", Vector3.new(1.9, 0.14, 1.1), CFrame.new(0, 0.95, -0.05), "FFE066", Enum.Material.Neon)
		end,
	},
	Jacket_Gang = {
		Torso = "15151A",
		Arms = "15151A",
		Legs = "333340",
		Shoes = "EF233C",
		Decor = function(character, add)
			local player = Players:GetPlayerFromCharacter(character)
			local gang = player and player:GetAttribute("GangColor")
			local color = if typeof(gang) == "string" and gang ~= "" then gang else "EF233C"
			add("UpperTorso", Vector3.new(1.7, 1.7, 0.12), CFrame.new(0, 0, 0.62), color) -- ลายหลัง
			add("UpperTorso", Vector3.new(0.5, 0.5, 1.3), CFrame.new(-1.15, 0.8, 0), "15151A") -- ไหล่
			add("UpperTorso", Vector3.new(0.5, 0.5, 1.3), CFrame.new(1.15, 0.8, 0), "15151A")
			add("UpperTorso", Vector3.new(0.18, 1.9, 0.12), CFrame.new(0, 0, -0.62), color) -- แถบซิป
		end,
	},
	-- โทกกุฟุกุ: ชุดสายแก๊งบอซโซกุ โค้ตขาวยาว ปักคันจิที่หลัง สายคาดแดง
	Tokko_Fuku = {
		Torso = "F4F1E8",
		Arms = "F4F1E8",
		Legs = "F4F1E8",
		Shoes = "15151A",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(1.9, 0.5, 1.1), CFrame.new(0, 1.0, -0.02), "F4F1E8") -- คอตั้ง
			add("UpperTorso", Vector3.new(2.05, 0.38, 1.15), CFrame.new(0, -0.55, 0), "C1272D") -- สายคาดเอวแดง
			add("UpperTorso", Vector3.new(0.5, 0.5, 1.2), CFrame.new(-1.15, 0.78, 0), "E8C34A", Enum.Material.Metal) -- บ่าทอง
			add("UpperTorso", Vector3.new(0.5, 0.5, 1.2), CFrame.new(1.15, 0.78, 0), "E8C34A", Enum.Material.Metal)
			add("LowerTorso", Vector3.new(2.25, 2.1, 1.2), CFrame.new(0, -1.3, 0), "F4F1E8") -- ชายโค้ตยาว
			add("LowerTorso", Vector3.new(2.35, 0.16, 1.3), CFrame.new(0, -2.3, 0), "C1272D")
			for _, arm in { "LeftLowerArm", "RightLowerArm" } do
				add(arm, Vector3.new(1.15, 0.4, 1.15), CFrame.new(0, -0.35, 0), "C1272D") -- ข้อมือแดง
			end
			backPrint(add, "夜露死苦", "F4F1E8", "C1272D", Vector3.new(1.4, 2.7, 0.06), -0.2, true)
		end,
	},
	-- เคนโด: เสื้อครามเข้ม ฮากามะขากว้าง ผ้าคาดหัวขาวจุดแดง
	Kendo_Hakama = {
		Torso = "1F2A44",
		Arms = "1F2A44",
		Legs = "161C30",
		Shoes = "E8E2D0",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(1.95, 0.22, 1.12), CFrame.new(0, 0.95, -0.05), "F4F1E8") -- ขอบคอเสื้อ
			add("UpperTorso", Vector3.new(0.28, 1.5, 0.08), CFrame.new(-0.35, 0.15, -0.54) * CFrame.Angles(0, 0, math.rad(-18)), "10162A") -- ปกไขว้
			add("UpperTorso", Vector3.new(0.28, 1.5, 0.08), CFrame.new(0.35, 0.15, -0.54) * CFrame.Angles(0, 0, math.rad(18)), "10162A")
			add("LowerTorso", Vector3.new(2.3, 0.7, 1.3), CFrame.new(0, 0, 0), "161C30") -- เอวฮากามะ
			add("LowerTorso", Vector3.new(0.2, 0.9, 0.1), CFrame.new(-0.3, -0.3, -0.68), "F4F1E8") -- เชือกผูก
			add("LowerTorso", Vector3.new(0.2, 0.9, 0.1), CFrame.new(0.3, -0.3, -0.68), "F4F1E8")
			for _, leg in { "LeftUpperLeg", "RightUpperLeg" } do
				add(leg, Vector3.new(1.95, 1.5, 1.95), CFrame.new(0, -0.05, 0), "161C30")
			end
			for _, leg in { "LeftLowerLeg", "RightLowerLeg" } do
				add(leg, Vector3.new(1.85, 1.3, 1.85), CFrame.new(0, 0.1, 0), "161C30")
			end
			add("Head", Vector3.new(1.4, 0.28, 1.4), CFrame.new(0, 0.35, 0), "F4F1E8") -- ฮาจิมากิ
			add("Head", Vector3.new(0.3, 0.3, 0.08), CFrame.new(0, 0.35, -0.7), "C1272D", Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end,
	},
	-- คาราเต้: ชุดขาวล้วน สายดำ
	Karate_Gi = {
		Torso = "F4F1E8",
		Arms = "F4F1E8",
		Legs = "EDE9DD",
		Shoes = "D8B89C",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(0.3, 1.55, 0.08), CFrame.new(-0.4, 0.2, -0.54) * CFrame.Angles(0, 0, math.rad(-20)), "FFFFFF") -- ปกรูปตัววี
			add("UpperTorso", Vector3.new(0.3, 1.55, 0.08), CFrame.new(0.4, 0.2, -0.54) * CFrame.Angles(0, 0, math.rad(20)), "FFFFFF")
			add("LowerTorso", Vector3.new(2.15, 0.32, 1.12), CFrame.new(0, 0.25, 0), "0B0B0F") -- สายดำ
			add("LowerTorso", Vector3.new(0.26, 0.95, 0.1), CFrame.new(-0.18, -0.35, -0.6), "0B0B0F") -- ปลายสาย
			add("LowerTorso", Vector3.new(0.26, 0.8, 0.1), CFrame.new(0.2, -0.3, -0.6) * CFrame.Angles(0, 0, math.rad(8)), "0B0B0F")
			add("UpperTorso", Vector3.new(0.4, 0.4, 0.08), CFrame.new(0.65, 0.45, -0.56), "C1272D", Enum.Material.SmoothPlastic, Enum.PartType.Ball) -- ตราสำนัก
		end,
	},
	-- ยูกาตะเทศกาล: ครามลายซากุระ โอบิแดงผูกโบว์หลัง
	Yukata_Festival = {
		Torso = "2E4A8F",
		Arms = "2E4A8F",
		Legs = "2E4A8F",
		Shoes = "8B5A2B",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(1.9, 0.16, 1.1), CFrame.new(0, 0.95, -0.05), "F4F1E8") -- คอเสื้อขาว
			add("LowerTorso", Vector3.new(2.15, 0.8, 1.15), CFrame.new(0, 0.2, 0), "C1272D") -- โอบิ
			add("LowerTorso", Vector3.new(1.4, 0.95, 0.35), CFrame.new(0, 0.2, 0.7), "C1272D") -- โบว์หลัง
			add("LowerTorso", Vector3.new(2.15, 1.5, 1.15), CFrame.new(0, -1.0, 0), "2E4A8F") -- ชายยูกาตะ
			for _, leg in { "LeftUpperLeg", "RightUpperLeg" } do
				add(leg, Vector3.new(1.5, 1.2, 1.5), CFrame.new(0, -0.05, 0), "2E4A8F")
			end
			for _, d in { Vector3.new(-0.6, 0.5, 0), Vector3.new(0.5, -0.15, 0), Vector3.new(-0.35, -0.7, 0), Vector3.new(0.65, 0.55, 0) } do
				add("UpperTorso", Vector3.new(0.22, 0.22, 0.06), CFrame.new(d.X, d.Y, -0.55), "FFD1DC", Enum.Material.SmoothPlastic, Enum.PartType.Ball) -- ลายซากุระ
			end
			add("LowerTorso", Vector3.new(0.22, 0.22, 0.06), CFrame.new(-0.6, -1.0, -0.6), "FFD1DC", Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			add("LowerTorso", Vector3.new(0.22, 0.22, 0.06), CFrame.new(0.55, -1.5, -0.6), "FFD1DC", Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			add("Head", Vector3.new(0.5, 0.5, 0.2), CFrame.new(0.55, 0.55, -0.4), "FF8FAB", Enum.Material.SmoothPlastic, Enum.PartType.Ball) -- ดอกไม้ติดผม
		end,
	},
	-- ฮู้ดสตรีท: เสื้อฮู้ดเทา กระเป๋าจิงโจ้ รองเท้าสะท้อนแสง
	Hoodie_Street = {
		Torso = "4A4E5A",
		Arms = "4A4E5A",
		Legs = "20232B",
		Shoes = "E8FF5A",
		Decor = function(_, add)
			add("UpperTorso", Vector3.new(1.7, 0.75, 0.95), CFrame.new(0, 0.95, 0.45), "3B3E49") -- ฮู้ดที่คอ
			add("UpperTorso", Vector3.new(1.3, 0.55, 0.1), CFrame.new(0, -0.5, -0.56), "3B3E49") -- กระเป๋าจิงโจ้
			add("UpperTorso", Vector3.new(0.08, 0.65, 0.08), CFrame.new(-0.25, 0.55, -0.56), "F4F1E8") -- เชือกฮู้ด
			add("UpperTorso", Vector3.new(0.08, 0.65, 0.08), CFrame.new(0.25, 0.55, -0.56), "F4F1E8")
			for _, arm in { "LeftLowerArm", "RightLowerArm" } do
				add(arm, Vector3.new(1.1, 0.3, 1.1), CFrame.new(0, -0.4, 0), "3B3E49") -- ข้อมือรัด
			end
			backPrint(add, "SUSU", "2B2D42", "FFE066", Vector3.new(1.6, 0.6, 0.06), 0.3)
		end,
	},
	Aura_Sparkle = {
		Torso = "FFFFFF",
		Arms = "FFFFFF",
		Legs = "2B2D42",
		Shoes = "2B2D42",
		Aura = true,
	},
}

local function clearOutfit(character: Model)
	for _, d in character:GetDescendants() do
		if d.Name == "OutfitDecor" or d.Name == "OutfitAura" then
			d:Destroy()
		end
	end
	for _, c in character:GetChildren() do
		if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") then
			c:Destroy() -- ลบเสื้อกางเกงเดิมของอวาตาร์ให้สีชุดเกมเห็นชัด
		end
	end
end

local function setColor(character: Model, names: { string }, color: Color3)
	for _, n in names do
		local p = character:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			p.Color = color
		end
	end
end

local function apply(character: Model, id: string)
	local look = looks[id] or looks[Outfits.Default]
	-- Aura_Sparkle ใช้ชุดนักเรียนเป็นฐานแล้วเพิ่มออร่า
	local base = if look.Aura then looks[Outfits.Default] else look
	clearOutfit(character)

	local bc = character:FindFirstChildOfClass("BodyColors")
	if bc then
		bc:Destroy() -- ไม่ให้ BodyColors ทับสีที่ตั้งเอง
	end
	setColor(character, { "UpperTorso", "LowerTorso" }, hex(base.Torso))
	setColor(character, { "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }, hex(base.Arms))
	setColor(character, { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }, hex(base.Legs))
	setColor(character, { "LeftFoot", "RightFoot" }, hex(base.Shoes or base.Legs))

	local function add(partName: string, size: Vector3, offset: CFrame, color: string, material: Enum.Material?, shape: Enum.PartType?): Part?
		local anchor = character:FindFirstChild(partName) :: BasePart?
		if not anchor then
			return nil
		end
		local p = Instance.new("Part")
		p.Name = "OutfitDecor"
		p.Size = size
		p.Color = hex(color)
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Massless = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CFrame = anchor.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchor
		weld.Part1 = p
		weld.Parent = p
		p.Parent = character
		return p
	end

	if base.Decor then
		base.Decor(character, add)
	end

	if look.Aura then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local e = Instance.new("ParticleEmitter")
			e.Name = "OutfitAura"
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(hex("FFB7C5"), hex("FFE066"))
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
			e.Lifetime = NumberRange.new(0.8, 1.4)
			e.Speed = NumberRange.new(1, 3)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Rate = 22
			e.LightEmission = 1
			e.Parent = root
			e.Rate = 10 -- ประกายเบาๆ ไม่ใช้แสงชมพูฟุ้งทับชุด
		end
	end
end

local function publish(player: Player)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	player:SetAttribute("Outfit", p.EquippedOutfit)
	for _, id in Outfits.Order do
		player:SetAttribute("OutfitOwned_" .. id, id == Outfits.Default or table.find(p.Owned, id) ~= nil)
	end
end

local function applyTo(player: Player)
	local p = PlayerData.Get(player)
	local char = player.Character
	if p and char and char:FindFirstChild("UpperTorso") then
		apply(char, p.EquippedOutfit)
	end
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown, id: unknown)
	if action == "ToggleAura" then
		player:SetAttribute("AuraOff", player:GetAttribute("AuraOff") ~= true) -- ถอด/สวมออร่าสไตล์ (ไม่แตะชุด)
		return
	end
	local p = PlayerData.Get(player)
	if not p or action ~= "Equip" or typeof(id) ~= "string" or not looks[id] then
		return
	end
	if id ~= Outfits.Default and not table.find(p.Owned, id) then
		return -- ต้องเป็นเจ้าของก่อน
	end
	p.EquippedOutfit = id
	publish(player)
	applyTo(player)
end)

local function setup(player: Player)
	for _ = 1, 100 do
		if PlayerData.Get(player) then
			break
		end
		task.wait(0.2)
	end
	publish(player)
	local function onChar(char: Model)
		char:WaitForChild("UpperTorso", 10)
		task.wait(0.5) -- รอให้ Humanoid ใส่คำอธิบายอวาตาร์เสร็จก่อน
		applyTo(player)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		task.spawn(onChar, player.Character)
	end
end
Players.PlayerAdded:Connect(setup)
for _, pl in Players:GetPlayers() do
	task.spawn(setup, pl)
end

-- ชุดที่ได้จากการซื้อ/บอส/Battle Pass เพิ่มเข้า Owned โดยตรง จึงซิงก์สถานะความเป็นเจ้าของเป็นระยะ
task.spawn(function()
	while true do
		task.wait(2)
		for _, pl in Players:GetPlayers() do
			publish(pl)
		end
	end
end)
