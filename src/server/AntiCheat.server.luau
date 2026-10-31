--!strict
-- กันโกงพื้นฐาน: ตรวจความเร็วเคลื่อนที่ต่อเนื่อง (บิน/สปีด) และบันทึก log เหตุการณ์น่าสงสัย
-- การวาร์ปจากเกม (ดวล/สงคราม/ก้าวเงา) เป็นการกระโดดครั้งเดียว ไม่ถูกนับเพราะต้องเกินเกณฑ์ติดกัน 3 ครั้ง
-- (ตรวจระยะโจมตี/คูลดาวน์/Rate limit อยู่ใน Combat/SkillService แล้ว)
local Players = game:GetService("Players")

local SAMPLE = 0.5
local MAX_SPEED = 110 -- studs/s เหนือ Dash(60)/ผลักถอย(~65) เล็กน้อย
local CONSECUTIVE = 3
local KICK_STRIKES = 6
local LOG_LIMIT = 200

local log: { string } = {}
local strikes: { [Player]: number } = {}
local streak: { [Player]: number } = {}
local lastPos: { [Player]: Vector3 } = {}

local function record(player: Player, reason: string)
	if #log >= LOG_LIMIT then
		table.remove(log, 1)
	end
	table.insert(log, `{os.date("!%H:%M:%S")} {player.Name}({player.UserId}): {reason}`)
	warn("[AntiCheat] " .. log[#log])
end

task.spawn(function()
	while true do
		task.wait(SAMPLE)
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local prev = lastPos[player]
				lastPos[player] = root.Position
				if prev then
					local d = Vector3.new(root.Position.X - prev.X, 0, root.Position.Z - prev.Z).Magnitude
					if d / SAMPLE > MAX_SPEED then
						streak[player] = (streak[player] or 0) + 1
						if streak[player] >= CONSECUTIVE then
							streak[player] = 0
							strikes[player] = (strikes[player] or 0) + 1
							record(player, `ความเร็วผิดปกติ {math.floor(d / SAMPLE)} studs/s (ครั้งที่ {strikes[player]})`)
							if strikes[player] >= KICK_STRIKES then
								player:Kick("ตรวจพบการเคลื่อนที่ผิดปกติ")
							end
						end
					else
						streak[player] = 0
					end
				end
			else
				lastPos[player] = nil
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	strikes[player], streak[player], lastPos[player] = nil, nil, nil
end)
