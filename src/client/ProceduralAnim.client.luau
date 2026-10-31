--!strict
-- ท่าทางต่อสู้แบบโค้ดล้วน: สร้าง KeyframeSequence ตอนรันเกมจากข้อมูลท่าด้านล่าง แล้ว register ผ่าน KeyframeSequenceProvider
-- เล่นด้วย Animator (Priority Action4) จึงเรนเดอร์จริงทั้ง Motor6D และ AnimationConstraint โดยไม่ต้องมี asset แอนิเมชัน
-- (เขียน Transform ตรง ๆ ไม่เรนเดอร์ใน rig แบบ AnimationConstraint เพราะตำแหน่งชิ้นส่วนมาจาก physics)
-- (ถ้าใส่ asset ID ใน Assets.Animations แล้ว จะข้ามท่านั้นและให้ AnimationPlayer เล่นของจริงแทน)
-- ทิศ (วัดจริงจากอวาตาร์ เทียบ HumanoidRootPart: หน้า = -Z, ขวา = +X, บน = +Y) ผลคาลิเบรตแกนของข้อต่อ AnimationConstraint:
--   ไหล่ X+ = ยกแขนไปข้างหน้า/ขึ้น, Z+ (ขวา) = กางแขนออกข้าง (ซ้ายกลับเครื่องหมาย Y และ Z), Y = บิดแกนแขน
--   ศอก X+ = พับปลายแขนขึ้นมาข้างหน้า, สะโพก X+ = เหวี่ยงขาไปข้างหน้า, เข่า X- = พับหน้าแข้งไปหลังแบบธรรมชาติ
--   เอว X- = โน้มตัวไปข้างหน้า, เอว Y+ = ไหล่ขวาไปข้างหน้า, คอ X+ = หัวไปหลัง, Root เลื่อนได้ด้วย CFrame.new
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

local function sideSign(side: string): number
	return if side == "Right" then 1 else -1
end

local function other(side: string): string
	return if side == "Right" then "Left" else "Right"
end

-- ไหล่: fwd +ยกไปข้างหน้า/-สะบัดไปหลัง, twist บิดแกนแขน (ใช้พับศอกเข้าหาใบหน้า), out กางแขนออกข้างลำตัว
local function shoulder(side: string, fwd: number, twist: number?, out: number?): CFrame
	local s = sideSign(side)
	return A(fwd, s * (twist or 0), s * (out or 0))
end

local function armForward(side: string, deg: number): CFrame
	return shoulder(side, deg)
end

local function armOut(side: string, deg: number): CFrame
	return shoulder(side, 0, 0, deg)
end

-- ศอก: deg +พับปลายแขนขึ้นมาข้างหน้า
local function elbowBend(side: string, deg: number, twist: number?): CFrame
	return A(deg, sideSign(side) * (twist or 0))
end

local function hipForward(deg: number): CFrame
	return A(deg)
end

-- เข่า: deg +พับหน้าแข้งไปข้างหลัง
local function kneeBend(deg: number): CFrame
	return A(-deg)
end

-- เอว: lean +โน้มไปข้างหน้า (ลบ = เอนหลัง), twist +ไหล่ขวาไปข้างหน้า
local function waist(lean: number, twist: number?): CFrame
	return A(-lean, twist)
end

-- คอ: back +หัวไปข้างหลัง, turn หันหน้า
local function neck(back: number, turn: number?): CFrame
	return A(back, turn)
end

-- สะโพกตัวละคร (Root): forward พุ่งไปข้างหน้า (stud), drop ย่อตัวลง (stud), twist บิดรอบแกนตั้ง, back เอนหลัง
local function pelvis(forward: number, drop: number?, twist: number?, back: number?): CFrame
	return CFrame.new(0, -(drop or 0), -forward) * A(back, twist)
end

local function pose(...: Pose): Pose
	local merged: Pose = {}
	for _, part in { ... } do
		for joint, cf in part do
			merged[joint] = cf
		end
	end
	return merged
end

-- ชุดมุมแขนที่ผ่านการวัดตำแหน่งมือจริงแล้ว: { ไหล่ fwd, ไหล่ twist, ไหล่ out, ศอก bend, ศอก twist }
local GUARD = { 53, 35, -14, 78, 5 } -- การ์ดหน้าใบหน้า มือ x ±0.7 สูงระดับคางถึงจมูก ศอกต่ำกว่ามือ
local GUARD_WIND = { 23, 18, 9, 98, 12 } -- มือหลังการ์ดขณะอีกข้างง้างหมัด
local GUARD_STRIKE = { 87, 60, -30, 52, 14 } -- มือหลังการ์ดขณะอีกข้างชก
local WIND = { -67, 10, 4, 115, 14 } -- ง้างหมัดกลับมาข้างลำตัว
local STRIKE = { 82, -4, 0, 8, 1 } -- แขนเหยียดตรงชกไปข้างหน้าระดับไหล่

local function armOf(side: string, angles: { number }): Pose
	return {
		[side .. "Shoulder"] = shoulder(side, angles[1], angles[2], angles[3]),
		[side .. "Elbow"] = elbowBend(side, angles[4], angles[5]),
	}
end

local function legs(hip: number, knee: number): Pose
	return { RightHip = hipForward(hip), LeftHip = hipForward(hip), RightKnee = kneeBend(knee), LeftKnee = kneeBend(knee) }
end

local STANCE = legs(10, 18)

-- ท่ายืนการ์ด: ลำตัวโน้มเล็กน้อย มือทั้งสองอยู่หน้าใบหน้า
local guardPose: Pose = pose(armOf("Right", GUARD), armOf("Left", GUARD), STANCE, { Waist = waist(10), Neck = neck(8) })

-- พุ่งตัวไปข้างหน้าให้เท้าติดพื้น: ขาหลัง(ข้างที่ชก)ถอยหลังเอนเข่า ขาหน้าย่อเข่ารับ
local function lungeStance(side: string, lunge: number): Pose
	local k = lunge / 0.8
	return {
		Root = pelvis(lunge, 0.2 * k),
		[side .. "Hip"] = hipForward(-12),
		[side .. "Knee"] = kneeBend(47 * k),
		[other(side) .. "Hip"] = hipForward(10),
		[other(side) .. "Knee"] = kneeBend(70 * k),
	}
end

-- ท่าง้างหมัดกับท่าชก ของข้าง side (power มากขึ้น = พุ่งตัว/บิดเอว/โน้มตัวมากขึ้น)
local function punchPoses(side: string, power: number): (Pose, Pose)
	local o, s = other(side), sideSign(side)
	local lean, twist, lunge = 8 + 3 * (power - 1), 34 + 6 * (power - 1), 0.65 + 0.15 * power
	local wind: Pose = pose(armOf(side, WIND), armOf(o, GUARD_WIND), STANCE, { Waist = waist(4, -22 * s), Neck = neck(3, 15 * s) })
	local strike: Pose = pose(
		armOf(side, STRIKE),
		armOf(o, GUARD_STRIKE),
		lungeStance(side, lunge),
		{ Waist = waist(lean, twist * s), Neck = neck(lean * 0.8, -twist * 0.7 * s) }
	)
	return wind, strike
end

local function punch(side: string, power: number, duration: number?): Track
	local d = duration or 0.38
	local k = d / 0.38
	local wind, strike = punchPoses(side, power)
	return { Duration = d, Keys = { { 0, {} }, { 0.07 * k, wind }, { 0.14 * k, strike }, { 0.22 * k, strike }, { d, {} } } }
end

-- ถีบขวา: ยกเข่าเข้าหาตัวแล้วเหวี่ยงเท้าตรงไปข้างหน้าระดับเอว ตัวพุ่งตามและขาซ้ายรับน้ำหนัก
local kickChamber: Pose = pose(
	armOf("Right", GUARD),
	armOf("Left", GUARD),
	{ Root = pelvis(0.35, 0.15, 5), Waist = waist(-8), Neck = neck(8), RightHip = hipForward(75), RightKnee = kneeBend(110), LeftHip = hipForward(-5), LeftKnee = kneeBend(15) }
)
local kickStrike: Pose = pose(
	armOf("Right", GUARD),
	armOf("Left", GUARD),
	{ Root = pelvis(1.5, 0, 17.7, 0.6), Waist = waist(0, -9), Neck = neck(0), RightHip = hipForward(109), RightKnee = kneeBend(30), LeftHip = hipForward(-22), LeftKnee = kneeBend(9) }
)

local spinArms: Pose = pose(
	{ RightShoulder = armOut("Right", 75), LeftShoulder = armOut("Left", 75), RightElbow = elbowBend("Right", 5), LeftElbow = elbowBend("Left", 5) },
	STANCE,
	{ Waist = waist(8) }
)

local ultWind, ultStrike = punchPoses("Right", 2.4)
local dashWind, dashStrike = punchPoses("Right", 2.2)

local Tracks: { [string]: Track } = {
	M1_1 = punch("Right", 1),
	M1_2 = punch("Left", 1),
	M1_3 = punch("Right", 1.5),
	M1_4 = {
		-- ถีบปิดคอมโบ
		Duration = 0.5,
		Keys = { { 0, {} }, { 0.1, kickChamber }, { 0.2, kickStrike }, { 0.3, kickStrike }, { 0.5, {} } },
	},
	Block = { Duration = 0.1, Hold = true, Keys = { { 0, {} }, { 0.1, guardPose } } },
	BlockHit = {
		Duration = 0.18,
		Keys = {
			{ 0, guardPose },
			{ 0.05, pose(guardPose, { Root = pelvis(-0.2), Waist = waist(2), Neck = neck(4) }) },
			{ 0.18, guardPose },
		},
	},
	Dash = {
		Duration = 0.4,
		Keys = (function()
			local lean: Pose = {
				Root = pelvis(0.25, 0.1),
				Waist = waist(32),
				Neck = neck(20),
				RightShoulder = armForward("Right", -50),
				LeftShoulder = armForward("Left", -50),
				RightElbow = elbowBend("Right", 25),
				LeftElbow = elbowBend("Left", 25),
			}
			return {
				{ 0, {} },
				{ 0.06, pose(lean, { RightHip = hipForward(30), LeftHip = hipForward(-20), RightKnee = kneeBend(40) }) },
				{ 0.2, pose(lean, { RightHip = hipForward(-20), LeftHip = hipForward(40), LeftKnee = kneeBend(40) }) },
				{ 0.4, {} },
			}
		end)(),
	},
	Hit = {
		-- สะดุ้งโดนตี: ลำตัวเอนหลังเล็กน้อย แขนสะบัดไปหลัง
		Duration = 0.3,
		Keys = {
			{ 0, {} },
			{
				0.05,
				{
					Root = pelvis(-0.05, 0, 0, 4),
					Waist = waist(-8),
					Neck = neck(6),
					RightShoulder = armForward("Right", -25),
					LeftShoulder = armForward("Left", -25),
					RightElbow = elbowBend("Right", 20),
					LeftElbow = elbowBend("Left", 20),
				},
			},
			{ 0.3, {} },
		},
	},
	Knockdown = {
		-- ล้มหงายแล้วลุกขึ้น
		Duration = 1.3,
		Keys = (function()
			local down: Pose = {
				Root = pelvis(0.3, 1.95, 0, 78),
				RightShoulder = shoulder("Right", -20, 0, 35),
				LeftShoulder = shoulder("Left", -20, 0, 35),
				Neck = neck(15),
			}
			return { { 0, {} }, { 0.18, down }, { 0.9, down }, { 1.3, {} } }
		end)(),
	},
	Skill_Melee = punch("Right", 1.8),
	Skill_Dash = {
		Duration = 0.55,
		Keys = { { 0, {} }, { 0.08, dashWind }, { 0.2, dashStrike }, { 0.32, dashStrike }, { 0.55, {} } },
	},
	Skill_AoE = {
		-- หมุนตัวฟาดรอบ (หมุนต่อเนื่องทีละ 120 องศาเพื่อให้ได้เต็มรอบ)
		Duration = 0.6,
		Keys = {
			{ 0, {} },
			{ 0.1, pose(spinArms, { Root = A(0, -50) }) },
			{ 0.23, pose(spinArms, { Root = A(0, -170) }) },
			{ 0.36, pose(spinArms, { Root = A(0, -290) }) },
			{ 0.5, pose(spinArms, { Root = A(0, -410) }) },
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
				local _, strike = punchPoses(if i % 2 == 1 then "Right" else "Left", 0.7)
				table.insert(keys, { t, strike })
				t += 0.13
			end
			table.insert(keys, { 1.3, {} })
			return keys
		end)(),
	},
	Skill_Counter = { Duration = 1.3, Keys = { { 0, {} }, { 0.15, guardPose }, { 1, guardPose }, { 1.3, {} } } },
	Skill_Deflect = { Duration = 1.3, Keys = { { 0, {} }, { 0.15, guardPose }, { 1, guardPose }, { 1.3, {} } } },
	Skill_Teleport = {
		Duration = 0.4,
		Keys = { { 0, {} }, { 0.1, pose(legs(55, 95), { Root = pelvis(0, 0.45), Waist = waist(25), Neck = neck(15) }) }, { 0.4, {} } },
	},
	Skill_Charge = (function()
		local charge: Pose = pose(
			{ RightShoulder = armForward("Right", 75), LeftShoulder = armForward("Left", 75), RightElbow = elbowBend("Right", 25), LeftElbow = elbowBend("Left", 25) },
			legs(15, 30),
			{ Waist = waist(20, 10), Neck = neck(15, -7) }
		)
		return { Duration = 0.6, Keys = { { 0, {} }, { 0.1, charge }, { 0.45, charge }, { 0.6, {} } } }
	end)(),
	Skill_Grapple = (function()
		local reach: Pose = pose(
			{ RightShoulder = armForward("Right", 88), LeftShoulder = armForward("Left", 88), RightElbow = elbowBend("Right", 8), LeftElbow = elbowBend("Left", 8) },
			legs(15, 30),
			{ Root = pelvis(0.4, 0.1), Waist = waist(14), Neck = neck(8) }
		)
		return { Duration = 0.6, Keys = { { 0, {} }, { 0.12, reach }, { 0.4, pose(reach, { Waist = waist(24), Neck = neck(18) }) }, { 0.6, {} } } }
	end)(),
	Skill_Ultimate = {
		-- ชาร์จพลังแล้วปล่อยหมัดเต็มแรง
		Duration = 1.1,
		Keys = { { 0, {} }, { 0.4, ultWind }, { 0.52, ultStrike }, { 0.8, ultStrike }, { 1.1, {} } },
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

-- เฉพาะ Studio: ตั้ง attribute "PADebug" = "<ชื่อท่า>:<เวลา>" บนตัวละครเพื่อค้างท่า ณ เวลานั้น (ใช้วัดตำแหน่งแขนขาที่เรนเดอร์จริง)
local function debugHold(character: Model, spec: string)
	local name, at = table.unpack(spec:split(":"))
	local track = trackFor(name)
	local state = stateOf(character)
	for _, loaded in state.Tracks do
		loaded:Stop(0)
	end
	local animTrack = track and playTrack(character, state, name, track, 0)
	if animTrack then
		animTrack:AdjustSpeed(0)
		animTrack.TimePosition = tonumber(at) or 0
	end
end

local watched: { [Model]: boolean } = {}
local function watch(character: Model)
	if watched[character] then
		return
	end
	watched[character] = true
	if RunService:IsStudio() then
		character:GetAttributeChangedSignal("PADebug"):Connect(function()
			local spec = character:GetAttribute("PADebug")
			if typeof(spec) == "string" then
				task.spawn(debugHold, character, spec)
			end
		end)
	end
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
