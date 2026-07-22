--[[
	BakeShopUI
	Ella's Bake Shop menu + baking minigame

	The menu lists family recipes from Constants.BAKERY.ITEMS with name,
	cost and a Bake button (baked recipes show "In Book"). Choosing a
	recipe fires BakeStartRequest; on BakeStartResult a minigame panel
	opens: a progress bar fills over the bake duration while big timed
	buttons (Stir! / Add sprinkles! / Frost!) appear one per third of the
	bar. Clicking each button inside its window counts a perfect click.
	When the bar fills, BakeCompleteRequest(itemId, perfectClicks) goes to
	the server, which validates timing, charges, grants, and replies via
	BakeCompleteResult. The server opens the menu via OpenBakeryUI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local BakeShopUI = {}
BakeShopUI.IsOpen = false
BakeShopUI.BakedItems = {}
BakeShopUI.Currency = 0
BakeShopUI.ItemRows = {}
BakeShopUI.IsBaking = false

-- Remote Events (initialized in Init to avoid blocking module load)
local OpenBakeryUI
local BakeStartRequest
local BakeStartResult
local BakeCompleteRequest
local BakeCompleteResult
local CurrencyChanged

-- Create the menu UI
function BakeShopUI:CreateUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BakeShopUI"
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
	container.BackgroundColor3 = Color3.fromRGB(255, 244, 232)
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
	title.Text = "ELLA'S BAKE SHOP"
	title.TextSize = 26
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(190, 90, 100)
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
	closeButton.BackgroundColor3 = Color3.fromRGB(245, 220, 210)
	closeButton.Text = "X"
	closeButton.TextSize = 24
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextColor3 = Color3.fromRGB(140, 70, 70)
	closeButton.Parent = container

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		if not self.IsBaking then
			self:Close()
		end
	end)

	-- Recipe list
	local list = Instance.new("ScrollingFrame")
	list.Name = "RecipeList"
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

	for order, item in ipairs(Constants.BAKERY.ITEMS) do
		self:CreateRecipeRow(list, item, order)
	end

	-- Feedback label
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

-- Create one menu row for a recipe
function BakeShopUI:CreateRecipeRow(parent, item, order)
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
	nameLabel.TextColor3 = Color3.fromRGB(90, 50, 40)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -150, 0, 30)
	descLabel.Position = UDim2.new(0, 15, 0, 40)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = item.Description
	descLabel.TextSize = 12
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextColor3 = Color3.fromRGB(160, 125, 110)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = row

	local bakeButton = Instance.new("TextButton")
	bakeButton.Name = "BakeButton"
	bakeButton.Size = UDim2.new(0, 110, 0, 44)
	bakeButton.Position = UDim2.new(1, -125, 0.5, 0)
	bakeButton.AnchorPoint = Vector2.new(0, 0.5)
	bakeButton.BackgroundColor3 = Color3.fromRGB(240, 140, 110)
	bakeButton.BorderSizePixel = 0
	bakeButton.Text = item.Cost .. " " .. Constants.CURRENCY_NAME
	bakeButton.TextSize = 14
	bakeButton.Font = Enum.Font.GothamBold
	bakeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	bakeButton.Parent = row

	local bakeCorner = Instance.new("UICorner")
	bakeCorner.CornerRadius = UDim.new(0, 8)
	bakeCorner.Parent = bakeButton

	bakeButton.MouseButton1Click:Connect(function()
		if self.BakedItems[item.Id] or self.IsBaking then
			return
		end
		if BakeStartRequest then
			BakeStartRequest:FireServer(item.Id)
		end
	end)

	self.ItemRows[item.Id] = bakeButton
end

-- Refresh Bake/In Book button states
function BakeShopUI:RefreshItemStates()
	for itemId, button in pairs(self.ItemRows) do
		if self.BakedItems[itemId] then
			button.Text = "In Book"
			button.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
			button.AutoButtonColor = false
		else
			for _, item in ipairs(Constants.BAKERY.ITEMS) do
				if item.Id == itemId then
					button.Text = item.Cost .. " " .. Constants.CURRENCY_NAME
					break
				end
			end
			button.BackgroundColor3 = Color3.fromRGB(240, 140, 110)
			button.AutoButtonColor = true
		end
	end
end

-- Update the currency label
function BakeShopUI:UpdateCurrencyDisplay()
	if self.CurrencyLabel then
		self.CurrencyLabel.Text = tostring(self.Currency) .. " " .. Constants.CURRENCY_NAME
	end
end

-- Show transient feedback text
function BakeShopUI:ShowFeedback(text, isError)
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

-- The baking minigame: progress bar + one timed button per step.
-- Each step's button lives for one third of the total duration; clicking
-- it in its window counts a perfect click.
function BakeShopUI:RunMinigame(itemId, duration, steps)
	self.IsBaking = true

	local panel = Instance.new("Frame")
	panel.Name = "BakingPanel"
	panel.Size = UDim2.new(0, 380, 0, 220)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
	panel.BorderSizePixel = 0
	panel.Parent = self.ScreenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 14)
	panelCorner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "Baking..."
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(190, 90, 100)
	title.Parent = panel

	-- Progress bar
	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.new(1, -40, 0, 24)
	barBack.Position = UDim2.new(0, 20, 0, 60)
	barBack.BackgroundColor3 = Color3.fromRGB(235, 220, 205)
	barBack.BorderSizePixel = 0
	barBack.Parent = panel

	local barBackCorner = Instance.new("UICorner")
	barBackCorner.CornerRadius = UDim.new(0, 8)
	barBackCorner.Parent = barBack

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(240, 140, 110)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(0, 8)
	barFillCorner.Parent = barFill

	-- Timed step button
	local stepButton = Instance.new("TextButton")
	stepButton.Size = UDim2.new(0, 220, 0, 60)
	stepButton.Position = UDim2.new(0.5, 0, 0, 120)
	stepButton.AnchorPoint = Vector2.new(0.5, 0)
	stepButton.BackgroundColor3 = Color3.fromRGB(255, 180, 90)
	stepButton.BorderSizePixel = 0
	stepButton.Text = "Get ready..."
	stepButton.TextSize = 22
	stepButton.Font = Enum.Font.GothamBold
	stepButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	stepButton.AutoButtonColor = false
	stepButton.Parent = panel

	local stepCorner = Instance.new("UICorner")
	stepCorner.CornerRadius = UDim.new(0, 12)
	stepCorner.Parent = stepButton

	local stepCount = #steps
	local stepWindow = duration / stepCount
	local currentStep = 0 -- Step index whose window is open (0 = none yet)
	local clickedStep = 0 -- Steps already clicked
	local perfectClicks = 0

	stepButton.MouseButton1Click:Connect(function()
		if currentStep >= 1 and currentStep > clickedStep then
			clickedStep = currentStep
			perfectClicks = perfectClicks + 1
			stepButton.Text = "Nice!"
			stepButton.BackgroundColor3 = Color3.fromRGB(140, 200, 140)
		end
	end)

	-- Drive the bar and step windows
	local startTime = os.clock()
	while true do
		local elapsed = os.clock() - startTime
		local progress = math.clamp(elapsed / duration, 0, 1)
		barFill.Size = UDim2.new(progress, 0, 1, 0)

		local stepIndex = math.min(stepCount, math.floor(elapsed / stepWindow) + 1)
		if elapsed < duration then
			if stepIndex ~= currentStep then
				currentStep = stepIndex
				if clickedStep < currentStep then
					stepButton.Text = steps[currentStep]
					stepButton.BackgroundColor3 = Color3.fromRGB(255, 180, 90)
				end
			end
			task.wait(0.05)
		else
			break
		end
	end

	stepButton.Text = "Done!"
	stepButton.BackgroundColor3 = Color3.fromRGB(140, 200, 140)
	task.wait(0.4)
	panel:Destroy()

	self.IsBaking = false

	if BakeCompleteRequest then
		BakeCompleteRequest:FireServer(itemId, perfectClicks)
	end
end

-- Open the menu with the player's baked recipes and balance
function BakeShopUI:Open(bakedItems, currency)
	self.BakedItems = {}
	if type(bakedItems) == "table" then
		for _, itemId in ipairs(bakedItems) do
			self.BakedItems[itemId] = true
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

-- Close the menu
function BakeShopUI:Close()
	self.IsOpen = false
	self.ScreenGui.Enabled = false
end

-- Initialize
function BakeShopUI:Init()
	OpenBakeryUI = ReplicatedStorage:WaitForChild("OpenBakeryUI", 10)
	BakeStartRequest = ReplicatedStorage:WaitForChild("BakeStartRequest", 10)
	BakeStartResult = ReplicatedStorage:WaitForChild("BakeStartResult", 10)
	BakeCompleteRequest = ReplicatedStorage:WaitForChild("BakeCompleteRequest", 10)
	BakeCompleteResult = ReplicatedStorage:WaitForChild("BakeCompleteResult", 10)
	CurrencyChanged = ReplicatedStorage:WaitForChild("CurrencyChanged", 10)

	if not BakeStartRequest or not BakeCompleteRequest then
		warn("BakeShopUI: Bakery remotes not found - baking will not work")
	end

	self:CreateUI()

	-- Server opens the menu (ProximityPrompt at the shop)
	if OpenBakeryUI then
		OpenBakeryUI.OnClientEvent:Connect(function(bakedItems, currency)
			self:Open(bakedItems, currency)
		end)
	end

	-- Bake accepted by the server: run the minigame
	if BakeStartResult then
		BakeStartResult.OnClientEvent:Connect(function(result)
			if result.success then
				task.spawn(function()
					self:RunMinigame(result.itemId, result.duration, result.steps)
				end)
			else
				self:ShowFeedback(result.error or "Could not start baking", true)
			end
		end)
	end

	-- Bake outcome from the server
	if BakeCompleteResult then
		BakeCompleteResult.OnClientEvent:Connect(function(result)
			if result.success then
				self.BakedItems[result.itemId] = true
				self:RefreshItemStates()
				self:ShowFeedback("Fresh out of the oven!", false)
			else
				self:ShowFeedback(result.error or "Bake failed", true)
			end
		end)
	end

	-- Keep the currency display in sync with the shared economy
	if CurrencyChanged then
		CurrencyChanged.OnClientEvent:Connect(function(newAmount)
			self.Currency = newAmount
			self:UpdateCurrencyDisplay()
		end)
	end
end

return BakeShopUI
