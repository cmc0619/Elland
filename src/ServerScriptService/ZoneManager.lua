--[[
	ZoneManager
	Handles zone teleportation
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

-- Find spawn location in Workspace (created by WorldBuilder).
-- The spawn name comes from Constants.ZONES[zoneName].SpawnName so
-- there is a single source of truth.
local function findSpawnLocation(zoneName)
	local zoneData = Constants.ZONES[zoneName]
	if not zoneData or not zoneData.SpawnName then
		return nil
	end

	return Workspace:FindFirstChild(zoneData.SpawnName, true)
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
		return false
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return false
	end

	-- Teleport the character (slightly above the spawn pad)
	humanoidRootPart.CFrame = zone.SpawnLocation.CFrame + Vector3.new(0, 3, 0)

	-- Remove any ForceField created during teleport (non-blocking)
	task.spawn(function()
		task.wait(0.1)
		local forceField = character:FindFirstChildOfClass("ForceField")
		if forceField then
			forceField:Destroy()
		end
	end)

	return true
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
		else
			warn("Spawn location not found for", zoneName, "- WorldBuilder should have created it")
		end
	end

	-- Handle teleportation requests from clients
	TeleportRequest.OnServerEvent:Connect(function(player, zoneName)
		self:TeleportToZone(player, zoneName)
	end)

	-- Spawn players at Hub when they join
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			self:TeleportToZone(player, "Hub")
		end)
	end)

	print("ZoneManager initialized")
end

return ZoneManager
