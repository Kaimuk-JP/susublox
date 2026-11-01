--!strict
-- ท่าเตะของบอทฟุตบอล (SoccerPitch.server): server เพิ่มค่า Attribute "KickSeq" ที่โมเดลบอททุกครั้งที่เตะ
-- ฝั่งผู้เล่นสร้าง KeyframeSequence ตอนรัน (วิธีเดียวกับ ProceduralAnim) แล้วเล่นบน Animator ของบอทนั้น
-- ทิศข้อต่อ: สะโพก X+ = เหวี่ยงขาไปข้างหน้า, เข่า X- = พับหน้าแข้งไปข้างหลัง
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local function A(x: number): CFrame
	return CFrame.Angles(math.rad(x), 0, math.rad(0))
end

-- เวลา, สะโพก (องศา), เข่า (องศา พับไปหลัง), เอวเอนไปข้างหน้า
local FRAMES = {
	{ 0.0, 0, 0, 0 },
	{ 0.10, -28, 55, -4 },
	{ 0.20, 80, 6, 6 },
	{ 0.32, 48, 0, 4 },
	{ 0.50, 0, 0, 0 },
}

local function buildSequence(): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "SoccerKick"
	seq.Priority = Enum.AnimationPriority.Action4
	seq.Loop = false
	for _, f in FRAMES do
		local kf = Instance.new("Keyframe")
		kf.Time = f[1]
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		root.Parent = kf
		local lower = Instance.new("Pose")
		lower.Name = "LowerTorso"
		lower.Weight = 0
		lower.Parent = root
		local upper = Instance.new("Pose")
		upper.Name = "UpperTorso"
		upper.Weight = 1
		upper.CFrame = A(-f[4])
		upper.Parent = lower
		local hip = Instance.new("Pose")
		hip.Name = "RightUpperLeg"
		hip.Weight = 1
		hip.CFrame = A(f[2])
		hip.EasingStyle = Enum.PoseEasingStyle.Cubic
		hip.Parent = lower
		local knee = Instance.new("Pose")
		knee.Name = "RightLowerLeg"
		knee.Weight = 1
		knee.CFrame = A(-f[3])
		knee.Parent = hip
		kf.Parent = seq
	end
	return seq
end

local animId: string? = nil
local tracks: { [Model]: AnimationTrack } = {}

local function play(rig: Model)
	local track = tracks[rig]
	if not track then
		local hum = rig:FindFirstChildOfClass("Humanoid")
		local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 2))
		if not animator then
			return
		end
		if not animId then
			local ok, id = pcall(function()
				return KeyframeSequenceProvider:RegisterKeyframeSequence(buildSequence())
			end)
			if not ok then
				warn("[SoccerAnim] register ท่าเตะไม่สำเร็จ: " .. tostring(id))
				return
			end
			animId = id :: string
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = animId :: string
		local ok, loaded = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		if not ok then
			return
		end
		track = loaded :: AnimationTrack
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = false
		tracks[rig] = track
		rig.Destroying:Once(function()
			tracks[rig] = nil
		end)
	end
	track:Play(0.05)
end

local function watch(inst: Instance)
	if inst:IsA("Model") and inst:GetAttribute("SoccerBot") then
		inst:GetAttributeChangedSignal("KickSeq"):Connect(function()
			play(inst)
		end)
	end
end

workspace.DescendantAdded:Connect(watch)
for _, d in workspace:GetDescendants() do
	watch(d)
end
