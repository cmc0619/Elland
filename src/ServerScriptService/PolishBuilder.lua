--[[
	PolishBuilder
	Visual polish pass for Elland:
	  - Golden-hour lighting (Atmosphere, ColorCorrection, Bloom, SunRays,
	    warm ClockTime, soft ShadowMap shadows)
	  - Soft terrain clouds
	  - Cobble paths connecting the Hub to every zone (they bridge the river)
	  - Warm lampposts along the paths
	  - A fountain centerpiece beside the Hub platform

	Runs once at server start, right after WorldBuilder:BuildWorld().
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local WorldUtils = require(script.Parent.WorldUtils)

local PolishBuilder = {}

local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL

-- Golden-hour lighting and post-processing
function PolishBuilder:ApplyLighting()
	local settings = Constants.LIGHTING

	Lighting.ClockTime = settings.CLOCK_TIME
	Lighting.GeographicLatitude = settings.GEOGRAPHIC_LATITUDE
	Lighting.Ambient = settings.AMBIENT
	Lighting.OutdoorAmbient = settings.OUTDOOR_AMBIENT
	Lighting.Brightness = 2
	Lighting.GlobalShadows = true
	Lighting.Technology = Enum.Technology.ShadowMap

	-- Replace any previous atmosphere/post effects (idempotent rebuilds)
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = settings.ATMOSPHERE_COLOR
	atmosphere.Decay = settings.ATMOSPHERE_DECAY
	atmosphere.Glare = 0.2
	atmosphere.Haze = 2
	atmosphere.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.TintColor = settings.TINT
	colorCorrection.Saturation = 0.08
	colorCorrection.Brightness = 0.02
	colorCorrection.Contrast = 0.02
	colorCorrection.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 24
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.05
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting
end

-- Cheap soft clouds drifting over the map
function PolishBuilder:CreateClouds()
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
	end
	clouds.Cover = 0.35
	clouds.Density = 0.4
	clouds.Color = Color3.fromRGB(255, 250, 245)
	clouds.Parent = Workspace.Terrain
end

-- A warm glowing lamppost (pole + neon head + light)
local function createLamppost(parent, position)
	local pole = Instance.new("Part")
	pole.Name = "LamppostPole"
	pole.Size = Vector3.new(0.6, 7, 0.6)
	pole.Position = position + Vector3.new(0, 3.5, 0)
	pole.Anchored = true
	pole.BrickColor = BrickColor.new("Dark stone grey")
	pole.Material = Enum.Material.Metal
	pole.Parent = parent

	local head = Instance.new("Part")
	head.Name = "LamppostHead"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Position = position + Vector3.new(0, 7.5, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.Neon
	head.Color = Color3.fromRGB(255, 205, 130)
	head.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 130)
	light.Brightness = 1.2
	light.Range = 18
	light.Parent = head
end

-- Cobble paths from the Hub to each zone, with lampposts along the way
function PolishBuilder:BuildPaths(parent)
	local pathSettings = Constants.PATHS
	local hubPos = Constants.ZONES.Hub.Position
	local hub2D = Vector3.new(hubPos.X, 0, hubPos.Z)

	local lamppostCounter = 0

	for zoneName, zone in pairs(Constants.ZONES) do
		if zoneName ~= "Hub" then
			local to2D = Vector3.new(zone.Position.X, 0, zone.Position.Z)
			local offset = to2D - hub2D
			local distance = offset.Magnitude
			local dir = offset.Unit
			local perp = Vector3.new(-dir.Z, 0, dir.X)
			local step = pathSettings.SEGMENT_LENGTH
			local segmentCount = math.floor(distance / step)

			for i = 0, segmentCount - 1 do
				local segPos = hub2D + dir * (i * step + step / 2)

				local segment = Instance.new("Part")
				segment.Name = "PathSegment"
				segment.Anchored = true
				segment.Size = Vector3.new(pathSettings.WIDTH, 0.4, step + 0.5)
				-- Z axis points along the path direction
				segment.CFrame = CFrame.lookAt(
					Vector3.new(segPos.X, GROUND_LEVEL + 0.2, segPos.Z),
					Vector3.new(segPos.X + dir.X, GROUND_LEVEL + 0.2, segPos.Z + dir.Z)
				)
				segment.BrickColor = BrickColor.new("Cool yellow")
				segment.Material = Enum.Material.Cobblestone
				segment.TopSurface = Enum.SurfaceType.Smooth
				segment.Parent = parent

				-- Lampposts every few segments, alternating sides, on dry land
				lamppostCounter = lamppostCounter + 1
				if lamppostCounter % pathSettings.LAMPPOST_INTERVAL == 0 then
					local side = (lamppostCounter % 2 == 0) and 1 or -1
					local lampPos = segPos + perp * (side * (pathSettings.WIDTH / 2 + 2))
					if not WorldUtils:IsNearRiver(lampPos, 16) then
						createLamppost(parent, Vector3.new(lampPos.X, GROUND_LEVEL, lampPos.Z))
					end
				end
			end
		end
	end
end

-- Hub fountain centerpiece: stone basin, water disc, and an animated spray
function PolishBuilder:BuildFountain(parent)
	local hubPos = Constants.ZONES.Hub.Position
	local pos = hubPos + Constants.HUB.FOUNTAIN_OFFSET

	local fountain = Instance.new("Model")
	fountain.Name = "HubFountain"

	-- Basin (cylinder axis runs along X, so rotate 90 degrees to stand it up)
	local basin = Instance.new("Part")
	basin.Name = "Basin"
	basin.Shape = Enum.PartType.Cylinder
	basin.Size = Vector3.new(2.5, 16, 16)
	basin.CFrame = CFrame.new(Vector3.new(pos.X, GROUND_LEVEL + 1.25, pos.Z)) * CFrame.Angles(0, 0, math.rad(90))
	basin.Anchored = true
	basin.BrickColor = BrickColor.new("Light stone grey")
	basin.Material = Enum.Material.Marble
	basin.Parent = fountain

	-- Water surface inside the basin
	local water = Instance.new("Part")
	water.Name = "Water"
	water.Shape = Enum.PartType.Cylinder
	water.Size = Vector3.new(0.6, 13.5, 13.5)
	water.CFrame = CFrame.new(Vector3.new(pos.X, GROUND_LEVEL + 2.2, pos.Z)) * CFrame.Angles(0, 0, math.rad(90))
	water.Anchored = true
	water.CanCollide = false
	water.Transparency = 0.25
	water.Color = Color3.fromRGB(120, 190, 255)
	water.Material = Enum.Material.SmoothPlastic
	water.Parent = fountain

	-- Center column
	local column = Instance.new("Part")
	column.Name = "Column"
	column.Shape = Enum.PartType.Cylinder
	column.Size = Vector3.new(4, 1.6, 1.6)
	column.CFrame = CFrame.new(Vector3.new(pos.X, GROUND_LEVEL + 3.5, pos.Z)) * CFrame.Angles(0, 0, math.rad(90))
	column.Anchored = true
	column.BrickColor = BrickColor.new("Light stone grey")
	column.Material = Enum.Material.Marble
	column.Parent = fountain

	-- Spray nozzle ball on top of the column
	local nozzle = Instance.new("Part")
	nozzle.Name = "Nozzle"
	nozzle.Shape = Enum.PartType.Ball
	nozzle.Size = Vector3.new(2, 2, 2)
	nozzle.Position = Vector3.new(pos.X, GROUND_LEVEL + 6, pos.Z)
	nozzle.Anchored = true
	nozzle.CanCollide = false
	nozzle.Color = Color3.fromRGB(170, 215, 255)
	nozzle.Material = Enum.Material.Neon
	nozzle.Parent = fountain

	-- Water spray
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 35
	spray.Lifetime = NumberRange.new(0.5, 0.9)
	spray.Speed = NumberRange.new(6, 9)
	spray.SpreadAngle = Vector2.new(35, 35)
	spray.Size = NumberSequence.new(0.35)
	spray.Transparency = NumberSequence.new(0.3)
	spray.LightEmission = 0.4
	spray.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
	spray.Parent = nozzle

	fountain.Parent = parent
end

function PolishBuilder:Build()
	self:ApplyLighting()
	self:CreateClouds()

	local old = Workspace:FindFirstChild("Polish")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Polish"
	folder.Parent = Workspace

	self:BuildPaths(folder)
	self:BuildFountain(folder)

	print("PolishBuilder finished: lighting, clouds, paths, lampposts, fountain")
end

return PolishBuilder
