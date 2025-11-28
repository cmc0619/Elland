--[[
	ZoneManager
	Handles zone teleportation and zone-specific logic
	All zones are accessible from the start - no progression gates
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ZoneManager = {}

-- RemoteEvent for teleportation requests
local TeleportRequest = Instance.new("RemoteEvent")
TeleportRequest.Name = "TeleportRequest"
TeleportRequest.Parent = ReplicatedStorage

-- Zone spawn locations (to be set in Workspace)
-- These will be SpawnLocation parts in each zone folder
local ZONES = {
	Hub = {
		Name = "Central Hub",
		Description = "The heart of Elland - choose your next adventure!",
		SpawnLocation = nil, -- Will be set during Init
	},
	WordGarden = {
		Name = "Word Garden",
		Description = "Grow your vocabulary with word puzzles and language games",
		SpawnLocation = nil,
	},
	FashionDistrict = {
		Name = "Fashion District",
		Description = "Express yourself through style and creativity",
		SpawnLocation = nil,
	},
	MathAcademy = {
		Name = "Math Academy",
		Description = "Sharpen your mind with algebra and number challenges",
		SpawnLocation = nil,
	},
	CreativeCommons = {
		Name = "Creative Commons",
		Description = "Build, design, and showcase your creations",
		SpawnLocation = nil,
	},
}

-- Create or find spawn location for a zone
local function getOrCreateSpawnLocation(zoneName, parentFolder)
	local spawnLocation = parentFolder:FindFirstChild("SpawnLocation")

	if not spawnLocation then
		-- Create a spawn location if it doesn't exist
		spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "SpawnLocation"
		spawnLocation.Transparency = 0.5
		spawnLocation.Size = Vector3.new(8, 1, 8)
		spawnLocation.Anchored = true
		spawnLocation.CanCollide = true

		-- Position it in a grid pattern based on zone
		local positions = {
			Hub = Vector3.new(0, 5, 0),
			WordGarden = Vector3.new(100, 5, 0),
			FashionDistrict = Vector3.new(-100, 5, 0),
			MathAcademy = Vector3.new(0, 5, 100),
			CreativeCommons = Vector3.new(0, 5, -100),
		}

		spawnLocation.Position = positions[zoneName] or Vector3.new(0, 5, 0)
		spawnLocation.Parent = parentFolder

		print("Created spawn location for", zoneName)
	end

	return spawnLocation
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
	-- Set up spawn locations for each zone
	local zonesFolder = Workspace:FindFirstChild("Zones")

	if zonesFolder then
		-- Set up named zones
		for zoneName, zoneData in pairs(ZONES) do
			if zoneName ~= "Hub" then
				local zoneFolder = zonesFolder:FindFirstChild(zoneName)
				if zoneFolder then
					ZONES[zoneName].SpawnLocation = getOrCreateSpawnLocation(zoneName, zoneFolder)
				else
					warn("Zone folder not found:", zoneName)
				end
			end
		end
	else
		warn("Zones folder not found in Workspace")
	end

	-- Create hub spawn location in Workspace root
	local hubFolder = Workspace:FindFirstChild("Hub")
	if not hubFolder then
		hubFolder = Instance.new("Folder")
		hubFolder.Name = "Hub"
		hubFolder.Parent = Workspace
	end
	ZONES.Hub.SpawnLocation = getOrCreateSpawnLocation("Hub", hubFolder)

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
