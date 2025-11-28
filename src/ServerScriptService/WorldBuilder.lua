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
	local segments = 20
	for i = 0, segments do
		local t = i / segments

		-- Linear interpolation with sine wave for meandering
		local x = riverStart.X + (riverEnd.X - riverStart.X) * t
		local z = riverStart.Z + (riverEnd.Z - riverStart.Z) * t

		-- Add meandering (sine wave perpendicular to river direction)
		local meander = math.sin(t * math.pi * 4) * 30
		x = x + meander

		-- Use river Y position from Constants (not hardcoded)
		local y = riverStart.Y

		-- Create water segment - make it thinner to fit within terrain
		local pos = Vector3.new(x, y, z)
		terrain:FillBlock(
			CFrame.new(pos),
			Vector3.new(25, 3, 25),  -- Reduced from 6 to 3 studs tall
			Enum.Material.Water
		)
	end

	print("River created")
end

-- Create Ella's Lookout - the big hill
function WorldBuilder:CreateEllasLookout()
	print("Creating Ella's Lookout...")

	local pos = Constants.ZONES.EllasLookout.Position
	local terrain = Workspace.Terrain

	-- Create hill using sphere of terrain
	local hillRadius = 60
	local hillHeight = 80

	terrain:FillBall(
		Vector3.new(pos.X, hillHeight / 2, pos.Z),
		hillRadius,
		Enum.Material.Grass
	)

	-- Create the tree
	local tree = Instance.new("Model")
	tree.Name = "WishingTree"

	-- Tree trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(3, 15, 3)
	trunk.Position = pos
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.BrickColor = BrickColor.new("Brown")
	trunk.Parent = tree

	-- Tree foliage
	local foliage = Instance.new("Part")
	foliage.Name = "Foliage"
	foliage.Shape = Enum.PartType.Ball
	foliage.Size = Vector3.new(20, 20, 20)
	foliage.Position = pos + Vector3.new(0, 15, 0)
	foliage.Anchored = true
	foliage.Material = Enum.Material.Grass
	foliage.BrickColor = BrickColor.new("Dark green")
	foliage.Parent = tree

	-- Swing branch
	local branch = Instance.new("Part")
	branch.Name = "SwingBranch"
	branch.Size = Vector3.new(12, 1, 1)
	branch.Position = pos + Vector3.new(5, 12, 0)
	branch.Anchored = true
	branch.Material = Enum.Material.Wood
	branch.BrickColor = BrickColor.new("Brown")
	branch.Parent = tree

	-- Swing ropes
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

	-- Swing seat
	local seat = Instance.new("Seat")
	seat.Name = "SwingSeat"
	seat.Size = Vector3.new(4, 0.5, 2)
	seat.Position = branch.Position + Vector3.new(0, -8, 0)
	seat.Anchored = false
	seat.BrickColor = BrickColor.new("Medium brown")
	seat.Parent = tree

	-- Attach swing with constraints
	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(-2, 4, 0)
	attachment1.Parent = seat

	local attachment2 = Instance.new("Attachment")
	attachment2.Position = Vector3.new(2, 4, 0)
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

	-- Create spawn location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LookoutSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = pos + Vector3.new(-10, 0, 0)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Bright green")
	spawn.Parent = Workspace

	print("Ella's Lookout created")
end

-- Create Ella's House
function WorldBuilder:CreateEllasHouse()
	print("Creating Ella's House...")

	local pos = Constants.ZONES.EllasHouse.Position

	local house = Instance.new("Model")
	house.Name = "EllasHouse"

	-- House base
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(30, 1, 25)
	base.Position = pos
	base.Anchored = true
	base.BrickColor = BrickColor.new("Dark stone grey")
	base.Parent = house

	-- Walls
	local wall1 = Instance.new("Part")
	wall1.Size = Vector3.new(30, 12, 1)
	wall1.Position = pos + Vector3.new(0, 6, -12)
	wall1.Anchored = true
	wall1.BrickColor = BrickColor.new("Light yellow")
	wall1.Parent = house

	local wall2 = Instance.new("Part")
	wall2.Size = Vector3.new(30, 12, 1)
	wall2.Position = pos + Vector3.new(0, 6, 12)
	wall2.Anchored = true
	wall2.BrickColor = BrickColor.new("Light yellow")
	wall2.Parent = house

	local wall3 = Instance.new("Part")
	wall3.Size = Vector3.new(1, 12, 25)
	wall3.Position = pos + Vector3.new(-15, 6, 0)
	wall3.Anchored = true
	wall3.BrickColor = BrickColor.new("Light yellow")
	wall3.Parent = house

	local wall4 = Instance.new("Part")
	wall4.Size = Vector3.new(1, 12, 25)
	wall4.Position = pos + Vector3.new(15, 6, 0)
	wall4.Anchored = true
	wall4.BrickColor = BrickColor.new("Light yellow")
	wall4.Parent = house

	-- Roof
	local roof = Instance.new("WedgePart")
	roof.Size = Vector3.new(1, 8, 32)
	roof.Position = pos + Vector3.new(0, 16, 0)
	roof.Orientation = Vector3.new(0, 90, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Bright red")
	roof.Parent = house

	local roof2 = Instance.new("WedgePart")
	roof2.Size = Vector3.new(1, 8, 32)
	roof2.Position = pos + Vector3.new(0, 16, 0)
	roof2.Orientation = Vector3.new(0, -90, 0)
	roof2.Anchored = true
	roof2.BrickColor = BrickColor.new("Bright red")
	roof2.Parent = house

	-- Door
	local door = Instance.new("Part")
	door.Size = Vector3.new(4, 8, 0.5)
	door.Position = pos + Vector3.new(0, 4, -12.5)
	door.Anchored = true
	door.BrickColor = BrickColor.new("Brown")
	door.Parent = house

	house.Parent = Workspace

	-- Spawn location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HouseSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = pos + Vector3.new(0, 0, -20)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Light yellow")
	spawn.Parent = Workspace

	print("Ella's House created")
end

-- Create Wordle Library
function WorldBuilder:CreateWordleLibrary()
	print("Creating Wordle Library...")

	local pos = Constants.ZONES.WordleLibrary.Position

	local library = Instance.new("Model")
	library.Name = "WordleLibrary"

	-- Building base
	local base = Instance.new("Part")
	base.Size = Vector3.new(35, 1, 30)
	base.Position = pos
	base.Anchored = true
	base.BrickColor = BrickColor.new("Dark stone grey")
	base.Parent = library

	-- Walls
	for i, wallData in ipairs({
		{Vector3.new(0, 7, -15), Vector3.new(35, 14, 1)},
		{Vector3.new(0, 7, 15), Vector3.new(35, 14, 1)},
		{Vector3.new(-17.5, 7, 0), Vector3.new(1, 14, 30)},
		{Vector3.new(17.5, 7, 0), Vector3.new(1, 14, 30)},
	}) do
		local wall = Instance.new("Part")
		wall.Size = wallData[2]
		wall.Position = pos + wallData[1]
		wall.Anchored = true
		wall.BrickColor = BrickColor.new("Lavender")
		wall.Parent = library
	end

	-- Roof
	local roof = Instance.new("Part")
	roof.Size = Vector3.new(35, 1, 30)
	roof.Position = pos + Vector3.new(0, 14, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Dark indigo")
	roof.Parent = library

	-- Sign
	local sign = Instance.new("Part")
	sign.Size = Vector3.new(20, 3, 0.5)
	sign.Position = pos + Vector3.new(0, 10, -15.5)
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
	spawn.Position = pos + Vector3.new(0, 0, -22)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Lavender")
	spawn.Parent = Workspace

	print("Wordle Library created")
end

-- Create Fashion Boutique
function WorldBuilder:CreateFashionBoutique()
	print("Creating Fashion Boutique...")

	local pos = Constants.ZONES.FashionBoutique.Position

	local boutique = Instance.new("Model")
	boutique.Name = "FashionBoutique"

	-- Building base
	local base = Instance.new("Part")
	base.Size = Vector3.new(30, 1, 30)
	base.Position = pos
	base.Anchored = true
	base.BrickColor = BrickColor.new("Dark stone grey")
	base.Parent = boutique

	-- Walls with glass
	for i, wallData in ipairs({
		{Vector3.new(0, 7, -15), Vector3.new(30, 14, 1)},
		{Vector3.new(0, 7, 15), Vector3.new(30, 14, 1)},
		{Vector3.new(-15, 7, 0), Vector3.new(1, 14, 30)},
		{Vector3.new(15, 7, 0), Vector3.new(1, 14, 30)},
	}) do
		local wall = Instance.new("Part")
		wall.Size = wallData[2]
		wall.Position = pos + wallData[1]
		wall.Anchored = true
		wall.Material = Enum.Material.Glass
		wall.Transparency = 0.3
		wall.BrickColor = BrickColor.new("Pink")
		wall.Parent = boutique
	end

	-- Roof
	local roof = Instance.new("Part")
	roof.Size = Vector3.new(30, 1, 30)
	roof.Position = pos + Vector3.new(0, 14, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Hot pink")
	roof.Parent = boutique

	-- Sign
	local sign = Instance.new("Part")
	sign.Size = Vector3.new(15, 3, 0.5)
	sign.Position = pos + Vector3.new(0, 10, -15.5)
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
	spawn.Position = pos + Vector3.new(0, 0, -22)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Pink")
	spawn.Parent = Workspace

	print("Fashion Boutique created")
end

-- Create Building Area
function WorldBuilder:CreateBuildingArea()
	print("Creating Building Area...")

	local pos = Constants.ZONES.BuildingArea.Position

	-- Just create a large platform for building
	local platform = Instance.new("Part")
	platform.Name = "BuildingPlatform"
	platform.Size = Vector3.new(80, 1, 80)
	platform.Position = pos
	platform.Anchored = true
	platform.BrickColor = BrickColor.new("Sand yellow")
	platform.Material = Enum.Material.Concrete
	platform.Parent = Workspace

	-- Spawn location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BuildingSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = pos + Vector3.new(0, 1, 30)
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Sand yellow")
	spawn.Parent = Workspace

	print("Building Area created")
end

-- Create Hub (central spawn by the river)
function WorldBuilder:CreateHub()
	print("Creating Hub...")

	local pos = Constants.ZONES.Hub.Position

	-- Create a nice platform by the river
	local platform = Instance.new("Part")
	platform.Name = "HubPlatform"
	platform.Size = Vector3.new(20, 2, 20)
	platform.Position = pos + Vector3.new(0, -1, 0)  -- Lower it 1 stud
	platform.Anchored = true
	platform.BrickColor = BrickColor.new("Sand blue")
	platform.Material = Enum.Material.Slate
	platform.Parent = Workspace

	-- Add some decorative elements
	local bench = Instance.new("Part")
	bench.Size = Vector3.new(6, 2, 2)
	bench.Position = pos + Vector3.new(0, 1.5, 8)
	bench.Anchored = true
	bench.BrickColor = BrickColor.new("Brown")
	bench.Parent = Workspace

	-- Welcome sign
	local sign = Instance.new("Part")
	sign.Size = Vector3.new(10, 5, 0.5)
	sign.Position = pos + Vector3.new(0, 3, -10)
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
	spawn.Position = pos + Vector3.new(0, 1, 0)  -- Raise it 1 stud above center
	spawn.Anchored = true
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Bright green")
	spawn.CanCollide = true  -- Changed to true so players don't fall through!
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
