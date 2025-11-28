--[[
	ClientController
	Main client-side script that initializes UI and client systems
	Handles communication with server and manages local state
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load shared constants
local Constants = require(ReplicatedStorage.Shared.Constants)

local ClientController = {}

-- Client-side state
ClientController.Currency = 0
ClientController.CurrentZone = "Hub"
ClientController.IsLoading = true

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

	print("Currency updated:", newAmount)

	if change > 0 then
		print("Earned", change, Constants.CURRENCY_NAME)
		-- TODO: Show currency gain animation/notification
	elseif change < 0 then
		print("Spent", math.abs(change), Constants.CURRENCY_NAME)
		-- TODO: Show currency spent animation/notification
	end

	-- Update UI
	-- TODO: Update currency display in UI
end

-- Request teleport to zone
function ClientController:TeleportToZone(zoneName)
	if not Constants.ZONES[zoneName] then
		warn("Invalid zone:", zoneName)
		return
	end

	print("Requesting teleport to", zoneName)
	TeleportRequest:FireServer(zoneName)

	self.CurrentZone = zoneName
end

-- Create basic HUD
local function createHUD()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EllandHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Currency Display
	local currencyFrame = Instance.new("Frame")
	currencyFrame.Name = "CurrencyFrame"
	currencyFrame.Size = UDim2.new(0, 200, 0, 50)
	currencyFrame.Position = UDim2.new(1, -220, 0, 20)
	currencyFrame.BackgroundColor3 = Constants.COLORS.BACKGROUND_SECONDARY
	currencyFrame.BorderSizePixel = 0
	currencyFrame.Parent = screenGui

	-- Round corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = currencyFrame

	-- Currency Label
	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.Name = "CurrencyLabel"
	currencyLabel.Size = UDim2.new(1, -20, 1, 0)
	currencyLabel.Position = UDim2.new(0, 10, 0, 0)
	currencyLabel.BackgroundTransparency = 1
	currencyLabel.Text = "0 " .. Constants.CURRENCY_NAME
	currencyLabel.TextColor3 = Constants.COLORS.TEXT_PRIMARY
	currencyLabel.TextSize = 20
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Left
	currencyLabel.Font = Enum.Font.GothamBold
	currencyLabel.Parent = currencyFrame

	-- Zone Display
	local zoneFrame = Instance.new("Frame")
	zoneFrame.Name = "ZoneFrame"
	zoneFrame.Size = UDim2.new(0, 250, 0, 50)
	zoneFrame.Position = UDim2.new(0, 20, 0, 20)
	zoneFrame.BackgroundColor3 = Constants.COLORS.BACKGROUND_SECONDARY
	zoneFrame.BorderSizePixel = 0
	zoneFrame.Parent = screenGui

	local zoneCorner = Instance.new("UICorner")
	zoneCorner.CornerRadius = UDim.new(0, 8)
	zoneCorner.Parent = zoneFrame

	local zoneLabel = Instance.new("TextLabel")
	zoneLabel.Name = "ZoneLabel"
	zoneLabel.Size = UDim2.new(1, -20, 1, 0)
	zoneLabel.Position = UDim2.new(0, 10, 0, 0)
	zoneLabel.BackgroundTransparency = 1
	zoneLabel.Text = "Central Hub"
	zoneLabel.TextColor3 = Constants.COLORS.TEXT_PRIMARY
	zoneLabel.TextSize = 20
	zoneLabel.TextXAlignment = Enum.TextXAlignment.Left
	zoneLabel.Font = Enum.Font.GothamBold
	zoneLabel.Parent = zoneFrame

	screenGui.Parent = playerGui

	print("HUD created")

	-- Store references for updates
	ClientController.CurrencyLabel = currencyLabel
	ClientController.ZoneLabel = zoneLabel
end

-- Update currency display
local function updateCurrencyDisplay()
	if ClientController.CurrencyLabel then
		ClientController.CurrencyLabel.Text = tostring(ClientController.Currency) .. " " .. Constants.CURRENCY_NAME
	end
end

-- Update zone display
local function updateZoneDisplay()
	if ClientController.ZoneLabel then
		local zoneName = Constants.ZONES[ClientController.CurrentZone]
		if zoneName then
			ClientController.ZoneLabel.Text = zoneName.Name
			ClientController.ZoneLabel.TextColor3 = zoneName.Color
		end
	end
end

-- Initialize the controller
function ClientController:Init()
	print("Initializing ClientController for", player.Name)

	-- Wait for character
	local character = player.Character or player.CharacterAdded:Wait()
	print("Character loaded")

	-- Initialize remote events
	initializeRemotes()

	-- Set up event listeners
	CurrencyChanged.OnClientEvent:Connect(function(newAmount, change)
		onCurrencyChanged(newAmount, change)
		updateCurrencyDisplay()
	end)

	-- Create HUD
	createHUD()

	-- Update displays
	updateCurrencyDisplay()
	updateZoneDisplay()

	-- Finished loading
	ClientController.IsLoading = false

	print("ClientController initialized")
	print("Welcome to Elland!")
end

-- Start the controller
ClientController:Init()

return ClientController
