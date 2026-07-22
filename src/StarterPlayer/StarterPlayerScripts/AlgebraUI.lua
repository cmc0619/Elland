--[[
	AlgebraUI
	Linear Lab practice interface for the Algebra Academy. Opens when the
	server fires OpenAlgebraUI (the "Practice!" prompt); requests a
	session via AlgebraStartRequest and renders the 5 server-generated
	questions one at a time: question text, 4 multiple-choice buttons, a
	progress bar, and a streak counter. The client sends ONLY the chosen
	option index - the server knows the correct answer and scores it.

	Follows the FashionUI module pattern: CreateUI/Open/Close/Init,
	initialized by ClientController.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AlgebraUI = {}
AlgebraUI.ScreenGui = nil

local OpenAlgebraUI
local AlgebraStartRequest
local AlgebraSession
local AlgebraAnswer
local AlgebraAnswerResult

local questions = {}
local currentQuestion = 1
local totalQuestions = 5
local awaitingResult = false
local advanceToken = 0

local questionLabel
local progressFill
local progressLabel
local streakLabel
local feedbackLabel
local optionButtons = {}

function AlgebraUI:CreateUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AlgebraUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.new(0, 460, 0, 380)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(47, 49, 54)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 14)
	frameCorner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -70, 0, 34)
	title.Position = UDim2.new(0, 16, 0, 12)
	title.BackgroundTransparency = 1
	title.Text = "Linear Lab"
	title.TextColor3 = Color3.fromRGB(190, 150, 255)
	title.TextSize = 24
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 40, 0, 34)
	close.Position = UDim2.new(1, -52, 0, 12)
	close.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
	close.Text = "X"
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.TextSize = 18
	close.Font = Enum.Font.GothamBold
	close.Parent = frame
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = close
	close.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Progress bar
	local progressBack = Instance.new("Frame")
	progressBack.Size = UDim2.new(1, -32, 0, 14)
	progressBack.Position = UDim2.new(0, 16, 0, 56)
	progressBack.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
	progressBack.BorderSizePixel = 0
	progressBack.Parent = frame
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 7)
	backCorner.Parent = progressBack

	progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(190, 150, 255)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 7)
	fillCorner.Parent = progressFill

	progressLabel = Instance.new("TextLabel")
	progressLabel.Size = UDim2.new(0, 200, 0, 18)
	progressLabel.Position = UDim2.new(0, 16, 0, 74)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "Question 1 of 5"
	progressLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	progressLabel.TextSize = 14
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.Font = Enum.Font.Gotham
	progressLabel.Parent = frame

	streakLabel = Instance.new("TextLabel")
	streakLabel.Size = UDim2.new(0, 200, 0, 18)
	streakLabel.Position = UDim2.new(1, -216, 0, 74)
	streakLabel.BackgroundTransparency = 1
	streakLabel.Text = "Streak: 0"
	streakLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	streakLabel.TextSize = 14
	streakLabel.TextXAlignment = Enum.TextXAlignment.Right
	streakLabel.Font = Enum.Font.GothamBold
	streakLabel.Parent = frame

	questionLabel = Instance.new("TextLabel")
	questionLabel.Size = UDim2.new(1, -32, 0, 80)
	questionLabel.Position = UDim2.new(0, 16, 0, 100)
	questionLabel.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
	questionLabel.Text = ""
	questionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	questionLabel.TextSize = 20
	questionLabel.TextWrapped = true
	questionLabel.Font = Enum.Font.GothamBold
	questionLabel.Parent = frame
	local questionCorner = Instance.new("UICorner")
	questionCorner.CornerRadius = UDim.new(0, 10)
	questionCorner.Parent = questionLabel

	-- 2x2 grid of option buttons
	optionButtons = {}
	for i = 1, 4 do
		local column = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		local button = Instance.new("TextButton")
		button.Name = "Option" .. i
		button.Size = UDim2.new(0, 206, 0, 52)
		button.Position = UDim2.new(0, 16 + column * 222, 0, 192 + row * 62)
		button.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
		button.Text = ""
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 22
		button.Font = Enum.Font.GothamBold
		button.Parent = frame
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 10)
		buttonCorner.Parent = button

		button.MouseButton1Click:Connect(function()
			self:ChooseOption(i)
		end)
		table.insert(optionButtons, button)
	end

	feedbackLabel = Instance.new("TextLabel")
	feedbackLabel.Size = UDim2.new(1, -32, 0, 36)
	feedbackLabel.Position = UDim2.new(0, 16, 1, -48)
	feedbackLabel.BackgroundTransparency = 1
	feedbackLabel.Text = ""
	feedbackLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	feedbackLabel.TextSize = 18
	feedbackLabel.Font = Enum.Font.GothamBold
	feedbackLabel.Parent = frame

	self.ScreenGui = gui
end

function AlgebraUI:ShowQuestion()
	local question = questions[currentQuestion]
	if not question then
		return
	end

	awaitingResult = false
	questionLabel.Text = question.prompt
	progressLabel.Text = "Question " .. currentQuestion .. " of " .. totalQuestions
	progressFill.Size = UDim2.new((currentQuestion - 1) / totalQuestions, 0, 1, 0)
	feedbackLabel.Text = ""

	for i, button in ipairs(optionButtons) do
		button.Text = tostring(question.options[i])
		button.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
		button.Active = true
	end
end

function AlgebraUI:ChooseOption(index)
	if awaitingResult or not self.ScreenGui.Enabled then
		return
	end
	awaitingResult = true

	for _, button in ipairs(optionButtons) do
		button.Active = false
	end

	AlgebraAnswer:FireServer(index)
end

function AlgebraUI:OnSession(data)
	if not data.success then
		-- Cooldown or busy: show the server's message on the panel
		questions = {}
		questionLabel.Text = data.error or "The Linear Lab is resting."
		progressLabel.Text = ""
		feedbackLabel.Text = ""
		streakLabel.Text = ""
		progressFill.Size = UDim2.new(0, 0, 1, 0)
		for _, button in ipairs(optionButtons) do
			button.Text = "-"
			button.Active = false
		end
		return
	end

	questions = data.questions
	totalQuestions = data.total or #questions
	currentQuestion = 1
	streakLabel.Text = "Streak: 0"
	self:ShowQuestion()
end

function AlgebraUI:OnAnswerResult(data)
	if data.expired then
		feedbackLabel.Text = "Session expired - tap Practice! to start again."
		return
	end
	if not data.success then
		awaitingResult = false
		return
	end

	-- Highlight the chosen outcome and reveal the correct answer
	for i, button in ipairs(optionButtons) do
		if i == data.correctIndex then
			button.BackgroundColor3 = Color3.fromRGB(67, 181, 129)
		end
	end
	streakLabel.Text = "Streak: " .. (data.streak or 0)
	progressFill.Size = UDim2.new((data.questionNumber or currentQuestion) / totalQuestions, 0, 1, 0)
	feedbackLabel.Text = data.message or ""

	advanceToken = advanceToken + 1
	local token = advanceToken

	task.delay(1.4, function()
		if token ~= advanceToken then
			return
		end
		if data.done then
			questionLabel.Text = string.format(
				"Worksheet complete!\nYou got %d/%d correct.\nBest streak: %d   +%d Coins",
				data.totalCorrect or 0, totalQuestions, data.bestStreak or 0, data.coinsEarned or 0
			)
			progressLabel.Text = "All done!"
			feedbackLabel.Text = "Come back after a short break for a new worksheet!"
			for _, button in ipairs(optionButtons) do
				button.Text = "-"
				button.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
				button.Active = false
			end
		else
			currentQuestion = currentQuestion + 1
			self:ShowQuestion()
		end
	end)
end

function AlgebraUI:Open()
	if not self.ScreenGui then
		return
	end
	self.ScreenGui.Enabled = true
	AlgebraStartRequest:FireServer()
end

function AlgebraUI:Close()
	advanceToken = advanceToken + 1
	awaitingResult = false
	if self.ScreenGui then
		self.ScreenGui.Enabled = false
	end
end

function AlgebraUI:Init()
	OpenAlgebraUI = ReplicatedStorage:WaitForChild("OpenAlgebraUI", 10)
	AlgebraStartRequest = ReplicatedStorage:WaitForChild("AlgebraStartRequest", 10)
	AlgebraSession = ReplicatedStorage:WaitForChild("AlgebraSession", 10)
	AlgebraAnswer = ReplicatedStorage:WaitForChild("AlgebraAnswer", 10)
	AlgebraAnswerResult = ReplicatedStorage:WaitForChild("AlgebraAnswerResult", 10)

	if not (OpenAlgebraUI and AlgebraStartRequest and AlgebraSession and AlgebraAnswer and AlgebraAnswerResult) then
		warn("AlgebraUI: remotes not found - server may still be starting")
		return
	end

	self:CreateUI()

	OpenAlgebraUI.OnClientEvent:Connect(function()
		self:Open()
	end)
	AlgebraSession.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			self:OnSession(data)
		end
	end)
	AlgebraAnswerResult.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			self:OnAnswerResult(data)
		end
	end)
end

return AlgebraUI
