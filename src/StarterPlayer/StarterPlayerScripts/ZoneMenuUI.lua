--[[
	ZoneMenuUI
	Interactive map/menu for teleporting between zones
	Beautiful UI showing all locations in Elland
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local ZoneMenuUI = {}
ZoneMenuUI.IsOpen = false

-- Remote Event (initialized later to avoid blocking)
local TeleportRequest

-- Create the zone menu
function ZoneMenuUI:CreateUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ZoneMenuUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false

	-- Background
	local dimmer = Instance.new("Frame")
	dimmer.Name = "Dimmer"
	dimmer.Size = UDim2.new(1, 0, 1, 0)
	dimmer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimmer.BackgroundTransparency = 0.3
	dimmer.BorderSizePixel = 0
	dimmer.Parent = screenGui

	-- Main container
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 700, 0, 500)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
	container.BorderSizePixel = 0
	container.Parent = screenGui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 16)
	containerCorner.Parent = container

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 0, 60)
	title.Position = UDim2.new(0, 20, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "🗺️  EXPLORE ELLAND"
	title.TextSize = 28
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(50, 50, 50)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = container

	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -40, 0, 30)
	subtitle.Position = UDim2.new(0, 20, 0, 50)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Choose where you want to go"
	subtitle.TextSize = 14
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextColor3 = Color3.fromRGB(120, 120, 120)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = container

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 50, 0, 50)
	closeButton.Position = UDim2.new(1, -60, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
	closeButton.Text = "✕"
	closeButton.TextSize = 24
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextColor3 = Color3.fromRGB(50, 50, 50)
	closeButton.Parent = container

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Zones grid
	local zonesFrame = Instance.new("ScrollingFrame")
	zonesFrame.Size = UDim2.new(1, -40, 1, -100)
	zonesFrame.Position = UDim2.new(0, 20, 0, 80)
	zonesFrame.BackgroundTransparency = 1
	zonesFrame.BorderSizePixel = 0
	zonesFrame.ScrollBarThickness = 6
	zonesFrame.Parent = container

	local listLayout = Instance.new("UIGridLayout")
	listLayout.CellSize = UDim2.new(0, 200, 0, 120)
	listLayout.CellPadding = UDim2.new(0, 15, 0, 15)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = zonesFrame

	-- Create zone buttons
	local zoneOrder = {"Hub", "EllasLookout", "EllasHouse", "WordleLibrary", "FashionBoutique", "BuildingArea"}

	for order, zoneName in ipairs(zoneOrder) do
		local zoneData = Constants.ZONES[zoneName]
		if zoneData then
			self:CreateZoneButton(zonesFrame, zoneName, zoneData, order)
		end
	end

	screenGui.Parent = playerGui
	self.ScreenGui = screenGui

	print("Zone Menu UI created")
end

-- Create a zone button
function ZoneMenuUI:CreateZoneButton(parent, zoneName, zoneData, order)
	local button = Instance.new("TextButton")
	button.Name = zoneName
	button.LayoutOrder = order
	button.BackgroundColor3 = zoneData.Color
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button

	-- Gradient overlay
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0)
	}
	gradient.Rotation = 90
	gradient.Parent = button

	-- Zone name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -20, 0, 30)
	nameLabel.Position = UDim2.new(0, 10, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = zoneData.Name
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Parent = button

	-- Zone description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -20, 0, 60)
	descLabel.Position = UDim2.new(0, 10, 0, 45)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = zoneData.Description
	descLabel.TextSize = 12
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.TextStrokeTransparency = 0.7
	descLabel.Parent = button

	-- Hover effect
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2), {
			Size = UDim2.new(0, 210, 0, 130)
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2), {
			Size = UDim2.new(0, 200, 0, 120)
		}):Play()
	end)

	-- Click to teleport
	button.MouseButton1Click:Connect(function()
		self:TeleportToZone(zoneName, zoneData.Name)
	end)
end

-- Teleport to zone
function ZoneMenuUI:TeleportToZone(zoneName, displayName)
	print("Teleporting to", displayName)
	TeleportRequest:FireServer(zoneName)
	self:Close()

	-- Show notification
	self:ShowNotification("Traveling to " .. displayName .. "...")
end

-- Show notification
function ZoneMenuUI:ShowNotification(text)
	local notification = Instance.new("Frame")
	notification.Size = UDim2.new(0, 300, 0, 60)
	notification.Position = UDim2.new(0.5, 0, 0.1, 0)
	notification.AnchorPoint = Vector2.new(0.5, 0)
	notification.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	notification.BorderSizePixel = 0
	notification.Parent = playerGui:FindFirstChild("MainHUD") or playerGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = notification

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = notification

	-- Fade in
	notification.BackgroundTransparency = 1
	label.TextTransparency = 1

	TweenService:Create(notification, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
	TweenService:Create(label, TweenInfo.new(0.3), {TextTransparency = 0}):Play()

	-- Fade out and destroy
	task.wait(2)
	TweenService:Create(notification, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
	TweenService:Create(label, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	task.wait(0.3)
	notification:Destroy()
end

-- Open menu
function ZoneMenuUI:Open()
	if self.IsOpen then return end
	self.IsOpen = true
	self.ScreenGui.Enabled = true
end

-- Close menu
function ZoneMenuUI:Close()
	self.IsOpen = false
	self.ScreenGui.Enabled = false
end

-- Toggle menu
function ZoneMenuUI:Toggle()
	if self.IsOpen then
		self:Close()
	else
		self:Open()
	end
end

-- Initialize
function ZoneMenuUI:Init()
	-- Initialize remote event now (lazy loading to avoid blocking module load)
	TeleportRequest = ReplicatedStorage:WaitForChild("TeleportRequest", 10)
	
	if not TeleportRequest then
		warn("ZoneMenuUI: Could not find TeleportRequest remote event")
	end
	
	self:CreateUI()

	-- Listen for M key to open menu
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.M then
			self:Toggle()
		end
	end)

	print("Zone Menu UI initialized")
end

return ZoneMenuUI
