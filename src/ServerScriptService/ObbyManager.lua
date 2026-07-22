--[[
	ObbyManager
	Ella's Obby: a short workout obstacle course near the Hub.

	Course: a start pad plus PLATFORM_COUNT jumps in a gentle zigzag line.
	Some platforms slide side to side (Heartbeat-driven sine), some blink
	in and out on a timer. Numbered checkpoint pads (stages 0, 4, 8) save
	the player's progress in leaderstats ("Obby Stage"); after dying, the
	player respawns at their highest checkpoint instead of the start.
	The gold winner pad pays Coins via CurrencyManager with a 5-minute
	cooldown and bursts confetti.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local ObbyManager = {}
ObbyManager.CurrencyManager = nil

local OBBY = Constants.OBBY

-- stage -> world CFrame of that checkpoint pad (for respawning)
local checkpointPads = {}
-- player.UserId -> highest stage reached
local playerStages = {}
-- player.UserId -> os.time() of last winner-pad payout
local lastWinTime = {}
-- moving platforms: { part, basePosition, phase }
local movingPlatforms = {}
-- blinking platforms: { part, phase }
local blinkingPlatforms = {}

-- World position of platform i (0 = start pad, PLATFORM_COUNT+1 = winner)
local function platformPosition(index)
	local zigzag = ((index % 2 == 0) and 1 or -1) * OBBY.LATERAL_ZIGZAG
	if index == 0 or index == OBBY.PLATFORM_COUNT + 1 then
		zigzag = 0 -- Start and winner pads stay centered
	end
	return OBBY.START + Vector3.new(
		index * OBBY.SPACING,
		0.5 + index * OBBY.RISE_PER_PLATFORM,
		zigzag
	)
end

local function playerFromHit(hit)
	local character = hit and hit.Parent
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function setStage(player, stage)
	local current = playerStages[player.UserId] or 0
	if stage <= current then
		return
	end
	playerStages[player.UserId] = stage

	local leaderstats = player:FindFirstChild("leaderstats")
	local stageValue = leaderstats and leaderstats:FindFirstChild("Obby Stage")
	if stageValue then
		stageValue.Value = stage
	end
end

local function createPad(parent, name, position, size, color, material)
	local pad = Instance.new("Part")
	pad.Name = name
	pad.Size = size
	pad.Position = position
	pad.Anchored = true
	pad.BrickColor = color
	pad.Material = material or Enum.Material.SmoothPlastic
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.Parent = parent
	return pad
end

-- Checkpoint pad: touching it saves progress
local function createCheckpoint(parent, stage, position)
	local pad = createPad(
		parent,
		"Checkpoint" .. stage,
		position,
		Vector3.new(8, 1, 8),
		BrickColor.new("Bright green")
	)
	checkpointPads[stage] = pad

	-- Number label so players can see their progress
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 60, 0, 30)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = (stage == 0) and "START" or ("Stage " .. stage)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local debounce = {}
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local now = os.clock()
		if debounce[player.UserId] and now - debounce[player.UserId] < 1 then
			return
		end
		debounce[player.UserId] = now
		setStage(player, stage)
	end)
end

-- Winner pad: coins + confetti, once per cooldown per player
local function createWinnerPad(parent, position)
	local pad = createPad(
		parent,
		"WinnerPad",
		position,
		Vector3.new(8, 1, 8),
		BrickColor.new("Bright yellow"),
		Enum.Material.Neon
	)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Brightness = 1.5
	light.Range = 16
	light.Parent = pad

	local confetti = Instance.new("ParticleEmitter")
	confetti.Rate = 0
	confetti.Lifetime = NumberRange.new(1, 2)
	confetti.Speed = NumberRange.new(10, 18)
	confetti.SpreadAngle = Vector2.new(180, 180)
	confetti.Size = NumberSequence.new(0.4)
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 105, 180)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(135, 206, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
	})
	confetti.Parent = pad

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 120, 0, 40)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "YOU DID IT!"
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player then
			return
		end

		local now = os.time()
		if lastWinTime[player.UserId] and now - lastWinTime[player.UserId] < OBBY.WIN_COOLDOWN then
			return
		end
		lastWinTime[player.UserId] = now

		-- Mark the run complete (stage past the last checkpoint)
		setStage(player, OBBY.PLATFORM_COUNT)

		if ObbyManager.CurrencyManager then
			ObbyManager.CurrencyManager:AddCurrency(player, OBBY.WIN_REWARD, "Finished Ella's Obby")
		end
		confetti:Emit(60)
	end)
end

function ObbyManager:BuildCourse()
	local old = Workspace:FindFirstChild("EllasObby")
	if old then
		old:Destroy()
	end

	local course = Instance.new("Folder")
	course.Name = "EllasObby"
	course.Parent = Workspace

	table.clear(movingPlatforms)
	table.clear(blinkingPlatforms)
	table.clear(checkpointPads)

	-- Start pad is also checkpoint stage 0
	createCheckpoint(course, 0, platformPosition(0))

	for i = 1, OBBY.PLATFORM_COUNT do
		local position = platformPosition(i)

		if table.find(OBBY.CHECKPOINT_STAGES, i) then
			createCheckpoint(course, i, position)
		else
			local platform = createPad(
				course,
				"Platform" .. i,
				position,
				OBBY.PLATFORM_SIZE,
				BrickColor.new("Bright blue")
			)

			if OBBY.MOVING_STAGES[i] then
				platform.BrickColor = BrickColor.new("Bright violet")
				table.insert(movingPlatforms, {
					part = platform,
					base = position,
					phase = i * 0.7,
				})
			elseif OBBY.BLINKING_STAGES[i] then
				platform.BrickColor = BrickColor.new("Bright orange")
				table.insert(blinkingPlatforms, {
					part = platform,
					phase = i * 0.9, -- Stagger so they don't all vanish together
				})
			end
		end
	end

	createWinnerPad(course, platformPosition(OBBY.PLATFORM_COUNT + 1))
end

-- Smooth side-to-side motion for the moving platforms
function ObbyManager:StartMovingLoop()
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, mover in ipairs(movingPlatforms) do
			if mover.part.Parent then
				local offset = math.sin((t + mover.phase) * (2 * math.pi / OBBY.MOVE_PERIOD)) * OBBY.MOVE_AMPLITUDE
				mover.part.Position = mover.base + Vector3.new(0, 0, offset)
			end
		end
	end)
end

-- Blinking platforms: solid for a while, then ghosted and non-collidable
function ObbyManager:StartBlinkingLoop()
	task.spawn(function()
		local cycle = OBBY.BLINK_VISIBLE_TIME + OBBY.BLINK_HIDDEN_TIME
		while true do
			local t = os.clock()
			for _, blinker in ipairs(blinkingPlatforms) do
				if blinker.part.Parent then
					local phaseTime = (t + blinker.phase) % cycle
					local visible = phaseTime < OBBY.BLINK_VISIBLE_TIME
					blinker.part.Transparency = visible and 0 or 0.75
					blinker.part.CanCollide = visible
				end
			end
			task.wait(0.1)
		end
	end)
end

-- leaderstats + checkpoint respawning
function ObbyManager:SetupPlayer(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	if not leaderstats:FindFirstChild("Obby Stage") then
		local stageValue = Instance.new("IntValue")
		stageValue.Name = "Obby Stage"
		stageValue.Value = 0
		stageValue.Parent = leaderstats
	end

	playerStages[player.UserId] = playerStages[player.UserId] or 0

	-- After dying, respawn at the highest checkpoint reached (not the start)
	player.CharacterAdded:Connect(function(character)
		local stage = playerStages[player.UserId] or 0
		if stage == 0 then
			return
		end

		local pad = checkpointPads[stage]
		if not pad then
			return
		end

		task.spawn(function()
			local rootPart = character:WaitForChild("HumanoidRootPart", 5)
			if rootPart then
				task.wait(0.1) -- Let the default spawn finish first
				rootPart.CFrame = pad.CFrame + Vector3.new(0, 3, 0)
			end
		end)
	end)
end

function ObbyManager:Init(currencyManager)
	self.CurrencyManager = currencyManager

	self:BuildCourse()
	self:StartMovingLoop()
	self:StartBlinkingLoop()

	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		playerStages[player.UserId] = nil
		lastWinTime[player.UserId] = nil
	end)

	print("ObbyManager initialized: Ella's Obby is open")
end

return ObbyManager
