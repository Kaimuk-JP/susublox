--!strict
-- แก๊ง (ข้ามเซิร์ฟเวอร์ผ่าน GangStore): สร้าง/เข้า/ออก สูงสุด 20 คน
-- เลเวลแก๊งเพิ่มจากการชนะร่วมกัน คะแนนชนะถูกรวมเป็นชุดแล้วเขียนทุก 30 วินาที (ประหยัดโควตา DataStore)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Shop)
local Combat = require(script.Parent.Combat)
local GangStore = require(script.Parent.GangStore)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "GangRemote"
remote.Parent = ReplicatedStorage

local pendingWins: { [string]: number } = {}
local busy: { [Player]: boolean } = {}

local function publish(player: Player)
	local p = PlayerData.Get(player)
	local g = p and p.Gang ~= "" and GangStore.Get(p.Gang)
	player:SetAttribute("Gang", if g then g.Name else "")
	player:SetAttribute("GangLevel", if g then GangStore.Level(g) else 0)
	player:SetAttribute("GangFunds", if g then g.Funds else 0)
	player:SetAttribute("GangColor", if g then g.Color else "")
end

local function validName(name: string): boolean
	return #name >= 3 and #name <= 16 and name:match("^[%w_]+$") ~= nil
end

local function handle(player: Player, action: string, arg: unknown)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	if action == "Create" and typeof(arg) == "string" then
		if p.Gang ~= "" or not validName(arg) or p.Yen < Shop.GangCreateCost then
			return
		end
		local color = Color3.fromHSV(math.random(), 0.6, 1):ToHex()
		if GangStore.Create(arg, player.UserId, color) then
			p.Yen -= Shop.GangCreateCost
			p.Gang = arg
			player:SetAttribute("Yen", p.Yen)
		end
	elseif action == "Join" and typeof(arg) == "string" then
		if p.Gang == "" and validName(arg) and GangStore.Join(arg, player.UserId) then
			p.Gang = arg
		end
	elseif action == "Leave" then
		if p.Gang ~= "" then
			GangStore.Leave(p.Gang, player.UserId)
			p.Gang = ""
		end
	end
	publish(player)
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown, arg: unknown)
	if typeof(action) ~= "string" or busy[player] then
		return
	end
	busy[player] = true -- กันกดรัวระหว่างรอ DataStore
	task.spawn(function()
		handle(player, action, arg)
		busy[player] = nil
	end)
end)

Combat.OnKill(function(killer)
	local pl = Players:GetPlayerFromCharacter(killer.Character)
	local p = pl and PlayerData.Get(pl)
	if p and p.Gang ~= "" then
		pendingWins[p.Gang] = (pendingWins[p.Gang] or 0) + 1
	end
end)

task.spawn(function()
	while true do
		task.wait(30)
		for name, wins in pendingWins do
			pendingWins[name] = nil
			task.spawn(GangStore.AddWins, name, wins, wins * 5)
		end
	end
end)

game:BindToClose(function()
	for name, wins in pendingWins do
		pendingWins[name] = nil
		task.spawn(GangStore.AddWins, name, wins, wins * 5)
	end
end)

Players.PlayerAdded:Connect(function(player)
	for _ = 1, 100 do
		if PlayerData.Get(player) then
			break
		end
		task.wait(0.2)
	end
	local p = PlayerData.Get(player)
	if p and p.Gang ~= "" then
		local g = GangStore.Get(p.Gang, true)
		if not g or not g.Members[tostring(player.UserId)] then
			p.Gang = "" -- ถูกลบ/ไม่ได้เป็นสมาชิกแล้ว
		end
	end
	publish(player)
end)
