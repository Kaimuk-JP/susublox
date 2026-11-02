--!strict
-- เมนูหลัก (กด M หรือปุ่มมุมขวาบน): สเตตัส สไตล์ เควส ร้านค้า ปุ่มใหญ่พอสำหรับมือถือ
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Passives = require(ReplicatedStorage.Shared.Passives)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Shop = require(ReplicatedStorage.Shared.Shop)
local StyleData = require(ReplicatedStorage.Shared.Styles)
local Progression = require(ReplicatedStorage.Shared.Progression)

local player = Players.LocalPlayer
local menu = ReplicatedStorage:WaitForChild("MenuRemote") :: RemoteEvent
local questRemote = ReplicatedStorage:WaitForChild("QuestRemote") :: RemoteEvent
local shopRemote = ReplicatedStorage:WaitForChild("ShopRemote") :: RemoteEvent

local BP = require(ReplicatedStorage.Shared.BattlePass)
local Outfits = require(ReplicatedStorage.Shared.Outfits)
local World = require(ReplicatedStorage.Shared.World)
local Story = require(ReplicatedStorage.Shared.Story)
local WQ = require(ReplicatedStorage.Shared.WorldQuests)
local worldRemote = ReplicatedStorage:WaitForChild("WorldRemote") :: RemoteEvent
local outfitRemote = ReplicatedStorage:WaitForChild("OutfitRemote") :: RemoteEvent
local bpRemote = ReplicatedStorage:WaitForChild("BattlePassRemote") :: RemoteEvent
local gangRemote = ReplicatedStorage:WaitForChild("GangRemote") :: RemoteEvent
local warRemote = ReplicatedStorage:WaitForChild("WarRemote") :: RemoteEvent

local PRESTIGE_TITLES = { [0] = "มือใหม่", "ผู้กล้า", "นักสู้ตัวจริง", "ตำนานโรงเรียน", "ราชันย์นิรันดร์" }

local PANEL, ACCENT =Color3.fromHex("2B2D42"), Color3.fromHex("FFB7C5")

local gui = Instance.new("ScreenGui")
gui.Name = "Menu"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(70, 60)
toggle.Position = UDim2.new(1, -86, 0, 16)
toggle.Text = "เมนู"
toggle.Font = Enum.Font.FredokaOne
toggle.TextSize = 20
toggle.BackgroundColor3 = ACCENT
toggle.TextColor3 = PANEL
toggle.Parent = gui
Instance.new("UICorner", toggle)

local window = Instance.new("Frame")
window.Size = UDim2.new(0, 780, 0, 400)
window.Position = UDim2.fromScale(0.5, 0.5)
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.BackgroundColor3 = PANEL
window.Visible = false
window.Parent = gui
Instance.new("UICorner", window)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(780, 400)
constraint.Parent = window

local tabs = Instance.new("Frame")
tabs.Size = UDim2.new(1, 0, 0, 44)
tabs.BackgroundTransparency = 1
tabs.Parent = window
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Parent = tabs

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(8, 50)
content.Size = UDim2.new(1, -16, 1, -58)
content.BackgroundTransparency = 1
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.ScrollBarThickness = 4
content.Parent = window
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = content

local function clear()
	for _, c in content:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local order = 0
local function row(text: string, buttonText: string?, onClick: (() -> ())?)
	order += 1
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -8, 0, if text:find("\n") then 62 else 44)
	f.BackgroundColor3 = Color3.fromHex("3A3D5C")
	f.LayoutOrder = order
	f.Parent = content
	Instance.new("UICorner", f)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, if buttonText then -96 else -8, 1, 0)
	l.Position = UDim2.fromOffset(8, 0)
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 14
	l.Text = text
	l.Parent = f
	if buttonText and onClick then
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(84, 36)
		b.Position = UDim2.new(1, -90, 0.5, -18)
		b.BackgroundColor3 = ACCENT
		b.TextColor3 = PANEL
		b.Font = Enum.Font.FredokaOne
		b.TextSize = 14
		b.Text = buttonText
		b.Parent = f
		Instance.new("UICorner", b)
		b.Activated:Connect(onClick)
	end
end

local current = "stats"
local statAmount = 10
local render: () -> ()

local views: { [string]: () -> () } = {}

views.stats = function()
	local level = (player:GetAttribute("Level") :: number?) or 1
	row(`Lv.{level}  แต้มสเตตัส: {player:GetAttribute("StatPoints") or 0}  Prestige: {player:GetAttribute("Prestige") or 0}`)
	local names = { Strength = "พลังหมัด", Health = "พลังชีวิต", Stamina = "พลังงาน", Speed = "ความเร็ว" }
	local effects = {
		Strength = function(v: number) return `ดาเมจ +{v * 5}%` end,
		Health = function(v: number) return `เลือดสูงสุด +{v * 5}` end,
		Stamina = function(v: number) return `พลังงานสูงสุด +{v * 5}` end,
		Speed = function(v: number) return `ความเร็วเดิน +{math.floor(v * 3) / 10}` end,
	}
	if ((player:GetAttribute("StatPoints") :: number?) or 0) > 0 then
		row("ลงแต้มทั้งหมดอัตโนมัติ (แบ่งเท่าๆ กันทุกสเตตัส)", "ลงให้ทั้งหมด", function()
			menu:FireServer("AutoStats")
		end)
	end
	local points = (player:GetAttribute("StatPoints") :: number?) or 0
	if points > 0 then
		-- ช่องกรอกจำนวนแต้มที่จะลงต่อการกดหนึ่งครั้ง (กรอกแล้วกดปุ่ม "ลง" ที่สเตตัสที่ต้องการ)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, -8, 0, 44)
		f.BackgroundColor3 = Color3.fromHex("3A3D5C")
		order += 1
		f.LayoutOrder = order
		f.Parent = content
		Instance.new("UICorner", f)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -190, 1, 0)
		l.Position = UDim2.fromOffset(8, 0)
		l.BackgroundTransparency = 1
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Font = Enum.Font.FredokaOne
		l.TextSize = 14
		l.Text = "จำนวนแต้มที่จะลงต่อครั้ง"
		l.Parent = f
		local box = Instance.new("TextBox")
		box.Size = UDim2.fromOffset(70, 32)
		box.Position = UDim2.new(1, -176, 0.5, -16)
		box.BackgroundColor3 = Color3.fromHex("22243A")
		box.TextColor3 = Color3.new(1, 1, 1)
		box.Font = Enum.Font.FredokaOne
		box.TextSize = 16
		box.ClearTextOnFocus = true
		box.Text = tostring(math.min(statAmount, points))
		box.Parent = f
		Instance.new("UICorner", box)
		box.FocusLost:Connect(function()
			local n = tonumber(box.Text)
			statAmount = if n then math.clamp(math.floor(n), 1, 9999) else 1
			render()
		end)
		local maxB = Instance.new("TextButton")
		maxB.Size = UDim2.fromOffset(92, 32)
		maxB.Position = UDim2.new(1, -98, 0.5, -16)
		maxB.BackgroundColor3 = ACCENT
		maxB.TextColor3 = PANEL
		maxB.Font = Enum.Font.FredokaOne
		maxB.TextSize = 14
		maxB.Text = "ใช้ทั้งหมด"
		maxB.Parent = f
		Instance.new("UICorner", maxB)
		maxB.Activated:Connect(function()
			statAmount = points
			render()
		end)
	end
	for _, stat in Progression.Stats do
		local v = (player:GetAttribute("Stat_" .. stat) :: number?) or 0
		local n = math.max(1, math.min(statAmount, math.max(points, 1)))
		row(`{names[stat]}  {v} แต้ม  ({effects[stat](v)})`, `+{n}`, function()
			menu:FireServer("AddStat", stat, n)
		end)
	end
	if level >= Progression.MaxLevel then
		row("ถึงเลเวลสูงสุดแล้ว: รีเซ็ตเพื่อรับโบนัส EXP ถาวร 10%", "Prestige", function()
			menu:FireServer("Prestige")
		end)
	end
	local used = (player:GetAttribute("PassiveSlots") :: number?) or 0
	row(`สกิลติดตัว: ใส่ได้ {Passives.MaxSlots} ช่อง (ใช้อยู่ {used}/{Passives.MaxSlots}) — กดซ้ำเพื่อถอด`)
	for id, passive in Passives.All do
		local unlocked = level >= passive.UnlockLevel
		local on = player:GetAttribute("Passive_" .. id) == true
		local full = used >= Passives.MaxSlots
		local label = `{if on then "✓ " elseif unlocked then "" else "🔒 "}{passive.Name} (Lv.{passive.UnlockLevel})\n{passive.Desc}`
		if on then
			row(label, "ถอด", function()
				menu:FireServer("EquipPassive", id)
			end)
		elseif unlocked and not full then
			row(label, "ใส่", function()
				menu:FireServer("EquipPassive", id)
			end)
		elseif unlocked then
			row(label .. "  (ช่องเต็ม ถอดตัวอื่นก่อน)")
		else
			row(label)
		end
	end
end

local STYLE_ORDER = { "StreetBrawl", "Karate", "Judo", "Wrestling", "Kendo", "ShadowFist" }

views.styles = function()
	local mastery = (player:GetAttribute("MasteryLevel") :: number?) or 1
	local current = player:GetAttribute("Style")
	row(`สไตล์ที่สวมอยู่: {StyleData.Styles[current :: string] and StyleData.Styles[current :: string].Name or current}  Mastery {mastery}`)
	for _, id in STYLE_ORDER do
		local style = StyleData.Styles[id]
		if style then
			local unlocked = player:GetAttribute("StyleUnlocked_" .. id) == true
			local equipped = current == id
			local sk = style.Skills
			local skills = `Z {sk.Z.Name} · X {sk.X.Name} · C {sk.C.Name} · V {sk.V.Name} · ไม้ตาย {style.Ultimate.Name}`
			local status = if equipped then "✓ " elseif unlocked then "" else "🔒 "
			local hint = if unlocked then "" elseif style.UnlockLevel then ` (ปลดล็อก Lv.{style.UnlockLevel})` else " (ปลดล็อกจากบอสหัวหน้าชมรม)"
			local label = `{status}{style.Name}{hint}\n{skills}`
			if unlocked and not equipped then
				row(label, "สวม", function()
					menu:FireServer("EquipStyle", id)
				end)
			else
				row(label)
			end
		end
	end
end

views.quests = function()
	row(`ล็อกอินต่อเนื่อง: วันที่ {player:GetAttribute("LoginStreak") or 0}/7`)
	for _, group in { Quests.Daily, Quests.Weekly } do
		for _, q in group do
			local prog = (player:GetAttribute("Q_" .. q.Id) :: number?) or 0
			if player:GetAttribute("QC_" .. q.Id) == true then
				row(`✓ {q.Name}  รับรางวัลแล้ว`)
			else
				row(`{q.Name}  {prog}/{q.Goal}  (+¥{q.Yen} +{q.Exp} EXP)`, if prog >= q.Goal then "รับ" else nil, function()
					questRemote:FireServer(q.Id)
				end)
			end
		end
	end
end

views.shop = function()
	row(`เยน: ¥{player:GetAttribute("Yen") or 0}`)
	for id, item in Shop.Items do
		row(`{item.Name}  ¥{item.Price}`, "ซื้อ", function()
			shopRemote:FireServer(id)
		end)
	end
end

views.battlepass = function()
	local tier = (player:GetAttribute("BP_Tier") :: number?) or 0
	local premium = player:GetAttribute("BP_Premium") == true
	row(`Battle Pass ซีซัน {BP.Season}  ขั้น {tier}/{BP.Tiers}  XP {player:GetAttribute("BP_Xp") or 0}  {if premium then "(พรีเมียม)" else "(สายฟรี)"}`)
	for t = 1, BP.Tiers do
		if tier >= t then
			row(`ขั้น {t} ฟรี: ¥{BP.Free[t].Yen or 0}{if BP.Free[t].Outfit then " + ชุด" else ""}`, "รับ", function()
				bpRemote:FireServer("Free", t)
			end)
			if premium then
				local r = BP.Premium[t]
				row(`ขั้น {t} พรีเมียม: ¥{r.Yen or 0}{if r.Outfit then " + ชุด" elseif r.ExpBoost then " + บูสต์ EXP" else ""}`, "รับ", function()
					bpRemote:FireServer("Premium", t)
				end)
			end
		end
	end
end

views.gang = function()
	local gang = (player:GetAttribute("Gang") :: string?) or ""
	if gang == "" then
		row("ยังไม่มีแก๊ง: พิมพ์ชื่อ 3–16 ตัว (อังกฤษ/ตัวเลข/_) แล้วสร้างหรือเข้าร่วม")
		order += 1
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(1, -8, 0, 40)
		box.LayoutOrder = order
		box.PlaceholderText = "ชื่อแก๊ง"
		box.Text = ""
		box.ClearTextOnFocus = false
		box.Font = Enum.Font.FredokaOne
		box.TextSize = 16
		box.BackgroundColor3 = Color3.fromHex("3A3D5C")
		box.TextColor3 = Color3.new(1, 1, 1)
		box.Parent = content
		Instance.new("UICorner", box)
		row(`สร้างแก๊ง (¥{Shop.GangCreateCost})`, "สร้าง", function()
			gangRemote:FireServer("Create", box.Text)
		end)
		row("เข้าร่วมแก๊งตามชื่อที่พิมพ์", "เข้า", function()
			gangRemote:FireServer("Join", box.Text)
		end)
	else
		row(`แก๊ง {gang}  เลเวล {player:GetAttribute("GangLevel") or 1}  เงินแก๊ง ¥{player:GetAttribute("GangFunds") or 0}`)
		row("ออกจากแก๊ง", "ออก", function()
			gangRemote:FireServer("Leave")
		end)
		local queued = player:GetAttribute("WarQueued") == true
		row(
			if player:GetAttribute("InWar") then "กำลังอยู่ในสงคราม!" else "สงครามแก๊ง 4v4: ต้องมีเพื่อนในแก๊งเข้าคิว 4 คน",
			if queued then "ออกคิว" else "เข้าคิว",
			function()
				warRemote:FireServer(if queued then "Unqueue" else "Queue")
			end
		)
	end
end

views.story = function()
	local index = (player:GetAttribute("StoryIndex") :: number?) or 1
	local total = #Story.Steps
	row(`เส้นทางสู่ราชาโรงเรียน: ผ่านแล้ว {math.min(index - 1, total)}/{total} ขั้น`)
	-- ขั้นที่ผ่านแล้ว 2 ขั้นล่าสุด, ขั้นปัจจุบัน, และขั้นถัดไปอีก 3 ขั้น
	for i = math.max(1, index - 2), math.min(total, index + 3) do
		local step = Story.Steps[i]
		local r = step.Reward
		local rewardLine = `รางวัล: ¥{r.Yen}{if r.Exp > 0 then ` +{r.Exp} EXP` else ""}{if r.Outfit then " + ชุด" else ""}`
		if i < index then
			row(`✓ {step.Title}`)
		elseif i == index then
			row(`▶ {step.Title} ({Story.Acts[step.Act]})\n{player:GetAttribute("StoryText") or step.Desc}\n{rewardLine}`)
		else
			row(`🔒 {step.Title}  (ขั้นที่ {i}, {Story.Acts[step.Act]})`)
		end
	end
	if index > total then
		row("จบเนื้อเรื่องหลักแล้ว คุณคือราชาโรงเรียน! รับใบสั่งล่าต่อได้ไม่จำกัด")
	end
	-- ใบสั่งล่าแก๊ง (ทำซ้ำได้ไม่จบ)
	local bounty = player:GetAttribute("BountyText")
	if typeof(bounty) == "string" then
		row(`🎯 {bounty}\nรางวัล: {player:GetAttribute("BountyReward") or ""}  |  ทำสำเร็จแล้ว {player:GetAttribute("BountyDone") or 0} ครั้ง`, "เปลี่ยนใบ", function()
			worldRemote:FireServer("RerollBounty", "")
		end)
	end
end

views.map = function()
	row("แผนที่โลก: เดินทางด่วนไปย่านที่เคยค้นพบแล้ว (รอ 12 วินาทีระหว่างการเดินทาง)")
	row("โรงเรียนซูซูบล็อกซ์ (จุดเริ่มต้น)", "เดินทาง", function()
		worldRemote:FireServer("Travel", "School")
	end)
	for _, d in World.Districts do
		local found = player:GetAttribute("Disc_" .. d.Id) == true
		if found then
			row(`{d.Name}  Lv.{d.Levels[1]}–{d.Levels[2]}`, "เดินทาง", function()
				worldRemote:FireServer("Travel", d.Id)
			end)
		else
			row(`🔒 ??? ยังไม่ได้ค้นพบ (เดินไปตามถนนสายหลักเพื่อค้นหา)`)
		end
	end
end

views.worldQuests = function()
	local count = (player:GetAttribute("QTCount") :: number?) or 0
	row(`ภารกิจที่รับอยู่: {count}/{WQ.MaxActive}  — คุยกับตัวละครที่มีเครื่องหมาย ! ในแต่ละย่านเพื่อรับภารกิจ`)
	for i = 1, count do
		local name = player:GetAttribute(`QT{i}Name`)
		local id = player:GetAttribute(`QT{i}Id`)
		row(`{name}\n{player:GetAttribute(`QT{i}Text`)}`, "ละทิ้ง", function()
			if typeof(id) == "string" then
				worldRemote:FireServer("Abandon", id)
			end
		end)
	end
	for _, d in World.Districts do
		if player:GetAttribute("Disc_" .. d.Id) == true then
			row(`{d.Name}: ผู้ให้ภารกิจคือ {d.GiverName}`)
		end
	end
end

views.outfits = function()
	local equipped = player:GetAttribute("Outfit")
	row(`เยน: ¥{player:GetAttribute("Yen") or 0}  — ชุดที่ใส่อยู่: {Outfits.Name((equipped :: string?) or Outfits.Default)}`)
	local auraOn = player:GetAttribute("AuraOff") ~= true
	row(`ออร่าสไตล์: {if auraOn then "สวมอยู่" else "ถอดอยู่"} (ใส่ซ้อนกับชุดใดก็ได้)`, if auraOn then "ถอด" else "สวม", function()
		outfitRemote:FireServer("ToggleAura")
	end)
	for _, id in Outfits.Order do
		local owned = player:GetAttribute("OutfitOwned_" .. id) == true
		local isAuraItem = id == "Aura_Sparkle"
		local isOn = if isAuraItem then player:GetAttribute("SparkleOn") == true else equipped == id
		local label = `{if isOn then "✓ " elseif owned then "" else "🔒 "}{Outfits.Name(id)}{if owned then "" else `  ¥{Outfits.Price(id)}`}`
		if isOn and isAuraItem then
			row(label, "ถอด", function()
				outfitRemote:FireServer("Equip", id)
			end)
		elseif isOn then
			row(label)
		elseif owned then
			row(label, "สวม", function()
				outfitRemote:FireServer("Equip", id)
			end)
		else
			row(label, "ซื้อ", function()
				shopRemote:FireServer(id)
			end)
		end
	end
end

views.prestige = function()
	local p = (player:GetAttribute("Prestige") :: number?) or 0
	local level = (player:GetAttribute("Level") :: number?) or 1
	row(`ฉายา: {PRESTIGE_TITLES[math.min(p, #PRESTIGE_TITLES)]}  Prestige {p}  โบนัส EXP ถาวร +{p * 10}%`)
	row(`ต้องถึงเลเวล {Progression.MaxLevel} (ตอนนี้ Lv.{level}) รีเซ็ตเลเวลและสเตตัส แลกฉายาและโบนัสถาวร`)
	if level >= Progression.MaxLevel then
		row("พร้อม Prestige แล้ว!", "ยืนยัน", function()
			menu:FireServer("Prestige")
		end)
	end
end

render = function()
	order = 0
	clear()
	views[current]()
end

local tabList = {
	{ "stats", "สเตตัส" },
	{ "styles", "สไตล์" },
	{ "outfits", "ชุด" },
	{ "story", "เนื้อเรื่อง" },
	{ "quests", "เควส" },
	{ "worldQuests", "ภารกิจโลก" },
	{ "map", "แผนที่" },
	{ "shop", "ร้าน" },
	{ "battlepass", "Pass" },
	{ "gang", "แก๊ง" },
	{ "prestige", "Prestige" },
}
for _, t in tabList do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1 / #tabList, 0, 1, 0)
	b.BackgroundColor3 = PANEL
	b.TextColor3 = ACCENT
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 12
	b.Text = t[2]
	b.Parent = tabs
	b.Activated:Connect(function()
		current = t[1]
		render()
	end)
end

local function setOpen(open: boolean)
	window.Visible = open
	if open then
		render()
	end
end

toggle.Activated:Connect(function()
	setOpen(not window.Visible)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		setOpen(not window.Visible)
	end
end)

-- อัปเดตเมื่อค่าเปลี่ยนขณะเปิดเมนู
player.AttributeChanged:Connect(function()
	if window.Visible and not UserInputService:GetFocusedTextBox() then -- ไม่รีเฟรชระหว่างพิมพ์
		render()
	end
end)
