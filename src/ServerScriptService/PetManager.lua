--[[
	PetManager
	The Pet Corner: a small fenced adoption pen between the Hub and the
	soccer pitch. The "Pet Adoption" ProximityPrompt opens PetUI on the
	client; adopting is server-authoritative: the price is looked up in
	Constants.PETS.LIST (never trusted from the client), funds are checked
	via CurrencyManager, and ownership is saved in player data
	(Pets / ActivePet, persisted by PlayerDataService).

	Follow behavior: the server spawns an anchored, non-collidable pet
	model in Workspace/Pets with an OwnerUserId attribute and positions it
	once. Every client runs a smooth Heartbeat follow/bob loop
	(PetFollow.client.lua) driven by the owner's replicated character, so
	the pet trails its owner with zero per-frame network traffic. Only one
	active pet per player; the pet is cleaned up when the owner leaves.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local PetManager = {}
PetManager.PlayerDataService = nil
PetManager.CurrencyManager = nil

-- RemoteEvents (created at module load so clients can WaitForChild them)
local OpenPetUI = Instance.new("RemoteEvent")
OpenPetUI.Name = "OpenPetUI"
OpenPetUI.Parent = ReplicatedStorage

local PetPurchaseRequest = Instance.new("RemoteEvent")
PetPurchaseRequest.Name = "PetPurchaseRequest"
PetPurchaseRequest.Parent = ReplicatedStorage

local PetPurchaseResult = Instance.new("RemoteEvent")
PetPurchaseResult.Name = "PetPurchaseResult"
PetPurchaseResult.Parent = ReplicatedStorage

-- Equip = make an owned pet the active follower; no petId = dismiss
local PetEquipRequest = Instance.new("RemoteEvent")
PetEquipRequest.Name = "PetEquipRequest"
PetEquipRequest.Parent = ReplicatedStorage

local PetEquipResult = Instance.new("RemoteEvent")
PetEquipResult.Name = "PetEquipResult"
PetEquipResult.Parent = ReplicatedStorage

-- Shared one-line notification channel (ClientController shows the toast)
local NotifyPlayer = ReplicatedStorage:FindFirstChild("NotifyPlayer")
if not NotifyPlayer then
	NotifyPlayer = Instance.new("RemoteEvent")
	NotifyPlayer.Name = "NotifyPlayer"
	NotifyPlayer.Parent = ReplicatedStorage
end

local PETS = Constants.PETS
local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL

-- Server-side catalog built from Constants.PETS.LIST (single source of
-- truth). PetPurchaseRequest only trusts prices here.
local PET_CATALOG = {}
for _, pet in ipairs(PETS.LIST) do
	PET_CATALOG[pet.Id] = pet
end

local function createPart(parent, name, size, cframe, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Fenced pen + sign + adoption prompt
function PetManager:BuildCorner()
	local old = Workspace:FindFirstChild("PetCorner")
	if old then
		old:Destroy()
	end

	local corner = Instance.new("Folder")
	corner.Name = "PetCorner"
	corner.Parent = Workspace

	local center = PETS.POSITION
	local half = PETS.FENCE_HALF_SIZE

	-- Paw-print colored floor pad so the pen reads as its own little place
	createPart(
		corner, "PenFloor", Vector3.new(half * 2, 0.4, half * 2),
		CFrame.new(center.X, GROUND_LEVEL + 0.2, center.Z),
		Color3.fromRGB(255, 228, 196), Enum.Material.WoodPlanks
	)

	-- Corner posts
	for _, offset in ipairs({
		Vector3.new(-half, 0, -half),
		Vector3.new(half, 0, -half),
		Vector3.new(-half, 0, half),
		Vector3.new(half, 0, half),
	}) do
		createPart(
			corner, "FencePost", Vector3.new(1, 4, 1),
			CFrame.new(center.X + offset.X, GROUND_LEVEL + 2, center.Z + offset.Z),
			Color3.fromRGB(150, 105, 60), Enum.Material.Wood
		)
	end

	-- Two rail heights per side; leave a gap in the front (-Z) for the gate
	for _, railY in ipairs({ 1.5, 3 }) do
		createPart(
			corner, "FenceRail", Vector3.new(half * 2, 0.4, 0.4),
			CFrame.new(center.X, GROUND_LEVEL + railY, center.Z + half),
			Color3.fromRGB(180, 130, 80), Enum.Material.Wood
		)
		for _, xSign in ipairs({ -1, 1 }) do
			createPart(
				corner, "FenceRail", Vector3.new(half - 3, 0.4, 0.4),
				CFrame.new(center.X + xSign * (half + 3) / 1.15, GROUND_LEVEL + railY, center.Z - half),
				Color3.fromRGB(180, 130, 80), Enum.Material.Wood
			)
			createPart(
				corner, "FenceRail", Vector3.new(0.4, 0.4, half * 2),
				CFrame.new(center.X + xSign * half, GROUND_LEVEL + railY, center.Z),
				Color3.fromRGB(180, 130, 80), Enum.Material.Wood
			)
		end
	end

	-- Sign above the gate
	local sign = createPart(
		corner, "Sign", Vector3.new(10, 3, 0.5),
		CFrame.new(center.X, GROUND_LEVEL + 6.5, center.Z - half),
		Color3.fromRGB(255, 250, 240)
	)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "PET CORNER"
	signLabel.TextColor3 = Color3.fromRGB(150, 105, 60)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Parent = signGui

	-- Adoption prompt (glowing paw-yellow ball inside the pen)
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "PetAdoptionInteraction"
	interactionPart.Size = Vector3.new(6, 6, 6)
	interactionPart.Shape = Enum.PartType.Ball
	interactionPart.Position = Vector3.new(center.X, GROUND_LEVEL + 4, center.Z - half + 3)
	interactionPart.Anchored = true
	interactionPart.CanCollide = false
	interactionPart.Transparency = 0.5
	interactionPart.Color = Color3.fromRGB(255, 200, 80)
	interactionPart.Material = Enum.Material.Neon
	interactionPart.Parent = corner

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 16
	light.Color = Color3.fromRGB(255, 210, 120)
	light.Parent = interactionPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Adopt a Pet"
	prompt.ObjectText = "Pet Corner"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 15
	prompt.Parent = interactionPart

	prompt.Triggered:Connect(function(player)
		local data = self.PlayerDataService and self.PlayerDataService:GetData(player)
		if not data then
			return
		end
		local currency = self.CurrencyManager and self.CurrencyManager:GetCurrency(player) or 0
		OpenPetUI:FireClient(player, data.Pets or {}, data.ActivePet, currency)
	end)

	print("PetManager: Pet Corner built")
end

-- Blocky-cute pet model: body ball + head + eyes + tail + per-pet accents.
-- All parts anchored and non-collidable; the client follow loop pivots it.
local function buildPetModel(petDef)
	local model = Instance.new("Model")
	model.Name = petDef.Id

	local function part(name, shape, size, offset, color)
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = CFrame.new(offset)
		p.Anchored = true
		p.CanCollide = false
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end

	-- Model faces -Z (the head/eyes sit on -Z)
	part("Body", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 0, 0), petDef.BodyColor)
	part("Head", Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 0.9, -0.55), petDef.BodyColor)
	for _, xSign in ipairs({ -1, 1 }) do
		part("Eye", Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22),
			Vector3.new(xSign * 0.3, 1.05, -1.12), Color3.fromRGB(30, 30, 30))
	end
	part("Tail", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 0.25, 0.85), petDef.AccentColor)

	if petDef.Id == "Puppy" then
		-- Floppy ears hanging off the sides of the head
		for _, xSign in ipairs({ -1, 1 }) do
			part("Ear", nil, Vector3.new(0.35, 0.9, 0.5),
				Vector3.new(xSign * 0.7, 0.85, -0.55), petDef.AccentColor)
		end
	elseif petDef.Id == "Kitten" then
		-- Pointy wedge ears on top
		for _, xSign in ipairs({ -1, 1 }) do
			local ear = Instance.new("WedgePart")
			ear.Name = "Ear"
			ear.Size = Vector3.new(0.3, 0.5, 0.4)
			ear.CFrame = CFrame.new(xSign * 0.35, 1.7, -0.55)
			ear.Anchored = true
			ear.CanCollide = false
			ear.Color = petDef.AccentColor
			ear.Material = Enum.Material.SmoothPlastic
			ear.Parent = model
		end
	elseif petDef.Id == "Bunny" then
		-- Tall upright ears
		for _, xSign in ipairs({ -1, 1 }) do
			part("Ear", nil, Vector3.new(0.3, 1.2, 0.3),
				Vector3.new(xSign * 0.3, 2.05, -0.55), petDef.BodyColor)
		end
	elseif petDef.Id == "Axolotl" then
		-- Frilly gills fanning out from the head
		for _, xSign in ipairs({ -1, 1 }) do
			for i = 1, 3 do
				part("Gill", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35),
					Vector3.new(xSign * (0.75 + i * 0.18), 0.75 + i * 0.28, -0.55), petDef.AccentColor)
			end
		end
	end

	model.PrimaryPart = model:FindFirstChild("Body")
	return model
end

-- Spawn (or respawn) the player's active pet into Workspace/Pets
function PetManager:SpawnPet(player)
	self:ClearPet(player)

	local data = self.PlayerDataService and self.PlayerDataService:GetData(player)
	local activePet = data and data.ActivePet
	local petDef = activePet and PET_CATALOG[activePet]
	if not petDef then
		return
	end

	local folder = Workspace:FindFirstChild("Pets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Pets"
		folder.Parent = Workspace
	end

	local model = buildPetModel(petDef)
	model:SetAttribute("OwnerUserId", player.UserId)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		model:PivotTo(rootPart.CFrame * CFrame.new(PETS.FOLLOW_OFFSET + Vector3.new(0, PETS.FOLLOW_HEIGHT, 0)))
	else
		model:PivotTo(CFrame.new(PETS.POSITION + Vector3.new(0, 3, 0)))
	end

	model.Name = player.Name .. "_" .. petDef.Id
	model.Parent = folder
end

-- Remove the player's pet model (dismiss or cleanup on leave)
function PetManager:ClearPet(player)
	local folder = Workspace:FindFirstChild("Pets")
	if not folder then
		return
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("OwnerUserId") == player.UserId then
			model:Destroy()
		end
	end
end

function PetManager:GetOwnedPets(player)
	local data = self.PlayerDataService and self.PlayerDataService:GetData(player)
	if data and data.Pets then
		return data.Pets
	end
	return {}
end

function PetManager:PlayerOwnsPet(player, petId)
	return table.find(self:GetOwnedPets(player), petId) ~= nil
end

-- Adoption: client sends a petId only; the server validates everything
function PetManager:HandlePurchase(player, petId)
	local function fail(message)
		PetPurchaseResult:FireClient(player, {
			success = false,
			petId = petId,
			error = message,
		})
		return false
	end

	if type(petId) ~= "string" then
		return fail("Invalid pet")
	end

	local petDef = PET_CATALOG[petId]
	if not petDef then
		warn("PetManager: Unknown pet", petId, "requested by", player.Name)
		return fail("Unknown pet")
	end

	if self:PlayerOwnsPet(player, petId) then
		return fail("Already adopted")
	end

	if not self.CurrencyManager then
		return fail("Adoption unavailable")
	end

	if not self.CurrencyManager:CanAfford(player, petDef.Cost) then
		return fail("Not enough " .. Constants.CURRENCY_NAME)
	end

	if not self.CurrencyManager:RemoveCurrency(player, petDef.Cost, "Adopted pet: " .. petId) then
		return fail("Adoption failed")
	end

	-- Record ownership and make the new pet the active follower
	local owned = self:GetOwnedPets(player)
	table.insert(owned, petId)
	self.PlayerDataService:UpdateData(player, "Pets", owned)
	self.PlayerDataService:UpdateData(player, "ActivePet", petId)
	self:SpawnPet(player)

	PetPurchaseResult:FireClient(player, {
		success = true,
		petId = petId,
		cost = petDef.Cost,
		activePet = petId,
	})
	NotifyPlayer:FireClient(player, petDef.Name .. " joined your family!")

	return true
end

-- Switch the active follower (petId) or dismiss it (nil)
function PetManager:HandleEquip(player, petId)
	if petId == nil then
		self.PlayerDataService:UpdateData(player, "ActivePet", nil)
		self:ClearPet(player)
		PetEquipResult:FireClient(player, { success = true, activePet = nil })
		return
	end

	if type(petId) ~= "string" or not self:PlayerOwnsPet(player, petId) then
		PetEquipResult:FireClient(player, { success = false, error = "Pet not adopted yet" })
		return
	end

	self.PlayerDataService:UpdateData(player, "ActivePet", petId)
	self:SpawnPet(player)
	PetEquipResult:FireClient(player, { success = true, activePet = petId })
end

function PetManager:Init(playerDataService, currencyManager)
	self.PlayerDataService = playerDataService
	self.CurrencyManager = currencyManager

	self:BuildCorner()

	PetPurchaseRequest.OnServerEvent:Connect(function(player, petId)
		self:HandlePurchase(player, petId)
	end)

	PetEquipRequest.OnServerEvent:Connect(function(player, petId)
		self:HandleEquip(player, petId)
	end)

	-- Respawn the active pet with each character (after data is loaded)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.spawn(function()
				-- Wait for PlayerDataService to finish loading
				while not self.PlayerDataService:GetData(player) and player.Parent do
					task.wait(0.5)
				end
				if player.Parent then
					task.wait(0.2) -- Let the character settle first
					self:SpawnPet(player)
				end
			end)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(function()
				task.wait(1)
				self:SpawnPet(player)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		self:ClearPet(player)
	end)

	print("PetManager initialized: Pet Corner is open")
end

return PetManager
