--[[
	PlayerDataService
	Handles player data loading, saving, and management using Roblox's
	built-in DataStoreService (raw GetAsync/SetAsync with retry logic).
	Persistent storage for player progress, currency, and unlocks across
	all zones.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local PlayerDataService = {}

-- DataStore setup
local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

-- Default player data structure.
-- LastPlayed is set at data-creation time (not at module load).
local DEFAULT_DATA = {
	Currency = Constants.STARTING_CURRENCY, -- 100
	Level = 1,
	Experience = 0,
	Zones = {
		WordleLibrary = {
			Completed = {},
			BestScores = {},
		},
		FashionBoutique = {
			OwnedItems = {},
			CurrentOutfit = {},
		},
		BuildingArea = {
			Builds = {},
		},
	},
	Settings = {
		MusicVolume = 0.7,
		SFXVolume = 0.8,
	},
	LastPlayed = nil,
}

-- Active player data cache
local PlayerDataCache = {}

-- Deep copy function for tables
local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

-- Merge saved data with default data (adds new fields if defaults updated)
local function mergeData(savedData, defaultData)
	local merged = deepCopy(defaultData)

	for key, value in pairs(savedData) do
		if type(value) == "table" and type(merged[key]) == "table" then
			merged[key] = mergeData(value, merged[key])
		else
			merged[key] = value
		end
	end

	return merged
end

-- Load player data from DataStore
function PlayerDataService:LoadData(player)
	local userId = player.UserId
	local success, data

	-- Retry logic for DataStore calls
	local retries = 3
	for i = 1, retries do
		success, data = pcall(function()
			return PlayerDataStore:GetAsync(userId)
		end)

		if success then
			break
		else
			warn("Failed to load data for", player.Name, "- Attempt", i, "/", retries)
			if i < retries then
				task.wait(1)
			end
		end
	end

	if success then
		if data then
			-- Merge with defaults to add any new fields
			data = mergeData(data, DEFAULT_DATA)
			print("Loaded data for", player.Name)
		else
			-- New player: stamp LastPlayed at creation time
			data = deepCopy(DEFAULT_DATA)
			data.LastPlayed = os.time()
			print("Created new data for", player.Name)
		end

		PlayerDataCache[userId] = data
		return true, data
	else
		warn("Failed to load data for", player.Name, "after", retries, "attempts")
		return false, nil
	end
end

-- Save player data to DataStore
function PlayerDataService:SaveData(player)
	local userId = player.UserId
	local data = PlayerDataCache[userId]

	if not data then
		warn("No data to save for", player.Name)
		return false
	end

	-- Update last played timestamp
	data.LastPlayed = os.time()

	local success
	local retries = 3

	for i = 1, retries do
		success = pcall(function()
			PlayerDataStore:SetAsync(userId, data)
		end)

		if success then
			return true
		else
			warn("Failed to save data for", player.Name, "- Attempt", i, "/", retries)
			if i < retries then
				task.wait(1)
			end
		end
	end

	warn("Failed to save data for", player.Name, "after", retries, "attempts")
	return false
end

-- Get player data from cache
function PlayerDataService:GetData(player)
	return PlayerDataCache[player.UserId]
end

-- Update specific data field
function PlayerDataService:UpdateData(player, path, value)
	local data = PlayerDataCache[player.UserId]
	if not data then
		warn("No data found for", player.Name)
		return false
	end

	-- Handle nested paths like "Zones.WordleLibrary.Completed"
	local keys = string.split(path, ".")
	local current = data

	for i = 1, #keys - 1 do
		if not current[keys[i]] then
			current[keys[i]] = {}
		end
		current = current[keys[i]]
	end

	current[keys[#keys]] = value
	return true
end

-- Remove player data from cache
function PlayerDataService:UnloadData(player)
	PlayerDataCache[player.UserId] = nil
end

-- Initialize service
function PlayerDataService:Init()
	-- DataStores don't work in Studio without API access enabled
	local isStudio = RunService:IsStudio()

	-- Handle player joining
	Players.PlayerAdded:Connect(function(player)
		local success = self:LoadData(player)

		if not success then
			if isStudio then
				-- In Studio without API access, just use default data
				warn("Studio mode: Using default data for", player.Name)
				local data = deepCopy(DEFAULT_DATA)
				data.LastPlayed = os.time()
				PlayerDataCache[player.UserId] = data
			else
				-- In production, kick player if data fails to load
				player:Kick("Failed to load player data. Please rejoin.")
			end
		end
	end)

	-- Handle player leaving
	Players.PlayerRemoving:Connect(function(player)
		self:SaveData(player)
		self:UnloadData(player)
	end)

	-- Auto-save every 5 minutes
	task.spawn(function()
		while true do
			task.wait(300)
			for _, player in ipairs(Players:GetPlayers()) do
				self:SaveData(player)
			end
		end
	end)

	-- Save all data on server shutdown
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			self:SaveData(player)
		end
		task.wait(3) -- Give time for saves to complete
	end)

	print("PlayerDataService initialized")
end

return PlayerDataService
