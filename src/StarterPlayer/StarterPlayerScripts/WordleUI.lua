--[[
	WordleUI
	Client-side Wordle game interface
	Beautiful, interactive Wordle game UI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local WordleUI = {}

-- Remote Events (initialized later to avoid blocking)
local WordleGuess
local WordleResult
local WordleNewGame
WordleUI.IsOpen = false
WordleUI.CurrentGuess = ""
WordleUI.CurrentRow = 1
WordleUI.GuessBoxes = {}
WordleUI.KeyboardButtons = {}

-- Colors for tile states
local COLORS = {
	CORRECT = Color3.fromRGB(106, 170, 100),
	PRESENT = Color3.fromRGB(201, 180, 88),
	ABSENT = Color3.fromRGB(120, 124, 126),
	EMPTY = Color3.fromRGB(211, 214, 218),
	ACTIVE = Color3.fromRGB(255, 255, 255),
}

-- Create the main Wordle UI
function WordleUI:CreateUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WordleUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false

	-- Background blur/dimmer
	local dimmer = Instance.new("Frame")
	dimmer.Name = "Dimmer"
	dimmer.Size = UDim2.new(1, 0, 1, 0)
	dimmer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimmer.BackgroundTransparency = 0.5
	dimmer.BorderSizePixel = 0
	dimmer.Parent = screenGui

	-- Main container
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 400, 0, 560)  -- Smaller size
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	container.BorderSizePixel = 0
	container.Parent = screenGui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 12)
	containerCorner.Parent = container

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 45)
	title.Position = UDim2.new(0, 20, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "WORDLE"
	title.TextSize = 26
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(50, 50, 50)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = container

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 32, 0, 32)
	closeButton.Position = UDim2.new(1, -42, 0, 12)
	closeButton.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
	closeButton.Text = "✕"
	closeButton.TextSize = 20
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextColor3 = Color3.fromRGB(50, 50, 50)
	closeButton.Parent = container

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Stats display
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(1, -32, 0, 30)
	statsFrame.Position = UDim2.new(0, 16, 0, 52)
	statsFrame.BackgroundTransparency = 1
	statsFrame.Parent = container

	local statsText = Instance.new("TextLabel")
	statsText.Name = "StatsText"
	statsText.Size = UDim2.new(1, 0, 1, 0)
	statsText.BackgroundTransparency = 1
	statsText.Text = "Loading..."
	statsText.TextSize = 12
	statsText.Font = Enum.Font.Gotham
	statsText.TextColor3 = Color3.fromRGB(100, 100, 100)
	statsText.TextXAlignment = Enum.TextXAlignment.Center
	statsText.Parent = statsFrame

	-- Grid for guesses
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "GridFrame"
	gridFrame.Size = UDim2.new(0, 270, 0, 300)
	gridFrame.Position = UDim2.new(0.5, 0, 0, 88)
	gridFrame.AnchorPoint = Vector2.new(0.5, 0)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = container

	-- Create 6x5 grid
	for row = 1, Constants.WORDLE.MAX_ATTEMPTS do
		for col = 1, Constants.WORDLE.WORD_LENGTH do
			local box = Instance.new("Frame")
			box.Name = "Box_" .. row .. "_" .. col
			box.Size = UDim2.new(0, 48, 0, 48)
			box.Position = UDim2.new(0, (col - 1) * 54, 0, (row - 1) * 54)
			box.BackgroundColor3 = COLORS.EMPTY
			box.BorderSizePixel = 2
			box.BorderColor3 = Color3.fromRGB(180, 180, 180)
			box.Parent = gridFrame

			local boxCorner = Instance.new("UICorner")
			boxCorner.CornerRadius = UDim.new(0, 4)
			boxCorner.Parent = box

			local letter = Instance.new("TextLabel")
			letter.Name = "Letter"
			letter.Size = UDim2.new(1, 0, 1, 0)
			letter.BackgroundTransparency = 1
			letter.Text = ""
			letter.TextSize = 26
			letter.Font = Enum.Font.GothamBold
			letter.TextColor3 = Color3.fromRGB(50, 50, 50)
			letter.Parent = box

			if not self.GuessBoxes[row] then
				self.GuessBoxes[row] = {}
			end
			self.GuessBoxes[row][col] = box
		end
	end

	-- Keyboard
	local keyboardFrame = Instance.new("Frame")
	keyboardFrame.Name = "KeyboardFrame"
	keyboardFrame.Size = UDim2.new(0, 380, 0, 150)
	keyboardFrame.Position = UDim2.new(0.5, 0, 1, -160)
	keyboardFrame.AnchorPoint = Vector2.new(0.5, 0)
	keyboardFrame.BackgroundTransparency = 1
	keyboardFrame.Parent = container

	local keyboardLayout = {
		{"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
		{"A", "S", "D", "F", "G", "H", "J", "K", "L"},
		{"ENTER", "Z", "X", "C", "V", "B", "N", "M", "⌫"}
	}

	for rowIndex, keys in ipairs(keyboardLayout) do
		local rowOffset = (rowIndex - 1) * 12
		for keyIndex, key in ipairs(keys) do
			local keyWidth = 32
			local keyX = (keyIndex - 1) * 36

			if key == "ENTER" or key == "⌫" then
				keyWidth = 50
			end

			if rowIndex == 2 then
				keyX = keyX + 18
			elseif rowIndex == 3 and keyIndex > 1 then
				keyX = keyX + 50
			end

			local keyButton = Instance.new("TextButton")
			keyButton.Name = "Key_" .. key
			keyButton.Size = UDim2.new(0, keyWidth, 0, 42)
			keyButton.Position = UDim2.new(0, keyX, 0, rowIndex * 46)
			keyButton.BackgroundColor3 = Color3.fromRGB(211, 214, 218)
			keyButton.Text = key
			keyButton.TextSize = key == "ENTER" and 10 or 16
			keyButton.Font = Enum.Font.GothamBold
			keyButton.TextColor3 = Color3.fromRGB(0, 0, 0)
			keyButton.Parent = keyboardFrame

			local keyCorner = Instance.new("UICorner")
			keyCorner.CornerRadius = UDim.new(0, 4)
			keyCorner.Parent = keyButton

			self.KeyboardButtons[key] = keyButton

			keyButton.MouseButton1Click:Connect(function()
				self:HandleKeyPress(key)
			end)
		end
	end

	screenGui.Parent = playerGui
	self.ScreenGui = screenGui
	self.StatsText = statsText

	print("Wordle UI created")
end

-- Handle key press
function WordleUI:HandleKeyPress(key)
	print("WordleUI:HandleKeyPress():", key)
	
	if key == "ENTER" then
		self:SubmitGuess()
	elseif key == "⌫" then
		if #self.CurrentGuess > 0 then
			self.CurrentGuess = self.CurrentGuess:sub(1, -2)
			self:UpdateDisplay()
		end
	else
		if #self.CurrentGuess < Constants.WORDLE.WORD_LENGTH then
			self.CurrentGuess = self.CurrentGuess .. key
			self:UpdateDisplay()
		end
	end
end

-- Update the display
function WordleUI:UpdateDisplay()
	for col = 1, Constants.WORDLE.WORD_LENGTH do
		local box = self.GuessBoxes[self.CurrentRow][col]
		local letter = box:FindFirstChild("Letter")

		if col <= #self.CurrentGuess then
			letter.Text = self.CurrentGuess:sub(col, col)
			box.BackgroundColor3 = COLORS.ACTIVE
		else
			letter.Text = ""
			box.BackgroundColor3 = COLORS.EMPTY
		end
	end
end

-- Submit guess
function WordleUI:SubmitGuess()
	print("WordleUI:SubmitGuess() called with:", self.CurrentGuess, "length:", #self.CurrentGuess)
	
	if #self.CurrentGuess ~= Constants.WORDLE.WORD_LENGTH then
		print("WordleUI: Not enough letters, need", Constants.WORDLE.WORD_LENGTH)
		self:ShowMessage("Not enough letters!", Color3.fromRGB(237, 66, 69))
		return
	end

	print("WordleUI: Firing guess to server:", self.CurrentGuess)
	WordleGuess:FireServer(self.CurrentGuess)
end

-- Handle result from server
function WordleUI:HandleResult(data)
	print("WordleUI: Received result from server", data.success)
	
	if not data.success then
		-- Show error visually
		warn("WordleUI error:", data.error)
		self:ShowMessage(data.error or "Unknown error", Color3.fromRGB(237, 66, 69))
		return
	end
	
	print("WordleUI: Processing successful result")

	-- Animate the result
	for col, letterData in ipairs(data.result) do
		local box = self.GuessBoxes[self.CurrentRow][col]

		task.wait(0.1)

		local color = COLORS.ABSENT
		if letterData.status == "correct" then
			color = COLORS.CORRECT
		elseif letterData.status == "present" then
			color = COLORS.PRESENT
		end

		-- Flip animation
		local tween = TweenService:Create(box, TweenInfo.new(0.3), {
			BackgroundColor3 = color
		})
		tween:Play()

		-- Update keyboard
		local keyButton = self.KeyboardButtons[letterData.letter]
		if keyButton then
			keyButton.BackgroundColor3 = color
		end
	end

	if data.complete then
		task.wait(1)

		if data.won then
			self:ShowMessage("🎉 Amazing! You got it in " .. data.attempts .. " tries!\n+" .. (data.reward or 0) .. " coins", Color3.fromRGB(106, 170, 100))
		else
			self:ShowMessage("😊 Good try! Come back tomorrow for a new word!", Color3.fromRGB(201, 180, 88))
		end

		task.wait(3)
		self:Close()
	else
		self.CurrentRow = self.CurrentRow + 1
		self.CurrentGuess = ""
	end
end

-- Show message
function WordleUI:ShowMessage(text, color)
	local message = Instance.new("TextLabel")
	message.Size = UDim2.new(0, 400, 0, 100)
	message.Position = UDim2.new(0.5, 0, 0.5, 0)
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.BackgroundColor3 = color or Color3.fromRGB(100, 100, 100)
	message.Text = text
	message.TextSize = 18
	message.Font = Enum.Font.GothamBold
	message.TextColor3 = Color3.fromRGB(255, 255, 255)
	message.TextWrapped = true
	message.Parent = self.ScreenGui.Container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = message

	task.wait(2)
	message:Destroy()
end

-- Open Wordle UI
function WordleUI:Open()
	print("WordleUI:Open() called")
	
	if self.IsOpen then 
		print("WordleUI already open, returning")
		return 
	end

	self.IsOpen = true
	self.CurrentGuess = ""
	self.CurrentRow = 1

	-- Reset grid
	if self.GuessBoxes then
		for row = 1, Constants.WORDLE.MAX_ATTEMPTS do
			for col = 1, Constants.WORDLE.WORD_LENGTH do
				local box = self.GuessBoxes[row] and self.GuessBoxes[row][col]
				if box then
					box.BackgroundColor3 = COLORS.EMPTY
					local letter = box:FindFirstChild("Letter")
					if letter then letter.Text = "" end
				end
			end
		end
	end

	-- Reset keyboard
	if self.KeyboardButtons then
		for _, button in pairs(self.KeyboardButtons) do
			button.BackgroundColor3 = Color3.fromRGB(211, 214, 218)
		end
	end

	if self.ScreenGui then
		self.ScreenGui.Enabled = true
		print("WordleUI: ScreenGui enabled")
	else
		warn("WordleUI: ScreenGui is nil!")
	end

	-- Request game state
	if WordleNewGame then
		WordleNewGame:FireServer()
		print("WordleUI: Requested new game state")
	else
		warn("WordleUI: WordleNewGame RemoteEvent is nil!")
	end
end

-- Close Wordle UI
function WordleUI:Close()
	self.IsOpen = false
	self.ScreenGui.Enabled = false
end

-- Handle new game state
function WordleUI:HandleNewGame(data)
	if data.complete then
		if data.won then
			self.StatsText.Text = "✓ Today's Wordle complete! Come back tomorrow."
		else
			self.StatsText.Text = "✗ No more attempts today. Try again tomorrow!"
		end

		-- Show previous guesses
		for i, guess in ipairs(data.guesses) do
			for col, letterData in ipairs(guess.result) do
				local box = self.GuessBoxes[i][col]
				box:FindFirstChild("Letter").Text = letterData.letter

				if letterData.status == "correct" then
					box.BackgroundColor3 = COLORS.CORRECT
				elseif letterData.status == "present" then
					box.BackgroundColor3 = COLORS.PRESENT
				else
					box.BackgroundColor3 = COLORS.ABSENT
				end
			end
		end

		task.wait(3)
		self:Close()
	else
		self.StatsText.Text = string.format("Wins: %d | Streak: %d | Attempts: %d/%d",
			data.stats.totalWins,
			data.stats.currentStreak,
			data.attempts,
			data.maxAttempts
		)

		-- Show previous guesses
		for i, guess in ipairs(data.guesses) do
			self.CurrentRow = i + 1
			for col, letterData in ipairs(guess.result) do
				local box = self.GuessBoxes[i][col]
				box:FindFirstChild("Letter").Text = letterData.letter

				if letterData.status == "correct" then
					box.BackgroundColor3 = COLORS.CORRECT
				elseif letterData.status == "present" then
					box.BackgroundColor3 = COLORS.PRESENT
				else
					box.BackgroundColor3 = COLORS.ABSENT
				end

				-- Update keyboard
				local keyButton = self.KeyboardButtons[letterData.letter]
				if keyButton then
					local currentColor = keyButton.BackgroundColor3
					if currentColor == COLORS.CORRECT then
						-- Keep correct
					elseif letterData.status == "correct" then
						keyButton.BackgroundColor3 = COLORS.CORRECT
					elseif letterData.status == "present" and currentColor ~= COLORS.CORRECT then
						keyButton.BackgroundColor3 = COLORS.PRESENT
					elseif currentColor ~= COLORS.CORRECT and currentColor ~= COLORS.PRESENT then
						keyButton.BackgroundColor3 = COLORS.ABSENT
					end
				end
			end
		end
	end
end

-- Initialize
function WordleUI:Init()
	print("WordleUI:Init() starting...")
	
	-- Initialize remote events now (lazy loading to avoid blocking module load)
	WordleGuess = ReplicatedStorage:WaitForChild("WordleGuess", 10)
	WordleResult = ReplicatedStorage:WaitForChild("WordleResult", 10)
	WordleNewGame = ReplicatedStorage:WaitForChild("WordleNewGame", 10)
	
	print("WordleUI: Remote events found:", WordleGuess ~= nil, WordleResult ~= nil, WordleNewGame ~= nil)
	
	if not WordleGuess or not WordleResult or not WordleNewGame then
		warn("WordleUI: Could not find all remote events - UI will not work!")
		return
	end
	
	self:CreateUI()
	print("WordleUI: UI created, ScreenGui =", self.ScreenGui ~= nil)

	-- Listen for results
	WordleResult.OnClientEvent:Connect(function(data)
		self:HandleResult(data)
	end)

	-- Listen for new game state
	WordleNewGame.OnClientEvent:Connect(function(data)
		self:HandleNewGame(data)
	end)

	print("WordleUI initialized")
end

return WordleUI
