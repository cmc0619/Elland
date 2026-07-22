--[[
	PetUI
	Pet Corner adoption interface
	Lists adoptable pets from Constants.PETS.LIST with name, cost and an
	Adopt button; owned pets show Follow / Following instead. A Dismiss
	button calls the active pet home. Purchases go through
	PetPurchaseRequest and equip changes through PetEquipRequest; results
	come back via PetPurchaseResult / PetEquipResult. The server opens the
	UI via OpenPetUI with the player's pets, active pet and balance.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local PetUI = {}
PetUI.IsOpen = false
PetUI.OwnedPets = {}
PetUI.ActivePet = nil
PetUI.Currency = 0
PetUI.PetRows = {}

-- Remote Events (initialized in Init to avoid blocking module load)
local OpenPetUI
local PetPurchaseRequest
local PetPurchaseResult
local PetEquipRequest
local PetEquipResult
local CurrencyChanged

-- Create the adoption UI
function PetUI:CreateUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PetUI"
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
	container.BackgroundColor3 = Color3.fromRGB(255, 248, 235)
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
	title.Text = "PET CORNER"
	title.TextSize = 26
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(170, 120, 50)
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
	closeButton.BackgroundColor3 = Color3.fromRGB(240, 225, 200)
	closeButton.Text = "X"
	closeButton.TextSize = 24
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextColor3 = Color3.fromRGB(120, 90, 50)
	closeButton.Parent = container

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Pet list
	local list = Instance.new("ScrollingFrame")
	list.Name = "PetList"
	list.Size = UDim2.new(1, -40, 1, -190)
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

	for order, pet in ipairs(Constants.PETS.LIST) do
		self:CreatePetRow(list, pet, order)
	end

	-- Dismiss button (calls the active pet home)
	local dismissButton = Instance.new("TextButton")
	dismissButton.Name = "DismissButton"
	dismissButton.Size = UDim2.new(0, 200, 0, 40)
	dismissButton.Position = UDim2.new(1, -220, 1, -45)
	dismissButton.BackgroundColor3 = Color3.fromRGB(220, 200, 180)
	dismissButton.BorderSizePixel = 0
	dismissButton.Text = "Dismiss Pet"
	dismissButton.TextSize = 14
	dismissButton.Font = Enum.Font.GothamBold
	dismissButton.TextColor3 = Color3.fromRGB(110, 85, 55)
	dismissButton.Parent = container

	local dismissCorner = Instance.new("UICorner")
	dismissCorner.CornerRadius = UDim.new(0, 8)
	dismissCorner.Parent = dismissButton

	dismissButton.MouseButton1Click:Connect(function()
		if PetEquipRequest then
			PetEquipRequest:FireServer() -- No petId = dismiss
		end
	end)

	-- Feedback label (adoption success/failure)
	local feedback = Instance.new("TextLabel")
	feedback.Name = "Feedback"
	feedback.Size = UDim2.new(1, -240, 0, 30)
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

-- Create one adoption row for a pet
function PetUI:CreatePetRow(parent, pet, order)
	local row = Instance.new("Frame")
	row.Name = pet.Id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -10, 0, 80)
	row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	row.BorderSizePixel = 0
	row.Parent = parent

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	-- Little color swatch so each pet row looks like the pet
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.new(0, 40, 0, 40)
	swatch.Position = UDim2.new(0, 12, 0.5, 0)
	swatch.AnchorPoint = Vector2.new(0, 0.5)
	swatch.BackgroundColor3 = pet.BodyColor
	swatch.BorderSizePixel = 0
	swatch.Parent = row

	local swatchCorner = Instance.new("UICorner")
	swatchCorner.CornerRadius = UDim.new(1, 0)
	swatchCorner.Parent = swatch

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -190, 0, 30)
	nameLabel.Position = UDim2.new(0, 62, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = pet.Name
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.fromRGB(70, 55, 35)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -190, 0, 30)
	descLabel.Position = UDim2.new(0, 62, 0, 40)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = pet.Description
	descLabel.TextSize = 12
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextColor3 = Color3.fromRGB(150, 130, 105)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = row

	local actionButton = Instance.new("TextButton")
	actionButton.Name = "ActionButton"
	actionButton.Size = UDim2.new(0, 110, 0, 44)
	actionButton.Position = UDim2.new(1, -125, 0.5, 0)
	actionButton.AnchorPoint = Vector2.new(0, 0.5)
	actionButton.BackgroundColor3 = Color3.fromRGB(255, 190, 90)
	actionButton.BorderSizePixel = 0
	actionButton.Text = pet.Cost .. " " .. Constants.CURRENCY_NAME
	actionButton.TextSize = 14
	actionButton.Font = Enum.Font.GothamBold
	actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionButton.Parent = row

	local actionCorner = Instance.new("UICorner")
	actionCorner.CornerRadius = UDim.new(0, 8)
	actionCorner.Parent = actionButton

	actionButton.MouseButton1Click:Connect(function()
		if self.OwnedPets[pet.Id] then
			if self.ActivePet ~= pet.Id and PetEquipRequest then
				PetEquipRequest:FireServer(pet.Id)
			end
		else
			if PetPurchaseRequest then
				PetPurchaseRequest:FireServer(pet.Id)
			end
		end
	end)

	self.PetRows[pet.Id] = actionButton
end

-- Refresh Adopt/Follow/Following button states
function PetUI:RefreshPetStates()
	for petId, button in pairs(self.PetRows) do
		if self.OwnedPets[petId] then
			if self.ActivePet == petId then
				button.Text = "Following"
				button.BackgroundColor3 = Color3.fromRGB(140, 200, 140)
				button.AutoButtonColor = false
			else
				button.Text = "Follow"
				button.BackgroundColor3 = Color3.fromRGB(150, 180, 230)
				button.AutoButtonColor = true
			end
		else
			for _, pet in ipairs(Constants.PETS.LIST) do
				if pet.Id == petId then
					button.Text = pet.Cost .. " " .. Constants.CURRENCY_NAME
					break
				end
			end
			button.BackgroundColor3 = Color3.fromRGB(255, 190, 90)
			button.AutoButtonColor = true
		end
	end
end

-- Update the currency label
function PetUI:UpdateCurrencyDisplay()
	if self.CurrencyLabel then
		self.CurrencyLabel.Text = tostring(self.Currency) .. " " .. Constants.CURRENCY_NAME
	end
end

-- Show transient feedback text
function PetUI:ShowFeedback(text, isError)
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

-- Open the adoption UI with the player's pets, active pet and balance
function PetUI:Open(pets, activePet, currency)
	self.OwnedPets = {}
	if type(pets) == "table" then
		for _, petId in ipairs(pets) do
			self.OwnedPets[petId] = true
		end
	end
	self.ActivePet = type(activePet) == "string" and activePet or nil
	if type(currency) == "number" then
		self.Currency = currency
	end

	self:RefreshPetStates()
	self:UpdateCurrencyDisplay()

	self.IsOpen = true
	self.ScreenGui.Enabled = true
end

-- Close the UI
function PetUI:Close()
	self.IsOpen = false
	self.ScreenGui.Enabled = false
end

-- Initialize
function PetUI:Init()
	OpenPetUI = ReplicatedStorage:WaitForChild("OpenPetUI", 10)
	PetPurchaseRequest = ReplicatedStorage:WaitForChild("PetPurchaseRequest", 10)
	PetPurchaseResult = ReplicatedStorage:WaitForChild("PetPurchaseResult", 10)
	PetEquipRequest = ReplicatedStorage:WaitForChild("PetEquipRequest", 10)
	PetEquipResult = ReplicatedStorage:WaitForChild("PetEquipResult", 10)
	CurrencyChanged = ReplicatedStorage:WaitForChild("CurrencyChanged", 10)

	if not PetPurchaseRequest or not PetEquipRequest then
		warn("PetUI: Pet remotes not found - adoption will not work")
	end

	self:CreateUI()

	-- Server opens the UI (ProximityPrompt at the Pet Corner)
	if OpenPetUI then
		OpenPetUI.OnClientEvent:Connect(function(pets, activePet, currency)
			self:Open(pets, activePet, currency)
		end)
	end

	-- Adoption outcome from the server
	if PetPurchaseResult then
		PetPurchaseResult.OnClientEvent:Connect(function(result)
			if result.success then
				self.OwnedPets[result.petId] = true
				self.ActivePet = result.activePet
				self:RefreshPetStates()
				self:ShowFeedback("Adopted! Your new friend is following you.", false)
			else
				self:ShowFeedback(result.error or "Adoption failed", true)
			end
		end)
	end

	-- Follow/dismiss outcome from the server
	if PetEquipResult then
		PetEquipResult.OnClientEvent:Connect(function(result)
			if result.success then
				self.ActivePet = result.activePet
				self:RefreshPetStates()
			else
				self:ShowFeedback(result.error or "Could not switch pet", true)
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

return PetUI
