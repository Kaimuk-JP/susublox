--!strict
-- ดวล 1v1: ท้า (จากคีออสก์/ลานหน้าสนามประลอง) -> อีกฝ่ายกดรับ -> วาร์ปเข้าสนามธีมสุ่ม (instance แยก)
-- ผู้ชนะได้แต้มแรงก์ ผู้แพ้เสียแต้ม จบแล้วทุกคนถูกส่งกลับลานหน้าสนาม
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Arena = require(script.Parent.ArenaManager)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "DuelRemote"
remote.Parent = ReplicatedStorage
local worldRemote = ReplicatedStorage:WaitForChild("WorldRemote") :: RemoteEvent

local WIN_POINTS, LOSE_POINTS = 25, 10
local DUEL_TIMEOUT = 180
local CHALLENGE_TIMEOUT = 15
local CHALLENGE_COOLDOWN = 3
local RETURN_DELAY = 5
local COUNTDOWN = 10

type Duel = { A: Player, B: Player, Inst: Arena.Inst, Over: boolean, StartAt: number }

local challenges: { [Player]: { from: Player, at: number } } = {} -- ผู้ถูกท้า -> ผู้ท้า
local lastChallenge: { [Player]: number } = {}
local duelOf: { [Player]: Duel } = {}

local function toast(text: string)
	worldRemote:FireAllClients("Toast", text)
end

local function alive(player: Player): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function inLobby(player: Player): boolean
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return alive(player) and r ~= nil and Arena.InLobby(r.Position) and Arena.Of(player) == nil and duelOf[player] == nil
end

local function endDuel(d: Duel, winner: Player?, loser: Player?, note: string?)
	if d.Over then
		return
	end
	d.Over = true
	for _, pl in { d.A, d.B } do
		if duelOf[pl] == d then
			duelOf[pl] = nil
		end
		pl:SetAttribute("InDuel", false)
	end
	Arena.EndFight(d.Inst)
	if winner then
		local pw = PlayerData.Get(winner)
		if pw then
			pw.RankPoints += WIN_POINTS
			winner:SetAttribute("RankPoints", pw.RankPoints)
			local storyEvent = ServerStorage:FindFirstChild("StoryEvent") :: BindableEvent?
			if storyEvent then
				storyEvent:Fire(winner, "DuelWin")
			end
		end
	end
	if loser then
		local pl = PlayerData.Get(loser)
		if pl then
			pl.RankPoints = math.max(0, pl.RankPoints - LOSE_POINTS)
			loser:SetAttribute("RankPoints", pl.RankPoints)
		end
	end
	local text = if winner and loser
		then `{winner.DisplayName} ชนะดวล {loser.DisplayName}! +{WIN_POINTS} แต้มแรงก์`
		else (note or "ดวลจบแบบเสมอ ไม่เปลี่ยนแต้ม")
	toast(text)
	Arena.SetBoard(d.Inst, { State = "over", Note = text })
	task.delay(RETURN_DELAY, function()
		Arena.Destroy(d.Inst)
	end)
end

local function start(a: Player, b: Player)
	if not inLobby(a) or not inLobby(b) then
		return
	end
	local inst = Arena.Create("Duel", `ดวล {a.DisplayName} vs {b.DisplayName}`, nil, 2)
	if not inst then
		worldRemote:FireClient(a, "Toast", "สนามเต็มแล้ว ลองใหม่ภายหลัง")
		worldRemote:FireClient(b, "Toast", "สนามเต็มแล้ว ลองใหม่ภายหลัง")
		return
	end
	local d: Duel = { A = a, B = b, Inst = inst, Over = false, StartAt = os.clock() }
	duelOf[a], duelOf[b] = d, d
	a:SetAttribute("InDuel", true)
	b:SetAttribute("InDuel", true)
	Arena.SetBoard(inst, { State = "wait", Title = "ดวล 1v1", NameA = a.DisplayName, NameB = b.DisplayName, Mid = "VS", Note = "" })
	inst.OnLeave = function(pl: Player)
		local other = if pl == a then b else a
		if inst.Locked then -- ออกระหว่างนับถอยหลัง = ยกเลิก ไม่ให้แต้ม
			endDuel(d, nil, nil, `ยกเลิกดวล: {pl.DisplayName} ออกระหว่างนับถอยหลัง`)
			return
		end
		endDuel(d, other, pl, `{pl.DisplayName} ยอมแพ้ {other.DisplayName} ชนะดวล`)
	end
	task.spawn(function()
		local okA, okB = false, false
		local pending = 2
		task.spawn(function()
			okA = Arena.Enter(inst, a, "SpawnA4", "fighter")
			pending -= 1
		end)
		task.spawn(function()
			okB = Arena.Enter(inst, b, "SpawnB4", "fighter")
			pending -= 1
		end)
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 10 do
			task.wait(0.1)
		end
		if not (okA and okB) then
			endDuel(d, nil, nil, "เริ่มดวลไม่สำเร็จ")
			return
		end
		-- ผู้เล่นตายเอง (ไม่ผ่าน Combat.OnKill) ก็นับเป็นแพ้
		for _, pl in { a, b } do
			local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Died:Once(function()
					if not d.Over then
						local other = if pl == a then b else a
						endDuel(d, other, pl)
					end
				end)
			end
		end
		-- นับถอยหลัง 10 วิ (ล็อกทั้งคู่) ถ้ามีใครออก/ตายระหว่างนับ = ยกเลิกคืนทั้งคู่กลับลาน
		if not Arena.RunCountdown(inst, COUNTDOWN, function()
			return d.Over
		end) then
			if not d.Over then
				endDuel(d, nil, nil, "ยกเลิกดวลระหว่างนับถอยหลัง")
			end
			return
		end
		if d.Over then
			return
		end
		d.StartAt = os.clock()
		Arena.SetBoard(inst, { State = "live", Ends = workspace:GetServerTimeNow() + DUEL_TIMEOUT })
		while not d.Over do
			if os.clock() - d.StartAt >= DUEL_TIMEOUT then
				endDuel(d, nil, nil)
				break
			end
			task.wait(0.5)
		end
	end)
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown, targetId: unknown)
	if typeof(action) ~= "string" or typeof(targetId) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player then
		return
	end
	local now = os.clock()
	if action == "Challenge" then
		if now - (lastChallenge[player] or -math.huge) < CHALLENGE_COOLDOWN then
			return
		end
		lastChallenge[player] = now
		if not inLobby(player) or not inLobby(target) then
			worldRemote:FireClient(player, "Toast", "ต้องอยู่ที่ลานหน้าสนามประลองทั้งคู่ (และไม่ติดแมตช์อื่น)")
			return
		end
		challenges[target] = { from = player, at = now }
		remote:FireClient(target, "Challenged", player.UserId, player.DisplayName)
		worldRemote:FireClient(player, "Toast", `ส่งคำท้าให้ {target.DisplayName} แล้ว (รอ {CHALLENGE_TIMEOUT} วิ)`)
	elseif action == "Accept" then
		local c = challenges[player]
		if c and c.from == target and now - c.at <= CHALLENGE_TIMEOUT then
			challenges[player] = nil
			start(target, player)
		end
	elseif action == "Decline" then
		local c = challenges[player]
		if c and c.from == target then
			challenges[player] = nil
			worldRemote:FireClient(target, "Toast", `{player.DisplayName} ปฏิเสธคำท้า`)
		end
	end
end)

Combat.OnKill(function(killer, victim)
	local a, b = Players:GetPlayerFromCharacter(killer.Character), Players:GetPlayerFromCharacter(victim.Character)
	local d = a and duelOf[a]
	if a and b and d and duelOf[b] == d then
		endDuel(d, a, b)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	challenges[player] = nil
	lastChallenge[player] = nil
	for target, c in challenges do
		if c.from == player then
			challenges[target] = nil
		end
	end
	local d = duelOf[player]
	if d then
		local other = if player == d.A then d.B else d.A
		if d.Inst.Locked then
			endDuel(d, nil, nil, `ยกเลิกดวล: {player.DisplayName} หลุดจากเกมระหว่างนับถอยหลัง`)
		else
			endDuel(d, other, player, `{player.DisplayName} หลุดจากเกม {other.DisplayName} ชนะดวล`)
		end
	end
	duelOf[player] = nil
end)
