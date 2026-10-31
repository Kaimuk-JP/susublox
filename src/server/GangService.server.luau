--!strict
-- แก๊ง: สร้าง/เข้า/ออก สูงสุด 20 คน เลเวลแก๊งเพิ่มจากการชนะร่วมกัน
-- ข้อจำกัด: ทะเบียนแก๊งเก็บในหน่วยความจำของเซิร์ฟเวอร์นี้ ชื่อแก๊งเก็บในโปรไฟล์ผู้เล่น
-- (ข้ามเซิร์ฟเวอร์ต้องใช้ MemoryStore/DataStore เพิ่ม — ดู docs/STATUS.md)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Shop)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local MAX_MEMBERS = 20
local WINS_PER_LEVEL = 25

local remote = Instance.new("RemoteEvent")
remote.Name = "GangRemote"
remote.Parent = ReplicatedStorage

type Gang = { Name: string, Leader: number, Members: { [number]: boolean }, Wins: number, Color: Color3 }
local gangs: { [string]: Gang } = {}

local function count(g: Gang): number
	local n = 0
	for _ in g.Members do
		n += 1
	end
	return n
end

local function publish(player: Player)
	local p = PlayerData.Get(player)
	local g = p and gangs[p.Gang]
	player:SetAttribute("Gang", if g then g.Name else "")
	player:SetAttribute("GangLevel", if g then 1 + g.Wins // WINS_PER_LEVEL else 0)
end

local function validName(name: string): boolean
	return #name >= 3 and #name <= 16 and name:match("^[%w_]+$") ~= nil
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown, arg: unknown)
	local p = PlayerData.Get(player)
	if not p or typeof(action) ~= "string" then
		return
	end
	if action == "Create" and typeof(arg) == "string" then
		if p.Gang ~= "" or not validName(arg) or gangs[arg] or p.Yen < Shop.GangCreateCost then
			return
		end
		p.Yen -= Shop.GangCreateCost
		gangs[arg] = {
			Name = arg,
			Leader = player.UserId,
			Members = { [player.UserId] = true },
			Wins = 0,
			Color = Color3.fromHSV(math.random(), 0.6, 1),
		}
		p.Gang = arg
		player:SetAttribute("Yen", p.Yen)
	elseif action == "Join" and typeof(arg) == "string" then
		local g = gangs[arg]
		if p.Gang == "" and g and count(g) < MAX_MEMBERS then
			g.Members[player.UserId] = true
			p.Gang = arg
		end
	elseif action == "Leave" then
		local g = gangs[p.Gang]
		if g then
			g.Members[player.UserId] = nil
			if next(g.Members) == nil then
				gangs[g.Name] = nil
			elseif g.Leader == player.UserId then
				g.Leader = next(g.Members) :: number
			end
		end
		p.Gang = ""
	end
	publish(player)
end)

-- ชนะร่วมกัน: เพิ่ม Wins ให้แก๊งของผู้ฆ่า
Combat.OnKill(function(killer)
	local pl = Players:GetPlayerFromCharacter(killer.Character)
	local p = pl and PlayerData.Get(pl)
	local g = p and gangs[p.Gang]
	if pl and g then
		g.Wins += 1
		publish(pl)
	end
end)

-- เมื่อผู้เล่นเข้าเกม: ถ้าแก๊งยังไม่มีในเซิร์ฟเวอร์นี้ ให้สร้างทะเบียนจากชื่อในโปรไฟล์
Players.PlayerAdded:Connect(function(player)
	for _ = 1, 100 do
		if PlayerData.Get(player) then
			break
		end
		task.wait(0.2)
	end
	local p = PlayerData.Get(player)
	if p and p.Gang ~= "" then
		local g = gangs[p.Gang]
		if not g then
			g = {
				Name = p.Gang,
				Leader = player.UserId,
				Members = {},
				Wins = 0,
				Color = Color3.fromHSV(math.random(), 0.6, 1),
			}
			gangs[p.Gang] = g
		end
		(g :: Gang).Members[player.UserId] = true
	end
	publish(player)
end)
