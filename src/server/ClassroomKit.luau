--!strict
-- ห้องเรียนญี่ปุ่นในอาคารเรียน (x -60..60, z -120..-60) เรียกจาก MapBuilder
-- แต่ละชั้นแบ่ง 2 ฝั่งทางเดิน (หลัง z -119..-98 / หน้า z -82..-61) เป็นห้องกว้าง ~20 stud ทุกห้องหันหน้าไปทางตะวันตก (กระดานอยู่ผนังตะวันตก)
-- พิกัดในห้อง: u = จากกระดาน (ผนังตะวันตก) ไปท้ายห้อง (+x), v = จากผนังทางเดินไปผนังหน้าต่าง, h = สูงจากพื้น
-- งบประมาณ: ชิ้นส่วนรวมไม่เกิน ~5,000, PointLight 1 ดวงต่อห้อง (ชิ้นนีออนใต้ฝ้า), โต๊ะ+เก้าอี้ 5 ชิ้นต่อชุด
local ClassroomKit = {}

local hex = Color3.fromHex
local Mat = Enum.Material

local K = {
	wall = hex("D6CDBA"),
	board = hex("2E4A3F"),
	boardFrame = hex("A98557"),
	tray = hex("C9AE82"),
	deskTop = hex("D8C095"),
	steel = hex("7A8087"),
	darkSteel = hex("4B5058"),
	navy = hex("2A2D33"),
	alu = hex("C4C8CB"),
	cream = hex("EFE6CF"),
	cork = hex("B98A5A"),
	red = hex("B03A32"),
	white = hex("ECE9E0"),
	tile = hex("E8E4D8"),
	woodDark = hex("6E5037"),
	cabinet = hex("A28259"),
	chalk = hex("EEEEE6"),
	yellow = hex("F2E394"),
	pink = hex("F2B1C0"),
	blue = hex("ABD8F0"),
	green = hex("2F7D55"),
}
local CHAIR = { hex("4F8E8A"), hex("5C7FA6"), hex("C98A4B"), hex("7FA070") }

local D = 21 -- ความลึกห้องจากผนังทางเดินถึงผนังหน้าต่าง
local BANDS = {
	front = { zc = -82, sgn = 1 }, -- ผนังทางเดินฝั่งหน้าอยู่ z -83..-82, หน้าต่างที่ z -61
	back = { zc = -98, sgn = -1 }, -- ผนังทางเดินฝั่งหลังอยู่ z -98..-97, หน้าต่างที่ z -119
}
local GRADE = { "一", "二", "三" }
local LETTERS = "ABCDEFGHIJKL"

local stats = { parts = 0, lights = 0, guis = 0 }

----------------------------------------------------------------- ตัวช่วย
-- flags: "n" = ไม่ชน/ไม่ query, "S" = เปิดเงา (ค่าเริ่มต้นของชิ้นเล็ก = ไม่มีเงา)
local function newPart(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material?, flags: string?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = mat or Mat.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	local fl = flags or ""
	p.CastShadow = string.find(fl, "S", 1, true) ~= nil
	if string.find(fl, "n", 1, true) then
		p.CanCollide = false
		p.CanQuery = false
	end
	p.Parent = parent
	stats.parts += 1
	return p
end

local function mkGui(p: BasePart, face: Enum.NormalId, ppu: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppu
	g.LightInfluence = 0.6
	pcall(function()
		(g :: any).MaxDistance = 70
	end)
	g.Parent = p
	stats.guis += 1
	return g
end

local function frame(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, transp: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transp or 0
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Parent = parent
	return f
end

local function label(parent: Instance, text: string, x: number, y: number, w: number, h: number, color: Color3, font: Enum.Font?, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.Text = text
	l.TextColor3 = color
	l.Font = font or Enum.Font.GothamBold
	l.TextScaled = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

-- ป้ายตัวอักษรเต็มหน้า
local function plainSign(p: BasePart, face: Enum.NormalId, text: string, color: Color3, ppu: number?, font: Enum.Font?)
	local g = mkGui(p, face, ppu or 40)
	label(g, text, 0.04, 0.06, 0.92, 0.88, color, font)
end

local function clockGui(p: BasePart, face: Enum.NormalId, hh: number, mm: number)
	local g = mkGui(p, face, 40)
	for _, a in { 0, 90, 180, 270 } do
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromScale(1, 1)
		holder.Rotation = a
		holder.Parent = g
		local tick = frame(holder, 0.485, 0.04, 0.03, 0.1, K.navy)
		tick.Parent = holder
	end
	local function hand(angle: number, len: number, thick: number)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromScale(1, 1)
		holder.Rotation = angle
		holder.Parent = g
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = K.navy
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(thick, len)
		bar.Parent = holder
	end
	hand((hh % 12) * 30 + mm * 0.5, 0.27, 0.05)
	hand(mm * 6, 0.40, 0.032)
end

----------------------------------------------------------------- ผังห้อง
type Cell = { x0: number, x1: number, kind: string, west: boolean }

local function cellsOf(level: number, band: string): { Cell }
	local b = if level == 0 and band == "front" then { -59, -36.5, -14, 14, 36.5, 59 } else { -59, -40, -20, 0, 20, 40, 59 }
	local n = #b - 1
	local out: { Cell } = {}
	for i = 1, n do
		local kind = "class"
		if level == 0 and band == "front" and i == 3 then
			kind = "lobby" -- โถงทางเข้า (genkan) ตรงประตูหน้า x -7..7
		elseif level == 1 and band == "back" and i == 1 then
			kind = "hall" -- โถงบันไดหนีไฟ (ประตูตะวันตก z -108..-98)
		end
		table.insert(out, {
			x0 = if i == 1 then b[1] else b[i] + 0.5,
			x1 = if i == n then b[n + 1] else b[i + 1] - 0.5,
			kind = kind,
			west = i > 1,
		})
	end
	return out
end

-- จุดกลางหน้าต่างบนผนังหน้า/หลัง (2 บานต่อห้อง) ผนังหน้าชั้น 2-3 เว้นหอนาฬิกา |x|<11
function ClassroomKit.WindowXs(level: number, band: string): { number }
	local out = {}
	for _, c in cellsOf(level, band) do
		if c.kind ~= "lobby" then
			local w = c.x1 - c.x0
			for _, f in { 0.25, 0.75 } do
				local cx = c.x0 + w * f
				if not (band == "front" and level >= 1 and math.abs(cx) < 11) then
					table.insert(out, cx)
				end
			end
		end
	end
	return out
end

-- ตำแหน่ง x ของผนังกั้นห้องฝั่งหลัง (ใช้เลี่ยงล็อกเกอร์เดิม)
function ClassroomKit.PartitionHitsX(x1: number, x2: number): boolean
	for _, b in { -40, -20, 0, 20, 40 } do
		if x1 < b + 0.5 and x2 > b - 0.5 then
			return true
		end
	end
	return false
end

----------------------------------------------------------------- เปลือกอาคาร (ผนังนอกเจาะหน้าต่างจริง)
local function wallPieces(parent: Instance, name: string, axis: string, f0: number, f1: number, a0: number, a1: number, ya: number, yb: number, holes: { { number } }, wy0: number, wy1: number, color: Color3)
	local function seg(a: number, b: number, lo: number, hi: number, nm: string)
		if b - a < 0.01 or hi - lo < 0.01 then
			return
		end
		local size, pos
		if axis == "x" then
			size = Vector3.new(b - a, hi - lo, f1 - f0)
			pos = Vector3.new((a + b) / 2, (lo + hi) / 2, (f0 + f1) / 2)
		else
			size = Vector3.new(f1 - f0, hi - lo, b - a)
			pos = Vector3.new((f0 + f1) / 2, (lo + hi) / 2, (a + b) / 2)
		end
		newPart(parent, nm, size, pos, color, Mat.Concrete, "S")
	end
	if #holes == 0 then
		seg(a0, a1, ya, yb, name)
		return
	end
	seg(a0, a1, ya, wy0, name .. "Low")
	seg(a0, a1, wy1, yb, name .. "Top")
	local cur = a0
	for _, h in holes do
		seg(cur, h[1], wy0, wy1, name .. "Pier")
		cur = h[2]
	end
	seg(cur, a1, wy0, wy1, name .. "Pier")
end

local function glaze(parent: Instance, axis: string, f0: number, f1: number, lo: number, hi: number, wy0: number, wy1: number, outward: number, frameColor: Color3, glassColor: Color3)
	local fm, mid, c, w = (f0 + f1) / 2, (wy0 + wy1) / 2, (lo + hi) / 2, hi - lo
	local outer = if outward > 0 then f1 else f0
	local pane, mull, sill
	if axis == "x" then
		pane = newPart(parent, "WindowGlass", Vector3.new(w, wy1 - wy0, 0.2), Vector3.new(c, mid, fm), glassColor, Mat.Glass)
		mull = newPart(parent, "WindowMullion", Vector3.new(0.3, wy1 - wy0, 0.3), Vector3.new(c, mid, fm), frameColor)
		sill = newPart(parent, "WindowSill", Vector3.new(w + 1.2, 0.35, 0.9), Vector3.new(c, wy0 - 0.17, outer + outward * 0.4), K.white, Mat.Concrete, "n")
	else
		pane = newPart(parent, "WindowGlass", Vector3.new(0.2, wy1 - wy0, w), Vector3.new(fm, mid, c), glassColor, Mat.Glass)
		mull = newPart(parent, "WindowMullion", Vector3.new(0.3, wy1 - wy0, 0.3), Vector3.new(fm, mid, c), frameColor)
		sill = newPart(parent, "WindowSill", Vector3.new(0.9, 0.35, w + 1.2), Vector3.new(outer + outward * 0.4, wy0 - 0.17, c), K.white, Mat.Concrete, "n")
	end
	pane.Transparency = 0.55
end

-- ผนังนอก 4 ด้านของชั้น level (0..2): หน้า/หลัง/ตะวันออก/ตะวันตก เจาะหน้าต่างให้ตรงกับห้อง
-- ชั้นล่างผนังหน้าเจาะประตู x -7..7 (สูง 11), ชั้น 2 ผนังตะวันตกเจาะประตูหนีไฟ z -108..-98 (สูง 9)
function ClassroomKit.BuildShell(parent: Instance, level: number, wallColor: Color3, frameColor: Color3, glassColor: Color3)
	local y0, y1 = level * 16, level * 16 + 16
	local wy0, wy1 = y0 + 6.8, y0 + 11.2
	local function holesOf(xs: { number }, lo: number, hi: number): { { number } }
		local hs = {}
		for _, cx in xs do
			if cx - 3.2 >= lo and cx + 3.2 <= hi then
				table.insert(hs, { cx - 3.2, cx + 3.2 })
			end
		end
		return hs
	end
	local function windows(axis: string, f0: number, f1: number, hs: { { number } }, outward: number)
		for _, h in hs do
			glaze(parent, axis, f0, f1, h[1], h[2], wy0, wy1, outward, frameColor, glassColor)
		end
	end

	-- ผนังหน้า z -61..-60
	local fx = ClassroomKit.WindowXs(level, "front")
	if level == 0 then
		local hl, hr = holesOf(fx, -60, -7), holesOf(fx, 7, 60)
		wallPieces(parent, "FrontWallL", "x", -61, -60, -60, -7, y0, y1, hl, wy0, wy1, wallColor)
		wallPieces(parent, "FrontWallR", "x", -61, -60, 7, 60, y0, y1, hr, wy0, wy1, wallColor)
		wallPieces(parent, "FrontDoorTop", "x", -61, -60, -7, 7, y0 + 11, y1, {}, 0, 0, wallColor)
		windows("x", -61, -60, hl, 1)
		windows("x", -61, -60, hr, 1)
	else
		local hs = holesOf(fx, -60, 60)
		wallPieces(parent, "FrontWall" .. level, "x", -61, -60, -60, 60, y0, y1, hs, wy0, wy1, wallColor)
		windows("x", -61, -60, hs, 1)
	end

	-- ผนังหลัง z -120..-119
	local bs = holesOf(ClassroomKit.WindowXs(level, "back"), -60, 60)
	wallPieces(parent, "BackWall" .. level, "x", -120, -119, -60, 60, y0, y1, bs, wy0, wy1, wallColor)
	windows("x", -120, -119, bs, -1)

	-- ผนังด้านข้าง: หน้าต่างเฉพาะปลายทางเดิน (z -93..-87) เพราะท้ายห้องติดผนังข้าง
	local endHole = { { -93, -87 } }
	wallPieces(parent, "EastWall" .. level, "z", 59, 60, -120, -60, y0, y1, endHole, wy0, wy1, wallColor)
	windows("z", 59, 60, endHole, 1)
	if level == 1 then
		wallPieces(parent, "WestWall1a", "z", -60, -59, -120, -108, y0, y1, {}, 0, 0, wallColor)
		wallPieces(parent, "WestWall1b", "z", -60, -59, -98, -60, y0, y1, endHole, wy0, wy1, wallColor)
		wallPieces(parent, "WestDoorTop", "z", -60, -59, -108, -98, y0 + 9, y1, {}, 0, 0, wallColor)
	else
		wallPieces(parent, "WestWall" .. level, "z", -60, -59, -120, -60, y0, y1, endHole, wy0, wy1, wallColor)
	end
	windows("z", -60, -59, endHole, -1)
end

----------------------------------------------------------------- เนื้อหากระดาน/บอร์ด
local LESSONS = {
	{ "数学", { "二次関数", "y = ax² + bx + c", "頂点 (p, q)" } },
	{ "国語", { "走れメロス", "作者：太宰治", "音読 p.34〜36" } },
	{ "英語", { "Unit 5  Daily Life", "Do you like ~ ?", "Yes, I do. / No, I don't." } },
	{ "理科", { "光合成", "6CO₂ + 6H₂O", "→ C₆H₁₂O₆ + 6O₂" } },
	{ "社会", { "江戸時代", "参勤交代・鎖国", "1639年" } },
	{ "数学", { "平方根", "√2 ≈ 1.414", "√9 = 3" } },
	{ "音楽", { "合唱コンクール", "パート別練習", "ソプラノ・アルト" } },
	{ "体育", { "体育祭 リレー", "校庭に集合", "ジャージで！" } },
	{ "道徳", { "思いやりとは", "ノートに意見を", "グループで話し合い" } },
	{ "地理", { "日本の気候", "太平洋側・日本海側", "降水量グラフ" } },
	{ "美術", { "水彩画 風景", "遠近法", "道具を忘れずに" } },
	{ "技術", { "木工 本立て", "のこぎりの使い方", "安全第一" } },
}
local SUBJ = { "国語", "数学", "英語", "理科", "社会", "音楽", "体育", "美術", "技術", "道徳" }
local DUTY = { "田中・佐藤", "鈴木・高橋", "伊藤・渡辺", "山本・中村", "小林・加藤", "吉田・山田", "佐々木・松本", "井上・木村", "林・清水", "山口・斎藤", "森・阿部", "池田・橋本" }
local MOTTO = { "一期一会", "努力は裏切らない", "笑顔であいさつ", "思いやり", "挑戦", "一致団結", "継続は力なり", "感謝", "全力投球", "仲間を大切に", "有言実行", "元気に前向き" }
local TIMES = { { 8, 50 }, { 10, 20 }, { 13, 5 }, { 14, 50 }, { 9, 15 }, { 11, 40 } }

local function chalkBoard(p: BasePart, seed: number)
	local g = mkGui(p, Enum.NormalId.Right, 40)
	local L = LESSONS[seed % #LESSONS + 1]
	local font = Enum.Font.PatrickHand
	label(g, "11月2日（月）", 0.02, 0.05, 0.28, 0.30, K.chalk, font)
	label(g, "日直\n" .. DUTY[seed % #DUTY + 1], 0.02, 0.40, 0.28, 0.46, K.yellow, font)
	frame(g, 0.315, 0.08, 0.004, 0.84, K.chalk, 0.4)
	label(g, "【" .. L[1] .. "】", 0.34, 0.05, 0.36, 0.26, K.pink, font)
	label(g, table.concat(L[2], "\n"), 0.34, 0.33, 0.36, 0.58, K.chalk, font)
	frame(g, 0.715, 0.08, 0.004, 0.84, K.chalk, 0.4)
	label(g, "時間割", 0.74, 0.05, 0.24, 0.18, K.blue, font)
	local rows = {}
	for i = 1, 5 do
		table.insert(rows, i .. "  " .. SUBJ[(seed * 3 + i * 7) % #SUBJ + 1])
	end
	label(g, table.concat(rows, "\n"), 0.76, 0.24, 0.22, 0.70, K.chalk, font, Enum.TextXAlignment.Left)
end

local function corkBoard(p: BasePart, face: Enum.NormalId, seed: number, big: boolean)
	local g = mkGui(p, face, 40)
	frame(g, 0.03, 0.08, 0.34, 0.84, K.white)
	label(g, "当番表", 0.04, 0.10, 0.32, 0.18, K.navy)
	label(g, "日直 " .. DUTY[seed % #DUTY + 1] .. "\n黒板 " .. DUTY[(seed + 3) % #DUTY + 1] .. "\n配膳 " .. DUTY[(seed + 5) % #DUTY + 1], 0.05, 0.30, 0.30, 0.58, K.navy, Enum.Font.GothamMedium, Enum.TextXAlignment.Left)
	local notes = { { "宿題\n提出日\n11/5", K.yellow }, { "遠足\n11/20", K.pink }, { "テスト\n来週", K.blue } }
	for i, n in notes do
		local f = frame(g, 0.40 + (i - 1) * 0.20, if i % 2 == 0 then 0.18 else 0.10, 0.18, 0.5, n[2] :: Color3)
		label(f, n[1] :: string, 0.05, 0.05, 0.9, 0.9, K.navy, Enum.Font.GothamMedium)
	end
	if big then
		label(g, "掲示板", 0.40, 0.72, 0.58, 0.2, K.navy)
	end
end

----------------------------------------------------------------- ห้อง
type Room = { x0: number, x1: number, W: number, zc: number, sgn: number, yf: number, H: number, level: number, west: boolean, k: number }

local function roomApi(R: Room, folder: Instance)
	local x0, zc, sgn, yf = R.x0, R.zc, R.sgn, R.yf
	local function P(name: string, u0: number, u1: number, v0: number, v1: number, h0: number, h1: number, color: Color3, mat: Enum.Material?, flags: string?): Part
		local xa, xb = x0 + u0, x0 + u1
		local za, zb = zc + sgn * v0, zc + sgn * v1
		if za > zb then
			za, zb = zb, za
		end
		return newPart(folder, name, Vector3.new(xb - xa, h1 - h0, zb - za), Vector3.new((xa + xb) / 2, yf + (h0 + h1) / 2, (za + zb) / 2), color, mat, flags)
	end
	return P
end

local function buildClass(parent: Instance, R: Room, letter: string, seed: number)
	local W, H, sgn, zc, yf, x0 = R.W, R.H, R.sgn, R.zc, R.yf, R.x0
	local grade = GRADE[R.level + 1]
	local folder = Instance.new("Folder")
	folder.Name = "Room_" .. (R.level + 1) .. letter
	folder.Parent = parent
	local P = roomApi(R, folder)
	local fE, fW = Enum.NormalId.Right, Enum.NormalId.Left
	local fC = if sgn == 1 then Enum.NormalId.Front else Enum.NormalId.Back -- หันเข้าทางเดิน
	local fX = if sgn == 1 then Enum.NormalId.Back else Enum.NormalId.Front -- หันเข้าผนังหน้าต่าง
	local sc = (seed % 6) + 1

	-- ผนังกั้นห้อง (ฝั่งตะวันตกของห้องนี้) หนา 1
	if R.west then
		P("Partition", -1, 0, 0, D, 0, H, K.wall, Mat.Concrete, "S")
	end

	-- ผนังทางเดิน + ประตูบานเลื่อนครึ่งบาน (ช่องโล่ง ~6.6 สูง 10.2)
	local wd1 = W - 1.5
	local wd0 = wd1 - 8.6
	local a0 = if R.west then -1 else 0
	P("CorridorWallA", a0, wd0, -1, 0, 0, H, K.wall, Mat.Concrete, "S")
	P("CorridorWallB", wd1, W, -1, 0, 0, H, K.wall, Mat.Concrete, "S")
	P("DoorHeader", wd0, wd1, -1, 0, 10.2, H, K.wall, Mat.Concrete, "S")
	-- บานที่ 1 เลื่อนสุดซ้อนหน้าผนัง, บานที่ 2 เปิดครึ่ง (คลุมช่องด้านท้ายห้อง 2 stud)
	for i, u in { wd0 - 4.4, wd1 - 2.0 } do
		P("DoorPanel" .. i, u, u + 4.4, -1.4, -1.0, 0, 4.2, K.alu, Mat.Metal)
		local gl = P("DoorGlass" .. i, u + 0.2, u + 4.2, -1.3, -1.1, 4.2, 10.0, hex("BFD6DC"), Mat.Glass)
		gl.Transparency = 0.55
	end
	-- ป้ายเหนือประตู "1-A" และป้ายยื่น 一年A組
	local plate = P("ClassPlate", wd0 + 1.6, wd1 - 1.6, -1.25, -1.0, 11.4, 14.2, K.navy, Mat.SmoothPlastic, "n")
	plainSign(plate, fC, (R.level + 1) .. "-" .. letter, K.white, 40)
	local bu = wd0 - 1.6
	local blade = P("ClassBlade", bu - 0.15, bu + 0.15, -4.4, -1.0, 10.6, 13.0, K.cream, Mat.SmoothPlastic, "n")
	local blabel = grade .. "年" .. letter .. "組"
	plainSign(blade, fE, blabel, K.navy, 40)
	plainSign(blade, fW, blabel, K.navy, 40)

	-- ของติดผนังทางเดิน (ส่วนผนังหน้าห้องที่ไม่ถูกบานประตูบัง u 0..4.4)
	local kk = R.k
	if kk % 3 == 1 then
		local cb = P("CorridorBoard", 0.3, 3.8, -1.2, -1.0, 3.6, 7.6, K.cork, Mat.SmoothPlastic, "n")
		corkBoard(cb, fC, seed + 4, false)
	elseif kk % 3 == 0 then
		local fe = P("FireExtinguisherBox", 1.2, 2.8, -1.5, -1.0, 3.0, 6.8, K.red, Mat.SmoothPlastic, "n")
		local g = mkGui(fe, fC, 50)
		frame(g, 0.15, 0.18, 0.7, 0.45, K.white)
		label(g, "消火器", 0.1, 0.68, 0.8, 0.22, K.white)
	end
	if kk % 2 == 0 then
		local ct = TIMES[sc]
		local c = newPart(folder, "CorridorClock", Vector3.new(0.2, 2.4, 2.4), Vector3.new(x0 + 2.3, yf + 12.2, zc + sgn * -1.15), K.white, Mat.SmoothPlastic, "n")
		c.Shape = Enum.PartType.Cylinder
		c.CFrame = CFrame.new(c.Position) * CFrame.Angles(0, math.rad(90), 0)
		clockGui(c, if sgn == 1 then Enum.NormalId.Right else Enum.NormalId.Left, ct[1], ct[2])
	end

	-- กระดานดำ (ผนังตะวันตก) กว้าง 14 สูง 4.5 กรอบไม้ รางชอล์ก ชอล์ก แปรงลบ
	P("BoardFrame", 0, 0.45, 3.2, 17.8, 3.6, 8.7, K.boardFrame, Mat.Wood, "n")
	local board = P("Chalkboard", 0.45, 0.58, 3.5, 17.5, 3.9, 8.4, K.board, Mat.SmoothPlastic, "n")
	chalkBoard(board, seed)
	P("ChalkTray", 0.3, 1.2, 3.5, 17.5, 3.6, 3.9, K.tray, Mat.Wood, "n")
	P("Chalk", 0.5, 1.0, 6.0, 6.8, 3.9, 4.05, K.white, Mat.SmoothPlastic, "n")
	P("Eraser", 0.5, 1.1, 12.0, 13.4, 3.9, 4.3, K.darkSteel, Mat.SmoothPlastic, "n")

	-- นาฬิกา (กลาง) ป้ายคติ (ซ้าย) ธงชาติ (ขวา) ลำโพง 2 ตัวเหนือกระดาน
	local ct = TIMES[sc]
	local clock = P("RoomClock", 0.05, 0.3, 9.2, 11.8, 10.0, 12.6, K.white, Mat.SmoothPlastic, "n")
	clock.Shape = Enum.PartType.Cylinder
	clockGui(clock, fE, ct[1], ct[2])
	local motto = P("Motto", 0, 0.25, 3.0, 8.2, 10.4, 12.4, K.woodDark, Mat.Wood, "n")
	plainSign(motto, fE, MOTTO[seed % #MOTTO + 1], K.cream, 40)
	local flag = P("Flag", 0, 0.12, 12.8, 17.6, 10.0, 13.2, K.white, Mat.Fabric, "n")
	do
		local g = mkGui(flag, fE, 40)
		local c = frame(g, 0.5, 0.5, 0.0, 0.6, K.red)
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1
		ar.Parent = c
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.5, 0)
		cr.Parent = c
		c.Size = UDim2.fromScale(0.6, 0.6)
	end
	P("SpeakerL", 0, 1.1, 0.8, 2.4, 12.6, 14.4, K.navy, Mat.SmoothPlastic, "n")
	P("SpeakerR", 0, 1.1, 18.6, 20.2, 12.6, 14.4, K.navy, Mat.SmoothPlastic, "n")

	-- โต๊ะครู + เก้าอี้ + แท่นพูด
	P("TeacherDesk", 1.0, 3.0, 5.0, 10.2, 2.4, 2.65, K.cabinet, Mat.Wood)
	P("TeacherPedL", 1.2, 2.8, 5.1, 6.4, 0, 2.4, K.woodDark, Mat.Wood)
	P("TeacherPedR", 1.2, 2.8, 8.8, 10.1, 0, 2.4, K.woodDark, Mat.Wood)
	P("TeacherChairSeat", 3.1, 4.5, 6.9, 8.3, 1.4, 1.65, K.darkSteel, Mat.SmoothPlastic)
	P("TeacherChairBack", 4.35, 4.55, 6.8, 8.4, 1.65, 3.2, K.darkSteel, Mat.SmoothPlastic, "n")
	P("TeacherChairLeg", 3.6, 3.9, 7.4, 7.8, 0, 1.4, K.steel, Mat.Metal)
	P("PodiumBase", 1.2, 2.9, 13.6, 15.4, 0, 3.4, K.woodDark, Mat.Wood)
	P("PodiumTop", 1.0, 3.1, 13.4, 15.6, 3.4, 3.6, K.cabinet, Mat.Wood)

	-- โต๊ะนักเรียน 5 คอลัมน์ x 4 แถว (2 + ทางเดินกลาง + 3) หันหน้าไปกระดาน เก้าอี้อยู่ท้ายโต๊ะ
	local seat = CHAIR[(seed % #CHAIR) + 1]
	for _, r in { 5.8, 8.6, 11.4, 14.2 } do
		for _, cv in { 4.8, 7.0, 11.7, 13.9, 16.1 } do
			P("DeskTop", r, r + 1.7, cv - 1.05, cv + 1.05, 2.0, 2.2, K.deskTop, Mat.Wood)
			P("DeskLeg", r + 0.75, r + 0.95, cv - 0.9, cv + 0.9, 0, 2.0, K.steel, Mat.Metal)
			P("Seat", r + 1.2, r + 2.6, cv - 0.7, cv + 0.7, 1.2, 1.4, seat, Mat.SmoothPlastic)
			P("ChairBack", r + 2.45, r + 2.65, cv - 0.65, cv + 0.65, 1.4, 2.6, seat, Mat.SmoothPlastic, "n")
			P("ChairLeg", r + 1.9, r + 2.1, cv - 0.55, cv + 0.55, 0, 1.2, K.darkSteel, Mat.Metal)
		end
	end

	-- ท้ายห้อง (ผนังตะวันออก): บอร์ดไม้ก๊อก ตู้เก็บของ แอร์ ตู้ไม้กวาดที่มุมใกล้ประตู
	P("CorkFrame", W - 0.35, W, 5.4, 15.6, 7.0, 11.1, K.woodDark, Mat.Wood, "n")
	local cork = P("CorkBoard", W - 0.5, W - 0.35, 5.6, 15.4, 7.2, 10.9, K.cork, Mat.SmoothPlastic, "n")
	corkBoard(cork, fW, seed, true)
	P("StorageCabinet", W - 1.3, W, 8.0, 16.0, 0, 6.0, K.cabinet, Mat.Wood)
	P("StorageDoors", W - 1.4, W - 1.3, 8.2, 15.8, 0.3, 5.8, K.woodDark, Mat.Wood, "n")
	P("AirconBody", W - 1.2, W, 6.0, 12.0, 12.4, 14.2, K.white, Mat.SmoothPlastic, "n")
	P("AirconVent", W - 1.25, W - 1.2, 6.4, 11.6, 12.5, 12.9, K.darkSteel, Mat.SmoothPlastic, "n")
	P("CleaningLocker", W - 1.7, W, 0.3, 2.5, 0, 7.2, K.steel, Mat.Metal)
	P("CleaningLockerDoor", W - 1.8, W - 1.7, 0.4, 2.4, 0.3, 6.9, K.darkSteel, Mat.Metal, "n")
	P("BroomHandle", W - 2.4, W - 2.2, 0.5, 0.7, 0, 5.6, K.cabinet, Mat.Wood, "n")
	P("BroomHead", W - 2.7, W - 1.9, 0.3, 1.1, 0, 0.5, K.yellow, Mat.Fabric, "n")

	-- ชั้นวางกระเป๋าใต้หน้าต่าง (ฝั่งหน้า; ฝั่งหลังใช้ล็อกเกอร์เดิม)
	if sgn == 1 then
		P("BagShelf", 1.0, W - 1.0, D - 1.5, D, 0, 3.4, K.cabinet, Mat.Wood)
		P("BagShelfCubby", 1.0, W - 1.0, D - 1.6, D - 1.5, 0.6, 3.0, K.woodDark, Mat.Wood, "n")
	end

	-- ผ้าม่านครีม ปิดบางส่วน (ซ้ายของบานแรก, ขวาของบานที่สอง)
	local curtainLo, curtainHi = 6.5 - (yf - R.level * 16), 11.8 - (yf - R.level * 16)
	for i, f in { 0.25, 0.75 } do
		local u = W * f
		if not (R.sgn == 1 and R.level >= 1 and math.abs(x0 + u) < 11) then
			local c0, c1 = if i == 1 then u - 3.4 else u + 0.9, if i == 1 then u - 0.9 else u + 3.4
			local cur = P("Curtain" .. i, c0, c1, D - 0.6, D - 0.25, curtainLo, curtainHi, K.cream, Mat.Fabric, "n")
			cur.Transparency = 0.12
		end
	end

	-- แสงฟลูออเรสเซนต์ยาว 3 แถว (นีออนอ่อน) + PointLight ดวงเดียวกลางห้อง
	local strips = {}
	for i, v in { 4.5, 10.5, 16.5 } do
		local s = P("Fluorescent" .. i, 2.0, W - 2.0, v - 0.5, v + 0.5, H - 0.3, H - 0.05, hex("F4F1E2"), Mat.Neon, "n")
		s.Color = hex("DAD6C6")
		strips[i] = s
	end
	local light = Instance.new("PointLight")
	light.Color = hex("FFF3E0")
	light.Range = 24
	light.Brightness = 0.9
	light.Shadows = false
	light.Parent = strips[2]
	stats.lights += 1
end

-- โถงทางเข้า (genkan): ชั้นวางรองเท้า ม้านั่ง ป้ายต้อนรับ พื้นกระเบื้องสว่าง
local function buildLobby(parent: Instance, R: Room)
	local W, D_ = R.W, D
	local folder = Instance.new("Folder")
	folder.Name = "Genkan"
	folder.Parent = parent
	local P = roomApi(R, folder)
	if R.west then
		P("Partition", -1, 0, 0, D_, 0, R.H, K.wall, Mat.Concrete, "S")
	end
	P("GenkanTile", 0, W, 0.5, D_, 0, 0.1, K.tile, Mat.SmoothPlastic, "n")
	for _, side in { 0, 1 } do
		local u0 = if side == 0 then 0 else W - 1.8
		local face = if side == 0 then Enum.NormalId.Right else Enum.NormalId.Left
		for _, v in { 4.0, 10.8 } do
			local box = P("ShoeLockers", u0, u0 + 1.8, v, v + 6.2, 0, 5.4, K.cabinet, Mat.Wood)
			local g = mkGui(box, face, 40)
			for c = 0, 3 do
				for r = 0, 3 do
					frame(g, 0.04 + c * 0.24, 0.04 + r * 0.24, 0.22, 0.22, if (c + r) % 2 == 0 then K.woodDark else hex("8A6B47"))
				end
			end
		end
		P("GenkanBench", if side == 0 then 2.4 else W - 3.8, if side == 0 then 3.8 else W - 2.4, 5.0, 9.0, 0, 1.4, K.cabinet, Mat.Wood)
		local sg = P("ShoeSign", if side == 0 then 0 else W - 0.25, if side == 0 then 0.25 else W, 6.0, 15.0, 5.8, 7.4, K.navy, Mat.SmoothPlastic, "n")
		plainSign(sg, face, "下駄箱", K.white, 40)
	end
	local welcome = P("WelcomeSign", 7.0, W - 7.0, D_ - 0.3, D_, 11.2, 14.0, K.navy, Mat.SmoothPlastic, "n")
	plainSign(welcome, if R.sgn == 1 then Enum.NormalId.Front else Enum.NormalId.Back, "ようこそ  SUSUBLOX HIGH へ", K.yellow, 40)
end

-- โถงบันไดหนีไฟชั้น 2 (ประตูตะวันตก z -108..-98): ป้ายทางหนีไฟ ตู้ดับเพลิง
local function buildHall(parent: Instance, R: Room)
	local folder = Instance.new("Folder")
	folder.Name = "StairHall"
	folder.Parent = parent
	local P = roomApi(R, folder)
	local exit = P("ExitSign", 0, 0.2, 2.8, 7.2, 9.6, 11.2, K.green, Mat.SmoothPlastic, "n")
	plainSign(exit, Enum.NormalId.Right, "非常口 →", K.white, 40)
	local fe = P("FireExtinguisherBox", R.W - 1.2, R.W, 14.0, 15.6, 3.0, 6.8, K.red, Mat.SmoothPlastic, "n")
	local g = mkGui(fe, Enum.NormalId.Left, 50)
	frame(g, 0.15, 0.18, 0.7, 0.45, K.white)
	label(g, "消火器", 0.1, 0.68, 0.8, 0.22, K.white)
	P("HallBench", 6.0, 7.4, 14.0, 19.0, 0, 1.4, K.cabinet, Mat.Wood)
end

----------------------------------------------------------------- ประกอบทั้งอาคาร
function ClassroomKit.Build(school: Instance): { parts: number, lights: number, guis: number }
	stats = { parts = 0, lights = 0, guis = 0 }
	local root = Instance.new("Folder")
	root.Name = "Classrooms"
	for level = 0, 2 do
		local count = 0
		local yf = if level == 0 then 0.4 else level * 16 + 0.1
		for _, bandName in { "back", "front" } do
			local band = BANDS[bandName]
			local k = 0
			for _, cell in cellsOf(level, bandName) do
				k += 1
				local R: Room = {
					x0 = cell.x0,
					x1 = cell.x1,
					W = cell.x1 - cell.x0,
					zc = band.zc,
					sgn = band.sgn,
					yf = yf,
					H = level * 16 + 15.5 - yf,
					level = level,
					west = cell.west,
					k = k,
				}
				if cell.kind == "class" then
					count += 1
					buildClass(root, R, string.sub(LETTERS, count, count), level * 12 + count)
				elseif cell.kind == "lobby" then
					buildLobby(root, R)
				else
					buildHall(root, R)
					-- โถงบันไดยังคงมีผนังกั้นฝั่งตะวันออกโดยห้องถัดไป
				end
			end
		end
	end
	root.Parent = school
	return stats
end

return ClassroomKit
