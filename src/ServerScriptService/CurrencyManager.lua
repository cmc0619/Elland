--[[
	CurrencyManager
	Handles all currency transactions across the game
	Unified economy system shared across all zones
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyManager = {}
CurrencyManager.PlayerDataService = nil

-- RemoteEvents for client communication
local CurrencyChanged = Instance.new("RemoteEvent")
CurrencyChanged.Name = "CurrencyChanged"
CurrencyChanged.Parent = ReplicatedStorage

local PurchaseRequest = Instance.new("RemoteEvent")
PurchaseRequest.Name = "PurchaseRequest"
PurchaseRequest.Parent = ReplicatedStorage

-- Currency rewards configuration
local CURRENCY_REWARDS = {
	WordGarden = {
		PuzzleComplete = 10,
		PerfectScore = 25,
		DailyChallenge = 50,
	},
	FashionDistrict = {
		OutfitCreate = 15,
		ShowcaseWin = 100,
		DailyVisit = 20,
	},
	MathAcademy = {
		ProblemSolved = 10,
		QuizComplete = 50,
		PerfectQuiz = 100,
	},
	CreativeCommons = {
		BuildSave = 20,
		BuildShowcase = 75,
		DailyBuild = 30,
	},
}

-- Get player's current currency
function CurrencyManager:GetCurrency(player)
	if not self.PlayerDataService then
		warn("PlayerDataService not initialized")
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
		warn("PlayerDataService not initialized")
		return false
	end

	if amount <= 0 then
		warn("Cannot add non-positive currency amount:", amount)
		return false
	end

	local data = self.PlayerDataService:GetData(player)
	if not data then
		warn("No data found for", player.Name)
		return false
	end

	local oldAmount = data.Currency or 0
	local newAmount = oldAmount + amount

	self.PlayerDataService:UpdateData(player, "Currency", newAmount)

	print(player.Name, "earned", amount, "currency.", "Reason:", reason or "Unknown")
	print(player.Name, "total currency:", newAmount)

	-- Notify client
	CurrencyChanged:FireClient(player, newAmount, amount)

	return true
end

-- Remove currency from player
function CurrencyManager:RemoveCurrency(player, amount, reason)
	if not self.PlayerDataService then
		warn("PlayerDataService not initialized")
		return false
	end

	if amount <= 0 then
		warn("Cannot remove non-positive currency amount:", amount)
		return false
	end

	local data = self.PlayerDataService:GetData(player)
	if not data then
		warn("No data found for", player.Name)
		return false
	end

	local currentAmount = data.Currency or 0

	if currentAmount < amount then
		warn(player.Name, "does not have enough currency. Has:", currentAmount, "Needs:", amount)
		return false
	end

	local newAmount = currentAmount - amount
	self.PlayerDataService:UpdateData(player, "Currency", newAmount)

	print(player.Name, "spent", amount, "currency.", "Reason:", reason or "Unknown")
	print(player.Name, "total currency:", newAmount)

	-- Notify client
	CurrencyChanged:FireClient(player, newAmount, -amount)

	return true
end

-- Check if player can afford something
function CurrencyManager:CanAfford(player, amount)
	local currentAmount = self:GetCurrency(player)
	return currentAmount >= amount
end

-- Award currency for activity completion
function CurrencyManager:AwardActivity(player, zone, activity)
	if not CURRENCY_REWARDS[zone] then
		warn("Unknown zone:", zone)
		return false
	end

	if not CURRENCY_REWARDS[zone][activity] then
		warn("Unknown activity:", activity, "in zone:", zone)
		return false
	end

	local amount = CURRENCY_REWARDS[zone][activity]
	local reason = string.format("%s - %s", zone, activity)

	return self:AddCurrency(player, amount, reason)
end

-- Handle purchase requests from client
function CurrencyManager:HandlePurchaseRequest(player, itemId, cost)
	if not self:CanAfford(player, cost) then
		warn(player.Name, "cannot afford item", itemId, "- Cost:", cost)
		return false
	end

	-- Remove currency
	local success = self:RemoveCurrency(player, cost, "Purchase: " .. itemId)

	if success then
		print(player.Name, "purchased", itemId, "for", cost)
		return true
	end

	return false
end

-- Initialize the manager
function CurrencyManager:Init(playerDataService)
	self.PlayerDataService = playerDataService

	-- Handle purchase requests
	PurchaseRequest.OnServerEvent:Connect(function(player, itemId, cost)
		local success = self:HandlePurchaseRequest(player, itemId, cost)
		-- You would typically fire back a response event here
		-- and handle the actual item granting in a separate system
	end)

	-- Notify players of their currency on join
	Players.PlayerAdded:Connect(function(player)
		-- Wait for data to load
		wait(1)
		local currency = self:GetCurrency(player)
		CurrencyChanged:FireClient(player, currency, 0)
	end)

	print("CurrencyManager initialized")
end

return CurrencyManager
