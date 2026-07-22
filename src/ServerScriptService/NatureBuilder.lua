--[[
	NatureBuilder
	Scatters low-poly trees and bright flower patches around Elland.

	Placement is deterministic (seeded Random) and respects keep-out zones:
	the river channel, walking paths, the lookout hill/swing, every zone
	structure, and the new attractions (obby, soccer pitch, stage, plaza,
	picnic, photo spot, pet corner, bake shop, algebra academy). Nothing is
	placed in the riverbed.

	Runs once at server start, after WorldBuilder:BuildWorld().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local WorldUtils = require(script.Parent.WorldUtils)

local NatureBuilder = {}

local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL

-- Keep-out circles: { center, radius }. Trees use the full radius; flowers
-- are allowed a little closer (they're tiny and don't block movement).
local function buildKeepOuts()
	local keepOuts = {}

	for zoneName, zone in pairs(Constants.ZONES) do
		local radius = 30
		if zoneName == "EllasLookout" then
			radius = 95 -- Cone hill base + swing area
		elseif zoneName == "BuildingArea" then
			radius = 55 -- 80x80 build platform
		elseif zoneName == "Hub" then
			radius = 40 -- Platform, fountain, welcome sign
		end
		table.insert(keepOuts, { center = zone.Position, radius = radius })
	end

	table.insert(keepOuts, { center = Constants.OBBY.START, radius = 100 }) -- Course runs along +X
	table.insert(keepOuts, { center = Constants.SOCCER.CENTER, radius = 45 })
	table.insert(keepOuts, { center = Constants.STAGE.CENTER, radius = 35 })
	table.insert(keepOuts, { center = Constants.NUTCRACKER.CENTER, radius = 30 })
	table.insert(keepOuts, { center = Constants.FAMILY.PICNIC_CENTER, radius = 15 })
	table.insert(keepOuts, { center = Constants.FAMILY.PHOTO_SPOT, radius = 15 })
	table.insert(keepOuts, { center = Constants.PETS.POSITION, radius = 20 }) -- Pet Corner pen
	table.insert(keepOuts, { center = Constants.BAKERY.POSITION, radius = 25 }) -- Ella's Bake Shop
	table.insert(keepOuts, { center = Constants.ALGEBRA.POSITION, radius = 30 }) -- Algebra Academy

	return keepOuts
end

local function isSpotClear(position, keepOuts, radiusScale)
	local nature = Constants.NATURE

	if math.abs(position.X) > nature.MAP_EDGE or math.abs(position.Z) > nature.MAP_EDGE then
		return false
	end

	if WorldUtils:IsNearRiver(position, nature.RIVER_CLEARANCE) then
		return false
	end

	if WorldUtils:DistanceToNearestPath(position) < nature.PATH_CLEARANCE * radiusScale then
		return false
	end

	for _, keepOut in ipairs(keepOuts) do
		local dx = position.X - keepOut.center.X
		local dz = position.Z - keepOut.center.Z
		local radius = keepOut.radius * radiusScale
		if dx * dx + dz * dz < radius * radius then
			return false
		end
	end

	return true
end

-- A charming low-poly tree: wooden trunk + 2-3 green sphere canopies
local function createTree(parent, position, rng)
	local tree = Instance.new("Model")
	tree.Name = "Tree"

	local trunkHeight = rng:NextNumber(6, 9)

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(1.5, trunkHeight, 1.5)
	trunk.Position = position + Vector3.new(0, trunkHeight / 2, 0)
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.BrickColor = BrickColor.new("Reddish brown")
	trunk.Parent = tree

	local canopyShades = {
		Color3.fromRGB(84, 160, 84),
		Color3.fromRGB(101, 180, 92),
		Color3.fromRGB(70, 145, 75),
	}

	local canopyCount = rng:NextInteger(2, 3)
	for i = 1, canopyCount do
		local canopy = Instance.new("Part")
		canopy.Name = "Canopy"
		canopy.Shape = Enum.PartType.Ball
		local canopySize = rng:NextNumber(7, 11) - (i - 1) * 1.5
		canopy.Size = Vector3.new(canopySize, canopySize, canopySize)
		canopy.Position = position + Vector3.new(
			rng:NextNumber(-1.5, 1.5),
			trunkHeight + 1 + (i - 1) * 3,
			rng:NextNumber(-1.5, 1.5)
		)
		canopy.Anchored = true
		canopy.CanCollide = false
		canopy.Material = Enum.Material.Grass
		canopy.Color = canopyShades[rng:NextInteger(1, #canopyShades)]
		canopy.Parent = tree
	end

	tree.Parent = parent
end

-- A small flower: thin green stem + bright blossom ball
local function createFlower(parent, position, rng)
	local stem = Instance.new("Part")
	stem.Name = "FlowerStem"
	stem.Size = Vector3.new(0.15, 1.2, 0.15)
	stem.Position = position + Vector3.new(0, 0.6, 0)
	stem.Anchored = true
	stem.CanCollide = false
	stem.Material = Enum.Material.Grass
	stem.Color = Color3.fromRGB(80, 150, 80)
	stem.Parent = parent

	local blossom = Instance.new("Part")
	blossom.Name = "FlowerBlossom"
	blossom.Shape = Enum.PartType.Ball
	blossom.Size = Vector3.new(0.8, 0.8, 0.8)
	blossom.Position = position + Vector3.new(0, 1.35, 0)
	blossom.Anchored = true
	blossom.CanCollide = false
	blossom.Material = Enum.Material.Neon
	local colors = Constants.NATURE.FLOWER_COLORS
	blossom.Color = colors[rng:NextInteger(1, #colors)]
	blossom.Parent = parent
end

function NatureBuilder:Build()
	local nature = Constants.NATURE
	local keepOuts = buildKeepOuts()
	local rng = Random.new(nature.TREE_SEED)

	local old = Workspace:FindFirstChild("Nature")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Nature"
	folder.Parent = Workspace

	-- Trees (rejection sampling with a bounded attempt count)
	local placedTrees = 0
	local attempts = 0
	while placedTrees < nature.TREE_COUNT and attempts < nature.TREE_COUNT * 40 do
		attempts = attempts + 1
		local position = Vector3.new(
			rng:NextNumber(-nature.MAP_EDGE, nature.MAP_EDGE),
			GROUND_LEVEL,
			rng:NextNumber(-nature.MAP_EDGE, nature.MAP_EDGE)
		)
		if isSpotClear(position, keepOuts, 1) then
			createTree(folder, position, rng)
			placedTrees = placedTrees + 1
		end
	end

	-- Flower patches (clusters of tiny flowers; looser keep-out than trees)
	local placedPatches = 0
	attempts = 0
	while placedPatches < nature.FLOWER_PATCH_COUNT and attempts < nature.FLOWER_PATCH_COUNT * 40 do
		attempts = attempts + 1
		local patchCenter = Vector3.new(
			rng:NextNumber(-nature.MAP_EDGE, nature.MAP_EDGE),
			GROUND_LEVEL,
			rng:NextNumber(-nature.MAP_EDGE, nature.MAP_EDGE)
		)
		if isSpotClear(patchCenter, keepOuts, 0.5) then
			local flowerCount = rng:NextInteger(nature.FLOWERS_PER_PATCH_MIN, nature.FLOWERS_PER_PATCH_MAX)
			for _ = 1, flowerCount do
				local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
				createFlower(folder, patchCenter + offset, rng)
			end
			placedPatches = placedPatches + 1
		end
	end

	print(string.format("NatureBuilder finished: %d trees, %d flower patches", placedTrees, placedPatches))
end

return NatureBuilder
