--[[
	WorldBuilder
	Generates the terrain and builds the structures for Elland
	Run this script once in Studio to create the world
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local WorldBuilder = {}

-- Create grass terrain
function WorldBuilder:CreateTerrain()
	print("Creating terrain...")

	local terrain = Workspace.Terrain
	terrain:Clear()

	-- Create thin grass layer starting at ground level
	local size = Vector3.new(600, 10, 600)  -- Only 10 studs tall
	local center = Vector3.new(0, 5, 0)     -- Center at Y=5, so terrain is Y=0 to Y=10

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

		-- FIRST: Carve a deeper river channel into the terrain
		-- Ground surface is at Y=10. We want to carve down to Y=5 (5 studs deep)
		-- Air block: center at Y=10, height 10 → carves from Y=5 to Y=15
		local airPos = Vector3.new(pos.X, 10, pos.Z)
		terrain:FillBlock(
			CFrame.new(airPos),
			Vector3.new(28, 10, 28),  -- Slightly wider than water for banks
			Enum.Material.Air
		)

		-- SECOND: Fill with water
		-- Water should fill from Y=5 to Y=9.5 (4.5 studs deep, surface just below ground)
		-- Center at Y=7.25, height 4.5 → Y=5 to Y=9.5
		local waterPos = Vector3.new(pos.X, 7.25, pos.Z)
		terrain:FillBlock(
			CFrame.new(waterPos),
			Vector3.new(22, 4.5, 22),  -- Narrower than air carving for natural banks
			Enum.Material.Water
		)
	end

	print("River created - channel carved 5 studs deep, water surface at Y=9.5")
end

-- Create Ella's Lookout - the big hill (FIXED: proper cone shape, not spheres)
function WorldBuilder:CreateEllasLookout()
	print("Creating Ella's Lookout...")

	local pos = Constants.ZONES.EllasLookout.Position  -- Y=70 is the TOP of the hill
	local terrain = Workspace.Terrain

	-- Hill parameters
	local hillBaseY = 10      -- Ground level (top of base terrain)
	local hillTopY = pos.Y    -- Top of hill (Y=70)
	local hillHeight = hillTopY - hillBaseY  -- 60 studs tall
	local hillCenterX = pos.X
	local hillCenterZ = pos.Z
	local baseRadius = 80     -- Wide base for gentle slope

	-- Create hill using stacked cylinders (creates a cone shape)
	-- This looks like a natural hill, not a sphere
	local layers = 30  -- Number of cylinder layers
	for i = 0, layers do
		local progress = i / layers  -- 0 to 1 from bottom to top
		
		-- Current layer height
		local layerY = hillBaseY + (hillHeight * progress)
		
		-- Radius decreases as we go up (creates cone shape)
		-- Use a slight curve for more natural look
		local layerRadius = baseRadius * (1 - progress * 0.85)  -- Shrinks to 15% at top
		
		if layerRadius > 3 then
			-- Use FillCylinder for flat circular layers
			terrain:FillCylinder(
				CFrame.new(hillCenterX, layerY, hillCenterZ),
				4,  -- Height of each cylinder layer
				layerRadius,
				Enum.Material.Grass
			)
		end
	end

	-- Add a flat top to the hill for the tree
	terrain:FillCylinder(
		CFrame.new(hillCenterX, hillTopY - 2, hillCenterZ),
		4,
		15,  -- Flat top radius
		Enum.Material.Grass
	)

	-- Create the tree ON TOP of the hill
	local tree = Instance.new("Model")
	tree.Name = "WishingTree"

	-- Tree trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(3, 15, 3)
	trunk.Position = Vector3.new(hillCenterX, hillTopY + 7.5, hillCenterZ)  -- Trunk base at hill top
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.BrickColor = BrickColor.new("Brown")
	trunk.Parent = tree

	-- Tree foliage
	local foliage = Instance.new("Part")
	foliage.Name = "Foliage"
	foliage.Shape = Enum.PartType.Ball
	foliage.Size = Vector3.new(20, 20, 20)
	foliage.Position = Vector3.new(hillCenterX, hillTopY + 20, hillCenterZ)  -- Above trunk
	foliage.Anchored = true
	foliage.Material = Enum.Material.Grass
	foliage.BrickColor = BrickColor.new("Dark green")
	foliage.Parent = tree

	-- Swing branch
	local branch = Instance.new("Part")
	branch.Name = "SwingBranch"
	branch.Size = Vector3.new(12, 1, 1)
	branch.Position = Vector3.new(hillCenterX + 5, hillTopY + 17, hillCenterZ)  -- At foliage level
	branch.Anchored = true
	branch.Material = Enum.Material.Wood
	branch.BrickColor = BrickColor.new("Brown")
	branch.Parent = tree

	-- Swing ropes (visual only)
	local leftRope = Instance.new("Part")
	leftRope.Name = "LeftRope"
	leftRope.Size = Vector3.new(0.3, 8, 0.3)
	leftRope.Position = branch.Position + Vector3.new(-2, -4, 0)
	leftRope.Anchored = true
	leftRope.BrickColor = BrickColor.new("Tan")
	leftRope.Parent = tree

	local rightRope = Instance.new("Part")
	rightRope.Name = "RightRope"
	rightRope.Size = Vector3.new(0.3, 8, 0.3)
	rightRope.Position = branch.Position + Vector3.new(2, -4, 0)
	rightRope.Anchored = true
	rightRope.BrickColor = BrickColor.new("Tan")
	rightRope.Parent = tree

	-- Swing seat (moved further out from hill)
	local seat = Instance.new("Seat")
	seat.Name = "SwingSeat"
	seat.Size = Vector3.new(4, 0.5, 2)
	seat.Position = branch.Position + Vector3.new(10, -8, 0)  -- Moved 10 studs away from hill
	seat.Anchored = false
	seat.BrickColor = BrickColor.new("Medium brown")
	seat.Parent = tree

	-- Attach swing with constraints
	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(-2, 0.25, 0)
	attachment1.Parent = seat

	local attachment2 = Instance.new("Attachment")
	attachment2.Position = Vector3.new(2, 0.25, 0)
	attachment2.Parent = seat

	local attachment3 = Instance.new("Attachment")
	attachment3.Position = Vector3.new(-2, -0.5, 0)
	attachment3.Parent = branch

	local attachment4 = Instance.new("Attachment")
	attachment4.Position = Vector3.new(2, -0.5, 0)
	attachment4.Parent = branch

	local rope1 = Instance.new("RopeConstraint")
	rope1.Attachment0 = attachment1
	rope1.Attachment1 = attachment3
	rope1.Length = 8
	rope1.Visible = true
	rope1.Parent = seat

	local rope2 = Instance.new("RopeConstraint")
	rope2.Attachment0 = attachment2
	rope2.Attachment1 = attachment4
	rope2.Length = 8
	rope2.Visible = true
	rope2.Parent = seat

	tree.Parent = Workspace

	-- Create spawn location at base of hill (on the flat ground, not on the slope)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LookoutSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(hillCenterX - 100, 12, hillCenterZ)  -- Further out from hill base
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Bright green")
	spawn.CanCollide = true  -- IMPORTANT: Must be true so players don't fall through
	spawn.Duration = 0 -- Remove ForceField
	spawn.Parent = Workspace

	print("Ella's Lookout created - proper cone-shaped hill")
end

-- Create Ella's House
function WorldBuilder:CreateEllasHouse()
	print("Creating Ella's House...")

	local pos = Constants.ZONES.EllasHouse.Position
	-- Ground is at Y=10, so position house with base ON the ground
	local groundLevel = 10
	local baseHeight = 1
	local baseCenter = groundLevel + (baseHeight / 2)  -- Y=10.5

	local house = Instance.new("Model")
	house.Name = "EllasHouse"

	-- House base - sits ON ground
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(30, 1, 25)
	base.Position = Vector3.new(pos.X, baseCenter, pos.Z)  -- Base at Y=10.5
	base.Anchored = true
	base.BrickColor = BrickColor.new("Dark stone grey")
	base.Parent = house

	local wallY = groundLevel + baseHeight + 6  -- Y=10 + 1 + 6 = 17

	-- Walls
	local wall1 = Instance.new("Part")
	wall1.Size = Vector3.new(30, 12, 1)
	wall1.Position = Vector3.new(pos.X, wallY, pos.Z - 12)
	wall1.Anchored = true
	wall1.BrickColor = BrickColor.new("Light yellow")
	wall1.Parent = house

	local wall2 = Instance.new("Part")
	wall2.Size = Vector3.new(30, 12, 1)
	wall2.Position = Vector3.new(pos.X, wallY, pos.Z + 12)
	wall2.Anchored = true
	wall2.BrickColor = BrickColor.new("Light yellow")
	wall2.Parent = house

	local wall3 = Instance.new("Part")
	wall3.Size = Vector3.new(1, 12, 25)
	wall3.Position = Vector3.new(pos.X - 15, wallY, pos.Z)
	wall3.Anchored = true
	wall3.BrickColor = BrickColor.new("Light yellow")
	wall3.Parent = house

	local wall4 = Instance.new("Part")
	wall4.Size = Vector3.new(1, 12, 25)
	wall4.Position = Vector3.new(pos.X + 15, wallY, pos.Z)
	wall4.Anchored = true
	wall4.BrickColor = BrickColor.new("Light yellow")
	wall4.Parent = house

	local roofY = wallY + 6 + 4  -- Wall center + half wall height + half roof height

	-- Roof
	local roof = Instance.new("WedgePart")
	roof.Size = Vector3.new(1, 8, 32)
	roof.Position = Vector3.new(pos.X, roofY, pos.Z)
	roof.Orientation = Vector3.new(0, 90, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Bright red")
	roof.Parent = house

	local roof2 = Instance.new("WedgePart")
	roof2.Size = Vector3.new(1, 8, 32)
	roof2.Position = Vector3.new(pos.X, roofY, pos.Z)
	roof2.Orientation = Vector3.new(0, -90, 0)
	roof2.Anchored = true
	roof2.BrickColor = BrickColor.new("Bright red")
	roof2.Parent = house

	local doorY = groundLevel + baseHeight + 4  -- Bottom of wall + half door height

	-- Door
	local door = Instance.new("Part")
	door.Size = Vector3.new(4, 8, 0.5)
	door.Position = Vector3.new(pos.X, doorY, pos.Z - 12.5)
	door.Anchored = true
	door.BrickColor = BrickColor.new("Brown")
	door.Parent = house

	house.Parent = Workspace

	-- Spawn location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HouseSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = pos + Vector3.new(0, 2, -20)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Light yellow")
	spawn.CanCollide = true  -- IMPORTANT: Must be true
	spawn.Duration = 0 -- Remove ForceField
	spawn.Parent = Workspace

	print("Ella's House created")
end

-- Create Wordle Library
function WorldBuilder:CreateWordleLibrary()
	print("Creating Wordle Library...")

	local pos = Constants.ZONES.WordleLibrary.Position
	-- Ground is at Y=10, so position building with base ON the ground
	local groundLevel = 10
	local baseHeight = 1
	local baseCenter = groundLevel + (baseHeight / 2)

	local library = Instance.new("Model")
	library.Name = "WordleLibrary"

	-- Building base
	local base = Instance.new("Part")
	base.Size = Vector3.new(35, 1, 30)
	base.Position = Vector3.new(pos.X, baseCenter, pos.Z)
	base.Anchored = true
	base.BrickColor = BrickColor.new("Dark stone grey")
	base.Parent = library

	-- Walls
	local wallY = groundLevel + baseHeight + 7 -- Base + half wall height (14/2)
	
	for i, wallData in ipairs({
		{Vector3.new(0, 0, -15), Vector3.new(35, 14, 1)},
		{Vector3.new(0, 0, 15), Vector3.new(35, 14, 1)},
		{Vector3.new(-17.5, 0, 0), Vector3.new(1, 14, 30)},
		{Vector3.new(17.5, 0, 0), Vector3.new(1, 14, 30)},
	}) do
		local wall = Instance.new("Part")
		wall.Size = wallData[2]
		wall.Position = Vector3.new(pos.X, wallY, pos.Z) + wallData[1]
		wall.Anchored = true
		wall.BrickColor = BrickColor.new("Lavender")
		wall.Parent = library
	end

	-- Roof
	local roofY = groundLevel + baseHeight + 14 + 0.5 -- Base + wall height + half roof height
	local roof = Instance.new("Part")
	roof.Size = Vector3.new(35, 1, 30)
	roof.Position = Vector3.new(pos.X, roofY, pos.Z)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Dark indigo")
	roof.Parent = library

	-- Sign
	local signY = groundLevel + baseHeight + 10
	local sign = Instance.new("Part")
	sign.Size = Vector3.new(20, 3, 0.5)
	sign.Position = Vector3.new(pos.X, signY, pos.Z - 15.5)
	sign.Anchored = true
	sign.BrickColor = BrickColor.new("White")
	sign.Parent = library

	local signText = Instance.new("SurfaceGui")
	signText.Face = Enum.NormalId.Front
	signText.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "WORDLE LIBRARY"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(100, 50, 150)
	label.Parent = signText

	library.Parent = Workspace

	-- Spawn location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LibrarySpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = pos + Vector3.new(0, 2, -22)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Lavender")
	spawn.CanCollide = true  -- IMPORTANT: Must be true
	spawn.Duration = 0 -- Remove ForceField
	spawn.Parent = Workspace

	print("Wordle Library created")
end

-- Create Fashion Boutique
function WorldBuilder:CreateFashionBoutique()
	print("Creating Fashion Boutique...")

	local pos = Constants.ZONES.FashionBoutique.Position
	-- Ground is at Y=10, so position building with base ON the ground
	local groundLevel = 10
	local baseHeight = 1
	local baseCenter = groundLevel + (baseHeight / 2)

	local boutique = Instance.new("Model")
	boutique.Name = "FashionBoutique"

	-- Building base
	local base = Instance.new("Part")
	base.Size = Vector3.new(30, 1, 30)
	base.Position = Vector3.new(pos.X, baseCenter, pos.Z)
	base.Anchored = true
	base.BrickColor = BrickColor.new("Dark stone grey")
	base.Parent = boutique

	-- Walls with glass
	local wallY = groundLevel + baseHeight + 7 -- Base + half wall height (14/2)

	for i, wallData in ipairs({
		{Vector3.new(0, 0, -15), Vector3.new(30, 14, 1)},
		{Vector3.new(0, 0, 15), Vector3.new(30, 14, 1)},
		{Vector3.new(-15, 0, 0), Vector3.new(1, 14, 30)},
		{Vector3.new(15, 0, 0), Vector3.new(1, 14, 30)},
	}) do
		local wall = Instance.new("Part")
		wall.Size = wallData[2]
		wall.Position = Vector3.new(pos.X, wallY, pos.Z) + wallData[1]
		wall.Anchored = true
		wall.Material = Enum.Material.Glass
		wall.Transparency = 0.3
		wall.BrickColor = BrickColor.new("Pink")
		wall.Parent = boutique
	end

	-- Roof
	local roofY = groundLevel + baseHeight + 14 + 0.5 -- Base + wall height + half roof height
	local roof = Instance.new("Part")
	roof.Size = Vector3.new(30, 1, 30)
	roof.Position = Vector3.new(pos.X, roofY, pos.Z)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Hot pink")
	roof.Parent = boutique

	-- Sign
	local signY = groundLevel + baseHeight + 10
	local sign = Instance.new("Part")
	sign.Size = Vector3.new(15, 3, 0.5)
	sign.Position = Vector3.new(pos.X, signY, pos.Z - 15.5)
	sign.Anchored = true
	sign.BrickColor = BrickColor.new("White")
	sign.Parent = boutique

	local signText = Instance.new("SurfaceGui")
	signText.Face = Enum.NormalId.Front
	signText.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "FASHION BOUTIQUE"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 100, 150)
	label.Parent = signText

	boutique.Parent = Workspace

	-- Spawn location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BoutiqueSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = pos + Vector3.new(0, 2, -22)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Pink")
	spawn.CanCollide = true  -- IMPORTANT: Must be true
	spawn.Duration = 0 -- Remove ForceField
	spawn.Parent = Workspace

	print("Fashion Boutique created")
end

-- Create Building Area
function WorldBuilder:CreateBuildingArea()
	print("Creating Building Area...")

	local pos = Constants.ZONES.BuildingArea.Position
	-- Ground is at Y=10, so position building with base ON the ground
	local groundLevel = 10
	local baseHeight = 1
	local baseCenter = groundLevel + (baseHeight / 2)

	-- Just create a large platform for building
	local platform = Instance.new("Part")
	platform.Name = "BuildingPlatform"
	platform.Size = Vector3.new(80, 1, 80)
	platform.Position = Vector3.new(pos.X, baseCenter, pos.Z)
	platform.Anchored = true
	platform.BrickColor = BrickColor.new("Sand yellow")
	platform.Material = Enum.Material.Concrete
	platform.Parent = Workspace

	-- Spawn location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BuildingSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = pos + Vector3.new(0, 2, 30)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Sand yellow")
	spawn.CanCollide = true  -- IMPORTANT: Must be true
	spawn.Duration = 0 -- Remove ForceField
	spawn.Parent = Workspace

	print("Building Area created")
end

-- Create Hub (central spawn by the river)
function WorldBuilder:CreateHub()
	print("Creating Hub...")

	local pos = Constants.ZONES.Hub.Position
	-- Hub should be ON the terrain (Y=10), not floating
	local groundLevel = 10
	local hubCenter = Vector3.new(pos.X, groundLevel, pos.Z)

	-- Create a nice platform by the river
	local platform = Instance.new("Part")
	platform.Name = "HubPlatform"
	platform.Size = Vector3.new(20, 2, 20)
	platform.Position = hubCenter + Vector3.new(0, 1, 0)  -- Platform center at Y=11
	platform.Anchored = true
	platform.BrickColor = BrickColor.new("Sand blue")
	platform.Material = Enum.Material.Slate
	platform.Parent = Workspace

	-- Add some decorative elements
	local bench = Instance.new("Part")
	bench.Size = Vector3.new(6, 2, 2)
	bench.Position = hubCenter + Vector3.new(0, 3.5, 8)  -- On top of platform
	bench.Anchored = true
	bench.BrickColor = BrickColor.new("Brown")
	bench.Parent = Workspace

	-- Welcome sign
	local sign = Instance.new("Part")
	sign.Size = Vector3.new(10, 5, 0.5)
	sign.Position = hubCenter + Vector3.new(0, 4.5, -10)  -- On top of platform
	sign.Anchored = true
	sign.BrickColor = BrickColor.new("White")
	sign.Parent = Workspace

	local signText = Instance.new("SurfaceGui")
	signText.Face = Enum.NormalId.Front
	signText.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "Welcome to\nELLAND"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(100, 150, 255)
	label.Parent = signText

	-- Spawn location ON TOP of platform
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = hubCenter + Vector3.new(0, 2.5, 0)  -- On top of platform (platform top is Y=12, spawn center at Y=12.5)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Bright green")
	spawn.CanCollide = true  -- IMPORTANT: Must be true so players don't fall through
	spawn.Duration = 0 -- Remove ForceField
	spawn.Parent = Workspace

	print("Hub created")
end

-- Build everything
function WorldBuilder:BuildWorld()
	print("======================")
	print("Building Elland World")
	print("======================")

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
		"BuildingPlatform", "HubPlatform"
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

	-- Build new world
	self:CreateTerrain()
	self:CreateRiver()
	self:CreateHub()
	self:CreateEllasLookout()
	self:CreateEllasHouse()
	self:CreateWordleLibrary()
	self:CreateFashionBoutique()
	self:CreateBuildingArea()

	print("======================")
	print("Elland World Complete!")
	print("======================")
end

return WorldBuilder
