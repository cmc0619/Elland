--[[
	SoccerManager
	A small soccer pitch near the Hub with a kickable ball and two goals.

	Kicking: when a player touches the ball, the server punts it in the
	direction the player's character is facing (per-player debounce). The
	last kicker is remembered; if the ball then enters a goal detector,
	that player scores: leaderstats "Goals" +1, the scoreboard updates,
	confetti fires, and CurrencyManager pays a few Coins (1-minute payout
	cooldown per player). The ball resets to center after a goal, if it
	leaves the pitch area, or if it falls out of the world.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local SoccerManager = {}
SoccerManager.CurrencyManager = nil

local SOCCER = Constants.SOCCER
local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL

local ball = nil
local scoreboardLabel = nil
local lastScorerLabel = nil
local lastKicker = nil -- Player who last touched the ball
local kickDebounce = {} -- [UserId] = os.clock()
local goalPayoutTime = {} -- [UserId] = os.time()
local goalScores = { West = 0, East = 0 }

local function updateScoreboard(scorerName)
	if scoreboardLabel then
		scoreboardLabel.Text = string.format("WEST  %d  :  %d  EAST", goalScores.West, goalScores.East)
	end
	if lastScorerLabel and scorerName then
		lastScorerLabel.Text = "Last goal: " .. scorerName
	end
end

local function resetBall()
	if not ball then
		return
	end
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.Position = SOCCER.CENTER + Vector3.new(0, GROUND_LEVEL - SOCCER.CENTER.Y + SOCCER.BALL_SIZE, 0)
	lastKicker = nil
end

local function createPart(parent, name, size, cframe, color, material, transparency, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.BrickColor = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- One goal frame on the given end (-1 = West/-X, +1 = East/+X)
local function buildGoal(parent, side)
	local center = SOCCER.CENTER
	local halfLength = SOCCER.FIELD_SIZE.X / 2
	local goalLineX = center.X + side * halfLength
	local backX = goalLineX + side * SOCCER.GOAL_DEPTH
	local midX = (goalLineX + backX) / 2
	local baseY = GROUND_LEVEL + 1 -- Field top

	local white = BrickColor.new("White")

	-- Posts and crossbar
	for _, zSign in ipairs({ -1, 1 }) do
		createPart(
			parent,
			"GoalPost",
			Vector3.new(0.8, SOCCER.GOAL_HEIGHT, 0.8),
			CFrame.new(goalLineX, baseY + SOCCER.GOAL_HEIGHT / 2, center.Z + zSign * SOCCER.GOAL_WIDTH / 2),
			white
		)
	end
	createPart(
		parent,
		"Crossbar",
		Vector3.new(0.8, 0.8, SOCCER.GOAL_WIDTH + 0.8),
		CFrame.new(goalLineX, baseY + SOCCER.GOAL_HEIGHT, center.Z),
		white
	)

	-- Backstop and roof so the ball stays in the goal
	local net = BrickColor.new("Institutional white")
	createPart(
		parent,
		"GoalBack",
		Vector3.new(0.5, SOCCER.GOAL_HEIGHT, SOCCER.GOAL_WIDTH),
		CFrame.new(backX, baseY + SOCCER.GOAL_HEIGHT / 2, center.Z),
		net, Enum.Material.Fabric, 0.4
	)
	createPart(
		parent,
		"GoalRoof",
		Vector3.new(SOCCER.GOAL_DEPTH, 0.5, SOCCER.GOAL_WIDTH),
		CFrame.new(midX, baseY + SOCCER.GOAL_HEIGHT + 0.25, center.Z),
		net, Enum.Material.Fabric, 0.4
	)
	for _, zSign in ipairs({ -1, 1 }) do
		createPart(
			parent,
			"GoalSide",
			Vector3.new(SOCCER.GOAL_DEPTH, SOCCER.GOAL_HEIGHT, 0.5),
			CFrame.new(midX, baseY + SOCCER.GOAL_HEIGHT / 2, center.Z + zSign * SOCCER.GOAL_WIDTH / 2),
			net, Enum.Material.Fabric, 0.4
		)
	end

	-- Invisible goal detector just inside the goal line
	local detector = createPart(
		parent,
		(side < 0) and "GoalDetectorWest" or "GoalDetectorEast",
		Vector3.new(1, SOCCER.GOAL_HEIGHT, SOCCER.GOAL_WIDTH - 1),
		CFrame.new(goalLineX + side * 1.5, baseY + SOCCER.GOAL_HEIGHT / 2, center.Z),
		white, Enum.Material.ForceField, 1, false
	)

	-- Confetti cannon for goals
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
	confetti.Parent = detector

	detector.Touched:Connect(function(hit)
		if hit ~= ball then
			return
		end

		local sideName = (side < 0) and "West" or "East"
		goalScores[sideName] = goalScores[sideName] + 1

		local scorer = lastKicker
		local scorerName = scorer and scorer.Name or "Someone"
		updateScoreboard(scorerName)
		confetti:Emit(60)

		if scorer and scorer.Parent then
			-- leaderstats Goals +1
			local leaderstats = scorer:FindFirstChild("leaderstats")
			local goals = leaderstats and leaderstats:FindFirstChild("Goals")
			if goals then
				goals.Value = goals.Value + 1
			end

			-- Coin reward with per-player cooldown (server-authoritative)
			local now = os.time()
			local last = goalPayoutTime[scorer.UserId] or 0
			if now - last >= SOCCER.GOAL_COOLDOWN and SoccerManager.CurrencyManager then
				goalPayoutTime[scorer.UserId] = now
				SoccerManager.CurrencyManager:AddCurrency(scorer, SOCCER.GOAL_REWARD, "Soccer goal")
			end
		end

		task.delay(1, resetBall)
	end)
end

function SoccerManager:BuildPitch()
	local old = Workspace:FindFirstChild("SoccerPitch")
	if old then
		old:Destroy()
	end

	local pitch = Instance.new("Folder")
	pitch.Name = "SoccerPitch"
	pitch.Parent = Workspace

	local center = SOCCER.CENTER
	local field = SOCCER.FIELD_SIZE

	-- Field
	createPart(
		pitch,
		"Field",
		Vector3.new(field.X, 1, field.Z),
		CFrame.new(center.X, GROUND_LEVEL + 0.5, center.Z),
		BrickColor.new("Bright green"),
		Enum.Material.Grass
	)

	-- White lines: border + midfield
	local lineY = GROUND_LEVEL + 1.05
	local lineColor = BrickColor.new("White")
	local function line(name, sizeX, sizeZ, offsetX, offsetZ)
		createPart(
			pitch,
			name,
			Vector3.new(sizeX, 0.1, sizeZ),
			CFrame.new(center.X + offsetX, lineY, center.Z + offsetZ),
			lineColor, Enum.Material.SmoothPlastic, 0, false
		)
	end
	line("LineNorth", field.X, 0.5, 0, -field.Z / 2)
	line("LineSouth", field.X, 0.5, 0, field.Z / 2)
	line("LineWest", 0.5, field.Z, -field.X / 2, 0)
	line("LineEast", 0.5, field.Z, field.X / 2, 0)
	line("LineMid", 0.5, field.Z, 0, 0)

	-- Goals on each end
	buildGoal(pitch, -1) -- West
	buildGoal(pitch, 1) -- East

	-- Scoreboard beside the pitch
	local board = createPart(
		pitch,
		"Scoreboard",
		Vector3.new(18, 8, 1),
		CFrame.new(center.X, GROUND_LEVEL + 8, center.Z - field.Z / 2 - 4),
		BrickColor.new("Dark stone grey")
	)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.3, 0)
	title.BackgroundTransparency = 1
	title.Text = "SOCCER"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	scoreboardLabel = Instance.new("TextLabel")
	scoreboardLabel.Size = UDim2.new(1, 0, 0.4, 0)
	scoreboardLabel.Position = UDim2.new(0, 0, 0.3, 0)
	scoreboardLabel.BackgroundTransparency = 1
	scoreboardLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	scoreboardLabel.TextScaled = true
	scoreboardLabel.Font = Enum.Font.GothamBold
	scoreboardLabel.Parent = gui

	lastScorerLabel = Instance.new("TextLabel")
	lastScorerLabel.Size = UDim2.new(1, 0, 0.3, 0)
	lastScorerLabel.Position = UDim2.new(0, 0, 0.7, 0)
	lastScorerLabel.BackgroundTransparency = 1
	lastScorerLabel.Text = "Kick the ball to play!"
	lastScorerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	lastScorerLabel.TextScaled = true
	lastScorerLabel.Font = Enum.Font.Gotham
	lastScorerLabel.Parent = gui

	updateScoreboard(nil)

	-- The ball
	ball = Instance.new("Part")
	ball.Name = "SoccerBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(SOCCER.BALL_SIZE, SOCCER.BALL_SIZE, SOCCER.BALL_SIZE)
	ball.Color = Color3.fromRGB(255, 255, 255)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Position = Vector3.new(center.X, GROUND_LEVEL + SOCCER.BALL_SIZE, center.Z)
	ball.Parent = pitch

	-- Kicking: punt in the direction the character faces (server-side)
	ball.Touched:Connect(function(hit)
		local character = hit and hit.Parent
		if not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not rootPart then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local now = os.clock()
		if kickDebounce[player.UserId] and now - kickDebounce[player.UserId] < SOCCER.KICK_DEBOUNCE then
			return
			kickDebounce[player.UserId] = now
		end

		local look = rootPart.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			return
		end

		lastKicker = player
		ball.AssemblyLinearVelocity = flat.Unit * SOCCER.KICK_POWER + Vector3.new(0, SOCCER.KICK_LIFT, 0)
	end)

	-- Watchdog: reset the ball if it leaves the pitch or the world
	task.spawn(function()
		while ball and ball.Parent do
			task.wait(2)
			local margin = SOCCER.OUT_OF_BOUNDS_MARGIN
			local outX = math.abs(ball.Position.X - center.X) > field.X / 2 + margin
			local outZ = math.abs(ball.Position.Z - center.Z) > field.Z / 2 + margin
			local outY = ball.Position.Y < GROUND_LEVEL - 2 or ball.Position.Y > 200
			if outX or outZ or outY then
				resetBall()
			end
		end
	end)
end

function SoccerManager:SetupPlayer(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	if not leaderstats:FindFirstChild("Goals") then
		local goals = Instance.new("IntValue")
		goals.Name = "Goals"
		goals.Value = 0
		goals.Parent = leaderstats
	end
end

function SoccerManager:Init(currencyManager)
	self.CurrencyManager = currencyManager

	self:BuildPitch()

	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		kickDebounce[player.UserId] = nil
		goalPayoutTime[player.UserId] = nil
		if lastKicker == player then
			lastKicker = nil
		end
	end)

	print("SoccerManager initialized: pitch is open")
end

return SoccerManager
