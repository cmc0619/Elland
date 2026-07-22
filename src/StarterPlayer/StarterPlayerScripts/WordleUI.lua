--[[
	WordleUI
	Client-side Wordle game interface
	"Premium" Design Edition
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local WordleUI = {}

-- Remote Events
local WordleGuess
local WordleResult
local WordleNewGame

WordleUI.IsOpen = false
WordleUI.CurrentGuess = ""
WordleUI.CurrentRow = 1
WordleUI.GuessBoxes = {}
WordleUI.KeyboardButtons = {}

-- Modern Color Palette
local COLORS = {
	CORRECT = Color3.fromRGB(106, 170, 100),    -- Green
	PRESENT = Color3.fromRGB(201, 180, 88),     -- Yellow
	ABSENT = Color3.fromRGB(120, 124, 126),     -- Grey
	EMPTY = Color3.fromRGB(251, 252, 255),      -- Off-white
	BORDER = Color3.fromRGB(223, 224, 226),     -- Light border
	ACTIVE = Color3.fromRGB(135, 138, 140),     -- Active border
	TEXT = Color3.fromRGB(26, 26, 27),          -- Dark text
	BACKGROUND = Color3.fromRGB(255, 255, 255), -- White bg
	OVERLAY = Color3.fromRGB(0, 0, 0),          -- Dark overlay
	KEY_BG = Color3.fromRGB(211, 214, 218),     -- Keyboard key
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
	dimmer.BackgroundColor3 = COLORS.OVERLAY
	dimmer.BackgroundTransparency = 1 -- Start transparent for fade in
	dimmer.BorderSizePixel = 0
	dimmer.Parent = screenGui

	-- Main container
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 400, 0, 580) -- Compact, mobile-friendly size
	container.Position = UDim2.new(0.5, 0, 0.55, 0) -- Start slightly lower for slide up
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = COLORS.BACKGROUND
	container.BorderSizePixel = 0
	container.Parent = screenGui

	-- Styling: Shadow
	local shadow = Instance.new("UIStroke")
	shadow.Thickness = 6
	shadow.Transparency = 0.8
	shadow.Color = Color3.new(0, 0, 0)
	shadow.Parent = container

	-- Styling: Rounded Corners
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 16)
	containerCorner.Parent = container

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundTransparency = 1
	header.Parent = container

	local headerBorder = Instance.new("Frame")
	headerBorder.Name = "Border"
	headerBorder.Size = UDim2.new(1, 0, 0, 1)
	headerBorder.Position = UDim2.new(0, 0, 1, -1)
	headerBorder.BackgroundColor3 = COLORS.BORDER
	headerBorder.BorderSizePixel = 0
	headerBorder.Parent = header

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "Wordle"
	title.TextSize = 24
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = COLORS.TEXT
	title.Parent = header

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -45, 0.5, 0)
	closeButton.AnchorPoint = Vector2.new(0, 0.5)
	closeButton.BackgroundTransparency = 1
	closeButton.Text = "X"
	closeButton.TextSize = 20
	closeButton.Font = Enum.Font.Gotham
	closeButton.TextColor3 = COLORS.ABSENT
	closeButton.Parent = header

	closeButton.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Stats/Message display
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.Size = UDim2.new(1, -40, 0, 30)
	messageLabel.Position = UDim2.new(0.5, 0, 0, 60)
	messageLabel.AnchorPoint = Vector2.new(0.5, 0)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = "Welcome!"
	messageLabel.TextSize = 14
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextColor3 = COLORS.TEXT
	messageLabel.Parent = container

	-- Grid for guesses
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "GridFrame"
	gridFrame.Size = UDim2.new(0, 280, 0, 330) -- 5 cols * (50 size + 5 gap)
	gridFrame.Position = UDim2.new(0.5, 0, 0, 100)
	gridFrame.AnchorPoint = Vector2.new(0.5, 0)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = container

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 50, 0, 50)
	gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gridFrame

	-- Create 6x5 grid
	for row = 1, Constants.WORDLE.MAX_ATTEMPTS do
		self.GuessBoxes[row] = {}
		for col = 1, Constants.WORDLE.WORD_LENGTH do
			local box = Instance.new("Frame")
			box.Name = "Box_" .. row .. "_" .. col
			box.LayoutOrder = (row - 1) * 5 + col
			box.BackgroundColor3 = COLORS.BACKGROUND
			box.Parent = gridFrame

			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = COLORS.BORDER
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = box

			local letter = Instance.new("TextLabel")
			letter.Name = "Letter"
			letter.Size = UDim2.new(1, 0, 1, 0)
			letter.BackgroundTransparency = 1
			letter.Text = ""
			letter.TextSize = 28
			letter.Font = Enum.Font.GothamBold
			letter.TextColor3 = COLORS.TEXT
			letter.Parent = box

			self.GuessBoxes[row][col] = box
		end
	end

	-- Keyboard
	local keyboardFrame = Instance.new("Frame")
	keyboardFrame.Name = "KeyboardFrame"
	keyboardFrame.Size = UDim2.new(1, -20, 0, 120)
	keyboardFrame.Position = UDim2.new(0.5, 0, 1, -10)
	keyboardFrame.AnchorPoint = Vector2.new(0.5, 1)
	keyboardFrame.BackgroundTransparency = 1
	keyboardFrame.Parent = container

	local keyboardLayout = {
		{"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
		{"A", "S", "D", "F", "G", "H", "J", "K", "L"},
		{"ENTER", "Z", "X", "C", "V", "B", "N", "M", "<"}
	}

	local rowHeight = 36
	local keyGap = 4

	for rowIndex, keys in ipairs(keyboardLayout) do
		local rowFrame = Instance.new("Frame")
		rowFrame.Size = UDim2.new(1, 0, 0, rowHeight)
		rowFrame.Position = UDim2.new(0, 0, 0, (rowIndex - 1) * (rowHeight + keyGap))
		rowFrame.BackgroundTransparency = 1
		rowFrame.Parent = keyboardFrame

		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Padding = UDim.new(0, keyGap)
		list.Parent = rowFrame

		for _, key in ipairs(keys) do
			local keyButton = Instance.new("TextButton")
			keyButton.Name = "Key_" .. key

			local width = 28
			if key == "ENTER" or key == "<" then width = 45 end

			keyButton.Size = UDim2.new(0, width, 1, 0)
			keyButton.BackgroundColor3 = COLORS.KEY_BG
			keyButton.Text = key
			keyButton.TextSize = 12
			keyButton.Font = Enum.Font.GothamBold
			keyButton.TextColor3 = COLORS.TEXT
			keyButton.AutoButtonColor = false -- handled manually for style
			keyButton.Parent = rowFrame

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = keyButton

			self.KeyboardButtons[key] = keyButton

			-- Hover effect
			keyButton.MouseEnter:Connect(function()
				TweenService:Create(keyButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play()
			end)
			keyButton.MouseLeave:Connect(function()
				TweenService:Create(keyButton, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
			end)

			keyButton.MouseButton1Click:Connect(function()
				self:HandleKeyPress(key)
			end)
		end
	end

	screenGui.Parent = playerGui
	self.ScreenGui = screenGui
	self.Dimmer = dimmer
	self.Container = container
	self.MessageLabel = messageLabel

	print("Wordle UI created")
end

-- Handle key press
function WordleUI:HandleKeyPress(key)
	if key == "ENTER" then
		self:SubmitGuess()
	elseif key == "<" then
		if #self.CurrentGuess > 0 then
			self.CurrentGuess = self.CurrentGuess:sub(1, -2)
			self:UpdateDisplay()
		end
	else
		-- Letter
		if #self.CurrentGuess < Constants.WORDLE.WORD_LENGTH then
			self.CurrentGuess = self.CurrentGuess .. key

			-- Pop animation for typing. Tween the letter's TextSize, not the
			-- box Size: the UIGridLayout owns cell sizes and would fight a
			-- Size tween.
			local box = self.GuessBoxes[self.CurrentRow][#self.CurrentGuess]
			local letter = box and box:FindFirstChild("Letter")
			if letter then
				letter.TextSize = 34
				TweenService:Create(letter, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextSize = 28
				}):Play()
			end

			self:UpdateDisplay()
		end
	end
end

-- Update the display
function WordleUI:UpdateDisplay()
	for col = 1, Constants.WORDLE.WORD_LENGTH do
		local box = self.GuessBoxes[self.CurrentRow][col]
		local letter = box:FindFirstChild("Letter")
		local stroke = box:FindFirstChild("UIStroke")

		if col <= #self.CurrentGuess then
			letter.Text = self.CurrentGuess:sub(col, col)
			stroke.Color = COLORS.ACTIVE
			stroke.Thickness = 2
		else
			letter.Text = ""
			stroke.Color = COLORS.BORDER
			stroke.Thickness = 2
		end
	end
end

-- Submit guess
function WordleUI:SubmitGuess()
	if #self.CurrentGuess ~= Constants.WORDLE.WORD_LENGTH then
		self:FlashMessage("Not enough letters")
		-- Flash the row borders to indicate the rejection (a positional
		-- shake would fight the UIGridLayout)
		local rowBoxes = self.GuessBoxes[self.CurrentRow]
		for _, box in pairs(rowBoxes) do
			local stroke = box:FindFirstChild("UIStroke")
			local originalColor = stroke.Color
			stroke.Color = COLORS.ABSENT
			task.delay(0.2, function()
				stroke.Color = originalColor
			end)
		end
		return
	end

	WordleGuess:FireServer(self.CurrentGuess)
end

-- Handle result from server
function WordleUI:HandleResult(data)
	if not data.success then
		self:FlashMessage(data.error or "Something went wrong")
		return
	end

	-- Reveal animation. Flip via Rotation instead of Size so the tween
	-- doesn't fight the UIGridLayout, which owns cell sizes.
	for col, letterData in ipairs(data.result) do
		local box = self.GuessBoxes[self.CurrentRow][col]
		local letter = box:FindFirstChild("Letter")
		local stroke = box:FindFirstChild("UIStroke")

		-- Cascading delay
		task.wait(0.2)

		-- Flip part 1: rotate away
		local tween1 = TweenService:Create(box, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Rotation = 90
		})
		tween1:Play()
		tween1.Completed:Wait()

		-- Determine color
		local color = COLORS.ABSENT
		if letterData.status == "correct" then
			color = COLORS.CORRECT
		elseif letterData.status == "present" then
			color = COLORS.PRESENT
		end

		-- Apply state while flipped
		box.BackgroundColor3 = color
		stroke.Transparency = 1 -- Hide border on filled cells
		letter.TextColor3 = Color3.fromRGB(255, 255, 255) -- White text on colored bg

		-- Flip part 2: rotate back
		local tween2 = TweenService:Create(box, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = 0
		})
		tween2:Play()

		-- Update keyboard (never downgrade a green key back to yellow/grey)
		local keyButton = self.KeyboardButtons[letterData.letter]
		if keyButton then
			local formatColor = color
			if keyButton.BackgroundColor3 == COLORS.CORRECT then
				formatColor = COLORS.CORRECT
			end

			TweenService:Create(keyButton, TweenInfo.new(0.4), {
				BackgroundColor3 = formatColor,
				TextColor3 = Color3.fromRGB(255, 255, 255)
			}):Play()
		end
	end

	if data.complete then
		task.wait(1)

		local msg
		if data.won then
			local flavor = {"Genius", "Magnificent", "Impressive", "Splendid", "Great", "Phew"}
			msg = flavor[math.min(data.attempts, #flavor)]
			if data.reward then
				msg = msg .. "\n+" .. data.reward .. " " .. Constants.CURRENCY_NAME
			end
		else
			-- The server's message contains the actual answer
			msg = data.message or "Out of attempts!"
		end

		self.MessageLabel.Text = msg
		self.MessageLabel.TextTransparency = 0

		task.wait(4)
		self:Close()
	else
		self.CurrentRow = self.CurrentRow + 1
		self.CurrentGuess = ""
	end
end

-- Flash message on screen
function WordleUI:FlashMessage(text)
	self.MessageLabel.Text = text
	self.MessageLabel.TextTransparency = 0

	-- Fade out after delay
	task.delay(1.5, function()
		TweenService:Create(self.MessageLabel, TweenInfo.new(1), {TextTransparency = 1}):Play()
	end)
end

-- Open Wordle UI
function WordleUI:Open()
	if self.IsOpen then return end
	self.IsOpen = true

	if not self.ScreenGui then self:CreateUI() end
	self.ScreenGui.Enabled = true

	self.CurrentGuess = ""
	self.CurrentRow = 1
	self.MessageLabel.Text = "Guess the Wordle"
	self.MessageLabel.TextTransparency = 0

	-- Reset visual state of grid
	for row = 1, Constants.WORDLE.MAX_ATTEMPTS do
		for col = 1, Constants.WORDLE.WORD_LENGTH do
			local box = self.GuessBoxes[row][col]
			if box then
				box.Rotation = 0
				box.BackgroundColor3 = COLORS.BACKGROUND
				box:FindFirstChild("Letter").Text = ""
				box:FindFirstChild("Letter").TextColor3 = COLORS.TEXT
				box:FindFirstChild("UIStroke").Color = COLORS.BORDER
				box:FindFirstChild("UIStroke").Transparency = 0
			end
		end
	end

	-- Reset Keyboard
	for _, button in pairs(self.KeyboardButtons) do
		button.BackgroundColor3 = COLORS.KEY_BG
		button.TextColor3 = COLORS.TEXT
	end

	-- Entrance Animation
	self.Dimmer.BackgroundTransparency = 1
	self.Container.Position = UDim2.new(0.5, 0, 0.55, 0) -- Start lower

	local tweenDim = TweenService:Create(self.Dimmer, TweenInfo.new(0.3), {BackgroundTransparency = 0.5})
	local tweenCont = TweenService:Create(self.Container, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0)
	})

	tweenDim:Play()
	tweenCont:Play()

	-- Request State
	if WordleNewGame then WordleNewGame:FireServer() end
end

-- Close Wordle UI
function WordleUI:Close()
	self.IsOpen = false

	-- Exit Animation
	local tweenDim = TweenService:Create(self.Dimmer, TweenInfo.new(0.3), {BackgroundTransparency = 1})
	local tweenCont = TweenService:Create(self.Container, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.55, 0)
	})

	tweenDim:Play()
	tweenCont:Play()

	tweenCont.Completed:Wait()
	self.ScreenGui.Enabled = false
end

-- Handle new game state (restore grid)
function WordleUI:HandleNewGame(data)
	if data.complete then
		self.MessageLabel.Text = "Come back tomorrow"
		self.MessageLabel.TextTransparency = 0
		task.wait(2)
		self:Close()
	else
		-- Restore previous attempts (no animation)
		for i, guess in ipairs(data.guesses) do
			self.CurrentRow = i + 1
			for col, letterData in ipairs(guess.result) do
				local box = self.GuessBoxes[i][col]

				local color = COLORS.ABSENT
				if letterData.status == "correct" then color = COLORS.CORRECT
				elseif letterData.status == "present" then color = COLORS.PRESENT end

				box.BackgroundColor3 = color
				box:FindFirstChild("UIStroke").Transparency = 1
				local letter = box:FindFirstChild("Letter")
				letter.Text = letterData.letter
				letter.TextColor3 = Color3.fromRGB(255, 255, 255)

				-- Keyboard update
				local keyButton = self.KeyboardButtons[letterData.letter]
				if keyButton then
					if letterData.status == "correct" or keyButton.BackgroundColor3 ~= COLORS.CORRECT then
						keyButton.BackgroundColor3 = color
						keyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
					end
				end
			end
		end
	end
end

-- Initialize
function WordleUI:Init()
	-- Lazy load Remotes
	WordleGuess = ReplicatedStorage:WaitForChild("WordleGuess", 10)
	WordleResult = ReplicatedStorage:WaitForChild("WordleResult", 10)
	WordleNewGame = ReplicatedStorage:WaitForChild("WordleNewGame", 10)

	if not (WordleGuess and WordleResult and WordleNewGame) then
		warn("WordleUI: Missing Remotes")
		return
	end

	self:CreateUI()

	-- Wrap handlers in task.spawn so their animation delays don't block
	-- the RemoteEvent dispatch thread.
	WordleResult.OnClientEvent:Connect(function(data)
		task.spawn(function()
			self:HandleResult(data)
		end)
	end)
	WordleNewGame.OnClientEvent:Connect(function(data)
		task.spawn(function()
			self:HandleNewGame(data)
		end)
	end)

	print("WordleUI Initialized")
end

return WordleUI
