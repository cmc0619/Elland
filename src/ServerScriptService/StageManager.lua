--[[
	StageManager
	Ella's Stage: a concert stage near the Hub (a nod to the Philadelphia
	Girls Choir). Raised platform, backdrop arch, warm spotlights, a mic
	stand, and bench seating for the family.

	Interaction: the "Perform!" ProximityPrompt on the mic stand pays a few
	Coins (2-minute per-player cooldown, server-side), bursts sparkles and
	musical notes over the stage, and puts the performer's name on the
	"Now Performing" billboard for 30 seconds.

	Audio: Constants.STAGE.CHOIR_SONGS is intentionally EMPTY. Real songs
	require audio uploaded/licensed by the owner in Roblox - paste the
	rbxassetid IDs there and Perform! will play a random one.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local StageManager = {}
StageManager.CurrencyManager = nil

local STAGE = Constants.STAGE
local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL

local performPayoutTime = {} -- [UserId] = os.time()
local billboardLabel = nil
local stageSound = nil
local billboardResetToken = 0

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

local function buildStageStructure(stage)
	local center = STAGE.CENTER
	local size = STAGE.PLATFORM_SIZE
	local topY = GROUND_LEVEL + size.Y

	-- Raised platform
	createPart(
		stage,
		"StagePlatform",
		size,
		CFrame.new(center.X, GROUND_LEVEL + size.Y / 2, center.Z),
		BrickColor.new("Reddish brown"),
		Enum.Material.Wood
	)

	-- Front steps
	createPart(
		stage,
		"Steps",
		Vector3.new(6, 1, 3),
		CFrame.new(center.X, GROUND_LEVEL + 0.5, center.Z - size.Z / 2 - 1.5),
		BrickColor.new("Reddish brown"),
		Enum.Material.Wood
	)

	-- Backdrop arch: two columns + top beam at the back edge
	local backZ = center.Z + size.Z / 2 - 1
	local archColor = BrickColor.new("Bright violet")
	for _, xSign in ipairs({ -1, 1 }) do
		createPart(
			stage,
			"ArchColumn",
			Vector3.new(1.5, 14, 1.5),
			CFrame.new(center.X + xSign * (size.X / 2 - 2), topY + 7, backZ),
			archColor
		)
	end
	createPart(
		stage,
		"ArchBeam",
		Vector3.new(size.X - 2, 1.5, 1.5),
		CFrame.new(center.X, topY + 14, backZ),
		archColor
	)

	-- "Now Performing" billboard on the arch beam
	local billboardPart = createPart(
		stage,
		"NowPerformingBoard",
		Vector3.new(size.X - 6, 4, 0.5),
		CFrame.new(center.X, topY + 11, backZ - 0.8),
		BrickColor.new("Dark stone grey"),
		Enum.Material.SmoothPlastic,
		false
	)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = billboardPart

	billboardLabel = Instance.new("TextLabel")
	billboardLabel.Size = UDim2.new(1, 0, 1, 0)
	billboardLabel.BackgroundTransparency = 1
	billboardLabel.Text = "Now Performing: -"
	billboardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	billboardLabel.TextScaled = true
	billboardLabel.Font = Enum.Font.GothamBold
	billboardLabel.Parent = gui

	-- Warm spotlights shining down on the stage from the arch beam
	for _, xSign in ipairs({ -1, 1 }) do
		local head = createPart(
			stage,
			"SpotlightHead",
			Vector3.new(1.5, 1, 1.5),
			CFrame.new(center.X + xSign * 8, topY + 13, backZ - 2),
			BrickColor.new("Dark stone grey"),
			Enum.Material.Metal,
			false
		)

		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Color = Color3.fromRGB(255, 215, 160)
		spot.Brightness = 3
		spot.Range = 25
		spot.Angle = 55
		spot.Parent = head
	end

	-- Bench seating for the family (3 rows in front of the stage)
	for row = 1, 3 do
		for _, xSign in ipairs({ -1, 1 }) do
			local bench = Instance.new("Seat")
			bench.Name = "AudienceBench"
			bench.Size = Vector3.new(8, 1, 2)
			bench.Position = Vector3.new(center.X + xSign * 6, GROUND_LEVEL + 0.5, center.Z - size.Z / 2 - 6 - row * 4)
			bench.Anchored = true
			bench.BrickColor = BrickColor.new("Medium brown")
			bench.Material = Enum.Material.Wood
			bench.TopSurface = Enum.SurfaceType.Smooth
			bench.Parent = stage
		end
	end
end

local function buildMicStand(stage)
	local center = STAGE.CENTER
	local topY = GROUND_LEVEL + STAGE.PLATFORM_SIZE.Y
	local micZ = center.Z - 3

	-- Thin pole + round mic head
	local pole = createPart(
		stage,
		"MicStand",
		Vector3.new(0.3, 4.5, 0.3),
		CFrame.new(center.X, topY + 2.25, micZ),
		BrickColor.new("Dark stone grey"),
		Enum.Material.Metal
	)

	createPart(
		stage,
		"MicHead",
		Vector3.new(1, 1, 1),
		CFrame.new(center.X, topY + 4.8, micZ),
		BrickColor.new("Really black"),
		Enum.Material.Metal
	).Shape = Enum.PartType.Ball

	-- Sparkles + "musical notes" burst above the mic
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 0
	sparkle.Lifetime = NumberRange.new(0.8, 1.5)
	sparkle.Speed = NumberRange.new(4, 8)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.Size = NumberSequence.new(0.5)
	sparkle.LightEmission = 0.6
	sparkle.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 105, 180)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(135, 206, 250)),
	})
	sparkle.Parent = pole

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Perform!"
	prompt.ObjectText = "Ella's Stage"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.Parent = pole

	prompt.Triggered:Connect(function(player)
		StageManager:HandlePerform(player, sparkle)
	end)
end

function StageManager:HandlePerform(player, sparkle)
	local now = os.time()
	local last = performPayoutTime[player.UserId] or 0
	if now - last < STAGE.PERFORM_COOLDOWN then
		return
	end
	performPayoutTime[player.UserId] = now

	if self.CurrencyManager then
		self.CurrencyManager:AddCurrency(player, STAGE.PERFORM_REWARD, "Stage performance")
	end

	sparkle:Emit(50)

	-- "Now Performing" billboard for a while, then reset
	billboardResetToken = billboardResetToken + 1
	local token = billboardResetToken
	if billboardLabel then
		billboardLabel.Text = "Now Performing: " .. player.Name
	end

	-- Optional song (only if the owner added audio IDs in Constants)
	if stageSound and #STAGE.CHOIR_SONGS > 0 then
		stageSound.SoundId = STAGE.CHOIR_SONGS[math.random(1, #STAGE.CHOIR_SONGS)]
		stageSound:Play()
	end

	task.delay(STAGE.BILLBOARD_DURATION, function()
		if token ~= billboardResetToken then
			return -- A newer performance took over
		end
		if billboardLabel then
			billboardLabel.Text = "Now Performing: -"
		end
		if stageSound and stageSound.IsPlaying then
			stageSound:Stop()
		end
	end)
end

function StageManager:Init(currencyManager)
	self.CurrencyManager = currencyManager

	local old = Workspace:FindFirstChild("EllasStage")
	if old then
		old:Destroy()
	end

	local stage = Instance.new("Folder")
	stage.Name = "EllasStage"
	stage.Parent = Workspace

	buildStageStructure(stage)
	buildMicStand(stage)

	-- Sound instance lives in the platform; plays only when CHOIR_SONGS has IDs
	local platform = stage:FindFirstChild("StagePlatform")
	stageSound = Instance.new("Sound")
	stageSound.Name = "StageSong"
	stageSound.Volume = Constants.SOUNDS.MUSIC_VOLUME
	stageSound.RollOffMaxDistance = 80
	stageSound.Parent = platform

	Players.PlayerRemoving:Connect(function(player)
		performPayoutTime[player.UserId] = nil
	end)

	print("StageManager initialized: Ella's Stage is open")
end

return StageManager
