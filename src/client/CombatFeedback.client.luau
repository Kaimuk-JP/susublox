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

local function damageNumber(position: Vector3, amount: number)
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
	label.TextColor3 = Color3.fromHex("FFE066")
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	anchor.Parent = workspace
	TweenService:Create(anchor, TweenInfo.new(0.6), { Position = anchor.Position + Vector3.new(0, 3, 0) }):Play()
	Debris:AddItem(anchor, 0.6)
end

feedback.OnClientEvent:Connect(function(kind: string, position: Vector3, amount: number)
	if kind ~= "Hit" then
		return
	end
	shake(0.15, 0.4)
	damageNumber(position, amount)
	-- hit-stop: หน่วงอนิเมชันของตัวเองสั้น ๆ
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		for _, track in hum:GetPlayingAnimationTracks() do
			track:AdjustSpeed(0)
		end
		task.delay(Config.HitStop, function()
			for _, track in hum:GetPlayingAnimationTracks() do
				track:AdjustSpeed(1)
			end
		end)
	end
end)
