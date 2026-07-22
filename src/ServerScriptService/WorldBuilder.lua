--[[
	WorldBuilder
	Generates the terrain and builds the structures for Elland.

	Init.server.lua calls WorldBuilder:BuildWorld() on EVERY server start
	(it cleans up any previously built world first), so this module must
	stay idempotent. There is no separate "run once in Studio" step.

	When the build finishes, Workspace:GetAttribute("WorldBuilt") is set
	to true so other services (e.g. InteractionManager) can wait on the
	world deterministically instead of guessing with task.wait().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local WorldBuilder = {}

local GROUND_LEVEL = 10 -- Top surface of the base terrain (Y=0 to Y=10)

-- Create grass terrain
function WorldBuilder:CreateTerrain()
	print("Creating terrain...")

	local terrain = Workspace.Terrain
	terrain:Clear()

	-- Thin grass layer: TERRAIN_SIZE is (600, 10, 600), centered at Y=5
	-- so the terrain spans Y=0 to Y=10.
	local size = Constants.WORLD.TERRAIN_SIZE
	local center = Vector3.new(0, size.Y / 2, 0)

	terrain:FillBlock(
		CFrame.new(center),
		size,
		Enum.Material.Grass
	)

	print("Base terrain created")
end

-- Create the meandering river
function WorldBuilder:CreateRiver()
	print("Creating river...")

	local terrain = Workspace.Terrain
	local riverStart = Constants.WORLD.RIVER_START
	local riverEnd = Constants.WORLD.RIVER_END

	-- Create river path with meanders
	local segments = 100 -- Increased to prevent gaps
	local totalDist = (riverEnd - riverStart).Magnitude
	local dir = (riverEnd - riverStart).Unit
	local perp = Vector3.new(-dir.Z, 0, dir.X) -- Perpendicular vector for meandering

	for i = 0, segments do
		local t = i / segments

		-- Base position along the line
		local basePos = riverStart + (dir * (totalDist * t))

		-- Add meandering (sine wave perpendicular to river direction)
		local meanderOffset = math.sin(t * math.pi * 4) * 30
		local pos = basePos + (perp * meanderOffset)

		-- FIRST: Carve the river channel into the terrain.
		-- Ground surface is at Y=10. Carve from Y=5 to Y=15 so the channel
		-- is 5 studs deep and any grass above the waterline is removed.
		local airPos = Vector3.new(pos.X, 10, pos.Z)
		terrain:FillBlock(
			CFrame.new(airPos),
			Vector3.new(28, 10, 28), -- Slightly wider than water for banks
			Enum.Material.Air
		)

		-- SECOND: Lay a sandy riverbed so no grass is left under the water.
		-- Bed fills Y=4.2 to Y=5.4, slightly wider than the water.
		local bedPos = Vector3.new(pos.X, 4.8, pos.Z)
		terrain:FillBlock(
			CFrame.new(bedPos),
			Vector3.new(24, 1.2, 24),
			Enum.Material.Sand
		)

		-- THIRD: Fill with water.
		-- Water fills Y=5 to Y=9.8 (surface just below ground level).
		local waterPos = Vector3.new(pos.X, 7.4, pos.Z)
		terrain:FillBlock(
			CFrame.new(waterPos),
			Vector3.new(22, 4.8, 22), -- Narrower than air carving for natural banks
			Enum.Material.Water
		)
	end

	print("River created - channel carved 5 studs deep, sand bed, water surface at Y=9.8")
end

-- Create Ella's Lookout - the big hill with the wishing tree and swing
function WorldBuilder:CreateEllasLookout()
	print("Creating Ella's Lookout...")

	local pos = Constants.ZONES.EllasLookout.Position -- Y=70 is the TOP of the hill
	local terrain = Workspace.Terrain

	-- Hill parameters
	local hillBaseY = GROUND_LEVEL
	local hillTopY = pos.Y
	local hillHeight = hillTopY - hillBaseY -- 60 studs tall
	local hillCenterX = pos.X
	local hillCenterZ = pos.Z
	local baseRadius = 80 -- Wide base for gentle slope

	-- Create hill using stacked cylinders (creates a cone shape).
	-- NOTE: Terrain:FillCylinder's axis runs along the CFrame's Z axis,
	-- so the CFrame must be rotated 90 degrees to make each layer horizontal.
	local layers = 30
	for i = 0, layers do
		local progress = i / layers -- 0 to 1 from bottom to top

		-- Current layer height
		local layerY = hillBaseY + (hillHeight * progress)

		-- Radius decreases as we go up (creates cone shape)
		local layerRadius = baseRadius * (1 - progress * 0.85) -- Shrinks to 15% at top

		if layerRadius > 3 then
			terrain:FillCylinder(
				CFrame.new(hillCenterX, layerY, hillCenterZ) * CFrame.Angles(math.rad(90), 0, 0),
				4, -- Height of each cylinder layer
				layerRadius,
				Enum.Material.Grass
			)
		end
	end

	-- Add a flat top to the hill for the tree
	terrain:FillCylinder(
		CFrame.new(hillCenterX, hillTopY - 2, hillCenterZ) * CFrame.Angles(math.rad(90), 0, 0),
		4,
		15, -- Flat top radius
		Enum.Material.Grass
	)

	-- The top terrain layer is a 4-stud-thick cylinder CENTERED on hillTopY,
	-- so the real walking surface sits 2 studs above hillTopY. Plant the tree
	-- on the actual surface or the trunk ends up buried in the hilltop.
	local surfaceY = hillTopY + 2

	-- Create the tree ON TOP of the hill
	local tree = Instance.new("Model")
	tree.Name = "WishingTree"

	-- Tree trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(3, 15, 3)
	trunk.Position = Vector3.new(hillCenterX, surfaceY + 7.5, hillCenterZ) -- Trunk base rests on the hilltop surface
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.BrickColor = BrickColor.new("Brown")
	trunk.Parent = tree

	-- Tree foliage
	local foliage = Instance.new("Part")
	foliage.Name = "Foliage"
	foliage.Shape = Enum.PartType.Ball
	foliage.Size = Vector3.new(20, 20, 20)
	foliage.Position = Vector3.new(hillCenterX, surfaceY + 20, hillCenterZ) -- Above trunk
	foliage.Anchored = true
	-- Decorative canopy: the swing hangs just below it, and solid leaves
	-- colliding with the seated player's head is what flipped sitters
	-- upside down. NatureBuilder's trees are non-collidable for the same reason.
	foliage.CanCollide = false
	foliage.Material = Enum.Material.Grass
	foliage.BrickColor = BrickColor.new("Dark green")
	foliage.Parent = tree

	-- Swing branch
	local branch = Instance.new("Part")
	branch.Name = "SwingBranch"
	-- Swing branch, long enough to stick out past the foliage (radius 10) so
	-- the swing hangs clear of the leaves instead of into them
	branch.Size = Vector3.new(16, 1, 1)
	branch.Position = Vector3.new(hillCenterX + 8, surfaceY + 17, hillCenterZ) -- At foliage level
	branch.Anchored = true
	branch.Material = Enum.Material.Wood
	branch.BrickColor = BrickColor.new("Brown")
	branch.Parent = tree

	-- Swing seat hangs DIRECTLY BELOW the branch so the ropes start
	-- vertical and the seat swings as a proper pendulum. (The old build
	-- offset the seat 10 studs sideways with only 8-stud ropes, which
	-- left the ropes permanently taut and the swing broken.)
	local seat = Instance.new("Seat")
	seat.Name = "SwingSeat"
	seat.Size = Vector3.new(4, 0.5, 2)
	local seatPos = branch.Position + Vector3.new(0, -8, 0)
	-- Rotate 90 degrees on Y so the sitter faces outward from the trunk.
	-- NOTE: this maps seat-local +X to world -Z (and -X to world +Z).
	seat.CFrame = CFrame.new(seatPos) * CFrame.Angles(0, math.rad(90), 0)
	seat.Anchored = false
	seat.BrickColor = BrickColor.new("Medium brown")
	seat.Parent = tree

	-- Attachments on the seat (top face, left/right edges)
	local seatAttachL = Instance.new("Attachment")
	seatAttachL.Name = "SeatAttachL"
	seatAttachL.Position = Vector3.new(-1.5, 0.25, 0) -- World Z + 1.5 (seat rotated 90°)
	seatAttachL.Parent = seat

	local seatAttachR = Instance.new("Attachment")
	seatAttachR.Name = "SeatAttachR"
	seatAttachR.Position = Vector3.new(1.5, 0.25, 0) -- World Z - 1.5 (seat rotated 90°)
	seatAttachR.Parent = seat

	-- Attachments on the branch, aligned vertically with the seat attachments.
	-- Because the seat is rotated 90° on Y, SeatAttachL sits on the world +Z
	-- side and SeatAttachR on the world -Z side, so the branch attachments use
	-- matching Z signs to keep each rope straight (uncrossed).
	local branchAttachL = Instance.new("Attachment")
	branchAttachL.Name = "BranchAttachL"
	branchAttachL.Position = Vector3.new(0, -0.5, 1.5)
	branchAttachL.Parent = branch

	local branchAttachR = Instance.new("Attachment")
	branchAttachR.Name = "BranchAttachR"
	branchAttachR.Position = Vector3.new(0, -0.5, -1.5)
	branchAttachR.Parent = branch

	-- Rope constraints connect seat to branch (Visible draws the rope)
	local rope1 = Instance.new("RopeConstraint")
	rope1.Attachment0 = branchAttachL
	rope1.Attachment1 = seatAttachL
	rope1.Length = 7.5
	rope1.Visible = true
	rope1.Parent = seat

	local rope2 = Instance.new("RopeConstraint")
	rope2.Attachment0 = branchAttachR
	rope2.Attachment1 = seatAttachR
	rope2.Length = 7.5
	rope2.Visible = true
	rope2.Parent = seat

	tree.Parent = Workspace

	-- Create spawn location at base of hill (on the flat ground, not on the slope)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LookoutSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(hillCenterX - 100, 12, hillCenterZ) -- Out from hill base
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Bright green")
	spawn.CanCollide = true -- IMPORTANT: Must be true so players don't fall through
	spawn.Duration = 0 -- Remove ForceField
	spawn.Parent = Workspace

	print("Ella's Lookout created - cone hill with working swing")
end

--[[
	BuildStructure
	Shared helper for the repeated base + walls + door + roof + sign pattern
	used by Ella's House, the Wordle Library and the Fashion Boutique.

	config = {
		Name            string
		Position        Vector3 (ground-level center of the footprint)
		Size            Vector3 (footprint X/Z; Y ignored)
		WallHeight      number
		WallColor       BrickColor
		WallMaterial    Enum.Material? (default SmoothPlastic)
		WallTransparency number? (default 0)
		RoofColor       BrickColor
		GabledRoof      boolean? (two wedges, like the house; default flat slab)
		Door            boolean? (add a physical door part; default false)
		SignText        string?
		SignTextColor   Color3?
	}
]]
function WorldBuilder:BuildStructure(config)
	local pos = config.Position
	local sizeX = config.Size.X
	local sizeZ = config.Size.Z
	local wallHeight = config.WallHeight
	local baseHeight = 1
	local baseCenter = GROUND_LEVEL + baseHeight / 2
	local wallY = GROUND_LEVEL + baseHeight + wallHeight / 2
	local doorWidth = 8

	local model = Instance.new("Model")
	model.Name = config.Name

	local wallMaterial = config.WallMaterial or Enum.Material.SmoothPlastic
	local wallTransparency = config.WallTransparency or 0

	local function newPart(name, partSize, partPos, color, material, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = partSize
		p.Position = partPos
		p.Anchored = true
		p.BrickColor = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		p.Parent = model
		return p
	end

	-- Base slab sits ON the ground
	newPart("Base", Vector3.new(sizeX, baseHeight, sizeZ),
		Vector3.new(pos.X, baseCenter, pos.Z), BrickColor.new("Dark stone grey"))

	-- Front wall with a door opening (split into left/right pieces + frame top)
	local sideWidth = (sizeX - doorWidth) / 2
	local frontZ = pos.Z - sizeZ / 2
	newPart("FrontWallLeft", Vector3.new(sideWidth, wallHeight, 1),
		Vector3.new(pos.X - (doorWidth + sideWidth) / 2, wallY, frontZ),
		config.WallColor, wallMaterial, wallTransparency)
	newPart("FrontWallRight", Vector3.new(sideWidth, wallHeight, 1),
		Vector3.new(pos.X + (doorWidth + sideWidth) / 2, wallY, frontZ),
		config.WallColor, wallMaterial, wallTransparency)
	newPart("DoorFrame", Vector3.new(doorWidth, 4, 1),
		Vector3.new(pos.X, wallY + wallHeight / 2 - 2, frontZ),
		config.WallColor, wallMaterial, wallTransparency)

	-- Back and side walls
	newPart("BackWall", Vector3.new(sizeX, wallHeight, 1),
		Vector3.new(pos.X, wallY, pos.Z + sizeZ / 2), config.WallColor, wallMaterial, wallTransparency)
	newPart("LeftWall", Vector3.new(1, wallHeight, sizeZ),
		Vector3.new(pos.X - sizeX / 2, wallY, pos.Z), config.WallColor, wallMaterial, wallTransparency)
	newPart("RightWall", Vector3.new(1, wallHeight, sizeZ),
		Vector3.new(pos.X + sizeX / 2, wallY, pos.Z), config.WallColor, wallMaterial, wallTransparency)

	-- Roof
	local wallTop = wallY + wallHeight / 2
	if config.GabledRoof then
		local roofY = wallTop + 4
		for _, angle in ipairs({ 90, -90 }) do
			local roof = Instance.new("WedgePart")
			roof.Name = "Roof"
			roof.Size = Vector3.new(1, 8, sizeZ + 7)
			roof.Position = Vector3.new(pos.X, roofY, pos.Z)
			roof.Orientation = Vector3.new(0, angle, 0)
			roof.Anchored = true
			roof.BrickColor = config.RoofColor
			roof.Parent = model
		end
	else
		newPart("Roof", Vector3.new(sizeX, 1, sizeZ),
			Vector3.new(pos.X, wallTop + 0.5, pos.Z), config.RoofColor)
	end

	-- Optional physical door
	if config.Door then
		newPart("Door", Vector3.new(4, 8, 0.5),
			Vector3.new(pos.X, GROUND_LEVEL + baseHeight + 4, frontZ - 0.5),
			BrickColor.new("Brown"))
	end

	-- Optional sign above the entrance
	if config.SignText then
		local sign = newPart("Sign", Vector3.new(math.min(sizeX - 10, 20), 3, 0.5),
			Vector3.new(pos.X, GROUND_LEVEL + baseHeight + 10, frontZ - 0.5),
			BrickColor.new("White"))

		local signGui = Instance.new("SurfaceGui")
		signGui.Face = Enum.NormalId.Front
		signGui.Parent = sign

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = config.SignText
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = config.SignTextColor or Color3.fromRGB(50, 50, 50)
		label.Parent = signGui
	end

	model.Parent = Workspace
	return model
end

-- Helper: create a spawn location for a zone
function WorldBuilder:CreateSpawn(name, position, color)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = position
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = color
	spawn.CanCollide = true -- IMPORTANT: Must be true so players don't fall through
	spawn.Duration = 0 -- Remove ForceField
	spawn.Parent = Workspace
	return spawn
end

-- Create Ella's House
function WorldBuilder:CreateEllasHouse()
	print("Creating Ella's House...")

	local pos = Constants.ZONES.EllasHouse.Position

	self:BuildStructure({
		Name = "EllasHouse",
		Position = pos,
		Size = Vector3.new(30, 0, 25),
		WallHeight = 12,
		WallColor = BrickColor.new("Light yellow"),
		RoofColor = BrickColor.new("Bright red"),
		GabledRoof = true,
		Door = true,
	})

	self:CreateSpawn("HouseSpawn", pos + Vector3.new(0, 2, -20), BrickColor.new("Light yellow"))

	print("Ella's House created")
end

-- Create Wordle Library
function WorldBuilder:CreateWordleLibrary()
	print("Creating Wordle Library...")

	local pos = Constants.ZONES.WordleLibrary.Position

	self:BuildStructure({
		Name = "WordleLibrary",
		Position = pos,
		Size = Vector3.new(35, 0, 30),
		WallHeight = 14,
		WallColor = BrickColor.new("Lavender"),
		RoofColor = BrickColor.new("Dark indigo"),
		SignText = "WORDLE LIBRARY",
		SignTextColor = Color3.fromRGB(100, 50, 150),
	})

	self:CreateSpawn("LibrarySpawn", pos + Vector3.new(0, 2, -22), BrickColor.new("Lavender"))

	print("Wordle Library created")
end

-- Create Fashion Boutique
function WorldBuilder:CreateFashionBoutique()
	print("Creating Fashion Boutique...")

	local pos = Constants.ZONES.FashionBoutique.Position

	self:BuildStructure({
		Name = "FashionBoutique",
		Position = pos,
		Size = Vector3.new(30, 0, 30),
		WallHeight = 14,
		WallColor = BrickColor.new("Pink"),
		WallMaterial = Enum.Material.Glass,
		WallTransparency = 0.3,
		RoofColor = BrickColor.new("Hot pink"),
		SignText = "FASHION BOUTIQUE",
		SignTextColor = Color3.fromRGB(255, 100, 150),
	})

	self:CreateSpawn("BoutiqueSpawn", pos + Vector3.new(0, 2, -22), BrickColor.new("Pink"))

	print("Fashion Boutique created")
end

-- Create Building Area
function WorldBuilder:CreateBuildingArea()
	print("Creating Building Area...")

	local pos = Constants.ZONES.BuildingArea.Position

	-- Just a large platform for building
	local platform = Instance.new("Part")
	platform.Name = "BuildingPlatform"
	platform.Size = Vector3.new(80, 1, 80)
	platform.Position = Vector3.new(pos.X, GROUND_LEVEL + 0.5, pos.Z)
	platform.Anchored = true
	platform.BrickColor = BrickColor.new("Sand yellow")
	platform.Material = Enum.Material.Concrete
	platform.Parent = Workspace

	self:CreateSpawn("BuildingSpawn", pos + Vector3.new(0, 2, 30), BrickColor.new("Sand yellow"))

	print("Building Area created")
end

-- Create Hub (central spawn by the river)
function WorldBuilder:CreateHub()
	print("Creating Hub...")

	local pos = Constants.ZONES.Hub.Position
	local hubCenter = Vector3.new(pos.X, GROUND_LEVEL, pos.Z)

	-- Create a nice platform by the river
	local platform = Instance.new("Part")
	platform.Name = "HubPlatform"
	platform.Size = Vector3.new(20, 2, 20)
	platform.Position = hubCenter + Vector3.new(0, 1, 0) -- Platform center at Y=11
	platform.Anchored = true
	platform.BrickColor = BrickColor.new("Sand blue")
	platform.Material = Enum.Material.Slate
	platform.Parent = Workspace

	-- Bench
	local bench = Instance.new("Part")
	bench.Name = "Bench"
	bench.Size = Vector3.new(6, 2, 2)
	bench.Position = hubCenter + Vector3.new(0, 3.5, 8) -- On top of platform
	bench.Anchored = true
	bench.BrickColor = BrickColor.new("Brown")
	bench.Parent = Workspace

	-- Welcome sign
	local sign = Instance.new("Part")
	sign.Name = "WelcomeSign"
	sign.Size = Vector3.new(10, 5, 0.5)
	sign.Position = hubCenter + Vector3.new(0, 4.5, -10) -- On top of platform
	sign.Anchored = true
	sign.BrickColor = BrickColor.new("White")
	sign.Parent = Workspace

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "Welcome to\nELLAND"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(100, 150, 255)
	label.Parent = signGui

	-- Spawn location ON TOP of platform (platform top is Y=12, spawn center at Y=12.5)
	local spawn = self:CreateSpawn("HubSpawn", hubCenter + Vector3.new(0, 2.5, 0), BrickColor.new("Bright green"))
	spawn.Size = Vector3.new(8, 1, 8)

	print("Hub created")
end

-- Build everything
function WorldBuilder:BuildWorld()
	print("======================")
	print("Building Elland World")
	print("======================")

	Workspace:SetAttribute("WorldBuilt", false)

	-- Clean up old world if it exists
	local oldSpawns = {
		"HubSpawn", "LookoutSpawn", "HouseSpawn", "LibrarySpawn",
		"BoutiqueSpawn", "BuildingSpawn"
	}

	for _, spawnName in ipairs(oldSpawns) do
		local oldSpawn = Workspace:FindFirstChild(spawnName, true)
		if oldSpawn then
			oldSpawn:Destroy()
		end
	end

	local oldModels = {
		"WishingTree", "EllasHouse", "WordleLibrary", "FashionBoutique",
		"BuildingPlatform", "HubPlatform", "Bench", "WelcomeSign"
	}

	for _, modelName in ipairs(oldModels) do
		local oldModel = Workspace:FindFirstChild(modelName, true)
		if oldModel then
			oldModel:Destroy()
		end
	end

	-- Clear terrain
	Workspace.Terrain:Clear()

	print("Cleaned up old world")

	-- Build new world. Order matters:
	-- 1. Base terrain, 2. Hill, 3. River LAST of the terrain passes so the
	--    channel carving removes any grass (e.g. from the hill) that would
	--    otherwise poke into the water, then structures on top.
	self:CreateTerrain()
	self:CreateEllasLookout()
	self:CreateRiver()
	self:CreateHub()
	self:CreateEllasHouse()
	self:CreateWordleLibrary()
	self:CreateFashionBoutique()
	self:CreateBuildingArea()

	-- Signal that the world is ready (InteractionManager waits on this)
	Workspace:SetAttribute("WorldBuilt", true)

	print("======================")
	print("Elland World Complete!")
	print("======================")
end

return WorldBuilder
