--!strict
-- โหลด/เซฟข้อมูลผู้เล่นด้วย DataStore UpdateAsync + session lock เบื้องต้น (JobId)
-- หมายเหตุ: ควรเปลี่ยนไปใช้ ProfileStore เมื่อลงผ่าน Wally แล้ว (ดู docs/DATA.md)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ProfileTemplate = require(game.ReplicatedStorage.Shared.ProfileTemplate)

local STORE_NAME = "PlayerData_v1"
local LOCK_TIMEOUT = 120 -- วินาที ถือว่าเซิร์ฟเวอร์เดิมตายถ้าไม่อัปเดตเกินนี้
local AUTOSAVE_INTERVAL = 60

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	end
end

local profiles: { [Player]: any } = {}
local PlayerData = {}

local function key(player: Player): string
	return `Player_{player.UserId}`
end

-- คืนค่า profile หรือ nil ถ้าถูกล็อกโดยเซิร์ฟเวอร์อื่น/โหลดไม่ได้
function PlayerData.Load(player: Player): ProfileTemplate.Profile?
	if not store then
		local p = ProfileTemplate.new()
		profiles[player] = p
		return p
	end
	for _ = 1, 5 do
		local locked = false
		local ok, data = pcall(function()
			return (store :: DataStore):UpdateAsync(key(player), function(old)
				old = old or {}
				local lock = old._lock
				if lock and lock.JobId ~= game.JobId and os.time() - lock.Time < LOCK_TIMEOUT then
					locked = true
					return nil -- ยกเลิกการเขียน
				end
				old._lock = { JobId = game.JobId, Time = os.time() }
				return old
			end)
		end)
		if ok and data and not locked then
			local profile = ProfileTemplate.Migrate(data)
			profiles[player] = profile
			return profile
		end
		task.wait(3)
	end
	return nil
end

function PlayerData.Get(player: Player): ProfileTemplate.Profile?
	return profiles[player]
end

function PlayerData.Save(player: Player, release: boolean?)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function(old)
			if old and old._lock and old._lock.JobId ~= game.JobId then
				return nil -- ไม่ใช่เจ้าของล็อก ห้ามเขียนทับ
			end
			local copy = table.clone(profile)
			copy._lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return copy
		end)
	end)
end

function PlayerData.Release(player: Player)
	PlayerData.Save(player, true)
	profiles[player] = nil
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player in profiles do
			task.spawn(PlayerData.Save, player)
		end
	end
end)

game:BindToClose(function()
	for player in profiles do
		task.spawn(PlayerData.Release, player)
	end
	task.wait(3)
end)

Players.PlayerRemoving:Connect(PlayerData.Release)

return PlayerData
