--[[
	CurrencyManager
	Handles all currency transactions across the game
	Unified economy system shared across all zones

	Purchases: the client fires PurchaseRequest with an item ID only. The
	price is looked up server-side in ITEM_CATALOG (built from
	Constants.FASHION.ITEMS), the player is charged, the item is granted
	into PlayerDataService (Zones.FashionBoutique.OwnedItems), and the
	result is reported back to that client via PurchaseResult.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local CurrencyManager = {}
CurrencyManager.PlayerDataService = nil

-- RemoteEvents for client communication
local CurrencyChanged = Instance.new("RemoteEvent")
CurrencyChanged.Name = "CurrencyChanged"
CurrencyChanged.Parent = ReplicatedStorage

local PurchaseRequest = Instance.new("RemoteEvent")
PurchaseRequest.Name = "PurchaseRequest"
PurchaseRequest.Parent = ReplicatedStorage

-- Reports the outcome of a PurchaseRequest back to the requesting client
local PurchaseResult = Instance.new("RemoteEvent")
PurchaseResult.Name = "PurchaseResult"
PurchaseResult.Parent = ReplicatedStorage

-- Currency rewards configuration (keyed by Constants.ZONES names)
local CURRENCY_REWARDS = {
	WordleLibrary = {
		DailyComplete = 50,
	},
	FashionBoutique = {
		OutfitCreate = 15,
		ShowcaseWin = 100,
		DailyVisit = 20,
	},
	BuildingArea = {
		BuildSave = 20,
		BuildShowcase = 75,
		DailyBuild = 30,
	},
}

-- Server-side item price catalog, built from Constants.FASHION.ITEMS so
-- item definitions have a single source of truth. PurchaseRequest
-- ignores any cost sent by the client and only trusts prices here.
local ITEM_CATALOG = {}
for _, item in ipairs(Constants.FASHION.ITEMS) do
	ITEM_CATALOG[item.Id] = item.Cost
end

-- Get player's current currency
function CurrencyManager:GetCurrency(player)
	if not self.PlayerDataService then
		warn("CurrencyManager: PlayerDataService not initialized")
		return 0
	end

	local data = self.PlayerDataService:GetData(player)
	if data then
		return data.Currency or 0
	end

	return 0
end

-- Add currency to player
function CurrencyManager:AddCurrency(player, amount, reason)
	if not self.PlayerDataService then
		warn("CurrencyManager: PlayerDataService not initialized")
		return false
	end

	if type(amount) ~= "number" or amount <= 0 then
		warn("CurrencyManager: Cannot add non-positive currency amount:", amount)
		return false
	end

	local data = self.PlayerDataService:GetData(player)
	if not data then
		warn("CurrencyManager: No data found for", player.Name)
		return false
	end

	local newAmount = (data.Currency or 0) + amount
	self.PlayerDataService:UpdateData(player, "Currency", newAmount)

	-- Notify client
	CurrencyChanged:FireClient(player, newAmount, amount)

	return true
end

-- Remove currency from player
function CurrencyManager:RemoveCurrency(player, amount, reason)
	if not self.PlayerDataService then
		warn("CurrencyManager: PlayerDataService not initialized")
		return false
	end

	if type(amount) ~= "number" or amount <= 0 then
		warn("CurrencyManager: Cannot remove non-positive currency amount:", amount)
		return false
	end

	local data = self.PlayerDataService:GetData(player)
	if not data then
		warn("CurrencyManager: No data found for", player.Name)
		return false
	end

	local currentAmount = data.Currency or 0

	if currentAmount < amount then
		return false
	end

	local newAmount = currentAmount - amount
	self.PlayerDataService:UpdateData(player, "Currency", newAmount)

	-- Notify client
	CurrencyChanged:FireClient(player, newAmount, -amount)

	return true
end

-- Check if player can afford something
function CurrencyManager:CanAfford(player, amount)
	return self:GetCurrency(player) >= amount
end

-- Get the list of item IDs the player owns (Fashion Boutique inventory)
function CurrencyManager:GetOwnedItems(player)
	if not self.PlayerDataService then
		return {}
	end

	local data = self.PlayerDataService:GetData(player)
	if not data or not data.Zones or not data.Zones.FashionBoutique then
		return {}
	end

	return data.Zones.FashionBoutique.OwnedItems or {}
end

-- Check if the player already owns an item
function CurrencyManager:PlayerOwnsItem(player, itemId)
	return table.find(self:GetOwnedItems(player), itemId) ~= nil
end

-- Award currency for activity completion
function CurrencyManager:AwardActivity(player, zone, activity)
	if not CURRENCY_REWARDS[zone] then
		warn("CurrencyManager: Unknown zone:", zone)
		return false
	end

	if not CURRENCY_REWARDS[zone][activity] then
		warn("CurrencyManager: Unknown activity:", activity, "in zone:", zone)
		return false
	end

	local amount = CURRENCY_REWARDS[zone][activity]
	local reason = string.format("%s - %s", zone, activity)

	return self:AddCurrency(player, amount, reason)
end

-- Handle purchase requests from client. The client only identifies the
-- item; the price is always looked up server-side in ITEM_CATALOG.
-- Validates, charges, grants the item into player data, and reports the
-- outcome to the client via PurchaseResult.
function CurrencyManager:HandlePurchaseRequest(player, itemId)
	local function fail(message)
		PurchaseResult:FireClient(player, {
			success = false,
			itemId = itemId,
			error = message,
		})
		return false
	end

	if type(itemId) ~= "string" then
		return fail("Invalid item")
	end

	local cost = ITEM_CATALOG[itemId]
	if not cost then
		warn("CurrencyManager: Unknown item", itemId, "requested by", player.Name)
		return fail("Unknown item")
	end

	-- Prevent buying the same item twice
	if self:PlayerOwnsItem(player, itemId) then
		return fail("Already owned")
	end

	if not self:CanAfford(player, cost) then
		return fail("Not enough " .. Constants.CURRENCY_NAME)
	end

	if not self:RemoveCurrency(player, cost, "Purchase: " .. itemId) then
		return fail("Purchase failed")
	end

	-- Grant the item into saved player data
	local owned = self:GetOwnedItems(player)
	table.insert(owned, itemId)
	self.PlayerDataService:UpdateData(player, "Zones.FashionBoutique.OwnedItems", owned)

	PurchaseResult:FireClient(player, {
		success = true,
		itemId = itemId,
		cost = cost,
	})

	return true
end

-- Initialize the manager
function CurrencyManager:Init(playerDataService)
	self.PlayerDataService = playerDataService

	-- Handle purchase requests (itemId only; client-sent cost is ignored)
	PurchaseRequest.OnServerEvent:Connect(function(player, itemId)
		self:HandlePurchaseRequest(player, itemId)
	end)

	-- Notify players of their currency once their data is loaded
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			-- Wait for PlayerDataService to finish loading
			while not self.PlayerDataService:GetData(player) and player.Parent do
				task.wait(0.5)
			end
			if player.Parent then
				CurrencyChanged:FireClient(player, self:GetCurrency(player), 0)
			end
		end)
	end)

	-- Also handle players already in game (for Studio testing)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			task.wait(1)
			CurrencyChanged:FireClient(player, self:GetCurrency(player), 0)
		end)
	end

	print("CurrencyManager initialized")
end

return CurrencyManager
