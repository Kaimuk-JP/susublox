--!strict
-- ทะเบียนแก๊งข้ามเซิร์ฟเวอร์ด้วย DataStore (1 key ต่อแก๊ง) + แคชในเซิร์ฟเวอร์
local DataStoreService = game:GetService("DataStoreService")

export type Gang = {
	Name: string,
	Leader: number,
	Members: { [string]: boolean }, -- key = UserId (DataStore ต้องใช้ string key)
	Wins: number,
	Funds: number,
	Color: string, -- hex
}

local CACHE_TTL = 30
local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("Gangs_v1")
end)

local cache: { [string]: { gang: Gang?, at: number } } = {}
local GangStore = {}

GangStore.MaxMembers = 20
GangStore.WinsPerLevel = 25

local function key(name: string): string
	return "Gang_" .. name:lower()
end

function GangStore.Count(g: Gang): number
	local n = 0
	for _ in g.Members do
		n += 1
	end
	return n
end

function GangStore.Level(g: Gang): number
	return 1 + g.Wins // GangStore.WinsPerLevel
end

function GangStore.Get(name: string, force: boolean?): Gang?
	local c = cache[key(name)]
	if c and not force and os.clock() - c.at < CACHE_TTL then
		return c.gang
	end
	if not store then
		return c and c.gang
	end
	local ok, data = pcall(function()
		return (store :: DataStore):GetAsync(key(name))
	end)
	if ok then
		cache[key(name)] = { gang = data, at = os.clock() }
		return data
	end
	return c and c.gang
end

-- แก้ไขแบบ atomic: fn รับ gang ปัจจุบัน (หรือ nil) คืน gang ใหม่ หรือ nil เพื่อยกเลิก/ลบ
-- คืนค่า (สำเร็จ, gang ล่าสุด)
function GangStore.Update(name: string, fn: (Gang?) -> Gang?, allowDelete: boolean?): (boolean, Gang?)
	if not store then
		local c = cache[key(name)]
		local new = fn(c and c.gang)
		cache[key(name)] = { gang = new, at = os.clock() }
		return new ~= nil, new
	end
	local result: Gang? = nil
	local changed = false
	local ok = pcall(function()
		(store :: DataStore):UpdateAsync(key(name), function(old)
			local new = fn(old)
			if new == nil and not allowDelete then
				return nil
			end
			changed = true
			result = new
			return new
		end)
	end)
	if ok and changed then
		cache[key(name)] = { gang = result, at = os.clock() }
	end
	return ok and changed, result
end

function GangStore.Create(name: string, leader: number, color: string): boolean
	local created = false
	local ok = GangStore.Update(name, function(old)
		if old then
			return nil -- ชื่อซ้ำ
		end
		created = true
		return {
			Name = name,
			Leader = leader,
			Members = { [tostring(leader)] = true },
			Wins = 0,
			Funds = 0,
			Color = color,
		}
	end)
	return ok and created
end

function GangStore.Join(name: string, userId: number): boolean
	local joined = false
	local ok = GangStore.Update(name, function(old)
		if not old or GangStore.Count(old) >= GangStore.MaxMembers then
			return nil
		end
		old.Members[tostring(userId)] = true
		joined = true
		return old
	end)
	return ok and joined
end

function GangStore.Leave(name: string, userId: number)
	GangStore.Update(name, function(old)
		if not old then
			return nil
		end
		old.Members[tostring(userId)] = nil
		local nextId = next(old.Members)
		if not nextId then
			return nil -- แก๊งว่าง ลบทิ้ง
		end
		if old.Leader == userId then
			old.Leader = tonumber(nextId) :: number
		end
		return old
	end, true)
end

function GangStore.AddWins(name: string, wins: number, funds: number)
	GangStore.Update(name, function(old)
		if not old then
			return nil
		end
		old.Wins += wins
		old.Funds += funds
		return old
	end)
end

return GangStore
