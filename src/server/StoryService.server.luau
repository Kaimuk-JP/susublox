--!strict
-- เนื้อเรื่องหลัก (29 ขั้น 4 องก์) + ใบสั่งล่าแก๊งแบบทำซ้ำได้ไม่จบ (สุ่มตามเลเวลผู้เล่น ทำเสร็จได้ใบใหม่ทันที)
-- ความคืบหน้าเนื้อเรื่องคำนวณจากสถิติสะสมในโปรไฟล์ รางวัลให้อัตโนมัติเมื่อครบ
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Story = require(ReplicatedStorage.Shared.Story)
local Scenes = require(ReplicatedStorage.Shared.Scenes)
local World = require(ReplicatedStorage.Shared.World)
local WQ = require(ReplicatedStorage.Shared.WorldQuests)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local remote = ReplicatedStorage:WaitForChild("WorldRemote", 60) :: RemoteEvent
local changed = ServerStorage:WaitForChild("ProfileChanged") :: BindableEvent

-- ระบบอื่นยิงเหตุการณ์มาที่นี่: Fire(player, "CampCleared", districtId) / Fire(player, "DuelWin")
local storyEvent = Instance.new("BindableEvent")
storyEvent.Name = "StoryEvent"
storyEvent.Parent = ServerStorage

local rng = Random.new()
local REROLL_COOLDOWN = 120

local function inc(p: any, name: string, n: number)
	p.Counters[name] = (p.Counters[name] or 0) + n
end

---------------------------------------------------------------- เนื้อเรื่องหลัก
local function progressOf(p: any, step: Story.Step): number
	local k = step.Kind
	if k == "Wins" then
		return p.Wins
	elseif k == "Level" then
		return p.Level
	elseif k == "Fame" then
		return p.Fame
	elseif k == "Prestige" then
		return p.Prestige
	elseif k == "DuelWins" then
		return p.Counters.DuelWins or 0
	elseif k == "CampsCleared" then
		return p.Counters.CampsCleared or 0
	elseif k == "WorldBossKills" then
		return p.Counters.WorldBossKills or 0
	elseif k == "Gang" then
		return if p.Gang ~= "" then 1 else 0
	elseif k == "Discover" then
		return if p.World.Discovered[step.Target :: string] then 1 else 0
	elseif k == "QuestDone" then
		return if p.World.Done[step.Target :: string] then 1 else 0
	elseif k == "QuestsDone" then
		local n = 0
		for _, q in WQ.ForDistrict(step.Target :: string) do
			if p.World.Done[q.Id] then
				n += 1
			end
		end
		return n
	end
	return 0
end

local function stepTarget(step: Story.Step): Vector3?
	local districtId = step.Target
	if step.Kind == "QuestDone" and districtId then
		local q = WQ.ById[districtId]
		districtId = q and q.District
	end
	local d = districtId and World.ById(districtId)
	if d and (step.Kind == "Discover" or step.Kind == "QuestDone" or step.Kind == "QuestsDone") then
		return d.Center
	end
	return nil
end

local function giveReward(player: Player, p: any, r: Story.Reward)
	p.Yen += r.Yen
	p.Fame += r.Fame
	if r.Exp > 0 then
		local level, exp, points = Progression.AddExp(p.Level, p.Exp, r.Exp, p.Prestige)
		p.Level, p.Exp = level, exp
		p.StatPoints += points
	end
	if r.Outfit and not table.find(p.Owned, r.Outfit) then
		table.insert(p.Owned, r.Outfit)
	end
	changed:Fire(player)
end

local function publishStory(player: Player, p: any)
	local total = #Story.Steps
	player:SetAttribute("StoryIndex", p.StoryStep)
	player:SetAttribute("StoryTotal", total)
	local step = Story.Steps[p.StoryStep]
	if not step then
		player:SetAttribute("StoryTitle", "จบเนื้อเรื่องหลักแล้ว: คุณคือราชาโรงเรียน")
		player:SetAttribute("StoryText", "ไต่เวลต่อ ล่าบอสสุ่ม และรับใบสั่งล่าได้ไม่จำกัด")
		player:SetAttribute("StoryPos", nil)
		return
	end
	local prog = math.min(progressOf(p, step), step.Goal)
	player:SetAttribute("StoryTitle", `{Story.Acts[step.Act]}  •  {step.Title}`)
	player:SetAttribute("StoryText", if step.Goal > 1 then `{step.Desc}  ({math.floor(prog)}/{step.Goal})` else step.Desc)
	player:SetAttribute("StoryPos", stepTarget(step))
end

-- เล่นฉากบทสนทนา (ครั้งเดียวต่อผู้เล่น) client ถือบทเอง ส่งแค่คีย์
local function playScene(player: Player, p: any, key: string)
	if Scenes.Scenes[key] and not p.SeenScenes[key] then
		p.SeenScenes[key] = true
		remote:FireClient(player, "Scene", key)
	end
end

-- ตรวจและเลื่อนขั้น (ถ้าผู้เล่นเกินเกณฑ์อยู่แล้วหลายขั้นก็ไล่ให้ครบ สูงสุด 12 ขั้นต่อรอบ)
local function advanceStory(player: Player)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	local completed = 0
	local lastTitle = ""
	local sceneKeys: { string } = {}
	for _ = 1, 12 do
		local step = Story.Steps[p.StoryStep]
		if not step or progressOf(p, step) < step.Goal then
			break
		end
		giveReward(player, p, step.Reward)
		p.StoryStep += 1
		completed += 1
		lastTitle = step.Title
		table.insert(sceneKeys, step.Id .. ":done")
		local nextStep = Story.Steps[p.StoryStep]
		if nextStep then
			table.insert(sceneKeys, nextStep.Id .. ":start")
		end
		local r = step.Reward
		remote:FireClient(
			player,
			"Toast",
			`เนื้อเรื่อง: {step.Title} สำเร็จ! +¥{r.Yen}`
				.. (if r.Exp > 0 then ` +{r.Exp} EXP` else "")
				.. (if r.Outfit then " + ได้ชุดใหม่!" else "")
		)
	end
	if completed > 1 then
		remote:FireClient(player, "Toast", `เนื้อเรื่องก้าวหน้า {completed} ขั้นรวด! (ล่าสุด: {lastTitle})`)
	end
	-- ฉากบทสนทนา: ผ่านทีละขั้นเล่นครบ; ถ้าข้ามรวดหลายขั้น (เช่นเลเวลสูงอยู่แล้ว) เล่นเฉพาะฉากท้ายสุด ไม่ให้ท่วมจอ
	if completed == 1 then
		for _, key in sceneKeys do
			playScene(player, p, key)
		end
	elseif completed > 1 then
		for i, key in sceneKeys do
			if i >= #sceneKeys - 1 then
				playScene(player, p, key)
			else
				p.SeenScenes[key] = true
			end
		end
	end
	publishStory(player, p)
end

---------------------------------------------------------------- ใบสั่งล่าแก๊ง (ทำซ้ำได้ไม่จบ)
local function pickDistrict(level: number): World.District
	local best: { World.District } = {}
	local bestScore = math.huge
	for _, d in World.Districts do
		local lo, hi = d.Levels[1], d.Levels[2] + 2
		local score = if level < lo then lo - level elseif level > hi then level - hi else 0
		if score < bestScore then
			best, bestScore = { d }, score
		elseif score == bestScore then
			table.insert(best, d)
		end
	end
	return best[rng:NextInteger(1, #best)]
end

local function newBounty(p: any)
	local d = pickDistrict(p.Level)
	local mid = (d.Levels[1] + d.Levels[2]) / 2
	local camp = rng:NextNumber() < 0.3
	local count = if camp then (if p.Level >= 10 then 2 else 1) else math.min(30, 8 + math.floor(p.Level / 8) * 2)
	p.Bounty.Active = {
		Kind = if camp then "Camp" else "Kill",
		District = d.Id,
		Target = count,
		Progress = 0,
		Yen = math.floor(count * (if camp then 40 else 6) * mid),
		Exp = math.floor(count * (if camp then 110 else 22) * mid),
		Fame = if camp then 8 * count else math.floor(count / 3),
	}
end

local function publishBounty(player: Player, p: any)
	local b = p.Bounty.Active
	if not b then
		player:SetAttribute("BountyText", nil)
		return
	end
	local d = World.ById(b.District) :: World.District
	local verb = if b.Kind == "Camp" then `เคลียร์ค่ายแก๊ง{d.EnemyName}` else `ล้ม{d.EnemyName}`
	player:SetAttribute("BountyText", `ใบสั่งล่า: {verb} ที่{d.Name}  {b.Progress}/{b.Target}`)
	player:SetAttribute("BountyReward", `¥{b.Yen} +{b.Exp} EXP +{b.Fame} Fame`)
	player:SetAttribute("BountyPos", d.Center)
	player:SetAttribute("BountyDone", p.Bounty.Done or 0)
end

local function bountyProgress(player: Player, kind: string, districtId: string)
	local p = PlayerData.Get(player)
	local b = p and p.Bounty.Active
	if not p or not b or b.Kind ~= kind or b.District ~= districtId then
		return
	end
	b.Progress = math.min(b.Target, b.Progress + 1)
	if b.Progress >= b.Target then
		giveReward(player, p, { Yen = b.Yen, Exp = b.Exp, Fame = b.Fame })
		p.Bounty.Done = (p.Bounty.Done or 0) + 1
		remote:FireClient(player, "Toast", `ใบสั่งล่าสำเร็จ! +¥{b.Yen} +{b.Exp} EXP (ครั้งที่ {p.Bounty.Done}) — มีใบสั่งใหม่แล้ว`)
		newBounty(p)
	end
	publishBounty(player, p)
end

---------------------------------------------------------------- เหตุการณ์
Combat.OnKill(function(killer, victim)
	local player = Players:GetPlayerFromCharacter(killer.Character)
	local p = player and PlayerData.Get(player)
	if not player or not p then
		return
	end
	inc(p, "Kills", 1)
	if victim.Character:GetAttribute("WorldBoss") == true then
		inc(p, "WorldBossKills", 1)
	elseif victim.IsBoss then
		inc(p, "BossKills", 1)
	end
	local districtId = victim.Character:GetAttribute("District")
	if typeof(districtId) == "string" then
		bountyProgress(player, "Kill", districtId)
	end
	advanceStory(player)
end)

storyEvent.Event:Connect(function(player: Player, kind: string, arg: string?)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	if kind == "CampCleared" then
		inc(p, "CampsCleared", 1)
		if arg then
			bountyProgress(player, "Camp", arg)
		end
	elseif kind == "DuelWin" then
		inc(p, "DuelWins", 1)
	end
	advanceStory(player)
end)

remote.OnServerEvent:Connect(function(player: Player, action: unknown)
	if action ~= "RerollBounty" then
		return
	end
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	if os.time() < (p.Bounty.RerollAt or 0) then
		remote:FireClient(player, "Toast", `เปลี่ยนใบสั่งได้อีกใน {(p.Bounty.RerollAt or 0) - os.time()} วินาที`)
		return
	end
	p.Bounty.RerollAt = os.time() + REROLL_COOLDOWN
	newBounty(p)
	publishBounty(player, p)
end)

local function setup(player: Player)
	for _ = 1, 100 do
		if PlayerData.Get(player) then
			break
		end
		task.wait(0.2)
	end
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	if not p.Bounty.Active then
		newBounty(p)
	end
	publishBounty(player, p)
	advanceStory(player)
	-- ฉากเปิดเรื่อง: เล่นครั้งแรกที่เข้าเกม (รอให้จอโหลดเสร็จ)
	if not p.SeenScenes.intro and p.StoryStep <= 1 then
		task.wait(4)
		playScene(player, p, "intro")
	end
end
Players.PlayerAdded:Connect(setup)
for _, pl in Players:GetPlayers() do
	task.spawn(setup, pl)
end

-- ตรวจความคืบหน้าเป็นระยะ (เลเวล/ชื่อเสียง/ค้นพบย่าน ที่เปลี่ยนจากระบบอื่นโดยไม่มีเหตุการณ์ส่งมา)
task.spawn(function()
	while true do
		task.wait(1.5)
		for _, pl in Players:GetPlayers() do
			advanceStory(pl)
		end
	end
end)
