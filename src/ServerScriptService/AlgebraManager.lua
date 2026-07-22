--[[
	AlgebraManager
	Algebra Academy: a little schoolhouse between the Hub and the Wordle
	Library (chalkboard, desks, sign) with a "Linear Lab" practice game
	and the Graphing Easel.

	LINEAR LAB - LINEAR ONLY, by construction: the question generators
	build problems from slope-intercept pieces (m, b, points) - there is
	no quadratic generator at all, so a quadratic can never appear.
	Question types (clean integer answers, 4 multiple-choice options with
	plausible distractors - sign flips, off-by-one, b/m swaps):
	  1. Solve for x:        ax + b = c
	  2. Find the slope      from two points on y = mx + b
	  3. Evaluate            y = mx + b for a given x
	  4. Find the y-intercept of a line through a point with slope m
	Flow: OpenAlgebraUI -> AlgebraStartRequest -> AlgebraSession (5
	server-generated questions, correct index known ONLY to the server) ->
	AlgebraAnswer (choice index) -> AlgebraAnswerResult. +2 Coins per
	correct answer (session cap 10, 5-minute per-player cooldown).
	AlgebraStats = { Sessions, Correct, BestStreak } persist.

	GRAPHING EASEL: the "Graph an equation" prompt fires OpenGraphUI; the
	client parses and renders locally with the shared EquationParser
	module (linear AND quadratic are both OK to graph - only the practice
	problems exclude quadratics). The first successful graph per session
	pays +2 Coins via GraphBonusRequest, which the server validates by
	re-parsing with the same shared module (5-minute cooldown).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local EquationParser = require(ReplicatedStorage.Shared.EquationParser)

local AlgebraManager = {}
AlgebraManager.PlayerDataService = nil
AlgebraManager.CurrencyManager = nil

-- RemoteEvents (created at module load so clients can WaitForChild them)
local OpenAlgebraUI = Instance.new("RemoteEvent")
OpenAlgebraUI.Name = "OpenAlgebraUI"
OpenAlgebraUI.Parent = ReplicatedStorage

local AlgebraStartRequest = Instance.new("RemoteEvent")
AlgebraStartRequest.Name = "AlgebraStartRequest"
AlgebraStartRequest.Parent = ReplicatedStorage

local AlgebraSession = Instance.new("RemoteEvent")
AlgebraSession.Name = "AlgebraSession"
AlgebraSession.Parent = ReplicatedStorage

local AlgebraAnswer = Instance.new("RemoteEvent")
AlgebraAnswer.Name = "AlgebraAnswer"
AlgebraAnswer.Parent = ReplicatedStorage

local AlgebraAnswerResult = Instance.new("RemoteEvent")
AlgebraAnswerResult.Name = "AlgebraAnswerResult"
AlgebraAnswerResult.Parent = ReplicatedStorage

local OpenGraphUI = Instance.new("RemoteEvent")
OpenGraphUI.Name = "OpenGraphUI"
OpenGraphUI.Parent = ReplicatedStorage

local GraphBonusRequest = Instance.new("RemoteEvent")
GraphBonusRequest.Name = "GraphBonusRequest"
GraphBonusRequest.Parent = ReplicatedStorage

-- Shared one-line notification channel (ClientController shows the toast)
local NotifyPlayer = ReplicatedStorage:FindFirstChild("NotifyPlayer")
if not NotifyPlayer then
	NotifyPlayer = Instance.new("RemoteEvent")
	NotifyPlayer.Name = "NotifyPlayer"
	NotifyPlayer.Parent = ReplicatedStorage
end

local ALGEBRA = Constants.ALGEBRA
local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL

-- [UserId] = session table: { questions, current, streak, bestStreak,
--   correct, coins, startedAt }
local activeSessions = {}
local lastSessionTime = {} -- [UserId] = os.time() (Linear Lab cooldown)
local lastGraphBonusTime = {} -- [UserId] = os.time() (graph bonus cooldown)

local rng = Random.new()

--------------------------------------------------------------------------------
-- Question generation (LINEAR ONLY - no quadratic generator exists here)
--------------------------------------------------------------------------------

-- Format a signed constant term, e.g. (5) -> "+ 5", (-3) -> "- 3"
local function signTerm(value)
	if value >= 0 then
		return "+ " .. value
	end
	return "- " .. math.abs(value)
end

-- Build 4 unique integer options (correct + plausible distractors) and
-- shuffle them. Returns (options, correctIndex).
local function buildOptions(correct, distractors)
	local options = { correct }
	local seen = { [tostring(correct)] = true }

	for _, candidate in ipairs(distractors) do
		if #options >= 4 then
			break
		end
		if type(candidate) == "number" and candidate == math.floor(candidate) and not seen[tostring(candidate)] then
			seen[tostring(candidate)] = true
			table.insert(options, candidate)
		end
	end

	-- Fallback filler if distractors collided
	local filler = correct + 2
	while #options < 4 do
		if not seen[tostring(filler)] then
			seen[tostring(filler)] = true
			table.insert(options, filler)
		end
		filler = filler + 1
	end

	-- Fisher-Yates shuffle
	for i = #options, 2, -1 do
		local j = rng:NextInteger(1, i)
		options[i], options[j] = options[j], options[i]
	end

	return options, table.find(options, correct)
end

-- Type 1: Solve for x in ax + b = c
local function genSolveForX()
	local a = rng:NextInteger(2, 9)
	local x = rng:NextInteger(-9, 9)
	local b = rng:NextInteger(-9, 9)
	local c = a * x + b

	local prompt = "Solve for x:  " .. a .. "x " .. signTerm(b) .. " = " .. c
	local options, correctIndex = buildOptions(x, { x + 1, x - 1, -x, x + 2 })
	return prompt, options, correctIndex
end

-- Type 2: Find the slope of the line through two points
local function genSlopeFromPoints()
	local m = rng:NextInteger(-4, 4)
	if m == 0 then
		m = 3
	end
	local b = rng:NextInteger(-6, 6)
	local x1 = rng:NextInteger(-4, 2)
	local x2 = x1 + rng:NextInteger(1, 4)
	local y1 = m * x1 + b
	local y2 = m * x2 + b

	local prompt = string.format("Find the slope of the line through (%d, %d) and (%d, %d)", x1, y1, x2, y2)
	local options, correctIndex = buildOptions(m, { -m, m + 1, m - 1, m + 2 })
	return prompt, options, correctIndex
end

-- Type 3: Evaluate y = mx + b for a given x
local function genEvaluate()
	local m = rng:NextInteger(-5, 5)
	if m == 0 then
		m = 2
	end
	local b = rng:NextInteger(-8, 8)
	local x = rng:NextInteger(-5, 5)
	local answer = m * x + b

	local prompt = "If y = " .. m .. "x " .. signTerm(b) .. ", what is y when x = " .. x .. "?"
	-- Distractors: sign flip on b, b/m swap, off-by-one
	local options, correctIndex = buildOptions(answer, { m * x - b, b * x + m, answer + 1, answer - 1 })
	return prompt, options, correctIndex
end

-- Type 4: Find the y-intercept of a line through a point with slope m
local function genIntercept()
	local m = rng:NextInteger(-4, 4)
	if m == 0 then
		m = -2
	end
	local x1 = rng:NextInteger(-5, 5)
	if x1 == 0 then
		x1 = 3
	end
	local b = rng:NextInteger(-8, 8)
	local y1 = m * x1 + b

	local prompt = string.format("A line has slope %d and passes through (%d, %d). What is its y-intercept?", m, x1, y1)
	-- Distractors: the point's y, the slope itself, sign flip on the mx term
	local options, correctIndex = buildOptions(b, { y1, m, y1 + m * x1, b + 1 })
	return prompt, options, correctIndex
end

local GENERATORS = { genSolveForX, genSlopeFromPoints, genEvaluate, genIntercept }

local function generateQuestions(count)
	local questions = {}
	for i = 1, count do
		local generator = GENERATORS[rng:NextInteger(1, #GENERATORS)]
		local prompt, options, correctIndex = generator()
		questions[i] = {
			prompt = prompt,
			options = options,
			correctIndex = correctIndex, -- Server-only; never sent to the client
		}
	end
	return questions
end

--------------------------------------------------------------------------------
-- Schoolhouse + easel structures
--------------------------------------------------------------------------------

local function createPart(parent, name, size, cframe, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildDesk(parent, position)
	createPart(parent, "DeskTop", Vector3.new(4, 0.4, 2.5),
		CFrame.new(position + Vector3.new(0, 2.6, 0)),
		Color3.fromRGB(180, 130, 85), Enum.Material.Wood)
	for _, offset in ipairs({ Vector3.new(-1.7, 1.2, -1), Vector3.new(1.7, 1.2, -1), Vector3.new(-1.7, 1.2, 1), Vector3.new(1.7, 1.2, 1) }) do
		createPart(parent, "DeskLeg", Vector3.new(0.4, 2.4, 0.4),
			CFrame.new(position + offset), Color3.fromRGB(150, 105, 60), Enum.Material.Wood)
	end
	local seat = Instance.new("Seat")
	seat.Name = "DeskSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Position = position + Vector3.new(0, 0.5, 2.4)
	seat.Anchored = true
	seat.Color = Color3.fromRGB(150, 105, 60)
	seat.Material = Enum.Material.Wood
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
end

-- The Graphing Easel: two legs, a tray, and a big graph-paper board whose
-- SurfaceGui (GraphPaperGui > GraphArea) the client draws grids/graphs on
function AlgebraManager:BuildEasel(school, baseTop)
	local center = ALGEBRA.POSITION
	local easelX = center.X + 16
	local easelZ = center.Z - 6

	-- A-frame legs
	for _, xSign in ipairs({ -1, 1 }) do
		createPart(school, "EaselLeg", Vector3.new(0.5, 14, 0.5),
			CFrame.new(easelX + xSign * 4.5, baseTop + 6.5, easelZ + 1)
				* CFrame.Angles(math.rad(-8), 0, xSign * math.rad(-12)),
			Color3.fromRGB(150, 105, 60), Enum.Material.Wood)
	end
	-- Cross tray the board rests on
	createPart(school, "EaselTray", Vector3.new(11, 0.6, 1.2),
		CFrame.new(easelX, baseTop + 2.2, easelZ),
		Color3.fromRGB(150, 105, 60), Enum.Material.Wood)

	-- Graph-paper board (faces the schoolhouse front, -Z)
	local board = createPart(school, "GraphBoard", Vector3.new(10, 10, 0.4),
		CFrame.new(easelX, baseTop + 7.6, easelZ),
		Color3.fromRGB(250, 250, 248), Enum.Material.SmoothPlastic, false)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "GraphPaperGui"
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = board

	-- The client draws GridLayer + GraphLayer inside this area
	local area = Instance.new("Frame")
	area.Name = "GraphArea"
	area.Size = UDim2.new(1, 0, 1, 0)
	area.BackgroundColor3 = Color3.fromRGB(250, 250, 248)
	area.BorderSizePixel = 0
	area.Parent = gui

	-- Prompt at the easel
	local promptPart = Instance.new("Part")
	promptPart.Name = "EaselInteraction"
	promptPart.Size = Vector3.new(4, 4, 4)
	promptPart.Shape = Enum.PartType.Ball
	promptPart.Position = Vector3.new(easelX, baseTop + 2, easelZ - 3)
	promptPart.Anchored = true
	promptPart.CanCollide = false
	promptPart.Transparency = 0.5
	promptPart.Color = Color3.fromRGB(255, 170, 120)
	promptPart.Material = Enum.Material.Neon
	promptPart.Parent = school

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Graph an equation"
	prompt.ObjectText = "Graphing Easel"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 14
	prompt.Parent = promptPart

	prompt.Triggered:Connect(function(player)
		OpenGraphUI:FireClient(player)
	end)
end

function AlgebraManager:BuildSchool()
	local old = Workspace:FindFirstChild("AlgebraAcademy")
	if old then
		old:Destroy()
	end

	local school = Instance.new("Folder")
	school.Name = "AlgebraAcademy"
	school.Parent = Workspace

	local center = ALGEBRA.POSITION
	local sizeX, sizeZ = 22, 16
	local wallHeight = 10
	local baseTop = GROUND_LEVEL + 1

	-- Base slab
	createPart(school, "Base", Vector3.new(sizeX, 1, sizeZ),
		CFrame.new(center.X, GROUND_LEVEL + 0.5, center.Z),
		Color3.fromRGB(210, 190, 160), Enum.Material.WoodPlanks)

	local wallColor = Color3.fromRGB(240, 230, 210) -- Warm schoolhouse cream
	local wallY = baseTop + wallHeight / 2

	-- Back and side walls (open front, like the bake shop)
	createPart(school, "BackWall", Vector3.new(sizeX, wallHeight, 1),
		CFrame.new(center.X, wallY, center.Z + sizeZ / 2), wallColor)
	for _, xSign in ipairs({ -1, 1 }) do
		createPart(school, "SideWall", Vector3.new(1, wallHeight, sizeZ),
			CFrame.new(center.X + xSign * sizeX / 2, wallY, center.Z), wallColor)
	end

	-- Roof
	createPart(school, "Roof", Vector3.new(sizeX + 2, 1, sizeZ + 2),
		CFrame.new(center.X, baseTop + wallHeight + 0.5, center.Z),
		Color3.fromRGB(120, 90, 160))

	-- Chalkboard on the back wall
	local board = createPart(school, "Chalkboard", Vector3.new(12, 6, 0.4),
		CFrame.new(center.X, baseTop + 5.5, center.Z + sizeZ / 2 - 0.8),
		Color3.fromRGB(45, 75, 55), Enum.Material.SmoothPlastic, false)
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Front
	boardGui.Parent = board
	local boardLabel = Instance.new("TextLabel")
	boardLabel.Size = UDim2.new(1, 0, 1, 0)
	boardLabel.BackgroundTransparency = 1
	boardLabel.Text = "Algebra Academy\ny = mx + b"
	boardLabel.TextColor3 = Color3.fromRGB(245, 245, 235)
	boardLabel.TextScaled = true
	boardLabel.Font = Enum.Font.GothamBold
	boardLabel.Parent = boardGui

	-- Desks facing the chalkboard
	for _, xOffset in ipairs({ -6, 0, 6 }) do
		buildDesk(school, Vector3.new(center.X + xOffset, baseTop, center.Z - 2))
	end

	-- Sign above the open front
	local sign = createPart(school, "Sign", Vector3.new(14, 3, 0.5),
		CFrame.new(center.X, baseTop + wallHeight + 2.5, center.Z - sizeZ / 2 - 1),
		Color3.fromRGB(250, 245, 235))
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "ALGEBRA ACADEMY"
	signLabel.TextColor3 = Color3.fromRGB(90, 60, 140)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Parent = signGui

	-- Linear Lab prompt by the door
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "AlgebraInteraction"
	interactionPart.Size = Vector3.new(5, 5, 5)
	interactionPart.Shape = Enum.PartType.Ball
	interactionPart.Position = Vector3.new(center.X - sizeX / 2 + 3, baseTop + 3, center.Z - sizeZ / 2 - 3)
	interactionPart.Anchored = true
	interactionPart.CanCollide = false
	interactionPart.Transparency = 0.5
	interactionPart.Color = Color3.fromRGB(170, 130, 255)
	interactionPart.Material = Enum.Material.Neon
	interactionPart.Parent = school

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 16
	light.Color = Color3.fromRGB(190, 150, 255)
	light.Parent = interactionPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Practice!"
	prompt.ObjectText = "Linear Lab"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 15
	prompt.Parent = interactionPart

	prompt.Triggered:Connect(function(player)
		local data = self.PlayerDataService and self.PlayerDataService:GetData(player)
		if not data then
			return
		end
		OpenAlgebraUI:FireClient(player)
	end)

	-- The Graphing Easel beside the schoolhouse
	self:BuildEasel(school, baseTop)

	print("AlgebraManager: Algebra Academy built (schoolhouse + graphing easel)")
end

--------------------------------------------------------------------------------
-- Linear Lab session flow (server generates AND validates; client sends indexes)
--------------------------------------------------------------------------------

function AlgebraManager:HandleStartRequest(player)
	if activeSessions[player.UserId] then
		-- Resume an in-progress session instead of erroring
		local session = activeSessions[player.UserId]
		if os.clock() - session.startedAt > ALGEBRA.SESSION_TIMEOUT then
			activeSessions[player.UserId] = nil
		else
			AlgebraSession:FireClient(player, { success = false, error = "Finish your current worksheet first!" })
			return
		end
	end

	local now = os.time()
	local last = lastSessionTime[player.UserId] or 0
	local remaining = ALGEBRA.SESSION_COOLDOWN - (now - last)
	if remaining > 0 then
		local minutes = math.ceil(remaining / 60)
		AlgebraSession:FireClient(player, {
			success = false,
			error = "The Linear Lab needs a short break! Try again in about " .. minutes .. " minute(s).",
		})
		return
	end

	local questions = generateQuestions(ALGEBRA.QUESTIONS_PER_SESSION)
	activeSessions[player.UserId] = {
		questions = questions,
		current = 1,
		streak = 0,
		bestStreak = 0,
		correct = 0,
		coins = 0,
		startedAt = os.clock(),
	}

	-- Client payload: prompts + options ONLY (never the correct index)
	local payload = {}
	for i, question in ipairs(questions) do
		payload[i] = { prompt = question.prompt, options = question.options }
	end

	AlgebraSession:FireClient(player, {
		success = true,
		questions = payload,
		total = #questions,
		coinsPerCorrect = ALGEBRA.COINS_PER_CORRECT,
	})
end

function AlgebraManager:HandleAnswer(player, choiceIndex)
	local session = activeSessions[player.UserId]
	if not session then
		return
	end

	-- Session expired (player walked away)
	if os.clock() - session.startedAt > ALGEBRA.SESSION_TIMEOUT then
		activeSessions[player.UserId] = nil
		AlgebraAnswerResult:FireClient(player, { expired = true })
		return
	end

	if type(choiceIndex) ~= "number" or choiceIndex < 1 or choiceIndex > 4 then
		return
	end

	local question = session.questions[session.current]
	if not question then
		return
	end

	local correct = (choiceIndex == question.correctIndex)
	local message

	if correct then
		session.streak = session.streak + 1
		session.bestStreak = math.max(session.bestStreak, session.streak)
		session.correct = session.correct + 1

		-- Coin payout with a hard session cap
		if session.coins < ALGEBRA.SESSION_COIN_CAP and self.CurrencyManager then
			local payout = math.min(ALGEBRA.COINS_PER_CORRECT, ALGEBRA.SESSION_COIN_CAP - session.coins)
			self.CurrencyManager:AddCurrency(player, payout, "Linear Lab")
			session.coins = session.coins + payout
		end

		message = ALGEBRA.ENCOURAGEMENTS[rng:NextInteger(1, #ALGEBRA.ENCOURAGEMENTS)]
	else
		session.streak = 0
		message = "Good try! The answer was " .. tostring(question.options[question.correctIndex]) .. "."
	end

	local done = session.current >= #session.questions

	AlgebraAnswerResult:FireClient(player, {
		success = true,
		correct = correct,
		correctIndex = question.correctIndex,
		questionNumber = session.current,
		total = #session.questions,
		streak = session.streak,
		message = message,
		done = done,
		totalCorrect = done and session.correct or nil,
		bestStreak = done and session.bestStreak or nil,
		coinsEarned = done and session.coins or nil,
	})

	if done then
		activeSessions[player.UserId] = nil
		lastSessionTime[player.UserId] = os.time()

		-- Persist stats (fields exist via migration-safe defaults)
		local data = self.PlayerDataService and self.PlayerDataService:GetData(player)
		if data and data.AlgebraStats then
			data.AlgebraStats.Sessions = (data.AlgebraStats.Sessions or 0) + 1
			data.AlgebraStats.Correct = (data.AlgebraStats.Correct or 0) + session.correct
			data.AlgebraStats.BestStreak = math.max(data.AlgebraStats.BestStreak or 0, session.bestStreak)
			self.PlayerDataService:UpdateData(player, "AlgebraStats", data.AlgebraStats)
		end

		NotifyPlayer:FireClient(player, "Linear Lab complete: " .. session.correct .. "/" .. #session.questions
			.. " correct! +" .. session.coins .. " " .. Constants.CURRENCY_NAME)
	else
		session.current = session.current + 1
	end
end

--------------------------------------------------------------------------------
-- Graphing Easel bonus: re-parse server-side, then pay once per cooldown
--------------------------------------------------------------------------------

function AlgebraManager:HandleGraphBonus(player, equationText)
	-- Never trust the client's "I graphed something valid" - re-parse it
	local parsed = EquationParser.Parse(equationText)
	if not parsed then
		return
	end

	local now = os.time()
	local last = lastGraphBonusTime[player.UserId] or 0
	if now - last < ALGEBRA.GRAPH_BONUS_COOLDOWN then
		return -- Cooldowns are silent: the graph still draws, just no payout
	end
	lastGraphBonusTime[player.UserId] = now

	if self.CurrencyManager then
		self.CurrencyManager:AddCurrency(player, ALGEBRA.GRAPH_BONUS, "First graph of the visit")
	end
	NotifyPlayer:FireClient(player, "Beautiful graph! +" .. ALGEBRA.GRAPH_BONUS .. " " .. Constants.CURRENCY_NAME)
end

function AlgebraManager:Init(playerDataService, currencyManager)
	self.PlayerDataService = playerDataService
	self.CurrencyManager = currencyManager

	self:BuildSchool()

	AlgebraStartRequest.OnServerEvent:Connect(function(player)
		self:HandleStartRequest(player)
	end)

	AlgebraAnswer.OnServerEvent:Connect(function(player, choiceIndex)
		self:HandleAnswer(player, choiceIndex)
	end)

	GraphBonusRequest.OnServerEvent:Connect(function(player, equationText)
		self:HandleGraphBonus(player, equationText)
	end)

	Players.PlayerRemoving:Connect(function(player)
		activeSessions[player.UserId] = nil
		lastSessionTime[player.UserId] = nil
		lastGraphBonusTime[player.UserId] = nil
	end)

	print("AlgebraManager initialized: Algebra Academy is open (linear only + graphing easel)")
end

return AlgebraManager
