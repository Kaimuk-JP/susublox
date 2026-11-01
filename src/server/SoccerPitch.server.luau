--!strict
-- แมตช์ฟุตบอล 4v4 ของบอทบนสนามโรงเรียน (Field จาก PitchKit): ลูกบอลฟิสิกส์จริงที่ server เป็นเจ้าของ + AI ง่าย ๆ
-- (ไล่บอล เลี้ยง ส่ง ยิง ผู้รักษาประตูยืนตำแหน่ง/ดาย/ปัด) ครึ่งละ 5 นาที สลับข้าง จบแล้วเริ่มใหม่
-- สร้างบอท/ลูกบอลเมื่อมีผู้เล่นอยู่ในระยะ SPAWN_R และลบทิ้งเมื่อไม่มีใครอยู่ในระยะ DESPAWN_R นาน 8 วินาที (ประหยัดเครื่อง)
-- บอทไม่สนใจผู้เล่นและไม่ใช่ศัตรู (ไม่ผ่าน Combat/NpcService); ผู้เล่นเตะบอลได้ด้วยการวิ่งชน หรือกด E (ProximityPrompt "เตะบอล")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RigFactory = require(script.Parent.RigFactory)
local PitchKit = require(script.Parent.PitchKit)

local L = PitchKit.Layout
local CX, CZ = L.CX, L.CZ

local SPAWN_R, DESPAWN_R = 250, 290
local HALF_TIME = 300
local RUN_SPEED = 14
local BALL_D = 1.6
local BALL_R = BALL_D / 2
local ANTIGRAV = 0.55 -- ลดแรงโน้มถ่วงที่ลูกบอลเป็น 45% ให้ลอยนุ่มแบบฟุตบอล (g=196 ปกติตกเร็วเกิน)
local G_EFF = workspace.Gravity * (1 - ANTIGRAV)
local MAX_BALL_SPEED = 72
local KICK_RANGE = 3.4
local hex = Color3.fromHex
local rng = Random.new()

local KITS = {
	Home = { shirt = hex("F2F2EE"), shorts = hex("2F5FA0"), socks = hex("2F5FA0"), num = hex("2F5FA0"), gk = hex("3E8E50") },
	Away = { shirt = hex("C93A30"), shorts = hex("E3C13B"), socks = hex("C93A30"), num = hex("E3C13B"), gk = hex("7A4E9A") },
}
-- ตำแหน่งตั้งต้นสัมพัทธ์ทีม: u = ระยะจากกลางสนามไปทางประตูคู่แข่ง (ลบ = ฝั่งตัวเอง), v = ซ้าย/ขวา
local FORMATION = {
	{ Role = "GK", U = -33.5, V = 0, Numbers = { Home = 1, Away = 1 } },
	{ Role = "DEF", U = -17, V = 0, Numbers = { Home = 4, Away = 5 } },
	{ Role = "MID", U = -3, V = -11, Numbers = { Home = 8, Away = 7 } },
	{ Role = "FWD", U = 13, V = 11, Numbers = { Home = 9, Away = 10 } },
}

type Bot = {
	Model: Model,
	Root: BasePart,
	Hum: Humanoid,
	Team: string,
	Role: string,
	U: number,
	V: number,
	KickCd: number,
	Kicking: boolean,
	DiveCd: number,
	Diving: boolean,
	LastPos: Vector3,
	Stuck: number,
}

---------------------------------------------------------------- สถานะแมตช์
local field: Folder
local active = false
local spawning = false
local container: Folder? = nil
local ball: Part? = nil
local bots: { Bot } = {}
local attackDir = { Home = 1, Away = -1 }
local score = { Home = 0, Away = 0 }
local half = 1
local timeLeft = HALF_TIME
local phase = "Play" -- Play | Goal | HalfTime | FullTime
local phaseUntil = 0
local chaser: { [string]: Bot? } = {}
local lastTouch: Bot? = nil
local outSince = 0
local aiAcc = 0
local clockAcc = 0
local stats = { Goals = 0, Kicks = 0, Passes = 0, Shots = 0, Dives = 0, Unstuck = 0, OutResets = 0, PlayerKicks = 0 }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function pushStats()
	local c = container
	if not c then
		return
	end
	for k, v in stats do
		c:SetAttribute(k, v)
	end
	c:SetAttribute("Score", string.format("%d-%d", score.Home, score.Away))
	c:SetAttribute("Half", half)
	c:SetAttribute("Phase", phase)
end

---------------------------------------------------------------- กระดานคะแนน
local function setBoard(name: string, text: string)
	local stand = field:FindFirstChild("ScoreboardStand")
	local gui = stand and stand:FindFirstChild("Scoreboard") and (stand :: any).Scoreboard:FindFirstChild("ScoreGui")
	local label = gui and gui:FindFirstChild(name)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function updateBoard(status: string?)
	setBoard("HomeScore", tostring(score.Home))
	setBoard("AwayScore", tostring(score.Away))
	local t = math.max(0, math.ceil(timeLeft))
	setBoard("Clock", string.format("%02d:%02d", t // 60, t % 60))
	setBoard("Status", status or (if half == 1 then "1st HALF" else "2nd HALF"))
	setBoard("Half", if phase == "Play" then "LIVE" else "")
end

---------------------------------------------------------------- ลูกบอล
local function clampBall(b: Part)
	local v = b.AssemblyLinearVelocity
	if v.Magnitude > MAX_BALL_SPEED then
		b.AssemblyLinearVelocity = v.Unit * MAX_BALL_SPEED
	end
end

local function setBallVelocity(vel: Vector3)
	local b = ball
	if not b then
		return
	end
	b.AssemblyLinearVelocity = vel
	b.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
	clampBall(b)
end

local playerKickCd: { [Player]: number } = {}

local function playerFromPart(part: Instance): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model) or nil
end

local function makeBall(parent: Instance): Part
	local b = Instance.new("Part")
	b.Name = "SoccerBall"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.one * BALL_D
	b.Color = hex("F4F4F0")
	b.Material = Enum.Material.SmoothPlastic
	b.TopSurface = Enum.SurfaceType.Smooth
	b.BottomSurface = Enum.SurfaceType.Smooth
	b.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.6, 0.55, 1, 1)
	b.CollisionGroup = "PitchBall"
	b.Position = Vector3.new(CX, L.Floor + 2, CZ)
	-- แผ่นดำ 12 จุดแบบลูกบอลห้าเหลี่ยม (จุดยอด icosahedron)
	local phi = (1 + math.sqrt(5)) / 2
	local dirs: { Vector3 } = {}
	for _, a in { -1, 1 } do
		for _, c in { -phi, phi } do
			table.insert(dirs, Vector3.new(0, a, c).Unit)
			table.insert(dirs, Vector3.new(a, c, 0).Unit)
			table.insert(dirs, Vector3.new(c, 0, a).Unit)
		end
	end
	local seen: { Vector3 } = {}
	for _, n in dirs do
		local dup = false
		for _, s in seen do
			if (s - n).Magnitude < 0.1 then
				dup = true
			end
		end
		if not dup then
			table.insert(seen, n)
			local patch = Instance.new("Part")
			patch.Name = "Patch"
			patch.Shape = Enum.PartType.Cylinder
			patch.Size = Vector3.new(0.06, 0.6, 0.6)
			patch.Color = hex("1A1A1C")
			patch.Material = Enum.Material.SmoothPlastic
			patch.CanCollide, patch.CanQuery, patch.CanTouch, patch.Massless = false, false, false, true
			local cf = CFrame.lookAt(b.Position + n * (BALL_R - 0.02), b.Position + n * 5) * CFrame.Angles(0, math.rad(90), 0)
			patch.CFrame = cf
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = b, patch
			w.Parent = patch
			patch.Parent = b
		end
	end
	local att = Instance.new("Attachment")
	att.Parent = b
	local vf = Instance.new("VectorForce")
	vf.Attachment0 = att
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.ApplyAtCenterOfMass = true
	vf.Force = Vector3.new(0, b.AssemblyMass * workspace.Gravity * ANTIGRAV, 0)
	vf.Parent = b
	b.Parent = parent
	pcall(function()
		b:SetNetworkOwner(nil)
	end)
	-- ผู้เล่นเตะบอล: กด E ใกล้บอล
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "ลูกฟุตบอล"
	prompt.ActionText = "เตะบอล"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = b
	prompt.Triggered:Connect(function(player: Player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local now = os.clock()
		if not root or (playerKickCd[player] or 0) > now or (root.Position - b.Position).Magnitude > 14 then
			return
		end
		playerKickCd[player] = now + 0.3
		local dir = flat(root.CFrame.LookVector)
		if dir.Magnitude < 0.1 then
			return
		end
		stats.PlayerKicks += 1
		lastTouch = nil
		setBallVelocity(dir.Unit * 46 + Vector3.new(0, 11, 0))
	end)
	-- ผู้เล่นวิ่งชน: ส่งแรงตามความเร็วของตัวละคร (รูปแบบเดียวกับ Combat.Impulse แต่กับลูกบอล)
	b.Touched:Connect(function(other: BasePart)
		local player = playerFromPart(other)
		if not player then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local now = os.clock()
		if not root or (playerKickCd[player] or 0) > now then
			return
		end
		local rv = flat(root.AssemblyLinearVelocity)
		if rv.Magnitude < 5 then
			return
		end
		playerKickCd[player] = now + 0.2
		stats.PlayerKicks += 1
		lastTouch = nil
		setBallVelocity(rv.Unit * math.clamp(rv.Magnitude * 1.5, 12, 40) + Vector3.new(0, 3, 0))
	end)
	return b
end

---------------------------------------------------------------- บอท
-- ท่าเตะ: rig เป็น AnimationConstraint (C0 แก้ไม่ได้) จึงส่งสัญญาณผ่าน Attribute KickSeq ให้ SoccerAnim.client เล่นท่าเตะแบบ KeyframeSequence
local function kickAnim(b: Bot)
	if b.Kicking then
		return
	end
	b.Kicking = true
	b.Model:SetAttribute("KickSeq", ((b.Model:GetAttribute("KickSeq") :: number?) or 0) + 1)
	task.delay(0.45, function()
		b.Kicking = false
	end)
end

-- ฉลองประตู: ท่า cheer มาตรฐานของ Roblox (R15) + กระโดด 3 ครั้ง
local CHEER_ID = "rbxassetid://507770677"
local function celebrate(b: Bot)
	task.spawn(function()
		local animator = b.Hum:FindFirstChildOfClass("Animator")
		local track: AnimationTrack? = nil
		if animator then
			local anim = Instance.new("Animation")
			anim.AnimationId = CHEER_ID
			local ok, t = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and t then
				track = t
				t.Priority = Enum.AnimationPriority.Action2
				t.Looped = true
				t:Play(0.2)
			end
		end
		for _ = 1, 3 do
			if b.Hum.Parent then
				b.Hum.Jump = true
			end
			task.wait(0.8)
		end
		if track then
			track:Stop(0.3)
		end
	end)
end

local function dress(rig: Model, kit: typeof(KITS.Home), isGK: boolean, number: number)
	local function col(name: string, c: Color3)
		local p = rig:FindFirstChild(name) :: BasePart?
		if p then
			p.Color = c
		end
	end
	local shirt = if isGK then kit.gk else kit.shirt
	local shorts = if isGK then hex("1E1E22") else kit.shorts
	local socks = if isGK then hex("1E1E22") else kit.socks
	col("UpperTorso", shirt)
	col("LowerTorso", shorts)
	for _, s in { "Left", "Right" } do
		col(s .. "UpperArm", shirt)
		col(s .. "UpperLeg", shorts)
		col(s .. "LowerLeg", socks)
		col(s .. "Foot", hex("151517"))
		if isGK then
			col(s .. "Hand", hex("D8E04A"))
		end
	end
	local torso = rig:FindFirstChild("UpperTorso") :: BasePart?
	if torso then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0.5
		gui.Parent = torso
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(0.7, 0.62)
		t.Position = UDim2.fromScale(0.15, 0.12)
		t.BackgroundTransparency = 1
		t.Text = tostring(number)
		t.TextColor3 = if isGK then hex("F2F2EE") else kit.num
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Parent = gui
	end
end

local function loadRunAnim(b: Bot)
	task.spawn(function()
		local animator = b.Hum:WaitForChild("Animator", 5) :: Animator?
		if not animator then
			return
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://507767714"
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if not ok or not track then
			return
		end
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		b.Hum.Running:Connect(function(speed: number)
			if speed > 8 then
				track:AdjustSpeed(math.clamp(speed / 15, 0.6, 1.3))
				if not track.IsPlaying then
					track:Play(0.15)
				end
			elseif track.IsPlaying then
				track:Stop(0.2)
			end
		end)
	end)
end

local function worldSpot(team: string, u: number, v: number): Vector3
	local d = attackDir[team]
	return Vector3.new(CX + d * u, L.Floor + 0.5, CZ + d * v)
end

local function makeBot(team: string, def: any, parent: Instance): Bot?
	local isGK = def.Role == "GK"
	local kit = (KITS :: any)[team]
	local pos = worldSpot(team, def.U, def.V) + Vector3.new(0, 3, 0)
	local rig = RigFactory.Create("Footballer", pos, parent, { SoccerBot = true, Team = team }, if isGK then kit.gk else kit.shirt, "footballer")
	if not rig then
		return nil
	end
	local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	hum.WalkSpeed = RUN_SPEED
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	dress(rig, kit, isGK, def.Numbers[team])
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local bot: Bot = {
		Model = rig,
		Root = root,
		Hum = hum,
		Team = team,
		Role = def.Role,
		U = def.U,
		V = def.V,
		KickCd = 0,
		Kicking = false,
		DiveCd = 0,
		Diving = false,
		LastPos = root.Position,
		Stuck = 0,
	}
	loadRunAnim(bot)
	return bot
end

local function faceSpot(team: string): CFrame -- หันไปทางประตูคู่แข่ง
	return CFrame.Angles(0, if attackDir[team] == 1 then math.rad(-90) else math.rad(90), 0)
end

local function kickoff()
	for _, b in bots do
		local spot = worldSpot(b.Team, math.min(b.U, -1.5), b.V) + Vector3.new(0, 3, 0)
		b.Model:PivotTo(CFrame.new(spot) * faceSpot(b.Team))
		b.Root.AssemblyLinearVelocity = Vector3.zero
		b.Hum.PlatformStand = false
		b.Hum:MoveTo(spot)
		b.KickCd = os.clock() + 0.5
	end
	if ball then
		ball.CFrame = CFrame.new(CX, L.Floor + 1.5, CZ)
		ball.AssemblyLinearVelocity = Vector3.zero
		ball.AssemblyAngularVelocity = Vector3.zero
	end
	chaser = {}
	outSince = 0
end

---------------------------------------------------------------- ตัดสินใจของบอท
local function nearestOpponentDist(team: string, pos: Vector3): (number, Vector3?)
	local best, bp = math.huge, nil
	for _, o in bots do
		if o.Team ~= team then
			local d = (flat(o.Root.Position) - flat(pos)).Magnitude
			if d < best then
				best, bp = d, o.Root.Position
			end
		end
	end
	return best, bp
end

local function doKick(b: Bot, vel: Vector3, face: Vector3)
	local f = flat(face)
	if f.Magnitude > 0.1 then
		b.Root.CFrame = CFrame.lookAt(b.Root.Position, b.Root.Position + f)
	end
	kickAnim(b)
	setBallVelocity(vel)
	lastTouch = b
	stats.Kicks += 1
end

local function act(b: Bot, bp: Vector3)
	local now = os.clock()
	if b.KickCd > now then
		return
	end
	local d = attackDir[b.Team]
	local goalX = CX + d * L.HL
	local pos = b.Root.Position
	local distGoal = math.abs(goalX - pos.X)
	local opponentD, opponentPos = nearestOpponentDist(b.Team, pos)
	-- ยิง
	if distGoal < 27 and rng:NextNumber() < 0.75 then
		local target = Vector3.new(goalX + d * 1, 0, CZ + rng:NextNumber(-1, 1) * (L.GoalW / 2 + 2))
		local dir = flat(target - bp)
		local dist = dir.Magnitude
		local speed = rng:NextNumber(48, 66)
		local t = math.max(dist / speed, 0.1)
		local vy = 0
		if rng:NextNumber() > 0.4 then
			local yT = rng:NextNumber(0.8, 5.5)
			vy = math.clamp((yT - (L.Floor + BALL_R) + 0.5 * G_EFF * t * t) / t, 0, 40)
		end
		stats.Shots += 1
		b.KickCd = now + 0.9
		doKick(b, dir.Unit * speed + Vector3.new(0, vy, 0), dir)
		return
	end
	-- ส่งให้เพื่อนที่ว่างและอยู่ข้างหน้า
	if rng:NextNumber() < 0.45 then
		local bestScore, bestMate = -math.huge, nil :: Bot?
		for _, m in bots do
			if m ~= b and m.Team == b.Team and m.Role ~= "GK" then
				local md = (flat(m.Root.Position) - flat(pos)).Magnitude
				if md > 8 and md < 38 then
					local free = nearestOpponentDist(b.Team, m.Root.Position)
					local progress = d * (m.Root.Position.X - pos.X)
					local s = progress * 0.8 + math.min(free, 14) * 0.7 - md * 0.1
					if s > bestScore then
						bestScore, bestMate = s, m
					end
				end
			end
		end
		if bestMate and bestScore > 0 then
			local md = (flat(bestMate.Root.Position) - flat(pos)).Magnitude
			local aim = bestMate.Root.Position + flat(bestMate.Root.AssemblyLinearVelocity) * math.min(0.5, md / 40)
			local dir = flat(aim - bp)
			if dir.Magnitude > 1 then
				stats.Passes += 1
				b.KickCd = now + 0.6
				doKick(b, dir.Unit * math.clamp(md * 1.4 + 10, 20, 48) + Vector3.new(0, 2 + md * 0.05, 0), dir)
				return
			end
		end
	end
	-- เลี้ยงบอลไปทางประตู หลบฝ่ายตรงข้ามใกล้ ๆ
	local toGoal = flat(Vector3.new(goalX, 0, CZ) - pos)
	local dir = toGoal.Unit
	if opponentPos and opponentD < 8 then
		local away = flat(pos - opponentPos)
		if away.Magnitude > 0.1 then
			dir = (dir + away.Unit * 0.9).Unit
		end
	end
	b.KickCd = now + 0.35
	doKick(b, dir * 15 + Vector3.new(0, 0.5, 0), dir)
end

local function goalkeeper(b: Bot, bp: Vector3, bv: Vector3)
	local d = attackDir[b.Team]
	local gx = CX - d * 33.5
	local ownGoalX = CX - d * L.HL
	local pos = b.Root.Position
	local now = os.clock()
	local targetZ = CZ + math.clamp((bp.Z - CZ) * 0.3, -7, 7)
	local targetX = gx
	local towardGoal = (bv.X * -d) > 6 -- ความเร็วของบอลมุ่งหาประตูตัวเอง
	if towardGoal and math.abs(bp.X - ownGoalX) < 30 then
		local tHit = (gx - bp.X) / bv.X
		if tHit > 0 and tHit < 2 then
			local zPred = bp.Z + bv.Z * tHit
			targetZ = CZ + math.clamp(zPred - CZ, -9, 9)
			-- ดายเมื่อบอลแรงและห่างจากตัวเกินเอื้อม
			local gap = targetZ - pos.Z
			if bv.Magnitude > 22 and tHit < 0.5 and math.abs(gap) > 2.8 and math.abs(gap) < 10 and b.DiveCd < now and not b.Diving then
				b.Diving, b.DiveCd = true, now + 3
				stats.Dives += 1
				b.Hum.PlatformStand = true
				b.Root.AssemblyLinearVelocity = Vector3.new(0, 14, math.sign(gap) * 22)
				b.Root.AssemblyAngularVelocity = Vector3.new(math.sign(gap) * 5, 0, 0)
				task.delay(0.3, function()
					b.Root.AssemblyAngularVelocity = Vector3.zero
				end)
				task.delay(1.0, function()
					if b.Hum.Parent then
						local p = b.Root.Position
						b.Root.AssemblyLinearVelocity = Vector3.zero
						b.Root.AssemblyAngularVelocity = Vector3.zero
						b.Model:PivotTo(CFrame.new(p.X, L.Floor + 3, p.Z) * faceSpot(b.Team))
						b.Hum.PlatformStand = false
						b.Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
					end
					b.Diving = false
				end)
			end
		end
	end
	if b.Diving then
		return
	end
	-- ปัดออก/เตะทิ้งเมื่อบอลอยู่ในมือ
	local flatDist = (flat(bp) - flat(pos)).Magnitude
	if flatDist < 3.6 and bp.Y < 4.5 and b.KickCd < now then
		local target = Vector3.new(CX + d * rng:NextNumber(-2, 10), 0, CZ + rng:NextNumber(-16, 16))
		local dir = flat(target - bp)
		b.KickCd = now + 1
		doKick(b, dir.Unit * 38 + Vector3.new(0, 14, 0), dir)
		return
	end
	b.Hum:MoveTo(Vector3.new(targetX, L.Floor + 0.5, targetZ))
end

local function chooseChasers(bp: Vector3)
	for _, team in { "Home", "Away" } do
		local best, bestD = nil :: Bot?, math.huge
		local cur = chaser[team]
		local curD = math.huge
		for _, b in bots do
			if b.Team == team and b.Role ~= "GK" and not b.Diving then
				local dist = (flat(b.Root.Position) - flat(bp)).Magnitude
				if dist < bestD then
					best, bestD = b, dist
				end
				if b == cur then
					curD = dist
				end
			end
		end
		chaser[team] = if cur and curD <= bestD + 3 then cur else best
	end
end

local function outfield(b: Bot, bp: Vector3, bv: Vector3)
	local pos = b.Root.Position
	if chaser[b.Team] == b then
		local dist = (flat(bp) - flat(pos)).Magnitude
		if dist < KICK_RANGE and bp.Y < 3.6 then
			act(b, bp)
		end
		local lead = flat(bv) * math.min(0.4, dist / 40)
		local target = bp + lead
		target = Vector3.new(math.clamp(target.X, CX - L.HL - 1, CX + L.HL + 1), L.Floor + 0.5, math.clamp(target.Z, CZ - L.HW - 1, CZ + L.HW + 1))
		b.Hum:MoveTo(target)
		return
	end
	local d = attackDir[b.Team]
	local ballU = d * (bp.X - CX)
	local ballV = d * (bp.Z - CZ)
	local u = math.clamp(b.U + math.clamp(ballU * 0.5, -10, 14), -31, 31)
	local v = math.clamp(b.V + ballV * 0.35, -22, 22)
	b.Hum:MoveTo(worldSpot(b.Team, u, v))
end

local function keepInside(b: Bot)
	local p = b.Root.Position
	local lx, lz = L.GrassHX - 1.5, L.GrassHZ - 1.5
	if math.abs(p.X - CX) > lx or math.abs(p.Z - CZ) > lz or p.Y < -5 or p.Y > 30 then
		b.Model:PivotTo(CFrame.new(CX + math.clamp(p.X - CX, -lx, lx), L.Floor + 3, CZ + math.clamp(p.Z - CZ, -lz, lz)) * faceSpot(b.Team))
		b.Root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function aiTick()
	local b = ball
	if not b then
		return
	end
	local bp, bv = b.Position, b.AssemblyLinearVelocity
	chooseChasers(bp)
	for _, bot in bots do
		if bot.Hum.Parent and not bot.Diving then
			keepInside(bot)
			if bot.Role == "GK" then
				goalkeeper(bot, bp, bv)
			else
				outfield(bot, bp, bv)
			end
		end
	end
end

local function unstickTick()
	local b = ball
	if not b then
		return
	end
	for _, bot in bots do
		if chaser[bot.Team] == bot and not bot.Diving then
			local moved = (bot.Root.Position - bot.LastPos).Magnitude
			local dist = (flat(b.Position) - flat(bot.Root.Position)).Magnitude
			if moved < 0.8 and dist > 5 then
				bot.Stuck += 1
				if bot.Stuck >= 2 then
					stats.Unstuck += 1
					bot.Stuck = 0
					local toward = flat(b.Position - bot.Root.Position)
					if toward.Magnitude > 0.1 then
						bot.Model:PivotTo(bot.Root.CFrame + toward.Unit * 3 + Vector3.new(0, 1, 0))
					end
				else
					bot.Hum.Jump = true
				end
			else
				bot.Stuck = 0
			end
		end
		bot.LastPos = bot.Root.Position
	end
end

---------------------------------------------------------------- เกม: ประตู ครึ่งเวลา รีเซ็ต
local function startPhase(name: string, seconds: number, status: string)
	phase = name
	phaseUntil = os.clock() + seconds
	updateBoard(status)
	pushStats()
end

local function onGoal(team: string)
	score[team] += 1
	stats.Goals += 1
	for _, bot in bots do
		bot.Hum:MoveTo(bot.Root.Position)
		if bot.Team == team then
			celebrate(bot)
		end
	end
	startPhase("Goal", 5, "GOAL!")
end

local function checkGoal(b: Part)
	local p = b.Position
	for _, team in { "Home", "Away" } do
		local d = attackDir[team]
		local line = CX + d * L.HL
		if (p.X - line) * d > BALL_R and math.abs(p.Z - CZ) < L.GoalW / 2 - 0.5 and p.Y < L.Floor + L.GoalH - 0.3 then
			onGoal(team)
			return
		end
	end
end

local function checkOutOfBounds(b: Part, dt: number)
	local p = b.Position
	if p.Y < -5 or p.Y > 40 then
		stats.OutResets += 1
		b.CFrame = CFrame.new(CX, L.Floor + 2, CZ)
		b.AssemblyLinearVelocity = Vector3.zero
		return
	end
	local out = math.abs(p.X - CX) > L.HL + BALL_R or math.abs(p.Z - CZ) > L.HW + BALL_R
	if out then
		outSince += dt
		if outSince > 2 then
			-- ลูกออกนอกเส้น: วางกลับในเส้นจุดที่ใกล้ที่สุด (ถ้าออกท้ายสนามเลื่อนไปข้างหน้าให้พ้นประตู)
			stats.OutResets += 1
			outSince = 0
			local x = math.clamp(p.X, CX - L.HL + 4, CX + L.HL - 4)
			local z = math.clamp(p.Z, CZ - L.HW + 3, CZ + L.HW - 3)
			b.CFrame = CFrame.new(x, L.Floor + 1.5, z)
			b.AssemblyLinearVelocity = Vector3.zero
			b.AssemblyAngularVelocity = Vector3.zero
		end
	else
		outSince = 0
	end
end

local function gameStep(dt: number)
	local b = ball
	if not b or not b.Parent then
		return
	end
	-- แรงหน่วงการกลิ้ง/อากาศ (Roblox ไม่มี rolling resistance)
	local v = b.AssemblyLinearVelocity
	local k = if b.Position.Y < 2.4 then math.max(0, 1 - 0.55 * dt) else math.max(0, 1 - 0.06 * dt)
	b.AssemblyLinearVelocity = Vector3.new(v.X * k, v.Y, v.Z * k)
	if b.Position.Y < 2.4 then
		b.AssemblyAngularVelocity *= k
	end
	clampBall(b)
	local now = os.clock()
	if phase == "Play" then
		checkGoal(b)
		if phase ~= "Play" then
			return
		end
		checkOutOfBounds(b, dt)
		timeLeft -= dt
		clockAcc += dt
		if clockAcc >= 1 then
			clockAcc = 0
			updateBoard(nil)
			pushStats()
		end
		if timeLeft <= 0 then
			timeLeft = 0
			for _, bot in bots do
				bot.Hum:MoveTo(bot.Root.Position)
			end
			if half == 1 then
				startPhase("HalfTime", 6, "HALF TIME")
			else
				startPhase("FullTime", 9, "FULL TIME")
			end
			return
		end
		aiAcc += dt
		if aiAcc >= 0.12 then
			aiAcc = 0
			aiTick()
		end
	elseif now >= phaseUntil then
		if phase == "Goal" then
			phase = "Play"
			kickoff()
			updateBoard(nil)
		elseif phase == "HalfTime" then
			half = 2
			timeLeft = HALF_TIME
			attackDir = { Home = -1, Away = 1 }
			phase = "Play"
			kickoff()
			updateBoard(nil)
		else -- FullTime: เริ่มแมตช์ใหม่
			score = { Home = 0, Away = 0 }
			half = 1
			timeLeft = HALF_TIME
			attackDir = { Home = 1, Away = -1 }
			phase = "Play"
			kickoff()
			updateBoard(nil)
		end
		pushStats()
	end
end

---------------------------------------------------------------- สร้าง/ลบแมตช์ตามผู้เล่นที่อยู่ใกล้
local function despawn()
	active = false
	bots = {}
	chaser = {}
	ball = nil
	lastTouch = nil
	if container then
		container:Destroy()
		container = nil
	end
	setBoard("Status", "STANDBY")
end

local function spawnMatch()
	if spawning or active then
		return
	end
	spawning = true
	local c = Instance.new("Folder")
	c.Name = "SoccerMatch"
	c.Parent = workspace
	container = c
	local newBots: { Bot } = {}
	for _, team in { "Home", "Away" } do
		for _, def in FORMATION do
			local bot = makeBot(team, def, c)
			if bot then
				table.insert(newBots, bot)
			end
		end
	end
	ball = makeBall(c)
	bots = newBots
	score = { Home = 0, Away = 0 }
	half = 1
	timeLeft = HALF_TIME
	attackDir = { Home = 1, Away = -1 }
	phase = "Play"
	kickoff()
	updateBoard(nil)
	pushStats()
	spawning = false
	active = true
	print(string.format("[SoccerPitch] แมตช์เริ่ม: %d บอท", #newBots))
end

local function nearestPlayerDist(): number
	local best = math.huge
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			best = math.min(best, (flat(root.Position) - Vector3.new(CX, 0, CZ)).Magnitude)
		end
	end
	return best
end

local function main()
	local map = workspace:WaitForChild("Map")
	field = map:WaitForChild("Field") :: Folder
	while not field:GetAttribute("PitchReady") do
		task.wait(0.5)
	end
	-- รอให้เมืองสร้างเสร็จก่อน ไม่ให้ช่วงโหลดช้าลง
	local t0 = os.clock()
	while workspace:GetAttribute("GameReady") ~= true and os.clock() - t0 < 120 do
		task.wait(1)
	end
	task.wait(3)
	setBoard("Status", "STANDBY")
	RunService.Heartbeat:Connect(function(dt: number)
		if active then
			gameStep(dt)
		end
	end)
	local far = 0
	local tick = 0
	while true do
		task.wait(1)
		local dist = nearestPlayerDist()
		if not active and not spawning and dist < SPAWN_R then
			spawnMatch()
		elseif active then
			far = if dist > DESPAWN_R then far + 1 else 0
			if far >= 8 then
				far = 0
				despawn()
			end
			tick += 1
			if tick % 3 == 0 then
				unstickTick()
			end
		end
	end
end

main()
