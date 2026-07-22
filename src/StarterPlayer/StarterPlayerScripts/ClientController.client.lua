--[[
	ClientController
	Main client-side script that initializes UI and client systems
	Handles communication with server and manages local state
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Get player references
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load shared modules
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

-- Load UI modules (they are ModuleScripts required by this LocalScript)
local WordleUI = require(script.Parent:WaitForChild("WordleUI"))
local ZoneMenuUI = require(script.Parent:WaitForChild("ZoneMenuUI"))
local FashionUI = require(script.Parent:WaitForChild("FashionUI"))
local PetUI = require(script.Parent:WaitForChild("PetUI"))
local BakeShopUI = require(script.Parent:WaitForChild("BakeShopUI"))
local TalentShowUI = require(script.Parent:WaitForChild("TalentShowUI"))
local AlgebraUI = require(script.Parent:WaitForChild("AlgebraUI"))

-- Create the ClientController table
local ClientController = {}
ClientController.Currency = 0
ClientController.CurrentZone = "Hub"
ClientController.IsLoading = true
ClientController.MainHUD = nil
ClientController.CurrencyLabel = nil
ClientController.ZoneLabel = nil
ClientController.ZoneFrame = nil

-- Remote Events
local CurrencyChanged
local TeleportRequest

-- Initialize RemoteEvents with timeout to avoid blocking
local function initializeRemotes()
	CurrencyChanged = ReplicatedStorage:WaitForChild("CurrencyChanged", 10)
	TeleportRequest = ReplicatedStorage:WaitForChild("TeleportRequest", 10)

	if CurrencyChanged and TeleportRequest then
		print("RemoteEvents initialized")
	else
		warn("Some RemoteEvents failed to initialize - server may still be starting")
	end
end

-- Handle currency updates from server
local function onCurrencyChanged(newAmount, change)
	ClientController.Currency = newAmount

	-- Show gain/loss notifications without blocking the event handler
	if change > 0 then
		task.spawn(function()
			ClientController:ShowCurrencyGain(change)
		end)
	elseif change < 0 then
		task.spawn(function()
			ClientController:ShowCurrencyLoss(math.abs(change))
		end)
	end

	ClientController:UpdateCurrencyDisplay()
end

-- Show currency gain animation
function ClientController:ShowCurrencyGain(amount)
	if not self.MainHUD then return end

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
	if not self.MainHUD then return end

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

-- Generic toast notification (used by world events via NotifyPlayer,
-- e.g. the Nutcracker Plaza tree's "Break a leg, Ella!")
function ClientController:ShowNotification(text)
	if not self.MainHUD then return end

	local notification = Instance.new("TextLabel")
	notification.Size = UDim2.new(0, 320, 0, 44)
	notification.Position = UDim2.new(0.5, 0, 0, 20)
	notification.AnchorPoint = Vector2.new(0.5, 0)
	notification.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	notification.Text = text
	notification.TextSize = 18
	notification.Font = Enum.Font.GothamBold
	notification.TextColor3 = Color3.fromRGB(255, 255, 255)
	notification.Parent = self.MainHUD

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = notification

	TweenService:Create(notification, TweenInfo.new(0.3), {
		Position = UDim2.new(0.5, 0, 0, 30)
	}):Play()

	task.wait(Constants.UI.NOTIFICATION_DURATION)

	TweenService:Create(notification, TweenInfo.new(0.3), {
		BackgroundTransparency = 1,
		TextTransparency = 1
	}):Play()

	task.wait(0.3)
	notification:Destroy()
end

-- Create HUD
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
	currencyLabel.Text = "0 " .. Constants.CURRENCY_NAME
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
	zoneLabel.Text = "By the River"
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
	controlsLabel.Text = "Press M to open Map\nLook for glowing objects to interact"
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

	print("HUD created")
end

-- Update currency display
function ClientController:UpdateCurrencyDisplay()
	if self.CurrencyLabel then
		self.CurrencyLabel.Text = tostring(self.Currency) .. " " .. Constants.CURRENCY_NAME
	end
end

-- Update zone display
function ClientController:UpdateZoneDisplay(zoneName)
	if self.ZoneLabel and self.ZoneFrame then
		local zoneData = Constants.ZONES[zoneName or self.CurrentZone]
		if zoneData then
			self.ZoneLabel.Text = zoneData.Name
			self.ZoneFrame.BackgroundColor3 = zoneData.Color
		end
	end
end

-- Set up movement for a character
local function setupCharacterMovement(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		warn("Could not find Humanoid")
		return
	end

	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	humanoid.AutoRotate = true

	-- Ensure the humanoid can move
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)

	-- Monitor and fix movement if it gets stuck
	task.spawn(function()
		while humanoid and humanoid.Parent do
			task.wait(0.5)

			-- Check WalkSpeed
			if humanoid.WalkSpeed ~= 16 then
				humanoid.WalkSpeed = 16
			end

			-- Check States
			if not humanoid:GetStateEnabled(Enum.HumanoidStateType.Running) then
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
			end

			-- Check Anchored (common cause of "stuck in run animation")
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart and rootPart.Anchored then
				rootPart.Anchored = false
			end
		end
	end)
end

-- Initialize the controller
function ClientController:Init()
	print("Initializing ClientController for", player.Name)

	-- Set up movement for current character
	if player.Character then
		setupCharacterMovement(player.Character)
	end

	-- Handle character respawns
	player.CharacterAdded:Connect(function(newCharacter)
		setupCharacterMovement(newCharacter)
	end)

	-- Initialize remote events
	initializeRemotes()

	-- Set up event listeners (if remotes exist)
	if CurrencyChanged then
		CurrencyChanged.OnClientEvent:Connect(function(newAmount, change)
			onCurrencyChanged(newAmount, change)
		end)
	end

	-- Create HUD
	local hudSuccess, hudError = pcall(function()
		self:CreateHUD()
	end)
	if not hudSuccess then
		warn("HUD creation failed:", hudError)
	end

	-- Initialize UI modules with error protection
	local wordleSuccess, wordleError = pcall(function()
		WordleUI:Init()
	end)
	if not wordleSuccess then
		warn("WordleUI init failed:", wordleError)
	end

	-- Listen for Wordle open event from server (ProximityPrompt at the library)
	local openWordleEvent = ReplicatedStorage:WaitForChild("OpenWordleUI", 10)
	if openWordleEvent then
		openWordleEvent.OnClientEvent:Connect(function()
			if WordleUI and WordleUI.Open then
				WordleUI:Open()
			end
		end)
	end

	local zoneSuccess, zoneError = pcall(function()
		ZoneMenuUI:Init()
	end)
	if not zoneSuccess then
		warn("ZoneMenuUI init failed:", zoneError)
	end

	-- Fashion Boutique shop
	local fashionSuccess, fashionError = pcall(function()
		FashionUI:Init()
	end)
	if not fashionSuccess then
		warn("FashionUI init failed:", fashionError)
	end

	-- Listen for Fashion open event from server (ProximityPrompt at the boutique)
	local openFashionEvent = ReplicatedStorage:WaitForChild("OpenFashionUI", 10)
	if openFashionEvent then
		openFashionEvent.OnClientEvent:Connect(function(ownedItems, currency)
			if FashionUI and FashionUI.Open then
				FashionUI:Open(ownedItems, currency)
			end
		end)
	end

	-- Pet Corner adoption UI (listens for OpenPetUI internally)
	local petSuccess, petError = pcall(function()
		PetUI:Init()
	end)
	if not petSuccess then
		warn("PetUI init failed:", petError)
	end

	-- Ella's Bake Shop menu + baking minigame (listens for OpenBakeryUI)
	local bakerySuccess, bakeryError = pcall(function()
		BakeShopUI:Init()
	end)
	if not bakerySuccess then
		warn("BakeShopUI init failed:", bakeryError)
	end

	-- Talent Show audience voting panel (listens for TalentShowEvent)
	local talentSuccess, talentError = pcall(function()
		TalentShowUI:Init()
	end)
	if not talentSuccess then
		warn("TalentShowUI init failed:", talentError)
	end

	-- Algebra Academy Linear Lab (listens for OpenAlgebraUI internally)
	local algebraSuccess, algebraError = pcall(function()
		AlgebraUI:Init()
	end)
	if not algebraSuccess then
		warn("AlgebraUI init failed:", algebraError)
	end

	-- Listen for world-event notifications (e.g. Nutcracker Plaza tree)
	local notifyEvent = ReplicatedStorage:WaitForChild("NotifyPlayer", 10)
	if notifyEvent then
		notifyEvent.OnClientEvent:Connect(function(text)
			task.spawn(function()
				self:ShowNotification(text)
			end)
		end)
	end

	-- Update displays
	pcall(function()
		self:UpdateCurrencyDisplay()
		self:UpdateZoneDisplay()
	end)

	-- Finished loading
	self.IsLoading = false

	print("ClientController initialized. Welcome to Elland!")
end

-- Start the controller
ClientController:Init()

return ClientController
