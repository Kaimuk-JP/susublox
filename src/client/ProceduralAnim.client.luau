--!strict
-- ท่าทางต่อสู้แบบโค้ดล้วน: สร้าง KeyframeSequence ตอนรันเกมจากข้อมูลท่าด้านล่าง แล้ว register ผ่าน KeyframeSequenceProvider
-- เล่นด้วย Animator (Priority Action4) จึงเรนเดอร์จริงทั้ง Motor6D และ AnimationConstraint โดยไม่ต้องมี asset แอนิเมชัน
-- (เขียน Transform ตรง ๆ ไม่เรนเดอร์ใน rig แบบ AnimationConstraint เพราะตำแหน่งชิ้นส่วนมาจาก physics)
-- (ถ้าใส่ asset ID ใน Assets.Animations แล้ว จะข้ามท่านั้นและให้ AnimationPlayer เล่นของจริงแทน)
-- ทิศ: ตัวละครหันหน้า -Z, หมุนรอบ X บวก = แขน/ขายกไปข้างหน้า, รอบ Y บวก = ไหล่ขวาหมุนไปหน้า
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	Skill_Counter = { Duration = 1.3, Keys = { { 0, {} }, { 0.15, guardPose }, { 1, guardPose }, { 1.3, {} } } },
	Skill_Deflect = { Duration = 1.3, Keys = { { 0, {} }, { 0.15, guardPose }, { 1, guardPose }, { 1.3, {} } } },
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


-- ชื่อ joint ในข้อมูลท่า -> ชิ้นส่วนลูกของ joint นั้น (ชื่อ Pose ใน KeyframeSequence ใช้ชื่อชิ้นส่วน)
local JOINT_PART: { [string]: string } = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
}

local PART_PARENT: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
}

-- สร้าง KeyframeSequence จาก Track (ท่าค้างอย่าง Block จะ loop ค้างท่าสุดท้ายจนถูกสั่ง Stop)
local function buildSequence(name: string, track: Track): KeyframeSequence
	local keys = track.Keys
	local looped = track.Hold == true
	local lastTime = track.Duration
	if looped then
		local pose = keys[#keys][2] :: Pose
		keys = { { 0, pose }, { 1, pose } }
		lastTime = 1
	end

	local used: { [string]: boolean } = {}
	for _, key in keys do
		for joint in key[2] :: Pose do
			local part = JOINT_PART[joint]
			if part then
				used[part] = true
			end
		end
	end

	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Priority = Enum.AnimationPriority.Action4
	seq.Loop = looped
	for _, key in keys do
		local pose = key[2] :: Pose
		local kf = Instance.new("Keyframe")
		kf.Time = math.min(key[1] :: number, lastTime)
		local instances: { [string]: Pose } = {}
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		root.Parent = kf
		instances.HumanoidRootPart = root
		-- สร้างพ่อก่อนลูกเสมอ; ข้อต่อที่ท่านี้ไม่ใช้จะไม่ถูกสร้าง (ชิ้นพ่อที่แค่เป็นทางผ่านให้ Weight 0)
		local function make(part: string): Pose
			local existing = instances[part]
			if existing then
				return existing
			end
			local parentPose = make(PART_PARENT[part])
			local p = Instance.new("Pose")
			p.Name = part
			p.EasingStyle = Enum.PoseEasingStyle.Cubic
			p.EasingDirection = Enum.PoseEasingDirection.InOut
			p.Weight = if used[part] then 1 else 0
			p.Parent = parentPose
			instances[part] = p
			return p
		end
		for part in used do
			make(part)
		end
		for joint, cf in pose do
			local part = JOINT_PART[joint]
			if part then
				instances[part].CFrame = cf
			end
		end
		kf.Parent = seq
	end
	return seq
end

local animationIds: { [Track]: string } = {}
local function animationIdFor(name: string, track: Track): string?
	local cached = animationIds[track]
	if cached then
		return cached
	end
	local ok, id = pcall(function()
		return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(buildSequence(name, track))
	end)
	if not ok then
		warn("[ProceduralAnim] register ท่า " .. name .. " ไม่สำเร็จ: " .. tostring(id))
		return nil
	end
	animationIds[track] = id :: string
	return id :: string
end

type CharState = {
	Tracks: { [Track]: AnimationTrack },
	Current: AnimationTrack?,
	CurrentName: string?,
	Blocking: boolean,
}
local states: { [Model]: CharState } = {}

local function stateOf(character: Model): CharState
	local s = states[character]
	if not s then
		s = { Tracks = {}, Current = nil, CurrentName = nil, Blocking = false }
		states[character] = s
		character.Destroying:Once(function()
			states[character] = nil
		end)
	end
	return s :: CharState
end

local function animatorOf(character: Model): Animator?
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 2)
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	return animator :: Animator
end

local function trackOn(character: Model, state: CharState, name: string, track: Track): AnimationTrack?
	local loaded = state.Tracks[track]
	if loaded then
		return loaded
	end
	local animator = animatorOf(character)
	local id = animationIdFor(name, track)
	if not animator or not id then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, loadedTrack = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok then
		warn("[ProceduralAnim] LoadAnimation ไม่สำเร็จ: " .. tostring(loadedTrack))
		return nil
	end
	local animTrack = loadedTrack :: AnimationTrack
	animTrack.Priority = Enum.AnimationPriority.Action4
	animTrack.Looped = track.Hold == true
	state.Tracks[track] = animTrack
	return animTrack
end

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

local function playTrack(character: Model, state: CharState, name: string, track: Track, fade: number): AnimationTrack?
	local animTrack = trackOn(character, state, name, track)
	if not animTrack then
		return nil
	end
	local cur = state.Current
	if cur and cur ~= animTrack then
		cur:Stop(0.05)
	end
	if animTrack.IsPlaying then
		animTrack:Stop(0)
	end
	animTrack:Play(fade)
	state.Current, state.CurrentName = animTrack, name
	return animTrack
end

local function start(character: Model, name: string)
	local id = Assets.Animations[name]
	if id and id ~= 0 then
		return -- มี asset จริงแล้ว ให้ AnimationPlayer เล่น
	end
	local state = stateOf(character)
	if name == "BlockEnd" then
		state.Blocking = false
		if state.CurrentName == "Block" and state.Current then
			state.Current:Stop(0.1)
			state.Current, state.CurrentName = nil, nil
		end
		return
	end
	local track = trackFor(name)
	if not track then
		return
	end
	if name == "Block" then
		state.Blocking = true
		playTrack(character, state, name, track, 0.1)
		return
	end
	if name ~= "BlockHit" then
		state.Blocking = false
	end
	local animTrack = playTrack(character, state, name, track, 0.05)
	if name == "Hit" or name == "Knockdown" then
		flash(character)
	end
	if name == "BlockHit" and animTrack and state.Blocking then
		-- สะดุ้งจากการบล็อกเสร็จแล้วกลับเข้าท่าบล็อกต่อถ้ายังกดค้างอยู่
		animTrack.Stopped:Once(function()
			local blockTrack = trackFor("Block")
			if state.Blocking and state.CurrentName == "BlockHit" and blockTrack then
				playTrack(character, state, "Block", blockTrack, 0.1)
			end
		end)
	end
end

local watched: { [Model]: boolean } = {}
local function watch(character: Model)
	if watched[character] then
		return
	end
	watched[character] = true
	character:GetAttributeChangedSignal("Anim"):Connect(function()
		local value = character:GetAttribute("Anim")
		if typeof(value) == "string" then
			task.spawn(start, character, (value:split(":")[1]))
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
