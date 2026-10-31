--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("CombatRemote") :: RemoteEvent

local function handler(name: string, state: Enum.UserInputState)
	if name == "M1" and state == Enum.UserInputState.Begin then
		remote:FireServer("M1")
	elseif name == "Block" then
		if state == Enum.UserInputState.Begin then
			remote:FireServer("BlockStart")
		elseif state == Enum.UserInputState.End then
			remote:FireServer("BlockEnd")
		end
	elseif name == "Dash" and state == Enum.UserInputState.Begin then
		remote:FireServer("Dash")
	end
	return Enum.ContextActionResult.Pass
end

-- คีย์บอร์ด + จอยเกม + ปุ่มสัมผัสบนมือถือ (createTouchButton = true)
ContextActionService:BindAction("M1", handler, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("Block", handler, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
ContextActionService:BindAction("Dash", handler, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
for name, text in { M1 = "ชก", Block = "บล็อก", Dash = "หลบ" } do
	ContextActionService:SetTitle(name, text)
end
