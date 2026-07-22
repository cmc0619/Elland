--[[
	SeasonManager
	Seasonal decoration overlays, chosen from the real date at server start
	(os.date). Season definitions live in Constants.SEASONS as pure data
	(date windows + colors + rates); this module just detects the active
	season and applies its decorations to a Workspace/SeasonDecorations
	folder. If no season's window contains today, the world stays as-is.

	WINTER (Dec 1 - Jan 6):
	  - Gentle map-wide snowfall (low-density emitter high over the map)
	  - Warm-white fairy-light strings wrapped around every lamppost
	  - Lamp heads + their PointLights recolored warm-white
	  - Nature tree canopies tinted snow-dusted green
	  - Nutcracker Plaza's EXISTING snow emitter rate is boosted (never
	    duplicated)

	Adding Halloween/Spring later is data-only: add a LIST entry with its
	date window (and any new decoration fields), put its ID in ORDER, and
	(if it needs a new decoration type) teach SeasonManager one new
	apply-step. Priority = first match in ORDER wins.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local SeasonManager = {}

local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL
local MAP_HALF = Constants.NATURE.MAP_EDGE -- Scatter bounds; snow covers this area

-- Is (month, day) inside the season's inclusive window? Windows may wrap
-- the new year (e.g. Dec 1 -> Jan 6 has StartMonth > EndMonth).
local function isInWindow(month, day, season)
	local sm, sd = season.StartMonth, season.StartDay
	local em, ed = season.EndMonth, season.EndDay

	if sm <= em then
		-- Normal window inside one calendar year
		if month < sm or month > em then
			return false
		end
		if month == sm and day < sd then
			return false
		end
		if month == em and day > ed then
			return false
		end
		return true
	else
		-- Window wraps the new year (e.g. Dec -> Jan)
		if month > sm or (month == sm and day >= sd) then
			return true
		end
		if month < em or (month == em and day <= ed) then
			return true
		end
		return false
	end
end

-- First season in ORDER whose window contains today (or nil)
function SeasonManager:GetCurrentSeason()
	local today = os.date("*t")
	for _, seasonId in ipairs(Constants.SEASONS.ORDER) do
		local season = Constants.SEASONS.LIST[seasonId]
		if season and isInWindow(today.month, today.day, season) then
			return seasonId, season
		end
	end
	return nil, nil
end

-- Gentle snowfall covering the whole map from high above
local function buildMapSnow(parent, season)
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "MapSnowEmitter"
	emitterPart.Size = Vector3.new(MAP_HALF * 2, 1, MAP_HALF * 2)
	emitterPart.CFrame = CFrame.new(0, GROUND_LEVEL + 55, 0)
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.Transparency = 1
	emitterPart.Parent = parent

	local snow = Instance.new("ParticleEmitter")
	snow.Rate = season.MapSnowRate or 10
	snow.Lifetime = NumberRange.new(8, 12)
	snow.Speed = NumberRange.new(2.5, 4)
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.Size = NumberSequence.new(0.4)
	snow.Transparency = NumberSequence.new(0.2)
	snow.LightEmission = 0.2
	snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	snow.Rotation = NumberRange.new(0, 360)
	snow.Parent = emitterPart
end

-- Fairy-light strings: tiny neon spheres spiraling up each lamppost pole,
-- plus a warm-white recolor of the lamp head and its light
local function decorateLampposts(parent, season)
	local polish = Workspace:FindFirstChild("Polish")
	if not polish then
		return
	end

	local lightColor = season.FairyLightColor or Color3.fromRGB(255, 240, 210)
	local bulbsPerPost = 6

	for _, descendant in ipairs(polish:GetDescendants()) do
		if descendant.Name == "LamppostPole" then
			for i = 1, bulbsPerPost do
				local angle = (i / bulbsPerPost) * math.pi * 4 -- Two lazy loops up the pole
				local height = (i - 0.5) * (descendant.Size.Y / bulbsPerPost)
				local bulb = Instance.new("Part")
				bulb.Name = "FairyLight"
				bulb.Shape = Enum.PartType.Ball
				bulb.Size = Vector3.new(0.35, 0.35, 0.35)
				bulb.Position = descendant.Position + Vector3.new(
					math.cos(angle) * 0.55,
					height - descendant.Size.Y / 2 + 0.5,
					math.sin(angle) * 0.55
				)
				bulb.Anchored = true
				bulb.CanCollide = false
				bulb.Material = Enum.Material.Neon
				bulb.Color = lightColor
				bulb.Parent = parent
			end
		elseif descendant.Name == "LamppostHead" then
			-- Warm-white winter glow
			descendant.Color = season.LamppostColor or lightColor
			local pointLight = descendant:FindFirstChildOfClass("PointLight")
			if pointLight then
				pointLight.Color = season.LamppostColor or lightColor
			end
		end
	end
end

-- Snow-dusted tree canopies across the Nature scatter
local function tintTreeCanopies(season)
	local nature = Workspace:FindFirstChild("Nature")
	if not nature or not season.TreeCanopyTint then
		return
	end
	for _, descendant in ipairs(nature:GetDescendants()) do
		if descendant.Name == "Canopy" and descendant:IsA("BasePart") then
			descendant.Color = season.TreeCanopyTint
		end
	end
end

-- Boost Nutcracker Plaza's existing snowfall (never add a second emitter)
local function boostNutcrackerSnow(season)
	local multiplier = season.NutcrackerSnowMultiplier
	if not multiplier or multiplier <= 1 then
		return
	end
	local plaza = Workspace:FindFirstChild("NutcrackerPlaza")
	local emitterPart = plaza and plaza:FindFirstChild("SnowEmitter")
	local snow = emitterPart and emitterPart:FindFirstChildOfClass("ParticleEmitter")
	if snow then
		snow.Rate = snow.Rate * multiplier
	end
end

function SeasonManager:Init()
	local seasonId, season = self:GetCurrentSeason()

	-- Clean any previous overlay (idempotent rebuilds)
	local old = Workspace:FindFirstChild("SeasonDecorations")
	if old then
		old:Destroy()
	end

	if not season then
		print("SeasonManager: no active season (world stays as-is)")
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "SeasonDecorations"
	folder.Parent = Workspace

	buildMapSnow(folder, season)
	decorateLampposts(folder, season)
	tintTreeCanopies(season)
	boostNutcrackerSnow(season)

	print("SeasonManager initialized: " .. season.Name .. " decorations applied (" .. seasonId .. ")")
end

return SeasonManager
