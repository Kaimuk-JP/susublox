--!strict
-- ซื้อของด้วยเยน + Robux (Game Pass / Developer Product)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Shop)
local PlayerData = require(script.Parent.PlayerData)

local remote = Instance.new("RemoteEvent")
remote.Name = "ShopRemote"
remote.Parent = ReplicatedStorage

local function pushYen(player: Player)
	local p = PlayerData.Get(player)
	if p then
		player:SetAttribute("Yen", p.Yen)
	end
end

-- ซื้อด้วยเยน: ตรวจราคา/ความเป็นเจ้าของฝั่ง server เสมอ
remote.OnServerEvent:Connect(function(player: Player, id: unknown)
	local p = PlayerData.Get(player)
	if not p or typeof(id) ~= "string" then
		return
	end
	local item = Shop.Items[id]
	if not item or p.Yen < item.Price then
		return
	end
	if item.Kind == "Outfit" then
		if table.find(p.Owned, id) then
			return
		end
		table.insert(p.Owned, id)
	elseif id == "StatReset" then
		local total = 0
		local stats: any = p.Stats
		for stat, v in stats do
			total += v
			stats[stat] = 0
		end
		p.StatPoints += total
		player:SetAttribute("StatPoints", p.StatPoints)
	end
	p.Yen -= item.Price
	pushYen(player)
end)

-- Game Pass: เจ้าของตรวจจาก Marketplace แล้วเก็บลงโปรไฟล์
local function checkPasses(player: Player)
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	for name, id in Shop.GamePasses do
		if id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns then
				p.Passes[name] = true
			end
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	local p = PlayerData.Get(player)
	if not p then
		return
	end
	for name, id in Shop.GamePasses do
		if id == passId then
			p.Passes[name] = true
		end
	end
end)

-- ProcessReceipt: ให้ของก่อนแล้วค่อยคืน PurchaseGranted และกันซ้ำด้วย PurchaseId
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local p = PlayerData.Get(player)
	if not p then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if p.Receipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if info.ProductId == Shop.Products.ExpBoost30 and info.ProductId ~= 0 then
		p.ExpBoostUntil = math.max(os.time(), p.ExpBoostUntil) + Shop.ExpBoostSeconds
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	p.Receipts[info.PurchaseId] = true
	PlayerData.Save(player) -- บันทึกทันที กันของหายถ้าเซิร์ฟเวอร์ดับ
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

Players.PlayerAdded:Connect(function(player)
	for _ = 1, 100 do
		if PlayerData.Get(player) then
			break
		end
		task.wait(0.2)
	end
	checkPasses(player)
end)
