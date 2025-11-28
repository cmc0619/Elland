--[[
	ZoneManager
	Handles zone teleportation and zone-specific logic
	All zones are accessible from the start - no progression gates
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local ZoneManager = {}

-- RemoteEvent for teleportation requests
local TeleportRequest = Instance.new("RemoteEvent")
TeleportRequest.Name = "TeleportRequest"
TeleportRequest.Parent = ReplicatedStorage

-- Zone spawn locations (populated from Constants and Workspace)
local ZONES = {}

-- Find spawn location in Workspace (created by WorldBuilder)
local function findSpawnLocation(zoneName)
	-- Spawn locations are named like "LookoutSpawn", "HouseSpawn", etc.
	local spawnNames = {
		Hub = "HubSpawn",
		EllasLookout = "LookoutSpawn",
		EllasHouse = "HouseSpawn",
		WordleLibrary = "LibrarySpawn",
		FashionBoutique = "BoutiqueSpawn",
		BuildingArea = "BuildingSpawn",
	}

	local spawnName = spawnNames[zoneName]
	if not spawnName then
		return nil
	end

	local spawn = Workspace:FindFirstChild(spawnName, true)
	return spawn
end

-- Teleport player to a zone
function ZoneManager:TeleportToZone(player, zoneName)
	local zone = ZONES[zoneName]

	if not zone then
		warn("Invalid zone:", zoneName)
		return false
	end

	if not zone.SpawnLocation then
		warn("Spawn location not found for zone:", zoneName)
		return false
	end

	local character = player.Character
	if not character then
		warn("Character not found for", player.Name)
		return false
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		warn("HumanoidRootPart not found for", player.Name)
		return false
	end

	-- Teleport the character
	local spawnCFrame = zone.SpawnLocation.CFrame
	humanoidRootPart.CFrame = spawnCFrame + Vector3.new(0, 3, 0) -- Spawn slightly above

	print(player.Name, "teleported to", zone.Name)

	return true
end

-- Get list of all zones (for UI)
function ZoneManager:GetZonesList()
	local zonesList = {}

	for zoneName, zoneData in pairs(ZONES) do
		table.insert(zonesList, {
			Id = zoneName,
			Name = zoneData.Name,
			Description = zoneData.Description,
		})
	end

	return zonesList
end

-- Get current zone of a player
function ZoneManager:GetPlayerZone(player)
	local character = player.Character
	if not character then
		return nil
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return nil
	end

	local playerPosition = humanoidRootPart.Position

	-- Find which zone the player is in based on proximity
	local closestZone = nil
	local closestDistance = math.huge

	for zoneName, zoneData in pairs(ZONES) do
		if zoneData.SpawnLocation then
			local distance = (playerPosition - zoneData.SpawnLocation.Position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestZone = zoneName
			end
		end
	end

	return closestZone
end

-- Initialize the manager
function ZoneManager:Init()
	-- Populate ZONES from Constants
	for zoneName, zoneData in pairs(Constants.ZONES) do
		ZONES[zoneName] = {
			Name = zoneData.Name,
			Description = zoneData.Description,
			Position = zoneData.Position,
			SpawnLocation = nil,
		}
	end

	-- Find spawn locations created by WorldBuilder
	for zoneName, zoneData in pairs(ZONES) do
		local spawn = findSpawnLocation(zoneName)
		if spawn then
			zoneData.SpawnLocation = spawn
			print("Found spawn location for", zoneName)
		else
			warn("Spawn location not found for", zoneName, "- run WorldBuilder to create it")
		end
	end

	-- Handle teleportation requests from clients
	TeleportRequest.OnServerEvent:Connect(function(player, zoneName)
		self:TeleportToZone(player, zoneName)
	end)

	-- Spawn players at Hub when they join
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			wait(0.5) -- Wait for character to fully load
			self:TeleportToZone(player, "Hub")
		end)
	end)

	print("ZoneManager initialized")
end

return ZoneManager
