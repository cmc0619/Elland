--[[
	ClientController
	Main client-side script that initializes UI and client systems
	Handles communication with server and manages local state
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")


-- Remote Events
local CurrencyChanged
local TeleportRequest

-- Initialize RemoteEvents
local function initializeRemotes()
	CurrencyChanged = ReplicatedStorage:WaitForChild("CurrencyChanged")
	TeleportRequest = ReplicatedStorage:WaitForChild("TeleportRequest")

	print("RemoteEvents initialized")
end

-- Handle currency updates from server
local function onCurrencyChanged(newAmount, change)
	ClientController.Currency = newAmount

	if change > 0 then
		ClientController:ShowCurrencyGain(change)
	elseif change < 0 then
		ClientController:ShowCurrencyLoss(math.abs(change))
	end

	ClientController:UpdateCurrencyDisplay()
end

-- Show currency gain animation
function ClientController:ShowCurrencyGain(amount)
	local notification = Instance.new("TextLabel")
	notification.Size = UDim2.new(0, 200, 0, 40)
	notification.Position = UDim2.new(1, -220, 0, 80)
	notification.BackgroundColor3 = Color3.fromRGB(106, 170, 100)
	notification.Text = "+ " .. amount .. " " .. Constants.CURRENCY_NAME
	notification.TextSize = 18
	notification.Font = Enum.Font.GothamBold
	notification.TextColor3 = Color3.fromRGB(255, 255, 255)
	notification.Parent = self.MainHUD

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification

	-- Animate
	notification.Position = UDim2.new(1, -220, 0, 80)
	TweenService:Create(notification, TweenInfo.new(0.3), {
		Position = UDim2.new(1, -220, 0, 90)
	}):Play()

	task.wait(2)

	TweenService:Create(notification, TweenInfo.new(0.3), {
		BackgroundTransparency = 1,
		TextTransparency = 1
	}):Play()

	task.wait(0.3)
	notification:Destroy()
end

-- Show currency loss animation
function ClientController:ShowCurrencyLoss(amount)
	local notification = Instance.new("TextLabel")
	notification.Size = UDim2.new(0, 200, 0, 40)
	notification.Position = UDim2.new(1, -220, 0, 80)
	notification.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
	notification.Text = "- " .. amount .. " " .. Constants.CURRENCY_NAME
	notification.TextSize = 18
	notification.Font = Enum.Font.GothamBold
	notification.TextColor3 = Color3.fromRGB(255, 255, 255)
	notification.Parent = self.MainHUD

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification

	task.wait(2)

	TweenService:Create(notification, TweenInfo.new(0.3), {
		BackgroundTransparency = 1,
		TextTransparency = 1
	}):Play()

	task.wait(0.3)
	notification:Destroy()
end

-- Create enhanced HUD
function ClientController:CreateHUD()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Currency Display
	local currencyFrame = Instance.new("Frame")
	currencyFrame.Name = "CurrencyFrame"
	currencyFrame.Size = UDim2.new(0, 200, 0, 50)
	currencyFrame.Position = UDim2.new(1, -220, 0, 20)
	currencyFrame.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	currencyFrame.BorderSizePixel = 0
	currencyFrame.Parent = screenGui

	local currencyCorner = Instance.new("UICorner")
	currencyCorner.CornerRadius = UDim.new(0, 10)
	currencyCorner.Parent = currencyFrame

	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.Name = "CurrencyLabel"
	currencyLabel.Size = UDim2.new(1, -20, 1, 0)
	currencyLabel.Position = UDim2.new(0, 10, 0, 0)
	currencyLabel.BackgroundTransparency = 1
	currencyLabel.Text = "💰 0 Coins"
	currencyLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
	currencyLabel.TextSize = 20
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Center
	currencyLabel.Font = Enum.Font.GothamBold
	currencyLabel.Parent = currencyFrame

	-- Zone Display
	local zoneFrame = Instance.new("Frame")
	zoneFrame.Name = "ZoneFrame"
	zoneFrame.Size = UDim2.new(0, 300, 0, 60)
	zoneFrame.Position = UDim2.new(0, 20, 0, 20)
	zoneFrame.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
	zoneFrame.BorderSizePixel = 0
	zoneFrame.Parent = screenGui

	local zoneCorner = Instance.new("UICorner")
	zoneCorner.CornerRadius = UDim.new(0, 10)
	zoneCorner.Parent = zoneFrame

	local zoneLabel = Instance.new("TextLabel")
	zoneLabel.Name = "ZoneLabel"
	zoneLabel.Size = UDim2.new(1, -20, 0, 30)
	zoneLabel.Position = UDim2.new(0, 10, 0, 5)
	zoneLabel.BackgroundTransparency = 1
	zoneLabel.Text = "📍 By the River"
	zoneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	zoneLabel.TextSize = 18
	zoneLabel.TextXAlignment = Enum.TextXAlignment.Left
	zoneLabel.Font = Enum.Font.GothamBold
	zoneLabel.TextStrokeTransparency = 0.5
	zoneLabel.Parent = zoneFrame

	local zoneHint = Instance.new("TextLabel")
	zoneHint.Name = "ZoneHint"
	zoneHint.Size = UDim2.new(1, -20, 0, 20)
	zoneHint.Position = UDim2.new(0, 10, 0, 35)
	zoneHint.BackgroundTransparency = 1
	zoneHint.Text = "Press M to open map"
	zoneHint.TextColor3 = Color3.fromRGB(255, 255, 255)
	zoneHint.TextSize = 12
	zoneHint.TextXAlignment = Enum.TextXAlignment.Left
	zoneHint.Font = Enum.Font.Gotham
	zoneHint.TextTransparency = 0.3
	zoneHint.Parent = zoneFrame

	-- Controls hint (bottom center)
	local controlsFrame = Instance.new("Frame")
	controlsFrame.Name = "ControlsFrame"
	controlsFrame.Size = UDim2.new(0, 400, 0, 80)
	controlsFrame.Position = UDim2.new(0.5, 0, 1, -100)
	controlsFrame.AnchorPoint = Vector2.new(0.5, 0)
	controlsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	controlsFrame.BackgroundTransparency = 0.3
	controlsFrame.BorderSizePixel = 0
	controlsFrame.Parent = screenGui

	local controlsCorner = Instance.new("UICorner")
	controlsCorner.CornerRadius = UDim.new(0, 10)
	controlsCorner.Parent = controlsFrame

	local controlsLabel = Instance.new("TextLabel")
	controlsLabel.Size = UDim2.new(1, -20, 1, 0)
	controlsLabel.Position = UDim2.new(0, 10, 0, 0)
	controlsLabel.BackgroundTransparency = 1
	controlsLabel.Text = "🗺️  Press M to open Map\n📚 Look for glowing objects to interact"
	controlsLabel.TextSize = 14
	controlsLabel.Font = Enum.Font.Gotham
	controlsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	controlsLabel.TextWrapped = true
	controlsLabel.Parent = controlsFrame

	screenGui.Parent = playerGui
	self.MainHUD = screenGui
	self.CurrencyLabel = currencyLabel
	self.ZoneLabel = zoneLabel
	self.ZoneFrame = zoneFrame

	print("Enhanced HUD created")
end

-- Update currency display
function ClientController:UpdateCurrencyDisplay()
	if self.CurrencyLabel then
		self.CurrencyLabel.Text = "💰 " .. tostring(self.Currency) .. " Coins"
	end
end

-- Update zone display
function ClientController:UpdateZoneDisplay(zoneName)
	if self.ZoneLabel and self.ZoneFrame then
		local zoneData = Constants.ZONES[zoneName or self.CurrentZone]
		if zoneData then
			self.ZoneLabel.Text = "📍 " .. zoneData.Name
			self.ZoneFrame.BackgroundColor3 = zoneData.Color
		end
	end
end

-- Create welcome screen
function ClientController:CreateWelcomeScreen()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WelcomeScreen"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
	background.BorderSizePixel = 0
	background.Parent = screenGui

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 150, 255))
	}
	gradient.Rotation = 45
	gradient.Parent = background

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 600, 0, 100)
	title.Position = UDim2.new(0.5, 0, 0.3, 0)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.BackgroundTransparency = 1
	title.Text = "Welcome to ELLAND"
	title.TextSize = 48
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeTransparency = 0.5
	title.Parent = background

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(0, 600, 0, 150)
	subtitle.Position = UDim2.new(0.5, 0, 0.5, 0)
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Explore the world, play Wordle, design fashion,\nand build amazing creations!\n\n🗺️  Press M anytime to open the Map\n📚 Find the Wordle Library to play word puzzles"
	subtitle.TextSize = 18
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	subtitle.TextWrapped = true
	subtitle.Parent = background

	local continueButton = Instance.new("TextButton")
	continueButton.Size = UDim2.new(0, 250, 0, 60)
	continueButton.Position = UDim2.new(0.5, 0, 0.7, 0)
	continueButton.AnchorPoint = Vector2.new(0.5, 0.5)
	continueButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	continueButton.Text = "Start Exploring!"
	continueButton.TextSize = 24
	continueButton.Font = Enum.Font.GothamBold
	continueButton.TextColor3 = Color3.fromRGB(100, 150, 255)
	continueButton.Parent = background

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 12)
	buttonCorner.Parent = continueButton

	local function closeWelcomeScreen()
		TweenService:Create(background, TweenInfo.new(0.5), {
			BackgroundTransparency = 1
		}):Play()

		TweenService:Create(title, TweenInfo.new(0.5), {
			TextTransparency = 1
		}):Play()

		TweenService:Create(subtitle, TweenInfo.new(0.5), {
			TextTransparency = 1
		}):Play()

		TweenService:Create(continueButton, TweenInfo.new(0.5), {
			BackgroundTransparency = 1,
			TextTransparency = 1
		}):Play()

		task.wait(0.5)
		screenGui:Destroy()
	end

	continueButton.MouseButton1Click:Connect(closeWelcomeScreen)

	-- Auto-close after 3 seconds so player isn't stuck
	task.delay(3, closeWelcomeScreen)

	screenGui.Parent = playerGui
end

-- Initialize the controller
function ClientController:Init()
	print("Initializing ClientController for", player.Name)

	-- Wait for character
	local character = player.Character or player.CharacterAdded:Wait()
	print("Character loaded")

	-- Enforce movement settings
	local humanoid = character:WaitForChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
		
		-- Ensure the humanoid can move
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		
		print("Movement settings enforced - WalkSpeed:", humanoid.WalkSpeed, "JumpPower:", humanoid.JumpPower)
		
		-- Monitor and fix movement if it gets stuck
		task.spawn(function()
			while humanoid and humanoid.Parent do
				task.wait(0.5)
				
				-- Check WalkSpeed
				if humanoid.WalkSpeed ~= 16 then
					humanoid.WalkSpeed = 16
					print("Fixed WalkSpeed")
				end
				
				-- Check States
				if not humanoid:GetStateEnabled(Enum.HumanoidStateType.Running) then
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
					print("Re-enabled Running state")
				end
				
				-- Check Anchored (common cause of "stuck in run animation")
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart and rootPart.Anchored then
					rootPart.Anchored = false
					print("Fixed: Unanchored HumanoidRootPart")
				end
			end
		end)
	end

	-- Initialize remote events
	initializeRemotes()

	-- Set up event listeners
	CurrencyChanged.OnClientEvent:Connect(function(newAmount, change)
		onCurrencyChanged(newAmount, change)
	end)

	-- Create HUD
	self:CreateHUD()

	-- Initialize UI modules
	WordleUI:Init()
	
	-- Listen for Wordle open event from server
	local openWordleEvent = ReplicatedStorage:WaitForChild("OpenWordleUI", 10)
	if openWordleEvent then
		openWordleEvent.OnClientEvent:Connect(function()
			WordleUI:Open()
		end)
		print("Wordle UI event connected")
	end
	
	ZoneMenuUI:Init()

	-- Show welcome screen
	-- task.wait(1)
	-- self:CreateWelcomeScreen()  -- TEMPORARILY DISABLED TO TEST MOVEMENT

	-- Update displays
	self:UpdateCurrencyDisplay()
	self:UpdateZoneDisplay()

	-- Finished loading
	self.IsLoading = false

	print("ClientController initialized")
	print("Welcome to Elland!")

	-- Store reference globally for other scripts
	_G.ClientController = self
	_G.WordleUI = WordleUI
	_G.ZoneMenuUI = ZoneMenuUI
end

-- Start the controller
ClientController:Init()

return ClientController
