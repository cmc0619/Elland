--[[
	BakeryManager
	Ella's Bake Shop: a cozy family-recipes bake shop beside Ella's House.

	Structure: counter, striped awning, glass display case with cupcake
	props, warm interior lights, and a "Bake!" ProximityPrompt that opens
	BakeShopUI on the client.

	Baking is an ACTIVITY, not a plain purchase:
	  1. Client fires BakeStartRequest(itemId). The server validates the
	     recipe (from Constants.BAKERY.ITEMS), ownership, and funds, notes
	     the start time, and replies via BakeStartResult.
	  2. The client plays a short progress-bar minigame (timed Stir! /
	     Add sprinkles! / Frost! clicks) and fires
	     BakeCompleteRequest(itemId, perfectClicks).
	  3. The server sanity-checks the elapsed time (can't finish faster
	     than MIN_COMPLETION_TIME), charges the recipe cost, records the
	     baked good in player data (BakeryItems, persisted), and toasts
	     "Fresh out of the oven!". Perfect timing pays a small Coin bonus
	     with a per-player cooldown so it can't be farmed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local BakeryManager = {}
BakeryManager.PlayerDataService = nil
BakeryManager.CurrencyManager = nil

-- RemoteEvents (created at module load so clients can WaitForChild them)
local OpenBakeryUI = Instance.new("RemoteEvent")
OpenBakeryUI.Name = "OpenBakeryUI"
OpenBakeryUI.Parent = ReplicatedStorage

local BakeStartRequest = Instance.new("RemoteEvent")
BakeStartRequest.Name = "BakeStartRequest"
BakeStartRequest.Parent = ReplicatedStorage

local BakeStartResult = Instance.new("RemoteEvent")
BakeStartResult.Name = "BakeStartResult"
BakeStartResult.Parent = ReplicatedStorage

local BakeCompleteRequest = Instance.new("RemoteEvent")
BakeCompleteRequest.Name = "BakeCompleteRequest"
BakeCompleteRequest.Parent = ReplicatedStorage

local BakeCompleteResult = Instance.new("RemoteEvent")
BakeCompleteResult.Name = "BakeCompleteResult"
BakeCompleteResult.Parent = ReplicatedStorage

-- Shared one-line notification channel (ClientController shows the toast)
local NotifyPlayer = ReplicatedStorage:FindFirstChild("NotifyPlayer")
if not NotifyPlayer then
	NotifyPlayer = Instance.new("RemoteEvent")
	NotifyPlayer.Name = "NotifyPlayer"
	NotifyPlayer.Parent = ReplicatedStorage
end

local BAKERY = Constants.BAKERY
local GROUND_LEVEL = Constants.WORLD.GROUND_LEVEL

-- Server-side recipe catalog built from Constants.BAKERY.ITEMS (single
-- source of truth; the client never sets prices).
local RECIPE_CATALOG = {}
for _, item in ipairs(BAKERY.ITEMS) do
	RECIPE_CATALOG[item.Id] = item
end

-- player.UserId -> { itemId = string, startTime = os.clock() }
local pendingBakes = {}
-- player.UserId -> os.time() of last perfect-bake bonus payout
local lastBonusTime = {}

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

-- A little cupcake prop: wrapper cylinder + frosting ball + cherry
local function buildCupcake(parent, position, frostingColor)
	local wrapper = createPart(
		parent, "CupcakeWrapper", Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(210, 160, 100), Enum.Material.SmoothPlastic, false
	)
	wrapper.Shape = Enum.PartType.Cylinder

	createPart(
		parent, "Frosting", Vector3.new(0.6, 0.6, 0.6),
		CFrame.new(position + Vector3.new(0, 0.45, 0)),
		frostingColor, Enum.Material.SmoothPlastic, false
	).Shape = Enum.PartType.Ball

	createPart(
		parent, "Cherry", Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(position + Vector3.new(0, 0.8, 0)),
		Color3.fromRGB(220, 40, 60), Enum.Material.SmoothPlastic, false
	).Shape = Enum.PartType.Ball
end

-- The cozy shop: open-front counter, striped awning, display case, lights
function BakeryManager:BuildShop()
	local old = Workspace:FindFirstChild("EllasBakeShop")
	if old then
		old:Destroy()
	end

	local shop = Instance.new("Folder")
	shop.Name = "EllasBakeShop"
	shop.Parent = Workspace

	local center = BAKERY.POSITION
	local sizeX, sizeZ = 24, 18
	local wallHeight = 10
	local baseTop = GROUND_LEVEL + 1

	-- Base slab
	createPart(
		shop, "Base", Vector3.new(sizeX, 1, sizeZ),
		CFrame.new(center.X, GROUND_LEVEL + 0.5, center.Z),
		Color3.fromRGB(235, 210, 180), Enum.Material.WoodPlanks
	)

	local wallColor = Color3.fromRGB(255, 235, 215) -- Cream walls
	local wallY = baseTop + wallHeight / 2

	-- Back and side walls (front stays open like a market stall)
	createPart(shop, "BackWall", Vector3.new(sizeX, wallHeight, 1),
		CFrame.new(center.X, wallY, center.Z + sizeZ / 2), wallColor)
	for _, xSign in ipairs({ -1, 1 }) do
		createPart(shop, "SideWall", Vector3.new(1, wallHeight, sizeZ),
			CFrame.new(center.X + xSign * sizeX / 2, wallY, center.Z), wallColor)
	end

	-- Flat roof
	createPart(shop, "Roof", Vector3.new(sizeX + 2, 1, sizeZ + 2),
		CFrame.new(center.X, baseTop + wallHeight + 0.5, center.Z),
		Color3.fromRGB(200, 120, 110))

	-- Striped awning over the open front
	local awningY = baseTop + wallHeight - 1
	local stripeCount = 6
	for i = 1, stripeCount do
		local stripeX = center.X - sizeX / 2 + (i - 0.5) * (sizeX / stripeCount)
		local color = (i % 2 == 1) and Color3.fromRGB(255, 150, 160) or Color3.fromRGB(255, 250, 245)
		createPart(
			shop, "AwningStripe", Vector3.new(sizeX / stripeCount, 0.4, 6),
			CFrame.new(stripeX, awningY, center.Z - sizeZ / 2 - 3) * CFrame.Angles(math.rad(-20), 0, 0),
			color, Enum.Material.Fabric, false
		)
	end

	-- Sales counter across the open front (leaves gaps to walk around)
	createPart(
		shop, "Counter", Vector3.new(sizeX - 8, 3, 2),
		CFrame.new(center.X, baseTop + 1.5, center.Z - sizeZ / 2 + 2),
		Color3.fromRGB(180, 130, 85), Enum.Material.Wood
	)

	-- Glass display case on the counter with cupcakes inside
	local caseCenter = Vector3.new(center.X, baseTop + 3, center.Z - sizeZ / 2 + 2)
	createPart(
		shop, "DisplayCaseBase", Vector3.new(8, 0.4, 1.8),
		CFrame.new(caseCenter), Color3.fromRGB(120, 85, 55), Enum.Material.Wood
	)
	createPart(
		shop, "DisplayCaseGlass", Vector3.new(8, 1.6, 1.8),
		CFrame.new(caseCenter + Vector3.new(0, 1, 0)),
		Color3.fromRGB(220, 240, 255), Enum.Material.Glass, false
	).Transparency = 0.6
	for i, frosting in ipairs({
		Color3.fromRGB(255, 170, 190),
		Color3.fromRGB(255, 230, 170),
		Color3.fromRGB(200, 170, 255),
	}) do
		buildCupcake(shop, caseCenter + Vector3.new(-2.5 + (i - 1) * 2.5, 0.2, 0), frosting)
	end

	-- Oven against the back wall
	createPart(
		shop, "Oven", Vector3.new(5, 4, 3),
		CFrame.new(center.X + sizeX / 2 - 4, baseTop + 2, center.Z + sizeZ / 2 - 2.5),
		Color3.fromRGB(90, 90, 95), Enum.Material.Metal
	)
	createPart(
		shop, "OvenWindow", Vector3.new(3, 1.6, 0.3),
		CFrame.new(center.X + sizeX / 2 - 4, baseTop + 2.4, center.Z + sizeZ / 2 - 4),
		Color3.fromRGB(255, 170, 60), Enum.Material.Neon, false
	)

	-- Warm interior lights
	for _, offset in ipairs({ Vector3.new(-6, 0, 0), Vector3.new(6, 0, 0) }) do
		local lampPart = createPart(
			shop, "WarmLight", Vector3.new(1, 1, 1),
			CFrame.new(center.X + offset.X, baseTop + wallHeight - 1, center.Z + offset.Z),
			Color3.fromRGB(255, 220, 150), Enum.Material.Neon, false
		)
		lampPart.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 140)
		light.Brightness = 1.2
		light.Range = 18
		light.Parent = lampPart
	end

	-- Sign above the awning
	local sign = createPart(
		shop, "Sign", Vector3.new(14, 3, 0.5),
		CFrame.new(center.X, baseTop + wallHeight + 2.5, center.Z - sizeZ / 2 - 1),
		Color3.fromRGB(255, 250, 245)
	)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "ELLA'S BAKE SHOP"
	signLabel.TextColor3 = Color3.fromRGB(190, 90, 100)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Parent = signGui

	-- Bake! prompt at the counter
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "BakeryInteraction"
	interactionPart.Size = Vector3.new(6, 6, 6)
	interactionPart.Shape = Enum.PartType.Ball
	interactionPart.Position = Vector3.new(center.X, baseTop + 4, center.Z - sizeZ / 2 - 4)
	interactionPart.Anchored = true
	interactionPart.CanCollide = false
	interactionPart.Transparency = 0.5
	interactionPart.Color = Color3.fromRGB(255, 170, 120)
	interactionPart.Material = Enum.Material.Neon
	interactionPart.Parent = shop

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 16
	light.Color = Color3.fromRGB(255, 190, 140)
	light.Parent = interactionPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Bake!"
	prompt.ObjectText = "Ella's Bake Shop"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 15
	prompt.Parent = interactionPart

	prompt.Triggered:Connect(function(player)
		local data = self.PlayerDataService and self.PlayerDataService:GetData(player)
		if not data then
			return
		end
		local currency = self.CurrencyManager and self.CurrencyManager:GetCurrency(player) or 0
		OpenBakeryUI:FireClient(player, data.BakeryItems or {}, currency)
	end)

	print("BakeryManager: Ella's Bake Shop built")
end

function BakeryManager:GetBakedItems(player)
	local data = self.PlayerDataService and self.PlayerDataService:GetData(player)
	if data and data.BakeryItems then
		return data.BakeryItems
	end
	return {}
end

function BakeryManager:PlayerHasBaked(player, itemId)
	return table.find(self:GetBakedItems(player), itemId) ~= nil
end

-- Step 1: validate and begin a bake
function BakeryManager:HandleBakeStart(player, itemId)
	local function fail(message)
		BakeStartResult:FireClient(player, {
			success = false,
			itemId = itemId,
			error = message,
		})
		return false
	end

	if type(itemId) ~= "string" then
		return fail("Invalid recipe")
	end

	local recipe = RECIPE_CATALOG[itemId]
	if not recipe then
		warn("BakeryManager: Unknown recipe", itemId, "requested by", player.Name)
		return fail("Unknown recipe")
	end

	-- Each family recipe is baked once and kept in the scrapbook
	if self:PlayerHasBaked(player, itemId) then
		return fail("Already in your recipe book")
	end

	if pendingBakes[player.UserId] then
		return fail("Already baking something")
	end

	if not self.CurrencyManager then
		return fail("Bakery unavailable")
	end

	if not self.CurrencyManager:CanAfford(player, recipe.Cost) then
		return fail("Not enough " .. Constants.CURRENCY_NAME)
	end

	pendingBakes[player.UserId] = {
		itemId = itemId,
		startTime = os.clock(),
	}

	BakeStartResult:FireClient(player, {
		success = true,
		itemId = itemId,
		duration = BAKERY.BAKE_DURATION,
		steps = BAKERY.STEPS,
	})
	return true
end

-- Step 2: the minigame finished client-side; validate timing and grant
function BakeryManager:HandleBakeComplete(player, itemId, perfectClicks)
	local function fail(message)
		BakeCompleteResult:FireClient(player, {
			success = false,
			itemId = itemId,
			error = message,
		})
		pendingBakes[player.UserId] = nil
		return false
	end

	local pending = pendingBakes[player.UserId]
	if not pending or pending.itemId ~= itemId then
		return fail("No bake in progress")
	end

	-- Timing sanity: the minigame cannot honestly finish faster than this
	local elapsed = os.clock() - pending.startTime
	if elapsed < BAKERY.MIN_COMPLETION_TIME then
		warn("BakeryManager:", player.Name, "completed a bake suspiciously fast", elapsed)
		return fail("That bake went too fast - the oven needs its time!")
	end

	local recipe = RECIPE_CATALOG[itemId]
	if not recipe then
		return fail("Unknown recipe")
	end

	if self:PlayerHasBaked(player, itemId) then
		return fail("Already in your recipe book")
	end

	-- Charge only on successful completion (re-check funds server-side)
	if not self.CurrencyManager:CanAfford(player, recipe.Cost) then
		return fail("Not enough " .. Constants.CURRENCY_NAME)
	end
	if not self.CurrencyManager:RemoveCurrency(player, recipe.Cost, "Baked: " .. itemId) then
		return fail("Bake failed")
	end

	pendingBakes[player.UserId] = nil

	-- Grant the baked good into saved player data
	local baked = self:GetBakedItems(player)
	table.insert(baked, itemId)
	self.PlayerDataService:UpdateData(player, "BakeryItems", baked)

	-- Perfect timing bonus, rate-limited so it can't be farmed
	local perfect = false
	if type(perfectClicks) == "number" and perfectClicks >= #BAKERY.STEPS then
		local now = os.time()
		if not lastBonusTime[player.UserId] or now - lastBonusTime[player.UserId] >= BAKERY.PERFECT_COOLDOWN then
			lastBonusTime[player.UserId] = now
			self.CurrencyManager:AddCurrency(player, BAKERY.PERFECT_BONUS, "Perfect bake bonus")
			perfect = true
		end
	end

	BakeCompleteResult:FireClient(player, {
		success = true,
		itemId = itemId,
		cost = recipe.Cost,
		perfect = perfect,
	})

	local message = "Fresh out of the oven! You baked a " .. recipe.Name .. "!"
	if perfect then
		message = message .. " Perfect timing! +" .. BAKERY.PERFECT_BONUS .. " " .. Constants.CURRENCY_NAME
	end
	NotifyPlayer:FireClient(player, message)

	return true
end

function BakeryManager:Init(playerDataService, currencyManager)
	self.PlayerDataService = playerDataService
	self.CurrencyManager = currencyManager

	self:BuildShop()

	BakeStartRequest.OnServerEvent:Connect(function(player, itemId)
		self:HandleBakeStart(player, itemId)
	end)

	BakeCompleteRequest.OnServerEvent:Connect(function(player, itemId, perfectClicks)
		self:HandleBakeComplete(player, itemId, perfectClicks)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingBakes[player.UserId] = nil
		lastBonusTime[player.UserId] = nil
	end)

	print("BakeryManager initialized: Ella's Bake Shop is open")
end

return BakeryManager
