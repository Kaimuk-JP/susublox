--!strict
-- Game feel: hit-stop, กล้องสั่น, เลขดาเมจเด้ง
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local feedback = ReplicatedStorage:WaitForChild("CombatFeedback") :: RemoteEvent
local camera = workspace.CurrentCamera

local function shake(duration: number, power: number)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if os.clock() - t0 > duration then
			conn:Disconnect()
			return
		end
		camera.CFrame *= CFrame.new((math.random() - 0.5) * power, (math.random() - 0.5) * power, 0)
	end)
end

local function damageNumber(position: Vector3, amount: number, crit: boolean?)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.Transparency = true, false, false, 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(0, 3, 0)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 40)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(math.round(amount * 10) / 10)
	label.TextColor3 = if crit then Color3.fromHex("FF4D4D") else Color3.fromHex("FFE066")
	if crit then
		label.Text ..= "!"
		gui.Size = UDim2.fromOffset(130, 64) -- คริติคอล: เลขใหญ่สีแดง
	end
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	anchor.Parent = workspace
	TweenService:Create(anchor, TweenInfo.new(0.6), { Position = anchor.Position + Vector3.new(0, 3, 0) }):Play()
	Debris:AddItem(anchor, 0.6)
end

local lastShake, lastNumber, lastStop = 0, 0, 0
local frozen = false

feedback.OnClientEvent:Connect(function(kind: string, position: Vector3, amount: number)
	if kind ~= "Hit" and kind ~= "Crit" then
		return
	end
	local crit = kind == "Crit"
	local now = os.clock()
	-- กันของค้าง/หน่วงตอนตีโดนหลายตัวพร้อมกัน: จำกัดความถี่ของกล้องสั่น เลขดาเมจ และฮิตสต็อป
	if now - lastShake > 0.12 or crit then
		lastShake = now
		shake(if crit then 0.25 else 0.15, if crit then 0.8 else 0.4)
	end
	if now - lastNumber > 0.05 then
		lastNumber = now
		damageNumber(position, amount, crit)
	end
	-- hit-stop: หน่วงอนิเมชันของตัวเองสั้น ๆ (ไม่ซ้อนกัน และไม่เกินครั้งละ 0.25 วินาที)
	if frozen or now - lastStop < 0.25 then
		return
	end
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		frozen = true
		lastStop = now
		local tracks = hum:GetPlayingAnimationTracks()
		for _, track in tracks do
			track:AdjustSpeed(0)
		end
		task.delay(Config.HitStop, function()
			for _, track in tracks do
				track:AdjustSpeed(1)
			end
			frozen = false
		end)
	end
end)
