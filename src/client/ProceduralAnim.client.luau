--!strict
-- ท่าทางต่อสู้แบบโค้ดล้วน: ขยับ Motor6D/AnimationConstraint (Transform) ของ R15 เอง ใช้ได้ทันทีโดยไม่ต้องมี asset แอนิเมชัน
-- (ถ้าใส่ asset ID ใน Assets.Animations แล้ว จะข้ามท่านั้นและให้ AnimationPlayer เล่นของจริงแทน)
-- ทิศ: ตัวละครหันหน้า -Z, หมุนรอบ X บวก = แขน/ขายกไปข้างหน้า, รอบ Y บวก = ไหล่ขวาหมุนไปหน้า
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local StyleData = require(ReplicatedStorage.Shared.Styles)

type Pose = { [string]: CFrame }
type Track = { Duration: number, Hold: boolean?, Keys: { { number | Pose } } }

local function A(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

-- ท่ากำปั้น: ข้างที่ชก (R/L) ง้างแล้วพุ่ง
local function punch(side: string, power: number): Track
	local other = if side == "Right" then "Left" else "Right"
	local sign = if side == "Right" then 1 else -1
	local wind: Pose = {
		[side .. "Shoulder"] = A(-35),
		[side .. "Elbow"] = A(70),
		[other .. "Shoulder"] = A(55),
		[other .. "Elbow"] = A(95),
		Waist = A(0, -25 * sign * power),
	}
	local strike: Pose = {
		[side .. "Shoulder"] = A(92),
		[side .. "Elbow"] = A(0),
		[other .. "Shoulder"] = A(45),
		[other .. "Elbow"] = A(95),
		Waist = A(-10 * power, 38 * sign * power),
		Neck = A(0, -15 * sign),
	}
	return { Duration = 0.38, Keys = { { 0, {} }, { 0.07, wind }, { 0.14, strike }, { 0.22, strike }, { 0.38, {} } } }
end

local guardPose: Pose = {
	RightShoulder = A(105),
	LeftShoulder = A(105),
	RightElbow = A(105),
	LeftElbow = A(105),
	Waist = A(-12),
	Neck = A(10),
	RightHip = A(-12),
	LeftHip = A(-12),
	RightKnee = A(-15),
	LeftKnee = A(-15),
}

local Tracks: { [string]: Track } = {
	M1_1 = punch("Right", 1),
	M1_2 = punch("Left", 1),
	M1_3 = punch("Right", 1.5),
	M1_4 = {
		-- ถีบปิดคอมโบ
		Duration = 0.5,
		Keys = {
			{ 0, {} },
			{ 0.1, { RightHip = A(15), RightKnee = A(-95), Waist = A(8), RightShoulder = A(50), LeftShoulder = A(50), RightElbow = A(90), LeftElbow = A(90) } },
			{ 0.2, { RightHip = A(88), RightKnee = A(-8), Waist = A(14), RightShoulder = A(30), LeftShoulder = A(60), LeftElbow = A(80), Root = A(0, 12) } },
			{ 0.3, { RightHip = A(88), RightKnee = A(-8), Waist = A(14), Root = A(0, 12) } },
			{ 0.5, {} },
		},
	},
	Block = { Duration = 0.1, Hold = true, Keys = { { 0, {} }, { 0.1, guardPose } } },
	BlockHit = {
		Duration = 0.18,
		Keys = { { 0, guardPose }, { 0.05, { RightShoulder = A(95), LeftShoulder = A(95), Waist = A(8), Neck = A(-10), RightHip = A(-5), LeftHip = A(-5) } }, { 0.18, guardPose } },
	},
	Dash = {
		Duration = 0.4,
		Keys = {
			{ 0, {} },
			{ 0.06, { Waist = A(-32), Neck = A(20), RightShoulder = A(-50), LeftShoulder = A(-50), RightHip = A(30), LeftHip = A(-20), RightKnee = A(-40) } },
			{ 0.2, { Waist = A(-32), Neck = A(20), RightShoulder = A(-50), LeftShoulder = A(-50), RightHip = A(-20), LeftHip = A(40), LeftKnee = A(-40) } },
			{ 0.4, {} },
		},
	},
	Hit = {
		-- สะดุ้งโดนตี
		Duration = 0.3,
		Keys = { { 0, {} }, { 0.05, { Waist = A(18), Neck = A(-25), RightShoulder = A(-25), LeftShoulder = A(-25), Root = A(6) } }, { 0.3, {} } },
	},
	Knockdown = {
		-- ล้มหงายแล้วลุกขึ้น
		Duration = 1.3,
		Keys = {
			{ 0, {} },
			{ 0.18, { Root = A(78) * CFrame.new(0, -1.5, 0), RightShoulder = A(-40), LeftShoulder = A(-40), Neck = A(-20) } },
			{ 0.9, { Root = A(78) * CFrame.new(0, -1.5, 0), RightShoulder = A(-40), LeftShoulder = A(-40), Neck = A(-20) } },
			{ 1.3, {} },
		},
	},
	Skill_Melee = punch("Right", 1.8),
	Skill_Dash = {
		Duration = 0.55,
		Keys = {
			{ 0, {} },
			{ 0.08, { Waist = A(-20, -30), RightShoulder = A(-50), RightElbow = A(80), LeftShoulder = A(60), LeftElbow = A(90) } },
			{ 0.2, { Waist = A(-38, 40), RightShoulder = A(95), RightElbow = A(0), LeftShoulder = A(-30), RightHip = A(-25), LeftHip = A(35) } },
			{ 0.32, { Waist = A(-38, 40), RightShoulder = A(95), RightElbow = A(0) } },
			{ 0.55, {} },
		},
	},
	Skill_AoE = {
		-- หมุนตัวฟาดรอบ
		Duration = 0.6,
		Keys = {
			{ 0, {} },
			{ 0.1, { Root = A(0, -50), RightShoulder = A(90, 0, -90), LeftShoulder = A(90, 0, 90), Waist = A(-12) } },
			{ 0.45, { Root = A(0, 330), RightShoulder = A(90, 0, -90), LeftShoulder = A(90, 0, 90), Waist = A(-12) } },
			{ 0.6, {} },
		},
	},
	Skill_Multi = {
		-- รัวหมัดสลับซ้ายขวา
		Duration = 1.3,
		Keys = (function()
			local keys: { { number | Pose } } = { { 0, {} } }
			local t = 0.08
			for i = 1, 8 do
				local right = i % 2 == 1
				local s, o = if right then "Right" else "Left", if right then "Left" else "Right"
				table.insert(keys, {
					t,
					{ [s .. "Shoulder"] = A(92), [s .. "Elbow"] = A(0), [o .. "Shoulder"] = A(40), [o .. "Elbow"] = A(100), Waist = A(-14, if right then 28 else -28) },
				})
				t += 0.13
			end
			table.insert(keys, { 1.3, {} })
			return keys
		end)(),
	},
	Skill_Counter = { Duration = 0.15, Hold = true, Keys = { { 0, {} }, { 0.15, guardPose } } },
	Skill_Deflect = { Duration = 0.15, Hold = true, Keys = { { 0, {} }, { 0.15, guardPose } } },
	Skill_Teleport = { Duration = 0.4, Keys = { { 0, {} }, { 0.1, { Waist = A(-30), RightKnee = A(-50), LeftKnee = A(-50), RightHip = A(40), LeftHip = A(40) } }, { 0.4, {} } } },
	Skill_Charge = {
		Duration = 0.6,
		Keys = { { 0, {} }, { 0.1, { Waist = A(-35, 15), RightShoulder = A(70), LeftShoulder = A(70), Neck = A(25) } }, { 0.45, { Waist = A(-35, 15), RightShoulder = A(70), LeftShoulder = A(70), Neck = A(25) } }, { 0.6, {} } },
	},
	Skill_Grapple = {
		Duration = 0.6,
		Keys = { { 0, {} }, { 0.12, { RightShoulder = A(95), LeftShoulder = A(95), RightElbow = A(10), LeftElbow = A(10), Waist = A(-14) } }, { 0.4, { RightShoulder = A(95), LeftShoulder = A(95), Waist = A(-24), Neck = A(10) } }, { 0.6, {} } },
	},
	Skill_Ultimate = {
		-- ชาร์จพลังแล้วปล่อยหมัดเต็มแรง
		Duration = 1.1,
		Keys = {
			{ 0, {} },
			{ 0.4, { Waist = A(-22, -35), RightShoulder = A(-70), RightElbow = A(100), LeftShoulder = A(70), LeftElbow = A(90), RightHip = A(-20), LeftHip = A(-20), RightKnee = A(-35), LeftKnee = A(-35) } },
			{ 0.52, { Waist = A(-18, 50), RightShoulder = A(95), RightElbow = A(0), LeftShoulder = A(-35), RightHip = A(-30), LeftHip = A(40) } },
			{ 0.8, { Waist = A(-18, 50), RightShoulder = A(95), RightElbow = A(0), LeftShoulder = A(-35) } },
			{ 1.1, {} },
		},
	},
}
Tracks.BlockEnd = { Duration = 0, Keys = { { 0, {} } } } -- สัญญาณเลิกค้างท่าบล็อก ไม่มีท่าของตัวเอง

local ULT_GUARDED_KINDS = { Counter = true, Deflect = true }

-- แปลงชื่อท่าจาก server เป็น Track (สกิลใช้ "<Style>_<Key>" แล้วแมปตามประเภทสกิล)
local function trackFor(name: string): Track?
	if Tracks[name] then
		return Tracks[name]
	end
	local styleId, key = name:match("^(%w+)_(%w+)$")
	local style = styleId and StyleData.Styles[styleId]
	if not style then
		return nil
	end
	if key == "Ultimate" then
		return Tracks.Skill_Ultimate
	end
	local skill = (style.Skills :: any)[key]
	if skill then
		return Tracks["Skill_" .. skill.Kind] or Tracks.Skill_Melee
	end
	return nil
end

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

local function evaluate(track: Track, t: number): Pose?
	local keys = track.Keys
	local last = keys[#keys]
	if t >= (last[1] :: number) then
		return if track.Hold then (last[2] :: Pose) else nil
	end
	for i = 2, #keys do
		local k1, k2 = keys[i - 1], keys[i]
		local t1, t2 = k1[1] :: number, k2[1] :: number
		if t <= t2 then
			local alpha = smooth((t - t1) / math.max(t2 - t1, 1e-4))
			local p1, p2 = k1[2] :: Pose, k2[2] :: Pose
			local out: Pose = {}
			for joint, cf in p1 do
				out[joint] = cf:Lerp(p2[joint] or CFrame.identity, alpha)
			end
			for joint, cf in p2 do
				if not p1[joint] then
					out[joint] = CFrame.identity:Lerp(cf, alpha)
				end
			end
			return out
		end
	end
	return nil
end

local motorCache: { [Model]: { [string]: Motor6D | AnimationConstraint } } = {}
local function motorsOf(character: Model): { [string]: Motor6D | AnimationConstraint }
	local cached = motorCache[character]
	if cached then
		return cached
	end
	local map: { [string]: Motor6D | AnimationConstraint } = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			map[d.Name] = d
		end
	end
	motorCache[character] = map
	return map
end

local active: { [Model]: { Track: Track, Start: number, Name: string } } = {}

local function flash(character: Model)
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromHex("EF233C")
	h.FillTransparency = 0.45
	h.OutlineTransparency = 1
	h.Parent = character
	task.delay(0.12, function()
		h:Destroy()
	end)
end

local function start(character: Model, name: string)
	local base = name
	local id = Assets.Animations[base]
	if id and id ~= 0 then
		return -- มี asset จริงแล้ว ให้ AnimationPlayer เล่น
	end
	if name == "BlockEnd" then
		local cur = active[character]
		if cur and cur.Name == "Block" then
			active[character] = nil
		end
		return
	end
	local track = trackFor(name)
	if track then
		active[character] = { Track = track, Start = os.clock(), Name = name }
		if name == "Hit" or name == "Knockdown" then
			flash(character)
		end
	end
end

-- ต้อง Bind หลัง Animator อัปเดต ไม่งั้น Transform ที่เขียนจะถูกทับ (RenderStepped:Connect ถูกทับทุกเฟรม)
RunService:BindToRenderStep("ProceduralAnim", Enum.RenderPriority.Character.Value + 1, function()
	local now = os.clock()
	for character, act in active do
		if not character.Parent then
			active[character] = nil
			motorCache[character] = nil
		else
			local pose = evaluate(act.Track, now - act.Start)
			if not pose then
				active[character] = nil
			else
				local motors = motorsOf(character)
				for joint, offset in pose do
					local m = motors[joint]
					if m then
						m.Transform = m.Transform * offset
					end
				end
			end
		end
	end
end)

local watched: { [Model]: boolean } = {}
local function watch(character: Model)
	if watched[character] then
		return
	end
	watched[character] = true
	character:GetAttributeChangedSignal("Anim"):Connect(function()
		local value = character:GetAttribute("Anim")
		if typeof(value) == "string" then
			start(character, (value:split(":")[1]))
		end
	end)
end

local function watchPlayer(player: Player)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

for _, p in Players:GetPlayers() do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)

for _, folderName in { "Npcs", "Bosses" } do
	task.spawn(function()
		local f = workspace:WaitForChild(folderName, 30)
		if f then
			for _, c in f:GetChildren() do
				if c:IsA("Model") then
					watch(c)
				end
			end
			f.ChildAdded:Connect(function(c)
				if c:IsA("Model") then
					watch(c)
				end
			end)
		end
	end)
end
