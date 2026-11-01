--!strict
-- จับเวลา builder ฝั่ง server และตั้ง workspace attribute "GameReady" เมื่อ builder ท้ายๆ ทำงานครบ (หน้าโหลดฝั่ง client รอสัญญาณนี้)
local BuildSync = {}

local EXPECTED = { "WorldBuilder", "AlleyLife", "CityDressing", "StreetScape", "StreetFurniture", "RoadBed", "TidyGround", "NightCity" }
local done: { [string]: boolean } = {}
local start = os.clock()

function BuildSync.finish(name: string, t0: number)
	print(string.format("[Build] %s %.1fs (รวมตั้งแต่เริ่ม %.1fs)", name, os.clock() - t0, os.clock() - start))
	done[name] = true
	for _, n in EXPECTED do
		if not done[n] then
			return
		end
	end
	if workspace:GetAttribute("GameReady") ~= true then
		workspace:SetAttribute("GameReady", true)
		print(string.format("[Build] GameReady ที่ %.1fs", os.clock() - start))
	end
end

return BuildSync
