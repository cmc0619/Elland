--[[
	WorldUtils
	Small shared geometry helpers for world builders: distance to the
	meandering river centerline and point-to-segment distance. The river
	path is recomputed from Constants.WORLD so it always matches the
	channel carved by WorldBuilder:CreateRiver().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local WorldUtils = {}

local riverPoints = nil

-- Recompute the river centerline (same formula as WorldBuilder:CreateRiver)
local function buildRiverPoints()
	riverPoints = {}

	local riverStart = Constants.WORLD.RIVER_START
	local riverEnd = Constants.WORLD.RIVER_END
	local segments = 100
	local totalDist = (riverEnd - riverStart).Magnitude
	local dir = (riverEnd - riverStart).Unit
	local perp = Vector3.new(-dir.Z, 0, dir.X)

	for i = 0, segments do
		local t = i / segments
		local basePos = riverStart + (dir * (totalDist * t))
		local meanderOffset = math.sin(t * math.pi * 4) * 30
		table.insert(riverPoints, basePos + (perp * meanderOffset))
	end
end

-- Horizontal distance from a world position to the river centerline
function WorldUtils:DistanceToRiver(position)
	if not riverPoints then
		buildRiverPoints()
	end

	local minSq = math.huge
	for _, point in ipairs(riverPoints) do
		local dx = position.X - point.X
		local dz = position.Z - point.Z
		local distSq = dx * dx + dz * dz
		if distSq < minSq then
			minSq = distSq
		end
	end

	return math.sqrt(minSq)
end

function WorldUtils:IsNearRiver(position, clearance)
	return self:DistanceToRiver(position) < clearance
end

-- Horizontal distance from point p to the segment a-b (Y ignored)
function WorldUtils:DistanceToSegment2D(p, a, b)
	local abX = b.X - a.X
	local abZ = b.Z - a.Z
	local apX = p.X - a.X
	local apZ = p.Z - a.Z

	local lengthSq = abX * abX + abZ * abZ
	local t = 0
	if lengthSq > 0 then
		t = math.clamp((apX * abX + apZ * abZ) / lengthSq, 0, 1)
	end

	local closestX = a.X + abX * t
	local closestZ = a.Z + abZ * t

	local dx = p.X - closestX
	local dz = p.Z - closestZ
	return math.sqrt(dx * dx + dz * dz)
end

-- Distance from a point to the nearest Hub-to-zone walking path
function WorldUtils:DistanceToNearestPath(position)
	local hubPos = Constants.ZONES.Hub.Position
	local hub2D = Vector3.new(hubPos.X, 0, hubPos.Z)

	local nearest = math.huge
	for zoneName, zone in pairs(Constants.ZONES) do
		if zoneName ~= "Hub" then
			local to2D = Vector3.new(zone.Position.X, 0, zone.Position.Z)
			nearest = math.min(nearest, self:DistanceToSegment2D(position, hub2D, to2D))
		end
	end

	return nearest
end

return WorldUtils
