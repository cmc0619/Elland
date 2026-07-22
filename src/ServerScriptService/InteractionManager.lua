--[[
	InteractionManager
	Adds interactive elements (ProximityPrompts) to world objects
	Connects interactions to game systems
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InteractionManager = {}
InteractionManager.PlayerDataService = nil
InteractionManager.CurrencyManager = nil

-- Helper: create a glowing interaction part with a ProximityPrompt
local function createInteractionPart(name, position, color, lightColor, actionText, objectText)
	local interactionPart = Instance.new("Part")
	interactionPart.Name = name
	interactionPart.Size = Vector3.new(8, 8, 8)
	interactionPart.Position = position
	interactionPart.Anchored = true
	interactionPart.CanCollide = false
	interactionPart.Transparency = 0.5
	interactionPart.BrickColor = color
	interactionPart.Material = Enum.Material.Neon
	interactionPart.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 20
	light.Color = lightColor
	light.Parent = interactionPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 15
	prompt.Parent = interactionPart

	return interactionPart, prompt
end

-- Helper: position of a Model (pivot) or a plain Part
local function getWorldPosition(instance)
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return instance.Position
end

-- Create Wordle prompt at library
function InteractionManager:CreateWordlePrompt()
	local library = Workspace:FindFirstChild("WordleLibrary", true)
	if not library then
		warn("Wordle Library not found")
		return
	end

	local _, prompt = createInteractionPart(
		"WordleInteraction",
		getWorldPosition(library) + Vector3.new(0, 4, -20),
		BrickColor.new("Bright purple"),
		Color3.fromRGB(200, 150, 255),
		"Play Wordle",
		"Wordle Library"
	)

	prompt.Triggered:Connect(function(player)
		-- Fire remote to open Wordle UI
		local openWordle = ReplicatedStorage:FindFirstChild("OpenWordleUI")
		if openWordle then
			openWordle:FireClient(player)
		else
			warn("OpenWordleUI RemoteEvent not found!")
		end
	end)

	print("Wordle interaction created")
end

-- Create Fashion Boutique prompt
function InteractionManager:CreateFashionPrompt()
	local boutique = Workspace:FindFirstChild("FashionBoutique", true)
	if not boutique then
		warn("Fashion Boutique not found")
		return
	end

	local _, prompt = createInteractionPart(
		"FashionInteraction",
		getWorldPosition(boutique) + Vector3.new(0, 4, -20),
		BrickColor.new("Hot pink"),
		Color3.fromRGB(255, 150, 200),
		"Open Shop",
		"Fashion Boutique"
	)

	prompt.Triggered:Connect(function(player)
		-- Open the fashion shop UI, sending the player's current inventory
		-- and balance so the UI can render Owned states immediately.
		local openFashion = ReplicatedStorage:FindFirstChild("OpenFashionUI")
		if not openFashion then
			warn("OpenFashionUI RemoteEvent not found!")
			return
		end

		local ownedItems = {}
		local currency = 0
		if self.CurrencyManager then
			ownedItems = self.CurrencyManager:GetOwnedItems(player)
			currency = self.CurrencyManager:GetCurrency(player)
		end

		openFashion:FireClient(player, ownedItems, currency)
	end)

	print("Fashion interaction created")
end

-- Make swing interactive
function InteractionManager:MakeSwingInteractive()
	local tree = Workspace:FindFirstChild("WishingTree", true)
	if not tree then
		warn("Wishing tree not found")
		return
	end

	local seat = tree:FindFirstChild("SwingSeat", true)
	if not seat then
		warn("Swing seat not found")
		return
	end

	-- The Seat object already lets players sit; add a prompt for clarity
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sit on Swing"
	prompt.ObjectText = "Ella's Swing"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = seat

	print("Swing made interactive")
end

-- Initialize all interactions
function InteractionManager:Init(playerDataService, currencyManager)
	self.PlayerDataService = playerDataService
	self.CurrencyManager = currencyManager

	-- Create RemoteEvents upfront (so clients can connect to them)
	local openWordle = Instance.new("RemoteEvent")
	openWordle.Name = "OpenWordleUI"
	openWordle.Parent = ReplicatedStorage

	local openFashion = Instance.new("RemoteEvent")
	openFashion.Name = "OpenFashionUI"
	openFashion.Parent = ReplicatedStorage

	-- Wait for WorldBuilder to finish deterministically instead of a fixed
	-- task.wait(2) race. BuildWorld() sets Workspace WorldBuilt = true.
	if not Workspace:GetAttribute("WorldBuilt") then
		Workspace:GetAttributeChangedSignal("WorldBuilt"):Wait()
	end

	self:CreateWordlePrompt()
	self:CreateFashionPrompt()
	self:MakeSwingInteractive()

	print("InteractionManager initialized")
end

return InteractionManager
