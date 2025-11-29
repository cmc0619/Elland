--[[
	InteractionManager
	Adds interactive elements (ProximityPrompts) to world objects
	Connects interactions to game systems
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InteractionManager = {}

-- Create Wordle prompt at library
function InteractionManager:CreateWordlePrompt()
	local library = Workspace:FindFirstChild("WordleLibrary", true)
	if not library then
		warn("Wordle Library not found")
		return
	end

	-- Get position from Model (use GetPivot for Models, Position for Parts)
	local libraryPos
	if library:IsA("Model") then
		libraryPos = library:GetPivot().Position
	else
		libraryPos = library.Position
	end

	-- Create an invisible part for interaction
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "WordleInteraction"
	interactionPart.Size = Vector3.new(8, 8, 8)
	interactionPart.Position = libraryPos + Vector3.new(0, 4, -20)
	interactionPart.Anchored = true
	interactionPart.CanCollide = false
	interactionPart.Transparency = 0.5
	interactionPart.BrickColor = BrickColor.new("Bright purple")
	interactionPart.Material = Enum.Material.Neon
	interactionPart.Parent = Workspace

	-- Add glow effect
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 20
	light.Color = Color3.fromRGB(200, 150, 255)
	light.Parent = interactionPart

	-- Create ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Play Wordle"
	prompt.ObjectText = "Wordle Library"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 15
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = interactionPart

	-- Handle interaction
	prompt.Triggered:Connect(function(player)
		-- Fire remote to open Wordle UI
		local openWordle = ReplicatedStorage:FindFirstChild("OpenWordleUI")
		if openWordle then
			openWordle:FireClient(player)
			print(player.Name, "opened Wordle UI")
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

	-- Get position from Model or Part
	local boutiquePos
	if boutique:IsA("Model") then
		boutiquePos = boutique:GetPivot().Position
	else
		boutiquePos = boutique.Position
	end

	local interactionPart = Instance.new("Part")
	interactionPart.Name = "FashionInteraction"
	interactionPart.Size = Vector3.new(8, 8, 8)
	interactionPart.Position = boutiquePos + Vector3.new(0, 4, -20)
	interactionPart.Anchored = true
	interactionPart.CanCollide = false
	interactionPart.Transparency = 0.5
	interactionPart.BrickColor = BrickColor.new("Hot pink")
	interactionPart.Material = Enum.Material.Neon
	interactionPart.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 20
	light.Color = Color3.fromRGB(255, 150, 200)
	light.Parent = interactionPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Design Outfits"
	prompt.ObjectText = "Fashion Boutique"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 15
	prompt.Parent = interactionPart

	prompt.Triggered:Connect(function(player)
		-- TODO: Open Fashion UI when implemented
		print(player.Name, "wants to design outfits (coming soon!)")
	end)

	print("Fashion interaction created")
end

-- Create Building Area prompt
function InteractionManager:CreateBuildingPrompt()
	local platform = Workspace:FindFirstChild("BuildingPlatform", true)
	if not platform then
		warn("Building Platform not found")
		return
	end

	-- Get position from Model or Part
	local platformPos
	if platform:IsA("Model") then
		platformPos = platform:GetPivot().Position
	else
		platformPos = platform.Position
	end

	local interactionPart = Instance.new("Part")
	interactionPart.Name = "BuildingInteraction"
	interactionPart.Size = Vector3.new(8, 8, 8)
	interactionPart.Position = platformPos + Vector3.new(0, 4, 30)
	interactionPart.Anchored = true
	interactionPart.CanCollide = false
	interactionPart.Transparency = 0.5
	interactionPart.BrickColor = BrickColor.new("Bright yellow")
	interactionPart.Material = Enum.Material.Neon
	interactionPart.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 20
	light.Color = Color3.fromRGB(255, 200, 100)
	light.Parent = interactionPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Start Building"
	prompt.ObjectText = "Building Area"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 15
	prompt.Parent = interactionPart

	prompt.Triggered:Connect(function(player)
		-- TODO: Open Building tools when implemented
		print(player.Name, "wants to build (coming soon!)")
	end)

	print("Building interaction created")
end

-- Make swing interactive
function InteractionManager:MakeSwingInteractive()
	local swing = Workspace:FindFirstChild("WishingTree", true)
	if not swing then
		warn("Swing not found")
		return
	end

	local seat = swing:FindFirstChild("SwingSeat", true)
	if not seat then
		warn("Swing seat not found")
		return
	end

	-- The Seat object is already interactive!
	-- But let's add a prompt for clarity
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sit on Swing"
	prompt.ObjectText = "Ella's Swing"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = seat

	prompt.Triggered:Connect(function(player)
		-- The Seat will handle sitting automatically
		print(player.Name, "sat on the swing")
	end)

	print("Swing made interactive")
end

-- Initialize all interactions
function InteractionManager:Init()
	-- Create RemoteEvents upfront (so clients can connect to them)
	local openWordle = Instance.new("RemoteEvent")
	openWordle.Name = "OpenWordleUI"
	openWordle.Parent = ReplicatedStorage
	print("Created OpenWordleUI RemoteEvent")
	
	-- Wait a moment for world to build
	task.wait(2)

	self:CreateWordlePrompt()
	self:CreateFashionPrompt()
	self:CreateBuildingPrompt()
	self:MakeSwingInteractive()

	print("InteractionManager initialized")
end

return InteractionManager
