--!strict
-- สร้างตัวละคร NPC/บอส/คนเดินถนน (R15) ให้เป็นคนญี่ปุ่นที่หลากหลาย: โทนผิว แยกสีหัว/เสื้อ/กางเกง/รองเท้า หน้า ผม เครื่องแต่งกายตามบทบาท
-- Create(name, position, parent, attributes?, color?, look?) — color = สีประจำแก๊ง (ใช้เป็นผ้าพันแขน/ผ้าพันคอ), look = ชื่อบทบาท (ไม่ใส่ = เดาจากชื่อ/attribute)
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")

local RigFactory = {}

local rng = Random.new()

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

---------------------------------------------------------------- ข้อมูลสี
local SKINS = { "F3D2B5", "EBC4A0", "E2B591", "D9A987", "F6DCC4", "E8BE98" }
local HAIR_BLACK = { "16120F", "1E1814", "2A211C", "33261C" }
local HAIR_BROWN = { "4A3526", "5A4030" }
local HAIR_BLEACH = { "E4D79A", "D8C27A", "EFE6B8" }
local HAIR_GREY = { "B9B9BC", "D4D4D6", "9E9EA3" }

local TOPS = { "6B7A8F", "A65E4E", "D9D2C3", "4F6B58", "8C7B9B", "2F3A4F", "B89B72", "C9C4BA", "7A9CB5", "C48B8B", "8A8F5E" }
local PANTS = { "2B2D33", "3A4252", "5B5246", "1F2430", "4A4F5C", "6B6355" }
local SHOES = { "1A1A1C", "2B2420", "3A3A3F", "E8E8E8" }

---------------------------------------------------------------- ผมจริงจาก catalog (ตรวจ ID แล้วด้วย GetProductInfo type=41 HairAccessory)
-- 63690008 Pal Hair (ผมสั้น), 451220849 Lavender Updo (มวยผม) — โหลดครั้งเดียวตอนเริ่ม ถ้าโหลดไม่ได้ใช้ผมที่ประกอบจากชิ้นส่วนแทน
local catalogHair: { [string]: Accessory } = {}
for style, id in { short = 63690008, updo = 451220849 } do
	local ok, model = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if ok and model then
		local acc = model:FindFirstChildOfClass("Accessory")
		if acc then
			for _, d in acc:GetDescendants() do
				if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
					d:Destroy()
				end
			end
			acc.Parent = nil
			catalogHair[style] = acc
		end
		model:Destroy()
	else
		warn("[RigFactory] โหลดผม catalog ไม่ได้ ใช้ผมประกอบเอง: " .. tostring(style))
	end
end

---------------------------------------------------------------- ตัวช่วยสร้างชิ้นส่วนประกอบ
local function prop(rig: Model, onto: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = onto.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = onto
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = rig
	return p
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

type Ctx = {
	Rig: Model,
	Head: BasePart,
	Torso: BasePart,
	Lower: BasePart,
	Hum: Humanoid,
	Skin: Color3,
	Parts: { [string]: BasePart },
}

---------------------------------------------------------------- ทรงผม
local function hairColor(kind: string): Color3
	if kind == "bleach" then
		return hex(pick(HAIR_BLEACH))
	elseif kind == "grey" then
		return hex(pick(HAIR_GREY))
	elseif kind == "brown" then
		return hex(pick(HAIR_BROWN))
	end
	return hex(pick(HAIR_BLACK))
end

local function catalogOn(ctx: Ctx, style: string, color: Color3): boolean
	local template = catalogHair[style]
	if not template then
		return false
	end
	local acc = template:Clone()
	local handle = acc:FindFirstChild("Handle") :: BasePart?
	if handle then
		handle.Color = color
	end
	ctx.Hum:AddAccessory(acc)
	return true
end

local function applyHair(ctx: Ctx, style: string, kind: string)
	local rig, head = ctx.Rig, ctx.Head
	local hs = head.Size
	local c = hairColor(kind)
	local mat = Enum.Material.SmoothPlastic
	local function cap(h: number, y: number)
		prop(rig, head, Vector3.new(hs.X * 1.06, hs.Y * h, hs.Z * 1.06), at(0, hs.Y * y, hs.Z * 0.02), c, mat)
	end
	local function back(h: number, y: number, d: number)
		prop(rig, head, Vector3.new(hs.X * 1.06, hs.Y * h, hs.Z * d), at(0, hs.Y * y, hs.Z * (0.5 - d / 2 + 0.03)), c, mat)
	end
	if style == "bald" then
		return
	elseif style == "short" then
		if rng:NextNumber() < 0.55 and catalogOn(ctx, "short", c) then
			return
		end
		cap(0.32, 0.42)
		back(0.55, 0.15, 0.3)
		prop(rig, head, Vector3.new(hs.X * 1.02, hs.Y * 0.14, hs.Z * 0.18), at(0, hs.Y * 0.32, -hs.Z * 0.46), c, mat)
	elseif style == "side" then
		cap(0.32, 0.42)
		back(0.5, 0.18, 0.3)
		-- ปอยด้านข้างหน้าผาก (แสกข้าง)
		prop(rig, head, Vector3.new(hs.X * 0.62, hs.Y * 0.2, hs.Z * 0.2), at(hs.X * 0.18, hs.Y * 0.3, -hs.Z * 0.5), c, mat)
	elseif style == "pompadour" then
		cap(0.3, 0.42)
		back(0.5, 0.15, 0.28)
		prop(rig, head, Vector3.new(hs.X * 1.0, hs.Y * 0.34, hs.Z * 0.62), at(0, hs.Y * 0.68, -hs.Z * 0.28), c, mat)
	elseif style == "spiky" then
		cap(0.3, 0.42)
		back(0.5, 0.15, 0.28)
		for i = -1, 1 do
			prop(rig, head, Vector3.new(hs.X * 0.28, hs.Y * 0.38, hs.Z * 0.3), at(i * hs.X * 0.3, hs.Y * 0.68, 0), c, mat)
		end
	elseif style == "bun" then
		if rng:NextNumber() < 0.5 and catalogOn(ctx, "updo", c) then
			return
		end
		cap(0.34, 0.42)
		back(0.7, 0.1, 0.3)
		prop(rig, head, Vector3.new(hs.X * 0.5, hs.Y * 0.5, hs.Z * 0.5), at(0, hs.Y * 0.72, hs.Z * 0.2), c, mat, Enum.PartType.Ball)
	elseif style == "ponytail" then
		cap(0.34, 0.42)
		back(0.55, 0.12, 0.3)
		prop(rig, head, Vector3.new(hs.X * 0.3, hs.Y * 1.0, hs.Z * 0.3), at(0, -hs.Y * 0.1, hs.Z * 0.7), c, mat)
	elseif style == "long" then
		cap(0.34, 0.42)
		prop(rig, head, Vector3.new(hs.X * 1.1, hs.Y * 1.5, hs.Z * 0.3), at(0, -hs.Y * 0.2, hs.Z * 0.5), c, mat)
	elseif style == "oldman" then
		-- หัวล้านมีผมขาวด้านข้าง/หลัง
		for _, sx in { -1, 1 } do
			prop(rig, head, Vector3.new(hs.X * 0.14, hs.Y * 0.4, hs.Z * 0.6), at(sx * hs.X * 0.5, hs.Y * 0.0, hs.Z * 0.1), c, mat)
		end
		back(0.35, 0.05, 0.22)
	end
end

local function applyFace(head: BasePart)
	if head:FindFirstChildOfClass("Decal") then
		return
	end
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
end

---------------------------------------------------------------- เครื่องแต่งกาย (ทาสีชิ้นส่วนร่างกาย)
local function paint(rig: Model, skin: Color3, top: Color3, pants: Color3, shoes: Color3, shortSleeve: boolean?)
	for _, side in { "Left", "Right" } do
		(rig :: any)[side .. "UpperArm"].Color = if shortSleeve then skin else top
		;(rig :: any)[side .. "LowerArm"].Color = if shortSleeve then skin else top
		;(rig :: any)[side .. "Hand"].Color = skin
		;(rig :: any)[side .. "UpperLeg"].Color = pants
		;(rig :: any)[side .. "LowerLeg"].Color = pants
		;(rig :: any)[side .. "Foot"].Color = shoes
	end
	local head = rig:FindFirstChild("Head") :: BasePart
	head.Color = skin
	;(rig :: any).UpperTorso.Color = top
	;(rig :: any).LowerTorso.Color = pants
end

-- กระโปรง: ครอบเอว→ต้นขา (ขาเป็นสีผิว ถุงเท้ายาวสีเข้ม)
local function skirt(ctx: Ctx, color: Color3, length: number)
	local ls = ctx.Lower.Size
	prop(ctx.Rig, ctx.Lower, Vector3.new(ls.X * 1.12, length, ls.Z * 1.25), at(0, -ls.Y / 2 - length / 2 + 0.15, 0), color, Enum.Material.Fabric)
	ctx.Lower.Color = color
	for _, side in { "Left", "Right" } do
		(ctx.Rig :: any)[side .. "UpperLeg"].Color = ctx.Skin
	end
end

local function kneeSocks(rig: Model, color: Color3)
	for _, side in { "Left", "Right" } do
		(rig :: any)[side .. "LowerLeg"].Color = color
	end
end

local function collar(ctx: Ctx, color: Color3, height: number?)
	local ts = ctx.Torso.Size
	prop(ctx.Rig, ctx.Torso, Vector3.new(ts.X * 0.46, height or 0.28, ts.Z * 0.92), at(0, ts.Y / 2 - 0.02, 0), color, Enum.Material.Fabric)
end

local function buttons(ctx: Ctx, n: number)
	local ts = ctx.Torso.Size
	for i = 1, n do
		local y = ts.Y / 2 - 0.3 - (i - 1) * (ts.Y - 0.6) / math.max(1, n - 1) * 0.9
		prop(ctx.Rig, ctx.Torso, Vector3.new(0.14, 0.14, 0.14), at(0, y, -ts.Z / 2 - 0.02), hex("D4AF37"), Enum.Material.Metal, Enum.PartType.Ball)
	end
end

local function tie(ctx: Ctx, color: Color3)
	local ts = ctx.Torso.Size
	-- เสื้อเชิ้ตขาวด้านหน้า + เนคไท
	prop(ctx.Rig, ctx.Torso, Vector3.new(ts.X * 0.28, ts.Y * 0.8, 0.05), at(0, ts.Y * 0.05, -ts.Z / 2 - 0.02), hex("F2F2F0"), Enum.Material.Fabric)
	prop(ctx.Rig, ctx.Torso, Vector3.new(0.2, ts.Y * 0.7, 0.07), at(0, ts.Y * 0.0, -ts.Z / 2 - 0.05), color, Enum.Material.Fabric)
end

local function apron(ctx: Ctx, color: Color3, length: number)
	local ts = ctx.Torso.Size
	prop(ctx.Rig, ctx.Torso, Vector3.new(ts.X * 0.92, length, 0.1), at(0, ts.Y / 2 - length / 2, -ts.Z / 2 - 0.05), color, Enum.Material.Fabric)
end

local function headband(ctx: Ctx, color: Color3)
	local hs = ctx.Head.Size
	prop(ctx.Rig, ctx.Head, Vector3.new(hs.X * 1.1, hs.Y * 0.2, hs.Z * 1.1), at(0, hs.Y * 0.22, 0), color, Enum.Material.Fabric)
end

local function cap(ctx: Ctx, color: Color3)
	local hs = ctx.Head.Size
	prop(ctx.Rig, ctx.Head, Vector3.new(hs.X * 1.08, hs.Y * 0.3, hs.Z * 1.08), at(0, hs.Y * 0.45, 0), color, Enum.Material.Fabric)
	prop(ctx.Rig, ctx.Head, Vector3.new(hs.X * 0.9, 0.08, hs.Z * 0.5), at(0, hs.Y * 0.36, -hs.Z * 0.7), color, Enum.Material.Fabric)
end

local function sunglasses(ctx: Ctx)
	local hs = ctx.Head.Size
	prop(ctx.Rig, ctx.Head, Vector3.new(hs.X * 1.04, hs.Y * 0.17, 0.1), at(0, hs.Y * 0.06, -hs.Z / 2 - 0.02), hex("0C0C0E"), Enum.Material.Glass)
end

local function scar(ctx: Ctx)
	local hs = ctx.Head.Size
	prop(ctx.Rig, ctx.Head, Vector3.new(0.07, hs.Y * 0.5, 0.06), at(hs.X * 0.22, -hs.Y * 0.05, -hs.Z / 2 - 0.01), hex("A8574E"))
end

local function tattoo(ctx: Ctx, partName: string)
	local p = ctx.Parts[partName]
	if not p then
		return
	end
	prop(ctx.Rig, p, Vector3.new(p.Size.X * 1.05, p.Size.Y * 0.55, p.Size.Z * 1.05), at(0, 0.05, 0), hex("1F2E4A"), Enum.Material.Fabric)
end

local function armband(ctx: Ctx, color: Color3, side: string)
	local arm = ctx.Parts[side .. "UpperArm"]
	if arm then
		prop(ctx.Rig, arm, Vector3.new(arm.Size.X * 1.12, 0.32, arm.Size.Z * 1.12), at(0, 0.1, 0), color, Enum.Material.Fabric)
	end
end

local function scarf(ctx: Ctx, color: Color3)
	local ts = ctx.Torso.Size
	prop(ctx.Rig, ctx.Torso, Vector3.new(ts.X * 0.62, 0.26, ts.Z * 1.12), at(0, ts.Y / 2 - 0.1, 0), color, Enum.Material.Fabric)
end

local function longCoat(ctx: Ctx, color: Color3)
	local ls = ctx.Lower.Size
	-- ชายเสื้อคลุมยาว (หลัง + ข้างซ้ายขวา) แขวนจากเอว
	prop(ctx.Rig, ctx.Lower, Vector3.new(ls.X * 1.1, 2.0, 0.14), at(0, -1.0, ls.Z / 2 + 0.08), color, Enum.Material.Fabric)
	for _, sx in { -1, 1 } do
		prop(ctx.Rig, ctx.Lower, Vector3.new(0.16, 1.8, ls.Z * 1.0), at(sx * (ls.X / 2 + 0.06), -0.9, 0), color, Enum.Material.Fabric)
	end
end

local function backpackBox(ctx: Ctx, color: Color3)
	local ts = ctx.Torso.Size
	prop(ctx.Rig, ctx.Torso, Vector3.new(ts.X * 0.8, 1.3, 0.8), at(0, 0.0, ts.Z / 2 + 0.4), color, Enum.Material.Fabric)
end

local function carry(ctx: Ctx, kind: string)
	local lh, rh = ctx.Parts.LeftHand, ctx.Parts.RightHand
	if kind == "briefcase" then
		prop(ctx.Rig, rh, Vector3.new(0.22, 0.75, 1.0), at(0, -0.7, 0), hex("3B2A22"), Enum.Material.Leather)
	elseif kind == "umbrella" then
		prop(ctx.Rig, rh, Vector3.new(0.12, 3.1, 0.12), at(0, -0.3, 0), hex(pick({ "20344F", "7A1F2B", "2F2F33", "1F5C4B" })), Enum.Material.Fabric)
	elseif kind == "bag" then
		prop(ctx.Rig, lh, Vector3.new(0.35, 0.85, 0.65), at(0, -0.75, 0), hex(pick({ "E8E0CE", "F2B8C6", "B8905A", "A9D2E6" })), Enum.Material.Fabric)
	elseif kind == "phone" then
		prop(ctx.Rig, rh, Vector3.new(0.3, 0.1, 0.5), at(0, -0.1, -0.3), hex("101014"), Enum.Material.Glass)
	elseif kind == "cane" then
		prop(ctx.Rig, rh, Vector3.new(0.12, 3.0, 0.12), at(0, -1.0, -0.2), hex("6B4A2B"), Enum.Material.Wood)
	end
end

---------------------------------------------------------------- บทบาท → สไตล์
type Look = { Scale: { Height: number, Width: number, Head: number }, Build: (Ctx, Color3) -> () }

local function maleCasual(ctx: Ctx, _accent: Color3)
	paint(ctx.Rig, ctx.Skin, hex(pick(TOPS)), hex(pick(PANTS)), hex(pick(SHOES)), rng:NextNumber() < 0.4)
	applyHair(ctx, pick({ "short", "short", "side", "spiky" }), pick({ "black", "black", "black", "brown" }))
end

local function femaleCasual(ctx: Ctx, _accent: Color3)
	local pants = hex(pick(PANTS))
	paint(ctx.Rig, ctx.Skin, hex(pick(TOPS)), pants, hex(pick(SHOES)), rng:NextNumber() < 0.5)
	if rng:NextNumber() < 0.5 then
		skirt(ctx, hex(pick({ "3A4252", "7A5B66", "C9BBA4", "4F5E4A" })), 1.0)
	end
	applyHair(ctx, pick({ "long", "bun", "ponytail", "long" }), pick({ "black", "black", "brown" }))
end

local function salaryman(ctx: Ctx, _accent: Color3)
	local suit = hex(pick({ "20232B", "2B3140", "34363B" }))
	paint(ctx.Rig, ctx.Skin, suit, suit, hex("141416"))
	tie(ctx, hex(pick({ "7A1F2B", "20446B", "3E3E42" })))
	applyHair(ctx, pick({ "side", "short" }), "black")
	carry(ctx, "briefcase")
end

local function officeLady(ctx: Ctx, _accent: Color3)
	local jacket = hex(pick({ "2F3A4F", "4A4F5C", "6B6560" }))
	paint(ctx.Rig, ctx.Skin, jacket, hex("2F3A4F"), hex("1A1A1C"))
	skirt(ctx, hex(pick({ "2F3A4F", "3A3A40" })), 1.1)
	kneeSocks(ctx.Rig, hex("4A3F3B"))
	prop(ctx.Rig, ctx.Torso, Vector3.new(ctx.Torso.Size.X * 0.3, ctx.Torso.Size.Y * 0.75, 0.05), at(0, ctx.Torso.Size.Y * 0.05, -ctx.Torso.Size.Z / 2 - 0.02), hex("F4F1EA"), Enum.Material.Fabric)
	applyHair(ctx, pick({ "bun", "ponytail", "long" }), pick({ "black", "brown" }))
end

local function schoolgirl(ctx: Ctx, _accent: Color3)
	local navy = hex("1F2A4A")
	paint(ctx.Rig, ctx.Skin, hex("F4F4F6"), navy, hex(pick({ "2B2420", "3A2B22" })), true)
	skirt(ctx, hex(pick({ "1F2A4A", "3A3F55", "4A3A4F" })), 1.0)
	kneeSocks(ctx.Rig, navy)
	local ts = ctx.Torso.Size
	prop(ctx.Rig, ctx.Torso, Vector3.new(ts.X * 0.55, 0.3, ts.Z * 1.06), at(0, ts.Y / 2 - 0.12, 0), navy, Enum.Material.Fabric) -- ปกกะลาสี
	prop(ctx.Rig, ctx.Torso, Vector3.new(0.45, 0.22, 0.08), at(0, ts.Y / 2 - 0.4, -ts.Z / 2 - 0.04), hex("C8323C"), Enum.Material.Fabric) -- ริบบิ้น
	applyHair(ctx, pick({ "long", "ponytail", "bun", "short" }), pick({ "black", "black", "brown" }))
end

local function schoolboy(ctx: Ctx, _accent: Color3)
	local blazer = hex(pick({ "1F2A4A", "2B2F3A" }))
	paint(ctx.Rig, ctx.Skin, blazer, hex(pick({ "2B2F3A", "3A3F4A" })), hex("1A1A1C"))
	tie(ctx, hex("8A2A34"))
	collar(ctx, hex("F2F2F0"), 0.18)
	applyHair(ctx, pick({ "short", "side", "spiky" }), pick({ "black", "black", "brown" }))
end

local function elderly(ctx: Ctx, _accent: Color3)
	local male = rng:NextNumber() < 0.5
	paint(ctx.Rig, ctx.Skin, hex(pick({ "7C6B5A", "5F6B5A", "8A7F73", "6B5F7A" })), hex(pick({ "4A4238", "3A3F4A" })), hex(pick({ "2B2420", "4A3F38" })))
	if male then
		applyHair(ctx, "oldman", "grey")
	else
		applyHair(ctx, "bun", "grey")
	end
	if rng:NextNumber() < 0.5 then
		carry(ctx, "cane")
	end
end

local function delivery(ctx: Ctx, _accent: Color3)
	local uni = hex(pick({ "E8751A", "1F8A70", "2E6FBF" }))
	paint(ctx.Rig, ctx.Skin, uni, hex("2B2D33"), hex("1A1A1C"), true)
	cap(ctx, uni)
	backpackBox(ctx, uni)
	applyHair(ctx, "short", "black")
end

local function ramen(ctx: Ctx, _accent: Color3)
	paint(ctx.Rig, ctx.Skin, hex("2E3F66"), hex("1F2430"), hex("2B2420"), true)
	apron(ctx, hex("F4F1EA"), 2.1)
	applyHair(ctx, "oldman", "grey")
	headband(ctx, hex("F4F1EA"))
end

local function shopkeeper(ctx: Ctx, _accent: Color3)
	paint(ctx.Rig, ctx.Skin, hex(pick(TOPS)), hex("3A3F4A"), hex("2B2420"))
	apron(ctx, hex(pick({ "3E6B4F", "8A5A3A", "F4F1EA" })), 1.8)
	applyHair(ctx, pick({ "short", "side", "oldman" }), pick({ "black", "grey" }))
end

local function explorer(ctx: Ctx, _accent: Color3)
	paint(ctx.Rig, ctx.Skin, hex("6B7A4A"), hex("5B5246"), hex("3A2B22"))
	local ts = ctx.Torso.Size
	prop(ctx.Rig, ctx.Torso, Vector3.new(ts.X * 1.04, ts.Y * 0.9, ts.Z * 1.08), at(0, 0, 0), hex("8A7A52"), Enum.Material.Fabric) -- เสื้อกั๊ก
	cap(ctx, hex("8A7A52"))
	applyHair(ctx, "oldman", "grey")
end

local function miko(ctx: Ctx, _accent: Color3)
	paint(ctx.Rig, ctx.Skin, hex("F4F4F6"), hex("B8232F"), hex("E8E0CE"))
	skirt(ctx, hex("B8232F"), 1.9)
	applyHair(ctx, "ponytail", "black")
end

local function stationStaff(ctx: Ctx, _accent: Color3)
	local navy = hex("1F2E4F")
	paint(ctx.Rig, ctx.Skin, navy, navy, hex("141416"))
	tie(ctx, hex("C8A23C"))
	cap(ctx, navy)
	buttons(ctx, 3)
	applyHair(ctx, "short", "black")
end

local function captain(ctx: Ctx, _accent: Color3)
	local navy = hex("1B2B4A")
	paint(ctx.Rig, ctx.Skin, navy, hex("F2F2F0"), hex("1A1A1C"))
	cap(ctx, hex("F2F2F0"))
	buttons(ctx, 3)
	applyHair(ctx, "oldman", "grey")
end

local function questGirl(ctx: Ctx, _accent: Color3)
	paint(ctx.Rig, ctx.Skin, hex("F2C8D0"), hex("4A5670"), hex("F4F4F6"))
	applyHair(ctx, "ponytail", "brown")
end

-- นักเลง: ชุดกากุรัง (ดำ คอตั้ง กระดุมทอง) + ผ้าพันแขน/ผ้าพันคอสีแก๊ง
local function gang(ctx: Ctx, accent: Color3, kind: string?)
	local black = hex("17171B")
	paint(ctx.Rig, ctx.Skin, black, black, hex("0E0E10"))
	collar(ctx, black, 0.3)
	buttons(ctx, if kind == "leader" then 2 else 3)
	armband(ctx, accent, if rng:NextNumber() < 0.5 then "Left" else "Right")
	scarf(ctx, accent)
	if kind == "leader" then
		longCoat(ctx, hex("101013"))
		applyHair(ctx, "pompadour", pick({ "black", "bleach" }))
	else
		local r = rng:NextNumber()
		if r < 0.2 then
			applyHair(ctx, "pompadour", "black")
		elseif r < 0.45 then
			applyHair(ctx, "spiky", "bleach")
		else
			applyHair(ctx, pick({ "short", "side" }), "black")
		end
	end
end

local RIDER_TOPS = { "2A9D8F", "E76F51", "264653", "E9C46A", "8AB17D", "F4F1DE", "6D597A", "B56576", "3A86A8", "C8323C" }
local HELMET_COLORS = { "F2F2F2", "1C1D21", "B3262D", "2F6DB5", "E9C46A" }

-- ผู้ขับมอเตอร์ไซค์: เสื้อยืดหลายสี ผมปกติ (หมวกกันน็อก ~40%)
local function rider(ctx: Ctx, _accent: Color3)
	paint(ctx.Rig, ctx.Skin, hex(pick(RIDER_TOPS)), hex(pick({ "2B3A55", "1F2430", "3A4252", "55504A" })), hex(pick(SHOES)), true)
	if rng:NextNumber() < 0.4 then
		local hs = ctx.Head.Size
		applyHair(ctx, "bald", "black")
		prop(ctx.Rig, ctx.Head, Vector3.new(hs.X * 1.3, hs.Y * 1.2, hs.Z * 1.3), at(0, hs.Y * 0.1, hs.Z * 0.02), hex(pick(HELMET_COLORS)), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		prop(ctx.Rig, ctx.Head, Vector3.new(hs.X * 1.0, hs.Y * 0.3, 0.12), at(0, hs.Y * 0.04, -hs.Z * 0.62), hex("101216"), Enum.Material.Glass) -- กระจกบังลม
		ctx.Rig:SetAttribute("Helmet", true)
	else
		applyHair(ctx, pick({ "spiky", "spiky", "short", "side", "pompadour" }), pick({ "brown", "black", "black", "bleach" }))
	end
end

local function worker(ctx: Ctx, accent: Color3)
	paint(ctx.Rig, ctx.Skin, hex("3F4650"), hex("2E343C"), hex("2B2420"), true)
	prop(ctx.Rig, ctx.Torso, Vector3.new(ctx.Torso.Size.X * 1.04, ctx.Torso.Size.Y * 0.9, ctx.Torso.Size.Z * 1.08), at(0, 0, 0), accent, Enum.Material.Fabric) -- เสื้อกั๊กสีแก๊ง
	local hs = ctx.Head.Size
	prop(ctx.Rig, ctx.Head, Vector3.new(hs.X * 1.1, hs.Y * 0.35, hs.Z * 1.1), at(0, hs.Y * 0.45, 0), hex("E8C21A"), Enum.Material.SmoothPlastic) -- หมวกนิรภัย
	applyHair(ctx, "bald", "black")
end

local function boss(ctx: Ctx, accent: Color3)
	gang(ctx, accent, "leader")
	sunglasses(ctx)
	scar(ctx)
	tattoo(ctx, if rng:NextNumber() < 0.5 then "LeftUpperArm" else "RightLowerArm")
end

local LOOKS: { [string]: Look } = {
	maleCasual = { Scale = { Height = 1.0, Width = 1.0, Head = 1.0 }, Build = maleCasual },
	femaleCasual = { Scale = { Height = 0.94, Width = 0.92, Head = 1.0 }, Build = femaleCasual },
	salaryman = { Scale = { Height = 1.0, Width = 1.0, Head = 1.0 }, Build = salaryman },
	officeLady = { Scale = { Height = 0.95, Width = 0.9, Head = 1.0 }, Build = officeLady },
	schoolgirl = { Scale = { Height = 0.92, Width = 0.9, Head = 1.0 }, Build = schoolgirl },
	schoolboy = { Scale = { Height = 0.98, Width = 0.96, Head = 1.0 }, Build = schoolboy },
	elderly = { Scale = { Height = 0.92, Width = 0.95, Head = 1.0 }, Build = elderly },
	delivery = { Scale = { Height = 1.0, Width = 0.98, Head = 1.0 }, Build = delivery },
	ramen = { Scale = { Height = 0.94, Width = 1.08, Head = 1.02 }, Build = ramen },
	shopkeeper = { Scale = { Height = 0.98, Width = 1.0, Head = 1.0 }, Build = shopkeeper },
	explorer = { Scale = { Height = 1.0, Width = 1.0, Head = 1.0 }, Build = explorer },
	miko = { Scale = { Height = 0.95, Width = 0.9, Head = 1.0 }, Build = miko },
	stationStaff = { Scale = { Height = 1.0, Width = 1.0, Head = 1.0 }, Build = stationStaff },
	captain = { Scale = { Height = 1.04, Width = 1.08, Head = 1.0 }, Build = captain },
	questGirl = { Scale = { Height = 0.95, Width = 0.9, Head = 1.0 }, Build = questGirl },
	gang = { Scale = { Height = 1.0, Width = 1.0, Head = 1.0 }, Build = function(c, a) gang(c, a, nil) end },
	brute = { Scale = { Height = 1.06, Width = 1.18, Head = 1.0 }, Build = function(c, a) gang(c, a, nil) end },
	leader = { Scale = { Height = 1.08, Width = 1.12, Head = 1.0 }, Build = function(c, a) gang(c, a, "leader") end },
	worker = { Scale = { Height = 1.02, Width = 1.1, Head = 1.0 }, Build = worker },
	boss = { Scale = { Height = 1.15, Width = 1.22, Head = 1.0 }, Build = boss },
	rider = { Scale = { Height = 0.86, Width = 0.92, Head = 1.0 }, Build = rider },
}

local PEDESTRIAN_MIX = { "maleCasual", "maleCasual", "femaleCasual", "femaleCasual", "salaryman", "salaryman", "officeLady", "schoolgirl", "schoolgirl", "schoolboy", "elderly", "delivery", "shopkeeper" }
local PEDESTRIAN_PROPS = { "umbrella", "bag", "bag", "phone" }

local NAME_LOOKS: { [string]: string } = {
	["คุณลุงร้านราเมน"] = "ramen",
	["มิกะ"] = "questGirl",
	["ลุงนักสำรวจ"] = "explorer",
	["เจ้าหน้าที่สถานี"] = "stationStaff",
	["แม่ชีศาลเจ้า"] = "miko",
	["นักเรียนผู้ทรยศ"] = "schoolboy",
	["กัปตันเรือ"] = "captain",
}

local function inferLook(name: string, attributes: { [string]: any }?): string
	local forced = NAME_LOOKS[name]
	if forced then
		return forced
	end
	local a = attributes or {}
	if name == "คนเดินถนน" then
		return pick(PEDESTRIAN_MIX)
	end
	if a.IsBoss or a.WorldBoss then
		return "boss"
	end
	if a.CampLeader then
		return "leader"
	end
	if name:find("คนงาน") then
		return "worker"
	end
	if a.NpcType == "Brute" then
		return "brute"
	end
	if a.NpcType then
		return "gang"
	end
	return pick(PEDESTRIAN_MIX)
end

---------------------------------------------------------------- แอนิเมชันเดิน/ยืนเฉยแบบ Animate ของ Roblox (ไม่ชนกับท่าต่อสู้ Action4 ของ ProceduralAnim)
local IDLE_ID = "rbxassetid://507766666"
local WALK_ID = "rbxassetid://507777826"
local WAVE_ID = "rbxassetid://507770239"

local function loadTrack(animator: Animator, id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok or not track then
		return nil
	end
	track.Priority = priority
	track.Looped = looped
	return track
end

local function setupLocomotion(rig: Model, hum: Humanoid)
	task.spawn(function()
		local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 3)
		if not animator or not rig:IsDescendantOf(workspace) then
			return
		end
		local idle = loadTrack(animator :: Animator, IDLE_ID, Enum.AnimationPriority.Idle, true)
		local walk = loadTrack(animator :: Animator, WALK_ID, Enum.AnimationPriority.Movement, true)
		if idle then
			idle:Play(0)
			rig:SetAttribute("IdleAnim", true)
		end
		if not walk then
			return
		end
		hum.Running:Connect(function(speed: number)
			if speed > 0.6 then
				walk:AdjustSpeed(math.clamp(speed / 12, 0.5, 2.2))
				if not walk.IsPlaying then
					walk:Play(0.15)
				end
			elseif walk.IsPlaying then
				walk:Stop(0.2)
			end
		end)
	end)
end

-- โบกมือ (ใช้กับ NPC ให้ภารกิจ) — เล่นครั้งเดียวด้วย priority Action
local waveTracks: { [Model]: AnimationTrack } = {}
function RigFactory.Wave(rig: Model)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local track = waveTracks[rig]
	if not track then
		track = loadTrack(animator, WAVE_ID, Enum.AnimationPriority.Action, false)
		if not track then
			return
		end
		waveTracks[rig] = track
		rig.Destroying:Once(function()
			waveTracks[rig] = nil
		end)
	end
	if not track.IsPlaying then
		track:Play(0.2)
	end
end

---------------------------------------------------------------- สร้างตัวละคร
function RigFactory.Create(name: string, position: Vector3, parent: Instance, attributes: { [string]: any }?, color: Color3?, look: string?): Model?
	local lookName = look or inferLook(name, attributes)
	local spec = LOOKS[lookName] or LOOKS.maleCasual
	local skin = hex(pick(SKINS))
	local ok, rig = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local sc = spec.Scale
		-- สเกลเปลี่ยนเล็กน้อยรายคน (อยู่ในช่วงปลอดภัย: hitbox 7x6x7 ยังครอบคลุม)
		desc.HeightScale = sc.Height * rng:NextNumber(0.97, 1.03)
		desc.WidthScale = sc.Width * rng:NextNumber(0.95, 1.05)
		desc.DepthScale = sc.Width * rng:NextNumber(0.95, 1.05)
		desc.HeadScale = sc.Head * rng:NextNumber(0.97, 1.03)
		desc.ProportionScale = rng:NextNumber(0, 0.25)
		desc.BodyTypeScale = 0
		desc.HeadColor, desc.TorsoColor, desc.LeftArmColor = skin, skin, skin
		desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = skin, skin, skin
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[RigFactory] สร้างตัวละครไม่สำเร็จ: " .. tostring(rig))
		return nil
	end
	local model = rig :: Model
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local parts: { [string]: BasePart } = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			parts[p.Name] = p
		end
	end
	local ctx: Ctx = {
		Rig = model,
		Head = parts.Head,
		Torso = parts.UpperTorso,
		Lower = parts.LowerTorso,
		Hum = hum,
		Skin = skin,
		Parts = parts,
	}
	local okBuild, err = pcall(function()
		applyFace(parts.Head)
		spec.Build(ctx, color or Color3.fromHex("C8323C"))
		if lookName ~= "boss" and model.Name ~= "" and (name == "คนเดินถนน") and rng:NextNumber() < 0.3 then
			local hasCarry = lookName == "salaryman" or lookName == "elderly" or lookName == "delivery"
			if not hasCarry then
				carry(ctx, pick(PEDESTRIAN_PROPS))
			end
		end
	end)
	if not okBuild then
		warn("[RigFactory] แต่งตัวไม่สำเร็จ (" .. lookName .. "): " .. tostring(err))
	end
	model.Name = name
	model:SetAttribute("Look", lookName)
	for k, v in attributes or {} do
		model:SetAttribute(k, v)
	end
	model:PivotTo(CFrame.new(position))
	model.Parent = parent
	if not (attributes and attributes.NoLocomotion) then
		setupLocomotion(model, hum)
	end
	return model
end

---------------------------------------------------------------- ผู้ขับมอเตอร์ไซค์ (ท่านั่ง: ตัวเอนไปข้างหน้า มือจับแฮนด์ เข่างอบนที่พักเท้า)
-- มุมองศารอบแกน X ของ Motor6D.C0 (บวก = ไปข้างหน้า) หน้าตัวละครหัน -Z
local RIDER_POSES: { [string]: { [string]: number } } = {
	bike = { waist = -30, neck = 26, hip = 80, knee = -92, ankle = 8, shoulder = 80, elbow = 32, splay = 7 },
	scooter = { waist = -6, neck = 6, hip = 74, knee = -76, ankle = 0, shoulder = 50, elbow = 34, splay = 5 },
}

local function bend(rig: Model, joint: string, rx: number, rz: number?)
	local m = rig:FindFirstChild(joint, true)
	if m and m:IsA("Motor6D") then
		m.C0 = m.C0 * CFrame.Angles(math.rad(rx), 0, math.rad(rz or 0))
	end
end

-- สร้างคนขี่ที่นั่งอยู่ท่าขี่ ไม่มี Humanoid ไม่ชน ไม่มีน้ำหนัก (Weld เข้ากับรถที่ผู้เรียกทำ) pivot ที่ HumanoidRootPart
function RigFactory.CreateRider(parent: Instance, poseName: string): Model?
	local rig = RigFactory.Create("คนขับมอเตอร์ไซค์", Vector3.new(0, 1000, 0), parent, { NoLocomotion = true }, nil, "rider")
	if not rig then
		return nil
	end
	local pose = RIDER_POSES[poseName] or RIDER_POSES.scooter
	-- R15 จาก CreateHumanoidModelFromDescription ใช้ AnimationConstraint (ขยับด้วย Animator เท่านั้น) แปลงเป็น Motor6D เพื่อตั้งท่าด้วย C0
	for _, d in rig:GetDescendants() do
		if d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			local m = Instance.new("Motor6D")
			m.Name = d.Name
			m.Part0 = d.Attachment0.Parent :: BasePart
			m.Part1 = d.Attachment1.Parent :: BasePart
			m.C0 = d.Attachment0.CFrame
			m.C1 = d.Attachment1.CFrame
			m.Parent = d.Parent
			d:Destroy()
		end
	end
	bend(rig, "Waist", pose.waist)
	bend(rig, "Neck", pose.neck)
	bend(rig, "RightHip", pose.hip, pose.splay)
	bend(rig, "LeftHip", pose.hip, -pose.splay)
	bend(rig, "RightKnee", pose.knee)
	bend(rig, "LeftKnee", pose.knee)
	bend(rig, "RightAnkle", pose.ankle)
	bend(rig, "LeftAnkle", pose.ankle)
	bend(rig, "RightShoulder", pose.shoulder, -6)
	bend(rig, "LeftShoulder", pose.shoulder, 6)
	bend(rig, "RightElbow", pose.elbow)
	bend(rig, "LeftElbow", pose.elbow)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:Destroy()
	end
	-- วางชิ้นส่วนตามท่าเอง (forward kinematics) เพราะถ้ารถจอดถูก Anchored ฟิสิกส์จะไม่ขยับข้อต่อให้
	local joints: { JointInstance } = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("JointInstance") then
			table.insert(joints, d)
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local placed: { [Instance]: boolean } = { [root] = true }
	local queue: { BasePart } = { root }
	while #queue > 0 do
		local cur = table.remove(queue, 1) :: BasePart
		for _, j in joints do
			local p0, p1 = j.Part0, j.Part1
			if p0 and p1 then
				if p0 == cur and not placed[p1] then
					p1.CFrame = cur.CFrame * j.C0 * j.C1:Inverse()
					placed[p1] = true
					table.insert(queue, p1)
				elseif p1 == cur and not placed[p0] then
					p0.CFrame = cur.CFrame * j.C1 * j.C0:Inverse()
					placed[p0] = true
					table.insert(queue, p0)
				end
			end
		end
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	return rig
end

return RigFactory
