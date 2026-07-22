--[[
	FashionUI
	Fashion Boutique shop interface
	Lists purchasable items from Constants.FASHION.ITEMS with name, cost,
	Buy button and Owned state. Purchases go through PurchaseRequest and
	the result comes back via PurchaseResult; the currency display follows
	the shared CurrencyChanged event.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local FashionUI = {}
FashionUI.IsOpen = false
FashionUI.OwnedItems = {}
FashionUI.Currency = 0
FashionUI.ItemRows = {}

-- Remote Events (initialized in Init to avoid blocking module load)
local PurchaseRequest
local PurchaseResult
local CurrencyChanged

-- Create the shop UI
function FashionUI:CreateUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FashionUI"
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
	container.Size = UDim2.new(0, 520, 0, 460)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromRGB(255, 240, 248)
	container.BorderSizePixel = 0
	container.Parent = screenGui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 16)
	containerCorner.Parent = container

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 0, 50)
	title.Position = UDim2.new(0, 20, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "FASHION BOUTIQUE"
	title.TextSize = 26
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(180, 60, 120)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = container

	-- Currency display
	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.Name = "CurrencyLabel"
	currencyLabel.Size = UDim2.new(0, 180, 0, 30)
	currencyLabel.Position = UDim2.new(0, 20, 0, 55)
	currencyLabel.BackgroundTransparency = 1
	currencyLabel.Text = "0 " .. Constants.CURRENCY_NAME
	currencyLabel.TextSize = 16
	currencyLabel.Font = Enum.Font.GothamBold
	currencyLabel.TextColor3 = Color3.fromRGB(200, 150, 30)
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Left
	currencyLabel.Parent = container

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 50, 0, 50)
	closeButton.Position = UDim2.new(1, -60, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(240, 210, 225)
	closeButton.Text = "X"
	closeButton.TextSize = 24
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextColor3 = Color3.fromRGB(120, 50, 80)
	closeButton.Parent = container

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Item list
	local list = Instance.new("ScrollingFrame")
	list.Name = "ItemList"
	list.Size = UDim2.new(1, -40, 1, -140)
	list.Position = UDim2.new(0, 20, 0, 95)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.Parent = container

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	for order, item in ipairs(Constants.FASHION.ITEMS) do
		self:CreateItemRow(list, item, order)
	end

	-- Feedback label (purchase success/failure)
	local feedback = Instance.new("TextLabel")
	feedback.Name = "Feedback"
	feedback.Size = UDim2.new(1, -40, 0, 30)
	feedback.Position = UDim2.new(0, 20, 1, -40)
	feedback.BackgroundTransparency = 1
	feedback.Text = ""
	feedback.TextSize = 14
	feedback.Font = Enum.Font.GothamBold
	feedback.TextColor3 = Color3.fromRGB(80, 80, 80)
	feedback.TextXAlignment = Enum.TextXAlignment.Left
	feedback.Parent = container

	screenGui.Parent = playerGui
	self.ScreenGui = screenGui
	self.CurrencyLabel = currencyLabel
	self.FeedbackLabel = feedback
end

-- Create one shop row for an item
function FashionUI:CreateItemRow(parent, item, order)
	local row = Instance.new("Frame")
	row.Name = item.Id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -10, 0, 80)
	row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	row.BorderSizePixel = 0
	row.Parent = parent

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -150, 0, 30)
	nameLabel.Position = UDim2.new(0, 15, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = item.Name
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.fromRGB(60, 40, 60)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -150, 0, 30)
	descLabel.Position = UDim2.new(0, 15, 0, 40)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = item.Description
	descLabel.TextSize = 12
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextColor3 = Color3.fromRGB(140, 120, 140)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = row

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.Size = UDim2.new(0, 110, 0, 44)
	buyButton.Position = UDim2.new(1, -125, 0.5, 0)
	buyButton.AnchorPoint = Vector2.new(0, 0.5)
	buyButton.BackgroundColor3 = Color3.fromRGB(255, 150, 200)
	buyButton.BorderSizePixel = 0
	buyButton.Text = item.Cost .. " " .. Constants.CURRENCY_NAME
	buyButton.TextSize = 14
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.Parent = row

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 8)
	buyCorner.Parent = buyButton

	buyButton.MouseButton1Click:Connect(function()
		if self.OwnedItems[item.Id] then
			return
		end
		if PurchaseRequest then
			PurchaseRequest:FireServer(item.Id)
		end
	end)

	self.ItemRows[item.Id] = buyButton
end

-- Refresh Buy/Owned button states from the current inventory
function FashionUI:RefreshItemStates()
	for itemId, button in pairs(self.ItemRows) do
		if self.OwnedItems[itemId] then
			button.Text = "Owned"
			button.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
			button.AutoButtonColor = false
		else
			-- Restore the cost label for items not yet owned
			for _, item in ipairs(Constants.FASHION.ITEMS) do
				if item.Id == itemId then
					button.Text = item.Cost .. " " .. Constants.CURRENCY_NAME
					break
				end
			end
			button.BackgroundColor3 = Color3.fromRGB(255, 150, 200)
			button.AutoButtonColor = true
		end
	end
end

-- Update the currency label
function FashionUI:UpdateCurrencyDisplay()
	if self.CurrencyLabel then
		self.CurrencyLabel.Text = tostring(self.Currency) .. " " .. Constants.CURRENCY_NAME
	end
end

-- Show transient feedback text
function FashionUI:ShowFeedback(text, isError)
	if not self.FeedbackLabel then return end

	self.FeedbackLabel.Text = text
	self.FeedbackLabel.TextColor3 = isError and Constants.COLORS.ERROR or Constants.COLORS.SUCCESS

	-- Clear the message after a short moment
	task.delay(3, function()
		if self.FeedbackLabel and self.FeedbackLabel.Text == text then
			self.FeedbackLabel.Text = ""
		end
	end)
end

-- Open the shop with the player's current inventory and balance
function FashionUI:Open(ownedItems, currency)
	self.OwnedItems = {}
	if type(ownedItems) == "table" then
		for _, itemId in ipairs(ownedItems) do
			self.OwnedItems[itemId] = true
		end
	end
	if type(currency) == "number" then
		self.Currency = currency
	end

	self:RefreshItemStates()
	self:UpdateCurrencyDisplay()

	self.IsOpen = true
	self.ScreenGui.Enabled = true
end

-- Close the shop
function FashionUI:Close()
	self.IsOpen = false
	self.ScreenGui.Enabled = false
end

-- Initialize
function FashionUI:Init()
	PurchaseRequest = ReplicatedStorage:WaitForChild("PurchaseRequest", 10)
	PurchaseResult = ReplicatedStorage:WaitForChild("PurchaseResult", 10)
	CurrencyChanged = ReplicatedStorage:WaitForChild("CurrencyChanged", 10)

	if not PurchaseRequest or not PurchaseResult then
		warn("FashionUI: Purchase remotes not found - shop will not work")
	end

	self:CreateUI()

	-- Purchase outcome from the server
	if PurchaseResult then
		PurchaseResult.OnClientEvent:Connect(function(result)
			if result.success then
				self.OwnedItems[result.itemId] = true
				self:RefreshItemStates()
				self:ShowFeedback("Purchased! Enjoy your new item.", false)
			else
				self:ShowFeedback(result.error or "Purchase failed", true)
			end
		end)
	end

	-- Keep the shop currency display in sync with the shared economy
	if CurrencyChanged then
		CurrencyChanged.OnClientEvent:Connect(function(newAmount)
			self.Currency = newAmount
			self:UpdateCurrencyDisplay()
		end)
	end
end

return FashionUI
