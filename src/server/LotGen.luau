--!strict
-- แบ่งล็อตตึกแบบโตเกียวตามริมถนนทุกสายใน World.Roads: ล็อตแคบ กว้าง/ลึก/สูง/ยุคต่างกันในบล็อกเดียว ไม่เว้นสนามหญ้าในเมือง
-- ไม่ทับถนน (+ทางเท้า) / KeepOut / ตำแหน่งผู้ให้ภารกิจ-บอส-จุดสำรวจ-สถานี / ล็อตอื่น; ผลคงที่ (ไม่ขึ้นกับลำดับการเรียก)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.World)

export type Lot = {
	X: number,
	Z: number,
	W: number, -- ความกว้างหน้าอาคาร (ขนานถนน)
	D: number, -- ความลึก
	H: number,
	Yaw: number, -- องศาหมุนรอบ Y จากแบบ "หน้าอาคารหัน +Z": 0=+Z, 180=-Z, 90=+X, -90=-X
	Zone: string,
	Era: string,
	Ground: string, -- shop | house | ind | yard
	Kind: string?,
	Corner: boolean,
	Road: number,
	Side: number,
	Fx1: number,
	Fx2: number,
	Fz1: number,
	Fz2: number,
}

local LotGen = {}

type Profile = { w: { number }, d: { number }, h: { number }, gap: { number }, pgap: number, ground: string, eras: { [string]: number }, awning: boolean? }
local PROFILES: { [string]: Profile } = {
	down = { w = { 6, 13 }, d = { 12, 21 }, h = { 16, 54 }, gap = { 0, 0.6 }, pgap = 0.07, ground = "shop", eras = { postwar = 3, showa = 3, modern = 2 } },
	shop = { w = { 6, 10 }, d = { 12, 15 }, h = { 9, 17 }, gap = { 0, 0.4 }, pgap = 0.04, ground = "shop", eras = { postwar = 2, showa = 4, wood = 3, modern = 1 }, awning = true },
	resi = { w = { 7, 12 }, d = { 10, 16 }, h = { 7, 21 }, gap = { 1, 4.5 }, pgap = 0.5, ground = "house", eras = { wood = 4, showa = 3, postwar = 2, modern = 1 } },
	park = { w = { 9, 13 }, d = { 9, 12 }, h = { 6, 9 }, gap = { 4, 16 }, pgap = 0.65, ground = "house", eras = { wood = 4, showa = 1 } },
	ind = { w = { 16, 34 }, d = { 16, 28 }, h = { 9, 16 }, gap = { 3, 10 }, pgap = 0.25, ground = "ind", eras = { postwar = 1 } },
	monzen = { w = { 6, 9 }, d = { 9, 12 }, h = { 5, 8 }, gap = { 0.5, 2 }, pgap = 0.1, ground = "shop", eras = { wood = 1 } },
}
LotGen.Profiles = PROFILES

local DOWN_KINDS = { "karaoke", "pachinko", "izakaya", "game", "pharmacy", "kissaten", "books", "ramen", "izakaya", "karaoke", "game", "ramen" }
local SHOP_KINDS = { "ramen", "izakaya", "books", "kissaten", "game", "pharmacy", "izakaya", "ramen", "kissaten" }
local HOUSE_SHOP_KINDS = { "kissaten", "pharmacy", "ramen" }

local function sidewalkOf(w: number, kind: string): number
	if kind == "T" then
		return 0.6
	elseif w >= 14 then
		return 5.4 -- ทางเท้า 5 + ขอบถนน (ต้องตรงกับ WorldBuilder/StreetFurniture)
	elseif w >= 10 then
		return 2.4
	end
	return 0.6
end

local function pick(rng: Random, weights: { [string]: number }): string
	local total = 0
	for _, v in weights do
		total += v
	end
	local r = rng:NextNumber() * total
	local last = ""
	-- ลำดับคงที่ (เรียงชื่อ) เพื่อให้ผลซ้ำได้
	local names = {}
	for k in weights do
		table.insert(names, k)
	end
	table.sort(names)
	for _, k in names do
		last = k
		r -= weights[k]
		if r <= 0 then
			return k
		end
	end
	return last
end

local function range(rng: Random, r: { number }): number
	return rng:NextNumber(r[1], r[2])
end

local cache: { Lots: { Lot }, Stats: { [string]: any } }? = nil
local grid: { [string]: { Lot } } = {}
local CELL = 40

local function cellKey(ix: number, iz: number): string
	return ix .. "," .. iz
end

local function indexLot(lot: Lot)
	for ix = math.floor(lot.Fx1 / CELL), math.floor(lot.Fx2 / CELL) do
		for iz = math.floor(lot.Fz1 / CELL), math.floor(lot.Fz2 / CELL) do
			local k = cellKey(ix, iz)
			local bucket = grid[k]
			if not bucket then
				bucket = {}
				grid[k] = bucket
			end
			table.insert(bucket, lot)
		end
	end
end

function LotGen.generate(): { Lot }
	if cache then
		return cache.Lots
	end
	local roads = World.Roads
	local stats: { [string]: number } = { Candidates = 0, RoadHits = 0, KeepHits = 0, LotHits = 0, Placed = 0, Yards = 0, Corner = 0 }
	local lots: { Lot } = {}

	-- สี่เหลี่ยมถนน (ขยายด้วยทางเท้า) สำหรับตรวจชน
	local rr: { { number } } = {}
	for i, r in roads do
		local x1, x2, z1, z2 = World.RoadRect(r, sidewalkOf(r[5], r[6]) + 0.3)
		rr[i] = { x1, x2, z1, z2 }
	end
	-- ห้ามสร้าง: KeepOut + วงกลม (ผู้ให้ภารกิจ บอส จุดสำรวจ ศูนย์กลาง) + แท่นสถานี
	local keeps: { { number } } = {}
	for _, k in World.KeepOut do
		table.insert(keeps, { k[1], k[2], k[3], k[4] })
	end
	for id, p in World.Stones do
		table.insert(keeps, { p.X - 11, p.X + 11, p.Z - 7, p.Z + 7 })
		local _ = id
	end
	for _, d in World.Districts do
		local pts = { d.Center, d.Center + d.GiverOffset, d.Center + d.BossOffset }
		for _, poi in d.Pois do
			table.insert(pts, d.Center + poi)
		end
		for _, p in pts do
			if p.Y < 2 then
				table.insert(keeps, { p.X - 7, p.X + 7, p.Z - 7, p.Z + 7 })
			end
		end
	end
	local B = World.Bounds

	local function zoneAt(x: number, z: number): string?
		for _, zn in World.Zones do
			if x >= zn[1] and x <= zn[2] and z >= zn[3] and z <= zn[4] then
				return zn[5]
			end
		end
		return nil
	end

	-- คืน "road" | "keep" | "lot" | nil
	local function blocked(x1: number, x2: number, z1: number, z2: number, skipRoad: number): string?
		if x1 < B.MinX + 12 or x2 > B.MaxX - 12 or z1 < B.MinZ + 12 or z2 > B.MaxZ - 12 then
			return "keep"
		end
		for i, q in rr do
			if i ~= skipRoad and roads[i][6] ~= "T" and x1 < q[2] and q[1] < x2 and z1 < q[4] and q[3] < z2 then
				return "road"
			end
		end
		for _, k in keeps do
			if x1 < k[2] and k[1] < x2 and z1 < k[4] and k[3] < z2 then
				return "keep"
			end
		end
		for _, lot in lots do
			if x1 < lot.Fx2 + 0.25 and lot.Fx1 - 0.25 < x2 and z1 < lot.Fz2 + 0.25 and lot.Fz1 - 0.25 < z2 then
				return "lot"
			end
		end
		return nil
	end

	for i, r in roads do
		local kind: string = r[6]
		if kind == "T" then
			continue
		end
		local w: number = r[5]
		local horizontal = math.abs(r[3] - r[1]) >= math.abs(r[4] - r[2])
		local lo = if horizontal then math.min(r[1], r[3]) else math.min(r[2], r[4])
		local hi = if horizontal then math.max(r[1], r[3]) else math.max(r[2], r[4])
		local fixed = if horizontal then r[2] else r[1]
		for _, side in { -1, 1 } do
			local rng = Random.new(i * 7919 + (if side == 1 then 13 else 31))
			if kind == "Y" and rng:NextNumber() < 0.3 then
				continue -- ซอยแคบบางข้างเป็นกำแพง/รั้วหลังตึกอื่น
			end
			local off0 = w / 2 + sidewalkOf(w, kind) + 0.15
			local t = lo + 1
			while t < hi - 5 do
				-- โปรไฟล์ตามโซนตรงจุดนี้
				local px = if horizontal then t + 4 else fixed + side * (off0 + 6)
				local pz = if horizontal then fixed + side * (off0 + 6) else t + 4
				local zone = zoneAt(px, pz)
				local prof = if zone then PROFILES[zone] else nil
				if not prof then
					t += 6
					continue
				end
				if rng:NextNumber() < prof.pgap then
					t += rng:NextNumber(4, 11) -- ที่ว่าง/ซอยแคบระหว่างตึก
					continue
				end
				local wl = math.floor(range(rng, prof.w) * 2 + 0.5) / 2
				local dl0 = range(rng, prof.d)
				local placed = false
				local hitRoad = false
				stats.Candidates += 1
				for _, shrink in { 1, 0.78, 0.58 } do
					local dl = math.max(8, dl0 * shrink)
					local a1, a2 = t, t + wl
					local p1, p2
					if side == 1 then
						p1, p2 = fixed + off0, fixed + off0 + dl
					else
						p1, p2 = fixed - off0 - dl, fixed - off0
					end
					local x1, x2, z1, z2
					if horizontal then
						x1, x2, z1, z2 = a1, a2, p1, p2
					else
						x1, x2, z1, z2 = p1, p2, a1, a2
					end
					local why = blocked(x1, x2, z1, z2, i)
					if why == "road" then
						hitRoad = true
					end
					if why == nil then
						local era = pick(rng, prof.eras)
						local h = range(rng, prof.h)
						if era == "wood" then
							h = math.min(h, rng:NextNumber(6.5, 9))
						elseif era == "modern" and zone == "down" then
							h = math.max(h, 24)
						elseif era ~= "modern" and zone == "down" then
							h = math.min(h, 42)
						end
						-- ล็อตมุม (ติดแยก) = ที่ตั้งร้านสะดวกซื้อ
						local corner = false
						for j, q in rr do
							if j ~= i and (math.abs(roads[j][3] - roads[j][1]) >= math.abs(roads[j][4] - roads[j][2])) ~= horizontal and roads[j][5] >= 8 then
								if x1 < q[2] + 3 and q[1] - 3 < x2 and z1 < q[4] + 3 and q[3] - 3 < z2 then
									corner = true
									break
								end
							end
						end
						local ground = prof.ground
						local lotKind: string? = nil
						if ground == "shop" then
							if corner and rng:NextNumber() < 0.45 then
								lotKind = "konbini"
							elseif zone == "down" then
								lotKind = DOWN_KINDS[rng:NextInteger(1, #DOWN_KINDS)]
							else
								lotKind = SHOP_KINDS[rng:NextInteger(1, #SHOP_KINDS)]
							end
						elseif ground == "house" and rng:NextNumber() < 0.1 then
							ground = "shop"
							lotKind = HOUSE_SHOP_KINDS[rng:NextInteger(1, #HOUSE_SHOP_KINDS)]
						elseif ground == "ind" and rng:NextNumber() < 0.4 then
							ground = "yard"
							h = 0
						end
						local yaw: number
						if horizontal then
							yaw = if side == 1 then 180 else 0
						else
							yaw = if side == 1 then -90 else 90
						end
						local lot: Lot = {
							X = (x1 + x2) / 2,
							Z = (z1 + z2) / 2,
							W = wl,
							D = dl,
							H = h,
							Yaw = yaw,
							Zone = zone :: string,
							Era = era,
							Ground = ground,
							Kind = lotKind,
							Corner = corner,
							Road = i,
							Side = side,
							Fx1 = x1,
							Fx2 = x2,
							Fz1 = z1,
							Fz2 = z2,
						}
						table.insert(lots, lot)
						stats.Placed += 1
						stats["Zone_" .. (zone :: string)] = (stats["Zone_" .. (zone :: string)] or 0) + 1
						if ground == "yard" then
							stats.Yards += 1
						end
						if corner then
							stats.Corner += 1
						end
						placed = true
						t += wl + range(rng, prof.gap)
						break
					elseif why == "keep" then
						stats.KeepHits += 1
					elseif why == "lot" then
						stats.LotHits += 1
					end
				end
				if hitRoad then
					stats.RoadHits += 1
				end
				if not placed then
					t += 3
				end
			end
		end
	end

	-- ตรวจซ้ำอิสระ: ตึกที่ทับถนน (ไม่รวมทางเท้า) ต้องเป็น 0
	local overlaps = 0
	for _, lot in lots do
		for j, r in roads do
			if r[6] ~= "T" then
				local x1, x2, z1, z2 = World.RoadRect(r, 0)
				if lot.Fx1 < x2 and x1 < lot.Fx2 and lot.Fz1 < z2 and z1 < lot.Fz2 then
					overlaps += 1
					break
				end
			end
		end
		indexLot(lot)
	end
	stats.Overlaps = overlaps
	cache = { Lots = lots, Stats = stats }
	return lots
end

function LotGen.Stats(): { [string]: any }
	LotGen.generate()
	return (cache :: any).Stats
end

-- มีตึกครอบจุด (x, z) (ขยายขอบด้วย pad) หรือไม่
function LotGen.Hit(x: number, z: number, pad: number): Lot?
	LotGen.generate()
	for _, lot in grid[cellKey(math.floor(x / CELL), math.floor(z / CELL))] or {} do
		if x > lot.Fx1 - pad and x < lot.Fx2 + pad and z > lot.Fz1 - pad and z < lot.Fz2 + pad then
			return lot
		end
	end
	return nil
end

return LotGen
