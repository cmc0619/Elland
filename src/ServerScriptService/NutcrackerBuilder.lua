--[[
	NutcrackerBuilder
	Nutcracker Plaza: a festive corner for Ella, who sings in Nutcracker
	performances. A blocky nutcracker soldier statue, striped candy-cane
	poles, a decorated evergreen tree with sparkles and a glowing star,
	gentle local snowfall, and a plaza plaque.

	Touching the tree twinkles the star and sends the player a notification
	("Break a leg, Ella!") via the NotifyPlayer RemoteEvent (30s debounce).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local NutcrackerBuilder = {}

local PLAZA = Constants.NUTCRACKER
local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL

-- Shared one-line notification channel (ClientController shows the toast)
local NotifyPlayer = ReplicatedStorage:FindFirstChild("NotifyPlayer")
if not NotifyPlayer then
	NotifyPlayer = Instance.new("RemoteEvent")
	NotifyPlayer.Name = "NotifyPlayer"
	NotifyPlayer.Parent = ReplicatedStorage
end

local touchDebounce = {} -- [UserId] = os.clock()

local function createPart(parent, name, size, cframe, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.BrickColor = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- The blocky nutcracker soldier statue on a pedestal
local function buildStatue(parent, base)
	local statue = Instance.new("Model")
	statue.Name = "NutcrackerStatue"

	local y = base.Y
	local function part(name, size, offsetY, color, material)
		return createPart(
			statue, name, size,
			CFrame.new(base.X, y + offsetY, base.Z),
			color, material
		)
	end

	part("Pedestal", Vector3.new(5, 1, 5), 0.5, BrickColor.new("Light stone grey"), Enum.Material.Marble)

	-- Boots
	for _, xSign in ipairs({ -1, 1 }) do
		createPart(
			statue, "Boot", Vector3.new(1, 2, 1.2),
			CFrame.new(base.X + xSign * 0.8, y + 2, base.Z),
			BrickColor.new("Really black")
		)
	end

	-- Red soldier torso with gold belt
	part("Torso", Vector3.new(3, 3, 2), 4.5, BrickColor.new("Bright red"))
	part("Belt", Vector3.new(3.2, 0.6, 2.2), 4, BrickColor.new("Bright yellow"), Enum.Material.Neon)

	-- Arms
	for _, xSign in ipairs({ -1, 1 }) do
		createPart(
			statue, "Arm", Vector3.new(0.9, 3, 0.9),
			CFrame.new(base.X + xSign * 2, y + 4.5, base.Z),
			BrickColor.new("Bright red")
		)
	end

	-- Head + white beard + tall black hat with gold brim
	part("Head", Vector3.new(2, 2, 2), 7, BrickColor.new("Nougat"))
	createPart(
		statue, "Beard", Vector3.new(2.1, 1, 0.4),
		CFrame.new(base.X, y + 6.4, base.Z - 1.1),
		BrickColor.new("White")
	)
	part("HatBrim", Vector3.new(2.4, 0.4, 2.4), 8.2, BrickColor.new("Bright yellow"), Enum.Material.Neon)
	createPart(
		statue, "Hat", Vector3.new(3, 2, 2),
		CFrame.new(base.X, y + 9.4, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
		BrickColor.new("Really black")
	).Shape = Enum.PartType.Cylinder

	statue.Parent = parent
end

-- A candy-cane pole: alternating red/white stacked cylinders
local function buildCandyCane(parent, base)
	local segments = 8
	for i = 1, segments do
		local color = (i % 2 == 1) and BrickColor.new("Bright red") or BrickColor.new("White")
		createPart(
			parent, "CandyCane", Vector3.new(1, 0.9, 0.9),
			CFrame.new(base.X, base.Y + i - 0.5, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
			color
		).Shape = Enum.PartType.Cylinder
	end
end

-- The decorated evergreen tree (returns the star light for twinkling)
local function buildTree(parent, base)
	local tree = Instance.new("Model")
	tree.Name = "NutcrackerTree"

	createPart(
		tree, "Trunk", Vector3.new(1.5, 3, 1.5),
		CFrame.new(base.X, base.Y + 1.5, base.Z),
		BrickColor.new("Reddish brown"), Enum.Material.Wood
	)

	-- Stacked green spheres make a soft evergreen silhouette
	local layers = {
		{ size = 11, y = 6 },
		{ size = 8.5, y = 9.5 },
		{ size = 6, y = 12.5 },
	}
	for _, layer in ipairs(layers) do
		local foliage = createPart(
			tree, "Foliage", Vector3.new(layer.size, layer.size, layer.size),
			CFrame.new(base.X, base.Y + layer.y, base.Z),
			BrickColor.new("Dark green"), Enum.Material.Grass, false
		)
		foliage.Shape = Enum.PartType.Ball
	end

	-- Colored ornaments scattered over the foliage
	local ornamentColors = {
		Color3.fromRGB(255, 60, 60),
		Color3.fromRGB(255, 215, 0),
		Color3.fromRGB(120, 190, 255),
		Color3.fromRGB(255, 105, 180),
	}
	local rng = Random.new(12) -- Deterministic ornament placement
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local layer = layers[rng:NextInteger(1, #layers)]
		local radius = layer.size / 2 + 0.3
		local ornament = createPart(
			tree, "Ornament", Vector3.new(0.9, 0.9, 0.9),
			CFrame.new(
				base.X + math.cos(angle) * radius,
				base.Y + layer.y + rng:NextNumber(-1.5, 1.5),
				base.Z + math.sin(angle) * radius
			),
			BrickColor.new("White"), Enum.Material.Neon, false
		)
		ornament.Shape = Enum.PartType.Ball
		ornament.Color = ornamentColors[rng:NextInteger(1, #ornamentColors)]
	end

	-- Glowing star on top, with sparkles
	local star = createPart(
		tree, "Star", Vector3.new(1.8, 1.8, 1.8),
		CFrame.new(base.X, base.Y + 16, base.Z),
		BrickColor.new("Bright yellow"), Enum.Material.Neon, false
	)
	star.Shape = Enum.PartType.Ball

	local starLight = Instance.new("PointLight")
	starLight.Color = Color3.fromRGB(255, 230, 150)
	starLight.Brightness = 1.5
	starLight.Range = 20
	starLight.Parent = star

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Rate = 8
	sparkles.Lifetime = NumberRange.new(0.5, 1)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.Size = NumberSequence.new(0.3)
	sparkles.LightEmission = 0.8
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150))
	sparkles.Parent = star

	tree.Parent = parent
	return tree, starLight
end

-- Gentle snowfall localized above the plaza
local function buildSnow(parent, center)
	local emitterPart = createPart(
		parent, "SnowEmitter", Vector3.new(40, 1, 40),
		CFrame.new(center.X, GROUND_LEVEL + 28, center.Z),
		BrickColor.new("White"), Enum.Material.ForceField, false
	)
	emitterPart.Transparency = 1

	local snow = Instance.new("ParticleEmitter")
	snow.Rate = 30
	snow.Lifetime = NumberRange.new(6, 9)
	snow.Speed = NumberRange.new(2.5, 4)
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.Size = NumberSequence.new(0.45)
	snow.Transparency = NumberSequence.new(0.15)
	snow.LightEmission = 0.2
	snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	snow.Rotation = NumberRange.new(0, 360)
	snow.Parent = emitterPart
end

function NutcrackerBuilder:Build()
	local old = Workspace:FindFirstChild("NutcrackerPlaza")
	if old then
		old:Destroy()
	end

	local plaza = Instance.new("Folder")
	plaza.Name = "NutcrackerPlaza"
	plaza.Parent = Workspace

	local center = PLAZA.CENTER

	-- Plaza slab
	createPart(
		plaza, "PlazaFloor", PLAZA.PLAZA_SIZE,
		CFrame.new(center.X, GROUND_LEVEL + 0.5, center.Z),
		BrickColor.new("Institutional white"), Enum.Material.Marble
	)
	local floorTop = GROUND_LEVEL + PLAZA.PLAZA_SIZE.Y

	buildStatue(plaza, Vector3.new(center.X - 8, floorTop, center.Z + 6))

	-- Candy canes at the plaza corners
	for _, offset in ipairs({
		Vector3.new(-14, 0, -14),
		Vector3.new(14, 0, -14),
		Vector3.new(-14, 0, 14),
		Vector3.new(14, 0, 14),
	}) do
		buildCandyCane(plaza, Vector3.new(center.X + offset.X, floorTop, center.Z + offset.Z))
	end

	local tree, starLight = buildTree(plaza, Vector3.new(center.X + 7, floorTop, center.Z - 4))

	buildSnow(plaza, center)

	-- Plaque
	local plaque = createPart(
		plaza, "Plaque", Vector3.new(10, 4, 0.5),
		CFrame.new(center.X, GROUND_LEVEL + 2.5, center.Z - PLAZA.PLAZA_SIZE.Z / 2 - 1),
		BrickColor.new("Bright red")
	)
	local plaqueGui = Instance.new("SurfaceGui")
	plaqueGui.Face = Enum.NormalId.Front
	plaqueGui.Parent = plaque
	local plaqueLabel = Instance.new("TextLabel")
	plaqueLabel.Size = UDim2.new(1, 0, 1, 0)
	plaqueLabel.BackgroundTransparency = 1
	plaqueLabel.Text = "Nutcracker Plaza"
	plaqueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	plaqueLabel.TextScaled = true
	plaqueLabel.Font = Enum.Font.GothamBold
	plaqueLabel.Parent = plaqueGui

	-- Tree touch: twinkle the star + an encouraging notification
	local trunk = tree:FindFirstChild("Trunk")
	trunk.Touched:Connect(function(hit)
		local character = hit and hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local now = os.clock()
		if touchDebounce[player.UserId] and now - touchDebounce[player.UserId] < PLAZA.TREE_TOUCH_COOLDOWN then
			return
		end
		touchDebounce[player.UserId] = now

		-- Twinkle!
		starLight.Brightness = 5
		task.delay(0.6, function()
			starLight.Brightness = 1.5
		end)

		NotifyPlayer:FireClient(player, PLAZA.TREE_MESSAGE)
	end)

	Players.PlayerRemoving:Connect(function(player)
		touchDebounce[player.UserId] = nil
	end)

	print("NutcrackerBuilder finished: Nutcracker Plaza is open")
end

return NutcrackerBuilder
