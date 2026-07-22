--[[
	BuildingSandbox
	Turns the Building Area platform into a working build sandbox.

	Flow:
	  - A "Get Build Tool" ProximityPrompt at the platform gives the player
	    a code-created Build Tool (Tool + Handle).
	  - The client (BuildToolClient) fires BuildPlaceRequest with the mouse
	    hit position on click, and BuildDeleteRequest with the mouse target
	    on R / right-click.
	  - The server validates everything: plot bounds, 2-stud grid snap,
	    per-player block cap, and a placement rate limit. Blocks live in
	    Workspace/PlayerBuilds/<UserId> and only their owner can delete them.
	  - A "Clear my plot" prompt removes all of the player's blocks.

	Blocks do NOT persist across sessions yet (session-only sandbox);
	saving builds to the DataStore is future work (see Constants.BUILDING).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local BuildingSandbox = {}

local SANDBOX = Constants.BUILDING_SANDBOX

-- RemoteEvents (created at module load so clients can WaitForChild them)
local BuildPlaceRequest = Instance.new("RemoteEvent")
BuildPlaceRequest.Name = "BuildPlaceRequest"
BuildPlaceRequest.Parent = ReplicatedStorage

local BuildDeleteRequest = Instance.new("RemoteEvent")
BuildDeleteRequest.Name = "BuildDeleteRequest"
BuildDeleteRequest.Parent = ReplicatedStorage

-- Runtime state
local buildsFolder = nil -- Workspace/PlayerBuilds
local lastPlaceTime = {} -- [UserId] = os.clock() of last accepted placement

-- The plot is the BuildingPlatform footprint on top of the base terrain
local function getPlotInfo()
	local zonePos = Constants.ZONES.BuildingArea.Position
	local platformTop = Constants.WORLD.GROUND_LEVEL + 1 -- Platform is 1 stud thick
	return zonePos, platformTop, SANDBOX.PLOT_HALF_SIZE
end

local function getPlayerFolder(player)
	local folder = buildsFolder:FindFirstChild(tostring(player.UserId))
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = tostring(player.UserId)
		folder.Parent = buildsFolder
	end
	return folder
end

-- Snap a world position to the build grid, resting on the platform surface
local function snapToGrid(position)
	local _, platformTop = getPlotInfo()
	local grid = SANDBOX.GRID_SIZE
	local x = math.round(position.X / grid) * grid
	local z = math.round(position.Z / grid) * grid
	local y = platformTop + SANDBOX.BLOCK_SIZE.Y / 2
	return Vector3.new(x, y, z)
end

local function isInsidePlot(position)
	local zonePos, _, halfSize = getPlotInfo()
	return math.abs(position.X - zonePos.X) <= halfSize
		and math.abs(position.Z - zonePos.Z) <= halfSize
end

-- Server-authoritative block placement
function BuildingSandbox:HandlePlaceRequest(player, position)
	if typeof(position) ~= "Vector3" then
		return
	end

	-- Reject NaN/absurd coordinates before any math
	if position.Magnitude ~= position.Magnitude or position.Magnitude > 10000 then
		return
	end

	-- Rate limit
	local now = os.clock()
	local last = lastPlaceTime[player.UserId] or 0
	if now - last < SANDBOX.PLACE_COOLDOWN then
		return
	end

	local snapped = snapToGrid(position)
	if not isInsidePlot(snapped) then
		return
	end

	local folder = getPlayerFolder(player)
	local blockCount = #folder:GetChildren()
	if blockCount >= SANDBOX.MAX_BLOCKS_PER_PLAYER then
		return
	end

	lastPlaceTime[player.UserId] = now

	-- Cycle through the pastel palette per placement
	local palette = SANDBOX.PASTEL_COLORS
	local color = palette[(blockCount % #palette) + 1]

	local block = Instance.new("Part")
	block.Name = "BuildBlock"
	block.Size = SANDBOX.BLOCK_SIZE
	block.Position = snapped
	block.Anchored = true
	block.Material = Enum.Material.SmoothPlastic
	block.Color = color
	block.TopSurface = Enum.SurfaceType.Smooth
	block.BottomSurface = Enum.SurfaceType.Smooth
	block:SetAttribute("OwnerUserId", player.UserId)
	block.Parent = folder
end

-- Only the owner can delete, and only their own blocks
function BuildingSandbox:HandleDeleteRequest(player, target)
	if typeof(target) ~= "Instance" or not target:IsA("BasePart") then
		return
	end

	if target.Name ~= "BuildBlock" then
		return
	end

	if target:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end

	local folder = buildsFolder:FindFirstChild(tostring(player.UserId))
	if not folder or target.Parent ~= folder then
		return
	end

	target:Destroy()
end

-- Give the player the build tool (code-created; behavior lives in
-- BuildToolClient so no Script needs to be nested inside the Tool)
function BuildingSandbox:GiveBuildTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not backpack then
		return
	end

	-- Don't hand out duplicates
	if backpack:FindFirstChild("BuildTool") or (character and character:FindFirstChild("BuildTool")) then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = "BuildTool"
	tool.ToolTip = "Click: place block | R or Right-click: delete"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 3, 1)
	handle.BrickColor = BrickColor.new("Bright orange")
	handle.Material = Enum.Material.SmoothPlastic
	handle.Parent = tool

	tool.Parent = backpack
end

-- ProximityPrompts on the build platform: get the tool, clear your plot
function BuildingSandbox:CreatePrompts()
	local zonePos, platformTop = getPlotInfo()

	local function makePromptPart(name, offset, color, actionText, objectText)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(6, 6, 6)
		part.Position = zonePos + offset
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 0.5
		part.BrickColor = color
		part.Material = Enum.Material.Neon
		part.Parent = Workspace

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 15
		prompt.Parent = part

		return prompt
	end

	local toolPrompt = makePromptPart(
		"BuildToolPrompt",
		Vector3.new(0, platformTop + 3 - Constants.WORLD.GROUND_LEVEL, 30),
		BrickColor.new("Bright yellow"),
		"Get Build Tool",
		"Building Area"
	)
	toolPrompt.Triggered:Connect(function(player)
		self:GiveBuildTool(player)
	end)

	local clearPrompt = makePromptPart(
		"ClearPlotPrompt",
		Vector3.new(0, platformTop + 3 - Constants.WORLD.GROUND_LEVEL, -30),
		BrickColor.new("Bright red"),
		"Clear My Plot",
		"Building Area"
	)
	clearPrompt.Triggered:Connect(function(player)
		local folder = buildsFolder:FindFirstChild(tostring(player.UserId))
		if folder then
			folder:ClearAllChildren()
		end
	end)
end

function BuildingSandbox:Init()
	-- Fresh container for this session's builds
	local old = Workspace:FindFirstChild("PlayerBuilds")
	if old then
		old:Destroy()
	end

	buildsFolder = Instance.new("Folder")
	buildsFolder.Name = "PlayerBuilds"
	buildsFolder.Parent = Workspace

	BuildPlaceRequest.OnServerEvent:Connect(function(player, position)
		self:HandlePlaceRequest(player, position)
	end)

	BuildDeleteRequest.OnServerEvent:Connect(function(player, target)
		self:HandleDeleteRequest(player, target)
	end)

	self:CreatePrompts()

	-- Clean up per-player state on leave (blocks are session-only)
	Players.PlayerRemoving:Connect(function(player)
		lastPlaceTime[player.UserId] = nil
		local folder = buildsFolder:FindFirstChild(tostring(player.UserId))
		if folder then
			folder:Destroy()
		end
	end)

	print("BuildingSandbox initialized")
end

return BuildingSandbox
